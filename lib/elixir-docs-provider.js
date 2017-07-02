const { CompositeDisposable } = require('atom');
const { getSubjectAndMarkerRange } = require('./editor-utils');
const url = require('url');

let ElixirDocsView = null; // Defer until used

function createElixirDocsView(state) {
  if (!ElixirDocsView) {
    ElixirDocsView = require('./elixir-docs-view');
  }
  return new ElixirDocsView(state);
}

atom.deserializers.add({
  name: 'ElixirDocsView',
  deserialize(state) {
    if (state.viewId) {
      return createElixirDocsView(state);
    } else {
      return null;
    }
  },
});

module.exports = class ElixirDocsProvider {

  constructor() {
    this.subscriptions = new CompositeDisposable();
    const sourceElixirSelector = 'atom-text-editor:not(mini)[data-grammar^="source elixir"]';
    this.subscriptions.add(atom.commands.add(sourceElixirSelector, 'atom-elixir:show-elixir-docs', () => {
      this.showElixirDocs();
    }));

    atom.workspace.addOpener((uriToOpen) => {
      let components;
      try {
        components = url.parse(uriToOpen);
        console.log(components);
      } catch (error) {
        return null;
      }

      if (components.protocol !== 'atom-elixir:') {
        return null;
      }

      try {
        if (components.pathname) {
          components.pathname = decodeURI(components.pathname);
        }
      } catch (error) {
        return null;
      }

      if (components.host === 'elixir-docs-views') {
        return createElixirDocsView({ viewId: components.pathname.substring(1) });
      } else {
        return null;
      }
    });
  }

  dispose() {
    this.subscriptions.dispose();
  }

  setClient(client) {
    this.client = client;
  }

  showElixirDocs() {
    this.addViewForElement();
  }

  uriForElement(word) {
    return `atom-elixir://elixir-docs-views/${word}`;
  }

  addViewForElement(word) {
    const editor = atom.workspace.getActiveTextEditor();
    const buffer = editor.buffer.getText();
    const position = editor.getCursorBufferPosition();
    const line = position.row + 1;
    const column = position.column + 1;

    if (!this.client) {
      console.log('ElixirSense client not ready');
      return;
    }

    this.client.send('docs', { buffer, line, column }, (result) => {
      const { actual_subject: actualSubject, docs } = result;
      if (!docs) {
        return;
      }

      const uri = this.uriForElement(actualSubject);
      const options = { searchAllPanes: true, split: 'right' };
      // TODO: Create this configuration
      // options = { searchAllPanes: true };
      if (atom.config.get('atom-elixir.elixirDocs.openViewInSplitPane')) {
        // options.split = 'right'
      }

      // previousActivePane = atom.workspace.getActivePane()
      atom.workspace.open(uri, options)
        .then((elixirDocsView) => {
          // TODO: We could use a configuration to tell if the focus should remain on the editor
          // if atom.config.get('atom-elixir.elixirDocs.keepFocusOnEditorAfterOpenDocs')
          //   previousActivePane.activate()

          elixirDocsView.setSource(docs);
        });
    });
  }
};
