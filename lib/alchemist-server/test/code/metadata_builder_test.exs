Code.require_file "../test_helper.exs", __DIR__
Code.require_file "../../lib/code/metadata_builder.exs", __DIR__

defmodule Alchemist.Code.MetadataBuilderTest do

  use ExUnit.Case

  alias Alchemist.Code.MetadataBuilder

  setup_all do
    {_ast, acc} =
      File.read!("#{__DIR__}/my_module.ex")
      |> Code.string_to_quoted
      |> MetadataBuilder.build
    {:ok, acc: acc}
  end

  defp get_line_vars(acc, line) do
    get_in(acc.lines_to_context, [line, :vars]) |> Enum.sort
  end

  test "vars defined inside a function without params", %{acc: acc} do
    vars = acc |> get_line_vars(10)
    assert vars == [:var1, :var2, :var3]
  end

  test "vars defined inside a function with params", %{acc: acc} do
    vars = acc |> get_line_vars(15)
    assert vars == [:par1, :par2, :var1]
  end

  test "vars defined inside a function with more complex params", %{acc: acc} do
    vars = acc |> get_line_vars(20)
    assert vars == [:par1, :par2, :par3, :par4, :par5, :var1]
  end

  test "vars defined in a function definition", %{acc: acc} do
    vars = acc |> get_line_vars(13)
    assert vars == []
  end

  test "vars defined inside a module", %{acc: acc} do
    vars = acc |> get_line_vars(25)
    assert vars == [:var_in_module1, :var_in_module2]
  end

end
