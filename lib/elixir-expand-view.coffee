path = require 'path'

{Emitter, Disposable, CompositeDisposable, File} = require 'atom'
{$, ScrollView} = require 'atom-space-pen-views'

module.exports =
class ElixirExpandedView extends ScrollView
  @content: ->

    createEditor = =>
      element = document.createElement('atom-text-editor')
      element.setAttribute('tabIndex', 0)
      editor = element.getModel()
      editor.setLineNumberGutterVisible(true)
      editor.setGrammar(atom.grammars.grammarForScopeName('source.elixir'))
      element

    expandOnceCodeEditorElement = createEditor()
    expandOnceCodeEditorElement.setAttribute('mini', true)
    expandOnceCodeEditorElement.removeAttribute('tabindex')

    expandCodeEditorElement = createEditor()
    expandCodeEditorElement.setAttribute('mini', true)
    expandCodeEditorElement.removeAttribute('tabindex')

    expandPartialCodeEditorElement = createEditor()
    expandPartialCodeEditorElement.setAttribute('mini', true)
    expandPartialCodeEditorElement.removeAttribute('tabindex')

    expandAllCodeEditorElement = createEditor()
    expandAllCodeEditorElement.setAttribute('mini', true)
    expandAllCodeEditorElement.removeAttribute('tabindex')

    @div class: 'elixir-expand-view native-key-bindings', tabindex: -1, =>
      @div class: 'header', =>
        @div class: 'btn-group btn-group-sm viewButtons pull-left', style: 'margin-bottom: 8px;', =>
          @button class: "btn expandOnce", 'Expand Once'
          @button class: "btn expand", "Expand"
          @button class: "btn expandPartial selected", "Expand Partial"
          @button class: "btn expandAll", "Expand All"
        @hr style: 'clear: both;'
      @div class: 'markdownContent expandOnceContent', style: 'display: none', =>
        @section class: 'input-block', =>
          @subview 'expandOnceCodeEditorElement', expandOnceCodeEditorElement
      @div class: 'markdownContent expandContent', style: 'display: none', =>
        @section class: 'input-block', =>
          @subview 'expandCodeEditorElement', expandCodeEditorElement
      @div class: 'markdownContent expandPartialContent', =>
        @section class: 'input-block', =>
          @subview 'expandPartialCodeEditorElement', expandPartialCodeEditorElement
      @div class: 'markdownContent expandAllContent', style: 'display: none', =>
        @section class: 'input-block', =>
          @subview 'expandAllCodeEditorElement', expandAllCodeEditorElement

  constructor: ({@buffer, @code, @line}) ->
    super
    @disposables = new CompositeDisposable

  initialize: ->
    @expandOnceCodeEditor = @expandOnceCodeEditorElement.getModel()
    @expandOnceCodeEditor.setSoftWrapped(true)
    @expandOnceCodeEditor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()

    @expandCodeEditor = @expandCodeEditorElement.getModel()
    @expandCodeEditor.setSoftWrapped(true)
    @expandCodeEditor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()

    @expandPartialCodeEditor = @expandPartialCodeEditorElement.getModel()
    @expandPartialCodeEditor.setSoftWrapped(true)
    @expandPartialCodeEditor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()

    @expandAllCodeEditor = @expandAllCodeEditorElement.getModel()
    @expandAllCodeEditor.setSoftWrapped(true)
    @expandAllCodeEditor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()

  attached: ->
    return if @isAttached
    @isAttached = true

    resolve = =>
      @refreshView()
      @handleEvents()

    if atom.workspace?
      resolve()
    else
      @disposables.add atom.packages.onDidActivateInitialPackages(resolve)

  serialize: ->
    deserializer: 'ElixirExpandView'
    source: @code

  destroy: ->
    @disposables.dispose()

  handleEvents: ->

    unselectAllButtons = =>
      $(@element.querySelector('.viewButtons').children).removeClass('selected')

    renderExpandOnce = @renderExpandOnce
    renderExpand = @renderExpand
    renderExpandPartial = @renderExpandPartial
    renderExpandAll = @renderExpandAll

    @on 'click', ".expandOnce", ->
      unselectAllButtons()
      $(this).addClass('selected')
      renderExpandOnce()
    @on 'click', ".expand", ->
      unselectAllButtons()
      $(this).addClass('selected')
      renderExpand()
    @on 'click', ".expandPartial", ->
      unselectAllButtons()
      $(this).addClass('selected')
      renderExpandPartial()
    @on 'click', ".expandAll", ->
      unselectAllButtons()
      $(this).addClass('selected')
      renderExpandAll()

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

  renderExpandOnce: =>
    $(@element.querySelectorAll('.markdownContent')).css('display', 'none')
    @element.querySelector('.expandOnceContent').style.display = ''

  renderExpand: =>
    $(@element.querySelectorAll('.markdownContent')).css('display', 'none')
    @element.querySelector('.expandContent').style.display = ''

  renderExpandPartial: =>
    $(@element.querySelectorAll('.markdownContent')).css('display', 'none')
    @element.querySelector('.expandPartialContent').style.display = ''

  renderExpandAll: =>
    $(@element.querySelectorAll('.markdownContent')).css('display', 'none')
    @element.querySelector('.expandAllContent').style.display = ''

  setExpandFullGetter: (getter) ->
    @expandFullGetter = getter

  setExpandOnceCode:(code) ->
    @expandOnceCode = code
    @expandOnceCodeEditor.setText(@expandOnceCode)

  setExpandCode:(code) ->
    @expandCode = code
    @expandCodeEditor.setText(@expandCode)

  setExpandPartialCode:(code) ->
    @expandPartialCode = code
    @expandPartialCodeEditor.setText(@expandPartialCode)

  setExpandAllCode:(code) ->
    @expandAllCode = code
    @expandAllCodeEditor.setText(@expandAllCode)

  setBuffer:(buffer) ->
    @buffer = buffer

  setLine:(line) ->
    @line = line

  setCode:(code) ->
    @code = code
    @expandFullGetter @buffer, @code, @line, (result) =>
      [expandedOnce, expanded, expandedPartial, expandedAll] = result.split('\u000B')
      @setExpandOnceCode(expandedOnce?.trim() || "")
      @setExpandCode(expanded?.trim() || "")
      @setExpandPartialCode(expandedPartial?.trim() || "")
      @setExpandAllCode(expandedAll?.trim() || "")
      @refreshView()

  refreshView: ->
    if @expandOnceCode?
      @expandOnceCodeEditor.setText(@expandOnceCode)
    if @expandCode?
      @expandCodeEditor.setText(@expandCode)
    if @expandPartialCode?
      @expandPartialCodeEditor.setText(@expandPartialCode)
    if @expandAllCode?
      @expandAllCodeEditor.setText(@expandAllCode)

  getTitle: ->
    "Expand Macro"

  getIconName: ->
    "file-text"

  getURI: ->
    "atom-elixir://elixir-expand-views/view"
