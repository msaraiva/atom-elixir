Code.require_file "./state.exs", __DIR__

if Version.match?(System.version, "<1.2.0-rc.0") do
  Code.require_file "./traverse.exs", __DIR__
end

defmodule Alchemist.Code.MetadataBuilder do
  import Alchemist.Code.State

  @scope_keywords [:for, :try, :fn]
  @block_keywords [:do, :else, :rescue, :catch, :after]

  def build(ast) do
    state = Alchemist.Code.State.new
    mod = if Version.match?(System.version, "<1.2.0-rc.0"), do: Traverse, else: Macro
    mod.traverse(ast, state, &pre/2, &post/2)
  end

  defp pre({:defmodule, [line: line], [{:__aliases__, _, module}, _]} = ast, state) do
    state
    |> new_namespace(module)
    |> add_current_module_to_index(line)
    |> create_alias_for_current_module
    |> new_alias_scope
    |> new_import_scope
    |> new_vars_scope
    |> result(ast)
  end

  #TODO: create do_def
  defp pre({def_fun, meta, [{:when, _, [head|_]}, body]}, state) when def_fun in [:def, :defp] do
    pre({:def, meta, [head, body]}, state)
  end

  defp pre({def_fun, [line: line], [{name, _, params}, _body]} = ast, state) when def_fun in [:def, :defp] and is_atom(name) do
    state
    |> new_named_func(name)
    |> add_current_env_to_line(line)
    |> add_func_to_index(name, length(params || []), line)
    |> new_alias_scope
    |> new_import_scope
    |> new_func_vars_scope
    |> add_vars(find_vars(params))
    |> result(ast)
  end

  defp pre({def_fun, _, _} = ast, state) when def_fun in [:def, :defp] do
    {ast, state}
  end

  # Macro without body. Ex: Kernel.SpecialForms.import
  defp pre({:defmacro, meta, [head]}, state) do
    pre({:defmacro, meta, [head,nil]}, state)
  end

  defp pre({:defmacro, meta, args}, state) do
    pre({:def, meta, args}, state)
  end

  # import without options
  defp pre({:import, meta, [module_info]}, state) do
    pre({:import, meta, [module_info, []]}, state)
  end

  # import with options
  defp pre({:import, [line: line], [{_, _, module_atoms = [mod|_]}, _opts]} = ast, state) when is_atom(mod) do
    state
    |> add_current_env_to_line(line)
    |> add_import(module_atoms |> Module.concat)
    |> result(ast)
  end

  # alias without options
  defp pre({:alias, [line: line], [{:__aliases__, _, module_atoms = [mod|_]}]} = ast, state) when is_atom(mod) do
    alias_tuple = {Module.concat([List.last(module_atoms)]), Module.concat(module_atoms)}
    do_alias(ast, line, alias_tuple, state)
  end

  # alias with `as` option
  defp pre({:alias, [line: line], [{_, _, module_atoms = [mod|_]}, [as: {:__aliases__, _, alias_atoms = [al|_]}]]} = ast, state) when is_atom(mod) and is_atom(al) do
    alias_tuple = {Module.concat(alias_atoms), Module.concat(module_atoms)}
    do_alias(ast, line, alias_tuple, state)
  end

  defp pre({atom, [line: line], _} = ast, state) when atom in @scope_keywords do
    state
    |> add_current_env_to_line(line)
    |> new_vars_scope
    |> result(ast)
  end

  defp pre({atom, _block} = ast, state) when atom in @block_keywords do
    state
    |> new_alias_scope
    |> new_import_scope
    |> new_vars_scope
    |> result(ast)
  end

  defp pre({:->, [line: _line], [lhs, _rhs]} = ast, state) do
    state
    |> new_alias_scope
    |> new_import_scope
    |> new_vars_scope
    |> add_vars(find_vars(lhs))
    |> result(ast)
  end

  defp pre({:=, _meta, [lhs, _rhs]} = ast, state) do
    state
    |> add_vars(find_vars(lhs))
    |> result(ast)
  end

  defp pre({:<-, _meta, [lhs, _rhs]} = ast, state) do
    state
    |> add_vars(find_vars(lhs))
    |> result(ast)
  end

  # Any other tuple with a line
  defp pre({_, [line: line], _} = ast, state) do
    state
    |> add_current_env_to_line(line)
    |> result(ast)
  end

  # No line defined
  defp pre(ast, state) do
    {ast, state}
  end

  defp do_alias(ast, line, alias_tuple, state) do
    state
    |> add_current_env_to_line(line)
    |> add_alias(alias_tuple)
    |> result(ast)
  end

  defp post({:defmodule, _, [{:__aliases__, _, module}, _]} = ast, state) do
    state
    |> remove_module_from_namespace(module)
    |> remove_alias_scope
    |> remove_import_scope
    |> remove_vars_scope
    |> result(ast)
  end

  defp post({def_fun, meta, [{:when, _, [head|_]}, body]}, state) when def_fun in [:def, :defp] do
    pre({:def, meta, [head, body]}, state)
  end

  defp post({def_fun, [line: _line], [{name, _, _params}, _]} = ast, state) when def_fun in [:def, :defp] and is_atom(name) do
    state
    |> remove_alias_scope
    |> remove_import_scope
    |> remove_func_vars_scope
    |> remove_last_scope_from_scopes
    |> result(ast)
  end
  
  defp post({def_fun, _, _} = ast, state) when def_fun in [:def, :defp] do
    {ast, state}
  end

  # Macro without body. Ex: Kernel.SpecialForms.import
  defp post({:defmacro, meta, [head]}, state) do
    post({:def, meta, [head,nil]}, state)
  end

  defp post({:defmacro, meta, args}, state) do
    post({:def, meta, args}, state)
  end

  defp post({atom, _, _} = ast, state) when atom in @scope_keywords do
    state
    |> remove_vars_scope
    |> result(ast)
  end

  defp post({atom, _block} = ast, state) when atom in @block_keywords do
    state
    |> remove_alias_scope
    |> remove_import_scope
    |> remove_vars_scope
    |> result(ast)
  end

  defp post({:->, [line: _line], [_lhs, _rhs]} = ast, state) do
    state
    |> remove_alias_scope
    |> remove_import_scope
    |> remove_vars_scope
    |> result(ast)
  end

  defp post(ast, state) do
    {ast, state}
  end

  defp result(state, ast) do
    {ast, state}
  end

  defp find_vars(ast) do
    {_ast, vars} = Macro.prewalk(ast, [], &match_var/2)
    vars |> Enum.uniq
  end

  defp match_var({var, [line: _], context} = ast, vars) when is_atom(var) and context in [nil, Elixir] do
    {ast, [var|vars]}
  end

  defp match_var(ast, vars) do
    {ast, vars}
  end

end
