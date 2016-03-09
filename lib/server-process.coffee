spawn = require('child_process').spawn
path  = require 'path'
{createTempFile} = require './utils'
fs = require('fs')

module.exports =

class ServerProcess
  ready: false
  testing: false
  proc: null
  env: null

  constructor: (projectPath) ->
    @projectPath = projectPath
    @command     = "elixir"
    @args        = [path.join(__dirname, "alchemist-server/run.exs")]
    @proc        = null
    @busy        = false
    @lastRequestType = null
    @lastRequestWhenBusy = null

  start: (env) ->
    @env = env
    @proc = @spawnChildProcess(env)

    buffer = ''

    @proc.stdout.on 'data', (chunk) =>
      @ready = true
      if ~chunk.indexOf("END-OF-#{@lastRequestType}")
        [before, after] = chunk.toString().split("END-OF-#{@lastRequestType}")
        @onResult((buffer + before).trim())
        @busy = false
        if after
          buffer = after
        else
          buffer = ''
        if @lastRequestWhenBusy?
          [type, args, onResult] = @lastRequestWhenBusy
          @lastRequestWhenBusy = null
          console.log("Retrying last request when busy")
          @sendRequest(type, args, onResult)
      else
        buffer += chunk.toString()
      return

    @proc.stderr.on 'data', (chunk) =>
      @ready = true
      @busy = false
      message = "[atom-elixir] " + chunk.toString()
      if ~chunk.indexOf("Server Error")
        console.warn(message)
      else
        console.log(message)

    @proc.on 'close', (exitCode) =>
      console.log  "[atom-elixir] Child process exited with code " + exitCode
      @ready = false
      @busy = false
      @proc = null

    @proc.on 'error', (error) =>
      console.error "[atom-elixir] " + error.toString()
      @ready = false
      @busy = false
      @proc = null

  stop: ->
    @proc.stdin.end()
    @ready = false
    @busy = false
    @proc = null

  getSuggestionsForCodeComplete: (hint, buffer, line, onResult) ->
    tmpBufferFile = createTempFile(buffer)
    @sendRequest 'COMP', "\"#{hint}\", \"#{tmpBufferFile}\", #{line}", (result) ->
      fs.unlink(tmpBufferFile)
      onResult(result)

  getDefinitionFile: (expr, filePath, buffer, line, onResult) ->
    tmpBufferFile = createTempFile(buffer)
    @sendRequest 'DEFL', "\"#{expr}\", \"#{filePath}\", \"#{tmpBufferFile}\", #{line}", (result) ->
      fs.unlink(tmpBufferFile)
      onResult(result)

  getQuotedCode: (code, onResult) ->
    tmpFile = createTempFile(code)
    @sendRequest 'EVAL', ":quote, \"#{tmpFile}\"", (result) ->
      fs.unlink(tmpFile)
      onResult(result)

  evalCode: (code, onResult) ->
    tmpFile = createTempFile(code)
    @sendRequest 'EVAL', ":eval, \"#{tmpFile}\"", (result) ->
      fs.unlink(tmpFile)
      onResult(result)

  expandOnce: (buffer, code, line, onResult) ->
    tmpBufferFile = createTempFile(buffer)
    tmpFile = createTempFile(code)
    @sendRequest 'EVAL', ":expand_once, \"#{tmpBufferFile}\", \"#{tmpFile}\", #{line}", (result) ->
      fs.unlink(tmpFile)
      fs.unlink(tmpBufferFile)
      onResult(result)

  expand: (buffer, code, line, onResult) ->
    tmpBufferFile = createTempFile(buffer)
    tmpFile = createTempFile(code)
    @sendRequest 'EVAL', ":expand, \"#{tmpBufferFile}\", \"#{tmpFile}\", #{line}", (result) ->
      fs.unlink(tmpFile)
      fs.unlink(tmpBufferFile)
      onResult(result)

  expandFull: (buffer, code, line, onResult) ->
    tmpBufferFile = createTempFile(buffer)
    tmpFile = createTempFile(code)
    @sendRequest 'EVAL', ":expand_full, \"#{tmpBufferFile}\", \"#{tmpFile}\", #{line}", (result) ->
      fs.unlink(tmpFile)
      fs.unlink(tmpBufferFile)
      onResult(result)

  match: (code, onResult) ->
    tmpFile = createTempFile(code)
    @sendRequest 'EVAL', ":match, \"#{tmpFile}\"", (result) ->
      fs.unlink(tmpFile)
      onResult(result)

  getDocumentation: (subject, buffer, line, onResult) ->
    tmpBufferFile = createTempFile(buffer)
    @sendRequest 'DOCL', "\"#{subject}\", \"#{tmpBufferFile}\", #{line}", (result) ->
      fs.unlink(tmpBufferFile)
      onResult(result)

  setEnv: (env) ->
    if @testing
      console.log  "[atom-elixir] Not setting environment while testing"
    else
      @sendRequest 'SENV', "\"#{env}\"", (result) =>
        @env = result
        console.log  "[atom-elixir] Setting environment to \"#{@env}\""

  sendRequest: (type, args, onResult) ->
    # Note: The helper function `createTempFile` returns a path that contains uses backslashes as path separators.
    # That's fine for Atom, but the alchemist server does not seem to like it.
    if process.platform == 'win32'
      args = args.replace(/\\/g, '/')
    request = "#{type} { #{args} }\n"
    console.log('[Server] ' + request)
    if !@busy
      @onResult = onResult
      @busy = true
      @lastRequestType = type
      @proc.stdin.write(request);
    else
      console.log('Server busy!')
      @lastRequestWhenBusy = [type, args, onResult]

  spawnChildProcess: (env) ->
    options =
      cwd: @projectPath
      stdio: "pipe"

    if process.platform == 'win32'
      options.windowsVerbatimArguments = true
      spawn('cmd', ['/s', '/c', '"' + [@command].concat(@args).concat(env).join(' ') + '"'], options)
    else
      spawn(@command, @args.concat(env), options)
