os = require('os')
fs = require('fs')
marked = require('marked');

markdownToHTML = (markdownSource) ->
  marked.setOptions({
    renderer: new marked.Renderer(),
    gfm: true,
    tables: true,
    breaks: false,
    pedantic: false,
    sanitize: true,
    smartLists: true,
    smartypants: false
  });
  marked(markdownSource)

createTempFile = (content) ->
  tmpFile = os.tmpdir() + '/' + Math.random().toString(36).substr(2, 9)
  fs.writeFileSync(tmpFile, content)
  tmpFile

splitModuleAndFunc = (text) ->
  [p1..., p2] = text.split('.')
  fun = if isFunction(p2) then p2 else null
  if !fun
    p1 = p1.concat(p2)
  mod = if p1.length > 0 then p1.join('.').replace(/\.$/, '') else null
  [mod, fun]

isFunction = (word) ->
  !!word.match(/^[^A-Z:]/)

getDocURL = (mod, func, arity) ->
  #TODO: Retrieve from the environment or from the server process
  elixir_version = '1.2'

  erl_func_arity = elixir_func_arity = ''
  if func? && arity?
    erl_func_arity    = "\##{func}-#{arity}"
    elixir_func_arity = "\##{func}/#{arity}"

  if mod? && mod.match(/^:/)
    "http://www.erlang.org/doc/man/#{mod.replace(/^:/, '')}.html#{erl_func_arity}"
  else
    module = mod || 'Kernel'
    "http://elixir-lang.org/docs/v#{elixir_version}/elixir/#{module}.html#{elixir_func_arity}"

module.exports = {createTempFile, splitModuleAndFunc, markdownToHTML, getDocURL}
