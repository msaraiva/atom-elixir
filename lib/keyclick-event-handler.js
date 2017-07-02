const { Disposable, CompositeDisposable, Range } = require('atom');
const { getSubjectAndMarkerRange } = require('./editor-utils');

module.exports = class KeyClickEventHandler {

  constructor(editor, clickCallback) {
    this.editor = editor;
    this.clickCallback = clickCallback;
    this.editorView = atom.views.getView(editor);
    this.marker = null;
    this.lastBufferPosition = null;
    this.firstMouseMove = true;
    this.subjectAndMarkerRange = null;
    this.subscriptions = new CompositeDisposable();
    this.handleEvents();
  }

  dispose() {
    this.subscriptions.dispose();
  }

  handleEvents() {
    this.subscriptions.add(this.addEventHandler(this.editorView, 'mousedown', this.mousedownHandler.bind(this)));
    this.subscriptions.add(this.addEventHandler(this.editorView, 'keyup', this.keyupHandler.bind(this)));
    this.subscriptions.add(this.addEventHandler(this.editorView, 'mousemove', this.mousemoveHandler.bind(this)));
    this.subscriptions.add(this.addEventHandler(this.editorView, 'focus', this.focusHandler.bind(this)));
  }

  addEventHandler(editorView, eventName, handler) {
    editorView.addEventListener(eventName, handler);
    return new Disposable(() => editorView.removeEventListener(eventName, handler));
  }

  focusHandler(event) {
    this.clearMarker();
    this.lastBufferPosition = null;
    this.firstMouseMove = true;
  }

  mousedownHandler(event) {
    if (this.subjectAndMarkerRange != null) {
      this.clickCallback(this.editor, this.subjectAndMarkerRange.subject, this.lastBufferPosition);
    }
  }

  keyupHandler(event) {
    this.clearMarker();
    this.lastBufferPosition = null;
  }

  mousemoveHandler(event) {
    if (this.firstMouseMove) {
      this.firstMouseMove = false;
      return;
    }

    if (event.altKey && !event.metaKey && !event.ctrlKey) {
      const component = this.editorView.component;
      const screenPosition = component.screenPositionForMouseEvent({
        clientX: event.clientX,
        clientY: event.clientY,
      });
      const bufferPosition = this.editor.bufferPositionForScreenPosition(screenPosition);

      if (this.lastBufferPosition != null &&
          bufferPosition.compare(this.lastBufferPosition) === 0) {
        return;
      }
      this.lastBufferPosition = bufferPosition;

      const subjectAndMarkerRange = getSubjectAndMarkerRange(this.editor, bufferPosition);

      if (subjectAndMarkerRange == null) {
        this.clearMarker();
        return;
      }

      if (this.marker != null &&
          this.marker.getBufferRange().compare(subjectAndMarkerRange.range) === 0) {
        return;
      }

      this.clearMarker();
      this.createMarker(subjectAndMarkerRange);
    }
  }

  createMarker(subjectAndMarkerRange) {
    this.editorView.classList.add('keyclick');
    this.marker = this.editor.markBufferRange(subjectAndMarkerRange.range, { invalidate: 'never' });
    this.subjectAndMarkerRange = subjectAndMarkerRange;
    this.editor.decorateMarker(this.marker, { type: 'highlight', class: 'keyclick' });
  }

  clearMarker() {
    if (this.marker) {
      this.marker.destroy();
    }
    this.marker = null;
    this.subjectAndMarkerRange = null;
    this.editorView.classList.remove('keyclick');
  }
};
