defmodule ElixirSense.Core.Metadata do

  alias ElixirSense.Core.State

  defstruct source: nil,
            mods_funs_to_lines: %{},
            lines_to_env: %{},
            error: nil

  def get_env(%__MODULE__{} = metadata, line_number) do
    case Map.get(metadata.lines_to_env, line_number) do
      nil -> %State.Env{}
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
