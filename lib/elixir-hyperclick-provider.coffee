{CompositeDisposable} = require 'atom'

module.exports =
class ElixirHyperclickProvider
  priority: 0
  providerName: 'elixir-hyperclick-provider',
  wordRegExp: /^[	 ]*$|[^\s\/\\\(\)"',\.;<>~#\$%\^&\*\|\+=\[\]\{\}`\-…]+|[\/\\\(\)"',\.;<>~!#\$%\^&\*\|\+=\[\]\{\}`\?\-…]+/g
  elixirProvider: null

  setElixirProvider: (provider) ->
    @elixirProvider = provider

  constructor: ->
    @subscriptions = new CompositeDisposable

  dispose: ->
    @subscriptions.dispose()

  getSuggestionForWord: (textEditor, text, range) =>
    if (textEditor.getGrammar().scopeName != 'source.elixir')
      return

    if (!text.match(/[a-zA-Z_]/) || text.match(/\:$/))
      return

    line = textEditor.getTextInRange([[range.start.row, 0], range.end])
    regex = /[\w0-9\._!\?\:\@]+$/
    matches = line.match(regex)
    fullWord = (matches && matches[0]) || ''

    if (['do', 'fn', 'end', 'false', 'true', 'nil'].indexOf(text) < 0)
      return {
        range: range,
        callback: =>
          @elixirProvider.gotoDeclaration(fullWord, textEditor, range.start)
      }
