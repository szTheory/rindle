defmodule Rindle.Streaming.CancelDirectUploadContractTest do
  use ExUnit.Case, async: true

  test "exports cancel_direct_upload/1 implementation and types" do
    {:docs_v1, _, _, _, _, _, entries} = Code.fetch_docs(Rindle.Streaming)

    assert Enum.any?(entries, fn
             {{:type, :cancel_direct_upload_result, 0}, _, _, _, _} -> true
             _ -> false
           end)

    assert Enum.any?(entries, fn
             {{:type, :not_cancellable_detail, 0}, _, _, _, _} -> true
             _ -> false
           end)

    assert function_exported?(Rindle.Streaming, :cancel_direct_upload, 1)
  end

  test "Streaming.Provider behaviour declares optional cancel_direct_upload callback" do
    {:docs_v1, _, _, _, _, _, entries} = Code.fetch_docs(Rindle.Streaming.Provider)

    assert Enum.any?(entries, fn
             {{:callback, :cancel_direct_upload, 1}, _, _, _, _} -> true
             _ -> false
           end)
  end
end
