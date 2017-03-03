defmodule ElixirSense.Providers.Docs do

  alias ElixirSense.Core.Introspection

  @spec all(String.t, [module], [{module, module}], module) :: Introspection.docs
  def all(subject, imports, aliases, module) do
    {actual_mod, actual_func} =
      subject
      |> Introspection.split_mod_func_call
      |> Introspection.actual_mod_fun(imports, aliases, module)
    actual_subject = mod_func_to_string({actual_mod, actual_func})
    {actual_subject, Introspection.get_all_docs(actual_mod, actual_func)}
  end

  defp mod_func_to_string({nil, func}) do
    Atom.to_string(func)
  end

  defp mod_func_to_string({mod, nil}) do
    Introspection.module_to_string(mod)
  end

  defp mod_func_to_string({mod, func}) do
    Introspection.module_to_string(mod) <> "." <> Atom.to_string(func)
  end

end
