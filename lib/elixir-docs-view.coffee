path = require 'path'
{markdownToHTML} = require './utils'

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
      @div class: 'markdownContent padded'

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

  setSource: (source) ->
    @source = source
    [@docs, @types, @callbacks] = @source.split('\u000B')

    if @types
      @types = "> Types\n\n____\n\n#{@types}"
    else
      @types ="No type information available."

    @callbacks ||= "No callback information available."

    @renderMarkdown()

  renderMarkdown: =>
    return unless @source?
    @renderDocs()

  renderDocs: =>
    @element.querySelector('.markdownContent').innerHTML = markdownToHTML(@docs)

  renderTypes: =>
    @element.querySelector('.markdownContent').innerHTML = markdownToHTML(@types)

  renderCallbacks: =>
    @element.querySelector('.markdownContent').innerHTML = markdownToHTML(@callbacks)

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
