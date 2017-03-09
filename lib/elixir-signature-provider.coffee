ElixirSignatureView = require './elixir-signature-view'

module.exports =
class ElixirSignatureProvider

  view: null
  overlayDecoration: null
  marker: null
  lastResult: null
  timeout: null
  show: false

  constructor: () ->
    @view = new ElixirSignatureView()
    @view.initialize(this)

    atom.views.getView(atom.workspace).appendChild(@view)

  setPosition: ->
    if !@marker
      editor = atom.workspace.getActiveTextEditor()
      return unless editor
      @marker = editor.getLastCursor?().getMarker()
      return unless @marker
      @overlayDecoration = editor.decorateMarker(@marker, {type: 'overlay', item: @view, class: 'elixir-signature-view', position: 'tale', invalidate: 'touch'})
    else
      @marker.setProperties({type: 'overlay', item: @view, class: 'elixir-signature-view', position: 'tale', invalidate: 'touch'})

  destroyOverlay: ->
    @overlayDecoration?.destroy()
    @overlayDecoration = null
    @marker = null

  updateSignatures: (editor, cursor, fromAction) ->
    return if !@show || cursor.destroyed

    buffer = editor.getBuffer()
    bufferPosition = editor.getCursorBufferPosition()
    line = bufferPosition.row + 1
    col = bufferPosition.column + 1

    scopeDescriptor = cursor.getScopeDescriptor()
    if scopeDescriptor.scopes.join().match(/comment/)
      @destroyOverlay()
      return

    editorElement = atom.views.getView(editor)
    if 'autocomplete-active' in editorElement.classList
      return

    @querySignatures(buffer.getText(), line, col)

  querySignatures: (buffer, line, col) ->
    if !@client
      @show = false
      console.log("ElixirSense client not ready")
      return

    @client.send "signature", {buffer: buffer, line: line, column: col}, (result) =>
      @destroyOverlay()
      if result == 'none'
        @show = false
        return
      @view.setData(result)
      @setPosition()

  destroy: ->
    @destroyOverlay()
    @view?.destroy()
    @view = null

  setClient: (client) ->
    @client = client

  showSignature: (editor, cursor, fromAction) ->
    if @timeout != null
      clearTimeout(@timeout)
      @timeout = null

    if fromAction
      @show = true

    @timeout = setTimeout =>
      @updateSignatures(editor, cursor, fromAction)
    , 50

  closeSignature: ->
    @show = false
    @destroyOverlay()

  hideSignature: ->
    @destroyOverlay()
