{TextEditor, CompositeDisposable} = require 'atom'
spawn = require('child_process').spawn
ServerProcess = require './server-process'

ElixirExpandProvider = require('./elixir-expand-provider')
ElixirAutocompleteProvider = require('./elixir-autocomplete-provider')
ElixirDocsProvider = require('./elixir-docs-provider')
ElixirQuotedProvider = require('./elixir-quoted-provider')
ElixirGotoDefinitionProvider = require('./elixir-goto-definition-provider')

module.exports = AtomElixir =
  expandProvider: null
  autocompleteProvider: null
  gotoDefinitionProvider: null
  docsProvider: null
  quotedProvider: null

  activate: (state) ->
    @initEnv()
    unless @expandProvider?
      @expandProvider = new ElixirExpandProvider

    unless @autocompleteProvider?
      @autocompleteProvider = new ElixirAutocompleteProvider

    unless @gotoDefinitionProvider?
      @gotoDefinitionProvider = new ElixirGotoDefinitionProvider

    unless @docsProvider?
      @docsProvider = new ElixirDocsProvider

    unless @quotedProvider?
      @quotedProvider = new ElixirQuotedProvider

    atom.workspace.observeActivePaneItem (item) =>
      if item instanceof TextEditor
        @server?.setEnv(@getEditorEnv(item))

  deactivate: ->
    @expandProvider.dispose()
    @autocompleteProvider.dispose()
    @gotoDefinitionProvider.dispose()
    @docsProvider.dispose()
    @quotedProvider.dispose()
    @server.stop()

  provideAutocomplete: ->
    [@autocompleteProvider]

  getEditorEnv: (editor)->
    projectPath = atom.project.getPaths()[0]
    env = "dev"
    if editor?.getPath()?.startsWith(projectPath + '/test/')
      env = "test"
    env

  initEnv: ->
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
