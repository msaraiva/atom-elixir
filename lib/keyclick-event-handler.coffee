{Disposable, CompositeDisposable, Range}  = require 'atom'

module.exports =
class KeyClickEventHandler

  constructor: (editor, getFullWordAndMarkRangeHandler, clickCallback) ->
    @editor = editor
    @getFullWordAndMarkRangeHandler = getFullWordAndMarkRangeHandler
    @clickCallback = clickCallback
    @editorView = atom.views.getView(editor)
    @marker = null
    @lastBufferPosition = null
    @textAndRange = null
    @disposables = new CompositeDisposable
    # wordRegExp is based on atom.workspace.getActiveTextEditor().getLastCursor().wordRegExp()
    @wordRegExp = /^[	 ]*$|[^\s\/\\\(\)"',\.;<>~#\$%\^&\*\|\+=\[\]\{\}`\-…]+|[\/\\\(\)"',\.;<>~!#\$%\^&\*\|\+=\[\]\{\}`\?\-…]+/g
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
    if @textAndRange != null
      @clickCallback(@editor, @textAndRange.text, @textAndRange.range)
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

      textAndRange = @getFullWordAndMarkRangeHandler(@editor, bufferPosition, @wordRegExp)

      if textAndRange == null
        @clearMarker()
        return

      if @marker != null && @marker.getBufferRange().compare(textAndRange.range) == 0
        return

      @clearMarker()
      @createMarker(textAndRange)

  createMarker: (textAndRange) ->
    @editorView.classList.add('keyclick');
    @marker = @editor.markBufferRange(textAndRange.range, { invalidate: 'never' });
    @textAndRange = textAndRange
    @editor.decorateMarker(@marker, { type: 'highlight', 'class': 'keyclick' });

  clearMarker: ->
    @marker?.destroy()
    @marker = null
    @textAndRange = null
    @lastBufferPosition = null
    @editorView.classList.remove('keyclick')
