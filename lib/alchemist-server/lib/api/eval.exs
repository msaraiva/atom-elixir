Code.require_file "../helpers/introspection.exs", __DIR__

defmodule Alchemist.API.Eval do

  @moduledoc false

  def request(args) do
    args
    |> normalize
    |> process

    IO.puts "END-OF-EVAL"
  end

  def process({:eval, file}) do
    try do
      File.read!("#{file}")
      |> Code.eval_string
      |> Tuple.to_list
      |> List.first
      |> IO.inspect
    rescue
      e -> IO.inspect e
    end
  end

  def process({:match, file}) do
    try do
      file_content = File.read!("#{file}")
      {:=, _, [pattern|_]} = file_content |> Code.string_to_quoted!
      vars = extract_vars(pattern)

      bindings = file_content
      |> Code.eval_string
      |> Tuple.to_list
      |> List.last

      if Enum.empty?(vars) do
        IO.puts "# No bindings"
      else
        IO.puts "# Bindings"
      end

      Enum.each(vars, fn var ->
        IO.puts ""
        IO.write "#{var} = "
        IO.inspect Keyword.get(bindings, var)
      end)
    rescue
      e -> print_match_error(e)
    end
  end

  def process({:quote, file}) do
    try do
      File.read!("#{file}")
      |> Code.string_to_quoted
      |> Tuple.to_list
      |> List.last
      |> IO.inspect
    rescue
      e -> IO.inspect e
    end
  end

  def process({:expand, file}) do
    try do
      {_, expr} = File.read!("#{file}")
      |> Code.string_to_quoted
      res = Macro.expand(expr, __ENV__)
      IO.puts Macro.to_string(res)
    rescue
      e -> IO.inspect e
    end
  end

  def process({:expand_once, file}) do
    try do
      {_, expr} = File.read!("#{file}")
      |> Code.string_to_quoted
      res = Macro.expand_once(expr, __ENV__)
      IO.puts Macro.to_string(res)
    rescue
      e -> IO.inspect e
    end
  end

  def normalize(request) do
    {expr , _} = Code.eval_string(request)
    expr
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

  defp print_match_error(%{__struct__: type, description: description, line: line}) do
    IO.puts "# #{Introspection.module_to_string(type)} on line #{line}: \n#  ↳ #{description}"
  end

  defp print_match_error(%MatchError{}) do
    IO.puts "# No match"
  end

  defp print_match_error(e) do
    IO.inspect(e)
  end

end
