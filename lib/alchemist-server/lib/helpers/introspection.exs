defmodule Introspection do

  # From https://github.com/elixir-lang/elixir/blob/c983b3db6936ce869f2668b9465a50007ffb9896/lib/iex/lib/iex/introspection.ex

  alias Kernel.Typespec

  def get_docs_md(mod_str, fun_str) do
    mod = Module.concat([mod_str])
    fun = String.to_atom(fun_str)
    docs = Code.get_docs(mod, :docs)
    texts = for {{f, arity}, _, _, args, text} <- docs, f == fun do
      fun_args_text = Enum.map_join(args, ", ", &print_doc_arg(&1)) |> String.replace("\\\\", "\\\\\\\\")
      "> #{mod_str}.#{fun_str}(#{fun_args_text})\n\n### Specs\n\n`#{get_spec(mod, fun, arity)}`\n\n#{text}"
    end
    texts |> Enum.join("\n\n____\n\n")
  end

  def extract_fun_args_and_desc({ { _fun, _ }, _line, _kind, args, doc }) do
    args = Enum.map_join(args, ",", &print_doc_arg(&1))
    desc =
      (doc || "")
      |> String.split("\n\n")
      |> Enum.at(0)
      |> String.replace(~r/\n/, "_#LB#_")
    {args, desc}
  end

  def extract_fun_args_and_desc(nil) do
    {"", ""}
  end

  def get_spec(module, function, arity) when is_atom(module) and is_atom(function) and is_integer(arity) do
    case beam_specs(module) do
      nil   -> ""
      specs ->
        for {_kind, {{f, a}, _spec}} = spec <- specs, f == function and a == arity do
          spec |> spec_to_string
        end |> Enum.join("\n")
    end
  end

  defp print_doc_arg({ :\\, _, [left, right] }) do
    print_doc_arg(left) <> " \\\\ " <> Macro.to_string(right)
  end

  defp print_doc_arg({ var, _, _ }) do
    Atom.to_string(var)
  end

  defp spec_to_string({kind, {{name, _arity}, specs}}) do
    Enum.map specs, fn(spec) ->
      binary = Macro.to_string Typespec.spec_to_ast(name, spec)
      "@#{kind} #{binary}"
    end
  end

  defp beam_specs(module) do
    beam_specs_tag(Typespec.beam_specs(module), :spec)
  end

  defp beam_specs_tag(nil, _), do: nil
  defp beam_specs_tag(specs, tag) do
    Enum.map(specs, &{tag, &1})
  end

end
