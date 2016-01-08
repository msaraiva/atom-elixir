{Disposable, CompositeDisposable, Range}  = require 'atom'

module.exports =
class KeyClickEventHandler

  constructor: (editor, getSubjectAndMarkerRange, clickCallback) ->
    @editor = editor
    @getSubjectAndMarkerRange = getSubjectAndMarkerRange
    @clickCallback = clickCallback
    @editorView = atom.views.getView(editor)
    @marker = null
    @lastBufferPosition = null
    @subjectAndRange = null
    @disposables = new CompositeDisposable
    @handleEvents()

  dispose: ->
    @disposables.dispose()

  handleEvents: ->
    @disposables.add @addEventHandler(@editorView, 'mousedown', @mousedownHandler)
    @disposables.add @addEventHandler(@editorView, 'keyup',     @keyupHandler)
    @disposables.add @addEventHandler(@editorView, 'mousemove', @mousemoveHandler)

  addEventHandler: (editorView, eventName, handler) ->
    editorView.addEventListener eventName, handler
    new Disposable ->
      console.log("removeEventListener(#{eventName}): #{editorView}")
      editorView.removeEventListener eventName, handler

  mousedownHandler: (event) =>
    console.log("mousedown: #{@editor.id}")
    # event.stopPropagation()
    if @subjectAndRange != null
      @clickCallback(@editor, @subjectAndRange.subject, @lastBufferPosition)
    @clearMarker()

  keyupHandler: (event) =>
    console.log("keyup: #{@editor.id}")
    @clearMarker()

  mousemoveHandler: (event) =>
    if event.altKey
      component = @editorView.component
      screenPosition = component.screenPositionForMouseEvent({clientX: event.clientX, clientY: event.clientY})
      bufferPosition = @editor.bufferPositionForScreenPosition(screenPosition)

      if @lastBufferPosition != null && bufferPosition.compare(@lastBufferPosition) == 0
        return
      @lastBufferPosition = bufferPosition

      subjectAndRange = @getSubjectAndMarkerRange(@editor, bufferPosition)

      if subjectAndRange == null
        @clearMarker()
        return

      if @marker != null && @marker.getBufferRange().compare(subjectAndRange.range) == 0
        return

      @clearMarker()
      @createMarker(subjectAndRange)

  createMarker: (subjectAndRange) ->
    @editorView.classList.add('keyclick');
    @marker = @editor.markBufferRange(subjectAndRange.range, { invalidate: 'never' });
    @subjectAndRange = subjectAndRange
    @editor.decorateMarker(@marker, { type: 'highlight', 'class': 'keyclick' });

  clearMarker: ->
    @marker?.destroy()
    @marker = null
    @subjectAndRange = null
    @lastBufferPosition = null
    @editorView.classList.remove('keyclick')
