{splitModuleAndFunc} = require './utils'
{getSubjectAndMarkerRange, gotoFirstNonCommentPosition} = require './editor-utils'
{Disposable, CompositeDisposable, Range} = require 'atom'
KeyClickEventHandler = require './keyclick-event-handler'

module.exports =
class ElixirGotoDefinitionProvider

  constructor: ->
    @subscriptions = new CompositeDisposable
    @gotoStack = []
    sourceElixirSelector = 'atom-text-editor:not(mini)[data-grammar^="source elixir"]'

    @subscriptions.add atom.commands.add sourceElixirSelector, 'atom-elixir:goto-definition', =>
      editor = atom.workspace.getActiveTextEditor()
      position = editor.getCursorBufferPosition()
      subjectAndMarkerRange = getSubjectAndMarkerRange(editor, position)
      if subjectAndMarkerRange != null
        @gotoDefinition(editor, subjectAndMarkerRange.subject, position)

    @subscriptions.add atom.commands.add 'atom-text-editor:not(mini)', 'atom-elixir:return-from-definition', =>
      previousPosition = @gotoStack.pop()
      return unless previousPosition?
      [file, position] = previousPosition
      atom.workspace.open(file, {searchAllPanes: true}).then (editor) ->
        return unless position?
        editor.setCursorBufferPosition(position)
        editor.scrollToScreenPosition(position, {center: true})

    @subscriptions.add atom.workspace.observeTextEditors (editor) =>
      if (editor.getGrammar().scopeName != 'source.elixir')
        return
      keyClickEventHandler = new KeyClickEventHandler(editor, @keyClickHandler)

      editorDestroyedSubscription = editor.onDidDestroy =>
        editorDestroyedSubscription.dispose()
        keyClickEventHandler.dispose()

      @subscriptions.add(editorDestroyedSubscription)

  dispose: ->
    @subscriptions.dispose()

  setServer: (server) ->
    @server = server

  keyClickHandler: (editor, subject, position) =>
    @gotoDefinition(editor, subject, position)

  gotoDefinition: (editor, subject, position) ->
    filePath   = editor.getPath()
    line       = position.row + 1
    bufferText = editor.buffer.getText()
    @gotoStack.push([editor.getPath(), position])

    [mod, fun] = splitModuleAndFunc(subject)
    expr = "#{mod || 'nil'},#{fun || 'nil'}"

    @server.getDefinitionFile expr, filePath, bufferText, line, (file) ->

      switch file
        when 'non_existing'
          # atom.notifications.addInfo("Can't find <b>#{subject}</b>");
          console.log "Can't find \"#{subject}\""
          return
        when 'preloaded'
          # atom.notifications.addInfo("Module <b>#{subject}</b> is preloaded");
          console.log "Module \"#{subject}\" is preloaded"
          return
        when ''
          return

      pane = atom.workspace.getActivePane()
      [file_path, line] = file.split(':')
      atom.workspace.open(file_path, {initialLine: parseInt(line-1 || 0), searchAllPanes: true}).then (editor) ->
        pane.activateItem(editor)
        gotoFirstNonCommentPosition(editor)
