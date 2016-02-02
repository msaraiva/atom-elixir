{CompositeDisposable} = require 'atom'
marked = require('marked');

#TODO: Retrieve from the environment or from the server process
ELIXIR_VERSION = '1.1'

module.exports =
class ElixirAutocompleteProvider
  selector: ".source.elixir"
  # disableForSelector: '.source.elixir .comment'
  server: null
  inclusionPriority: 1
  excludeLowerPriority: true

  constructor: ->
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-text-editor', 'atom-elixir:autocomplete-tab', ->
      editor = atom.workspace.getActiveTextEditor()
      atom.commands.dispatch(atom.views.getView(editor), 'autocomplete-plus:cancel')
      atom.commands.dispatch(atom.views.getView(editor), 'snippets:next-tab-stop')
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
        module_prefix = ''
        modules_to_add = []
        is_prefix_a_function_call = !!(prefix.match(/\.[^A-Z][^\.]*$/) || prefix.match(/^[^A-Z:][^\.]*$/))

        if prefix != '' && !is_prefix_a_function_call
          prefix_modules = prefix.split('.')[...-1]
          hint_modules   = hint.split('.')[...-1]

          if prefix[-1...][0] != '.' || ("#{prefix_modules}" != "#{hint_modules}")
            modules_to_add = (m for m,i in hint_modules when m != prefix_modules[i])
            lastModuleHint = hint_modules[hint_modules.length-1]

        suggestions = suggestions.map (serverSuggestion) ->
          fields = serverSuggestion.replace(/;/g, '\u000B').replace(/\\\u000B/g, ';').split('\u000B')
          name = fields[0]
          if lastModuleHint && (lastModuleHint not in [name, ":#{name}"]) && modules_to_add.length > 0
            fields[0] = modules_to_add.join('.') + '.' + name
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

    switch kind
      when 'attribute'
        createSuggestionForAttribute(name, prefix)
      when 'var'
        createSuggestionForVariable(name)
      when 'private_function'
        createSuggestionForFunction(serverSuggestion, name, kind, signature, "", desc, spec, prefix, pipeBefore, captureBefore)
      when 'public_function'
        createSuggestionForFunction(serverSuggestion, name, kind, signature, "", desc, spec, prefix, pipeBefore, captureBefore)
      when 'function'
        createSuggestionForFunction(serverSuggestion, name, kind, signature, mod, desc, spec, prefix, pipeBefore, captureBefore)
      when 'public_macro'
        createSuggestionForFunction(serverSuggestion, name, kind, signature, "", desc, spec, prefix, pipeBefore, captureBefore)
      when 'macro'
        createSuggestionForFunction(serverSuggestion, name, kind, signature, mod, desc, spec, prefix, pipeBefore, captureBefore)
      when 'module'
        createSuggestionForModule(serverSuggestion, name, desc, prefix, subtype)
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
      type: 'value'
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
      params  = [1..arity].map (i) -> "${#{i}:arg#{i}}"
      displayText = "#{func}/#{arity}"

    snippet_params = params
    snippet_params = snippet_params[1...] if snippet_params.length > 0 && pipeBefore

    if captureBefore
      snippet = "#{func}/#{arity}"
    else if snippet_params.length > 0
      snippet = "#{func}(#{snippet_params.join(', ')})"

    snippet = snippet.replace(/^:/, '') + "$0"

    [type, iconHTML, rightLabel] =
      switch kind
        when 'private_function' then ['tag',      'f', 'private']
        when 'public_function'  then ['function', 'f', 'public']
        when 'function'         then ['function', 'f', mod]
        when 'public_macro'     then ['package',  'm', 'public']
        when 'macro'            then ['package',  'm', mod]
        else                         ['unknown',  '?', '']

    # TODO: duplicated
    if prefix.match(/^:/)
      module = ''
      func_name = ''
      if func.match(/^:/)
        [module, func_name] = func.split('.')
      else if moduleParts.length > 0
        module = moduleParts[0]
        func_name = func
      description = "Erlang function #{module}.#{func_name}/#{arity}"

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
      descriptionMoreURL: getDocURL(prefix, func, arity)
      iconHTML: iconHTML
    }

  createSuggestionForModule = (serverSuggestion, name, desc, prefix, subtype) ->
    return "" if serverSuggestion.match(/^[\s\d]/)

    snippet = name.replace(/^:/, '')
    name = ':' + name if name.match(/^[^A-Z:]/)
    description = desc || ""
    description = markdownToHTML(description.replace(/\\n/g, "\n"))

    iconHTML =
      switch subtype
        when 'protocol'
          'P'
        when 'implementation'
          'I'
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

  getDocURL = (prefix, func, arity) ->
    [moduleParts..., _postfix] = prefix.split('.')
    if prefix.match(/^:/)
      module = ''
      func_name = ''
      if func.match(/^:/)
        [module, func_name] = func.split('.')
      else if moduleParts.length > 0
        module = moduleParts[0]
        func_name = func
      "http://www.erlang.org/doc/man/#{module.replace(/^:/, '')}.html\##{func_name}-#{arity}"
    else
      module = if moduleParts.length > 0 then moduleParts.join('.') else 'Kernel'
      "http://elixir-lang.org/docs/v#{ELIXIR_VERSION}/elixir/#{module}.html\##{func}/#{arity}"

  sortSuggestions = (suggestions) ->
    sortKind = (a, b) ->
      priority =
        exception: 0 # unknown
        property:  0 # module attribute
        value:     1 # variable
        tag:       2 # private function
        class:     3 # module
        package:   4 # macro
        function:  4 # function

      priority[a.type] - priority[b.type]

    sortText = (a, b) ->
      if a.displayText > b.displayText then 1 else if a.displayText < b.displayText then -1 else 0

    isFunc = (suggestion) ->
      !!(suggestion.func)

    sortFunctionByName = (a, b) ->
      return 0 if !isFunc(a) || !isFunc(b)
      if a.func > b.func then 1 else if a.func < b.func then -1 else 0

    sortFunctionByArity = (a, b) ->
      return 0 if !isFunc(a) || !isFunc(b)
      if a.arity > b.arity then 1 else if a.arity < b.arity then -1 else 0

    sortFunc = (a, b) ->
      sortKind(a, b) || sortFunctionByName(a, b) || sortFunctionByArity(a, b) || sortText(a, b)

    suggestions.sort(sortFunc)

  markdownToHTML = (mdText) ->
    marked.setOptions({
      renderer: new marked.Renderer(),
      gfm: true,
      tables: true,
      breaks: false,
      pedantic: false,
      sanitize: true,
      smartLists: true,
      smartypants: false
    });
    marked(mdText)

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
