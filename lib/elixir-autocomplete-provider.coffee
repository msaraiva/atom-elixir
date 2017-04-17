{CompositeDisposable} = require 'atom'
{markdownToHTML, convertCodeBlocksToAtomEditors} = require './utils'

module.exports =
class ElixirAutocompleteProvider
  selector: ".source.elixir"
  # disableForSelector: '.source.elixir .comment'
  inclusionPriority: 1
  excludeLowerPriority: false

  constructor: ->
    @subscriptions = new CompositeDisposable
    @config = {}
    @subscriptions.add(atom.config.observe('atom-elixir.enableSuggestionSnippet', (value) =>
      @config.enableSuggestionSnippet = value
    ))
    @subscriptions.add(atom.config.observe('atom-elixir.addParenthesesAfterSuggestionConfirmed', (value) =>
      @config.addParenthesesAfterSuggestionConfirmed = value
    ))
    @subscriptions.add(atom.config.observe('atom-elixir.showSignatureInfoAfterSuggestionConfirm', (value) =>
      @config.showSignatureInfoAfterSuggestionConfirm = value
    ))

    @subscriptions.add(atom.config.observe('autocomplete-plus.minimumWordLength', (@minimumWordLength) => ))

    @subscriptions.add atom.commands.add 'atom-text-editor:not(mini)[data-grammar^="source elixir"]',
      # Replacing default autocomplete 'tab' key so that the snippet's tab-stops have precedence
      'atom-elixir:autocomplete-tab': (event) ->
        editor = atom.workspace.getActiveTextEditor()
        snippets = atom.packages.getActivePackage('snippets')?.mainModule
        nextTab = snippets.goToNextTabStop(editor)
        if nextTab
          atom.commands.dispatch(atom.views.getView(editor), 'autocomplete-plus:cancel')
        else
          event.abortKeyBinding()
          atom.commands.dispatch(atom.views.getView(editor), 'autocomplete-plus:confirm')
      # Replacing default autocomplete 'enter' key so that tab-stops keep working properly after 'enter'
      'atom-elixir:autocomplete-enter': (event) ->
        editor = atom.workspace.getActiveTextEditor()
        snippets = atom.packages.getActivePackage('snippets')?.mainModule
        nextTab = snippets.goToNextTabStop(editor)
        if nextTab
          atom.commands.dispatch(atom.views.getView(editor), 'snippets:previous-tab-stop')
        atom.commands.dispatch(atom.views.getView(editor), 'autocomplete-plus:confirm')

  dispose: ->
    @subscriptions.dispose()

  onDidInsertSuggestion: ({editor, triggerPosition, suggestion}) =>
    if @config.showSignatureInfoAfterSuggestionConfirm
      atom.commands.dispatch(atom.views.getView(editor), 'atom-elixir:show-signature')

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
    defBefore = null
    if textBeforeCursor.match(///def\s*#{prefix}$///)
      defBefore = 'def'
    else if textBeforeCursor.match(///defmacro\s*#{prefix}$///)
      defBefore = 'defmacro'

    return if !activatedManually && prefix == "" && !defBefore

    #TODO: maybe we should have our own configuration for that
    # return unless prefix?.length >= @minimumWordLength

    new Promise (resolve) =>
      editor     = atom.workspace.getActiveTextEditor()
      position   = editor.getCursorBufferPosition()
      line       = position.row + 1
      col = position.column + 1
      bufferText = editor.buffer.getText()

      if !@client
        console.log("ElixirSense client not ready")
        resolve([])
        return

      @client.send "suggestions", {buffer: bufferText, line: line, column: col}, (result) =>
        hint = result[0].value
        suggestions = result[1...]
        modulesToAdd = []
        isPrefixFunctionCall = !!(prefix.match(/\.[^A-Z][^\.]*$/) || prefix.match(/^[^A-Z:][^\.]*$/))

        if prefix != '' && !isPrefixFunctionCall
          prefixModules = prefix.split('.')[...-1]
          hintModules   = hint.split('.')[...-1]

          if prefix[-1...][0] != '.' || ("#{prefixModules}" != "#{hintModules}")
            modulesToAdd = (m for m,i in hintModules when m != prefixModules[i])
            lastModuleHint = hintModules[hintModules.length-1]

        suggestions = suggestions.map (serverSuggestion, index) =>
          name = serverSuggestion.name
          if lastModuleHint && (lastModuleHint not in [name, ":#{name}"]) && modulesToAdd.length > 0
            serverSuggestion.name = modulesToAdd.join('.') + '.' + name
          createSuggestion(serverSuggestion, index, prefix, pipeBefore, captureBefore, defBefore, @config)

        suggestions = suggestions.filter (item) -> item? && item != ''
        suggestions = sortSuggestions(suggestions)

        if suggestions.length > 0
          atom.commands.dispatch(atom.views.getView(editor), 'atom-elixir:hide-signature')

        resolve(suggestions)

  getPrefix = (textBeforeCursor) ->
    regex = /[\w0-9\._!\?\:@]+$/
    textBeforeCursor.match(regex)?[0] or ''

  createSuggestion = (serverSuggestion, index, prefix, pipeBefore, captureBefore, defBefore, config) ->
    if serverSuggestion.type == 'module'
      [name, kind, subtype, desc] = [serverSuggestion.name, serverSuggestion.type, serverSuggestion.subtype, serverSuggestion.summary]
    else if serverSuggestion.type == 'return'
      [name, kind, spec, snippet] = [serverSuggestion.name, serverSuggestion.type, serverSuggestion.spec, serverSuggestion.snippet]
    else
      [name, kind, signature, mod, desc, spec] = [serverSuggestion.name, serverSuggestion.type, serverSuggestion.args, serverSuggestion.origin, serverSuggestion.summary, serverSuggestion.spec]

    return "" if defBefore and kind != 'callback'

    suggestion =
      if kind == 'attribute'
        createSuggestionForAttribute(name, prefix)
      else if kind == 'variable'
        createSuggestionForVariable(name)
      else if kind == 'module'
        createSuggestionForModule(serverSuggestion, name, desc, prefix, subtype)
      else if kind == 'callback'
        createSuggestionForCallback(serverSuggestion, name + "/" + serverSuggestion.arity, kind, signature, mod, desc, spec, prefix, defBefore)
      else if kind == 'return'
        createSuggestionForReturn(serverSuggestion, name, kind, spec, snippet)
      else if ['private_function', 'public_function', 'public_macro'].indexOf(kind) > -1
        createSuggestionForFunction(serverSuggestion, name + "/" + serverSuggestion.arity, kind, signature, "", desc, spec, prefix, pipeBefore, captureBefore, config)
      else if ['function', 'macro'].indexOf(kind) > -1
        createSuggestionForFunction(serverSuggestion, name + "/" + serverSuggestion.arity, kind, signature, mod, desc, spec, prefix, pipeBefore, captureBefore, config)
      else
        console.log("Unknown kind: #{serverSuggestion}")
        {
          text: serverSuggestion
          type: 'exception'
          iconHTML: '?'
          rightLabel: kind || 'hint'
        }
    suggestion.index = index
    suggestion

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

  createSuggestionForFunction = (serverSuggestion, name, kind, signature, mod, desc, spec, prefix, pipeBefore, captureBefore, config) ->
    args = signature.split(',')
    [_, func, arity] = name.match(/(.+)\/(\d+)/)
    [moduleParts..., postfix] = prefix.split('.')

    params = []
    displayText = ''
    snippet = func
    description = desc
    spec = spec

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
      if config.enableSuggestionSnippet
        snippet = "#{func}(#{snippetParams.join(', ')})"
      else if !config.enableSuggestionSnippet && config.addParenthesesAfterSuggestionConfirmed == "addOpeningParenthesis"
        snippet = "#{func}("
      else if !config.enableSuggestionSnippet && config.addParenthesesAfterSuggestionConfirmed == "addParentheses"
        snippet = "#{func}(${1})"

    snippet = snippet.replace(/^:/, '') + "$0"

    [type, iconHTML, rightLabel] =
      switch kind
        when 'private_function' then ['method', 'f', 'private']
        when 'public_function'  then ['function', 'f', 'public']
        when 'function'         then ['function', 'f', mod]
        when 'public_macro'     then ['package',  'm', 'public']
        when 'macro'            then ['package',  'm', mod]
        else                         ['unknown',  '?', '']

    if prefix.match(/^:/)
      [module, funcName] = moduleAndFuncName(moduleParts, func)
      description = "No documentation available."

    {
      func: func
      arity: arity
      snippet: snippet
      displayText: displayText
      type: type
      rightLabel: rightLabel
      iconHTML: iconHTML
      spec: spec
      summary: description
    }

  createSuggestionForCallback = (serverSuggestion, name, kind, signature, mod, desc, spec, prefix, defBefore) ->
    args = signature.split(',')
    [func, arity] = name.split('/')

    params = []
    displayText = ''
    snippet = func
    description = desc
    spec = spec

    if signature
      params = args.map (arg, i) -> "${#{i+1}:#{arg.replace(/\s+\\.*$/, '')}}"
      displayText = "#{func}(#{args.join(', ')})"
    else
      params = ([1..arity].map (i) -> "${#{i}:arg#{i}}") if arity > 0
      displayText = "#{func}/#{arity}"

    snippet = "#{func}(#{params.join(', ')}) do\n\t$0\nend\n"

    if defBefore == 'def'
      return "" if spec.startsWith('@macrocallback')
    else if defBefore == 'defmacro'
      return "" if spec.startsWith('@callback')
    else
      def_str = if spec.startsWith('@macrocallback') then 'defmacro' else 'def'
      snippet = "#{def_str} #{snippet}"

    [type, iconHTML, rightLabel] = ['value', 'c', mod]

    if desc == ""
      description = "No documentation available."

    {
      func: func
      arity: arity
      snippet: snippet
      displayText: displayText
      type: type
      rightLabel: rightLabel
      iconHTML: iconHTML
      spec: spec
      summary: description
    }

  createSuggestionForReturn = (serverSuggestion, name, kind, spec, snippet) ->
    displayText = name
    snippet = snippet.replace(/"(\$\{\d+:)/g, "$1").replace(/(\})\$"/g, "$1") + "$0"

    [type, iconHTML, rightLabel] = ['value', 'r', 'return']

    {
      snippet: snippet
      displayText: displayText
      type: type
      rightLabel: rightLabel
      iconHTML: iconHTML
      spec: spec
    }

  createSuggestionForModule = (serverSuggestion, name, desc, prefix, subtype) ->
    snippet = name.replace(/^:/, '')
    name = ':' + name if name.match(/^[^A-Z:]/)
    description = desc || "No documentation available."

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
      summary: description
      rightLabel: subtype || 'module'
    }

  sortSuggestions = (suggestions) ->
    sortKind = (a, b) ->
      priority =
        exception: 0 # unknown
        snippet:   0
        value:     1 # callbacks/returns
        variable:  2 # variable
        property:  3 # module attribute
        method:    4 # private function
        class:     5 # module
        package:   6 # macro
        function:  6 # function

      priority[a.type] - priority[b.type]

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
      return a.arity - b.arity

    sortByOriginalOrder = (a, b) ->
      return a.index - b.index

    sortFunc = (a, b) ->
      sortKind(a, b) || sortFunctionByType(a, b) || sortFunctionByName(a, b) || sortFunctionByArity(a, b) || sortByOriginalOrder(a, b)

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

        if item.spec? or item.summary?
          if descriptionContent.children.length < 2
            descriptionContent.innerHTML = '<pre><code></code></pre><p></p>'
            convertCodeBlocksToAtomEditors(descriptionContent)

          specText       = (item.spec || '').trim()
          summaryText    = (item.summary || '').trim()
          specElement    = descriptionContent.children[0]
          summaryElement = descriptionContent.children[1]

          if specText != ''
            specElement.style.display = 'block'
            specElement.getModel().setText(specText)
          else
            specElement.style.display = 'none'

          if summaryText != ''
            summaryElement.style.display = 'block'
            summaryElement.outerHTML = markdownToHTML(summaryText)
          else
            summaryElement.style.display = 'none'

          if specText == summaryText == ''
            descriptionContainer.style.display = 'none'
          else
            descriptionContainer.style.display = 'block'
        else
          # Default implementation from https://github.com/atom/autocomplete-plus/blob/v2.29.1/lib/suggestion-list-element.coffee#L104
          if item.description? and item.description.length > 0
            descriptionContainer.style.display = 'block'
            descriptionContent.textContent = item.description
            if item.descriptionMoreURL? and item.descriptionMoreURL.length?
              descriptionMoreLink.style.display = 'inline'
              descriptionMoreLink.setAttribute('href', item.descriptionMoreURL)
            else
              descriptionMoreLink.style.display = 'none'
              descriptionMoreLink.setAttribute('href', '#')
          else
            descriptionContainer.style.display = 'none'

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

  setClient: (client) ->
    @client = client
    # This is a hack until descriptionHTML is suported. See:
    # https://github.com/atom/autocomplete-plus/issues/423
    replaceUpdateDescription()
