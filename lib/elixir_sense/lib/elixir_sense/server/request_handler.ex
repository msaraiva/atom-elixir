defmodule RequestHandler do

  def handle_request("signature", %{"buffer" => buffer, "textBeforeCursor" => textBeforeCursor, "line" => line}) do
    ElixirSense.signature(textBeforeCursor, buffer, line)
  end

  def handle_request("suggestions", %{"prefix" => prefix, "buffer" => buffer, "line" => line}) do
    ElixirSense.suggestions(prefix, buffer, line)
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

end
