const os = require('os');
const fs = require('fs');
const marked = require('marked');

function markdownToHTML(markdownSource) {
  marked.setOptions({
    renderer: new marked.Renderer(),
    gfm: true,
    tables: true,
    breaks: false,
    pedantic: false,
    sanitize: true,
    smartLists: true,
    smartypants: false,
  });
  return marked(markdownSource);
}

function createTempFile(content) {
  const randomName = Math.random().toString(36).substr(2, 9);
  const tempFile = `${os.tmpdir()}/${randomName}`;
  fs.writeFileSync(tempFile, content);
  return tempFile;
}

function isFunction(word) {
  return word.match(/^[^A-Z:]/) != null;
}

function splitModuleAndFunc(text) {
  const names = text.split('.');
  const lastName = names.pop();

  let func = null;
  if (isFunction(lastName)) {
    func = lastName;
  } else {
    names.concat(lastName);
  }

  let mod = null;
  if (names.length > 0) {
    mod = names.join('.').replace(/\.$/, '');
  }

  return [mod, func];
}

function getDocURL(mod, func, arity) {
  // TODO: Retrieve from the environment or from the server process
  const elixirVersion = '1.4';

  let erlangFunction = '';
  let elixirFunction = '';
  if (func && arity) {
    erlangFunction = `${func}-${arity}`;
    elixirFunction = `${func}/${arity}`;
  }

  if (mod && mod.match(/^:/)) {
    const module = mod.replace(/^:/, '');
    return `http://www.erlang.org/doc/man/${module}.html#${erlangFunction}`;
  } else {
    const module = mod || 'Kernel';
    return `https://hexdocs.pm/elixir/${elixirVersion}/${module}.html#${elixirFunction}`;
  }
}

function isSpec(text) {
  return text.startsWith('@spec') ||
    text.startsWith('@type') ||
    text.startsWith('@callback') ||
    text.startsWith('@macrocallback');
}

function convertCodeBlocksToAtomEditors(domFragment) {
  const fontFamily = atom.config.get('editor.fontFamily');
  if (fontFamily) {
    domFragment.querySelectorAll('code').forEach((element) => {
      const codeElement = element;
      codeElement.style.fontFamily = fontFamily;
    });
  }

  domFragment.querySelectorAll('pre, code').forEach((element) => {
    const preElement = element;

    if (preElement.tagName === 'PRE' || (preElement.tagName === 'CODE' && isSpec(preElement.innerText))) {
      const editorElement = document.createElement('atom-text-editor');
      editorElement.setAttributeNode(document.createAttribute('gutter-hidden'));
      editorElement.removeAttribute('tabindex'); // make read-only

      preElement.parentNode.insertBefore(editorElement, preElement);
      preElement.remove();

      const editor = editorElement.getModel();
      editor.setSoftWrapped(true);

      // remove the default selection of a line in each editor
      editor.getDecorations({ class: 'cursor-line', type: 'line' })[0].destroy();

      if (preElement.firstElementChild) {
        editor.setText(preElement.textContent.trim());
      }

      const grammar = atom.grammars.grammarForScopeName('source.elixir');
      if (grammar) {
        editor.setGrammar(grammar);
      }
    }
  });

  return domFragment;
}

module.exports = {
  markdownToHTML,
  createTempFile,
  splitModuleAndFunc,
  getDocURL,
  convertCodeBlocksToAtomEditors,
};
