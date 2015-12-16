Code.require_file "../helpers/complete.exs", __DIR__
Code.require_file "../helpers/ast.exs", __DIR__

defmodule Alchemist.API.Comp do

  @moduledoc false

  alias Alchemist.Helpers.Complete
  alias Ast.FileMetadata

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

    Complete.run(hint, imports) ++ Complete.run(hint)
    |> print
  end

  defp normalize(request) do
    {{hint, buffer_file, line, [ context: context,
              imports: _imports,
              aliases: _aliases ]}, _} =  Code.eval_string(request)

    metadata = FileMetadata.parse_file(buffer_file, true, true, line)
    %{imports: imports,
      aliases: aliases,
      module: module} = FileMetadata.get_line_context(metadata, line)

    [hint, context, [module|imports], aliases]
  end

  defp print(result) do
    result
    |> Enum.uniq
    |> Enum.map &IO.puts/1

    IO.puts "END-OF-COMP"
  end
end
