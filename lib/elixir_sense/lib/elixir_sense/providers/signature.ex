defmodule ElixirSense.Providers.Signature do

  @moduledoc """
  Provider responsible for introspection information about function signatures.
  """

  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.Source
  alias Alchemist.Helpers.ModuleInfo
  alias ElixirSense.Core.Metadata

  @type signature :: %{name: String.t, params: [String.t]}
  @type signature_info :: %{active_param: pos_integer, signatures: [signature]} | :none

  @doc """
  Returns the signature info from the function defined in the prefix, if any.

  ## Examples

      iex> Signature.find("MyList.flatten(par0, par1, ", [], [{MyList, List}], MyModule, %ElixirSense.Core.Metadata{})
      %{active_param: 2,
        pipe_before: false,
        signatures: [
          %{name: "flatten", params: ["list"]},
          %{name: "flatten", params: ["list", "tail"]}]}

  """
  @spec find(String.t, [module], [{module, module}], module, map) :: signature_info
  def find(prefix, imports, aliases, module, metadata) do
    case Source.which_func(prefix) do
      %{candidate: {mod, func}, npar: npar, pipe_before: pipe_before} ->
        # pipeBefore = !!textBeforeCursor.match(///\|>\s*#{prefix}$///)
        # Introspection.module_to_string(mod) <> "."
        %{active_param: npar, pipe_before: pipe_before, signatures: find_signatures(mod, func, imports, aliases, module, metadata)}
      _ ->
        :none
    end
  end

  defp find_signatures(mod, func, imports, aliases, module, metadata) do
    {actual_mod, actual_func} = actual_mod_fun({mod, func}, imports, aliases, module)

    Metadata.get_function_signatures(metadata, module, func)
    |> Kernel.++(Introspection.get_signatures(actual_mod, actual_func))
    |> Enum.uniq_by(fn sig -> sig.params end)
  end

  defp actual_mod_fun({mod, function}, imports, aliases, current_module) do
    with {nil, nil} <- look_for_kernel_functions(mod, function),
         {nil, nil} <- look_for_imported_functions(mod, function, imports),
         {nil, nil} <- look_for_aliased_functions(mod, function, aliases),
         {nil, nil} <- look_for_functions_in_module(mod, function, current_module)
    do
      {mod, function}
    else
      mod_func -> mod_func
    end
  end

  defp look_for_kernel_functions(nil, function) do
    cond do
      ModuleInfo.docs?(Kernel, function) ->
        {Kernel, function}
      ModuleInfo.docs?(Kernel.SpecialForms, function) ->
        {Kernel.SpecialForms, function}
      true -> {nil, nil}
    end
  end

  defp look_for_kernel_functions(_module, _function) do
    {nil, nil}
  end

  defp look_for_imported_functions(nil, function, imports) do
    case imports |> Enum.find(&ModuleInfo.has_function?(&1, function)) do
      nil -> {nil, nil}
      module  -> {module, function}
    end
  end

  defp look_for_imported_functions(_module, _function, _imports) do
    {nil, nil}
  end

  defp look_for_aliased_functions(nil, _function, _aliases) do
    {nil, nil}
  end

  defp look_for_aliased_functions(module, function, aliases) do
    if elixir_module?(module) do
      mod =
        module
        |> Module.split
        |> ModuleInfo.expand_alias(aliases)
      {mod, function}
    else
      {nil, nil}
    end
  end

  defp look_for_functions_in_module(nil, function, current_module) do
    look_for_functions_in_module(current_module, function, current_module)
  end

  defp look_for_functions_in_module(module, function, _current_module) do
    if ModuleInfo.has_function?(module, function) do
      {module, function}
    else
      {nil, nil}
    end
  end

  defp elixir_module?(module) do
    module == Module.concat(Elixir, module)
  end

end
