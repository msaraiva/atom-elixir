defmodule Ast do

  defmodule FileMetadata do
    defstruct [:source, :cursor_line, :ast, :mods_funs_to_lines, :lines_to_context, :parsed, :source_changed, :error, :changes]

    def parse_file(file, try_to_fix_parse_error, try_to_fix_line_not_found, cursor_line_number) do
      case File.read(file) do
        {:ok, source} ->
          parse_string(source, try_to_fix_parse_error, try_to_fix_line_not_found, cursor_line_number)
        error -> error
      end
    end

    def parse_string(source, try_to_fix_parse_error, try_to_fix_line_not_found, cursor_line_number) do
      case string_to_ast(source, try_to_fix_parse_error, cursor_line_number) do
        {:ok, ast} ->
          {_ast, acc} = Ast.parse(ast)
          if Map.has_key?(acc.lines_to_context, cursor_line_number) or !try_to_fix_line_not_found  do
            %FileMetadata{
              source: source,
              mods_funs_to_lines: acc.mods_funs_to_lines,
              lines_to_context: acc.lines_to_context,
              parsed: true
            }
          else
            IO.puts :stderr, "LINE NOT FOUND"
            source
            |> fix_line_not_found(cursor_line_number)
            |> parse_string(false, false, cursor_line_number)
          end
        {:error, error} ->
          IO.puts :stderr, "CAN'T FIX IT"
          IO.inspect :stderr, error, []
          %FileMetadata{
            source: source,
            parsed: false,
            error: error
          }
      end
    end

    def get_line_context(%FileMetadata{lines_to_context: nil}, _line_number) do
      %{imports: [], aliases: [], module: nil}
    end

    def get_line_context(metadata = %FileMetadata{}, line_number) do
      case Map.get(metadata.lines_to_context, line_number) do
        nil -> %{imports: [], aliases: [], module: nil}
        ctx -> ctx
      end
    end

    def get_function_line(metadata = %FileMetadata{}, module, function) do
      line = Map.get(metadata.mods_funs_to_lines, {module, function, nil})
      if line == nil do
        line = get_function_line_using_docs(module, function)
      end
      line
    end

    defp get_function_line_using_docs(module, function) do
      docs = Code.get_docs(module, :docs)

      for {{func, _arity}, line, _kind, _, _} <- docs, func == function do
        line
      end |> Enum.at(0)
    end

    defp string_to_ast(source, try_to_fix_parse_error, cursor_line_number) do
      case Code.string_to_quoted(source) do
        {:ok, ast} ->
          {:ok, ast}
        error ->
          IO.puts :stderr, "PARSE ERROR"
          IO.inspect :stderr, error, []
          if try_to_fix_parse_error do
            source
            |> fix_parse_error(cursor_line_number, error)
            |> string_to_ast(false, cursor_line_number)
          else
            error
          end
      end
    end

    defp fix_parse_error(source, _cursor_line_number, {:error, {_line, {_error_type, text}, _token}}) do
      IO.puts :stderr, "fix_parse_error(source, _cursor_line_number, {:error, {_line, {_error_type, text}, _token}})"
      [_, line] = Regex.run(~r/line\s(\d\d)/, text)
      line = line |> String.to_integer
      source
      |> replace_line_with_marker(line)
    end

    defp fix_parse_error(source, _cursor_line_number, {:error, {line, "syntax" <> _, _token}}) when is_integer(line) do
      IO.puts :stderr, "fix_parse_error(source, _cursor_line_number, {:error, {line, _error, _token}}) when is_integer(line)"
      source
      |> replace_line_with_marker(line)
    end

    defp fix_parse_error(_, nil, error) do
      IO.puts :stderr, "fix_parse_error(_, nil, error)"
      error
    end

    defp fix_parse_error(source, cursor_line_number, _error) do
      IO.puts :stderr, "fix_parse_error(source, cursor_line_number, _error)"
      source
      |> replace_line_with_marker(cursor_line_number)
    end

    defp fix_line_not_found(source, line_number) do
      IO.puts :stderr, "fix_line_not_found(source, line_number)"
      source |> replace_line_with_marker(line_number)
    end

    defp replace_line_with_marker(source, line) do
      IO.puts :stderr, "REPLACING LINE: #{line}"
      source
      |> String.split(["\n", "\r\n"])
      |> List.replace_at(line-1, "(__atom_elixir_marker_#{line}__())")
      |> Enum.join("\n")
    end

  end

  def parse(ast) do
    acc = %{
      modules: [:Elixir],
      scopes:  [:Elixir],
      imports: [[]],
      aliases: [[]],
      mods_funs_to_lines: %{},
      lines_to_context: %{}
    }
    traverse(ast, acc, &pre/2, &post/2)
  end

  defp pre(ast = {:defmodule, [line: line], [{:__aliases__, _, module}, _]}, acc) do
    modules_reversed = :lists.reverse(module)
    modules = modules_reversed ++ acc.modules
    scopes  = modules_reversed ++ acc.scopes
    imports = [[]|acc.imports]

    current_module = modules |> :lists.reverse |> Module.concat
    mods_funs_to_lines = Map.put(acc.mods_funs_to_lines, {current_module, nil, nil}, line)

    aliases = acc.aliases

    # TODO: Context.add_alias_to_current_scope(context)
    # Context.add_import_to_current_scope(context)
    # Context.create_new_scope(context)
    # ...

    # create alias for the module in the current scope
    if length(modules) > 2 do
      alias_tuple = {Module.concat([hd(modules)]), current_module}
      [aliases_from_scope|other_aliases] = acc.aliases
      aliases = [[alias_tuple|aliases_from_scope]|other_aliases]
    end

    # add new empty list of aliases for the new scope
    aliases = [[]|aliases]

    {ast, %{acc | modules: modules, scopes: scopes, imports: imports, aliases: aliases, mods_funs_to_lines: mods_funs_to_lines}}
  end

  defp pre({def_fun, meta, [{:when, _, [head|_]}, body]}, acc) when def_fun in [:def, :defp] do
    pre({:def, meta, [head, body]}, acc)
  end

  defp pre(ast = {def_fun, [line: line], [{name, _, params}, _body]}, acc) when def_fun in [:def, :defp] do
    current_module  = acc.modules |> :lists.reverse |> Module.concat
    current_imports = acc.imports |> :lists.reverse |> List.flatten
    current_aliases = acc.aliases |> :lists.reverse |> List.flatten

    scopes  = [name|acc.scopes]
    imports = [[]|acc.imports]
    aliases = [[]|acc.aliases]

    mods_funs_to_lines = Map.put(acc.mods_funs_to_lines, {current_module, name, length(params || [])}, line)
    if !Map.has_key?(acc.mods_funs_to_lines, {current_module, name, nil}) do
      mods_funs_to_lines = Map.put(acc.mods_funs_to_lines, {current_module, name, nil}, line)
    end
    lines_to_context = Map.put(acc.lines_to_context, line, %{imports: current_imports, aliases: current_aliases, module: current_module})

    {ast, %{acc | scopes: scopes, imports: imports, aliases: aliases, mods_funs_to_lines: mods_funs_to_lines, lines_to_context: lines_to_context}}
  end

  # Macro without body. Ex: Kernel.SpecialForms.import
  defp pre({:defmacro, meta, [head]}, acc) do
    pre({:defmacro, meta, [head,nil]}, acc)
  end

  defp pre({:defmacro, meta, args}, acc) do
    pre({:def, meta, args}, acc)
  end

  # import without options
  defp pre({:import, meta, [module_info]}, acc) do
    pre({:import, meta, [module_info, []]}, acc)
  end

  defp pre(ast = {:import, [line: line], [{_, _, module_atoms = [mod|_]}, _opts]}, acc) when is_atom(mod) do
    current_module  = acc.modules |> :lists.reverse |> Module.concat
    current_imports = acc.imports |> :lists.reverse |> List.flatten
    current_aliases = acc.aliases |> :lists.reverse |> List.flatten
    lines_to_context = Map.put(acc.lines_to_context, line, %{imports: current_imports, aliases: current_aliases, module: current_module})

    module = Module.concat(module_atoms)
    [imports_from_scope|other_imports] = acc.imports
    imports = [[module|imports_from_scope]|other_imports]

    {ast, %{acc | imports: imports, lines_to_context: lines_to_context}}
  end

  # alias without options
  defp pre(ast = {:alias, [line: line], [{:__aliases__, _, module_atoms = [mod|_]}]}, acc) when is_atom(mod) do
    alias_tuple = {Module.concat([List.last(module_atoms)]), Module.concat(module_atoms)}
    do_alias(ast, line, alias_tuple, acc)
  end

  defp pre(ast = {:alias, [line: line], [{_, _, module_atoms = [mod|_]}, [as: {:__aliases__, _, alias_atoms = [al|_]}]]}, acc) when is_atom(mod) and is_atom(al) do
    alias_tuple = {Module.concat(alias_atoms), Module.concat(module_atoms)}
    do_alias(ast, line, alias_tuple, acc)
  end

  defp pre(ast = {_, [line: line], _}, acc) do
    current_module  = acc.modules |> :lists.reverse |> Module.concat
    current_imports = acc.imports |> :lists.reverse |> List.flatten
    current_aliases = acc.aliases |> :lists.reverse |> List.flatten
    lines_to_context = Map.put(acc.lines_to_context, line, %{imports: current_imports, aliases: current_aliases, module: current_module})

    {ast, %{acc | lines_to_context: lines_to_context}}
  end

  defp pre(ast, acc) do
    # IO.puts "No line"
    {ast, acc}
  end

  defp do_alias(ast, line, alias_tuple, acc) do
    current_module  = acc.modules |> :lists.reverse |> Module.concat
    current_imports = acc.imports |> :lists.reverse |> List.flatten
    current_aliases = acc.aliases |> :lists.reverse |> List.flatten
    lines_to_context = Map.put(acc.lines_to_context, line, %{imports: current_imports, aliases: current_aliases, module: current_module})

    [aliases_from_scope|other_aliases] = acc.aliases
    aliases = [[alias_tuple|aliases_from_scope]|other_aliases]

    {ast, %{acc | aliases: aliases, lines_to_context: lines_to_context}}
  end

  defp post(ast = {:defmodule, _, [{:__aliases__, _, module}, _]}, acc) do
    outer_mods   = Enum.drop(acc.modules, length(module))
    outer_scopes = Enum.drop(acc.scopes, length(module))
    {ast, %{acc | modules: outer_mods, scopes: outer_scopes, imports: tl(acc.imports), aliases: tl(acc.aliases)}}
  end

  defp post({def_fun, meta, [{:when, _, [head|_]}, body]}, acc) when def_fun in [:def, :defp] do
    pre({:def, meta, [head, body]}, acc)
  end

  defp post(ast = {def_fun, [line: _line], [{_name, _, _params}, _]}, acc) when def_fun in [:def, :defp] do
    {ast, %{acc | scopes: tl(acc.scopes), imports: tl(acc.imports), aliases: tl(acc.aliases)}}
  end

  # Macro without body. Ex: Kernel.SpecialForms.import
  defp post({:defmacro, meta, [head]}, acc) do
    post({:def, meta, [head,nil]}, acc)
  end

  defp post({:defmacro, meta, args}, acc) do
    post({:def, meta, args}, acc)
  end

  defp post(ast, acc) do
    {ast, acc}
  end

  # From: https://github.com/elixir-lang/elixir/blob/bd3332c8484f791eba8c7db875cebdcd34d8112b/lib/elixir/lib/macro.ex#L175
  defp traverse(ast, acc, pre, post) when is_function(pre, 2) and is_function(post, 2) do
    {ast, acc} = pre.(ast, acc)
    do_traverse(ast, acc, pre, post)
  end

  defp do_traverse({form, meta, args}, acc, pre, post) do
    unless is_atom(form) do
      {form, acc} = pre.(form, acc)
      {form, acc} = do_traverse(form, acc, pre, post)
    end

    unless is_atom(args) do
      {args, acc} = Enum.map_reduce(args, acc, fn x, acc ->
        {x, acc} = pre.(x, acc)
        do_traverse(x, acc, pre, post)
      end)
    end

    post.({form, meta, args}, acc)
  end

  defp do_traverse({left, right}, acc, pre, post) do
    {left, acc} = pre.(left, acc)
    {left, acc} = do_traverse(left, acc, pre, post)
    {right, acc} = pre.(right, acc)
    {right, acc} = do_traverse(right, acc, pre, post)
    post.({left, right}, acc)
  end

  defp do_traverse(list, acc, pre, post) when is_list(list) do
    {list, acc} = Enum.map_reduce(list, acc, fn x, acc ->
      {x, acc} = pre.(x, acc)
      do_traverse(x, acc, pre, post)
    end)
    post.(list, acc)
  end

  defp do_traverse(x, acc, _pre, post) do
    post.(x, acc)
  end

end
