defmodule Rindle.Domain.LifecycleFSMTest do
  use ExUnit.Case, async: true

  import Ecto.Query

  alias Rindle.Domain.AssetFSM
  alias Rindle.Domain.MediaVariant
  alias Rindle.Domain.StalePolicy
  alias Rindle.Domain.UploadSessionFSM
  alias Rindle.Domain.VariantFSM
  alias VariantFSM

  describe "asset transition matrix" do
    test "accepts the nominal asset lifecycle path" do
      assert :ok == AssetFSM.transition("staged", "validating")
      assert :ok == AssetFSM.transition("validating", "analyzing")
      assert :ok == AssetFSM.transition("analyzing", "promoting")
      assert :ok == AssetFSM.transition("promoting", "available")
      assert :ok == AssetFSM.transition("available", "processing")
      assert :ok == AssetFSM.transition("processing", "ready")
    end

    test "accepts degraded, quarantine, and terminal delete branches" do
      assert :ok == AssetFSM.transition("ready", "degraded")
      assert :ok == AssetFSM.transition("available", "quarantined")
      assert :ok == AssetFSM.transition("processing", "quarantined")
      assert :ok == AssetFSM.transition("degraded", "quarantined")
      assert :ok == AssetFSM.transition("ready", "deleted")
      assert :ok == AssetFSM.transition("quarantined", "deleted")
    end

    test "rejects non-allowlisted asset jumps" do
      assert {:error, {:invalid_transition, "staged", "ready"}} =
               AssetFSM.transition("staged", "ready")

      assert {:error, {:invalid_transition, "staged", "degraded"}} =
               AssetFSM.transition("staged", "degraded")

      assert {:error, {:invalid_transition, "validating", "quarantined"}} =
               AssetFSM.transition("validating", "quarantined")

      assert {:error, {:invalid_transition, "analyzing", "deleted"}} =
               AssetFSM.transition("analyzing", "deleted")
    end
  end

  describe "variant transition matrix" do
    test "accepts planned through ready path" do
      assert :ok == VariantFSM.transition("planned", "queued")
      assert :ok == VariantFSM.transition("queued", "processing")
      assert :ok == VariantFSM.transition("processing", "ready")
    end

    test "accepts variant failure and stale lifecycle branches" do
      assert :ok == VariantFSM.transition("processing", "failed")
      assert :ok == VariantFSM.transition("ready", "stale")
      assert :ok == VariantFSM.transition("ready", "missing")
      assert :ok == VariantFSM.transition("stale", "queued")
      assert :ok == VariantFSM.transition("missing", "purged")
      assert :ok == VariantFSM.transition("failed", "purged")
    end

    test "rejects invalid variant transitions" do
      assert {:error, {:invalid_transition, "planned", "ready"}} =
               VariantFSM.transition("planned", "ready")

      assert {:error, {:invalid_transition, "queued", "purged"}} =
               VariantFSM.transition("queued", "purged")

      assert {:error, {:invalid_transition, "purged", "queued"}} =
               VariantFSM.transition("purged", "queued")
    end
  end

  describe "upload session transition matrix" do
    test "accepts initialized through completed path" do
      assert :ok == UploadSessionFSM.transition("initialized", "signed")
      assert :ok == UploadSessionFSM.transition("signed", "uploading")
      assert :ok == UploadSessionFSM.transition("uploading", "uploaded")
      assert :ok == UploadSessionFSM.transition("uploaded", "verifying")
      assert :ok == UploadSessionFSM.transition("verifying", "completed")
    end

    test "accepts upload session terminal branches" do
      assert :ok == UploadSessionFSM.transition("initialized", "expired")
      assert :ok == UploadSessionFSM.transition("signed", "failed")
      assert :ok == UploadSessionFSM.transition("uploading", "aborted")
      assert :ok == UploadSessionFSM.transition("verifying", "failed")
    end

    test "rejects invalid upload session transitions" do
      assert {:error, {:invalid_transition, "initialized", "completed"}} =
               UploadSessionFSM.transition("initialized", "completed")

      assert {:error, {:invalid_transition, "uploaded", "completed"}} =
               UploadSessionFSM.transition("uploaded", "completed")

      assert {:error, {:invalid_transition, "completed", "failed"}} =
               UploadSessionFSM.transition("completed", "failed")
    end
  end

  describe "structured log helpers" do
    test "quarantine helper returns ok" do
      assert :ok = AssetFSM.log_quarantine("asset-1", "application/x-msdownload", "mime_mismatch")
    end

    test "session expiry helper returns ok" do
      assert :ok = UploadSessionFSM.log_session_expiry("session-1", 300)
    end
  end

  describe "stale policy foundations" do
    test "serve_stale mode keeps stale variant response" do
      assert {:serve_variant, :stale} ==
               StalePolicy.resolve_stale_variant(:serve_stale, "stale", "/media/original.jpg")
    end

    test "serve_stale mode falls back when variant is not stale" do
      assert {:serve_original, "/media/original.jpg"} =
               StalePolicy.resolve_stale_variant(:serve_stale, "ready", "/media/original.jpg")
    end

    test "fallback mode always serves original url" do
      assert {:serve_original, "/media/source.jpg"} =
               StalePolicy.resolve_stale_variant(:fallback_original, "stale", "/media/source.jpg")
    end

    test "stale regeneration scope filters query to stale variants only" do
      base_query = from(v in MediaVariant)
      scoped_query = StalePolicy.stale_regeneration_scope(base_query)

      assert length(scoped_query.wheres) == 1
      assert inspect(scoped_query.wheres) =~ "state"
      assert inspect(scoped_query.wheres) =~ "stale"
    end
  end
end
