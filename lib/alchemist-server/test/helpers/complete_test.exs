Code.require_file "../test_helper.exs", __DIR__
Code.require_file "../../lib/helpers/complete.exs", __DIR__

defmodule CompleteTest do
  use ExUnit.Case, async: true

  import Alchemist.Helpers.Complete

  defmodule MyModule do
    def say_hi, do: true
  end

  test "return completion candidates for 'List'" do
    assert run('List') == [
      'List.;hint', 'List;module;;Specialized functions that only work on lists.',
      'Chars;module;protocol;The List.Chars protocol is responsible for\\nconverting a structure to a list (only if applicable).\\nThe only function required to be implemented is\\n`to_char_list` which does the conversion.',
      '__info__/1;function;;List;;', 'first/1;function;list;List;Returns the first element in `list` or `nil` if `list` is empty.;@spec first([elem]) :: nil | elem when elem: var',
      'last/1;function;list;List;Returns the last element in `list` or `nil` if `list` is empty.;@spec last([elem]) :: nil | elem when elem: var',
      'to_atom/1;function;char_list;List;Converts a char list to an atom.;@spec to_atom(char_list) :: atom',
      'to_existing_atom/1;function;char_list;List;Converts a char list to an existing atom. Raises an `ArgumentError`\\nif the atom does not exist.;@spec to_existing_atom(char_list) :: atom',
      'to_float/1;function;char_list;List;Returns the float whose text representation is `char_list`.;@spec to_float(char_list) :: float',
      'to_string/1;function;list;List;Converts a list of integers representing codepoints, lists or\\nstrings into a string.;@spec to_string(:unicode.charlist) :: String.t',
      'to_tuple/1;function;list;List;Converts a list to a tuple.;@spec to_tuple(list) :: tuple',
      'wrap/1;function;list;List;Wraps the argument in a list.\\nIf the argument is already a list, returns the list.\\nIf the argument is `nil`, returns an empty list.;@spec wrap(list | any) :: list',
      'zip/1;function;list_of_lists;List;Zips corresponding elements from each list in `list_of_lists`.;@spec zip([list]) :: [tuple]', 'module_info/1;function;;List;;', 'module_info/0;function;;List;;',
      'delete/2;function;list,item;List;Deletes the given item from the list. Returns a list without\\nthe item. If the item occurs more than once in the list, just\\nthe first occurrence is removed.;@spec delete(list, any) :: list',
      'delete_at/2;function;list,index;List;Produces a new list by removing the value at the specified `index`.\\nNegative indices indicate an offset from the end of the list.\\nIf `index` is out of bounds, the original `list` is returned.;@spec delete_at(list, integer) :: list',
      'duplicate/2;function;elem,n;List;Duplicates the given element `n` times in a list.;@spec duplicate(elem, non_neg_integer) :: [elem] when elem: var',
      'keysort/2;function;list,position;List;Receives a list of tuples and sorts the items\\nat `position` of the tuples. The sort is stable.;@spec keysort([tuple], non_neg_integer) :: [tuple]',
      'flatten/2;function;list,tail;List;Flattens the given `list` of nested lists.\\nThe list `tail` will be added at the end of\\nthe flattened list.;@spec flatten(deep_list, [elem]) :: [elem] when deep_list: [elem | deep_list], elem: var',
      'flatten/1;function;list;List;Flattens the given `list` of nested lists.;@spec flatten(deep_list) :: list when deep_list: [any | deep_list]',
      'to_integer/2;function;char_list,base;List;Returns an integer whose text representation is `char_list` in base `base`.;@spec to_integer(char_list, 2..36) :: integer',
      'to_integer/1;function;char_list;List;Returns an integer whose text representation is `char_list`.;@spec to_integer(char_list) :: integer',
      'foldl/3;function;list,acc,function;List;Folds (reduces) the given list from the left with\\na function. Requires an accumulator.;@spec foldl([elem], acc, (elem, acc -> acc)) :: acc when elem: var, acc: var',
      'foldr/3;function;list,acc,function;List;Folds (reduces) the given list from the right with\\na function. Requires an accumulator.;@spec foldr([elem], acc, (elem, acc -> acc)) :: acc when elem: var, acc: var',
      'insert_at/3;function;list,index,value;List;Returns a list with `value` inserted at the specified `index`.\\nNote that `index` is capped at the list length. Negative indices\\nindicate an offset from the end of the list.;@spec insert_at(list, integer, any) :: list',
      'keydelete/3;function;list,key,position;List;Receives a list of tuples and deletes the first tuple\\nwhere the item at `position` matches the\\ngiven `key`. Returns the new list.;@spec keydelete([tuple], any, non_neg_integer) :: [tuple]',
      'keymember?/3;function;list,key,position;List;Receives a list of tuples and returns `true` if there is\\na tuple where the item at `position` in the tuple matches\\nthe given `key`.;@spec keymember?([tuple], any, non_neg_integer) :: any',
      'keytake/3;function;list,key,position;List;Receives a `list` of tuples and returns the first tuple\\nwhere the element at `position` in the tuple matches the\\ngiven `key`, as well as the `list` without found tuple.;@spec keytake([tuple], any, non_neg_integer) :: {tuple, [tuple]} | nil',
      'replace_at/3;function;list,index,value;List;Returns a list with a replaced value at the specified `index`.\\nNegative indices indicate an offset from the end of the list.\\nIf `index` is out of bounds, the original `list` is returned.;@spec replace_at(list, integer, any) :: list',
      'update_at/3;function;list,index,fun;List;Returns a list with an updated value at the specified `index`.\\nNegative indices indicate an offset from the end of the list.\\nIf `index` is out of bounds, the original `list` is returned.;@spec update_at([elem], integer, (elem -> any)) :: list when elem: var',
      'keyfind/4;function;list,key,position,default \\\\ nil;List;Receives a list of tuples and returns the first tuple\\nwhere the item at `position` in the tuple matches the\\ngiven `key`.;@spec keyfind([tuple], any, non_neg_integer, any) :: any',
      'keyreplace/4;function;list,key,position,new_tuple;List;Receives a list of tuples and replaces the item\\nidentified by `key` at `position` if it exists.;@spec keyreplace([tuple], any, non_neg_integer, tuple) :: [tuple]',
      'keystore/4;function;list,key,position,new_tuple;List;Receives a list of tuples and replaces the item\\nidentified by `key` at `position`. If the item\\ndoes not exist, it is added to the end of the list.;@spec keystore([tuple], any, non_neg_integer, tuple) :: [tuple, ...]'
    ]
  end

  test "return completion candidates for 'Str'" do
    assert run('Str') == [
      'Str;hint',
      'Stream;module;struct;Module for creating and composing streams.',
      'String;module;;A String in Elixir is a UTF-8 encoded binary.',
      'StringIO;module;;This module provides an IO device that wraps a string.'
    ]
  end

  test "return completion candidates for 'List.del'" do
    assert run('List.del') == [
      'List.delete;hint',
      'delete/2;function;list,item;List;Deletes the given item from the list. Returns a list without\\nthe item. If the item occurs more than once in the list, just\\nthe first occurrence is removed.;@spec delete(list, any) :: list',
      'delete_at/2;function;list,index;List;Produces a new list by removing the value at the specified `index`.\\nNegative indices indicate an offset from the end of the list.\\nIf `index` is out of bounds, the original `list` is returned.;@spec delete_at(list, integer) :: list'
    ]
  end

  test "return completion candidates for module with alias" do
    Application.put_env(:"alchemist.el", :aliases, [{MyList, List}])

    assert run('MyList.del') == [
      'MyList.delete;hint',
      'delete/2;function;list,item;List;Deletes the given item from the list. Returns a list without\\nthe item. If the item occurs more than once in the list, just\\nthe first occurrence is removed.;@spec delete(list, any) :: list',
      'delete_at/2;function;list,index;List;Produces a new list by removing the value at the specified `index`.\\nNegative indices indicate an offset from the end of the list.\\nIf `index` is out of bounds, the original `list` is returned.;@spec delete_at(list, integer) :: list'
    ]
  end

  test "return completion candidates for functions from import" do
    imports = [MyModule]
    assert run('say', imports) == ["say_hi/0;private_function;;CompleteTest.MyModule;;"]
  end
end
