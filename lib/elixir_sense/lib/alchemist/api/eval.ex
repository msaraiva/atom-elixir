defmodule Alchemist.API.Eval do

  @moduledoc false

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
        print_expand_full(expanded_code_map)
    end
  end

  def process({:match, file}) do
    file_content = File.read!("#{file}")

    case ElixirSense.match(file_content) do
      :no_match ->
        IO.puts "# No match"
      {:error, message} ->
        IO.puts message
      bindings ->
        print_match_bindings(bindings)
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

  defp format_signatures(signatures) do
    for %{name: name, params: params} <- signatures do
      fun_args_text = params |> Enum.join(",")
      "#{name};#{fun_args_text}"
    end |> Enum.join("\n")
  end

  defp print_expand_full(expanded_code_map) do
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

  defp print_match_bindings(bindings) do
    if Enum.empty?(bindings) do
      IO.puts "# No bindings"
    else
      IO.puts "# Bindings"
    end

    Enum.each(bindings, fn {var, val} ->
      IO.puts ""
      IO.puts "#{var} = #{inspect(val)}"
    end)
  end

end
