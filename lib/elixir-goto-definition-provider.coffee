{Disposable, CompositeDisposable, Range} = require 'atom'
KeyClickEventHandler = require './keyclick-event-handler'
os = require('os')
fs = require('fs')

module.exports =
class ElixirGotoDefinitionProvider
  # wordRegExp is based on atom.workspace.getActiveTextEditor().getLastCursor().wordRegExp()
  wordRegExp: /^[	 ]*$|[^\s\/\\\(\)"',\.;<>~#\$%\^&\*\|\+=\[\]\{\}`\-…]+|[\/\\\(\)"',\.;<>~!#\$%\^&\*\|\+=\[\]\{\}`\?\-…]+/g

  constructor: ->
    @subscriptions = new CompositeDisposable
    @gotoStack = []
    sourceElixirSelector = 'atom-text-editor:not(mini)[data-grammar^="source elixir"]'

    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:goto-declaration', =>
      editor = atom.workspace.getActiveTextEditor()
      position = editor.getCursorBufferPosition()
      subjectAndMarkerRange = @getSubjectAndMarkerRange(editor, position)
      if subjectAndMarkerRange != null
        @gotoDeclaration(editor, subjectAndMarkerRange.subject, position)

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
      keyClickEventHandler = new KeyClickEventHandler(editor, @getSubjectAndMarkerRange, @keyClickHandler)

      editorDestroyedSubscription = editor.onDidDestroy =>
        console.log("editorDestroyedSubscription: #{editor.id}")
        editorDestroyedSubscription.dispose()
        keyClickEventHandler.dispose()

      @subscriptions.add(editorDestroyedSubscription)

  dispose: ->
    @subscriptions.dispose()

  setServer: (server) ->
    @server = server

  getSubjectAndMarkerRange: (editor, bufferPosition) =>
    wordAndRange = getWordAndRange(editor, bufferPosition, @wordRegExp)
    word = wordAndRange.word
    range = wordAndRange.range

    if (editor.getGrammar().scopeName != 'source.elixir')
      return null

    if (!word.match(/[a-zA-Z_]/) || word.match(/\:$/))
      return null

    line = editor.getTextInRange([[range.start.row, 0], range.end])
    regex = /[\w0-9\._!\?\:\@]+$/
    matches = line.match(regex)
    subject = (matches && matches[0]) || ''

    if (['do', 'fn', 'end', 'false', 'true', 'nil'].indexOf(word) > -1)
      return null

    return {subject: subject, range: range}

  keyClickHandler: (editor, subject, position) =>
    @gotoDeclaration(editor, subject, position)

  gotoDeclaration: (editor, subject, position) ->
    filePath = editor.getPath()
    line     = position.row + 1
    tmpFile  = @createTempFile(editor.buffer.getText())

    @gotoStack.push([editor.getPath(), position])
    @server.getFileDeclaration subject, filePath, tmpFile, line, (file) ->

      switch file
        when 'non_existing'
          # atom.notifications.addInfo("Can't find <b>#{subject}</b>");
          console.log "Can't find \"#{subject}\""
          return
        when 'preloaded'
          # atom.notifications.addInfo("Module <b>#{subject}</b> is preloaded");
          console.log "Module \"#{subject}\" is preloaded"
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

getWordAndRange = (editor, position, wordRegExp) ->
  wordAndRange = { word: '', range: new Range(position, position) }

  buffer = editor.getBuffer()
  buffer.scanInRange wordRegExp, buffer.rangeForRow(position.row), (data) ->
    if data.range.containsPoint(position)
      wordAndRange = {
        word: data.matchText,
        range: data.range
      }
      data.stop()
    else if data.range.end.column > position.column
      # Stop the scan if the scanner has passed our position.
      data.stop()
  return wordAndRange
