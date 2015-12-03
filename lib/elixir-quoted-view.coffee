path = require 'path'

{Emitter, Disposable, CompositeDisposable, File} = require 'atom'
{ScrollView} = require 'atom-space-pen-views'

module.exports =
class ElixirQuotedView extends ScrollView
  @content: ->
    @div class: 'elixir-quoted-view'

  constructor: ({@quotedCode}) ->
    super
    @disposables = new CompositeDisposable

  initialize: ->
    super
    @textEditorElement = document.createElement('atom-text-editor')
    # @textEditorElement.setAttribute('mini', true)
    @editor = @textEditorElement.getModel()
    @editor.setLineNumberGutterVisible(false)
    @editor.setGrammar(atom.grammars.grammarForScopeName('source.elixir'))
    @element.appendChild(@textEditorElement)


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
    @refreshView()

  refreshView: ->
    return unless @quotedCode?
    @editor.setText(@quotedCode)
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
