{Disposable, CompositeDisposable, Range} = require 'atom'
KeyClickEventHandler = require './keyclick-event-handler'

module.exports =
class ElixirGotoDefinitionProvider

  constructor: ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      if (editor.getGrammar().scopeName != 'source.elixir')
        return
      keyClickEventHandler = new KeyClickEventHandler(editor, @keyClickHandler)

      editorDestroyedSubscription = editor.onDidDestroy =>
        console.log("editorDestroyedSubscription: #{editor.id}")
        editorDestroyedSubscription.dispose()
        keyClickEventHandler.dispose()

      @subscriptions.add(editorDestroyedSubscription)

  dispose: ->
    @subscriptions.dispose()

  keyClickHandler: (editor, text, range) =>
    console.log "Text: #{text}"

# getSuggestionForWord: (textEditor, text, range) =>
#   if (textEditor.getGrammar().scopeName != 'source.elixir')
#     return
#
#   if (!text.match(/[a-zA-Z_]/) || text.match(/\:$/))
#     return
#
#   line = textEditor.getTextInRange([[range.start.row, 0], range.end])
#   regex = /[\w0-9\._!\?\:\@]+$/
#   matches = line.match(regex)
#   fullWord = (matches && matches[0]) || ''
#
#   if (['do', 'fn', 'end', 'false', 'true', 'nil'].indexOf(text) < 0)
#     return {
#       range: range,
#       callback: =>
#         @elixirProvider.gotoDeclaration(fullWord, textEditor, range.start)
#     }
