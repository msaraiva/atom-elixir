{CompositeDisposable} = require 'atom'
url = require 'url'

ElixirExpandView = null # Defer until used

createElixirExpandView = (state) ->
  ElixirExpandView ?= require './elixir-expand-view'
  new ElixirExpandView(state)

atom.deserializers.add
  name: 'ElixirExpandView'
  deserialize: (state) ->
    if state.expandCode
      createElixirExpandView(state)

module.exports =
class ElixirExpandProvider
  server: null

  constructor: ->
    @subscriptions = new CompositeDisposable
    sourceElixirSelector = 'atom-text-editor:not(mini)[data-grammar^="source elixir"]'

    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:expand-selected-text', =>
      editor = atom.workspace.getActiveTextEditor()
      buffer = editor.getText()
      text   = editor.getSelectedText().replace(/\s+$/, '')
      line   = editor.getSelectedBufferRange().start.row + 1
      @showExpandCodeView(buffer, text, line)

    atom.workspace.addOpener (uriToOpen) ->
      try
        {protocol, host, pathname} = url.parse(uriToOpen)
      catch error
        return
      return unless protocol is 'atom-elixir:'
      try
        pathname = decodeURI(pathname) if pathname
      catch error
        return
      if host is 'elixir-expand-views'
        createElixirExpandView(viewId: pathname.substring(1))

  dispose: ->
    @subscriptions.dispose()

  setServer: (server) ->
    @server = server

  getExpandFull: (buffer, selectedCode, line, onResult) =>
    if selectedCode.trim() == ""
      onResult("")
      return

    @server.expandFull buffer, selectedCode, line, (result) =>
      onResult(result)

  showExpandCodeView: (buffer, code, line) ->
    if code == ""
      @addView("", "", "")
      return
    @addView(buffer, code, line)

  addView: (buffer, code, line) ->
    options = {searchAllPanes: true, split: 'right'}
    uri = "atom-elixir://elixir-expand-views/view"
    atom.workspace.open(uri, options).then (elixirExpandView) =>
      elixirExpandView.setExpandFullGetter(@getExpandFull)
      elixirExpandView.setBuffer(buffer)
      elixirExpandView.setLine(line)
      elixirExpandView.setCode(code)
