const { Range } = require('atom');

function getWordAndRange(editor, position, wordRegExp) {
  let wordAndRange = { word: '', range: new Range(position, position) };

  const buffer = editor.getBuffer();
  buffer.scanInRange(wordRegExp, buffer.rangeForRow(position.row), (data) => {
    if (data.range.containsPoint(position)) {
      wordAndRange = { word: data.matchText, range: data.range };
      data.stop();
    } else if (data.range.end.column > position.column) {
      data.stop();
    }
  });

  return wordAndRange;
}

function getSubjectAndMarkerRange(editor, bufferPosition) {
  // wordRegExp is based on atom.workspace.getActiveTextEditor().getLastCursor().wordRegExp()
  const wordRegExp = /^[	 ]*$|[^\s/\\()"':,.;<>~!@#$%^&*|+=[\]{}`?\-…]+|[/\\()"':,.;<>~!@#$%^&*|+=[\]{}`?\-…]+/g;
  const { word, range } = getWordAndRange(editor, bufferPosition, wordRegExp);

  if (editor.getGrammar().scopeName !== 'source.elixir') {
    return null;
  }

  if (!word.match(/[a-zA-Z_]/) || word.match(/:$/)) {
    return null;
  }

  const line = editor.getTextInRange([[range.start.row, 0], range.end]);
  const regex = /[\w0-9._!?:@]+$/;
  const matches = line.match(regex);
  const subject = (matches && matches[0]) || '';

  if (['do', 'fn', 'end', 'false', 'true', 'nil'].indexOf(word) > -1) {
    return null;
  }

  return { subject, range };
}

function gotoFirstNonCommentPosition(editor) {
  const searchRange = new Range(editor.getCursorBufferPosition(),
                                editor.getBuffer().getEndPosition());
  const line = editor.getLastCursor().getCurrentBufferLine();
  if (line.match(/@doc """/)) {
    editor.scanInBufferRange(/@doc """[\s\S]+?"""\s*/, searchRange, ({ range, stop }) => {
      editor.setCursorBufferPosition(range.end);
      editor.scrollToScreenPosition(range.end, { center: true });
      stop();
    });
  } else {
    editor.scanInBufferRange(/\S/, searchRange, ({ range, stop }) => {
      editor.setCursorBufferPosition(range.start);
      editor.scrollToScreenPosition(range.start, { center: true });
      stop();
    });
  }
}

module.exports = { getSubjectAndMarkerRange, gotoFirstNonCommentPosition };
