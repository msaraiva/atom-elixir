spawn = require('child_process').spawn
path  = require 'path'
{createTempFile} = require './utils'
fs = require('fs')

module.exports =

class ServerProcess

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
      @busy = false
      message = "[atom-elixir] " + chunk.toString()
      if ~chunk.indexOf("Server Error")
        console.error(message)
      else
        console.log(message)

    @proc.on 'close', (exitCode) =>
      console.error  "[atom-elixir] Child process exited with code " + exitCode
      @busy = false
      @proc = null

    @proc.on 'error', (error) =>
      console.error "[atom-elixir] " + error.toString()
      @busy = false
      @proc = null

  stop: ->
    @proc.stdin.end()
    @busy = false
    @proc = null

  getSuggestionsForCodeComplete: (hint, bufferText, line, onResult) ->
    tmpBufferFile = createTempFile(bufferText)
    @sendRequest 'COMP', "\"#{hint}\", \"#{tmpBufferFile}\", #{line}", (result) ->
      fs.unlink(tmpBufferFile)
      onResult(result)

  getDefinitionFile: (expr, filePath, bufferText, line, onResult) ->
    tmpBufferFile = createTempFile(bufferText)
    @sendRequest 'DEFL', "\"#{expr}\", \"#{filePath}\", \"#{tmpBufferFile}\", #{line}", (result) ->
      fs.unlink(tmpBufferFile)
      onResult(result)

  getQuotedCode: (file, onResult) ->
    @sendRequest('EVAL', ":quote, \"#{file}\"", onResult)

  expandOnce: (file, onResult) ->
    @sendRequest('EVAL', ":expand_once, \"#{file}\"", onResult)

  expand: (file, onResult) ->
    @sendRequest('EVAL', ":expand, \"#{file}\"", onResult)

  match: (file, onResult) ->
    @sendRequest('EVAL', ":match, \"#{file}\"", onResult)

  getDocs: (text, bufferFile, line, onResult) ->
    @sendRequest('DOCL', "\"#{text}\", \"#{bufferFile}\", #{line}, [ context: Elixir, imports: [], aliases: [] ]", onResult)

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
