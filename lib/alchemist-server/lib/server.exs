Code.require_file "api/comp.exs", __DIR__
Code.require_file "api/docl.exs", __DIR__
Code.require_file "api/defl.exs", __DIR__
Code.require_file "api/eval.exs", __DIR__
Code.require_file "api/info.exs", __DIR__

defmodule Alchemist.Server do

  @version "0.1.0-beta"
  @minimal_reload_time 2000

  @moduledoc """
  The Alchemist-Server operates as an informant for a specific desired
  Elixir Mix project and serves with informations as the following:

    * Completion for Modules and functions.
    * Documentation lookup for Modules and functions.
    * Code evaluation and quoted representation of code.
    * Definition lookup of code.
    * Listing of all available Mix tasks.
    * Listing of all available Modules with documentation.
  """

  alias Alchemist.API

  def start([[env, line]]) do
    run(line, all_loaded(), [], [], env, 0)
  end

  def start([env]) do
    IO.puts(:stderr, "Initializing alchemist-server for environment \"#{env}\" (Elixir version #{System.version})")
    # IO.inspect(:stderr, System.get_env, [])

    loop(all_loaded(), [], [], env, 0)
  end

  def loop(loaded, paths, apps, env, last_load_time) do
    line  = IO.gets("") |> String.rstrip()
    {paths, apps, env, time} = run(line, loaded, paths, apps, env, last_load_time)
    loop(loaded, paths, apps, env, time)
  end

  defp run(line, loaded, paths, apps, env, last_load_time) do
    time = :erlang.system_time(:milli_seconds)
    reload = time - last_load_time > @minimal_reload_time

    {paths, apps} =
      if reload do
        purge_modules(loaded)
        purge_paths(paths)
        purge_apps(apps)
        {load_paths(env), load_apps(env)}
      else
        {paths, apps}
      end

    env =
      try do
        case read_input(line) do
          {:env, new_env} -> new_env
          _ -> env
        end
      rescue
        e ->
          IO.puts(:stderr, "Server Error: \n" <> Exception.message(e) <> "\n" <> Exception.format_stacktrace(System.stacktrace))
          env
      end
    {paths, apps, env, time}
  end

  def read_input(line) do
    case line |> String.split(" ", parts: 2) do
      ["COMP", args] ->
        API.Comp.request(args)
      ["DOCL", args] ->
        API.Docl.request(args)
      ["INFO", args] ->
        API.Info.request(args)
      ["EVAL", args] ->
        API.Eval.request(args)
      ["DEFL", args] ->
        API.Defl.request(args)
      ["SENV", args] ->
        {{env}, _} = Code.eval_string(args)
        set_env(env)
      _ ->
        nil
    end
  end

  defp set_env(env) when env in ["test", "dev"] do
    IO.puts env
    IO.puts "END-OF-SENV"
    {:env, env}
  end

  defp all_loaded() do
    for {m,_} <- :code.all_loaded, do: m
  end

  defp load_paths(env) do
    for path <- Path.wildcard("_build/#{env}/lib/*/ebin") do
      Code.prepend_path(path)
      path
    end
  end

  defp load_apps(env) do
    for path <- Path.wildcard("_build/#{env}/lib/*/ebin/*.app") do
      app = path |> Path.basename() |> Path.rootname() |> String.to_atom
      Application.load(app)
      app
    end
  end

  defp purge_modules(loaded) do
    for m <- (all_loaded() -- loaded) do
      :code.delete(m)
      :code.purge(m)
    end
  end

  defp purge_paths(paths) do
    for p <- paths, do: Code.delete_path(p)
  end

  defp purge_apps(apps) do
    for a <- apps, do: Application.unload(a)
  end
end
