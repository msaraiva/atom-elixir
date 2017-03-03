defmodule ElixirSense.Providers.Signature do

  @moduledoc """
  Provider responsible for introspection information about function signatures.
  """

  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.Source
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
        %{active_param: npar, pipe_before: pipe_before, signatures: find_signatures(mod, func, imports, aliases, module, metadata)}
      _ ->
        :none
    end
  end

  defp find_signatures(mod, func, imports, aliases, module, metadata) do
    {actual_mod, actual_func} = Introspection.actual_mod_fun({mod, func}, imports, aliases, module)

    Metadata.get_function_signatures(metadata, module, func)
    |> Kernel.++(Introspection.get_signatures(actual_mod, actual_func))
    |> Enum.uniq_by(fn sig -> sig.params end)
  end

end
