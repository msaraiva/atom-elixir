{Disposable, CompositeDisposable, Range}  = require 'atom'
{getSubjectAndMarkerRange} = require './editor-utils'

module.exports =
class KeyClickEventHandler

  constructor: (editor, clickCallback) ->
    @editor = editor
    @clickCallback = clickCallback
    @editorView = atom.views.getView(editor)
    @marker = null
    @lastScreenPosition = null
    @lastBufferPosition = null
    @subjectAndMarkerRange = null
    @subscriptions = new CompositeDisposable
    @handleEvents()

  dispose: ->
    @subscriptions.dispose()

  handleEvents: ->
    @subscriptions.add @addEventHandler(@editorView, 'mousedown', @mousedownHandler)
    @subscriptions.add @addEventHandler(@editorView, 'keyup',     @keyupHandler)
    @subscriptions.add @addEventHandler(@editorView, 'mousemove', @mousemoveHandler)

  addEventHandler: (editorView, eventName, handler) ->
    editorView.addEventListener eventName, handler
    new Disposable ->
      editorView.removeEventListener eventName, handler

  mousedownHandler: (event) =>
    if @subjectAndMarkerRange != null
      @clickCallback(@editor, @subjectAndMarkerRange.subject, @lastBufferPosition)
    @clearMarker()

  keyupHandler: (event) =>
    @clearMarker()
    @lastBufferPosition = null

  mousemoveHandler: (event) =>
    if event.altKey
      component = @editorView.component
      screenPosition = component.screenPositionForMouseEvent({clientX: event.clientX, clientY: event.clientY})
      if @lastScreenPosition != null && screenPosition.compare(@lastScreenPosition) == 0
        return

      @lastScreenPosition = screenPosition
      bufferPosition = @editor.bufferPositionForScreenPosition(screenPosition)

      if @lastBufferPosition != null && bufferPosition.compare(@lastBufferPosition) == 0
        return
      @lastBufferPosition = bufferPosition

      subjectAndMarkerRange = getSubjectAndMarkerRange(@editor, bufferPosition)

      if subjectAndMarkerRange == null
        @clearMarker()
        return

      if @marker != null && @marker.getBufferRange().compare(subjectAndMarkerRange.range) == 0
        return

      @clearMarker()
      @createMarker(subjectAndMarkerRange)

  createMarker: (subjectAndMarkerRange) ->
    @editorView.classList.add('keyclick');
    @marker = @editor.markBufferRange(subjectAndMarkerRange.range, { invalidate: 'never' });
    @subjectAndMarkerRange = subjectAndMarkerRange
    @editor.decorateMarker(@marker, { type: 'highlight', 'class': 'keyclick' });

  clearMarker: ->
    @marker?.destroy()
    @marker = null
    @subjectAndMarkerRange = null
    @editorView.classList.remove('keyclick')
