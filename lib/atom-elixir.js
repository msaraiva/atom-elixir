const { TextEditor, CompositeDisposable } = require('atom');
const spawn = require('child_process').spawn;

const ElixirSenseClient = require('./elixir-sense-client');
const ElixirExpandProvider = require('./elixir-expand-provider');
const ElixirAutocompleteProvider = require('./elixir-autocomplete-provider');
const ElixirDocsProvider = require('./elixir-docs-provider');
const ElixirQuotedProvider = require('./elixir-quoted-provider');
const ElixirGotoDefinitionProvider = require('./elixir-goto-definition-provider');
const ElixirSignatureProvider = require('./elixir-signature-provider');

const ServerProcess = require('./server-process');

module.exports = {
  config: {
    enableSuggestionSnippet: {
      type: 'boolean',
      default: false,
      description: 'Enable autocomplete suggestion snippets for functions/macros',
      order: 1,
    },
    addParenthesesAfterSuggestionConfirmed: {
      type: 'string',
      default: 'addOpeningParenthesis',
      title: 'Add Parentheses After Comfirm Suggestion',
      description: 'Add parentheses for functions/macros after confirm suggestion. NOTICE: Only applicable when "Autocomplete Snippets" is disabled',
      order: 2,
      enum: [
        { value: 'disabled', description: 'Disabled' },
        { value: 'addParentheses', description: 'Add Parentheses' },
        { value: 'addOpeningParenthesis', description: 'Add Opening Parenthesis' },
      ],
    },
    showSignatureInfoAfterSuggestionConfirm: {
      type: 'boolean',
      default: true,
      title: 'Show signature info after confirm sugggestion',
      description: 'Open the signature info view for functions/macros after confirm suggestion. NOTICE: Only applicable when "Add Parentheses After Confirm Suggestion" is also enabled',
      order: 3,
    },
  },

  expandProvider: null,
  autocompleteProvider: null,
  gotoDefinitionProvider: null,
  docsProvider: null,
  quotedProvider: null,
  signatureProvider: null,

  activate() {
    console.log(`[atom-elixir] Activating atom-elixir version ${this.packageVersion()}`);

    this.initEnv();
    this.expandProvider = new ElixirExpandProvider();
    this.autocompleteProvider = new ElixirAutocompleteProvider();
    this.gotoDefinitionProvider = new ElixirGotoDefinitionProvider();
    this.docsProvider = new ElixirDocsProvider();
    this.quotedProvider = new ElixirQuotedProvider();
    this.signatureProvider = new ElixirSignatureProvider();

    this.subscriptions = new CompositeDisposable();
    this.subscriptions.add(atom.workspace.observeActivePaneItem((item) => {
      if (this.elixirSenseClient && item instanceof TextEditor) {
        const env = this.getEditorEnv(item);
        const projectPath = this.getProjectPath();
        if ((env !== this.elixirSenseClient.env) ||
            (projectPath !== this.elixirSenseClient.projectPath)) {
          this.elixirSenseClient.setContext(this.getEditorEnv(item), projectPath);
        }
      }
    }));

    const sourceElixirSelector = 'atom-text-editor[data-grammar^="source elixir"]';
    this.subscriptions.add(atom.commands.add(sourceElixirSelector, 'atom-elixir:show-signature', (e) => {
      const editor = atom.workspace.getActiveTextEditor();
      this.signatureProvider.showSignature(editor, editor.getLastCursor(), true);
      if (e.originalEvent && e.originalEvent.key === '(') {
        e.abortKeyBinding();
      }
    }));

    this.subscriptions.add(atom.commands.add(sourceElixirSelector, 'atom-elixir:close-signature', (e) => {
      if (this.signatureProvider.show) {
        this.signatureProvider.closeSignature();
      } else {
        e.abortKeyBinding();
      }
    }));

    this.subscriptions.add(atom.commands.add(sourceElixirSelector, 'atom-elixir:hide-signature', () => {
      if (this.signatureProvider.show) {
        this.signatureProvider.hideSignature();
      }
    }));

    this.subscriptions.add(atom.workspace.observeTextEditors((editor) => {
      if (editor.getGrammar().scopeName !== 'source.elixir') {
        return;
      }

      const editorChangeCursorPositionSubscription = editor.onDidChangeCursorPosition((e) => {
        this.signatureProvider.showSignature(editor, e.cursor, false);
      });

      const editorDestroyedSubscription = editor.onDidDestroy(() => {
        editorChangeCursorPositionSubscription.dispose();
        editorDestroyedSubscription.dispose();
      });

      this.subscriptions.add(editorDestroyedSubscription);
    }));
  },

  deactivate() {
    console.log(`[atom-elixir] Deactivating atom-elixir version ${this.packageVersion()}`);

    this.cleanRequireCache();
    this.expandProvider.dispose();
    this.expandProvider = null;
    this.autocompleteProvider.dispose();
    this.autocompleteProvider = null;
    this.gotoDefinitionProvider.dispose();
    this.gotoDefinitionProvider = null;
    this.docsProvider.dispose();
    this.docsProvider = null;
    this.quotedProvider.dispose();
    this.quotedProvider = null;
    this.signatureProvider.destroy();
    this.signatureProvider = null;
    this.server.stop();
    this.server = null;
    this.subscriptions.dispose();
  },

  packageVersion() {
    return atom.packages.getLoadedPackage('atom-elixir').metadata.version;
  },

  provideAutocomplete() {
    return [this.autocompleteProvider];
  },

  getEditorEnv(editor) {
    const projectPath = atom.project.getPaths()[0];
    let env = 'dev';
    if (editor && editor.getPath() && editor.getPath().startsWith(`${projectPath}/test/`)) {
      env = 'test';
    }
    return env;
  },

  cleanRequireCache() {
    Object.keys(require.cache)
      .filter(p => p.indexOf('/atom-elixir/lib/') > 0)
      .forEach(p => delete require.cache[p]);
  },

  getProjectPath() {
    return atom.project.getPaths()[0];
  },

  initEnv() {
    const shell = process.env.SHELL || 'bash';
    let out = '';

    let pid;
    if (process.platform === 'win32') {
      pid = spawn('cmd', ['/C', 'set']);
    } else {
      pid = spawn(shell, ['--login', '-c', 'env']);
    }

    pid.stdout.on('data', (chunk) => {
      out += chunk;
    });
    pid.on('error', () => console.log('Failed to import ENV from', shell));
    pid.on('close', () => {
      out.split('\n').forEach((line) => {
        const match = line.match(/^(\S+?)=(.+)/);
        if (match) {
          process.env[match[1]] = match[2];
        }
      });

      this.server = new ServerProcess(this.getProjectPath(), (host, port, authToken) => {
        const env = this.getEditorEnv(atom.workspace.getActiveTextEditor());
        this.elixirSenseClient = new ElixirSenseClient(host, port, authToken,
                                                       env, this.getProjectPath());
        this.signatureProvider.setClient(this.elixirSenseClient);
        this.autocompleteProvider.setClient(this.elixirSenseClient);
        this.gotoDefinitionProvider.setClient(this.elixirSenseClient);
        this.docsProvider.setClient(this.elixirSenseClient);
        this.expandProvider.setClient(this.elixirSenseClient);
        this.quotedProvider.setClient(this.elixirSenseClient);
      });

      this.server.start(0, this.getEditorEnv(atom.workspace.getActiveTextEditor()));
    });

    pid.stdin.end();
  },
};
