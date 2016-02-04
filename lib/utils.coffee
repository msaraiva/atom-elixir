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
  tmpFile = os.tmpdir() + Math.random().toString(36).substr(2, 9)
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

module.exports = {createTempFile, splitModuleAndFunc, markdownToHTML}
