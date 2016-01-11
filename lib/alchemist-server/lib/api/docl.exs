Code.require_file "../helpers/module_info.exs", __DIR__
Code.require_file "../helpers/introspection.exs", __DIR__
Code.require_file "../code/metadata.exs", __DIR__
Code.require_file "../code/parser.exs", __DIR__

defmodule Alchemist.API.Docl do

  @moduledoc false

  import IEx.Helpers, warn: false

  alias Alchemist.Helpers.ModuleInfo
  alias Alchemist.Code.Metadata
  alias Alchemist.Code.Parser

  def request(args) do
    Application.put_env(:iex, :colors, [enabled: true])

    args
    |> normalize
    |> process

    IO.puts "END-OF-DOCL"
  end

  def process([expr, modules, aliases]) do
    search(expr, modules, aliases)
  end

  def search(nil), do: true
  def search(expr) do
    try do
      {module, function} = Introspection.split_mod_func_call(expr)
      Introspection.get_docs_md(module, function)
      |> IO.puts
    rescue
      e -> IO.inspect :stderr, e, []
    end
  end

  def search(expr, modules, []) do
    expr = to_string expr
    unless function?(expr) do
      search(expr)
    else
      search_with_context(modules, expr)
    end
  end

  def search(expr, modules, aliases) do
    unless function?(expr) do
      String.split(expr, ".")
      |> ModuleInfo.expand_alias(aliases)
      |> search
    else
      search_with_context(modules, expr)
    end
  end

  defp search_with_context(modules, expr) do
    modules ++ [Kernel, Kernel.SpecialForms]
    |> build_search(expr)
    |> search
  end

  defp build_search(modules, search) do
    function = Regex.replace(~r/\/[0-9]$/, search, "")
    function = String.to_atom(function)
    for module <- modules,
    ModuleInfo.docs?(module, function) do
      "#{module}.#{search}"
    end |> List.first
  end

  defp function?(expr) do
    Regex.match?(~r/^[a-z_]/, expr)
  end

  defp normalize(request) do
    {{expr, buffer_file, line}, _} = Code.eval_string(request)

    metadata = Parser.parse_file(buffer_file, true, true, line)
    %{imports: imports,
      aliases: aliases,
      module: _module} = Metadata.get_env(metadata, line)

    [expr, imports, aliases]
  end

end
