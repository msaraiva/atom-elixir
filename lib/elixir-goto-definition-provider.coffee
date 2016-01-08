{Disposable, CompositeDisposable, Range} = require 'atom'
KeyClickEventHandler = require './keyclick-event-handler'
os = require('os')
fs = require('fs')

module.exports =
class ElixirGotoDefinitionProvider

  constructor: ->
    @subscriptions = new CompositeDisposable
    @gotoStack = []
    sourceElixirSelector = 'atom-text-editor:not(mini)[data-grammar^="source elixir"]'

    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:goto-declaration', =>
      editor = atom.workspace.getActiveTextEditor()
      word = editor.getWordUnderCursor({wordRegex: /[\w0-9\._!\?\:]+/})
      position = editor.getCursorBufferPosition()
      # TODO
      # wordTextAndRange = getWordTextAndRange(editor, position, wordRegExp)
      # @gotoDeclaration(wordTextAndRange.text, editor, wordTextAndRange.range.start)
      @gotoDeclaration(word, editor, position)

    @subscriptions.add atom.commands.add 'atom-text-editor:not(mini)', 'atom-elixir:return-from-declaration', =>
      previousPosition = @gotoStack.pop()
      return unless previousPosition?
      [file, position] = previousPosition
      atom.workspace.open(file, {searchAllPanes: true}).then (editor) ->
        return unless position?
        editor.setCursorBufferPosition(position)
        editor.scrollToScreenPosition(position, {center: true})

    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      if (editor.getGrammar().scopeName != 'source.elixir')
        return
      keyClickEventHandler = new KeyClickEventHandler(editor, @keyClickGetFullWordAndMarkRangeHandler, @keyClickHandler)

      editorDestroyedSubscription = editor.onDidDestroy =>
        console.log("editorDestroyedSubscription: #{editor.id}")
        editorDestroyedSubscription.dispose()
        keyClickEventHandler.dispose()

      @subscriptions.add(editorDestroyedSubscription)

  dispose: ->
    @subscriptions.dispose()

  setServer: (server) ->
    @server = server

  keyClickGetFullWordAndMarkRangeHandler: (editor, bufferPosition, wordRegExp) =>
    textAndRange = getWordTextAndRange(editor, bufferPosition, wordRegExp)
    text = textAndRange.text
    range = textAndRange.range

    if (editor.getGrammar().scopeName != 'source.elixir')
      return null

    if (!text.match(/[a-zA-Z_]/) || text.match(/\:$/))
      return null

    line = editor.getTextInRange([[range.start.row, 0], range.end])
    regex = /[\w0-9\._!\?\:\@]+$/
    matches = line.match(regex)
    fullWord = (matches && matches[0]) || ''

    if (['do', 'fn', 'end', 'false', 'true', 'nil'].indexOf(text) > -1)
      return null

    return {text: fullWord, range: range}

  keyClickHandler: (editor, fullWord, range) =>
    @gotoDeclaration(fullWord, editor, range.start)

  gotoDeclaration: (word, editor, position) ->
    filePath = editor.getPath()
    line     = position.row + 1
    tmpFile  = @createTempFile(editor.buffer.getText())

    @gotoStack.push([editor.getPath(), position])
    @server.getFileDeclaration word, filePath, tmpFile, line, (file) ->

      switch file
        when 'non_existing'
          # atom.notifications.addInfo("Can't find <b>#{word}</b>");
          console.log "Can't find \"#{word}\""
          return
        when 'preloaded'
          # atom.notifications.addInfo("Module <b>#{word}</b> is preloaded");
          console.log "Module \"#{word}\" is preloaded"
          return
        when ''
          return

      pane = atom.workspace.getActivePane()
      [file_path, line] = file.split(':')
      atom.workspace.open(file_path, {initialLine: parseInt(line-1 || 0), searchAllPanes: true}).then (editor) ->
        pane.activateItem(editor)
        editor.scrollToScreenPosition(editor.getCursorBufferPosition(), {center: true})

  #TODO: duplicated
  createTempFile: (content) ->
    tmpFile = os.tmpdir() + Math.random().toString(36).substr(2, 9)
    fs.writeFileSync(tmpFile, content)
    tmpFile

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
