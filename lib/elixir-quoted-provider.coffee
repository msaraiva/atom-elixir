{CompositeDisposable} = require 'atom'
url = require 'url'

#TODO: Duplicated
os = require('os')
fs = require('fs')

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
      text    = editor.getSelectedText()
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
    tmpFile = @createTempFile(code)
    @server.getQuotedCode tmpFile, (result) =>
      fs.unlink(tmpFile)
      console.log result
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
      elixirQuotedView.setQuotedCodeGetter(@getQuotedCode)
      elixirQuotedView.setCode(code)

  #TODO: Duplicated
  createTempFile: (content) ->
    tmpFile = os.tmpdir() + Math.random().toString(36).substr(2, 9)
    fs.writeFileSync(tmpFile, content)
    tmpFile
