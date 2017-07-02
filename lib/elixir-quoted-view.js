const path = require('path');

const { Emitter, Disposable, CompositeDisposable, File } = require('atom');
const { ScrollView } = require('atom-space-pen-views');

module.exports = class ElixirQuotedView extends ScrollView {

  static content() {
    const createEditor = () => {
      const element = document.createElement('atom-text-editor');
      element.setAttribute('tabIndex', 0);

      const editor = element.getModel();
      editor.setLineNumberGutterVisible(true);
      editor.setGrammar(atom.grammars.grammarForScopeName('source.elixir'));

      atom.commands.add(element, {
        'core:move-up': () =>
          editor.moveUp(),
        'core:move-down': () =>
          editor.moveDown(),
        'editor:newline': () =>
          editor.insertText('\n'),
        'core:move-to-top': () =>
          editor.moveToTop(),
        'core:move-to-bottom': () =>
          editor.moveToBottom(),
        'core:select-to-top': () =>
          editor.selectToTop(),
        'core:select-to-bottom': () =>
          editor.selectToBottom(),
      });

      return element;
    };

    const codeEditorElement = createEditor();
    codeEditorElement.setAttribute('mini', true);

    const quotedCodeEditorElement = createEditor();
    quotedCodeEditorElement.setAttribute('mini', true);

    const patternEditorElement = createEditor();
    patternEditorElement.setAttribute('mini', true);

    const matchesEditorElement = createEditor();
    matchesEditorElement.setAttribute('mini', true);
    matchesEditorElement.removeAttribute('tabindex');

    this.div({ class: 'elixir-quoted-view', style: 'overflow: scroll;' }, () => {
      this.div({ class: 'padded' }, () => {
        this.header('Code', { class: 'header' });
        this.section({ class: 'input-block' }, () => {
          this.subview('codeEditorElement', codeEditorElement);
        });

        this.header('Quoted form', { class: 'header' });
        this.section({ class: 'input-block' }, () => {
          this.subview('quotedCodeEditorElement', quotedCodeEditorElement);
        });

        this.header('Pattern Matching', { class: 'header' });
        this.section({ class: 'input-block' }, () => {
          this.subview('patternEditorElement', patternEditorElement);
        });

        this.section({ class: 'input-block matchesEditorSection' }, () => {
          this.subview('matchesEditorElement', matchesEditorElement);
        });
      });
    });
  }

  constructor({ code, quotedCode }) {
    super();
    this.quotedCode = quotedCode;
    this.disposables = new CompositeDisposable();
    this.handleEvents();
  }

  initialize() {
    this.codeEditor = this.codeEditorElement.getModel();
    this.codeEditor.placeholderText = 'Elixir code. e.g. func(42, "meaning of life")';
    this.codeEditor.onDidChange((e) => {
      this.code = this.codeEditor.getText();
      if (this.quotedCodeGetter) {
        this.quotedCodeGetter(this.code, (result) => {
          this.setQuotedCode(result);
        });
      }
    });

    this.quotedCodeEditor = this.quotedCodeEditorElement.getModel();
    this.quotedCodeEditor.placeholderText = 'Elixir code in quoted form. e.g. {:func, [line: 1], [42, "meaning of life"]}';
    this.quotedCodeEditor.onDidChange((e) => {
      this.quotedCode = this.quotedCodeEditor.getText();
      if (this.matchesGetter) {
        this.matchesGetter(this.patternEditor.getText(), this.quotedCode, (result) => {
          this.matchesEditor.setText(result);
        });
      }
    });

    this.patternEditor = this.patternEditorElement.getModel();
    this.patternEditor.setSoftWrapped(true);
    this.patternEditor.getDecorations({ class: 'cursor-line', type: 'line' })[0].destroy();
    this.patternEditor.setLineNumberGutterVisible(false);
    this.patternEditor.placeholderText = 'Pattern matching against quoted form. e.g. {name, [line: line], args}';
    this.patternEditor.onDidChange((e) => {
      if (this.matchesGetter) {
        this.matchesGetter(this.patternEditor.getText(), this.quotedCode, (result) => {
          this.matchesEditor.setText(result);
        });
      }
    });

    this.matchesEditor = this.matchesEditorElement.getModel();
    this.matchesEditor.setSoftWrapped(true);
    this.matchesEditor.getDecorations({ class: 'cursor-line', type: 'line' })[0].destroy();
    this.matchesEditor.setLineNumberGutterVisible(false);
  }

  handleEvents() {
    this.disposables.add(atom.commands.add(this.element, {
      'elixir-quoted-view:focus-next': () => this.focusNextElement(1),
      'elixir-quoted-view:focus-previous': () => this.focusNextElement(-1),
    }));
  }

  attached() {
    if (this.isAttached) {
      return;
    }
    this.isAttached = true;

    const resolve = () => {
      this.refreshView();
    };

    if (atom.workspace) {
      resolve();
    } else {
      this.disposables.add(atom.packages.onDidActivateInitialPackages(resolve));
    }
  }

  serialize() {
    return {
      deserializer: 'ElixirQuotedView',
      source: this.quotedCode,
    };
  }

  destroy() {
    this.disposables.dispose();
  }

  setQuotedCodeGetter(quotedCodeGetter) {
    this.quotedCodeGetter = quotedCodeGetter;
  }

  setMatchesGetter(matchesGetter) {
    this.matchesGetter = matchesGetter;
  }

  setQuotedCode(quotedCode) {
    this.quotedCode = quotedCode;
    this.quotedCodeEditor.setText(this.quotedCode);
  }

  setCode(code) {
    this.code = code;
    this.codeEditor.setText(this.code);
  }

  refreshView() {
    if (this.quotedCode) {
      this.quotedCodeEditor.setText(this.quotedCode);
    }
  }

  getTitle() {
    return 'Quoted Code';
  }

  getIconName() {
    return 'file-text';
  }

  getURI() {
    return 'atom-elixir://elixir-quoted-views/view';
  }

  focusNextElement(direction) {
    const elements = [
      this.codeEditorElement,
      this.quotedCodeEditorElement,
      this.patternEditorElement,
    ];
    const focusedElement = elements.find(el => Array.from(el.classList).includes('is-focused'));

    let focusedIndex = elements.indexOf(focusedElement);
    focusedIndex += direction;
    if (focusedIndex >= elements.length) {
      focusedIndex = 0;
    }
    if (focusedIndex < 0) {
      focusedIndex = elements.length - 1;
    }

    elements[focusedIndex].focus();
  }
};
