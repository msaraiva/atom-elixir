spawn = require('child_process').spawn
fs = require('fs')

positionInModule = {row: 5, column: 0}
positionInPublicFunc = {row: 10, column: 0}

writeText = (editor, text) ->
  for i in [0..(text.length-1)]
    editor.insertText(text[i])
  advanceClock(200)

waitsForAutocompleteView = (editorView) ->
  waitsFor 'autocomplete view to appear', 3000, ->
    editorView.querySelector('.autocomplete-plus span.word')

expectListTexts = (editorView, texts) ->
  runs ->
    list = editorView.querySelectorAll('.autocomplete-plus li span.word')
    for i in [0..(texts.length-1)]
      expect(list[i]).toHaveText(texts[i])

describe 'ElixirAutocompleteProvider', ->
  [completionDelay, editor, editorView] = []

  beforeEach ->
    atom.config.set('autocomplete-plus.enableAutoActivation', true)
    atom.config.set('autocomplete-plus.autoActivationDelay', 100)
    completionDelay = 200 # Rendering delay
    workspaceElement = atom.views.getView(atom.workspace)
    jasmine.attachToDOM(workspaceElement)

    mainModule = null
    autocompleteManager = null

    waitsForPromise ->
      Promise.all [
        atom.workspace.open('sample.ex').then (e) ->
          editor = e
          editorView = atom.views.getView(editor)

          pid = spawn('elixirc', ['--ignore-module-conflict', '-o', '_build/dev/lib/sample/ebin/', editor.getPath()])
          out = ''
          pid.stdout.on 'data', (chunk) -> out += chunk
          pid.on 'error', (error) => console.log(error.toString())
          pid.on 'close', => console.log(out)
          pid.stdin.end()

        atom.packages.activatePackage('language-elixir')

        atom.packages.activatePackage('autocomplete-plus').then (pack) ->
          autocompleteManager = pack.mainModule.getAutocompleteManager()

        atom.packages.activatePackage('atom-elixir').then (pack) ->
          mainModule = pack.mainModule
      ]

    waitsFor 'provider to be registered', 1000, ->
      autocompleteManager?.providerManager.providers.length > 0

    waitsFor 'beam file to be created', 3000, ->
      try fs.statSync(editor.getPath())

    waitsFor 'server to be ready', 3000, ->
      mainModule.autocompleteProvider.server.testing = true
      mainModule.autocompleteProvider.server.ready

  describe 'autocomplete suggestions', ->

    it 'lists variables and functions with empty hint', ->
      runs ->
        editor.setCursorBufferPosition(positionInModule)
        atom.commands.dispatch(editorView, 'autocomplete-plus:activate')

      waitsForAutocompleteView(editorView)
      expectListTexts editorView, ['top_level_var', 'abs(number)', 'alias(module, opts)']

    it 'lists variables and functions', ->
      runs ->
        editor.setCursorBufferPosition(positionInModule)
        writeText(editor, 'to')

      waitsForAutocompleteView(editorView)
      expectListTexts editorView, ['top_level_var', 'to_atom(char_list)', 'to_char_list(arg)']

    it 'lists Elixir modules', ->
      runs ->
        editor.setCursorBufferPosition(positionInModule)
        writeText(editor, 'L')

      waitsForAutocompleteView(editorView)
      expectListTexts editorView, ['List', 'Logger']

    it 'lists Erlang modules', ->
      runs ->
        editor.setCursorBufferPosition(positionInModule)
        writeText(editor, ':l')

      waitsForAutocompleteView(editorView)
      expectListTexts editorView, [':lib', ':lists']

    it "lists Elixir module's functions", ->
      runs ->
        editor.setCursorBufferPosition(positionInModule)
        writeText(editor, 'List.')

      waitsForAutocompleteView(editorView)
      expectListTexts editorView, ['Chars', 'delete(list, item)', 'delete_at(list, index)']

    it "lists Erlang module's functions", ->
      runs ->
        editor.setCursorBufferPosition(positionInModule)
        writeText(editor, ':lists.')

      waitsForAutocompleteView(editorView)
      expectListTexts editorView, ['all/2', 'any/2']

    it 'lists functions from alias', ->
      runs ->
        editor.setCursorBufferPosition(positionInModule)
        writeText(editor, 'My')

      waitsForAutocompleteView(editorView)
      expectListTexts editorView, ['MyEnum', 'MyEnum.EmptyError', 'MyEnum.OutOfBoundsError', 'MyEnum.__info__/1']

    it 'lists module attributes, local variables and macro/functions when cursor inside a function', ->
      runs ->
        editor.setCursorBufferPosition(positionInPublicFunc)
        editor.insertNewline()
        atom.commands.dispatch(editorView, 'autocomplete-plus:activate')

      waitsForAutocompleteView(editorView)
      expectListTexts editorView, ['module_attr', 'module_var', 'abs(number)']

    describe "lists Elixir module's submodules and functions when the module is the only suggestion", ->

      it "lists with partial module name hint", ->
        runs ->
          editor.setCursorBufferPosition(positionInModule)
          writeText(editor, 'Li')

        waitsForAutocompleteView(editorView)
        expectListTexts editorView, ['List', 'List.Chars', 'List.__info__/1', 'List.delete(list, item)']

      it "lists with full module name hint", ->
        runs ->
          editor.setCursorBufferPosition(positionInModule)
          writeText(editor, 'List')

        waitsForAutocompleteView(editorView)
        expectListTexts editorView, ['List', 'List.Chars', 'List.__info__/1', 'List.delete(list, item)']

    describe "lists Erlang module's functions when the module is the only suggestion", ->

      it "lists with partial module name hint", ->
        runs ->
          editor.setCursorBufferPosition(positionInModule)
          writeText(editor, ':lis')

        waitsForAutocompleteView(editorView)
        expectListTexts editorView, [':lists', ':lists.all/2']

      it "lists with full module name hint", ->
        runs ->
          editor.setCursorBufferPosition(positionInModule)
          writeText(editor, ':lists')

        waitsForAutocompleteView(editorView)
        expectListTexts editorView, [':lists', ':lists.all/2']
