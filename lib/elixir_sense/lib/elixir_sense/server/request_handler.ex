defmodule RequestHandler do

  def handle_request("signature", %{"buffer" => buffer, "line" => line, "column" => column}) do
    ElixirSense.signature(buffer, line, column)
  end

  def handle_request("suggestions", %{"prefix" => prefix, "buffer" => buffer, "line" => line}) do
    ElixirSense.suggestions(prefix, buffer, line)
  end

  def handle_request("docs", %{"buffer" => buffer, "subject" => subject, "line" => line}) do
    ElixirSense.docs(subject, buffer, line)
  end

  def handle_request("definition", %{"buffer" => buffer, "module" => module, "function" => function, "line" => line}) do
    {mod, _} = Code.eval_string(module)
    fun = function && String.to_atom(function)

    case ElixirSense.definition(mod, fun, buffer, line) do
      {"non_existing", nil} -> "non_existing"
      {file, nil}  -> "#{file}:0"
      {file, line} -> "#{file}:#{line}"
    end
  end

  def handle_request(request, paylod) do
    IO.puts :stderr, "Cannot handle request \"#{request}\". Payload: #{inspect(paylod)}"
  end

end
