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
      @showQuotedCode()

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

  showQuotedCode: ->
    editor  = atom.workspace.getActiveTextEditor()
    text    = editor.getSelectedText()
    if text == ""
      @addView("", "")
      return

    tmpFile = @createTempFile(text)
    @server.getQuotedCode tmpFile, (result) =>
      fs.unlink(tmpFile)
      @addView(text, result)
      console.log result

  addView: (code, quotedCode) ->
    options = {searchAllPanes: true, split: 'right'}
    uri = "atom-elixir://elixir-quoted-views/view"
    atom.workspace.open(uri, options).then (elixirQuotedView) =>
      elixirQuotedView.setCode(code)
      elixirQuotedView.setQuotedCode(quotedCode)

  #TODO: Duplicated
  createTempFile: (content) ->
    tmpFile = os.tmpdir() + Math.random().toString(36).substr(2, 9)
    fs.writeFileSync(tmpFile, content)
    tmpFile
