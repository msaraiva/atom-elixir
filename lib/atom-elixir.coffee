{TextEditor, CompositeDisposable} = require 'atom'
spawn = require('child_process').spawn
ElixirSenseClient = require './elixir-sense-client'

module.exports = AtomElixir =

  config:
    enableSuggestionSnippet:
      type: 'boolean'
      default: false
      description: 'Enable autocomplete suggestion snippets for functions/macros'
      order: 1
    addParenthesesAfterSuggestionConfirmed:
      type: 'string'
      default: 'addOpeningParenthesis'
      title: 'Add Parentheses After Comfirm Suggestion'
      description: 'Add parentheses for functions/macros after comfirm suggestion. NOTICE: Only applicable when "Autocomplete Snippets" is disabled'
      order: 2
      enum: [
        {value: 'disabled', description: "Disabled"}
        {value: 'addParentheses', description: 'Add Parentheses'}
        {value: 'addOpeningParenthesis', description: 'Add Opening Parenthesis'}
      ]
    showSignatureInfoAfterSuggestionConfirm:
      type: 'boolean'
      default: true
      title: 'Show signature info after confirm sugggestion'
      description: 'Open the signature info view for functions/macros after confirm suggestion. NOTICE: Only applicable when "Add Parentheses After Comfirm Suggestion" is also enabled'
      order: 3

  expandProvider: null
  autocompleteProvider: null
  gotoDefinitionProvider: null
  docsProvider: null
  quotedProvider: null
  signatureProvider: null

  activate: (state) ->
    console.log "[atom-elixir] Activating atom-elixir version #{@packageVersion()}"

    ElixirExpandProvider = require('./elixir-expand-provider')
    ElixirAutocompleteProvider = require('./elixir-autocomplete-provider')
    ElixirDocsProvider = require('./elixir-docs-provider')
    ElixirQuotedProvider = require('./elixir-quoted-provider')
    ElixirGotoDefinitionProvider = require('./elixir-goto-definition-provider')
    ElixirSignatureProvider = require('./elixir-signature-provider');

    @initEnv()
    @expandProvider = new ElixirExpandProvider
    @autocompleteProvider = new ElixirAutocompleteProvider
    @gotoDefinitionProvider = new ElixirGotoDefinitionProvider
    @docsProvider = new ElixirDocsProvider
    @quotedProvider = new ElixirQuotedProvider
    @signatureProvider = new ElixirSignatureProvider

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.workspace.observeActivePaneItem (item) =>
      if @elixirSenseClient && item instanceof TextEditor
        env = @getEditorEnv(item)
        projectPath = @getProjectPath()
        if (env != @elixirSenseClient.env) or (projectPath != @elixirSenseClient.projectPath)
          @elixirSenseClient.setContext(@getEditorEnv(item), projectPath)

    sourceElixirSelector = 'atom-text-editor[data-grammar^="source elixir"]'

    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:observer-start', =>
      @elixirSenseClient.send "observer", {action: "start"}, (result) =>
        console.log("Observer response: " + result)

    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:observer-stop', =>
      @elixirSenseClient.send "observer", {action: "stop"}, (result) =>
        console.log("Observer response: " + result)

    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:show-signature', (e) =>
      editor = atom.workspace.getActiveTextEditor()
      @signatureProvider.showSignature(editor, editor.getLastCursor(), true)
      if e.originalEvent && e.originalEvent.key == '('
        e.abortKeyBinding()

    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:close-signature', (e) =>
      if (@signatureProvider.show)
        @signatureProvider.closeSignature()
      else
        e.abortKeyBinding()

    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:hide-signature', (e) =>
      if (@signatureProvider.show)
        @signatureProvider.hideSignature()

    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      if (editor.getGrammar().scopeName != 'source.elixir')
        return

      editorChangeCursorPositionSubscription = editor.onDidChangeCursorPosition (e) =>
        @signatureProvider.showSignature(editor, e.cursor, false)

      editorDestroyedSubscription = editor.onDidDestroy =>
        editorChangeCursorPositionSubscription.dispose()
        editorDestroyedSubscription.dispose()

      @subscriptions.add(editorDestroyedSubscription)

  deactivate: ->
    console.log "[atom-elixir] Deactivating atom-elixir version #{@packageVersion()}"

    @cleanRequireCache()
    @expandProvider.dispose()
    @expandProvider = null
    @autocompleteProvider.dispose()
    @autocompleteProvider = null
    @gotoDefinitionProvider.dispose()
    @gotoDefinitionProvider = null
    @docsProvider.dispose()
    @docsProvider = null
    @quotedProvider.dispose()
    @quotedProvider = null
    @signatureProvider.destroy()
    @signatureProvider = null
    @server.stop()
    @server = null
    @subscriptions.dispose()

  packageVersion: ->
    atom.packages.getLoadedPackage('atom-elixir').metadata.version

  provideAutocomplete: ->
    [@autocompleteProvider]

  getEditorEnv: (editor)->
    projectPath = atom.project.getPaths()[0]
    env = "dev"
    if editor?.getPath()?.startsWith(projectPath + '/test/')
      env = "test"
    env

  cleanRequireCache: ->
    Object.keys(require.cache)
      .filter (p) -> p.indexOf("/atom-elixir/lib/") > 0
      .forEach (p) ->
        delete require.cache[p]

  getProjectPath: ->
    atom.project.getPaths()[0]

  initEnv: ->
    ServerProcess = require './server-process'

    [shell, out] = [process.env.SHELL || 'bash', '']
    pid = if process.platform == 'win32' then spawn('cmd', ['/C', 'set']) else spawn(shell, ['--login', '-c', 'env'])
    pid.stdout.on 'data', (chunk) -> out += chunk
    pid.on 'error', =>
      console.log('Failed to import ENV from', shell)
    pid.on 'close', =>
      for line in out.split('\n')
        match = line.match(/^(\S+?)=(.+)/)
        process.env[match[1]] = match[2] if match

      @server = new ServerProcess @getProjectPath(), (host, port) =>
        env = @getEditorEnv(atom.workspace.getActiveTextEditor())
        @elixirSenseClient = new ElixirSenseClient(host, port, env, @getProjectPath())
        @signatureProvider.setClient(@elixirSenseClient)
        @autocompleteProvider.setClient(@elixirSenseClient)
        @gotoDefinitionProvider.setClient(@elixirSenseClient)
        @docsProvider.setClient(@elixirSenseClient)
        @expandProvider.setClient(@elixirSenseClient)
        @quotedProvider.setClient(@elixirSenseClient)

      @server.start(@getEditorEnv(atom.workspace.getActiveTextEditor()))

    pid.stdin.end()
