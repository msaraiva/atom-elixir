const { splitModuleAndFunc } = require('./utils');
const { getSubjectAndMarkerRange, gotoFirstNonCommentPosition } = require('./editor-utils');
const { Disposable, CompositeDisposable, Range } = require('atom');
const KeyClickEventHandler = require('./keyclick-event-handler');

module.exports = class ElixirGotoDefinitionProvider {

  constructor() {
    this.subscriptions = new CompositeDisposable();
    this.gotoStack = [];
    const sourceElixirSelector = 'atom-text-editor:not(mini)[data-grammar^="source elixir"]';

    this.subscriptions.add(atom.commands.add(sourceElixirSelector, 'atom-elixir:goto-definition', () => {
      const editor = atom.workspace.getActiveTextEditor();
      const position = editor.getCursorBufferPosition();
      const subjectAndMarkerRange = getSubjectAndMarkerRange(editor, position);
      if (subjectAndMarkerRange != null) {
        this.gotoDefinition(editor, position);
      }
    }));

    this.subscriptions.add(atom.commands.add('atom-text-editor:not(mini)', 'atom-elixir:return-from-definition', () => {
      const previousPosition = this.gotoStack.pop();
      if (!previousPosition) {
        return;
      }
      const [file, position] = previousPosition;
      atom.workspace.open(file, { searchAllPanes: true })
        .then((editor) => {
          if (!position) {
            return;
          }
          editor.setCursorBufferPosition(position);
          editor.scrollToScreenPosition(position, { center: true });
        });
    }));

    this.subscriptions.add(atom.workspace.observeTextEditors((editor) => {
      if (editor.getGrammar().scopeName !== 'source.elixir') {
        return;
      }
      const keyClickEventHandler = new KeyClickEventHandler(editor,
        this.keyClickHandler.bind(this));

      const editorDestroyedSubscription = editor.onDidDestroy(() => {
        editorDestroyedSubscription.dispose();
        keyClickEventHandler.dispose();
      });

      this.subscriptions.add(editorDestroyedSubscription);
    }));
  }

  dispose() {
    this.subscriptions.dispose();
  }

  setClient(client) {
    this.client = client;
  }

  keyClickHandler(editor, _subject, position) {
    this.gotoDefinition(editor, position);
  }

  gotoDefinition(editor, position) {
    const line = position.row + 1;
    const column = position.column + 1;
    const buffer = editor.buffer.getText();
    this.gotoStack.push([editor.getPath(), position]);

    if (!this.client) {
      console.log('ElixirSense client not ready');
      return;
    }

    this.client.send('definition', { buffer, line, column }, (file) => {
      switch (file) {
        case 'non_existing:0':
          console.log('[atom-elixir] Cannot find subject\'s definition. Either the source is not available or a required macro could not be properly expanded');
          return;
        case '':
          return;
        default:
          break;
      }

      const pane = atom.workspace.getActivePane();
      // "_" is match group 0, which is the original file name;
      const [, filePath, fileLine] = file.match(/(.*):(\d+)/);
      const initialLine = parseInt(fileLine - 1 || 0, 10);
      atom.workspace.open(filePath, { initialLine, searchAllPanes: true })
        .then((fileEditor) => {
          pane.activateItem(fileEditor);
          gotoFirstNonCommentPosition(fileEditor);
        });
    });
  }
};
