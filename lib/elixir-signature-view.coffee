{markdownToHTML, convertCodeBlocksToAtomEditors} = require './utils'

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
    paramPosition = data.active_param
    pipeBefore = data.pipe_before
    signatures = data.signatures.filter (sig) ->
      sig.params.length > paramPosition

    signatureElements = @container.querySelectorAll('.signature')

    # Create signature elements
    signatures.forEach (sig, i) =>
      if i < signatureElements.length
        return
      signature_element = document.createElement("div")
      @container.appendChild(signature_element)
      signature_element.outerHTML = "<div class=\"signature\">
        <div class=\"signature-func\"></div>
        <div class=\"signature-spec\"><pre><code></code></pre></div>
        <div class=\"signature-doc\"></div>
      </div>"

    # Remove unsused signature elements
    for i in [signatures.length..signatureElements.length-1] by 1
      signatureElements[i].remove()

    convertCodeBlocksToAtomEditors(@container)

    signatureElements = @container.querySelectorAll('.signature')

    # Update signature elements
    signatureElements.forEach (e, i) =>
      sig = signatures[i]
      params = sig.params.map (param, i) ->
        if pipeBefore && i == 0
          "<span class=\"pipe-subject-param\">#{param}</span>"
        else if i == paramPosition
          "<span class=\"current-param\">#{param}</span>"
        else
          "<span class=\"param\">#{param}</span>"

      e.children[0].innerHTML = "<span class=\"func-name\">#{sig.name}</span>(#{params.join(', ')})"

      specElement = e.querySelector('.signature-spec > atom-text-editor')
      if sig.spec == ""
        specElement.style.display = 'none'
      else
        specElement.style.display = 'block'
        specElement.getModel().setText(sig.spec)

      docElement = e.querySelector('.signature-doc')
      if sig.documentation == ""
        docElement.style.display = 'none'
      else
        docElement.style.display = 'block'
        docElement.innerHTML = markdownToHTML(' _ ' + sig.documentation + ' _ ')

  destroy: ->
    @remove()

module.exports = document.registerElement('elixir-signature-view', prototype: ElixirSignatureView.prototype)
