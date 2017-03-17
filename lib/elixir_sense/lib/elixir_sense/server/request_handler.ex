defmodule RequestHandler do

  def handle_request("signature", %{"buffer" => buffer, "line" => line, "column" => column}) do
    ElixirSense.signature(buffer, line, column)
  end

  def handle_request("docs", %{"buffer" => buffer, "line" => line, "column" => column}) do
    ElixirSense.docs(buffer, line, column)
  end

  def handle_request("definition", %{"buffer" => buffer, "line" => line, "column" => column}) do
    case ElixirSense.definition(buffer, line, column) do
      {"non_existing", nil} -> "non_existing"
      {file, nil}  -> "#{file}:0"
      {file, line} -> "#{file}:#{line}"
    end
  end

  def handle_request("suggestions", %{"buffer" => buffer, "prefix" => prefix, "line" => line}) do
    ElixirSense.suggestions(prefix, buffer, line)
  end

  def handle_request("expand_full", %{"buffer" => buffer, "selected_code" => selected_code, "line" => line}) do
    ElixirSense.expand_full(buffer, selected_code, line)
  end

  def handle_request("quote", %{"code" => code}) do
    ElixirSense.quote(code)
  end

  def handle_request("match", %{"code" => code}) do
    ElixirSense.match(code)
  end

  def handle_request("set_context", %{"env" => env, "cwd" => cwd}) do
    ContextLoader.set_context(env, cwd) |> Tuple.to_list
  end

  def handle_request(request, paylod) do
    IO.puts :stderr, "Cannot handle request \"#{request}\". Payload: #{inspect(paylod)}"
  end

end
