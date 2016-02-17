{CompositeDisposable} = require 'atom'
{markdownToHTML} = require './utils'

module.exports =
class ElixirAutocompleteProvider
  selector: ".source.elixir"
  # disableForSelector: '.source.elixir .comment'
  server: null
  inclusionPriority: 1
  excludeLowerPriority: true

  constructor: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add(atom.config.observe('autocomplete-plus.minimumWordLength', (@minimumWordLength) => ))

  dispose: ->
    @subscriptions.dispose()

  setServer: (server) ->
    @server = server

    # This is a hack until descriptionHTML is suported. See:
    # https://github.com/atom/autocomplete-plus/issues/423
    replaceUpdateDescription()

  getSuggestions: ({editor, bufferPosition, scopeDescriptor, prefix, activatedManually}) ->
    scopeChain = scopeDescriptor.getScopeChain()
    editorElement = atom.views.getView(editor)
    if scopeChain.match(/\.string\.quoted\./) || scopeChain.match(/\.comment/)
      unless (activatedManually || 'autocomplete-active' in editorElement.classList)
        return

    textBeforeCursor = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
    prefix = getPrefix(textBeforeCursor)
    pipeBefore = !!textBeforeCursor.match(///\|>\s*#{prefix}$///)
    captureBefore = !!textBeforeCursor.match(///&#{prefix}$///)

    return if !activatedManually && prefix == ""

    #TODO: maybe we should have our own configuration for that
    # return unless prefix?.length >= @minimumWordLength

    new Promise (resolve) =>
      editor     = atom.workspace.getActiveTextEditor()
      line       = editor.getCursorBufferPosition().row + 1
      bufferText = editor.buffer.getText()

      @server.getSuggestionsForCodeComplete prefix, bufferText, line, (result) ->
        suggestions = result.split('\n')

        [hint, _type] = suggestions[0].split(';')
        suggestions = suggestions[1...]
        modulesToAdd = []
        isPrefixFunctionCall = !!(prefix.match(/\.[^A-Z][^\.]*$/) || prefix.match(/^[^A-Z:][^\.]*$/))

        if prefix != '' && !isPrefixFunctionCall
          prefixModules = prefix.split('.')[...-1]
          hintModules   = hint.split('.')[...-1]

          if prefix[-1...][0] != '.' || ("#{prefixModules}" != "#{hintModules}")
            modulesToAdd = (m for m,i in hintModules when m != prefixModules[i])
            lastModuleHint = hintModules[hintModules.length-1]

        suggestions = suggestions.map (serverSuggestion) ->
          fields = serverSuggestion.replace(/;/g, '\u000B').replace(/\\\u000B/g, ';').split('\u000B')
          name = fields[0]
          if lastModuleHint && (lastModuleHint not in [name, ":#{name}"]) && modulesToAdd.length > 0
            fields[0] = modulesToAdd.join('.') + '.' + name
          createSuggestion(serverSuggestion, fields, prefix, pipeBefore, captureBefore)

        suggestions = sortSuggestions(suggestions)
        resolve(suggestions)

  getPrefix = (textBeforeCursor) ->
    regex = /[\w0-9\._!\?\:@]+$/
    textBeforeCursor.match(regex)?[0] or ''

  createSuggestion = (serverSuggestion, fields, prefix, pipeBefore, captureBefore) ->
    if fields[1] == 'module'
      [name, kind, subtype, desc] = fields
    else
      [name, kind, signature, mod, desc, spec] = fields

    return "" if serverSuggestion.match(/^[\s\d]/)

    if kind == 'attribute'
      createSuggestionForAttribute(name, prefix)
    else if kind == 'var'
      createSuggestionForVariable(name)
    else if kind == 'module'
      createSuggestionForModule(serverSuggestion, name, desc, prefix, subtype)
    else if kind in ['private_function', 'public_function', 'public_macro']
      createSuggestionForFunction(serverSuggestion, name, kind, signature, "", desc, spec, prefix, pipeBefore, captureBefore)
    else if kind in ['function', 'macro']
      createSuggestionForFunction(serverSuggestion, name, kind, signature, mod, desc, spec, prefix, pipeBefore, captureBefore)
    else
      console.log("Unknown kind: #{serverSuggestion}")
      {
        text: serverSuggestion
        type: 'exception'
        iconHTML: '?'
        rightLabel: kind || 'hint'
      }

  createSuggestionForAttribute = (name, prefix) ->
    if prefix.match(/^@/)
      snippet = name.replace(/^@/, '')
    else
      snippet = name

    {
      snippet: snippet
      displayText: name[1...]
      type: 'property'
      iconHTML: '@'
      rightLabel: 'attribute'
    }

  createSuggestionForVariable = (name) ->
    {
      text: name
      displayText: name
      type: 'variable'
      iconHTML: 'v'
      rightLabel: 'variable'
    }

  createSuggestionForFunction = (serverSuggestion, name, kind, signature, mod, desc, spec, prefix, pipeBefore, captureBefore) ->
    args = signature.split(',')
    [_, func, arity] = name.match(/(.+)\/(\d+)/)
    [moduleParts..., postfix] = prefix.split('.')

    params = []
    displayText = ''
    snippet = func
    description = desc.replace(/\\n/g, "\n")

    if signature
      params = args.map (arg, i) -> "${#{i+1}:#{arg.replace(/\s+\\.*$/, '')}}"
      displayText = "#{func}(#{args.join(', ')})"
    else
      params = ([1..arity].map (i) -> "${#{i}:arg#{i}}") if arity > 0
      displayText = "#{func}/#{arity}"

    snippetParams = params
    snippetParams = snippetParams[1...] if snippetParams.length > 0 && pipeBefore

    if captureBefore
      snippet = "#{func}/#{arity}"
    else if snippetParams.length > 0
      snippet = "#{func}(#{snippetParams.join(', ')})"

    snippet = snippet.replace(/^:/, '') + "$0"

    [type, iconHTML, rightLabel] =
      switch kind
        when 'private_function' then ['tag',      'f', 'private']
        when 'public_function'  then ['function', 'f', 'public']
        when 'function'         then ['function', 'f', mod]
        when 'public_macro'     then ['package',  'm', 'public']
        when 'macro'            then ['package',  'm', mod]
        else                         ['unknown',  '?', '']

    if prefix.match(/^:/)
      [module, funcName] = moduleAndFuncName(moduleParts, func)
      description = "No documentation available."

    description = "```\n#{spec}```\n\n#{description}" if spec? && spec != ""
    description = markdownToHTML(description)

    {
      func: func
      arity: arity
      snippet: snippet
      displayText: displayText
      type: type
      rightLabel: rightLabel
      descriptionHTML: description
      iconHTML: iconHTML
    }

  createSuggestionForModule = (serverSuggestion, name, desc, prefix, subtype) ->
    return "" if serverSuggestion.match(/^[\s\d]/)

    snippet = name.replace(/^:/, '')
    name = ':' + name if name.match(/^[^A-Z:]/)
    description = desc || "No documentation available."
    description = markdownToHTML(description.replace(/\\n/g, "\n"))

    iconHTML =
      switch subtype
        when 'protocol'
          'P'
        when 'implementation'
          'I'
        when 'exception'
          'E'
        when 'struct'
          'S'
        else
          'M'

    {
      snippet: snippet
      displayText: name
      type: 'class'
      iconHTML: iconHTML
      descriptionHTML: description
      rightLabel: subtype || 'module'
    }

  sortSuggestions = (suggestions) ->
    sortKind = (a, b) ->
      priority =
        exception: 0 # unknown
        property:  0 # module attribute
        variable:  1 # variable
        tag:       2 # private function
        class:     3 # module
        package:   4 # macro
        function:  4 # function

      priority[a.type] - priority[b.type]

    sortText = (a, b) ->
      if a.displayText > b.displayText then 1 else if a.displayText < b.displayText then -1 else 0

    isFunc = (suggestion) ->
      !!(suggestion.func)

    sortFunctionByType = (a, b) ->
      return 0 if !isFunc(a) || !isFunc(b)
      startsWithLetterRegex = /^[a-zA-Z]/
      aStartsWithLetter = a.func.match(startsWithLetterRegex)
      bStartsWithLetter = b.func.match(startsWithLetterRegex)
      if !aStartsWithLetter && bStartsWithLetter then 1 else if aStartsWithLetter && !bStartsWithLetter then -1 else 0

    sortFunctionByName = (a, b) ->
      return 0 if !isFunc(a) || !isFunc(b)
      if a.func > b.func then 1 else if a.func < b.func then -1 else 0

    sortFunctionByArity = (a, b) ->
      return 0 if !isFunc(a) || !isFunc(b)
      if a.arity > b.arity then 1 else if a.arity < b.arity then -1 else 0

    sortFunc = (a, b) ->
      sortKind(a, b) || sortFunctionByType(a, b) || sortFunctionByName(a, b) || sortFunctionByArity(a, b) || sortText(a, b)

    suggestions.sort(sortFunc)

  replaceUpdateDescription = ->
    replaceCreateView(p) for p in atom.views.providers when p.modelConstructor.name is 'SuggestionList'

  replaceCreateView = (viewProvider) ->
    viewProvider.createView = (model) ->
      SuggestionListElement = require "#{atom.packages.getActivePackage('autocomplete-plus').path}/lib/suggestion-list-element"
      element = new SuggestionListElement().initialize(model)
      element.updateDescription = (item) ->
        suggestionList = atom.packages.getActivePackage('autocomplete-plus').mainModule.autocompleteManager.suggestionList
        suggestionListView = atom.views.getView(suggestionList)
        descriptionContent = suggestionListView.querySelector('.suggestion-description-content')
        descriptionContainer = suggestionListView.querySelector('.suggestion-description')
        descriptionMoreLink = suggestionListView.querySelector('.suggestion-description-more-link')

        descriptionMoreLink.style.display = 'none'
        item = item ? @model?.items?[@selectedIndex]
        return unless item?
        if item.descriptionHTML? and item.descriptionHTML.length > 0
          descriptionContainer.style.display = 'block'
          descriptionContent.innerHTML = item.descriptionHTML
        else if item.description? and item.description.length > 0
          descriptionContainer.style.display = 'block'
          descriptionContent.textContent = item.descriptionHTML
        else
          @descriptionContainer.style.display = 'none'
      element

  moduleAndFuncName = (moduleParts, func) ->
    module = ''
    funcName = ''
    if func.match(/^:/)
      [module, funcName] = func.split('.')
    else if moduleParts.length > 0
      module = moduleParts[0]
      funcName = func
    [module, funcName]
