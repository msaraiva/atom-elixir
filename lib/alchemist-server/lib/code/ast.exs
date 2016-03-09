Code.require_file "../helpers/introspection.exs", __DIR__

defmodule Alchemist.Code.Ast do

  @empty_env_info %{requires: [], imports: [], behaviours: []}

  @partials [:def, :defp, :defmodule, :@, :defmacro, :defmacrop, :defoverridable, :__ENV__, :__CALLER__, :raise, :if, :unless, :in]

  def extract_use_info(use_ast, module) do
    try do
      env = Map.put(__ENV__, :module, module)
      {expanded_ast, _requires} = Macro.prewalk(use_ast, env, &do_expand/2)
      {_ast, env_info} = Macro.prewalk(expanded_ast, @empty_env_info, &pre_walk_expanded/2)
      env_info
    rescue
      _e ->
        # IO.puts(:stderr, "Expanding #{Macro.to_string(use_ast)} failed.")
        # IO.puts(:stderr, Exception.message(e) <> "\n" <> Exception.format_stacktrace(System.stacktrace))
        @empty_env_info
    end
  end

  def expand_partial(ast, env) do
    {expanded_ast, _} = Macro.prewalk(ast, env, &do_expand_partial/2)
    expanded_ast
  end

  def expand_all(ast, env) do
    {expanded_ast, _} = Macro.prewalk(ast, env, &do_expand_all/2)
    expanded_ast
  end

  def set_module_for_env(env, module) do
    Map.put(env, :module, module)
  end

  def add_requires_to_env(env, modules) do
    add_directive_modules_to_env(env, :require, modules)
  end

  def add_imports_to_env(env, modules) do
    add_directive_modules_to_env(env, :import, modules)
  end

  defp add_directive_modules_to_env(env, directive, modules) do
    directive_string = modules
    |> Enum.map(&"#{directive} #{Introspection.module_to_string(&1)}")
    |> Enum.join("; ")
    {new_env, _} = Code.eval_string("#{directive_string}; __ENV__", [], env)
    new_env
  end

  defp do_expand_all(ast, env) do
    do_expand(ast, env)
  end

  defp do_expand_partial({name, _, _} = ast, env) when name in @partials do
    {ast, env}
  end
  defp do_expand_partial(ast, env) do
    do_expand(ast, env)
  end

  defp do_expand({:require, _, _} = ast, env) do
    modules = extract_directive_modules(:require, ast)
    new_env = add_requires_to_env(env, modules)
    {ast, new_env}
  end

  defp do_expand(ast, env) do
    do_expand_with_fixes(ast, env)
  end

  # Fix inexpansible `use ExUnit.Case`
  defp do_expand_with_fixes({:use, _, [{:__aliases__, _, [:ExUnit, :Case]}|_]}, env) do
    ast = quote do
      import ExUnit.Callbacks
      import ExUnit.Assertions
      import ExUnit.Case
      import ExUnit.DocTest
    end
    {ast, env}
  end

  defp do_expand_with_fixes(ast, env) do
    expanded_ast = Macro.expand(ast, env)
    {expanded_ast, env}
  end

  defp pre_walk_expanded({:__block__, _, _} = ast, acc) do
    {ast, acc}
  end
  defp pre_walk_expanded({:require, _, _} = ast, acc) do
    modules = extract_directive_modules(:require, ast)
    {ast, %{acc | requires: (acc.requires ++ modules)}}
  end
  defp pre_walk_expanded({:import, _, _} = ast, acc) do
    modules = extract_directive_modules(:import, ast)
    {ast, %{acc | imports: (acc.imports ++ modules)}}
  end
  defp pre_walk_expanded({:@, _, [{:behaviour, _, [module]}]} = ast, acc) do
    {ast, %{acc | behaviours: [module|acc.behaviours]}}
  end
  defp pre_walk_expanded({_name, _meta, _args}, acc) do
    {nil, acc}
  end
  defp pre_walk_expanded(ast, acc) do
    {ast, acc}
  end

  defp extract_directive_modules(directive, ast) do
    case ast do
      # v1.2 notation
      {^directive, _, [{{:., _, [{:__aliases__, _, prefix_atoms}, :{}]}, _, aliases}]} ->
        aliases |> Enum.map(fn {:__aliases__, _, mods} ->
          Module.concat(prefix_atoms ++ mods)
        end)
      # with options
      {^directive, _, [{_, _, module_atoms = [mod|_]}, _opts]} when is_atom(mod) ->
        [module_atoms |> Module.concat]
      # with options
      {^directive, _, [module, _opts]} when is_atom(module) ->
        [module]
      # with options
      {^directive, _, [{:__aliases__, _, module_parts}, _opts]} ->
        [module_parts |> Module.concat]
      # without options
      {^directive, _, [{:__aliases__, _, module_parts}]} ->
        [module_parts |> Module.concat]
      # without options
      {^directive, _, [{:__aliases__, [alias: false, counter: _], module_parts}]} ->
        [module_parts |> Module.concat]
      # without options
      {^directive, _, [module]} ->
        [module]
    end
  end
end
