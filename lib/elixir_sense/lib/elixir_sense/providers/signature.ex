defmodule ElixirSense.Providers.Signature do

  @moduledoc """
  Provider responsible for introspection information about function signatures.
  """

  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.Source
  alias Alchemist.Helpers.ModuleInfo

  @type signature :: %{name: String.t, params: [String.t]}
  @type signature_info :: %{active_param: pos_integer, signatures: [signature]} | :none

  @doc """
  Returns the signature info from the function defined in the prefix, if any.

  ## Examples

      iex> Signature.find("MyList.flatten(par0, par1, ", [], [{MyList, List}])
      %{active_param: 2,
        signatures: [
          %{name: "flatten", params: ["list"]},
          %{name: "flatten", params: ["list", "tail"]}]}

  """
  @spec find(String.t, [module], [{module, module}]) :: signature_info
  def find(prefix, imports, aliases) do
    case prefix |> Source.which_func do
      {mod, func, npar} ->
        {mod, func} = original_mod_fun({mod, func}, imports, aliases)
        %{active_param: npar, signatures: Introspection.get_signatures(mod, func)}
      _ ->
        :none
    end
  end

  defp original_mod_fun({nil, function}, [], []) do
    look_for_kernel_functions(function)
  end

  defp original_mod_fun({nil, function}, imports, _) do
    module = Enum.filter(imports, &ModuleInfo.has_function?(&1, function))
    |> List.first

    case module do
      nil -> look_for_kernel_functions(function)
      _   -> {module, function}
    end
  end

  defp original_mod_fun({module, function}, _, aliases) do
    mod =
      if elixir_module?(module) do
        module
        |> Module.split
        |> ModuleInfo.expand_alias(aliases)
      else
        module
      end
    {mod, function}
  end

  defp look_for_kernel_functions(function) do
    cond do
      ModuleInfo.docs?(Kernel, function) ->
        {Kernel, function}
      ModuleInfo.docs?(Kernel.SpecialForms, function) ->
        {Kernel.SpecialForms, function}
      true -> {nil, nil}
    end
  end

  defp elixir_module?(module) do
    module == Module.concat(Elixir, module)
  end

end
