path = require 'path'
{markdownToHTML} = require './utils'

{Emitter, Disposable, CompositeDisposable, File} = require 'atom'
{ScrollView} = require 'atom-space-pen-views'

module.exports =
class ElixirDocsView extends ScrollView
  @content: ->
    @div class: 'elixir-docs-view native-key-bindings', tabindex: -1

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

  setSource:(source) ->
    @source = source
    @renderMarkdown()

  renderMarkdown: ->
    return unless @source?
    @html(markdownToHTML(@source))

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
