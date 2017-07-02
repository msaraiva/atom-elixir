const path = require('path');
const { markdownToHTML, getDocURL, splitModuleAndFunc, convertCodeBlocksToAtomEditors } = require('./utils');

const { Emitter, Disposable, CompositeDisposable, File } = require('atom');
const { $, ScrollView } = require('atom-space-pen-views');

module.exports = class ElixirDocsView extends ScrollView {
  static content() {
    this.div({ class: 'elixir-docs-view native-key-bindings', tabindex: -1 }, () => {
      this.div({ class: 'header' }, () => {
        this.div({ class: 'btn-group btn-group-sm viewButtons pull-left', style: 'margin-bottom: 8px;' }, () => {
          this.button({ class: 'btn selected docs' }, 'Docs');
          this.button({ class: 'btn types' }, 'Types');
          this.button({ class: 'btn callbacks' }, 'Callbacks');
        });
        this.a({ class: 'link pull-right', style: 'margin-top: 14px;' }, 'See Online Docs');
        this.hr({ style: 'clear: both;' });
      });
      this.div({ class: 'markdownContent docsContent padded' });
      this.div({ class: 'markdownContent typesContent padded', style: 'display: none' });
      this.div({ class: 'markdownContent callbacksContent padded', style: 'display: none' });
    });
  }

  constructor({ viewId, source }) {
    super();
    this.viewId = viewId;
    this.source = source;
    this.disposables = new CompositeDisposable();
  }

  attached() {
    if (this.isAttached) {
      return;
    }
    this.isAttached = true;

    const resolve = () => {
      this.handleEvents();
      this.renderMarkdown();
    };

    if (atom.workspace) {
      resolve();
    } else {
      this.disposables.add(atom.packages.onDidActivateInitialPackages(resolve));
    }
  }

  serialize() {
    return {
      deserializer: 'ElixirDocsView',
      viewId: this.viewId,
      source: this.source,
    };
  }

  destroy() {
    this.disposables.dispose();
  }

  handleEvents() {
    atom.commands.add(this.element, {
      'core:move-up': () =>
        this.scrollUp(),
      'core:move-down': () =>
        this.scrollDown(),
      'core:copy': (event) => {
        if (this.copyToClipboard()) {
          event.stopPropagation();
        }
      },
    });

    const unselectAllButtons = () => {
      $(this.element.querySelector('.viewButtons').children).removeClass('selected');
    };

    const renderDocs = this.renderDocs.bind(this);
    const renderTypes = this.renderTypes.bind(this);
    const renderCallbacks = this.renderCallbacks.bind(this);

    const getModFuncArity = () => {
      const [mod0, func] = splitModuleAndFunc(this.viewId);
      let mod = mod0;
      const docSubject = this.element.querySelector('.docsContent blockquote p').innerText;
      const [docMod, docFunc] = splitModuleAndFunc(docSubject.replace(/\(.*\)/, ''));
      if (mod !== docMod) {
        mod = docMod;
      }

      let arity;
      if (func) {
        arity = docSubject.split(',').length;
      }
      return [mod, func, arity];
    };

    this.on('click', '.docs', () => {
      unselectAllButtons();
      $(this).addClass('selected');
      renderDocs();
    });
    this.on('click', '.types', () => {
      unselectAllButtons();
      $(this).addClass('selected');
      renderTypes();
    });
    this.on('click', '.callbacks', () => {
      unselectAllButtons();
      $(this).addClass('selected');
      renderCallbacks();
    });
    this.on('click', '.header .link', () => {
      [mod, func, arity] = getModFuncArity();
      require('shell').openExternal(getDocURL(mod, func, arity));
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

  setSource(source) {
    this.source = source;
    this.docs = this.source.docs;
    this.types = this.source.types;
    this.callbacks = this.source.callbacks;

    if (this.types) {
      this.types = `> Types\n\n____\n\n${this.types}`;
    } else {
      this.types = 'No type information available.';
    }

    this.callbacks = this.callbacks || 'No callback information available.';

    const docsElement = this.element.querySelector('.docsContent');
    docsElement.innerHTML = markdownToHTML(this.docs);
    convertCodeBlocksToAtomEditors(docsElement);

    const typesElement = this.element.querySelector('.typesContent');
    typesElement.innerHTML = markdownToHTML(this.types);
    convertCodeBlocksToAtomEditors(typesElement);

    const callbacksElement = this.element.querySelector('.callbacksContent');
    callbacksElement.innerHTML = markdownToHTML(this.callbacks);
    convertCodeBlocksToAtomEditors(callbacksElement);

    this.renderMarkdown();
  }

  renderMarkdown() {
    if (this.source) {
      return;
    }

    this.renderDocs();
  }

  renderDocs() {
    $(this.element.querySelectorAll('.markdownContent')).css('display', 'none');
    this.element.querySelector('.docsContent').style.display = '';
  }

  renderTypes() {
    $(this.element.querySelectorAll('.markdownContent')).css('display', 'none');
    this.element.querySelector('.typesContent').style.display = '';
  }

  renderCallbacks() {
    $(this.element.querySelectorAll('.markdownContent')).css('display', 'none');
    this.element.querySelector('.callbacksContent').style.display = '';
  }

  getTitle() {
    return `Elixir Docs - ${this.viewId}`;
  }

  getIconName() {
    return 'file-text';
  }

  getURI() {
    return `atom-elixir://elixir-docs-views/${this.viewId}`;
  }

  copyToClipboard() {
    const selection = window.getSelection();
    const selectedText = selection.toString();
    atom.clipboard.write(selectedText);
    return true;
  }
};
