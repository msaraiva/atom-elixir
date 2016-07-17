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

  @doc ~S"""
    Returns all documentation related the module or function.

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
      iex> ElixirSense.signature("MyList.flatten(par0, par1, ", code, 3)
      %{active_param: 2,
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

end
