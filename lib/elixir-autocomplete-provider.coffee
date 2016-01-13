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

    prefix = getPrefix(editor, bufferPosition)

    return if !activatedManually && prefix == ""

    #TODO: maybe we should have our own configuration for that
    # return unless prefix?.length >= @minimumWordLength

    new Promise (resolve) =>
      editor     = atom.workspace.getActiveTextEditor()
      line       = editor.getCursorBufferPosition().row + 1
      bufferText = editor.buffer.getText()

      @server.getSuggestionsForCodeComplete prefix, bufferText, line, (result) ->
        suggestions = result.split('\n')

        hint = suggestions[0]
        suggestions = suggestions[1...]
        module_prefix = ''
        modules_to_add = []

        is_prefix_a_function_call = !!(prefix.match(/\.[^A-Z][^\.]*$/) || prefix.match(/^[^A-Z:][^\.]*$/))

        if prefix != '' && !is_prefix_a_function_call
          prefix_modules = prefix.split('.')[...-1]
          hint_modules   = hint.split('.')[...-1]

          if prefix[-1...][0] != '.' || ("#{prefix_modules}" != "#{hint_modules}")
            modules_to_add = (m for m,i in hint_modules when m != prefix_modules[i])
            # modules_to_add = (m for m,i in hint_modules when m != prefix_modules[i] || i == hint_modules.length-1)
            module_prefix = modules_to_add.join('.') + '.' if modules_to_add.length > 0

        suggestions = suggestions.map (serverSuggestion) ->
          createSuggestion(module_prefix + serverSuggestion, prefix)

        if modules_to_add.length > 0
          new_suggestion = modules_to_add.join('.')
          suggestions   = [createSuggestionForModule(new_suggestion, new_suggestion, '', '')].concat(suggestions)

        suggestions = sortSuggestions(suggestions)

        resolve(suggestions)

  getPrefix = (editor, bufferPosition) ->
    line = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition])
    regex = /[\w0-9\._!\?\:]+$/
    line.match(regex)?[0] or ''

  createSuggestion = (serverSuggestion, prefix) ->
    fields = serverSuggestion.replace(/;/g, '\u000B').replace(/\\\u000B/g, ';').split('\u000B')
    if fields[1] == 'module'
      [name, kind, desc] = serverSuggestion.replace(/;/g, '\u000B').replace(/\\\u000B/g, ';').split('\u000B')
    else
      [name, kind, signature, mod, desc, spec] = serverSuggestion.replace(/;/g, '\u000B').replace(/\\\u000B/g, ';').split('\u000B')

    return "" if serverSuggestion.match(/^[\s\d]/)

    switch kind
      when 'var'
        createSuggestionForVariable(name)
      when 'private_function'
        createSuggestionForFunction(serverSuggestion, name, kind, signature, "", desc, spec, prefix)
      when 'public_function'
        createSuggestionForFunction(serverSuggestion, name, kind, signature, "", desc, spec, prefix)
      when 'function'
        createSuggestionForFunction(serverSuggestion, name, kind, signature, mod, desc, spec, prefix)
      when 'public_macro'
        createSuggestionForFunction(serverSuggestion, name, kind, signature, "", desc, spec, prefix)
      when 'macro'
        createSuggestionForFunction(serverSuggestion, name, kind, signature, mod, desc, spec, prefix)
      when 'module'
        createSuggestionForModule(serverSuggestion, name, desc, prefix)
      else
        console.log("Unknown kind: #{serverSuggestion}")
        {
          text: serverSuggestion
          type: 'exception'
          iconHTML: '?'
          rightLabel: kind || 'hint'
        }

  createSuggestionForVariable = (name) ->
    {
      text: name
      type: 'value'
      iconHTML: 'v'
    }

  createSuggestionForFunction = (serverSuggestion, name, kind, signature, mod, desc, spec, prefix) ->
    args = signature.split(',')
    [func, arity] = name.split('/')
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

    if arity != '0'
      snippet = "#{func}(#{params.join(', ')})"

    snippet = snippet.replace(/^:/, '') + " $0"

    [type, iconHTML] =
      switch kind
        when 'private_function' then ['tag',      'f']
        when 'public_function'  then ['function', 'f']
        when 'function'         then ['function', 'f']
        when 'public_macro'     then ['package',  'm']
        when 'macro'            then ['package',  'm']
        else                         ['unknown',  '?']

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
      snippet: snippet
      displayText: displayText
      type: type
      rightLabel: mod
      # description: description
      descriptionHTML: description
      descriptionMoreURL: getDocURL(prefix, func, arity)
      iconHTML: iconHTML
      # replacementPrefix: prefix
    }

  createSuggestionForModule = (serverSuggestion, name, desc, prefix) ->
    return "" if serverSuggestion.match(/^[\s\d]/)

    snippet = name.replace(/^:/, '')
    name = ':' + name if name.match(/^[^A-Z:]/)
    description = desc || ""
    description = markdownToHTML(description.replace(/\\n/g, "\n"))

    {
      snippet: snippet
      displayText: name
      type: 'class'
      iconHTML: 'M'
      descriptionHTML: description
      rightLabel: 'module'
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
    sort_kind = (a, b) ->
      priority =
        exception: 0 # unknown
        value:     0 # variable
        tag:       1 # private function
        class:     3 # module
        package:   4 # macro
        function:  4 # function

      priority[a.type] - priority[b.type]

    sort_text = (a, b) ->
      if a.displayText > b.displayText then 1 else if a.displayText < b.displayText then -1 else 0

    sort_func = (a, b) ->
      sort_kind(a,b) || sort_text(a, b)

    suggestions.sort(sort_func)

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
