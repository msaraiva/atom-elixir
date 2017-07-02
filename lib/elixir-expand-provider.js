const { CompositeDisposable } = require('atom');
const url = require('url');

let ElixirExpandView = null; // Defer until used

function createElixirExpandView(state) {
  if (!ElixirExpandView) {
    ElixirExpandView = require('./elixir-expand-view');
  }
  return new ElixirExpandView(state);
}

atom.deserializers.add({
  name: 'ElixirExpandView',
  deserialize(state) {
    if (state.expandCode) {
      return createElixirExpandView(state);
    } else {
      return null;
    }
  },
});

module.exports = class ElixirExpandProvider {

  constructor() {
    this.subscriptions = new CompositeDisposable();
    const sourceElixirSelector = 'atom-text-editor:not(mini)[data-grammar^="source elixir"]';

    this.subscriptions.add(atom.commands.add(sourceElixirSelector, 'atom-elixir:expand-selected-text', () => {
      const editor = atom.workspace.getActiveTextEditor();
      const buffer = editor.getText();
      const text = editor.getSelectedText().replace(/\s+$/, '');
      const line = editor.getSelectedBufferRange().start.row + 1;
      this.showExpandCodeView(buffer, text, line);
    }));

    atom.workspace.addOpener((uriToOpen) => {
      let components;
      try {
        components = url.parse(uriToOpen);
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

      if (components.host === 'elixir-expand-views') {
        return createElixirExpandView({ viewId: components.pathname.substring(1) });
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

  getExpandFull(buffer, selectedCode, line, onResult) {
    if (!this.client) {
      console.log('ElixirSense client not ready');
      return;
    }

    if (selectedCode.trim() === '') {
      onResult('');
      return;
    }

    this.client.send('expand_full', { buffer, selected_code: selectedCode, line }, (result) => {
      onResult(result);
    });
  }

  showExpandCodeView(buffer, code, line) {
    if (code === '') {
      this.addView('', '', '');
      return;
    }
    this.addView(buffer, code, line);
  }

  addView(buffer, code, line) {
    const options = { searchAllPanes: true, split: 'right' };
    const uri = 'atom-elixir://elixir-expand-views/view';
    atom.workspace.open(uri, options)
      .then((elixirExpandView) => {
        elixirExpandView.setExpandFullGetter(this.getExpandFull.bind(this));
        elixirExpandView.setBuffer(buffer);
        elixirExpandView.setLine(line);
        elixirExpandView.setCode(code);
      });
  }
};
