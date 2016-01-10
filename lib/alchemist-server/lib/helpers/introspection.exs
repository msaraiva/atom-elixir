defmodule Introspection do

  # From https://github.com/elixir-lang/elixir/blob/c983b3db6936ce869f2668b9465a50007ffb9896/lib/iex/lib/iex/introspection.ex

  alias Kernel.Typespec

  def get_docs_md(mod, nil) do
    mod_str = module_to_string(mod)
    title = "> #{mod_str}\n\n"
    body = case Code.get_docs(mod, :moduledoc) do
      {_line, false} ->
        "No documentation found"
      {_line, doc} ->
        doc
    end
    title <> body
  end

  def get_docs_md(mod, fun) do
    docs = Code.get_docs(mod, :docs)
    texts = for {{f, arity}, _, _, args, text} <- docs, f == fun do
      fun_args_text = Enum.map_join(args, ", ", &print_doc_arg(&1)) |> String.replace("\\\\", "\\\\\\\\")
      mod_str = module_to_string(mod)
      fun_str = Atom.to_string(fun)
      "> #{mod_str}.#{fun_str}(#{fun_args_text})\n\n#{get_spec_text(mod, fun, arity)}#{text}"
    end
    texts |> Enum.join("\n\n____\n\n")
  end

  def get_module_docs_summary(module) do
    case Code.get_docs module, :moduledoc do
      {_, doc} -> extract_summary_from_docs(doc)
      _ -> ""
    end
  end

  def extract_fun_args_and_desc({ { _fun, _ }, _line, _kind, args, doc }) do
    args = Enum.map_join(args, ",", &print_doc_arg(&1))
    desc = extract_summary_from_docs(doc)
    {args, desc}
  end

  def extract_fun_args_and_desc(nil) do
    {"", ""}
  end

  def get_module_specs(module) do
    case beam_specs(module) do
      nil   -> %{}
      specs ->
        for {_kind, {{f, a}, _spec}} = spec <- specs, into: %{} do
          {{f,a}, spec_to_string(spec)}
        end
    end
  end

  def get_spec(module, function, arity) when is_atom(module) and is_atom(function) and is_integer(arity) do
    module
    |> get_module_specs
    |> Map.get({function, arity}, "")
  end

  def get_spec_text(mod, fun, arity) do
    case get_spec(mod, fun, arity) do
      ""  -> ""
      spec ->
        "### Specs\n\n`#{spec}`\n\n"
    end
  end

  def module_to_string(module) do
    case module |> Atom.to_string do
      "Elixir." <> name -> name
      name -> ":#{name}"
    end
  end

  def split_mod_func_call(call) do
    {:ok, quoted} = call |> Code.string_to_quoted
    case Macro.decompose_call(quoted) do
      {{:__aliases__, _, mod_parts}, fun, _args} ->
        {Module.concat(mod_parts), fun}
      {:__aliases__, mod_parts} ->
        {Module.concat(mod_parts), nil}
      _ -> {:error, "Could not split call: #{call}"}
    end
  end

  def module_functions_info(module) do
    docs = Code.get_docs(module, :docs) || []
    specs = get_module_specs(module)
    for {{f, a}, _line, func_kind, _sign, doc} = func_doc <- docs, doc != false, into: %{} do
      spec = Map.get(specs, {f,a}, "")
      {fun_args, desc} = extract_fun_args_and_desc(func_doc)
      {{f, a}, {func_kind, fun_args, desc, spec}}
    end
  end

  defp extract_summary_from_docs(doc) when doc in [nil, "", false], do: ""
  defp extract_summary_from_docs(doc) do
    doc
    |> String.split("\n\n")
    |> Enum.at(0)
    |> String.replace(~r/\n/, "\\\\n")
    |> String.replace(";", "\\;")
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
      "@#{kind} #{binary}" |> String.replace("()", "")
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
