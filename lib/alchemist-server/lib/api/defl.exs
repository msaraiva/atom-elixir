Code.require_file "../helpers/module_info.exs", __DIR__
Code.require_file "../helpers/ast.exs", __DIR__

defmodule Alchemist.API.Defl do

  @moduledoc false

  alias Alchemist.Helpers.ModuleInfo

  def request(args) do
    [mod, fun, file_path, buffer_file, line, _context_info] = args |> normalize

    buffer_file_metadata = case Ast.parse_file(buffer_file) do
      {:ok, {_ast, buffer_file_metadata}} ->
        buffer_file_metadata
      {:error, reason} ->
        IO.inspect :stderr, reason, []
        nil
    end

    %{imports: imports, aliases: aliases, module: module} = Ast.get_context_by_line(buffer_file_metadata, line)
    context_info = [context: nil, imports: [module|imports], aliases: aliases ]

    [mod, fun, context_info]
    |> process
    |> post_process(file_path, buffer_file_metadata, fun)
    |> IO.puts

    IO.puts "END-OF-DEFL"
  end

  defp post_process({mod, file}, file, buffer_file_metadata, fun) do
    line = Ast.get_function_line(buffer_file_metadata, mod, fun)
    do_post_process(file, line)
  end

  defp post_process({mod, file}, _f, _, fun) do
    file_metadata = case Ast.parse_file(file) do
      {:ok, {_ast, file_metadata}} ->
        file_metadata
      {:error, reason} ->
        IO.inspect :stderr, reason, []
        nil
    end
    line = Ast.get_function_line(file_metadata, mod, fun)
    do_post_process(file, line)
  end

  defp do_post_process(file, nil), do: file
  defp do_post_process(file, line), do: "#{file}:#{line}"

  def process([nil, function, [context: _, imports: [], aliases: _]]) do
    look_for_kernel_functions(function)
  end

  def process([nil, function, [context: _, imports: imports, aliases: _ ]]) do
    module = Enum.filter(imports, &ModuleInfo.has_function?(&1, function))
    |> List.first

    case module do
      nil -> look_for_kernel_functions(function)
      _   -> source(module)
    end
  end

  def process([module, _function, [context: _, imports: _, aliases: aliases]]) do
    if elixir_module?(module) do
      module
      |> Module.split
      |> ModuleInfo.expand_alias(aliases)
    else
      module
    end |> source
  end

  defp elixir_module?(module) do
    module == Module.concat(Elixir, module)
  end

  defp look_for_kernel_functions(function) do
    cond do
      ModuleInfo.docs?(Kernel, function) ->
        source(Kernel)
      ModuleInfo.docs?(Kernel.SpecialForms, function) ->
        source(Kernel.SpecialForms)
      true -> {nil, ""}
    end
  end

  defp source([]), do: nil
  defp source(module) when is_list(module) do
    module
    |> Module.concat
    |> do_source
  end
  defp source(module), do: do_source(module)

  defp do_source(module) do
    file = if Code.ensure_loaded? module do
      case module.module_info(:compile)[:source] do
        nil    -> nil
        source -> List.to_string(source)
      end
    end
    file = if File.exists?(file || "") do
      file
    else
      module |> :code.which |> to_string |> String.replace(~r/(.+)\/ebin\/([^\s]+)\.beam$/, "\\1/src/\\2.erl")
    end
    {module, file}
  end

  defp normalize(request) do
    {{expr, file_path, buffer_file, line, context_info}, _} = Code.eval_string(request)
    [module, function]        = String.split(expr, ",", parts: 2)
    # {module, _}               = Code.eval_string(module)
    module = case module do
      "nil" -> nil
      name -> Module.concat([name])
    end
    function                  = String.to_atom function
    [module, function, file_path, buffer_file, line, context_info]
  end

end
