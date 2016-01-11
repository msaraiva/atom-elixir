defmodule Alchemist.Code.Metadata do

  defstruct [:source, :mods_funs_to_lines, :lines_to_context, :error]

  def get_env(%__MODULE__{lines_to_context: nil}, _line_number) do
    %{imports: [], aliases: [], module: nil}
  end

  def get_env(%__MODULE__{} = metadata, line_number) do
    case Map.get(metadata.lines_to_context, line_number) do
      nil -> %{imports: [], aliases: [], module: nil}
      ctx -> ctx
    end
  end

  def get_function_line(%__MODULE__{} = metadata, module, function) do
    case Map.get(metadata.mods_funs_to_lines, {module, function, nil}) do
      nil -> get_function_line_using_docs(module, function)
      line -> line
    end
  end

  defp get_function_line_using_docs(module, function) do
    docs = Code.get_docs(module, :docs)

    for {{func, _arity}, line, _kind, _, _} <- docs, func == function do
      line
    end |> Enum.at(0)
  end

end
