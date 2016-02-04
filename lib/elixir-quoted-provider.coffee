{CompositeDisposable} = require 'atom'
url = require 'url'

ElixirQuotedView = null # Defer until used

createElixirQuotedView = (state) ->
  ElixirQuotedView ?= require './elixir-quoted-view'
  new ElixirQuotedView(state)

atom.deserializers.add
  name: 'ElixirQuotedView'
  deserialize: (state) ->
    if state.quotedCode
      createElixirQuotedView(state)

module.exports =
class ElixirQuotedProvider
  server: null

  constructor: ->
    @subscriptions = new CompositeDisposable
    sourceElixirSelector = 'atom-text-editor:not(mini)[data-grammar^="source elixir"]'

    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:quote-selected-text', =>
      editor  = atom.workspace.getActiveTextEditor()
      text    = editor.getSelectedText().replace(/\s+$/, '')
      @showQuotedCodeView(text)

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
      if host is 'elixir-quoted-views'
        createElixirQuotedView(viewId: pathname.substring(1))

  dispose: ->
    @subscriptions.dispose()

  setServer: (server) ->
    @server = server

  getQuotedCode: (code, onResult) =>
    if code.trim() == ""
      onResult("")
      return

    @server.getQuotedCode code, (result) =>
      onResult(result)

  getMatches: (pattern, quotedCode, onResult) =>
    if pattern.trim() == "" || quotedCode.trim() == ""
      onResult("")
      return

    code = "(#{pattern}) = (#{quotedCode})"
    @server.match code, (result) =>
      onResult(result)

  showQuotedCodeView: (code) ->
    if code == ""
      @addView("", "")
      return
    @addView(code, "")

  addView: (code) ->
    options = {searchAllPanes: true, split: 'right'}
    uri = "atom-elixir://elixir-quoted-views/view"
    atom.workspace.open(uri, options).then (elixirQuotedView) =>
      elixirQuotedView.setMatchesGetter(@getMatches)
      elixirQuotedView.setQuotedCodeGetter(@getQuotedCode)
      elixirQuotedView.setCode(code)
