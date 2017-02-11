class ElixirSignatureView extends HTMLElement

  createdCallback: ->
    @getModel()
    @addEventListener('click', =>
      @getModel().destroyOverlay()
    , false)
    @container = document.createElement('div')
    @appendChild(@container)

  initialize: (model) ->
    @setModel(model)
    this

  getModel: ->
    @model

  setModel: (model) ->
    @model = model

  setData: (data) ->
    @container.innerHTML = data.label

  destroy: ->
    @remove()

module.exports = document.registerElement('elixir-signature-view', prototype: ElixirSignatureView.prototype)
