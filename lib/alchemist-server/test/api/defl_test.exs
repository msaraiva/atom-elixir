Code.require_file "../test_helper.exs", __DIR__
Code.require_file "../../lib/api/defl.exs", __DIR__

defmodule Alchemist.API.DeflTest do

  use ExUnit.Case

  alias Alchemist.API.Defl

  test "DEFL request call for defmodule" do
    context = [context: Elixir, imports: [], aliases: []]
    {mod, file} = Defl.process([nil, :defmodule, context])
    assert mod == Kernel
    assert file =~ "lib/elixir/lib/kernel.ex"
  end

  test "DEFL request call for import" do
    context = [context: Elixir, imports: [], aliases: []]
    {mod, file} = Defl.process([nil, :import, context])
    assert mod == Kernel.SpecialForms
    assert file =~ "lib/elixir/lib/kernel/special_forms.ex"
  end

  test "DEFL request call for create_file with available import" do
    context = [context: Elixir, imports: [Mix.Generator], aliases: []]
    {mod, file} = Defl.process([nil, :create_file, context])
    assert mod == Mix.Generator
    assert file =~ "lib/mix/lib/mix/generator.ex"
  end

  test "DEFL request call for MyList.flatten with available aliases" do
    context = [context: Elixir, imports: [], aliases: [{MyList, List}]]
    {mod, file} = Defl.process([MyList, :flatten, context])
    assert mod == List
    assert file =~ "lib/elixir/lib/list.ex"
  end

  test "DEFL request call for String module" do
    context = [context: Elixir, imports: [], aliases: []]
    {mod, file} = Defl.process([String, nil, context])
    assert mod == String
    assert file =~ "lib/elixir/lib/string.ex"
  end

  test "DEFL request call for erlang module" do
    context = [ context: Elixir, imports: [], aliases: [] ]
    {mod, file} = Defl.process([:lists, :duplicate, context])
    assert mod == :lists
    assert file =~ "/src/lists.erl"
  end

  test "DEFL request call for none existing module" do
    context = [ context: Elixir, imports: [], aliases: [] ]
    assert Defl.process([Rock, :duplicate, context]) == {Rock, nil}
  end

end
