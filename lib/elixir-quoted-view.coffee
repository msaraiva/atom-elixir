path = require 'path'

{Emitter, Disposable, CompositeDisposable, File} = require 'atom'
{ScrollView} = require 'atom-space-pen-views'

module.exports =
class ElixirQuotedView extends ScrollView
  @content: ->
    @div class: 'elixir-quoted-view'
    # @message = document.createElement('div')
    # @message.classList.add('message')

  constructor: ({@code, @quotedCode}) ->
    super
    @disposables = new CompositeDisposable
    @handleEvents()

  initialize: ->
    super
    codeTitle = document.createElement('div')
    codeTitle.textContent = 'Code'
    codeTitle.classList.add('panel-heading')
    @element.appendChild(codeTitle)

    @codeEditorElement = @createEditor()
    @codeEditorElement.setAttribute('mini', true)
    @codeEditor = @codeEditorElement.getModel()
    @codeEditor.onDidChange (e) =>
      @code = @codeEditor.getText()
      @quotedCodeGetter @code, (result) =>
        @setQuotedCode(result)
    @element.appendChild(@codeEditorElement)

    quotedCodeTitle = document.createElement('div')
    quotedCodeTitle.textContent = 'Quoted form'
    quotedCodeTitle.classList.add('panel-heading')
    @element.appendChild(quotedCodeTitle)

    @quotedCodeEditorElement = @createEditor()
    @quotedCodeEditorElement.setAttribute('mini', true)
    @quotedCodeEditor = @quotedCodeEditorElement.getModel()
    @quotedCodeEditor.onDidChange (e) =>
      @quotedCode = @quotedCodeEditor.getText()
      @matchesGetter @patternEditor.getText(), @quotedCode, (result) =>
        @matchesEditor.setText(result)
    @element.appendChild(@quotedCodeEditorElement)

    patternTitle = document.createElement('div')
    patternTitle.textContent = 'Pattern'
    patternTitle.classList.add('panel-heading')
    @element.appendChild(patternTitle)

    @patternEditorElement = @createEditor()
    @patternEditorElement.setAttribute('mini', true)
    @patternEditor = @patternEditorElement.getModel()
    @patternEditor.setSoftWrapped(true)
    @patternEditor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()
    @patternEditor.setLineNumberGutterVisible(false)
    @patternEditor.placeholderText = 'Pattern matching the quoted form. e.g. {fun, [line: _], args}'
    @patternEditor.onDidChange (e) =>
      return unless @matchesGetter
      @matchesGetter @patternEditor.getText(), @quotedCode, (result) =>
        @matchesEditor.setText(result)
    @element.appendChild(@patternEditorElement)

    matchTitle = document.createElement('div')
    matchTitle.textContent = 'Match'
    matchTitle.classList.add('panel-heading')
    @element.appendChild(matchTitle)

    @matchesEditorElement = @createEditor()
    @matchesEditorElement.setAttribute('mini', true)
    @matchesEditorElement.removeAttribute('tabindex')
    @matchesEditor = @matchesEditorElement.getModel()
    @matchesEditor.setSoftWrapped(true)
    @matchesEditor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()
    @matchesEditor.setLineNumberGutterVisible(false)
    @element.appendChild(@matchesEditorElement)

    # Pattern  {var1, var2}
    # Match
    #   var1   [lksajdlf]
    #   var2   {:fedd}

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
    # @refreshView()

  setCode:(code) ->
    @code = code
    @codeEditor.setText(@code)
    # @refreshView()

  refreshView: ->
    return unless @quotedCode?
    @quotedCodeEditor.setText(@quotedCode)

  getTitle: ->
    "Quoted Code"

  getIconName: ->
    "file-text"

  getURI: ->
    "atom-elixir://elixir-quoted-views/view"

  copyToClipboard: ->
    selection = window.getSelection()
    selectedText = selection.toString()
    atom.clipboard.write(selectedText)
    true

  createEditor: ->
    element = document.createElement('atom-text-editor')
    element.setAttribute('tabIndex', 0)
    # element.removeAttribute('tabindex')
    editor = element.getModel()
    editor.setLineNumberGutterVisible(true)
    # editor.setSoftWrapped(true)
    # editor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()
    editor.setGrammar(atom.grammars.grammarForScopeName('source.elixir'))
    atom.commands.add element,
      'core:move-up': =>
        editor.moveUp()
      'core:move-down': =>
        editor.moveDown()
      'editor:newline': =>
        editor.insertText('\n')
    element

  handleEvents: ->
    @disposables.add atom.commands.add @element,
      'elixir-quoted-view:focus-next': => @focusNextElement(1)
      'elixir-quoted-view:focus-previous': => @focusNextElement(-1)

  focusNextElement: (direction) ->
    elements = [@codeEditorElement, @quotedCodeEditorElement, @patternEditorElement]
    focusedElement = (el for el in elements when 'is-focused' in el.classList)[0]
    focusedIndex = elements.indexOf focusedElement
    focusedIndex = focusedIndex + direction
    focusedIndex = 0 if focusedIndex >= elements.length
    focusedIndex = elements.length - 1 if focusedIndex < 0
    elements[focusedIndex].focus()
    # elements[focusedIndex].getModel?().selectAll()
