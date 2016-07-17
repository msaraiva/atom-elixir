defmodule ElixirSense.Providers.Docs do

  alias Alchemist.Helpers.ModuleInfo
  alias ElixirSense.Core.Introspection

  @spec all(String.t, [module], [{module, module}]) :: Introspection.docs
  def all(expr, modules, aliases) do
    search(expr, modules, aliases)
  end

  defp search(nil), do: true
  defp search(expr) do
    {module, function} = Introspection.split_mod_func_call(expr)
    Introspection.get_all_docs(module, function)
  end

  defp search(expr, modules, []) do
    expr = to_string expr
    unless function?(expr) do
      search(expr)
    else
      search_with_context(modules, expr)
    end
  end

  defp search(expr, modules, aliases) do
    unless function?(expr) do
      String.split(expr, ".")
      |> ModuleInfo.expand_alias(aliases)
      |> search
    else
      search_with_context(modules, expr)
    end
  end

  defp search_with_context(modules, expr) do
    modules ++ [Kernel, Kernel.SpecialForms]
    |> build_search(expr)
    |> search
  end

  defp build_search(modules, search) do
    function = Regex.replace(~r/\/[0-9]$/, search, "")
    function = String.to_atom(function)
    for module <- modules,
    ModuleInfo.docs?(module, function) do
      "#{module}.#{search}"
    end |> List.first
  end

  defp function?(expr) do
    Regex.match?(~r/^[a-z_]/, expr)
  end

end
