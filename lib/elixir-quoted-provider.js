const { CompositeDisposable } = require('atom');
const url = require('url');

let ElixirQuotedView = null; // Defer until used

function createElixirQuotedView(state) {
  if (!ElixirQuotedView) {
    ElixirQuotedView = require('./elixir-quoted-view');
  }
  return new ElixirQuotedView(state);
}

atom.deserializers.add({
  name: 'ElixirQuotedView',
  deserialize(state) {
    if (state.quotedCode) {
      return createElixirQuotedView(state);
    } else {
      return null;
    }
  },
});

module.exports = class ElixirQuotedProvider {

  constructor() {
    this.subscriptions = new CompositeDisposable();
    const sourceElixirSelector = 'atom-text-editor:not(mini)[data-grammar^="source elixir"]';

    this.subscriptions.add(atom.commands.add(sourceElixirSelector, 'atom-elixir:quote-selected-text', () => {
      const editor = atom.workspace.getActiveTextEditor();
      const text = editor.getSelectedText().replace(/\s+$/, '');
      this.showQuotedCodeView(text);
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

      if (components.host === 'elixir-quoted-views') {
        return createElixirQuotedView({ viewId: components.pathname.substring(1) });
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

  getQuotedCode(code, onResult) {
    if (code.trim() === '') {
      onResult('');
      return;
    }

    this.client.send('quote', { code }, (result) => {
      onResult(result);
    });
  }

  getMatches(pattern, quotedCode, onResult) {
    if (pattern.trim() === '' || quotedCode.trim() === '') {
      onResult('');
      return;
    }

    const code = `(${pattern}) = (${quotedCode})`;
    this.client.send('match', { code }, (result) => {
      onResult(result);
    });
  }

  showQuotedCodeView(code) {
    if (code === '') {
      this.addView('', '');
      return;
    }

    this.addView(code, '');
  }

  addView(code) {
    const options = { searchAllPanes: true, split: 'right' };
    const uri = 'atom-elixir://elixir-quoted-views/view';
    atom.workspace.open(uri, options)
      .then((elixirQuotedView) => {
        elixirQuotedView.setMatchesGetter(this.getMatches.bind(this));
        elixirQuotedView.setQuotedCodeGetter(this.getQuotedCode.bind(this));
        elixirQuotedView.setCode(code);
      });
  }
};
