# An Atom package for Elixir

Autocomplete, Go/Jump to Definition, Documentation and more.

### Dependencies
- [language-elixir](https://atom.io/packages/language-elixir)

### Install

```
apm install atom-elixir
```

### Features

- Autocomplete [(Screenshots)](#screenshots-autocomplete)
  - Lists modules, functions, variables, function params and module attributes available in the current scope.
  - Lists callbacks defined in behaviours (works also when @behaviour is injected by `use` directives)
  - Lists the accepted "returns" specs when inside a callback implementation
  - Indicates the type of the module (Module, Struct, Protocol, Implementation or Exception)
  - Shows documentation summary for each module or function
  - Shows function and callback specs
  - Works with aliased and imported modules
  - Indicates where the function was originally defined (for aliased, imported modules or callbacks)
  - Smart snippets for functions: After `|>`, doesn't write first parameter. After `&`, writes `&function/arity`
- Go to definition
  - Jump to the definition of the module or function under the cursor
  - Erlang modules and functions also supported
  - Return from definition (to previous files/positions)
  - Works with aliased and imported modules
- Documentation View [(Screenshots)](#screenshots-documentation)
  - Shows documentation of the module or function under the cursor
  - Also shows specs, types and callbacks (when available)
  - Works with aliased and imported modules
- Quoted Code view [(Screenshots)](#screenshots-quoted)
  - Convert selected text into its quoted form
  - Live pattern matching against quoted code
- Expand Macro view [(Screenshots)](#screenshots-expand)
  - Expands the selected macro. Shows expanded code using Expand Once, Expand and Expand All.
- All features depending on aliases and imports are already supporting the new v1.2 notation.

> **IMPORTANT:** Most of the features only work properly if you have the related `.beam` files in the project's `_build` folder. So please, before opening an issue, make sure you can successfully compile your project in the environment you're trying to use it ("dev" and/or "test"). You can also hit `ALT+CMD+i` to open the Atom's console (ALT+CTRL+i on windows/linux) in order to see the server's output. When successfully started, atom-elixir prints:
```
[atom-elixir] Initializing ElixirSense server for environment "dev" (Elixir version 1.4.0)
[atom-elixir] Working directory is "/Users/your_name/workspace/your_project/"
```
All error messages from the server should also be displayed in the console. Please send those messages when reporting an issue.

### Shortcuts

- Autocomplete: `ctrl + space`
- Go To Definition: `alt + down` or `alt + click`
- Return from Definition: `alt + up`
- Go To Documentation: `F2`
- Open Quoted Code View + quote selected text: `ctrl + shift + t`
- Open Expand Code View + expand selected text: `ctrl + shift + x`

> **Notice**: The keymaps were defined for my own OS X environment. If you're using Linux, Windows or even another OS X environment and the current key mapping conflicts with other commands, feel free to open an issue and report it.

### Screenshots

#### <a name="screenshots-autocomplete"></a> Autocomplete

- Listing variables, module attributes, functions and macros available in the current scope
- Showing specs and documentation summary
- Showing where each function was originally defined

![image](https://raw.githubusercontent.com/msaraiva/atom-elixir/assets/screenshots/autocomplete1.png)

- Listing callbacks defined in used behaviours

![image](https://raw.githubusercontent.com/msaraiva/atom-elixir/assets/screenshots/autocomplete4.png)

- Listing accepted "returns" when inside a callback implementation

![image](https://raw.githubusercontent.com/msaraiva/atom-elixir/assets/screenshots/autocomplete5.png)

#### <a name="screenshots-documentation"></a> Documentation
- Showing documentation of the module/function under the cursor

![image](https://raw.githubusercontent.com/msaraiva/atom-elixir/assets/screenshots/docs_docs.png)

- Showing documentation of the module under the cursor (callbacks)

![image](https://raw.githubusercontent.com/msaraiva/atom-elixir/assets/screenshots/docs_callbacks.png)

#### <a name="screenshots-expand"></a> Expand Macro View

- Expanding selected macro call

![image](https://raw.githubusercontent.com/msaraiva/atom-elixir/assets/screenshots/expand.png)

#### <a name="screenshots-quoted"></a> Quoted Code View

- Quoted form of the selected code
- Live pattern matching against quoted code

![image](https://raw.githubusercontent.com/msaraiva/atom-elixir/assets/screenshots/quoted.png)

### Credits

- The Elixir Server is an extended version of [alchemist-server](https://github.com/tonini/alchemist-server) by Samuel Tonini. Pay attention that the current API is no longer compatible with the original one.
- The Expand View was inspired by the [mex](https://github.com/mrluc/mex) tool by Luc Fueston. There's also a very nice post where he describes the whole process of [Building A Macro-Expansion Helper for IEx](http://blog.maketogether.com/building-a-macro-expansion-helper/).
