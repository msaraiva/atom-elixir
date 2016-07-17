defmodule ElixirSense.Providers.Definition do

  @moduledoc """
  Provides a function to find out where symbols are defined.

  Currently finds definition of modules, functions and macros.
  """

  alias Alchemist.Helpers.ModuleInfo
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Parser

  @type file :: String.t
  @type line :: pos_integer
  @type location :: {file, line | nil}

  @doc """
  Finds out where a module, function or macro was defined.

  ## Examples
    iex> {file, line} = Definition.find(MyString, nil, [], [{MyString, String}])
    iex> {Path.basename(file), line}
    {"string.ex", 3}
  """
  @spec find(module, atom, [module], [{module, module}]) :: location
  def find(mod, fun, imports, aliases) do
    [mod, fun, imports, aliases]
    |> find_file
    |> find_line(fun)
  end

  defp find_file([nil, function, [], []]) do
    look_for_kernel_functions(function)
  end

  defp find_file([nil, function, imports, _aliases]) do
    module = Enum.filter(imports, &ModuleInfo.has_function?(&1, function))
    |> List.first

    case module do
      nil -> look_for_kernel_functions(function)
      _   -> source(module)
    end
  end

  defp find_file([module, _function, _imports, aliases]) do
    if elixir_module?(module) do
      module
      |> Module.split
      |> ModuleInfo.expand_alias(aliases)
    else
      module
    end |> source
  end

  defp find_line({_, file}, _fun) when file in ["non_existing", nil, ""] do
    {"non_existing", nil}
  end

  defp find_line({mod, file}, fun) do
    line = if String.ends_with?(file, ".erl") do
      find_fun_line_in_erl_file(file, fun)
    else
      file_metadata = Parser.parse_file(file, false, false, nil)
      Metadata.get_function_line(file_metadata, mod, fun)
    end
    {file, line}
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

  defp source(module) do
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

end
