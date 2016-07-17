defmodule Alchemist.API.Docl do

  @moduledoc false

  @spec request(String.t) :: no_return
  def request(args) do
    Application.put_env(:iex, :colors, [enabled: true])

    {{expr, buffer_file, line}, _} = Code.eval_string(args)
    buffer = File.read!(buffer_file)

    ElixirSense.docs(expr, buffer, line)
    |> format_docs
    |> IO.puts

    IO.puts "END-OF-DOCL"
  end

  # Docs for modules
  defp format_docs(%{docs: docs, types: types, callbacks: callbacks}) do
    docs <> "\u000B" <> types <> "\u000B" <> callbacks
  end

  # Docs for functions
  defp format_docs(%{docs: docs, types: types}) do
    docs <> "\u000B" <> types
  end

end
