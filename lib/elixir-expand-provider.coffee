{CompositeDisposable} = require 'atom'

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
    code    = editor.getSelectedText()
    @server.expand code, (result) ->
      console.log result

  expandOnce: ->
    editor  = atom.workspace.getActiveTextEditor()
    code    = editor.getSelectedText()
    @server.expandOnce code, (result) ->
      console.log result
