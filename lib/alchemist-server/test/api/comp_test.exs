Code.require_file "../test_helper.exs", __DIR__
Code.require_file "../../lib/api/comp.exs", __DIR__

defmodule Alchemist.API.CompTest do

  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  alias Alchemist.API.Comp

  test "COMP request with empty hint" do
    assert capture_io(fn ->
      Comp.process([nil, Elixir, [], [], [], []])
    end) =~ """

    import/2;macro;module,opts;Kernel.SpecialForms;Imports functions and macros from other modules.;
    quote/2;macro;opts,block;Kernel.SpecialForms;Gets the representation of any expression.;
    require/2;macro;module,opts;Kernel.SpecialForms;Requires a given module to be compiled and loaded.;
    END-OF-COMP
    """
  end

  test "COMP request without empty hint" do
    assert capture_io(fn ->
      Comp.process(['is_b', Elixir, [], [], [], []])
    end) =~ """
    is_b;hint
    is_binary/1;function;term;Kernel;Returns `true` if `term` is a binary\\; otherwise returns `false`.;@spec is_binary(term) :: boolean
    is_bitstring/1;function;term;Kernel;Returns `true` if `term` is a bitstring (including a binary)\\; otherwise returns `false`.;@spec is_bitstring(term) :: boolean
    is_boolean/1;function;term;Kernel;Returns `true` if `term` is either the atom `true` or the atom `false` (i.e.,\\na boolean)\\; otherwise returns `false`.;@spec is_boolean(term) :: boolean
    END-OF-COMP
    """
  end

  test "COMP request with an alias" do
    assert capture_io(fn ->
      Comp.process(['MyList.flat', Elixir, [], [{MyList, List}], [], []])
    end) =~ """
    MyList.flatten;hint
    flatten/2;function;list,tail;List;Flattens the given `list` of nested lists.\\nThe list `tail` will be added at the end of\\nthe flattened list.;@spec flatten(deep_list, [elem]) :: [elem] when deep_list: [elem | deep_list], elem: var
    flatten/1;function;list;List;Flattens the given `list` of nested lists.;@spec flatten(deep_list) :: list when deep_list: [any | deep_list]
    END-OF-COMP
    """
  end

  test "COMP request with a module hint" do
    assert capture_io(fn ->
      Comp.process(['Str', Elixir, [], [], [], []])
    end) =~ """
    Str;hint
    Stream;module;struct;Module for creating and composing streams.
    String;module;;A String in Elixir is a UTF-8 encoded binary.
    StringIO;module;;This module provides an IO device that wraps a string.
    END-OF-COMP
    """
  end

end
