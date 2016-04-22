Code.require_file "../test_helper.exs", __DIR__
Code.require_file "../../lib/helpers/introspection.exs", __DIR__

defmodule Alchemist.Helpers.IntrospectionTest do

  use ExUnit.Case

  test "get_callbacks_with_docs for erlang behaviours" do
    assert Introspection.get_callbacks_with_docs(:supervisor) == [%{
      name: :init,
      arity: 1,
      callback: """
      @callback init(args :: term) ::
        {:ok, {supFlags :: sup_flags, [childSpec :: child_spec]}} |
        :ignore
      """,
      signature: "init(args)",
      doc: nil
    }]
  end

  test "get_callbacks_with_docs for Elixir behaviours with no docs defined" do
    assert Introspection.get_callbacks_with_docs(Exception) == [
      %{name: :exception, arity: 1, callback: "@callback exception(term) :: t\n",   signature: "exception(term)", doc: nil},
      %{name: :message,   arity: 1, callback: "@callback message(t) :: String.t\n", signature: "message(t)",      doc: nil}
    ]
  end

  test "get_callbacks_with_docs for Elixir behaviours with docs defined" do
    info = Introspection.get_callbacks_with_docs(GenServer) |> Enum.at(0)

    assert info.name      == :code_change
    assert info.arity     == 3
    assert info.callback  == """
    @callback code_change(old_vsn, state :: term, extra :: term) ::
      {:ok, new_state :: term} |
      {:error, reason :: term} when old_vsn: term | {:down, term}
    """
    assert info.doc       =~ "Invoked to change the state of the `GenServer`"
    assert info.signature == "code_change(old_vsn, state, extra)"
  end

  test "format_spec_ast with one return option does not aplit the returns" do
    type_ast = get_type_ast(GenServer, :debug)

    assert Introspection.format_spec_ast(type_ast) == """
    debug :: [:trace | :log | :statistics | {:log_to_file, Path.t}]
    """
  end

  test "format_spec_ast with more than one return option aplits the returns" do
    type_ast = get_type_ast(GenServer, :on_start)

    assert Introspection.format_spec_ast(type_ast) == """
    on_start ::
      {:ok, pid} |
      :ignore |
      {:error, {:already_started, pid} | term}
    """
  end

  test "format_spec_ast for callback" do
    ast = get_callback_ast(GenServer, :code_change, 3)
    assert Introspection.format_spec_ast(ast) == """
    code_change(old_vsn, state :: term, extra :: term) ::
      {:ok, new_state :: term} |
      {:error, reason :: term} when old_vsn: term | {:down, term}
    """
  end

  defp get_type_ast(module, type) do
    {_kind, type} =
      Kernel.Typespec.beam_types(module)
      |> Enum.find(fn {_, {name, _, _}} -> name == type end)
    Kernel.Typespec.type_to_ast(type)
  end

  defp get_callback_ast(module, callback, arity) do
    {{name, _}, [spec | _]} =
      Kernel.Typespec.beam_callbacks(module)
      |> Enum.find(fn {{f, a}, _} -> {f, a} == {callback, arity}  end)

    Kernel.Typespec.spec_to_ast(name, spec)
  end

end
