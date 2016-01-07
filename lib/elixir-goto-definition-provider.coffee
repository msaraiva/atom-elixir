{Disposable, CompositeDisposable, Range}  = require 'atom'

module.exports =
class KeyClickProvider

  constructor: ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      if (editor.getGrammar().scopeName != 'source.elixir')
        return
      @handleEvents(editor)

  dispose: ->
    @subscriptions.dispose()

  handleEvents: (editor) ->
    disposables = new CompositeDisposable()

    addEventListener = (editor, eventName, handler) ->
      editorView = atom.views.getView editor
      editorView.addEventListener eventName, handler
      new Disposable ->
        editorView.removeEventListener eventName, handler

    marker = null
    lastBufferPosition = null

    disposables.add addEventListener editor, 'mousedown', (event) ->
      console.log("mousedown: #{editor.id}")
      # event.stopPropagation()
      marker?.destroy()
      marker = null
      lastBufferPosition = null
      atom.views.getView(editor).classList.remove('keyclick')

    disposables.add addEventListener editor, 'keyup', (event) ->
      console.log("keyup: #{editor.id}")
      marker?.destroy()
      marker = null
      lastBufferPosition = null
      atom.views.getView(editor).classList.remove('keyclick')

    disposables.add addEventListener editor, 'mousemove', (event) ->
      if event.altKey
        # console.log("mousemove: #{editor.id}")

        #getMousePositionAsBufferPosition
        editorView = atom.views.getView editor
        component = editorView.component
        screenPosition = component.screenPositionForMouseEvent({clientX: event.clientX, clientY: event.clientY})
        bufferPosition = editor.bufferPositionForScreenPosition(screenPosition)

        if lastBufferPosition != null && bufferPosition.compare(lastBufferPosition) == 0
          return
        lastBufferPosition = bufferPosition

        # Based on atom.workspace.getActiveTextEditor().getLastCursor().wordRegExp()
        wordRegExp = /^[	 ]*$|[^\s\/\\\(\)"',\.;<>~#\$%\^&\*\|\+=\[\]\{\}`\-…]+|[\/\\\(\)"',\.;<>~!#\$%\^&\*\|\+=\[\]\{\}`\?\-…]+/g

        textAndRange = getWordTextAndRange(editor, bufferPosition, wordRegExp)

        if marker != null && marker.getBufferRange().compare(textAndRange.range) == 0
          return

        marker?.destroy()

        if textAndRange.range == null
          editorView.classList.remove('keyclick')
          return

        editorView.classList.add('keyclick');
        marker = editor.markBufferRange(textAndRange.range, { invalidate: 'never' });
        editor.decorateMarker(marker, { type: 'highlight', 'class': 'keyclick' });

        console.log textAndRange.text

    editorDestroyedSubscription = editor.onDidDestroy =>
      editorDestroyedSubscription.dispose()
      disposables.dispose()

    @subscriptions.add(editorDestroyedSubscription)

getWordTextAndRange = (textEditor, position, wordRegExp) ->
  textAndRange = { text: '', range: new Range(position, position) }

  buffer = textEditor.getBuffer()
  buffer.scanInRange wordRegExp, buffer.rangeForRow(position.row), (data) ->
    if data.range.containsPoint(position)
      textAndRange = {
        text: data.matchText,
        range: data.range
      }
      data.stop()
    else if data.range.end.column > position.column
      # Stop the scan if the scanner has passed our position.
      data.stop()
  return textAndRange

# getSuggestionForWord: (textEditor, text, range) =>
#   if (textEditor.getGrammar().scopeName != 'source.elixir')
#     return
#
#   if (!text.match(/[a-zA-Z_]/) || text.match(/\:$/))
#     return
#
#   line = textEditor.getTextInRange([[range.start.row, 0], range.end])
#   regex = /[\w0-9\._!\?\:\@]+$/
#   matches = line.match(regex)
#   fullWord = (matches && matches[0]) || ''
#
#   if (['do', 'fn', 'end', 'false', 'true', 'nil'].indexOf(text) < 0)
#     return {
#       range: range,
#       callback: =>
#         @elixirProvider.gotoDeclaration(fullWord, textEditor, range.start)
#     }
