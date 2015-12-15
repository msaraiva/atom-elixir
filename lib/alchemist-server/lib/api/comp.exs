Code.require_file "../helpers/complete.exs", __DIR__

defmodule Alchemist.API.Comp do

  @moduledoc false

  alias Alchemist.Helpers.Complete

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

    buffer_string = File.read!(buffer_file)
    buffer_file_metadata = case Ast.parse_string(buffer_string, true) do
      {:ok, {_ast, buffer_file_metadata}} ->
        buffer_file_metadata
      {:error, reason} ->
        IO.inspect :stderr, reason, []
        nil
    end

    %{imports: imports, aliases: aliases, module: module} =
      case Ast.get_context_by_line(buffer_file_metadata, line) do
        :line_not_found ->
          Ast.get_context_from_line_not_found(buffer_string, line)
        ctx -> ctx
      end

    [hint, context, [module|imports], aliases]
  end

  defp print(result) do
    result
    |> Enum.uniq
    |> Enum.map &IO.puts/1

    IO.puts "END-OF-COMP"
  end
end
