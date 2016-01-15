Code.require_file "../test_helper.exs", __DIR__
Code.require_file "../../lib/code/metadata_builder.exs", __DIR__

defmodule Alchemist.Code.MetadataBuilderTest do

  use ExUnit.Case

  alias Alchemist.Code.MetadataBuilder

  test "build metadata from kernel.ex" do
    assert get_subject_definition_line(Kernel, :defmodule, nil) =~ "defmacro defmodule(alias, do: block) do"
  end

  test "build metadata from kernel/special_forms.ex" do
    assert get_subject_definition_line(Kernel.SpecialForms, :alias, nil) =~ "defmacro alias(module, opts)"
  end

  test "vars defined inside a function without params" do
    {_ast, acc} = """
      defmodule MyModule do
        var_out1 = 1
        def func do
          var_in1 = 1
          var_in2 = 1
          IO.puts ""
        end
        var_out2 = 1
      end
      """
      |> Code.string_to_quoted
      |> MetadataBuilder.build

    vars = acc |> get_line_vars(6)
    assert vars == [:var_in1, :var_in2]
  end

  test "vars defined inside a function with params" do

    {_ast, acc} = """
      defmodule MyModule do
        var_out1 = 1
        def func(%{key1: par1, key2: [par2|[par3, _]]}, par4) do
          var_in1 = 1
          var_in2 = 1
          IO.puts ""
        end
        var_out2 = 1
      end
      """
      |> Code.string_to_quoted
      |> MetadataBuilder.build

    vars = acc |> get_line_vars(6)
    assert vars == [:par1, :par2, :par3, :par4, :var_in1, :var_in2]
  end

  test "vars defined inside a module" do

    {_ast, acc} =
      """
      defmodule MyModule do
        var_out1 = 1
        def func do
          var_in = 1
        end
        var_out2 = 1
        IO.puts ""
      end
      """
      |> Code.string_to_quoted
      |> MetadataBuilder.build

    vars = acc |> get_line_vars(7)
    assert vars == [:var_out1, :var_out2]
  end

  test "vars defined in a `for` comprehension" do

    {_ast, acc} =
      """
      defmodule MyModule do
        var_out1 = 1
        IO.puts ""
        for var_on <- [1,2], var_on != 2 do
          var_in = 1
          IO.puts ""
        end
        var_out2 = 1
        IO.puts ""
      end
      """
      |> Code.string_to_quoted
      |> MetadataBuilder.build

    assert get_line_vars(acc, 3) == [:var_out1]
    assert get_line_vars(acc, 6) == [:var_in, :var_on, :var_out1]
    assert get_line_vars(acc, 9) == [:var_out1, :var_out2]
  end

  test "vars defined in a `if/else` statement" do

    {_ast, acc} =
      """
      defmodule MyModule do
        var_out1 = 1
        if var_on = true do
          var_in_if = 1
          IO.puts ""
        else
          var_in_else = 1
          IO.puts ""
        end
        var_out2 = 1
        IO.puts ""
      end
      """
      |> Code.string_to_quoted
      |> MetadataBuilder.build

    assert get_line_vars(acc, 5) == [:var_in_if, :var_on, :var_out1]
    assert get_line_vars(acc, 11) == [:var_in_else, :var_in_if, :var_on, :var_out1, :var_out2]
    # This assert fails
    # assert get_line_vars(acc, 8) == [:var_in_else, :var_on, :var_out1]
  end

  test "vars defined inside a `fn`" do

    {_ast, acc} =
      """
      defmodule MyModule do
        var_out1 = 1
        fn var_on ->
          var_in = 1
          IO.puts ""
        end
        var_out2 = 1
        IO.puts ""
      end
      """
      |> Code.string_to_quoted
      |> MetadataBuilder.build

    assert get_line_vars(acc, 5) == [:var_in, :var_on, :var_out1]
    assert get_line_vars(acc, 8) == [:var_out1, :var_out2]
  end

  test "vars defined inside a `case`" do

    {_ast, acc} =
      """
      defmodule MyModule do
        var_out1 = 1
        case var_out1 do
          {var_on} ->
            var_in = 1
            IO.puts ""
        end
        var_out2 = 1
        IO.puts ""
      end
      """
      |> Code.string_to_quoted
      |> MetadataBuilder.build

    assert get_line_vars(acc, 6) == [:var_in, :var_on, :var_out1]
    # This assert fails
    # assert get_line_vars(acc, 9) == [:var_in, :var_out1, :var_out2]
  end

  test "vars defined inside a `cond`" do

    {_ast, acc} =
      """
      defmodule MyModule do
        var_out1 = 1
        cond do
          1 == 1 ->
            var_in = 1
            IO.puts ""
        end
        var_out2 = 1
        IO.puts ""
      end
      """
      |> Code.string_to_quoted
      |> MetadataBuilder.build

    assert get_line_vars(acc, 6) == [:var_in, :var_out1]
    assert get_line_vars(acc, 9) == [:var_in, :var_out1, :var_out2]
  end

  test "a variable should only be added once to the vars list" do

    {_ast, acc} =
      """
      defmodule MyModule do
        var = 1
        var = 2
        IO.puts ""
      end
      """
      |> Code.string_to_quoted
      |> MetadataBuilder.build

    assert get_line_vars(acc, 4) == [:var]
  end

  # test "functions of arity 0 should not be in the vars list" do
  #
  #   {_ast, acc} =
  #     """
  #     defmodule MyModule do
  #       myself = self
  #       mynode = node()
  #       IO.puts ""
  #     end
  #     """
  #     |> Code.string_to_quoted
  #     |> MetadataBuilder.build
  #
  #   assert get_line_vars(acc, 3) == [:mynode, :myself]
  # end

  test "aliases" do

    {_ast, acc} =
      """
      defmodule OuterModule do
        alias List, as: MyList
        IO.puts ""
        defmodule InnerModule do
          alias Enum, as: MyEnum
          IO.puts ""
          def func do
            alias String, as: MyString
            IO.puts ""
            if true do
              alias Macro, as: MyMacro
              IO.puts ""
            end
            IO.puts ""
          end
          IO.puts ""
        end
        alias Code, as: MyCode
        IO.puts ""
      end
      """
      |> Code.string_to_quoted
      |> MetadataBuilder.build

    assert get_line_aliases(acc, 3)  == [{MyList, List}]
    #TODO: should we keep the same order? [{MyList, List}, {InnerModule, OuterModule.InnerModule}, {MyEnum, Enum}]
    assert get_line_aliases(acc, 6)  == [{InnerModule, OuterModule.InnerModule}, {MyList, List}, {MyEnum, Enum}]
    assert get_line_aliases(acc, 9)  == [{InnerModule, OuterModule.InnerModule}, {MyList, List}, {MyEnum, Enum}, {MyString, String}]
    assert get_line_aliases(acc, 12) == [{InnerModule, OuterModule.InnerModule}, {MyList, List}, {MyEnum, Enum}, {MyMacro, Macro}, {MyString, String}]
    # assert get_line_aliases(acc, 14) == [{InnerModule, OuterModule.InnerModule}, {MyList, List}, {MyEnum, Enum}, {MyString, String}]
    assert get_line_aliases(acc, 16) == [{InnerModule, OuterModule.InnerModule}, {MyList, List}, {MyEnum, Enum}]
    assert get_line_aliases(acc, 19) == [{MyCode, Code}, {InnerModule, OuterModule.InnerModule}, {MyList, List}]
  end

  test "imports" do

    {_ast, acc} =
      """
      defmodule OuterModule do
        import List
        IO.puts ""
        defmodule InnerModule do
          import Enum
          IO.puts ""
          def func do
            import String
            IO.puts ""
            if true do
              import Macro
              IO.puts ""
            end
            IO.puts ""
          end
          IO.puts ""
        end
        import Code
        IO.puts ""
      end
      """
      |> Code.string_to_quoted
      |> MetadataBuilder.build

    assert get_line_imports(acc, 3)  == [List]
    assert get_line_imports(acc, 6)  == [List, Enum]
    assert get_line_imports(acc, 9)  == [List, Enum, String]
    assert get_line_imports(acc, 12) == [List, Enum, Macro, String]
    # assert get_line_imports(acc, 14)  == [List, Enum, String]
    assert get_line_imports(acc, 16)  == [List, Enum]
    assert get_line_imports(acc, 19)  == [Code, List]
  end

  defp get_line_vars(acc, line) do
    (get_in(acc.lines_to_env, [line, :vars]) || []) |> Enum.sort
  end

  defp get_line_aliases(acc, line) do
    (get_in(acc.lines_to_env, [line, :aliases]) || [])
  end

  defp get_line_imports(acc, line) do
    (get_in(acc.lines_to_env, [line, :imports]) || [])
  end

  defp get_subject_definition_line(module, func, arity) do
    file = module.module_info(:compile)[:source]
    {_ast, acc} =
      File.read!(file)
      |> Code.string_to_quoted
      |> MetadataBuilder.build

    line_number = Map.get(acc.mods_funs_to_lines, {module, func, arity})

    File.read!(file) |> String.split("\n") |> Enum.at(line_number-1)
  end

end
