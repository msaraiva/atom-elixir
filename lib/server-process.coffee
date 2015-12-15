spawn = require('child_process').spawn
path  = require 'path'

module.exports =

class ServerProcess

  constructor: (projectPath) ->
    @projectPath = projectPath
    @command     = "elixir"
    @args        = [path.join(__dirname, "alchemist-server/run.exs"), "dev"]
    @proc        = null
    @busy        = false
    @last_request_type = null

  start: ->
    @proc = @spawnChildProcess()

    buffer = ''

    @proc.stdout.on 'data', (chunk) =>
      if ~chunk.indexOf("END-OF-#{@last_request_type}")
        [before, after] = chunk.toString().split("END-OF-#{@last_request_type}")
        @busy = false
        @onResult((buffer + before).trim())
        if after
          buffer = after
        else
          buffer = ''
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

  getCodeCompleteSuggestions: (text, bufferFile, line, onResult) ->
    @sendRequest('COMP', "\"#{text}\", \"#{bufferFile}\", #{line}, [ context: Elixir, imports: [], aliases: [] ]", onResult)

  # TODO: Take this to a separate file
  isFunction = (word) ->
    !!word.match(/^[^A-Z:]/)

  splitModuleAndFunc = (word) ->
    [p1..., p2] = word.split('.')
    fun = if isFunction(p2) then p2 else null

    if !fun
      p1 = p1.concat(p2)

    mod = if p1.length > 0 then p1.join('.').replace(/\.$/, '') else null
    [mod, fun]

  #####################################

  getFileDeclaration: (word, filePath, bufferFile, line, onResult) ->
    [mod, fun] = splitModuleAndFunc(word)
    text = "#{mod || 'nil'},#{fun || 'nil'}"
    @sendRequest('DEFL', "\"#{text}\", \"#{filePath}\", \"#{bufferFile}\", #{line}, [ context: Elixir, imports: [], aliases: [] ]", onResult)

  getQuotedCode: (file, onResult) ->
    @sendRequest('EVAL', ":quote, \"#{file}\"", onResult)

  expandOnce: (file, onResult) ->
    @sendRequest('EVAL', ":expand_once, \"#{file}\"", onResult)

  expand: (file, onResult) ->
    @sendRequest('EVAL', ":expand, \"#{file}\"", onResult)

  match: (file, onResult) ->
    @sendRequest('EVAL', ":match, \"#{file}\"", onResult)

  getDocs: (text, onResult) ->
    @sendRequest('DOCL', "\"#{text}\", [ context: Elixir, imports: [], aliases: [] ]", onResult)

  sendRequest: (type, args, onResult) ->
    request = "#{type} { #{args} }\n"
    console.log('[Server] ' + request)
    if !@busy
      @onResult = onResult
      @busy = true
      @last_request_type = type
      @proc.stdin.write(request);
    else
      console.log('Server busy!')

  spawnChildProcess: ->
    options =
      cwd: @projectPath
      stdio: "pipe"

    if process.platform == 'win32'
      options.windowsVerbatimArguments = true
      spawn('cmd', ['/s', '/c', '"' + [@command].concat(args).join(' ') + '"'], options)
    else
      spawn(@command, @args, options)
