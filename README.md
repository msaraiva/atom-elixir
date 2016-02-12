# An Atom package for Elixir

This package provides a set of tools for Elixir makers. It uses an extended version of the [alchemist-server](https://github.com/tonini/alchemist-server) by Samuel Tonini.

> **Notice:** This package is available for testing and has not been published yet. If you want to test it, clone this repo into your `~/.atom/packages` and run `apm install` inside the newly created folder. Also notice that some features might still be added, changed or even removed before the first stable release. Feature addition and enhancements will heavily depend on feedback and/or contribution.

### Features

- Autocomplete
  - Lists modules, functions, variables, function params and module attributes available in the current scope.
  - Indicates the type of the module (Module, Struct, Protocol, Implementation or Exception)
  - Shows documentation summary for each module or function
  - Shows function specs
  - Works with aliased and imported modules
  - Indicates where the function was originally defined (for aliased and imported modules)
- Go to definition
  - Jump to the definition of the module or function under the cursor
  - Erlang modules and functions also supported
  - Return from definition (to previous files/positions)
  - Works with aliased and imported modules
- Go to Documentation View
  - Shows documentation of the module or function under the cursor
  - Also shows specs, types and callbacks (when available)
  - Works with aliased and imported modules
- Quoted Code view
  - Convert selected text into its quoted form
  - Live pattern matching of the quoted code
- Expand Macro view
  - Expands the selected macro. Shows expanded code using Expand Once, Expand and Expand All.
- All features depending on aliases and imports are already supporting the new v1.2 notation.

### Upcoming Features

- Show information on hover
- Go to definition of variables and module attributes
- Auto install dependencies
- Format [ExSamples](https://github.com/msaraiva/exsamples) tables

### Dependencies
- [language-elixir](https://atom.io/packages/language-elixir)

### Shortcuts

> **Notice**: The keymaps below were defined for my own OS X environment. If you're using Linux, Windows or even another OS X environment and the current key mapping conflicts with other commands, feel free to open an issue and report it.

- Autocomplete: `ctrl + space`
- Go To Definition: `alt + down` or `alt + click`
- Return from Definition: `alt + up`
- Go To Documentation: `F2`
- Open Quoted Code View + quote selected text: `ctrl + shift + t`
- Open Expand Code View + expand selected text: `ctrl + shift + x`

### Credits

- The Elixir Server, which is responsible for most of the features, is an extended version of [alchemist-server](https://github.com/tonini/alchemist-server) by Samuel Tonini. Pay attention that the current API is no longer compatible with the original one.
- The Expand View was totally based on the [mex](https://github.com/mrluc/mex) tool by Luc Fueston. There's also a very nice post where he describes the whole process of [Building A Macro-Expansion Helper for IEx](http://blog.maketogether.com/building-a-macro-expansion-helper/).
- The initEnv trick was based on the code from [Atom Runner](https://github.com/lsegal/atom-runner/blob/master/lib/atom-runner.coffee).
