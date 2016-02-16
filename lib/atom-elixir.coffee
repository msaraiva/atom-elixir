{CompositeDisposable} = require 'atom'
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

  deactivate: ->
    @expandProvider.dispose()
    @autocompleteProvider.dispose()
    @gotoDefinitionProvider.dispose()
    @docsProvider.dispose()
    @quotedProvider.dispose()
    @server.stop()

  provideAutocomplete: ->
    [@autocompleteProvider]

  initEnv: ->
    if process.platform in ['darwin', 'linux']
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
        @expandProvider.setServer(@server)
        @autocompleteProvider.setServer(@server)
        @gotoDefinitionProvider.setServer(@server)
        @docsProvider.setServer(@server)
        @quotedProvider.setServer(@server)
      pid.stdin.end()
