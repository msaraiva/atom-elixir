spawn = require('child_process').spawn
path  = require 'path'

module.exports =

class ServerProcess
  ready: false
  testing: false
  proc: null

  constructor: (projectPath, onTcpServerReady) ->
    @projectPath = projectPath
    @command     = "elixir"
    @args        = [path.join(__dirname, "elixir_sense/run.exs")]
    @proc        = null
    @onTcpServerReady = onTcpServerReady

  start: (port, env) ->
    @proc = @spawnChildProcess(port, env)
    @proc.stdout.on 'data', (chunk) =>
      if @onTcpServerReady
        if ~chunk.indexOf("ok:")
          [_, host, port, auth_token] = chunk.toString().split(":")
        @onTcpServerReady(host, port, auth_token || null)
        @onTcpServerReady = null
        return

      console.log("[ElixirSense] " + chunk.toString())
      @ready = true

    @proc.stderr.on 'data', (chunk) =>
      @ready = true
      message = "[ElixirSense] " + chunk.toString()
      if ~chunk.indexOf("Server Error")
        console.warn(message)
      else
        console.log(message)

    @proc.on 'close', (exitCode) =>
      console.log  "[atom-elixir] Child process exited with code " + exitCode
      @ready = false
      @proc = null

    @proc.on 'error', (error) =>
      console.error "[atom-elixir] " + error.toString()
      @ready = false
      @proc = null

  stop: ->
    @proc.stdin.end()
    @ready = false
    @proc = null

  spawnChildProcess: (port, env) ->
    options =
      cwd: @projectPath
      stdio: "pipe"

    if process.platform == 'win32'
      options.windowsVerbatimArguments = true
      spawn('cmd', ['/s', '/c', '"' + [@command].concat(@args).concat('tcpip', port, env).join(' ') + '"'], options)
    else
      spawn(@command, @args.concat('unix', port, env), options)
