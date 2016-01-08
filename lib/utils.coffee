os = require('os')
fs = require('fs')

module.exports =

  getWordAndRange: (editor, position, wordRegExp) ->
    wordAndRange = { word: '', range: new Range(position, position) }
    buffer = editor.getBuffer()
    buffer.scanInRange wordRegExp, buffer.rangeForRow(position.row), (data) ->
      if data.range.containsPoint(position)
        wordAndRange = { word: data.matchText, range: data.range }
        data.stop()
      else if data.range.end.column > position.column
        data.stop()
    return wordAndRange

  createTempFile: (content) ->
    tmpFile = os.tmpdir() + Math.random().toString(36).substr(2, 9)
    fs.writeFileSync(tmpFile, content)
    tmpFile
