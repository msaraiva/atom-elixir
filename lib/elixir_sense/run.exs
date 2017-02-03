requires = [
  "elixir_sense/core/introspection.ex",
  "elixir_sense/core/ast.ex",
  "elixir_sense/core/state.ex",
  "elixir_sense/core/metadata_builder.ex",
  "elixir_sense/core/metadata.ex",
  "elixir_sense/core/parser.ex",
  "elixir_sense/core/source.ex",
  "alchemist/helpers/module_info.ex",
  "alchemist/helpers/complete.ex",
  "elixir_sense/providers/definition.ex",
  "elixir_sense/providers/docs.ex",
  "elixir_sense/providers/suggestion.ex",
  "elixir_sense/providers/signature.ex",
  "elixir_sense/providers/expand.ex",
  "elixir_sense.ex",
  "alchemist/api/comp.ex",
  "alchemist/api/defl.ex",
  "alchemist/api/docl.ex",
  "alchemist/api/eval.ex",
  "alchemist/server.ex"
]

requires |> Enum.each(fn file ->
  Code.require_file("lib/#{file}", __DIR__)
end)

Alchemist.Server.start([System.argv])
