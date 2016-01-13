defmodule Traverse do

  # From: https://github.com/elixir-lang/elixir/blob/bd3332c8484f791eba8c7db875cebdcd34d8112b/lib/elixir/lib/macro.ex#L175
  def traverse(ast, acc, pre, post) when is_function(pre, 2) and is_function(post, 2) do
    {ast, acc} = pre.(ast, acc)
    do_traverse(ast, acc, pre, post)
  end

  defp do_traverse({form, meta, args}, acc, pre, post) do
    unless is_atom(form) do
      {form, acc} = pre.(form, acc)
      {form, acc} = do_traverse(form, acc, pre, post)
    end

    unless is_atom(args) do
      {args, acc} = Enum.map_reduce(args, acc, fn x, acc ->
        {x, acc} = pre.(x, acc)
        do_traverse(x, acc, pre, post)
      end)
    end

    post.({form, meta, args}, acc)
  end

  defp do_traverse({left, right}, acc, pre, post) do
    {left, acc} = pre.(left, acc)
    {left, acc} = do_traverse(left, acc, pre, post)
    {right, acc} = pre.(right, acc)
    {right, acc} = do_traverse(right, acc, pre, post)
    post.({left, right}, acc)
  end

  defp do_traverse(list, acc, pre, post) when is_list(list) do
    {list, acc} = Enum.map_reduce(list, acc, fn x, acc ->
      {x, acc} = pre.(x, acc)
      do_traverse(x, acc, pre, post)
    end)
    post.(list, acc)
  end

  defp do_traverse(x, acc, _pre, post) do
    post.(x, acc)
  end

end
