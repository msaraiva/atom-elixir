defmodule ElixirSense.Server.TCPServer do

  @tcp_server_supervisor ElixirSense.Server.TCPServer.Supervisor
  @request_handler_supervisor ElixirSense.Server.TCPServer.RequestHandlerSupervisor

  def start([host: host, port: port]) do
    import Supervisor.Spec

    children = [
      supervisor(Task.Supervisor, [[name: @request_handler_supervisor]]),
      worker(Task, [__MODULE__, :listen, [host, port]])
    ]

    opts = [strategy: :one_for_one, name: @tcp_server_supervisor]
    Supervisor.start_link(children, opts)
  end

  def listen(host, port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(socket)
    IO.puts "ok|#{host}:#{port}"
    accept_loop(socket)
  end

  defp accept_loop(socket) do
    {:ok, client_socket} = :gen_tcp.accept(socket)
    {:ok, pid} = start_request_handler(client_socket)
    :ok = :gen_tcp.controlling_process(client_socket, pid)
    accept_loop(socket)
  end

  defp start_request_handler(client_socket) do
    Task.Supervisor.start_child(@request_handler_supervisor, fn ->
      request_handler(client_socket)
    end)
  end

  defp request_handler(socket, rest \\ <<>>) do
    case :gen_tcp.recv(socket, 0) do
      {:error, :closed} ->
        IO.puts :stderr, "Client socket is closed"
      {:ok, data} ->
        request_handler(socket, match_packet(rest <> data, socket))
    end
  end

  defp match_packet(data, socket) do
    case data do
      <<101, length :: size(32), body :: binary-size(length), rest :: bitstring>> ->
        body
        |> process_request()
        |> send_response(socket)
        match_packet(rest, socket)
      rest ->
        rest
    end
  end

  def process_request(data) do
    %{ "request" => request, "payload" => payload } = :erlang.binary_to_term(data)
    request
    |> dispatch_request(payload)
    |> :erlang.term_to_binary
  end

  defp dispatch_request("signature", %{"buffer" => buffer, "textBeforeCursor" => textBeforeCursor, "line" => line}) do
    ElixirSense.signature(textBeforeCursor, buffer, line)
  end

  defp dispatch_request("suggestions", %{"prefix" => prefix, "buffer" => buffer, "line" => line}) do
    ElixirSense.suggestions(prefix, buffer, line)
  end

  defp send_response(data, socket) do
    :gen_tcp.send(socket, data)
  end

end
