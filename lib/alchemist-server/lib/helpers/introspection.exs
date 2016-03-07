defmodule Introspection do

  # Based on :
  # https://github.com/elixir-lang/elixir/blob/c983b3db6936ce869f2668b9465a50007ffb9896/lib/iex/lib/iex/introspection.ex
  # https://github.com/elixir-lang/ex_doc/blob/82463a56053b29a406fd271e9e2e2f05e87d6248/lib/ex_doc/retriever.ex

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

    title <> body <> "\u000B" <> get_types_md(mod) <> "\u000B" <> get_callbacks_md(mod)
  end

  def get_docs_md(mod, fun) do
    docs = Code.get_docs(mod, :docs)
    funcs_str =
      for {{f, arity}, _, _, args, text} <- docs, f == fun do
        fun_args_text = Enum.map_join(args, ", ", &print_doc_arg(&1)) |> String.replace("\\\\", "\\\\\\\\")
        mod_str = module_to_string(mod)
        fun_str = Atom.to_string(fun)
        "> #{mod_str}.#{fun_str}(#{fun_args_text})\n\n#{get_spec_text(mod, fun, arity)}#{text}"
      end |> Enum.join("\n\n____\n\n")

    funcs_str <> "\u000B" <> get_types_md(mod)
  end

  def get_types_md(mod) when is_atom(mod) do
    for %{type: type, doc: doc} <- get_types_with_docs(mod) do
      """
        `#{type}`

        #{doc}
      """
    end |> Enum.join("\n\n____\n\n")
  end

  def get_callbacks_md(mod) when is_atom(mod) do
    for %{callback: callback, signature: signature, doc: doc} <- get_callbacks_with_docs(mod) do
      """
        > #{signature}

        ### Specs

        `#{callback}`

        #{doc}
      """
    end |> Enum.join("\n\n____\n\n")
  end

  def get_types_with_docs(module) when is_atom(module) do
    get_types(module) |> Enum.map(fn {_, {t, _, _args}} = type ->
      %{type: format_type(type), doc: get_type_doc(module, t)}
    end)
  end

  defp get_types(module) when is_atom(module) do
    case Typespec.beam_types(module) do
      nil   -> []
      []    -> []
      types -> types
    end
  end

  defp format_type({:opaque, type}) do
    {:::, _, [ast, _]} = Typespec.type_to_ast(type)
    "@opaque #{Macro.to_string(ast)}" |> String.replace("()", "")
  end

  defp format_type({kind, type}) do
    ast = Typespec.type_to_ast(type)
    "@#{kind} #{Macro.to_string(ast)}" |> String.replace("()", "")
  end

  defp get_type_doc(module, type) do
    docs  = Code.get_docs(module, :type_docs)
    {{_, _}, _, _, description} = Enum.find(docs, fn({{name, _}, _, _, _}) ->
      type == name
    end)
    description || ""
  end

  defp get_callbacks_with_docs(mod) when is_atom(mod) do
    case get_callbacks_and_docs(mod) do
      {callbacks, docs} ->
        Enum.filter_map docs, &match?(_, &1), fn
          {{fun, arity}, _, :macrocallback, doc} ->
            get_callback_with_doc(fun, :macrocallback, doc, {:"MACRO-#{fun}", arity + 1}, callbacks)
          {{fun, arity}, _, kind, doc} ->
            get_callback_with_doc(fun, kind, doc, {fun, arity}, callbacks)
        end
      _ -> []
    end
  end

  defp get_callback_with_doc(name, kind, doc, key, callbacks) do
    {_, [spec | _]} = List.keyfind(callbacks, key, 0)
    {_f, arity} = key

    spec_ast = Typespec.spec_to_ast(name, spec)
    signature = get_typespec_signature(spec_ast, arity)

    definition =
      spec_ast
      |> Macro.prewalk(&drop_macro_env/1)
      |> Macro.to_string
      |> String.replace("()", "")

    %{callback: "@#{kind} #{definition}", signature: signature, doc: doc}
  end

  defp get_callbacks_and_docs(mod) do
    callbacks = Typespec.beam_callbacks(mod)
    docs = Code.get_docs(mod, :callback_docs)

    cond do
      is_nil(callbacks) -> {[], []}
      is_nil(docs) -> {[], []}
      true -> {callbacks, docs}
    end
  end

  defp drop_macro_env({name, meta, [{:::, _, [{:env, _, _}, _ | _]} | args]}), do: {name, meta, args}
  defp drop_macro_env(other), do: other

  defp get_typespec_signature({:when, _, [{:::, _, [{name, meta, args}, _]}, _]}, arity) do
    Macro.to_string {name, meta, strip_types(args, arity)}
  end

  defp get_typespec_signature({:::, _, [{name, meta, args}, _]}, arity) do
    Macro.to_string {name, meta, strip_types(args, arity)}
  end

  defp get_typespec_signature({name, meta, args}, arity) do
    Macro.to_string {name, meta, strip_types(args, arity)}
  end

  defp strip_types(args, arity) do
    args
    |> Enum.take(-arity)
    |> Enum.with_index()
    |> Enum.map(fn
      {{:::, _, [left, _]}, i} -> to_var(left, i)
      {{:|, _, _}, i}          -> to_var({}, i)
      {left, i}                -> to_var(left, i)
    end)
  end

  defp to_var({name, meta, _}, _) when is_atom(name),
    do: {name, meta, nil}
  defp to_var({:<<>>, _, _}, _),
    do: {:binary, [], nil}
  defp to_var({:%{}, _, _}, _),
    do: {:map, [], nil}
  defp to_var({:{}, _, _}, _),
    do: {:tuple, [], nil}
  defp to_var({_, _}, _),
    do: {:tuple, [], nil}
  defp to_var(integer, _) when is_integer(integer),
    do: {:integer, [], nil}
  defp to_var(float, _) when is_integer(float),
    do: {:float, [], nil}
  defp to_var(list, _) when is_list(list),
    do: {:list, [], nil}
  defp to_var(atom, _) when is_atom(atom),
    do: {:atom, [], nil}
  defp to_var(_, i),
    do: {:"arg#{i}", [], nil}

  def get_module_docs_summary(module) do
    case Code.get_docs module, :moduledoc do
      {_, doc} -> extract_summary_from_docs(doc)
      _ -> ""
    end
  end

  def get_module_subtype(module) do
    has_func = fn f,a -> Code.ensure_loaded?(module) && Kernel.function_exported?(module,f,a) end
    cond do
      has_func.(:__protocol__, 1) -> :protocol
      has_func.(:__impl__,     1) -> :implementation
      has_func.(:__struct__,   0) -> if Map.get(module.__struct__, :__exception__), do: :exception, else: :struct
      true -> nil
    end
  end

  def extract_fun_args_and_desc({ { _fun, _ }, _line, _kind, args, doc }) do
    args = Enum.map_join(args, ",", &print_doc_arg(&1)) |> String.replace(~r/\s+/, " ")
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
    spec = hd(specs)
    binary = Macro.to_string Typespec.spec_to_ast(name, spec)
    "@#{kind} #{binary}" |> String.replace("()", "")
  end

  defp beam_specs(module) do
    beam_specs_tag(Typespec.beam_specs(module), :spec)
  end

  defp beam_specs_tag(nil, _), do: nil
  defp beam_specs_tag(specs, tag) do
    Enum.map(specs, &{tag, &1})
  end

end
