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
        console.log "Changed"
    @element.appendChild(@codeEditorElement)

    quotedCodeTitle = document.createElement('div')
    quotedCodeTitle.textContent = 'Quoted form'
    quotedCodeTitle.classList.add('panel-heading')
    @element.appendChild(quotedCodeTitle)

    @quotedCodeEditorElement = @createEditor()
    @quotedCodeEditorElement.setAttribute('mini', true)
    @quotedCodeEditor = @quotedCodeEditorElement.getModel()
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
    @element.appendChild(@patternEditorElement)

    matchTitle = document.createElement('div')
    matchTitle.textContent = 'Match'
    matchTitle.classList.add('panel-heading')
    @element.appendChild(matchTitle)

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
    element
