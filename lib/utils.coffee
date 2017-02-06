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
  elixir_version = '1.4'

  erl_func_arity = elixir_func_arity = ''
  if func? && arity?
    erl_func_arity    = "\##{func}-#{arity}"
    elixir_func_arity = "\##{func}/#{arity}"

  if mod? && mod.match(/^:/)
    "http://www.erlang.org/doc/man/#{mod.replace(/^:/, '')}.html#{erl_func_arity}"
  else
    module = mod || 'Kernel'
    "https://hexdocs.pm/elixir/#{elixir_version}/#{module}.html#{elixir_func_arity}"

convertCodeBlocksToAtomEditors = (domFragment, defaultLanguage='text') ->
  if fontFamily = atom.config.get('editor.fontFamily')
    for codeElement in domFragment.querySelectorAll('code')
      codeElement.style.fontFamily = fontFamily

  isSpec = (text) ->
    text.startsWith('@spec') or
    text.startsWith('@type') or
    text.startsWith('@callback') or
    text.startsWith('@macrocallback')

  for preElement in domFragment.querySelectorAll('pre, code')
    if preElement.tagName == 'PRE' or (preElement.tagName == 'CODE' and isSpec(preElement.innerText))
      codeBlock = preElement.firstElementChild ? preElement
      fenceName = codeBlock.getAttribute('class')?.replace(/^lang-/, '') ? defaultLanguage

      editorElement = document.createElement('atom-text-editor')
      editorElement.setAttributeNode(document.createAttribute('gutter-hidden'))
      editorElement.removeAttribute('tabindex') # make read-only

      preElement.parentNode.insertBefore(editorElement, preElement)
      preElement.remove()

      editor = editorElement.getModel()
      editor.setSoftWrapped(true)

      # remove the default selection of a line in each editor
      editor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()
      editor.setText(codeBlock.textContent.trim())

      if grammar = atom.grammars.grammarForScopeName('source.elixir')
        editor.setGrammar(grammar)

  domFragment

module.exports = {createTempFile, splitModuleAndFunc, markdownToHTML, getDocURL, convertCodeBlocksToAtomEditors}
