{CompositeDisposable} = require 'atom'
os = require('os')
fs = require('fs')

module.exports =
class ElixirProvider
  server: null

  constructor: ->
    @subscriptions = new CompositeDisposable
    sourceElixirSelector = 'atom-text-editor:not(mini)[data-grammar^="source elixir"]'

    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:expand-selected-text', =>
      @expand()
    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:expand-once-selected-text', =>
      @expandOnce()

    @gotoStack = []
    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:goto-declaration', =>
      editor = atom.workspace.getActiveTextEditor()
      word = editor.getWordUnderCursor({wordRegex: /[\w0-9\._!\?\:]+/})
      position = editor.getCursorBufferPosition()
      @gotoDeclaration(word, editor, position)

    @subscriptions.add atom.commands.add 'atom-text-editor:not(mini)', 'atom-elixir:return-from-declaration', =>
      previousPosition = @gotoStack.pop()
      return unless previousPosition?
      [file, position] = previousPosition
      atom.workspace.open(file, {searchAllPanes: true}).then (editor) ->
        return unless position?
        editor.setCursorBufferPosition(position)
        editor.scrollToScreenPosition(position, {center: true})

  dispose: ->
    @subscriptions.dispose()

  setServer: (server) ->
    @server = server

  expand: ->
    editor  = atom.workspace.getActiveTextEditor()
    text    = editor.getSelectedText()
    tmpFile = @createTempFile(text)

    @server.expand tmpFile, (result) ->
      fs.unlink(tmpFile)
      console.log result

  expandOnce: ->
    editor  = atom.workspace.getActiveTextEditor()
    text    = editor.getSelectedText()
    tmpFile = @createTempFile(text)

    @server.expandOnce tmpFile, (result) ->
      fs.unlink(tmpFile)
      console.log result

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

  createTempFile: (content) ->
    tmpFile = os.tmpdir() + Math.random().toString(36).substr(2, 9)
    fs.writeFileSync(tmpFile, content)
    tmpFile
