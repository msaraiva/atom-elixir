{CompositeDisposable} = require 'atom'
os = require('os')
fs = require('fs')

module.exports =
class ElixirExpandProvider
  server: null

  constructor: ->
    @subscriptions = new CompositeDisposable
    sourceElixirSelector = 'atom-text-editor:not(mini)[data-grammar^="source elixir"]'

    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:expand-selected-text', =>
      @expand()
    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:expand-once-selected-text', =>
      @expandOnce()

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

  createTempFile: (content) ->
    tmpFile = os.tmpdir() + Math.random().toString(36).substr(2, 9)
    fs.writeFileSync(tmpFile, content)
    tmpFile
