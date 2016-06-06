Code.require_file "../helpers/complete.exs", __DIR__
Code.require_file "../code/introspection.exs", __DIR__
Code.require_file "../code/metadata.exs", __DIR__
Code.require_file "../code/parser.exs", __DIR__
Code.require_file "../code/state.exs", __DIR__

defmodule Alchemist.API.Comp do

  @moduledoc false

  alias Alchemist.Helpers.Complete
  alias Alchemist.Code.Metadata
  alias Alchemist.Code.Parser
  alias Alchemist.Code.Parser
  alias Alchemist.Code.State

  def request(args) do
    args
    |> normalize
    |> process
  end

  def process([nil, _, imports, _, _, _, _]) do
    Complete.run('', imports) ++ Complete.run('')
    |> print
  end

  def process([hint, _context, imports, aliases, vars, attributes, behaviours, scope]) do
    Application.put_env(:"alchemist.el", :aliases, aliases)

    list1 = Complete.run(hint, imports)
    list2 = Complete.run(hint)
    first_item = Enum.at(list2, 0)

    if first_item in [nil, ""] do
      first_item = "#{hint};hint"
    else
      list2 = List.delete_at(list2, 0)
    end

    callbacks_or_returns =
      case scope do
        {_f, _a} -> find_returns(behaviours, hint, scope)
        _mod   -> find_callbacks(behaviours, hint)
      end
    full_list = [first_item] ++ callbacks_or_returns ++ find_attributes(attributes, hint) ++ find_vars(vars, hint) ++ list1 ++ list2
    full_list |> print
  end

  defp normalize(request) do
    {{hint, buffer_file, line}, _} =  Code.eval_string(request)

    context = Elixir
    metadata = Parser.parse_file(buffer_file, true, true, line)
    %State.Env{
      imports: imports,
      aliases: aliases,
      vars: vars,
      attributes: attributes,
      behaviours: behaviours,
      module: module,
      scope: scope
    } = Metadata.get_env(metadata, line)

    [hint, context, [module|imports], aliases, vars, attributes, behaviours, scope]
  end

  defp print(result) do
    result
    |> Enum.uniq
    |> Enum.map(&IO.puts/1)

    IO.puts "END-OF-COMP"
  end

  defp find_vars(vars, hint) do
    for var <- vars, hint == "" or String.starts_with?("#{var}", hint) do
      "#{var};var"
    end |> Enum.sort
  end

  defp find_attributes(attributes, hint) do
    for attribute <- attributes, hint in ["", "@"] or String.starts_with?("@#{attribute}", hint) do
      "@#{attribute};attribute"
    end |> Enum.sort
  end

  defp find_returns(behaviours, "", {fun, arity}) do
    for mod <- behaviours, Introspection.define_callback?(mod, fun, arity) do
      for return <- Introspection.get_returns_from_callback(mod, fun, arity) do
        "#{return.description};return;#{return.spec};#{return.snippet}"
      end
    end |> List.flatten
  end
  defp find_returns(_behaviours, _hint, _) do
    []
  end

  defp find_callbacks(behaviours, hint) do
    behaviours |> Enum.flat_map(fn mod ->
      mod_name = mod |> Introspection.module_to_string
      for %{name: name, arity: arity, callback: spec, signature: signature, doc: doc} <- Introspection.get_callbacks_with_docs(mod),
          hint == "" or String.starts_with?("#{name}", hint)
      do
        desc = Introspection.extract_summary_from_docs(doc)
        [_, args_str] = Regex.run(~r/.\((.*)\)/, signature)
        args = args_str |> String.replace(~r/\s/, "")
        spec = spec |> String.replace(~r/\n/, "\\\\n")
        "#{name}/#{arity};callback;#{args};#{mod_name};#{desc};#{spec}"
      end
    end) |> Enum.sort
  end

end
