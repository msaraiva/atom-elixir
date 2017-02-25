defmodule ElixirSense.Server do

  def start([env]) do
    IO.puts(:stderr, "Initializing ElixirSense server for environment \"#{env}\" (Elixir version #{System.version})")
    IO.puts(:stderr, "Working directory is \"#{Path.expand(".")}\"")
    ElixirSense.start(host: "localhost", port: 0, env: "dev")
    ContextLoader.set_context(env, Path.expand("."))
    loop()
  end

  def loop() do
    case IO.gets("") do
      :eof ->
        IO.puts(:stderr, "Stopping alchemist-server")
      _  ->
        loop()
    end
  end

end
