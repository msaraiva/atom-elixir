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
  server: null

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

  setServer: (server) ->
    @server = server

  showElixirDocs: ->
    editor = atom.workspace.getActiveTextEditor()
    position = editor.getCursorBufferPosition()
    subjectAndMarkerRange = getSubjectAndMarkerRange(editor, position)
    subject = ''
    if subjectAndMarkerRange != null
      subject = subjectAndMarkerRange.subject

    if !subject.match(/^:/)
      @addViewForElement(subject)

  uriForElement: (word) ->
    "atom-elixir://elixir-docs-views/#{word}"

  addViewForElement: (word) ->
    editor   = atom.workspace.getActiveTextEditor()
    line       = editor.getCursorBufferPosition().row + 1
    bufferText = editor.buffer.getText()

    @server.getDocumentation word, bufferText, line, (result) =>
      return if result == ""
      uri = @uriForElement(word)

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

        # elixirDocsView.html(@markdownToHTML(result))
        elixirDocsView.setSource(result)
