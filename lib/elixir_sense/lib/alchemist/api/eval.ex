defmodule Alchemist.API.Eval do

  @moduledoc false

  alias ElixirSense.Core.Introspection

  def request(args) do
    _no_return =
      args
      |> normalize
      |> process

    IO.puts "END-OF-EVAL"
  end

  def process({:signature_info, buffer_file, file, line}) do
    buffer = File.read!(buffer_file)
    prefix = File.read!(file)

    case ElixirSense.signature(prefix, buffer, line) do
      %{active_param: npar, signatures: signatures} ->
        IO.puts "#{npar}"
        IO.puts format_signatures(signatures)
      :none ->
        IO.puts "none"
    end
  end

  def process({:expand_full, buffer_file, file, line}) do
    buffer = File.read!(buffer_file)
    code = File.read!(file)

    case ElixirSense.expand_full(buffer, code, line) do
      {:error, e} ->
        IO.inspect(e)
      expanded_code_map ->
        format_expand_full(expanded_code_map)
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
    File.read!("#{file}")
    |> Code.string_to_quoted
    |> Tuple.to_list
    |> List.last
    |> IO.inspect
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
    IO.puts "# #{Introspection.module_to_string(type)} on line #{line}:\n#  ↳ #{description}"
  end

  defp print_match_error(%MatchError{}) do
    IO.puts "# No match"
  end

  defp format_signatures(signatures) do
    for %{name: name, params: params} <- signatures do
      fun_args_text = params |> Enum.join(",") |> String.replace("\\\\", "\\\\\\\\")
      "#{name};#{fun_args_text}"
    end |> Enum.join("\n")
  end

  defp format_expand_full(expanded_code_map) do
    %{
      expand_once: expand_once,
      expand: expand,
      expand_partial: expand_partial,
      expand_all: expand_all,
    } = expanded_code_map

    IO.puts(expand_once)
    IO.puts("\u000B")
    IO.puts(expand)
    IO.puts("\u000B")
    IO.puts(expand_partial)
    IO.puts("\u000B")
    IO.puts(expand_all)
  end

end
