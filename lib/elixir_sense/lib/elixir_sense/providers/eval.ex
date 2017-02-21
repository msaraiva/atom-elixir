defmodule ElixirSense.Providers.Eval do

  @moduledoc """
  Provider responsible for evaluating Elixr expressions.
  """

  alias ElixirSense.Core.Introspection

  @type binding :: {name :: String.t, value :: String.t}
  @type bindings :: [binding] | :no_match | {:error, message :: String.t}

  def quote(code) do
    code
    |> Code.string_to_quoted
    |> Tuple.to_list
    |> List.last
    |> inspect
  end

  @doc """
  Evaluate a pattern matching expression and returns its bindings, if any.
  """
  @spec match(String.t) :: bindings
  def match(code) do
    try do
      {:=, _, [pattern|_]} = code |> Code.string_to_quoted!
      vars = extract_vars(pattern)

      bindings =
        code
        |> Code.eval_string
        |> Tuple.to_list
        |> List.last

      Enum.map(vars, fn var ->
        {var, Keyword.get(bindings, var)}
      end)
    rescue
      MatchError ->
        :no_match
      e ->
        %{__struct__: type, description: description, line: line} = e
        {:error, "# #{Introspection.module_to_string(type)} on line #{line}:\n#  ↳ #{description}"}
    end
  end

  defp extract_vars(ast) do
    {_ast, acc} = Macro.postwalk(ast, [], &extract_var/2)
    acc |> Enum.reverse
  end

  defp extract_var(ast = {var_name, [line: _], nil}, acc) when is_atom(var_name) and var_name != :_ do
    {ast, [var_name|acc]}
  end

  defp extract_var(ast, acc) do
    {ast, acc}
  end

end
