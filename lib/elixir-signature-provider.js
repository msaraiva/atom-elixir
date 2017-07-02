const ElixirSignatureView = require('./elixir-signature-view');

module.exports = class ElixirSignatureProvider {

  constructor() {
    this.view = new ElixirSignatureView();
    this.view.initialize(this);
    atom.views.getView(atom.workspace).appendChild(this.view);

    this.overlayDecoration = null;
    this.marker = null;
    this.lastResult = null;
    this.timeout = null;
    this.show = false;
  }

  setPosition() {
    const decorationParams = {
      type: 'overlay',
      item: this.view,
      class: 'elixir-signature-view',
      position: 'tale',
      invalidate: 'touch',
    };

    if (!this.marker) {
      const editor = atom.workspace.getActiveTextEditor();
      if (!editor) {
        return;
      }

      this.marker = editor.getLastCursor().getMarker();
      if (!this.marker) {
        return;
      }

      this.overlayDecoration = editor.decorateMarker(this.marker, decorationParams);
    } else {
      this.marker.setProperties(decorationParams);
    }
  }

  destroyOverlay() {
    if (this.overlayDecoration) {
      this.overlayDecoration.destroy();
    }
    this.overlayDecoration = null;
    this.marker = null;
  }

  updateSignatures(editor, cursor, fromAction) {
    if (!this.show || cursor.destroyed) {
      return;
    }

    const buffer = editor.getBuffer();
    const bufferPosition = editor.getCursorBufferPosition();
    const line = bufferPosition.row + 1;
    const column = bufferPosition.column + 1;

    const scopeDescriptor = cursor.getScopeDescriptor();
    if (scopeDescriptor.scopes.join().match(/comment/)) {
      this.destroyOverlay();
      return;
    }

    const editorElement = atom.views.getView(editor);
    if (Array.from(editorElement.classList).includes('autocomplete-active')) {
      return;
    }

    this.querySignatures(buffer.getText(), line, column);
  }

  querySignatures(buffer, line, column) {
    if (!this.client) {
      this.show = false;
      console.log('ElixirSense client not ready');
      return;
    }

    this.client.send('signature', { buffer, line, column }, (result) => {
      this.destroyOverlay();
      if (result === 'none') {
        this.show = false;
        return;
      }
      this.view.setData(result);
      this.setPosition();
    });
  }

  destroy() {
    this.destroyOverlay();
    if (this.view) {
      this.view.destroy();
    }
    this.view = null;
  }

  setClient(client) {
    this.client = client;
  }

  showSignature(editor, cursor, fromAction) {
    if (this.timeout != null) {
      clearTimeout(this.timeout);
      this.timeout = null;
    }

    if (fromAction) {
      this.show = true;
    }

    this.timeout = setTimeout(() => this.updateSignatures(editor, cursor, fromAction), 50);
  }

  closeSignature() {
    this.show = false;
    this.destroyOverlay();
  }

  hideSignature() {
    this.destroyOverlay();
  }
};
