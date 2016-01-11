Code.require_file "../helpers/module_info.exs", __DIR__
Code.require_file "../code/metadata.exs", __DIR__
Code.require_file "../code/parser.exs", __DIR__

defmodule Alchemist.API.Defl do

  @moduledoc false

  alias Alchemist.Helpers.ModuleInfo
  alias Alchemist.Code.Metadata
  alias Alchemist.Code.Parser

  def request(args) do
    [mod, fun, file_path, buffer_file, line] = args |> normalize

    buffer_file_metadata = Parser.parse_file(buffer_file, true, true, line)
    %{imports: imports,
      aliases: aliases,
      module: module} = Metadata.get_env(buffer_file_metadata, line)

    context_info = [context: nil, imports: [module|imports], aliases: aliases]

    [mod, fun, context_info]
    |> process
    |> post_process(file_path, buffer_file_metadata, fun)
    |> IO.puts

    IO.puts "END-OF-DEFL"
  end

  defp post_process({_, file = "preloaded"}, _, _, _) do
    do_post_process(file, nil)
  end

  defp post_process({_, file}, _, _, _) when file in ["non_existing", nil, ""] do
    do_post_process("non_existing", nil)
  end

  defp post_process({mod, file}, file, buffer_file_metadata, fun) do
    line = Metadata.get_function_line(buffer_file_metadata, mod, fun)
    do_post_process(file, line)
  end

  defp post_process({mod, file}, _f, _, fun) do
    line = if String.ends_with?(file, ".erl") do
      find_fun_line_in_erl_file(file, fun)
    else
      file_metadata = Parser.parse_file(file, false, false, nil)
      Metadata.get_function_line(file_metadata, mod, fun)
    end
    do_post_process(file, line)
  end

  defp find_fun_line_in_erl_file(file, fun) do
    fun_name = Atom.to_string(fun)
    index =
      file
      |> File.read!
      |> String.split(["\n", "\r\n"])
      |> Enum.find_index(&String.match?(&1, ~r/^#{fun_name}\b/))

    (index || 0) + 1
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
    file = if file && File.exists?(file) do
      file
    else
      erl_file = module |> :code.which |> to_string |> String.replace(~r/(.+)\/ebin\/([^\s]+)\.beam$/, "\\1/src/\\2.erl")
      if File.exists?(erl_file) do
        erl_file
      end
    end
    {module, file}
  end

  defp normalize(request) do
    {{expr, file_path, buffer_file, line}, _} = Code.eval_string(request)
    [module, function] = String.split(expr, ",", parts: 2)
    {module, _}        = Code.eval_string(module)
    function           = String.to_atom function
    [module, function, file_path, buffer_file, line]
  end

end
