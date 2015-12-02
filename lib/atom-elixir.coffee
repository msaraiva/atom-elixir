
#############################

url = require 'url'
ElixirDocsView = null # Defer until used

createElixirDocsView = (state) ->
  ElixirDocsView ?= require './elixir-docs-view'
  new ElixirDocsView(state)

atom.deserializers.add
  name: 'ElixirDocsView'
  deserialize: (state) ->
    if state.viewId
      createElixirDocsView(state)

#############################

{CompositeDisposable} = require 'atom'
ElixirProvider = require('./elixir-provider')
ElixirAutocompleteProvider = require('./elixir-autocomplete-provider')
spawn = require('child_process').spawn
ServerProcess = require './server-process'

module.exports = AtomElixir =
  subscriptions: null
  provider: null
  autocompleteProvider: null

  provideAutocomplete: ->
    [@autocompleteProvider]

  activate: (state) ->

    ##########################

    atom.commands.add 'atom-workspace', 'atom-elixir:show-elixir-docs': =>
      @showElixirDocs()

    atom.workspace.addOpener (uriToOpen) ->
      try
        {protocol, host, pathname} = url.parse(uriToOpen)
      catch error
        return

      return unless protocol is 'atom-elixir:'

      try
        pathname = decodeURI(pathname) if pathname
      catch error
        return

      if host is 'elixir-docs-views'
        createElixirDocsView(viewId: pathname.substring(1))

    ##########################

    @initEnv()

    @subscriptions = new CompositeDisposable

    unless @provider?
      @provider = new ElixirProvider

    unless @autocompleteProvider?
      @autocompleteProvider = new ElixirAutocompleteProvider

  deactivate: ->
    @provider.dispose()
    @autocompleteProvider.dispose()
    @subscriptions.dispose()
    @server.stop()

  # https://github.com/lsegal/atom-runner/blob/master/lib/atom-runner.coffee
  initEnv: ->
    if process.platform == 'darwin'
      [shell, out] = [process.env.SHELL || 'bash', '']
      pid = spawn(shell, ['--login', '-c', 'env'])
      pid.stdout.on 'data', (chunk) -> out += chunk
      pid.on 'error', =>
        console.log('Failed to import ENV from', shell)
      pid.on 'close', =>
        for line in out.split('\n')
          match = line.match(/^(\S+?)=(.+)/)
          process.env[match[1]] = match[2] if match
        @server = new ServerProcess(atom.project.getPaths()[0])
        @server.start()
        @provider.setServer(@server)
        @autocompleteProvider.setServer(@server)
      pid.stdin.end()

  ##################################################

  showElixirDocs: ->
    editor = atom.workspace.getActiveTextEditor()
    word = editor.getWordUnderCursor({wordRegex: /[\w0-9\._!\?\:]+/})
    @addViewForElement(word)

  uriForElement: (word) ->
    "atom-elixir://elixir-docs-views/#{word}"

  addViewForElement: (word) ->
    @server.getDocs word, (result) =>
      console.log result
      return if result == ""
      uri = @uriForElement(word)

      options = {searchAllPanes: true, split: 'right'}
      # TODO: Create this configuration
      # options = {searchAllPanes: true}
      # if atom.config.get('atom-elixir.elixirDocs.openViewInSplitPane')
        # options.split = 'right'

      # previousActivePane = atom.workspace.getActivePane()
      atom.workspace.open(uri, options).then (elixirDocsView) =>
        # TODO: We could use a configuration to tell if the focus should remain on the editor
        # if atom.config.get('atom-elixir.elixirDocs.keepFocusOnEditorAfterOpenDocs')
        #   previousActivePane.activate()

        # elixirDocsView.html(@markdownToHTML(result))
        elixirDocsView.setSource(result)

  ##################################################
