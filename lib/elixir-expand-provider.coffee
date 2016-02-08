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
      editor  = atom.workspace.getActiveTextEditor()
      text    = editor.getSelectedText().replace(/\s+$/, '')
      @showExpandCodeView(text)

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

  getExpandOnce: (code, onResult) =>
    if code.trim() == ""
      onResult("")
      return

    @server.expandOnce code, (result) =>
      onResult(result)

  getExpand: (code, onResult) =>
    if code.trim() == ""
      onResult("")
      return

    @server.expand code, (result) =>
      onResult(result)

  showExpandCodeView: (code) ->
    if code == ""
      @addView("", "")
      return
    @addView(code, "")

  addView: (code) ->
    options = {searchAllPanes: true, split: 'right'}
    uri = "atom-elixir://elixir-expand-views/view"
    atom.workspace.open(uri, options).then (elixirExpandView) =>
      elixirExpandView.setExpandOnceGetter(@getExpandOnce)
      elixirExpandView.setExpandGetter(@getExpand)
      elixirExpandView.setCode(code)
