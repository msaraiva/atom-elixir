defmodule ElixirSense.Server do

  def start([env]) do
    IO.puts(:stderr, "Initializing ElixirSense server for environment \"#{env}\" (Elixir version #{System.version})")
    IO.puts(:stderr, "Working directory is \"#{Path.expand(".")}\"")
    start_supervisor(host: "localhost", port: 0, env: "dev")
    ContextLoader.set_context(env, Path.expand("."))
    loop()
  end

  defp start_supervisor(host: host, port: port, env: env) do
    import Supervisor.Spec

    children = [
      supervisor(ElixirSense.Server.TCPServer, [[host: host, port: port]]),
      worker(ContextLoader, [env])
    ]

    opts = [strategy: :one_for_one, name: ElixirSense.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp loop() do
    case IO.gets("") do
      :eof ->
        IO.puts(:stderr, "Stopping alchemist-server")
      _  ->
        loop()
    end
  end

end
