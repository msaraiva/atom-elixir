# An Atom package for Elixir

This package provides a set of tools for Elixir makers. It uses an extended version of the [alchemist-server](https://github.com/tonini/alchemist-server) by Samuel Tonini.

> **Notice:** This package is available for testing. Some features might still be added, changed or even removed before the first stable release. Feature addition and enhancements will heavily depend on feedback and/or contribution.

### Install

```
apm install atom-elixir
```

### Dependencies
- [language-elixir](https://atom.io/packages/language-elixir)

### Features

- Autocomplete [(Screenshots)](#screenshots-autocomplete)
  - Lists modules, functions, variables, function params and module attributes available in the current scope.
  - Indicates the type of the module (Module, Struct, Protocol, Implementation or Exception)
  - Shows documentation summary for each module or function
  - Shows function specs
  - Works with aliased and imported modules
  - Indicates where the function was originally defined (for aliased and imported modules)
  - Smart snippets for functions: After `|>`, doesn't write first parameter. After `&`, writes `&function/arity`
- Go to definition
  - Jump to the definition of the module or function under the cursor
  - Erlang modules and functions also supported
  - Return from definition (to previous files/positions)
  - Works with aliased and imported modules
- Go to Documentation View [(Screenshots)](#screenshots-documentation)
  - Shows documentation of the module or function under the cursor
  - Also shows specs, types and callbacks (when available)
  - Works with aliased and imported modules
- Quoted Code view [(Screenshots)](#screenshots-quoted)
  - Convert selected text into its quoted form
  - Live pattern matching against quoted code
- Expand Macro view [(Screenshots)](#screenshots-expand)
  - Expands the selected macro. Shows expanded code using Expand Once, Expand and Expand All.
- All features depending on aliases and imports are already supporting the new v1.2 notation.

### Upcoming Features

- Support for `.eex` files
- Show information about `use` calls (e.g., required/imported modules, aliases, behaviours, ...)
- Add callbacks to Autocomplete
- Go to definition of variables and module attributes
- Show information on hover
- Auto install dependencies
- Format [ExSamples](https://github.com/msaraiva/exsamples) tables

### Shortcuts

> **Notice**: The keymaps below were defined for my own OS X environment. If you're using Linux, Windows or even another OS X environment and the current key mapping conflicts with other commands, feel free to open an issue and report it.

- Autocomplete: `ctrl + space`
- Go To Definition: `alt + down` or `alt + click`
- Return from Definition: `alt + up`
- Go To Documentation: `F2`
- Open Quoted Code View + quote selected text: `ctrl + shift + t`
- Open Expand Code View + expand selected text: `ctrl + shift + x`

### Screenshots

#### <a name="screenshots-autocomplete"></a> Autocomplete

- Listing module attributes, variables and functions available in the current scope
- Showing specs and documentation summary
- Showing where each function was originally defined

![image](https://raw.githubusercontent.com/msaraiva/atom-elixir/assets/screenshots/autocomplete1.png?raw=true)

- Listing modules and their types

![image](https://raw.githubusercontent.com/msaraiva/atom-elixir/assets/screenshots/autocomplete3.png?raw=true)

#### <a name="screenshots-documentation"></a> Documentation
- Showing documentation of the module under the cursor

![image](https://raw.githubusercontent.com/msaraiva/atom-elixir/assets/screenshots/docs_docs.png?raw=true)

#### <a name="screenshots-quoted"></a> Quoted Code View

- Quoted form of the selected code
- Live pattern matching against quoted code

![image](https://raw.githubusercontent.com/msaraiva/atom-elixir/assets/screenshots/quoted.png?raw=true)

#### <a name="screenshots-expand"></a> Expand Macro View

- Expanding selected macro call

![image](https://raw.githubusercontent.com/msaraiva/atom-elixir/assets/screenshots/expand.png?raw=true)

### Credits

- The Elixir Server, which is responsible for most of the features, is an extended version of [alchemist-server](https://github.com/tonini/alchemist-server) by Samuel Tonini. Pay attention that the current API is no longer compatible with the original one.
- The Expand View was totally based on the [mex](https://github.com/mrluc/mex) tool by Luc Fueston. There's also a very nice post where he describes the whole process of [Building A Macro-Expansion Helper for IEx](http://blog.maketogether.com/building-a-macro-expansion-helper/).
- The initEnv trick was based on the code from [Atom Runner](https://github.com/lsegal/atom-runner/blob/master/lib/atom-runner.coffee).
