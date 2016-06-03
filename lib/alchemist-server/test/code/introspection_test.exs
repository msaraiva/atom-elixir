Code.require_file "../test_helper.exs", __DIR__
Code.require_file "../../lib/code/introspection.exs", __DIR__

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
    ast = Introspection.get_callback_ast(GenServer, :code_change, 3)
    assert Introspection.format_spec_ast(ast) == """
    code_change(old_vsn, state :: term, extra :: term) ::
      {:ok, new_state :: term} |
      {:error, reason :: term} when old_vsn: term | {:down, term}
    """
  end

  test "get_returns_from_callback" do
    returns = Introspection.get_returns_from_callback(GenServer, :handle_call, 3) |> Enum.map(&Introspection.spec_ast_to_string/1)
    assert returns == [
      "{:reply, reply, new_state}",
      "{:reply, reply, new_state, timeout | :hibernate}",
      "{:noreply, new_state}",
      "{:noreply, new_state, timeout | :hibernate}",
      "{:stop, reason, reply, new_state}",
      "{:stop, reason, new_state}"
    ]
  end

  test "get_returns_from_callback (with types)" do
    returns = Introspection.get_returns_from_callback(GenServer, :code_change, 3) |> Enum.map(&Introspection.spec_ast_to_string/1)
    assert returns == [
      "{:ok, new_state :: term}",
      "{:error, reason :: term}"
    ]
  end

  test "return_to_snippet" do
    {:ok, ast} = "{:atom, type, var, type2 | {:atom2, var2}, String.t, [var3, ...], {:atom3, type3}}" |> Code.string_to_quoted
    assert Introspection.return_to_snippet(ast) ==
      ~s({:atom, "${1:type}$", "${2:var}$", "${3:type2 | {:atom2, var2}}$", "${4:String.t}$", ["${5:var3}$", "${6:...}$"], {:atom3, "${7:type3}$"}})
  end

  defp get_type_ast(module, type) do
    {_kind, type} =
      Kernel.Typespec.beam_types(module)
      |> Enum.find(fn {_, {name, _, _}} -> name == type end)
    Kernel.Typespec.type_to_ast(type)
  end

end
