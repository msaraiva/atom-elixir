defmodule Alchemist.API.Defl do

  @moduledoc false

  @spec request(String.t) :: no_return
  def request(args) do
    [mod, fun, _file_path, buffer_file, line] = args |> normalize
    buffer = File.read!(buffer_file)

    path =
      case ElixirSense.definition(mod, fun, buffer, line) do
        {file, nil}  -> "#{file}:0"
        {file, line} -> "#{file}:#{line}"
      end

    IO.puts path
    IO.puts "END-OF-DEFL"
  end

  defp normalize(request) do
    {{expr, file_path, buffer_file, line}, _} = Code.eval_string(request)
    [module, function] = String.split(expr, ",", parts: 2)
    {module, _}        = Code.eval_string(module)
    function           = String.to_atom(function)
    [module, function, file_path, buffer_file, line]
  end

end
