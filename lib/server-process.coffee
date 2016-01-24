spawn = require('child_process').spawn
path  = require 'path'
{createTempFile} = require './utils'
fs = require('fs')

module.exports =

class ServerProcess
  ready: false

  constructor: (projectPath) ->
    @projectPath = projectPath
    @command     = "elixir"
    @args        = [path.join(__dirname, "alchemist-server/run.exs"), "dev"]
    @proc        = null
    @busy        = false
    @lastRequestType = null
    @lastRequestWhenBusy = null

  start: ->
    @proc = @spawnChildProcess()

    buffer = ''

    @proc.stdout.on 'data', (chunk) =>
      @ready = true
      if ~chunk.indexOf("END-OF-#{@lastRequestType}")
        [before, after] = chunk.toString().split("END-OF-#{@lastRequestType}")
        @busy = false
        @onResult((buffer + before).trim())
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
        console.error(message)
      else
        console.log(message)

    @proc.on 'close', (exitCode) =>
      console.error  "[atom-elixir] Child process exited with code " + exitCode
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

  getQuotedCode: (file, onResult) ->
    @sendRequest('EVAL', ":quote, \"#{file}\"", onResult)

  evalCode: (code, onResult) ->
    tmpBufferFile = createTempFile(code)
    @sendRequest 'EVAL', ":eval, \"#{tmpBufferFile}\"", (result) ->
      fs.unlink(tmpBufferFile)
      onResult(result)

  expandOnce: (file, onResult) ->
    @sendRequest('EVAL', ":expand_once, \"#{file}\"", onResult)

  expand: (file, onResult) ->
    @sendRequest('EVAL', ":expand, \"#{file}\"", onResult)

  match: (file, onResult) ->
    @sendRequest('EVAL', ":match, \"#{file}\"", onResult)

  getDocumentation: (subject, buffer, line, onResult) ->
    tmpBufferFile = createTempFile(buffer)
    @sendRequest 'DOCL', "\"#{subject}\", \"#{tmpBufferFile}\", #{line}", (result) ->
      fs.unlink(tmpBufferFile)
      onResult(result)

  sendRequest: (type, args, onResult) ->
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

  spawnChildProcess: ->
    options =
      cwd: @projectPath
      stdio: "pipe"

    if process.platform == 'win32'
      options.windowsVerbatimArguments = true
      spawn('cmd', ['/s', '/c', '"' + [@command].concat(args).join(' ') + '"'], options)
    else
      spawn(@command, @args, options)
