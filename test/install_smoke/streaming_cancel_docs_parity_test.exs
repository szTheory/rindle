defmodule Rindle.InstallSmoke.StreamingCancelDocsParityTest do
  use ExUnit.Case, async: true

  @guide_path Path.expand("../../guides/streaming_providers.md", __DIR__)
  @delivery_path Path.expand("../../lib/rindle/delivery.ex", __DIR__)
  @webhook_plug_path Path.expand("../../lib/rindle/delivery/webhook_plug.ex", __DIR__)
  @sync_coordinator_path Path.expand("../../lib/rindle/workers/mux_sync_coordinator.ex", __DIR__)

  test "streaming guide documents cancel semantics for Phase 66 TRUTH-01" do
    guide = File.read!(@guide_path)
    delivery = File.read!(@delivery_path)
    webhook_plug = File.read!(@webhook_plug_path)
    sync_coordinator = File.read!(@sync_coordinator_path)

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

    assert Regex.match?(~r/Mux is the only\s+shipped streaming provider\./, guide)
    assert guide =~ "signed HLS playback"
    assert guide =~ "WebhookPlug"
    assert guide =~ "polling"
    assert guide =~ "cancel_processing/1"
    refute guide =~ "second streaming provider"

    assert delivery =~ "streaming_url"
    assert webhook_plug =~ "WebhookPlug"
    assert sync_coordinator =~ "MuxSyncCoordinator"
  end
end
