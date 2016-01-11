Code.require_file "../helpers/complete.exs", __DIR__
Code.require_file "../code/metadata.exs", __DIR__
Code.require_file "../code/parser.exs", __DIR__

defmodule Alchemist.API.Comp do

  @moduledoc false

  alias Alchemist.Helpers.Complete
  alias Alchemist.Code.Metadata
  alias Alchemist.Code.Parser

  def request(args) do
    args
    |> normalize
    |> process
  end

  def process([nil, _, imports, _]) do
    Complete.run('', imports) ++ Complete.run('')
    |> print
  end

  def process([hint, _context, imports, aliases]) do
    Application.put_env(:"alchemist.el", :aliases, aliases)

    list1 = Complete.run(hint, imports)
    list2 = Complete.run(hint)
    first_item = Enum.at(list2, 0)

    if first_item in [nil, ""] do
      first_item = hint
    else
      list2 = List.delete_at(list2, 0)
    end

    full_list = [first_item] ++ list1 ++ list2
    full_list |> print
  end

  defp normalize(request) do
    {{hint, buffer_file, line}, _} =  Code.eval_string(request)

    context = Elixir
    metadata = Parser.parse_file(buffer_file, true, true, line)
    %{imports: imports,
      aliases: aliases,
      module: module} = Metadata.get_env(metadata, line)

    [hint, context, [module|imports], aliases]
  end

  defp print(result) do
    result
    |> Enum.uniq
    |> Enum.map(&IO.puts/1)

    IO.puts "END-OF-COMP"
  end
end
