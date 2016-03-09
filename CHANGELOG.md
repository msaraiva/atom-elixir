## v0.1.4

### Bug fixes
* Package stops working after update [(#19)](https://github.com/msaraiva/atom-elixir/issues/19)

## v0.1.3

### Bug fixes
* Uncaught TypeError on Quoted Code View [(#20)](https://github.com/msaraiva/atom-elixir/issues/20) and [(#21)](https://github.com/msaraiva/atom-elixir/issues/21)

## v0.1.2

### Bug fixes
* Fixing tab change event before server is properly initialized

## v0.1.1

### Bug fixes
* Fixing README for the registry

## v0.1.0

### Bug fixes
* Autocomplete and Go To Definition do not work with `use ExUnit.Case`
* Uncaught TypeError: Cannot read property 'replace' of undefined [(#10)](https://github.com/msaraiva/atom-elixir/issues/10)
* Modules in `test/support` not loaded or could not be found [(#15)](https://github.com/msaraiva/atom-elixir/issues/15)

## v0.0.4

### Features
* Expand View now recursively expands `use` directives
* An "Expand Partial" tab was added to the Expand View. Partial expansion is the same as  `expand_all` without expanding `:def, :defp, :defmodule, :@, :defmacro, :defmacrop, :defoverridable, :__ENV__, :__CALLER__, :raise, :if, :unless, :in`
* Navigate through tabs using left/right keys (Docs View & Expand View)

### Bug fixes
* Autocomplete not listing macros from imported modules
* Windows compatibility

## v0.0.3

### Features
* Improved functionality/accuracy of "Autocomplete", "Go To Definition", "Docs View" and "Expand View" by expanding `use` directives to extract module information (e.g. requires and imports)

### Bug fixes
* Faster response for Autocomplete
* Default docs stylesheet results in washed-out heading and code on light theme [(#9)](https://github.com/msaraiva/atom-elixir/issues/9)

## v0.0.2

### Bug fixes
* Starting server on linux [(#3)](https://github.com/msaraiva/atom-elixir/issues/3)
* Autocomplete on a foo/0 method autofills foo(arg1, arg0) [(#4)](https://github.com/msaraiva/atom-elixir/issues/4)
* Double "tab" to trigger snippets [(#1)](https://github.com/msaraiva/atom-elixir/issues/1)

## v0.0.1

### Features
* Autocomplete
* Go to definition
* Go to Documentation View
* Quoted Code view
* Expand Macro view
