{CompositeDisposable} = require 'atom'
spawn = require('child_process').spawn
ServerProcess = require './server-process'

ElixirProvider = require('./elixir-provider')
ElixirAutocompleteProvider = require('./elixir-autocomplete-provider')
ElixirHyperclickProvider = require('./elixir-hyperclick-provider')
ElixirDocsProvider = require('./elixir-docs-provider')
ElixirQuotedProvider = require('./elixir-quoted-provider')

module.exports = AtomElixir =
  provider: null
  autocompleteProvider: null
  hyperclickProvider: null
  docsProvider: null

  activate: (state) ->
    @initEnv()
    unless @provider?
      @provider = new ElixirProvider

    unless @autocompleteProvider?
      @autocompleteProvider = new ElixirAutocompleteProvider

    unless @hyperclickProvider?
      @hyperclickProvider = new ElixirHyperclickProvider
      @hyperclickProvider.setElixirProvider(@provider)

    unless @docsProvider?
      @docsProvider = new ElixirDocsProvider

    unless @quotedProvider?
      @quotedProvider = new ElixirQuotedProvider

  deactivate: ->
    @provider.dispose()
    @autocompleteProvider.dispose()
    @hyperclickProvider.dispose()
    @docsProvider.dispose()
    @quotedProvider.dispose()
    @server.stop()

  provideAutocomplete: ->
    [@autocompleteProvider]

  provideHyperclick: ->
    @hyperclickProvider

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
        @docsProvider.setServer(@server)
        @quotedProvider.setServer(@server)
      pid.stdin.end()
