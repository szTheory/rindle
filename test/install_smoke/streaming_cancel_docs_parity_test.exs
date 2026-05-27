defmodule Rindle.InstallSmoke.StreamingCancelDocsParityTest do
  use ExUnit.Case, async: true

  @guide_path Path.expand("../../guides/streaming_providers.md", __DIR__)

  test "streaming guide documents cancel semantics for Phase 66 TRUTH-01" do
    guide = File.read!(@guide_path)

    assert guide =~ "cancel_direct_upload/1"
    assert guide =~ "create_direct_upload/2"
    assert guide =~ "upload.abort()" or guide =~ "UpChunk"
    assert guide =~ "pending"
    assert guide =~ "uploading"
    assert guide =~ "Mux"
    assert guide =~ "v1.13" or guide =~ "Mux-only" or guide =~ "Mux direct"
    assert guide =~ "Oban.cancel_jobs"
    assert guide =~ "provider_sync_failed"
    assert guide =~ "fresh" or guide =~ "do not reuse"
  end
end
