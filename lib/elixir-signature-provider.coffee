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

  queryType: (editor, cursor) ->
    return if !@show

    if @timeout != null
      clearTimeout(@timeout)
      @timeout = null

    return if cursor.destroyed

    scopeDescriptor = cursor.getScopeDescriptor()
    if scopeDescriptor.scopes.join().match(/comment/)
      @destroyOverlay()
      return

    position = cursor.getBufferPosition()
    lineCount = editor.getLineCount()

    buffer = editor.getBuffer()
    paramPosition = 0

    bufferPosition = editor.getCursorBufferPosition()
    line = bufferPosition.row + 1
    col = bufferPosition.column + 1
    @timeout = setTimeout =>
      if !@client
        @show = false
        console.log("ElixirSense client not ready")
        return

      @client.write {request: "signature", payload: {buffer: buffer.getText(), line: line, column: col}}, (result) =>
        @destroyOverlay()
        if result == 'none'
          @show = false
          return

        @view.setData(result)
        @setPosition()
        @timeout = null
    , 20

  destroy: ->
    @destroyOverlay()
    @view?.destroy()
    @view = null

  setClient: (client) ->
    @client = client

  showSignature: (editor, cursor)->
    @show = true
    @queryType(editor, cursor)

  hideSignature: ->
    @show = false
    @destroyOverlay()
