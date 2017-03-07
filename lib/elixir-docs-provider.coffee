{CompositeDisposable} = require 'atom'
{getSubjectAndMarkerRange} = require './editor-utils'
url = require 'url'

ElixirDocsView = null # Defer until used

createElixirDocsView = (state) ->
  ElixirDocsView ?= require './elixir-docs-view'
  new ElixirDocsView(state)

atom.deserializers.add
  name: 'ElixirDocsView'
  deserialize: (state) ->
    if state.viewId
      createElixirDocsView(state)

module.exports =
class ElixirDocsProvider

  constructor: ->
    @subscriptions = new CompositeDisposable
    sourceElixirSelector = 'atom-text-editor:not(mini)[data-grammar^="source elixir"]'
    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:show-elixir-docs', =>
      @showElixirDocs()

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
      if host is 'elixir-docs-views'
        createElixirDocsView(viewId: pathname.substring(1))

  dispose: ->
    @subscriptions.dispose()

  setClient: (client) ->
    @client = client

  showElixirDocs: ->
    @addViewForElement()

  uriForElement: (word) ->
    "atom-elixir://elixir-docs-views/#{word}"

  addViewForElement: (word) ->
    editor = atom.workspace.getActiveTextEditor()
    bufferText = editor.buffer.getText()
    position = editor.getCursorBufferPosition()
    line = position.row + 1
    col = position.column + 1

    if !@client
      console.log("ElixirSense client not ready")
      return

    @client.send "docs", {buffer: bufferText, line: line, column: col}, (result) =>
      {actual_subject, docs} = result

      return if !docs

      uri = @uriForElement(actual_subject)
      options = {searchAllPanes: true, split: 'right'}
      # TODO: Create this configuration
      # options = {searchAllPanes: true}
      # if atom.config.get('atom-elixir.elixirDocs.openViewInSplitPane')
        # options.split = 'right'

      # previousActivePane = atom.workspace.getActivePane()
      atom.workspace.open(uri, options).then (elixirDocsView) =>
        # TODO: We could use a configuration to tell if the focus should remain on the editor
        # if atom.config.get('atom-elixir.elixirDocs.keepFocusOnEditorAfterOpenDocs')
        #   previousActivePane.activate()

        elixirDocsView.setSource(docs)
