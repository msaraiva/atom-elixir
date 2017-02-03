defmodule Alchemist.API.Comp do

  @moduledoc false

  @spec request(String.t) :: no_return
  def request(args) do
    {{hint, buffer_file, line}, _} =  Code.eval_string(args)
    buffer = File.read!(buffer_file)

    ElixirSense.suggestions(hint, buffer, line)
    |> Enum.map(&format_suggestion/1)
    |> Enum.each(&IO.puts/1)
    IO.puts "END-OF-COMP"
  end

  defp format_suggestion(%{type: :variable, name: name}) do
    "#{name};var"
  end
  defp format_suggestion(%{type: :attribute, name: name}) do
    "#{name};attribute"
  end
  defp format_suggestion(%{type: :hint, value: value}) do
    "#{value};hint"
  end
  defp format_suggestion(%{type: :module, name: name, subtype: subtype, summary: summary}) do
    "#{name};module;#{subtype};#{summary}"
  end
  defp format_suggestion(%{type: :callback, name: name, arity: arity, args: args, origin: mod_name, summary: desc, spec: spec}) do
    "#{name}/#{arity};callback;#{args};#{mod_name};#{desc};#{spec}"
  end
  defp format_suggestion(%{type: :return, description: description, spec: spec, snippet: snippet}) do
    "#{description};return;#{spec};#{snippet}"
  end
  defp format_suggestion(%{type: type, name: func, arity: arity, args: args, origin: mod_name, summary: summary, spec: spec}) do
    "#{func}/#{arity};#{type};#{args};#{mod_name};#{summary};#{spec}"
  end
end
