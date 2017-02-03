defmodule ElixirSense do

  @moduledoc """
  Provides the most common functions for most editors/tools.
  """

  alias ElixirSense.Core.State
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Parser
  alias ElixirSense.Core.Introspection
  alias ElixirSense.Providers.Docs
  alias ElixirSense.Providers.Definition
  alias ElixirSense.Providers.Suggestion
  alias ElixirSense.Providers.Signature
  alias ElixirSense.Providers.Expand

  @doc ~S"""
  Returns all documentation related a module or function, including types and callback information.

  ## Examples

      iex> code = ~S'''
      ...> defmodule MyModule do
      ...>   alias Enum, as: MyEnum
      ...>
      ...> end
      ...> '''
      iex> ElixirSense.docs("MyEnum.to_list", code, 3) |> Map.get(:docs) |> String.split("\n") |> Enum.at(6)
      "Converts `enumerable` to a list."
      iex> ElixirSense.docs("Enum.to_list", code, 3) |> Map.get(:types) |> String.split("\n") |> Enum.at(0)
      "  `@type t :: Enumerable.t"
  """
  @spec docs(String.t, String.t, pos_integer) :: Introspection.docs
  def docs(expr, code, line) do
    metadata = Parser.parse_string(code, true, true, line)
    %State.Env{
      imports: imports,
      aliases: aliases
    } = Metadata.get_env(metadata, line)

    Docs.all(expr, imports, aliases)
  end

  @spec definition(module, atom, String.t, pos_integer) :: Definition.location
  def definition(mod, fun, code, line) do
    buffer_file_metadata = Parser.parse_string(code, true, true, line)
    %State.Env{
      imports: imports,
      aliases: aliases,
      module: module
    } = Metadata.get_env(buffer_file_metadata, line)

    Definition.find(mod, fun, [module|imports], aliases)
  end

  @doc """
  Finds all suggestions given a hint, the code buffer and the line where the cursor is positioned.

  ## Examples

      iex> code = ~S'''
      ...> defmodule MyModule do
      ...>   alias List, as: MyList
      ...>
      ...> end
      ...> '''
      iex> ElixirSense.suggestions("MyList.fi", code, 3)
      [%{type: :hint, value: "MyList.first"},
       %{type: "function", name: "first", arity: 1, origin: "List",
         spec: "@spec first([elem]) :: nil | elem when elem: var",
         summary: "Returns the first element in `list` or `nil` if `list` is empty.",
         args: "list"}]
  """
  @spec suggestions(String.t, String.t, non_neg_integer) :: [Suggestion.suggestion]
  def suggestions(hint, code, line) do
    buffer_file_metadata = Parser.parse_string(code, true, true, line)
    %State.Env{
      imports: imports,
      aliases: aliases,
      vars: vars,
      attributes: attributes,
      behaviours: behaviours,
      module: module,
      scope: scope
    } = Metadata.get_env(buffer_file_metadata, line)

    Suggestion.find(hint, [module|imports], aliases, vars, attributes, behaviours, scope)
  end

  @doc """
  Returns the signature info from the function when inside a function call.

  ## Examples

      iex> code = ~S'''
      ...> defmodule MyModule do
      ...>   alias List, as: MyList
      ...>
      ...> end
      ...> '''
      iex> ElixirSense.signature("MyList.flatten(par0, ", code, 3)
      %{active_param: 1,
        signatures: [
          %{name: "flatten", params: ["list"]},
          %{name: "flatten", params: ["list", "tail"]}]}
  """
  @spec signature(String.t, String.t, pos_integer) :: Signature.signature_info
  def signature(prefix, code, line) do
    buffer_file_metadata = Parser.parse_string(code, true, true, line)
    %State.Env{
      imports: imports,
      aliases: aliases,
    } = Metadata.get_env(buffer_file_metadata, line)

    Signature.find(prefix, imports, aliases)
  end

  @doc """
  Returns a map containing the results of all different code expansion methods
  available.

  Available axpansion methods:

    * `expand_once` - Calls `Macro.expand_once/2`
    * `expand` - Calls `Macro.expand/2`
    * `expand_all` - Recursively calls `Macro.expand/2`
    * `expand_partial` - The same as `expand_all` but do not expand `:def, :defp, :defmodule, :@, :defmacro,
    :defmacrop, :defoverridable, :__ENV__, :__CALLER__, :raise, :if, :unless, :in`

  > **Notice**: In order to expand the selected code properly, ElixirSense parses/expands the source file and tries to introspect context information
  like requires, aliases, import, etc. However the environment during the real compilation process may still be diffent from the one we
  try to simulate, therefore, in some cases, the expansion might not work as expected or, in some cases, not even be possible.

  ## Example

  Given the following code:

  ```
  unless ok do
    IO.puts to_string(:error)
  else
    IO.puts to_string(:ok)
  end

  ```

  A full expansion will generate the following results based on each method:

  ### expand_once

  ```
  if(ok) do
    IO.puts(to_string(:ok))
  else
    IO.puts(to_string(:error))
  end
  ```

  ### expand

  ```
  case(ok) do
    x when x in [false, nil] ->
      IO.puts(to_string(:error))
    _ ->
      IO.puts(to_string(:ok))
  end
  ```

  ### expand_partial

  ```
  unless(ok) do
    IO.puts(String.Chars.to_string(:error))
  else
    IO.puts(String.Chars.to_string(:ok))
  end
  ```

  ### expand_all

  ```
  case(ok) do
    x when :erlang.or(:erlang.=:=(x, nil), :erlang.=:=(x, false)) ->
      IO.puts(String.Chars.to_string(:error))
    _ ->
      IO.puts(String.Chars.to_string(:ok))
  end
  ```

  """
  @spec expand_full(String.t, String.t, pos_integer) :: Expand.expanded_code_map
  def expand_full(buffer, code, line) do
    buffer_file_metadata = Parser.parse_string(buffer, true, true, line)
    %State.Env{
      requires: requires,
      imports: imports,
      module: module
    } = Metadata.get_env(buffer_file_metadata, line)

    Expand.expand_full(code, requires, imports, module)
  end

end
