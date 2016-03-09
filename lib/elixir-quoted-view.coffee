path = require 'path'

{Emitter, Disposable, CompositeDisposable, File} = require 'atom'
{ScrollView} = require 'atom-space-pen-views'

module.exports =
class ElixirQuotedView extends ScrollView
  @content: =>

    createEditor = ->
      element = document.createElement('atom-text-editor')
      element.setAttribute('tabIndex', 0)
      editor = element.getModel()
      editor.setLineNumberGutterVisible(true)
      editor.setGrammar(atom.grammars.grammarForScopeName('source.elixir'))
      atom.commands.add element,
        'core:move-up': =>
          editor.moveUp()
        'core:move-down': =>
          editor.moveDown()
        'editor:newline': =>
          editor.insertText('\n')
        'core:move-to-top': =>
          editor.moveToTop()
        'core:move-to-bottom': =>
          editor.moveToBottom()
        'core:select-to-top': =>
          editor.selectToTop()
        'core:select-to-bottom': =>
          editor.selectToBottom()
      element

    codeEditorElement = createEditor()
    codeEditorElement.setAttribute('mini', true)
    quotedCodeEditorElement = createEditor()
    quotedCodeEditorElement.setAttribute('mini', true)
    patternEditorElement = createEditor()
    patternEditorElement.setAttribute('mini', true)
    matchesEditorElement = createEditor()
    matchesEditorElement.setAttribute('mini', true)
    matchesEditorElement.removeAttribute('tabindex')

    @div class: "elixir-quoted-view", style: "overflow: scroll;", =>
      @div class: 'padded', =>
        @header 'Code', class: 'header'
        @section class: 'input-block', =>
          @subview 'codeEditorElement', codeEditorElement

        @header 'Quoted form', class: 'header'
        @section class: 'input-block', =>
          @subview 'quotedCodeEditorElement', quotedCodeEditorElement

        @header 'Pattern Matching', class: 'header'
        @section class: 'input-block', =>
          @subview 'patternEditorElement', patternEditorElement

        @section class: 'input-block matchesEditorSection', =>
          @subview 'matchesEditorElement', matchesEditorElement

  constructor: ({@code, @quotedCode}) ->
    super
    @disposables = new CompositeDisposable
    @handleEvents()

  initialize: ->
    @codeEditor = @codeEditorElement.getModel()
    @codeEditor.placeholderText = 'Elixir code. e.g. func(42, "meaning of life")'
    @codeEditor.onDidChange (e) =>
      @code = @codeEditor.getText()
      @quotedCodeGetter? @code, (result) =>
        @setQuotedCode(result)

    @quotedCodeEditor = @quotedCodeEditorElement.getModel()
    @quotedCodeEditor.placeholderText = 'Elixir code in quoted form. e.g. {:func, [line: 1], [42, "meaning of life"]}'
    @quotedCodeEditor.onDidChange (e) =>
      @quotedCode = @quotedCodeEditor.getText()
      @matchesGetter? @patternEditor.getText(), @quotedCode, (result) =>
        @matchesEditor.setText(result)

    @patternEditor = @patternEditorElement.getModel()
    @patternEditor.setSoftWrapped(true)
    @patternEditor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()
    @patternEditor.setLineNumberGutterVisible(false)
    @patternEditor.placeholderText = 'Pattern matching against quoted form. e.g. {name, [line: line], args}'
    @patternEditor.onDidChange (e) =>
      return unless @matchesGetter
      @matchesGetter @patternEditor.getText(), @quotedCode, (result) =>
        @matchesEditor.setText(result)

    @matchesEditor = @matchesEditorElement.getModel()
    @matchesEditor.setSoftWrapped(true)
    @matchesEditor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()
    @matchesEditor.setLineNumberGutterVisible(false)

  handleEvents: ->
    @disposables.add atom.commands.add @element,
      'elixir-quoted-view:focus-next': => @focusNextElement(1)
      'elixir-quoted-view:focus-previous': => @focusNextElement(-1)

  attached: ->
    return if @isAttached
    @isAttached = true

    resolve = =>
      @refreshView()

    if atom.workspace?
      resolve()
    else
      @disposables.add atom.packages.onDidActivateInitialPackages(resolve)

  serialize: ->
    deserializer: 'ElixirQuotedView'
    source: @quotedCode

  destroy: ->
    @disposables.dispose()

  setQuotedCodeGetter: (quotedCodeGetter) ->
    @quotedCodeGetter = quotedCodeGetter

  setMatchesGetter: (matchesGetter) ->
    @matchesGetter = matchesGetter

  setQuotedCode:(quotedCode) ->
    @quotedCode = quotedCode
    @quotedCodeEditor.setText(@quotedCode)

  setCode:(code) ->
    @code = code
    @codeEditor.setText(@code)

  refreshView: ->
    return unless @quotedCode?
    @quotedCodeEditor.setText(@quotedCode)

  getTitle: ->
    "Quoted Code"

  getIconName: ->
    "file-text"

  getURI: ->
    "atom-elixir://elixir-quoted-views/view"

  focusNextElement: (direction) ->
    elements = [@codeEditorElement, @quotedCodeEditorElement, @patternEditorElement]
    focusedElement = (el for el in elements when 'is-focused' in el.classList)[0]
    focusedIndex = elements.indexOf focusedElement
    focusedIndex = focusedIndex + direction
    focusedIndex = 0 if focusedIndex >= elements.length
    focusedIndex = elements.length - 1 if focusedIndex < 0
    elements[focusedIndex].focus()
