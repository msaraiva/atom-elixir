defmodule MyModule do

  var_in_module1 = 1
  IO.inspect(var_in_module1)

  def func_with_no_params do
    var1 = 1
    [var2|_] = [2,1]
    %{key: var3} = %{key: 3}
    IO.inspect({var1, var2, var3})
  end

  def func_with_params(par1, par2) do
    var1 = 1
    IO.inspect({par1, par2, var1})
  end

  def func_with_more_complex_params(%{key1: par1, key2: [par2|[par3, _]]}, par4, par5) do
    var1 = 1
    IO.inspect({par1, par2, par3, par4, par5, var1})
  end

  var_in_module2 = 1
  IO.inspect(var_in_module1)
  IO.inspect({var_in_module1, var_in_module2})

end
