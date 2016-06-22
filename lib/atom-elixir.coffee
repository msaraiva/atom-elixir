{TextEditor, CompositeDisposable} = require 'atom'
spawn = require('child_process').spawn

module.exports = AtomElixir =
  expandProvider: null
  autocompleteProvider: null
  gotoDefinitionProvider: null
  docsProvider: null
  quotedProvider: null

  activate: (state) ->
    console.log "[atom-elixir] Activating atom-elixir version #{@packageVersion()}"

    ElixirExpandProvider = require('./elixir-expand-provider')
    ElixirAutocompleteProvider = require('./elixir-autocomplete-provider')
    ElixirDocsProvider = require('./elixir-docs-provider')
    ElixirQuotedProvider = require('./elixir-quoted-provider')
    ElixirGotoDefinitionProvider = require('./elixir-goto-definition-provider')

    @initEnv()
    @expandProvider = new ElixirExpandProvider
    @autocompleteProvider = new ElixirAutocompleteProvider
    @gotoDefinitionProvider = new ElixirGotoDefinitionProvider
    @docsProvider = new ElixirDocsProvider
    @quotedProvider = new ElixirQuotedProvider

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.workspace.observeActivePaneItem (item) =>
      if @server?.proc && item instanceof TextEditor
        env = @getEditorEnv(item)
        projectPath = atom.project.getPaths()[0]
        if (env != @server.env) or (projectPath != @server.projectPath)
          @server.setEnv(@getEditorEnv(item), projectPath)

    sourceElixirSelector = 'atom-text-editor[data-grammar^="source elixir"]'
    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:debug', =>
      @server.debug()

  deactivate: ->
    console.log "[atom-elixir] Deactivating atom-elixir version #{@packageVersion()}"

    @cleanRequireCache()
    @expandProvider.dispose()
    @expandProvider = null
    @autocompleteProvider.dispose()
    @autocompleteProvider = null
    @gotoDefinitionProvider.dispose()
    @gotoDefinitionProvider = null
    @docsProvider.dispose()
    @docsProvider = null
    @quotedProvider.dispose()
    @quotedProvider = null
    @server.stop()
    @server = null
    @subscriptions.dispose()

  packageVersion: ->
    atom.packages.getLoadedPackage('atom-elixir').metadata.version

  provideAutocomplete: ->
    [@autocompleteProvider]

  getEditorEnv: (editor)->
    projectPath = atom.project.getPaths()[0]
    env = "dev"
    if editor?.getPath()?.startsWith(projectPath + '/test/')
      env = "test"
    env

  cleanRequireCache: ->
    Object.keys(require.cache)
      .filter (p) -> p.indexOf("/atom-elixir/lib/") > 0
      .forEach (p) ->
        delete require.cache[p]

  initEnv: ->
    ServerProcess = require './server-process'

    [shell, out] = [process.env.SHELL || 'bash', '']
    pid = if process.platform == 'win32' then spawn('cmd', ['/C', 'set']) else spawn(shell, ['--login', '-c', 'env'])
    pid.stdout.on 'data', (chunk) -> out += chunk
    pid.on 'error', =>
      console.log('Failed to import ENV from', shell)
    pid.on 'close', =>
      for line in out.split('\n')
        match = line.match(/^(\S+?)=(.+)/)
        process.env[match[1]] = match[2] if match
      @server = new ServerProcess(atom.project.getPaths()[0])
      editor = atom.workspace.getActiveTextEditor()
      @server.start(@getEditorEnv(editor))
      @expandProvider.setServer(@server)
      @autocompleteProvider.setServer(@server)
      @gotoDefinitionProvider.setServer(@server)
      @docsProvider.setServer(@server)
      @quotedProvider.setServer(@server)

    pid.stdin.end()
