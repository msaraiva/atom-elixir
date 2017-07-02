const path = require('path');

const { Emitter, Disposable, CompositeDisposable, File } = require('atom');
const { $, ScrollView } = require('atom-space-pen-views');

module.exports = class ElixirExpandedView extends ScrollView {
  static content() {
    const createEditor = () => {
      const element = document.createElement('atom-text-editor');
      element.setAttribute('tabIndex', 0);

      const editor = element.getModel();
      editor.setLineNumberGutterVisible(true);
      editor.setGrammar(atom.grammars.grammarForScopeName('source.elixir'));
      return element;
    };

    const expandOnceCodeEditorElement = createEditor();
    expandOnceCodeEditorElement.setAttribute('mini', true);
    expandOnceCodeEditorElement.removeAttribute('tabindex');

    const expandCodeEditorElement = createEditor();
    expandCodeEditorElement.setAttribute('mini', true);
    expandCodeEditorElement.removeAttribute('tabindex');

    const expandPartialCodeEditorElement = createEditor();
    expandPartialCodeEditorElement.setAttribute('mini', true);
    expandPartialCodeEditorElement.removeAttribute('tabindex');

    const expandAllCodeEditorElement = createEditor();
    expandAllCodeEditorElement.setAttribute('mini', true);
    expandAllCodeEditorElement.removeAttribute('tabindex');

    this.div({ class: 'elixir-expand-view native-key-bindings', tabindex: -1 }, () => {
      this.div({ class: 'header' }, () => {
        this.div({ class: 'btn-group btn-group-sm viewButtons pull-left', style: 'margin-bottom: 8px;' }, () => {
          this.button({ class: 'btn expandOnce' }, 'Expand Once');
          this.button({ class: 'btn expand selected' }, 'Expand');
          this.button({ class: 'btn expandPartial' }, 'Expand Partial');
          this.button({ class: 'btn expandAll' }, 'Expand All');
        });
        this.hr({ style: 'clear: both;' });
      });
      this.div({ class: 'markdownContent expandOnceContent', style: 'display: none' }, () => {
        this.section({ class: 'input-block' }, () => {
          this.subview('expandOnceCodeEditorElement', expandOnceCodeEditorElement);
        });
      });
      this.div({ class: 'markdownContent expandContent' }, () => {
        this.section({ class: 'input-block' }, () => {
          this.subview('expandCodeEditorElement', expandCodeEditorElement);
        });
      });
      this.div({ class: 'markdownContent expandPartialContent', style: 'display: none' }, () => {
        this.section({ class: 'input-block' }, () => {
          this.subview('expandPartialCodeEditorElement', expandPartialCodeEditorElement);
        });
      });
      this.div({ class: 'markdownContent expandAllContent', style: 'display: none' }, () => {
        this.section({ class: 'input-block' }, () => {
          this.subview('expandAllCodeEditorElement', expandAllCodeEditorElement);
        });
      });
    });
  }

  constructor({ buffer, code, line }) {
    super();
    this.buffer = buffer;
    this.code = code;
    this.line = line;
    this.disposables = new CompositeDisposable();
  }

  initialize() {
    this.expandOnceCodeEditor = this.expandOnceCodeEditorElement.getModel();
    this.expandOnceCodeEditor.setSoftWrapped(true);
    this.expandOnceCodeEditor.getDecorations({ class: 'cursor-line', type: 'line' })[0].destroy();

    this.expandCodeEditor = this.expandCodeEditorElement.getModel();
    this.expandCodeEditor.setSoftWrapped(true);
    this.expandCodeEditor.getDecorations({ class: 'cursor-line', type: 'line' })[0].destroy();

    this.expandPartialCodeEditor = this.expandPartialCodeEditorElement.getModel();
    this.expandPartialCodeEditor.setSoftWrapped(true);
    this.expandPartialCodeEditor.getDecorations({ class: 'cursor-line', type: 'line' })[0].destroy();

    this.expandAllCodeEditor = this.expandAllCodeEditorElement.getModel();
    this.expandAllCodeEditor.setSoftWrapped(true);
    this.expandAllCodeEditor.getDecorations({ class: 'cursor-line', type: 'line' })[0].destroy();
  }

  attached() {
    if (this.isAttached) {
      return;
    }
    this.isAttached = true;

    const resolve = () => {
      this.refreshView();
      this.handleEvents();
    };

    if (atom.workspace) {
      resolve();
    } else {
      this.disposables.add(atom.packages.onDidActivateInitialPackages(resolve));
    }
  }

  serialize() {
    return {
      deserializer: 'ElixirExpandView',
      source: this.code,
    };
  }

  destroy() {
    this.disposables.dispose();
  }

  handleEvents() {
    const unselectAllButtons = () => {
      $(this.element.querySelector('.viewButtons').children).removeClass('selected');
    };

    const renderExpandOnce = this.renderExpandOnce.bind(this);
    const renderExpand = this.renderExpand.bind(this);
    const renderExpandPartial = this.renderExpandPartial.bind(this);
    const renderExpandAll = this.renderExpandAll.bind(this);

    this.on('click', '.expandOnce', () => {
      unselectAllButtons();
      $(this).addClass('selected');
      renderExpandOnce();
    });
    this.on('click', '.expand', () => {
      unselectAllButtons();
      $(this).addClass('selected');
      renderExpand();
    });
    this.on('click', '.expandPartial', () => {
      unselectAllButtons();
      $(this).addClass('selected');
      renderExpandPartial();
    });
    this.on('click', '.expandAll', () => {
      unselectAllButtons();
      $(this).addClass('selected');
      renderExpandAll();
    });

    this.disposables.add(this.addEventHandler(this.element, 'keyup', this.keyupHandler.bind(this)));
  }

  keyupHandler(event) {
    if ([37, 39].includes(event.keyCode)) {
      const selectedButton = this.element.querySelector('.viewButtons .selected');
      const allButtons = this.element.querySelectorAll('.viewButtons .btn');
      const allButtonsArray = Array.prototype.slice.call(allButtons);
      const index = allButtonsArray.indexOf(selectedButton);
      if (event.keyCode === 37 /* left */) {
        $(allButtonsArray[Math.max(0, index - 1)]).click();
      } else if (event.keyCode === 39 /* right */) {
        $(allButtonsArray[Math.min(allBtnsArray.length - 1, index + 1)]).click();
      }
    }
  }

  addEventHandler(element, eventName, handler) {
    element.addEventListener(eventName, handler);
    return new Disposable(() => element.removeEventListener(eventName, handler));
  }

  renderExpandOnce() {
    $(this.element.querySelectorAll('.markdownContent')).css('display', 'none');
    this.element.querySelector('.expandOnceContent').style.display = '';
  }

  renderExpand() {
    $(this.element.querySelectorAll('.markdownContent')).css('display', 'none');
    this.element.querySelector('.expandContent').style.display = '';
  }

  renderExpandPartial() {
    $(this.element.querySelectorAll('.markdownContent')).css('display', 'none');
    this.element.querySelector('.expandPartialContent').style.display = '';
  }

  renderExpandAll() {
    $(this.element.querySelectorAll('.markdownContent')).css('display', 'none');
    this.element.querySelector('.expandAllContent').style.display = '';
  }

  setExpandFullGetter(getter) {
    this.expandFullGetter = getter;
  }

  setExpandOnceCode(code) {
    this.expandOnceCode = code;
    this.expandOnceCodeEditor.setText(this.expandOnceCode);
  }

  setExpandCode(code) {
    this.expandCode = code;
    this.expandCodeEditor.setText(this.expandCode);
  }

  setExpandPartialCode(code) {
    this.expandPartialCode = code;
    this.expandPartialCodeEditor.setText(this.expandPartialCode);
  }

  setExpandAllCode(code) {
    this.expandAllCode = code;
    this.expandAllCodeEditor.setText(this.expandAllCode);
  }

  setBuffer(buffer) {
    this.buffer = buffer;
  }

  setLine(line) {
    this.line = line;
  }

  setCode(code) {
    this.code = code;
    this.expandFullGetter(this.buffer, this.code, this.line, (result) => {
      const {
        expand_once: expandOnce,
        expand,
        expand_partial: expandPartial,
        expand_all: expandAll,
      } = result;
      this.setExpandOnceCode(expandOnce ? expandOnce.trim() : '');
      this.setExpandCode(expand ? expand.trim() : '');
      this.setExpandPartialCode(expandPartial ? expandPartial.trim() : '');
      this.setExpandAllCode(expandAll ? expandAll.trim() : '');
      this.refreshView();
    });
  }

  refreshView() {
    if (this.expandOnceCode) {
      this.expandOnceCodeEditor.setText(this.expandOnceCode);
    }
    if (this.expandCode) {
      this.expandCodeEditor.setText(this.expandCode);
    }
    if (this.expandPartialCode) {
      this.expandPartialCodeEditor.setText(this.expandPartialCode);
    }
    if (this.expandAllCode) {
      this.expandAllCodeEditor.setText(this.expandAllCode);
    }
  }

  getTitle() {
    return 'Expand Macro';
  }

  getIconName() {
    return 'file-text';
  }

  getURI() {
    return 'atom-elixir://elixir-expand-views/view';
  }
};
