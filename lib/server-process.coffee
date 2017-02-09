net   = require('net');
path  = require 'path'
{createTempFile} = require './utils'
fs = require('fs')

module.exports =

class ServerProcess
  ready: false
  testing: false
  client: null
  env: null
  projectPath: null

  constructor: (projectPath) ->
    @projectPath = projectPath
    @command     = "elixir"
    @args        = [path.join(__dirname, "elixir_sense/run.exs"), "--listen", "--port 50501"]
    @client      = null
    @busy        = false
    @lastRequestType = null
    @lastRequestWhenBusy = null

  start: (env) ->
    @env = env
    @client = @connectToServer(env)
    console.log(@client)

    buffer = ''

    @client.on 'data', (chunk) =>
      @ready = true
      if ~chunk.indexOf("END-OF-#{@lastRequestType}")
        [before, after] = chunk.toString().split("END-OF-#{@lastRequestType}")
        try
          @onResult((buffer + before).trim())
        catch e
          console.error(e)

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

    @client.on 'close', () =>
      console.log  "[atom-elixir] Connection to server closed"
      @ready = false
      @busy = false
      @client = null

    @client.on 'error', (error) =>
      console.error "[atom-elixir] " + error.toString()
      @ready = false
      @busy = false
      @client = null

  stop: ->
    @client.close()
    @ready = false
    @busy = false
    @client = null

  getSuggestionsForCodeComplete: (hint, buffer, line, onResult) ->
    tmpBufferFile = createTempFile(buffer)
    @sendRequest 'COMP', "\"#{hint}\", [ context: Elixir, imports: [], aliases: [] ]", (result) ->
      fs.unlink(tmpBufferFile)
      onResult(result)

  getDefinitionFile: (expr, filePath, buffer, line, onResult) ->
    tmpBufferFile = createTempFile(buffer)
    @sendRequest 'DEFL', "\"#{expr}\", [ context: Elixir, imports: [], aliases: [] ]", (result) ->
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
    @sendRequest 'DOCL', "\"#{subject}\", [ context: Elixir, imports: [], aliases: [] ]", (result) ->
      fs.unlink(tmpBufferFile)
      onResult(result)

  setEnv: (env, cwd) ->
    if @testing
      console.log  "[atom-elixir] Not setting environment while testing"
    else
      @sendRequest 'SENV', "\"#{env}\", \"#{cwd}\"", (result) =>
        [@env, @projectPath] = result.split(',')
        console.log  "[atom-elixir] Setting environment to \"#{@env}\""
        console.log  "[atom-elixir] Working directory is \"#{@projectPath})\""

  debug: ->
    @sendRequest 'DEBG', "[]", (result) =>
      console.log  "[atom-elixir] DEBUG INFO:\n#{result}"

  sendRequest: (type, args, onResult) ->
    # Note: The helper function `createTempFile` returns a path that contains uses backslashes as path separators.
    # That's fine for Atom, but the alchemist server does not seem to like it.
    if process.platform == 'win32'
      args = args.replace(/\\/g, '/')
    request = "#{type} { #{args} }\n"
    console.log('[Server] ' + request)
    if @client != null && !@busy
      @onResult = onResult
      @busy = true
      @lastRequestType = type
      @client.write(request)
    else
      console.log('Server busy!')
      @lastRequestWhenBusy = [type, args, onResult]

  connectToServer: (env) ->
    if atom.config.get('atom-elixir.remoteUri') == null
      options =
        cwd: @projectPath
        stdio: "pipe"

      console.log("Command is " + @command, @args.concat(env), options)

      if process.platform == 'win32'
        options.windowsVerbatimArguments = true
        spawn('cmd', ['/s', '/c', '"' + [@command].concat(@args).concat(env).join(' ') + '"'], options)
      else
        spawn(@command, @args.concat(env), options)


    client = new net.Socket();
    client.connect(atom.config.get('atom-elixir.remoteUriPort'), atom.config.get('atom-elixir.remoteUriHost'), ->
      console.log("Connected")
    )
    return client
