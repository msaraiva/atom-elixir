defmodule ElixirSense.Server.TCPServer do

  alias ElixirSense.Server.{RequestHandler, ContextLoader}

  @connection_handler_supervisor ElixirSense.Server.TCPServer.ConnectionHandlerSupervisor
  @default_listen_options [:binary, active: false, reuseaddr: true, packet: 4]

  def start([socket_type: socket_type, port: port, env: env]) do
    import Supervisor.Spec

    children = [
      worker(Task, [__MODULE__, :listen, [socket_type, "localhost", port]]),
      supervisor(Task.Supervisor, [[name: @connection_handler_supervisor]]),
      worker(ContextLoader, [env])
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.start_link(children, opts)
  end

  def listen(socket_type, host, port) do
    {port_or_file, opts} = listen_options(socket_type, port)
    {:ok, socket} = :gen_tcp.listen(port_or_file, opts)
    {:ok, port_or_file} = :inet.port(socket)
    IO.puts "ok:#{host}:#{port_or_file}"
    accept(socket)
  end

  defp listen_options("tcpip", port) do
    {String.to_integer(port), @default_listen_options ++ [ip: {127,0,0,1}]}
  end

  defp listen_options("unix", _port) do
    {0, @default_listen_options ++ [ifaddr: {:local, socket_file()}]}
  end

  defp accept(socket) do
    {:ok, client_socket} = :gen_tcp.accept(socket)
    {:ok, pid} = start_connection_handler(client_socket)
    :ok = :gen_tcp.controlling_process(client_socket, pid)
    accept(socket)
  end

  defp start_connection_handler(client_socket) do
    Task.Supervisor.start_child(@connection_handler_supervisor, fn ->
      connection_handler(client_socket)
    end)
  end

  defp connection_handler(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:error, :closed} ->
        IO.puts :stderr, "Client socket is closed"
      {:ok, data} ->
        data
        |> process_request()
        |> send_response(socket)
        connection_handler(socket)
    end
  end

  defp process_request(data) do
    try do
      %{ "request_id" => request_id, "request" => request, "payload" => payload } = :erlang.binary_to_term(data)
      :erlang.term_to_binary(%{
        request_id: request_id,
        payload: dispatch_request(request, payload),
        error: nil
      })
    rescue
      e ->
        IO.puts(:stderr, "Server Error: \n" <> Exception.message(e) <> "\n" <> Exception.format_stacktrace(System.stacktrace))
        :erlang.term_to_binary(%{request_id: nil, payload: nil, error: Exception.message(e)})
    end
  end

  defp dispatch_request(type, payload) do
    ContextLoader.reload
    RequestHandler.handle_request(type, payload)
  end

  defp send_response(data, socket) do
    :gen_tcp.send(socket, data)
  end

  defp socket_file do
    sock_id = :erlang.system_time()
    String.to_charlist("/tmp/elixir-sense-#{sock_id}.sock")
  end

end
