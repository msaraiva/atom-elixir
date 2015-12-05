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
    @element.appendChild(@codeEditorElement)

    quotedCodeTitle = document.createElement('div')
    quotedCodeTitle.textContent = 'Quoted form'
    quotedCodeTitle.classList.add('panel-heading')
    @element.appendChild(quotedCodeTitle)

    # quotedCodeTitle.classList.add('panel-heading')
    @quotedCodeEditorElement = @createEditor()
    @quotedCodeEditorElement.setAttribute('mini', true)
    @quotedCodeEditor = @quotedCodeEditorElement.getModel()
    @element.appendChild(@quotedCodeEditorElement)

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
    # @quotedCodeEditor.setText(@quotedCode)
    # @element.appendChild(@textEditorElement)

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
    editor = element.getModel()
    editor.setLineNumberGutterVisible(true)
    editor.setGrammar(atom.grammars.grammarForScopeName('source.elixir'))
    atom.commands.add element,
      'core:move-up': =>
        editor.moveUp()
      'core:move-down': =>
        editor.moveDown()
    element
