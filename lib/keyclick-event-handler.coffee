{Disposable, CompositeDisposable, Range}  = require 'atom'
{getSubjectAndMarkerRange} = require './editor-utils'

module.exports =
class KeyClickEventHandler

  constructor: (editor, clickCallback) ->
    @editor = editor
    @clickCallback = clickCallback
    @editorView = atom.views.getView(editor)
    @marker = null
    @lastBufferPosition = null
    @firstMouseMove = true
    @subjectAndMarkerRange = null
    @subscriptions = new CompositeDisposable
    @handleEvents()

  dispose: ->
    @subscriptions.dispose()

  handleEvents: ->
    @subscriptions.add @addEventHandler(@editorView, 'mousedown', @mousedownHandler)
    @subscriptions.add @addEventHandler(@editorView, 'keyup',     @keyupHandler)
    @subscriptions.add @addEventHandler(@editorView, 'mousemove', @mousemoveHandler)
    @subscriptions.add @addEventHandler(@editorView, 'focus', @focusHandler)

  addEventHandler: (editorView, eventName, handler) ->
    editorView.addEventListener eventName, handler
    new Disposable ->
      editorView.removeEventListener eventName, handler

  focusHandler: (event) =>
    @clearMarker()
    @lastBufferPosition = null
    @firstMouseMove = true

  mousedownHandler: (event) =>
    if @subjectAndMarkerRange != null
      @clickCallback(@editor, @subjectAndMarkerRange.subject, @lastBufferPosition)

  keyupHandler: (event) =>
    @clearMarker()
    @lastBufferPosition = null

  mousemoveHandler: (event) =>
    if @firstMouseMove
      @firstMouseMove = false
      return

    if event.altKey && !event.metaKey && !event.ctrlKey
      component = @editorView.component
      screenPosition = component.screenPositionForMouseEvent({clientX: event.clientX, clientY: event.clientY})
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
