ElixirSignatureView = require './elixir-signature-view'

module.exports =
class ElixirSignatureProvider

  view: null
  overlayDecoration: null
  marker: null
  server: null
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
    # textBeforeCursor = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
    textBeforeCursor = editor.getTextInRange([[0, 0], bufferPosition])
    line = bufferPosition.row + 1
    @timeout = setTimeout =>
      @server.signatureInfo buffer.getText(), textBeforeCursor, line, (result) =>
        @destroyOverlay()
        if result == 'none'
          @show = false
          return

        [paramPosition, signatures...] = result.trim().split("\n")

        signatures = signatures.map (sig) ->
          [func_name, params_str] = sig.split(';')
          params = params_str.split(',')
          {name: func_name, params: params}

        signatures = signatures.filter (sig) ->
          sig.params.length > paramPosition

        signatures = signatures.map (sig, i) ->
          params = sig.params.map (param, i) ->
            if "#{i}" == paramPosition
              "<span class=\"current-param\">#{param}</span>"
            else
              param
          "#{sig.name}(#{params.join(', ')})"

        @view.setData({label: signatures.join('<br>')})
        @setPosition()
        @timeout = null
    , 20

  destroy: ->
    @destroyOverlay()
    @view?.destroy()
    @view = null

  setServer: (server) ->
    @server = server

  showSignature: (editor, cursor)->
    @show = true
    @queryType(editor, cursor)

  hideSignature: ->
    @show = false
    @destroyOverlay()
