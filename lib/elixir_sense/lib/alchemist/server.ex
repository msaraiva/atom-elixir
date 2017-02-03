defmodule Alchemist.Server do

  # v0.1.0-beta

  @minimal_reload_time 2000

  @moduledoc false
  
  # The Alchemist-Server operates as an informant for a specific desired
  # Elixir Mix project and serves with informations as the following:
  #
  #   * Completion for Modules and functions.
  #   * Documentation lookup for Modules and functions.
  #   * Code evaluation and quoted representation of code.
  #   * Definition lookup of code.
  #   * Listing of all available Mix tasks.
  #   * Listing of all available Modules with documentation.

  alias Alchemist.API

  def start([[env, line]]) do
    run(line, all_loaded(), [], [], env, Path.expand("."), 0)
  end

  def start([env]) do
    IO.puts(:stderr, "Initializing ElixirSense server for environment \"#{env}\" (Elixir version #{System.version})")
    IO.puts(:stderr, "Working directory is \"#{Path.expand(".")}\"")
    loop(all_loaded(), [], [], env, Path.expand("."), 0)
  end

  def loop(loaded, paths, apps, env, cwd, last_load_time) do
    case IO.gets("") do
      :eof ->
        IO.puts(:stderr, "Stopping alchemist-server")
      str  ->
        line  = str |> String.rstrip()
        {paths, apps, env, cwd, time} = run(line, loaded, paths, apps, env, cwd, last_load_time)
        loop(loaded, paths, apps, env, cwd, time)
    end
  end

  defp run(line, loaded, paths, apps, env, cwd, last_load_time) do
    time = :erlang.system_time(:milli_seconds)
    reload = time - last_load_time > @minimal_reload_time

    {paths, apps} =
      if reload do
        purge_modules(loaded)
        purge_paths(paths)
        purge_apps(apps)
        {load_paths(env, cwd), load_apps(env, cwd)}
      else
        {paths, apps}
      end

    {env, cwd} =
      try do
        case read_input(line) do
          {:env, env_and_cwd} -> env_and_cwd
          _ -> {env, cwd}
        end
      rescue
        e ->
          IO.puts(:stderr, "Server Error: \n" <> Exception.message(e) <> "\n" <> Exception.format_stacktrace(System.stacktrace))
          {env, cwd}
      end
    {paths, apps, env, cwd, time}
  end

  def read_input(line) do
    case line |> String.split(" ", parts: 2) do
      ["COMP", args] ->
        API.Comp.request(args)
      ["DOCL", args] ->
        API.Docl.request(args)
      ["EVAL", args] ->
        API.Eval.request(args)
      ["DEFL", args] ->
        API.Defl.request(args)
      ["DEBG", _args] ->
        debug()
      ["SENV", args] ->
        {{env, cwd}, _} = Code.eval_string(args)
        set_env(env, cwd)
      _ ->
        nil
    end
  end

  defp set_env(env, cwd) when env in ["test", "dev"] do
    IO.puts "#{env},#{cwd}"
    IO.puts "END-OF-SENV"
    {:env, {env, cwd}}
  end

  defp all_loaded() do
    for {m,_} <- :code.all_loaded, do: m
  end

  defp load_paths(env, cwd) do
    for path <- Path.wildcard(Path.join(cwd, "_build/#{env}/lib/*/ebin")) do
      Code.prepend_path(path)
      path
    end
  end

  defp load_apps(env, cwd) do
    for path <- Path.wildcard(Path.join(cwd, "_build/#{env}/lib/*/ebin/*.app")) do
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

  defp debug do
    print_debug_info([], [])
    IO.puts "END-OF-DEBG"
  end

  defp print_debug_info(paths, apps) do
    output = :code.all_loaded |> Enum.map(fn {m,f} -> "#{m} (#{f})" end) |> Enum.sort |> Enum.join("\n")
    IO.puts(:stderr, "# Current working directory:")
    IO.puts(:stderr, Path.expand("."))
    IO.puts(:stderr, "# Load paths:")
    IO.inspect(:stderr, paths, [])
    IO.puts(:stderr, "# Loaded apps:")
    IO.inspect(:stderr, apps, [])
    IO.puts(:stderr, "# Loaded modules")
    IO.puts(:stderr, output)
  end
end
