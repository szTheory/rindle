defmodule Rindle.OwnerErasureBatchContractTest do
  use ExUnit.Case, async: true

  @batch_types ~w(
    owner_ref
    owner_erasure_batch_entry
    owner_erasure_batch_report
    batch_too_large_detail
    batch_owner_erasure_result
  )a

  test "exports batch erasure types in compiled docs" do
    {:docs_v1, _, _, _, _, _, entries} = Code.fetch_docs(Rindle)

    for type_name <- @batch_types do
      assert Enum.any?(entries, fn
               {{:type, ^type_name, 0}, _, _, _, _} -> true
               _ -> false
             end),
             "Rindle should export @type #{type_name}"
    end
  end

  test "exports batch erasure entrypoints" do
    assert function_exported?(Rindle, :preview_batch_owner_erasure, 2)
    assert function_exported?(Rindle, :erase_batch_owner_erasure, 2)
  end
end
