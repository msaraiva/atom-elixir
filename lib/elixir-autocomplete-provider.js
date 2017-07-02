const { CompositeDisposable } = require('atom');
const { markdownToHTML, convertCodeBlocksToAtomEditors } = require('./utils');

module.exports = class ElixirAutocompleteProvider {

  constructor() {
    this.selector = '.source.elixir';
    // this.disableForSelector = '.source.elixir .comment';
    this.inclusionPriority = 1;
    this.excludeLowerPriority = false;

    this.subscriptions = new CompositeDisposable();
    this.config = {};
    this.subscriptions.add(atom.config.observe('atom-elixir.enableSuggestionSnippet', (value) => {
      this.config.enableSuggestionSnippet = value;
    }));
    this.subscriptions.add(atom.config.observe('atom-elixir.addParenthesesAfterSuggestionConfirmed', (value) => {
      this.config.addParenthesesAfterSuggestionConfirmed = value;
    }));
    this.subscriptions.add(atom.config.observe('atom-elixir.showSignatureInfoAfterSuggestionConfirm', (value) => {
      this.config.showSignatureInfoAfterSuggestionConfirm = value;
    }));

    this.subscriptions.add(atom.config.observe('autocomplete-plus.minimumWordLength', () => this.minimumWordLength));

    this.subscriptions.add(atom.commands.add('atom-text-editor:not(mini)[data-grammar^="source elixir"]', {
      // Replacing default autocomplete 'tab' key so that the snippet's tab-stops have precedence
      'atom-elixir:autocomplete-tab': (event) => {
        const editor = atom.workspace.getActiveTextEditor();
        let snippets;
        if (atom.packages.getActivePackage('snippets')) {
          snippets = atom.packages.getActivePackage('snippets').mainModule;
        }

        if (snippets && snippets.goToNextTabStop(editor)) {
          atom.commands.dispatch(atom.views.getView(editor), 'autocomplete-plus:cancel');
        } else {
          event.abortKeyBinding();
          atom.commands.dispatch(atom.views.getView(editor), 'autocomplete-plus:confirm');
        }
      },
      // Replacing default autocomplete 'enter' key so that
      // tab-stops keep working properly after 'enter'
      'atom-elixir:autocomplete-enter': (event) => {
        const editor = atom.workspace.getActiveTextEditor();
        let snippets;
        if (atom.packages.getActivePackage('snippets')) {
          snippets = atom.packages.getActivePackage('snippets').mainModule;
        }
        if (snippets && snippets.goToNextTabStop(editor)) {
          atom.commands.dispatch(atom.views.getView(editor), 'snippets:previous-tab-stop');
        }
        atom.commands.dispatch(atom.views.getView(editor), 'autocomplete-plus:confirm');
      },
    }));
  }

  dispose() {
    this.subscriptions.dispose();
  }

  onDidInsertSuggestion({ editor, triggerPosition, suggestion }) {
    if (this.config.showSignatureInfoAfterSuggestionConfirm) {
      atom.commands.dispatch(atom.views.getView(editor), 'atom-elixir:show-signature');
    }
  }

  getSuggestions({ editor, bufferPosition, scopeDescriptor, activatedManually }) {
    const scopeChain = scopeDescriptor.getScopeChain();
    const editorElement = atom.views.getView(editor);
    if (scopeChain.match(/\.string\.quoted\./) || scopeChain.match(/\.comment/)) {
      if (!(activatedManually || Array.from(editorElement.classList).includes('autocomplete-active'))) {
        return null;
      }
    }

    const textBeforeCursor = editor.getTextInRange([[bufferPosition.row, 0], bufferPosition]);
    const prefix = this.getPrefix(textBeforeCursor);
    const pipeBefore = !!textBeforeCursor.match(new RegExp(`|>\s*${prefix}$`));
    const captureBefore = !!textBeforeCursor.match(new RegExp(`&${prefix}$`));
    let defBefore = null;
    if (textBeforeCursor.match(new RegExp(`def\s*${prefix}$`))) {
      defBefore = 'def';
    } else if (textBeforeCursor.match(new RegExp(`defmacro\s*${prefix}$`))) {
      defBefore = 'defmacro';
    }

    if (!activatedManually && prefix === '' && !defBefore) {
      return null;
    }

    // TODO: maybe we should have our own configuration for that
    // return unless prefix?.length >= @minimumWordLength

    return new Promise((resolve) => {
      const position = editor.getCursorBufferPosition();
      const buffer = editor.buffer.getText();
      const line = position.row + 1;
      const column = position.column + 1;

      if (!this.client) {
        console.log('ElixirSense client not ready');
        resolve([]);
        return;
      }

      this.client.send('suggestions', { buffer, line, column }, (result) => {
        const [suggestion0, ...suggestions0] = result;
        const hint = suggestion0.value;
        let suggestions = suggestions0;
        const modulesToAdd = [];
        let lastModuleHint;
        const isPrefixFunctionCall = !!(prefix.match(/\.[^A-Z][^.]*$/) || prefix.match(/^[^A-Z:][^.]*$/));

        if (prefix !== '' && !isPrefixFunctionCall) {
          const prefixModules = prefix.split('.').slice(0, -1);
          const hintModules = hint.split('.').slice(0, -1);

          if (!prefix.endsWith('.') || (`${prefixModules}` !== `${hintModules}`)) {
            for (let i = 0; i < hintModules.length; i += 1) {
              if (hintModules[i] !== prefixModules[i]) {
                modulesToAdd.push(hintModules[i]);
              }
            }
            lastModuleHint = hintModules[hintModules.length - 1];
          }
        }

        suggestions = suggestions.map((serverSuggestion0, index) => {
          const serverSuggestion = serverSuggestion0;
          const name = serverSuggestion.name;
          if (lastModuleHint && ![name, `:${name}`].includes(lastModuleHint) && modulesToAdd.length > 0) {
            serverSuggestion.name = `${modulesToAdd.join('.')}.${name}`;
          }
          return this.createSuggestion(serverSuggestion, index, prefix, pipeBefore,
            captureBefore, defBefore, this.config);
        });

        suggestions = suggestions.filter(item => item != null && item !== '');
        suggestions = this.sortSuggestions(suggestions);

        if (suggestions.length > 0) {
          atom.commands.dispatch(atom.views.getView(editor), 'atom-elixir:hide-signature');
        }

        resolve(suggestions);
      });
    });
  }

  getPrefix(textBeforeCursor) {
    const matches = textBeforeCursor.match(/[\w0-9._!?:@]+$/);
    if (matches) {
      return matches[0];
    } else {
      return '';
    }
  }

  createSuggestion(serverSuggestion, index, prefix, pipeBefore, captureBefore, defBefore, config) {
    let name;
    let kind;
    let subtype;
    let desc;
    let spec;
    let snippet;
    let signature;
    let mod;

    if (serverSuggestion.type === 'module') {
      [name, kind, subtype, desc] = [
        serverSuggestion.name,
        serverSuggestion.type,
        serverSuggestion.subtype,
        serverSuggestion.summary,
      ];
    } else if (serverSuggestion.type === 'return') {
      [name, kind, spec, snippet] = [
        serverSuggestion.name,
        serverSuggestion.type,
        serverSuggestion.spec,
        serverSuggestion.snippet,
      ];
    } else {
      [name, kind, signature, mod, desc, spec] = [
        serverSuggestion.name,
        serverSuggestion.type,
        serverSuggestion.args,
        serverSuggestion.origin,
        serverSuggestion.summary,
        serverSuggestion.spec,
      ];
    }

    if (defBefore && kind !== 'callback') {
      return '';
    }

    let suggestion;
    if (kind === 'attribute') {
      suggestion = this.createSuggestionForAttribute(name, prefix);
    } else if (kind === 'variable') {
      suggestion = this.createSuggestionForVariable(name);
    } else if (kind === 'module') {
      suggestion = this.createSuggestionForModule(serverSuggestion, name, desc, prefix, subtype);
    } else if (kind === 'callback') {
      suggestion = this.createSuggestionForCallback(serverSuggestion, `${name}/${serverSuggestion.arity}`, kind, signature, mod, desc, spec, prefix, defBefore);
    } else if (kind === 'return') {
      suggestion = this.createSuggestionForReturn(serverSuggestion, name, kind, spec, snippet);
    } else if (['private_function', 'public_function', 'public_macro'].indexOf(kind) > -1) {
      suggestion = this.createSuggestionForFunction(serverSuggestion, `${name}/${serverSuggestion.arity}`, kind, signature, '', desc, spec, prefix, pipeBefore, captureBefore, config);
    } else if (['function', 'macro'].indexOf(kind) > -1) {
      suggestion = this.createSuggestionForFunction(serverSuggestion, `${name}/${serverSuggestion.arity}`, kind, signature, mod, desc, spec, prefix, pipeBefore, captureBefore, config);
    } else {
      console.log('Unknown kind: #{serverSuggestion}');
      suggestion = {
        text: serverSuggestion,
        type: 'exception',
        iconHTML: '?',
        rightLabel: kind || 'hint',
      };
    }
    suggestion.index = index;

    return suggestion;
  }

  createSuggestionForAttribute(name, prefix) {
    let snippet;
    if (prefix.match(/^@/)) {
      snippet = name.replace(/^@/, '');
    } else {
      snippet = name;
    }

    return {
      snippet,
      displayText: name.slice(1),
      type: 'property',
      iconHTML: '@',
      rightLabel: 'attribute',
    };
  }

  createSuggestionForVariable(name) {
    return {
      text: name,
      displayText: name,
      type: 'variable',
      iconHTML: 'v',
      rightLabel: 'variable',
    };
  }

  createSuggestionForFunction(serverSuggestion, name, kind, signature, mod, desc,
    spec, prefix, pipeBefore, captureBefore, config) {
    const args = signature.split(',');
    const [_, func, arity] = name.match(/(.+)\/(\d+)/);
    const moduleParts = prefix.split('.');
    const postfix = moduleParts.pop();

    let params = [];
    let displayText = '';
    let snippet = func;
    let description = desc;

    if (signature) {
      params = args.map((arg, i) => `\${${i + 1}:${arg.replace(/\s+\\.*$/, '')}}`);
      displayText = `${func}(${args.join(', ')})`;
    } else {
      if (arity > 0) {
        params = [...Array(arity).keys()].map(i => `\${${i}:arg${i}}`);
      }
      displayText = `${func}/${arity}`;
    }

    let snippetParams = params;
    if (snippetParams.length > 0 && pipeBefore) {
      snippetParams = snippetParams.slice(1);
    }

    if (captureBefore) {
      snippet = `${func}/${arity}`;
    } else if (snippetParams.length > 0) {
      if (config.enableSuggestionSnippet) {
        snippet = `${func}(${snippetParams.join(', ')})`;
      } else if (!config.enableSuggestionSnippet && config.addParenthesesAfterSuggestionConfirmed === 'addOpeningParenthesis') {
        snippet = `${func}(`;
      } else if (!config.enableSuggestionSnippet && config.addParenthesesAfterSuggestionConfirmed === 'addParentheses') {
        snippet = `${func}(\${1})`;
      }
    }

    snippet = `${snippet.replace(/^:/, '')}$0`;

    let kindComponents;
    switch (kind) {
      case 'private_function':
        kindComponents = ['method', 'f', 'private'];
        break;
      case 'public_function':
        kindComponents = ['function', 'f', 'public'];
        break;
      case 'function':
        kindComponents = ['function', 'f', mod];
        break;
      case 'public_macro':
        kindComponents = ['package', 'm', 'public'];
        break;
      case 'macro':
        kindComponents = ['package', 'm', mod];
        break;
      default:
        kindComponents = ['unknown', '?', ''];
        break;
    }
    const [type, iconHTML, rightLabel] = kindComponents;

    if (prefix.match(/^:/)) {
      const [module, funcName] = moduleAndFuncName(moduleParts, func);
      description = 'No documentation available.';
    }

    return {
      func,
      arity,
      snippet,
      displayText,
      type,
      rightLabel,
      iconHTML,
      spec,
      summary: description,
    };
  }

  createSuggestionForCallback(serverSuggestion, name, kind, signature,
    mod, desc, spec, prefix, defBefore) {
    const args = signature.split(',');
    const [func, arity] = name.split('/');

    let params = [];
    let displayText = '';
    let snippet = func;
    let description = desc;

    if (signature) {
      params = args.map((arg, i) => `\${${i + 1}:${arg.replace(/\s+\\.*$/, '')}}`);
      displayText = `${func}(${args.join(', ')})`;
    } else {
      if (arity > 0) {
        params = [...Array(arity).keys()].map(i => `\${${i}:arg${i}}`);
      }
      displayText = `${func}/${arity}`;
    }

    snippet = `${func}(${params.join(', ')}) do\n\t$0\nend\n`;

    if (defBefore === 'def') {
      if (spec.startsWith('@macrocallback')) {
        return '';
      }
    } else if (defBefore === 'defmacro') {
      if (spec.startsWith('@callback')) {
        return '';
      }
    } else {
      let defString;
      if (spec.startsWith('@macrocallback')) {
        defString = 'defmacro';
      } else {
        defString = 'def';
      }
      snippet = `${defString} ${snippet}`;
    }

    const [type, iconHTML, rightLabel] = ['value', 'c', mod];

    if (desc === '') {
      description = 'No documentation available.';
    }

    return {
      func,
      arity,
      snippet,
      displayText,
      type,
      rightLabel,
      iconHTML,
      spec,
      summary: description,
    };
  }

  createSuggestionForReturn(serverSuggestion, name, kind, spec, snippet0) {
    const displayText = name;
    const snippet = `${snippet0.replace(/"(\$\{\d+:)/g, '$1').replace(/(\})\$"/g, '$1')}$0`;

    const [type, iconHTML, rightLabel] = ['value', 'r', 'return'];

    return {
      snippet,
      displayText,
      type,
      rightLabel,
      iconHTML,
      spec,
    };
  }

  createSuggestionForModule(serverSuggestion, name0, desc, prefix, subtype) {
    const snippet = name0.replace(/^:/, '');
    let name = name0;
    if (name.match(/^[^A-Z:]/)) {
      name = `:${name}`;
    }
    const description = desc || 'No documentation available.';

    let iconHTML;
    switch (subtype) {
      case 'protocol':
        iconHTML = 'P';
        break;
      case 'implementation':
        iconHTML = 'I';
        break;
      case 'exception':
        iconHTML = 'E';
        break;
      case 'struct':
        iconHTML = 'S';
        break;
      default:
        iconHTML = 'M';
        break;
    }

    return {
      snippet,
      displayText: name,
      type: 'class',
      iconHTML,
      summary: description,
      rightLabel: subtype || 'module',
    };
  }

  sortSuggestions(suggestions) {
    const sortKind = (a, b) => {
      const priority = {
        exception: 0, // unknown
        snippet: 0,
        value: 1,     // callbacks/returns
        variable: 2,  // variable
        property: 3,  // module attribute
        method: 4,    // private function
        class: 5,     // module
        package: 6,   // macro
        function: 6,  // function
      };

      return priority[a.type] - priority[b.type];
    };

    const isFunc = suggestion => !!(suggestion.func);

    const sortFunctionByType = (a, b) => {
      if (!isFunc(a) || !isFunc(b)) {
        return 0;
      }
      const startsWithLetterRegex = /^[a-zA-Z]/;
      const aStartsWithLetter = a.func.match(startsWithLetterRegex);
      const bStartsWithLetter = b.func.match(startsWithLetterRegex);
      if (!aStartsWithLetter && bStartsWithLetter) {
        return 1;
      } else if (aStartsWithLetter && !bStartsWithLetter) {
        return -1;
      } else {
        return 0;
      }
    };

    const sortFunctionByName = (a, b) => {
      if (!isFunc(a) || !isFunc(b)) {
        return 0;
      }

      if (a.func > b.func) {
        return 1;
      } else if (a.func < b.func) {
        return -1;
      } else {
        return 0;
      }
    };

    const sortFunctionByArity = (a, b) => {
      if (!isFunc(a) || !isFunc(b)) {
        return 0;
      }
      return a.arity - b.arity;
    };

    const sortByOriginalOrder = (a, b) => a.index - b.index;

    const sortFunc = (a, b) => sortKind(a, b) ||
      sortFunctionByType(a, b) ||
      sortFunctionByName(a, b) ||
      sortFunctionByArity(a, b) ||
      sortByOriginalOrder(a, b);

    return suggestions.sort(sortFunc);
  }

  replaceUpdateDescription() {
    atom.views.providers.forEach((provider) => {
      if (provider.modelConstructor.name === 'SuggestionList') {
        replaceCreateView(p);
      }
    });
  }

  replaceCreateView(viewProvider) {
    viewProvider.createView = (model) => {
      const SuggestionListElement = require(`${atom.packages.getActivePackage('autocomplete-plus').path}/lib/suggestion-list-element`);
      const element = new SuggestionListElement().initialize(model);
      element.updateDescription = (item0) => {
        const suggestionList = atom.packages.getActivePackage('autocomplete-plus').mainModule.autocompleteManager.suggestionList;
        const suggestionListView = atom.views.getView(suggestionList);
        const descriptionContent = suggestionListView.querySelector('.suggestion-description-content');
        const descriptionContainer = suggestionListView.querySelector('.suggestion-description');
        const descriptionMoreLink = suggestionListView.querySelector('.suggestion-description-more-link');

        descriptionMoreLink.style.display = 'none';
        let item = item0;
        if (item != null &&
            this.model != null &&
            this.model.items != null &&
            this.model.items[this.selected]) {
          item = this.model.items[this.selected];
        } else {
          return;
        }

        if (item.spec || item.summary) {
          if (descriptionContent.children.length < 2) {
            descriptionContent.innerHTML = '<pre><code></code></pre><p></p>';
            convertCodeBlocksToAtomEditors(descriptionContent);
          }

          const specText = (item.spec || '').trim();
          const summaryText = (item.summary || '').trim();
          const specElement = descriptionContent.children[0];
          const summaryElement = descriptionContent.children[1];

          if (specText !== '') {
            specElement.style.display = 'block';
            specElement.getModel().setText(specText);
          } else {
            specElement.style.display = 'none';
          }

          if (summaryText !== '') {
            summaryElement.style.display = 'block';
            summaryElement.outerHTML = markdownToHTML(summaryText);
          } else {
            summaryElement.style.display = 'none';
          }

          if (specText === summaryText === '') {
            descriptionContainer.style.display = 'none';
          } else {
            descriptionContainer.style.display = 'block';
          }
        } else if (item.description && item.description.length > 0) {
          // Default implementation from https://github.com/atom/autocomplete-plus/blob/v2.29.1/lib/suggestion-list-element.coffee#L104
          descriptionContainer.style.display = 'block';
          descriptionContent.textContent = item.description;
          if (item.descriptionMoreURL && item.descriptionMoreURL.length) {
            descriptionMoreLink.style.display = 'inline';
            descriptionMoreLink.setAttribute('href', item.descriptionMoreURL);
          } else {
            descriptionMoreLink.style.display = 'none';
            descriptionMoreLink.setAttribute('href', '#');
          }
        } else {
          descriptionContainer.style.display = 'none';
        }
      };

      return element;
    };
  }

  moduleAndFuncName(moduleParts, func) {
    let module = '';
    let funcName = '';
    if (func.match(/^:/)) {
      [module, funcName] = func.split('.');
    } else if (moduleParts.length > 0) {
      module = moduleParts[0];
      funcName = func;
    }
    return [module, funcName];
  }

  setClient(client) {
    this.client = client;
    // This is a hack until descriptionHTML is supported. See:
    // https://github.com/atom/autocomplete-plus/issues/423
    this.replaceUpdateDescription();
  }
};
