defmodule RequestHandler do

  def handle_request("signature", %{"buffer" => buffer, "textBeforeCursor" => textBeforeCursor, "line" => line}) do
    ElixirSense.signature(textBeforeCursor, buffer, line)
  end

  def handle_request("suggestions", %{"prefix" => prefix, "buffer" => buffer, "line" => line}) do
    ElixirSense.suggestions(prefix, buffer, line)
  end

end
