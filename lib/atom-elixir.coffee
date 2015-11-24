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
    # console.log("provideAutocomplete")
    [@autocompleteProvider]

  activate: (state) ->
    # console.log("ACTIVATE")
    @initEnv()

    @subscriptions = new CompositeDisposable

    unless @provider?
      @provider = new ElixirProvider

    unless @autocompleteProvider?
      @autocompleteProvider = new ElixirAutocompleteProvider

    # atom.workspace.observeTextEditors (editor) ->
    #   editor.onDidSave (e) ->
    #     console.log "Saving: #{e.path}"

  deactivate: ->
    # console.log("DEACTIVATE")
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
        # console.log("Server Ready")
        @provider.setServer(@server)
        @autocompleteProvider.setServer(@server)
      pid.stdin.end()
