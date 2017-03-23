defmodule ElixirSense.Server do

  def start([socket_type, port, env]) do
    IO.puts(:stderr, "Initializing ElixirSense server for environment \"#{env}\" (Elixir version #{System.version})")
    IO.puts(:stderr, "Working directory is \"#{Path.expand(".")}\"")
    ElixirSense.Server.TCPServer.start([socket_type: socket_type, port: port, env: env])
    loop()
  end

  defp loop() do
    case IO.gets("") do
      :eof ->
        IO.puts(:stderr, "Stopping ElixirSense server")
      _  ->
        loop()
    end
  end

end
