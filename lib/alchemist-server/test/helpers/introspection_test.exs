Code.require_file "../test_helper.exs", __DIR__
Code.require_file "../../lib/helpers/introspection.exs", __DIR__

defmodule Alchemist.Helpers.IntrospectionTest do

  use ExUnit.Case

  test "get_callbacks_with_docs for erlang behaviours" do
    assert Introspection.get_callbacks_with_docs(:supervisor) == [%{
      name: :init,
      arity: 1,
      callback: "@callback init(args :: term) :: {:ok, {supFlags :: sup_flags, [childSpec :: child_spec]}} | :ignore",
      signature: "init(args)",
      doc: nil
    }]
  end

  test "get_callbacks_with_docs for Elixir behaviours with no docs defined" do
    assert Introspection.get_callbacks_with_docs(Exception) == [
      %{name: :exception, arity: 1, callback: "@callback exception(term) :: t",   signature: "exception(term)", doc: nil},
      %{name: :message,   arity: 1, callback: "@callback message(t) :: String.t", signature: "message(t)",      doc: nil}
    ]
  end

  test "get_callbacks_with_docs for Elixir behaviours with docs defined" do
    info = Introspection.get_callbacks_with_docs(GenServer) |> Enum.at(0)

    assert info.name      == :code_change
    assert info.arity     == 3
    assert info.callback  == "@callback code_change(old_vsn, state :: term, extra :: term) :: {:ok, new_state :: term} | {:error, reason :: term} when old_vsn: term | {:down, term}"
    assert info.doc       =~ "Invoked to change the state of the `GenServer`"
    assert info.signature == "code_change(old_vsn, state, extra)"
  end

end
