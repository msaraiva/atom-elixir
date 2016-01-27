top_level_var = "top_level_var"

defmodule Sample do
  import List
  alias Enum, as: MyEnum

  @module_attr false

  def test do
    module_var = [1,2,[3]]
    my_inspect(module_var |> flatten |> MyEnum.count)
  end

  def my_inspect(param1) do
    IO.inspect(param1)
  end

end
