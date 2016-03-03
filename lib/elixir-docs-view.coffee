path = require 'path'
{markdownToHTML, getDocURL, splitModuleAndFunc} = require './utils'

{Emitter, Disposable, CompositeDisposable, File} = require 'atom'
{$, ScrollView} = require 'atom-space-pen-views'

module.exports =
class ElixirDocsView extends ScrollView
  @content: ->
    @div class: 'elixir-docs-view native-key-bindings', tabindex: -1, =>
      @div class: 'header', =>
        @div class: 'btn-group btn-group-sm viewButtons pull-left', style: 'margin-bottom: 8px;', =>
          @button class: "btn selected docs", 'Docs'
          @button class: "btn types", "Types"
          @button class: "btn callbacks", "Callbacks"
        @a class: 'link pull-right', style: 'margin-top: 14px;', 'See Online Docs'
        @hr style: 'clear: both;'
      @div class: 'markdownContent docsContent padded'
      @div class: 'markdownContent typesContent padded', style: 'display: none'
      @div class: 'markdownContent callbacksContent padded', style: 'display: none'

  constructor: ({@viewId, @source}) ->
    super
    @disposables = new CompositeDisposable

  attached: ->
    return if @isAttached
    @isAttached = true

    resolve = =>
      @handleEvents()
      @renderMarkdown()

    if atom.workspace?
      resolve()
    else
      @disposables.add atom.packages.onDidActivateInitialPackages(resolve)

  serialize: ->
    deserializer: 'ElixirDocsView'
    viewId: @viewId
    source: @source

  destroy: ->
    @disposables.dispose()

  handleEvents: ->
    atom.commands.add @element,
      'core:move-up': =>
        @scrollUp()
      'core:move-down': =>
        @scrollDown()
      'core:copy': (event) =>
        event.stopPropagation() if @copyToClipboard()

    unselectAllButtons = =>
      $(@element.querySelector('.viewButtons').children).removeClass('selected')

    renderDocs = @renderDocs
    renderTypes = @renderTypes
    renderCallbacks = @renderCallbacks

    getModFuncArity = =>
      [mod, func] = splitModuleAndFunc(@viewId)
      docSubject = @element.querySelector('.docsContent blockquote p').innerText
      [docMod, docFunc] = splitModuleAndFunc(docSubject.replace(/\(.*\)/, ''))
      if mod != docMod
        mod = docMod
      if func?
        arity = docSubject.split(',').length
      [mod, func, arity]

    @on 'click', ".docs", ->
      unselectAllButtons()
      $(this).addClass('selected')
      renderDocs()
    @on 'click', ".types", ->
      unselectAllButtons()
      $(this).addClass('selected')
      renderTypes()
    @on 'click', ".callbacks", ->
      unselectAllButtons()
      $(this).addClass('selected')
      renderCallbacks()
    @on 'click', ".header .link", ->
      [mod, func, arity] = getModFuncArity()
      require('shell').openExternal(getDocURL(mod, func, arity))

    @disposables.add @addEventHandler(@element, 'keyup', @keyupHandler)

  keyupHandler: (event) =>
    if event.keyCode in [37, 39]
      selectedBtn = @element.querySelector('.viewButtons .selected')
      allBtns = @element.querySelectorAll('.viewButtons .btn')
      allBtnsArray = Array.prototype.slice.call(allBtns)
      index = allBtnsArray.indexOf(selectedBtn)
      if event.keyCode == 37 # left
        $(allBtnsArray[Math.max(0, index-1)]).click()
      else if event.keyCode == 39 #right
        $(allBtnsArray[Math.min(allBtnsArray.length-1, index+1)]).click()

  addEventHandler: (element, eventName, handler) ->
    element.addEventListener eventName, handler
    new Disposable ->
      element.removeEventListener eventName, handler

  setSource: (source) ->
    @source = source
    [@docs, @types, @callbacks] = @source.split('\u000B')

    if @types
      @types = "> Types\n\n____\n\n#{@types}"
    else
      @types ="No type information available."

    @callbacks ||= "No callback information available."

    @element.querySelector('.docsContent').innerHTML = markdownToHTML(@docs)
    @element.querySelector('.typesContent').innerHTML = markdownToHTML(@types)
    @element.querySelector('.callbacksContent').innerHTML = markdownToHTML(@callbacks)

    @renderMarkdown()

  renderMarkdown: =>
    return unless @source?
    @renderDocs()

  renderDocs: =>
    $(@element.querySelectorAll('.markdownContent')).css('display', 'none')
    @element.querySelector('.docsContent').style.display = ''

  renderTypes: =>
    $(@element.querySelectorAll('.markdownContent')).css('display', 'none')
    @element.querySelector('.typesContent').style.display = ''

  renderCallbacks: =>
    $(@element.querySelectorAll('.markdownContent')).css('display', 'none')
    @element.querySelector('.callbacksContent').style.display = ''

  getTitle: ->
    "Elixir Docs - #{@viewId}"

  getIconName: ->
    "file-text"

  getURI: ->
    "atom-elixir://elixir-docs-views/#{@viewId}"

  copyToClipboard: ->
    selection = window.getSelection()
    selectedText = selection.toString()
    atom.clipboard.write(selectedText)
    true
