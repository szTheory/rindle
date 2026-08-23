defmodule Rindle.InstallSmoke.PhoenixTusTruthParityTest do
  @moduledoc """
  Freezes the SHIPPED Phoenix tus contract (Phase 50): the adopter-facing guide,
  the `Rindle.LiveView` helper seam, and the generated-app proof helper.

  Deliberately asserts SHIPPED artifacts ONLY (guide, lib, test support). It does
  NOT couple to internal `.planning/` doc paths: those move/disappear when a
  milestone is archived (gsd-cleanup) or as GSD tooling rewrites STATE.md /
  research/, which would break this lock for a non-shipped reason. The previous
  planning-doc "truth parity" test asserted internal-only doc content (redirect
  notes, absence of a stale phrase) that protects no shipped behavior — the
  adopter-facing truth is fully locked by the guide + lib assertions below.
  """
  use ExUnit.Case, async: true

  @guide_path Path.expand("../../guides/resumable_uploads.md", __DIR__)
  @storage_capabilities_path Path.expand("../../guides/storage_capabilities.md", __DIR__)
  @profiles_guide_path Path.expand("../../guides/profiles.md", __DIR__)
  @live_view_path Path.expand("../../lib/rindle/live_view.ex", __DIR__)
  @generated_helper_path Path.expand("support/generated_app_helper.ex", __DIR__)

  test "guide, helper seam, and generated-app proof freeze the Phase 50 Phoenix contract" do
    guide = File.read!(@guide_path)
    storage_capabilities = File.read!(@storage_capabilities_path)
    profiles_guide = File.read!(@profiles_guide_path)
    live_view = File.read!(@live_view_path)
    generated_helper = File.read!(@generated_helper_path)

    assert guide =~ "allow_tus_upload/4"
    assert guide =~ ~s(uploader: "RindleTus")
    assert guide =~ "consume_uploaded_entries/3"
    assert guide =~ "verify_completion/2"
    assert guide =~ "`uploading`, `verifying`, `ready`, and `error`"
    assert guide =~ "`100%` means bytes transferred"
    assert guide =~ "findPreviousUploads()"
    assert guide =~ "resumeFromPreviousUpload(previousUploads[0])"

    assert guide =~
             "Supported tus extensions: creation, expiration, termination, checksum, creation-defer-length, concatenation."

    assert guide =~ "checksum"
    assert guide =~ "creation-defer-length"
    assert guide =~ "concatenation"
    assert guide =~ "parallelUploads"
    assert guide =~ "uploadLengthDeferred"
    assert guide =~ "parallelUploads: 2"
    assert guide =~ "uploadLengthDeferred: true"
    refute guide =~ "parallelUploads: 1 is the supported posture for the Rindle tus edge."

    assert live_view =~ "guides/resumable_uploads.md"
    assert live_view =~ "allow_tus_upload/4"
    assert live_view =~ ~s(uploader: "RindleTus")
    assert live_view =~ "consume_uploaded_entries/3"
    assert live_view =~ "session_id"
    assert live_view =~ "asset_id"

    assert generated_helper =~ "allow_tus_upload("
    assert generated_helper =~ "preflight_upload(upload)"
    assert generated_helper =~ "render_submit()"
    assert generated_helper =~ ~s(phoenix_helper_uploader: phoenix_helper_uploader)
    assert generated_helper =~ ~s(phoenix_helper_endpoint: phoenix_helper_endpoint)
    assert generated_helper =~ ~s(phoenix_helper_upload_url: phoenix_helper_upload_url)
    assert generated_helper =~ ~s(phoenix_helper_session_id: phoenix_helper_session_id)
    assert generated_helper =~ ~s(phoenix_helper_asset_id: phoenix_helper_asset_id)

    assert generated_helper =~
             ~s(completion_surface: "consume_uploaded_entries->verify_completion")

    assert generated_helper =~ ~s(phoenix_state_sequence: ["uploading", "verifying", "ready"])
    assert generated_helper =~ ~s(phoenix_error_state: "error")

    for doc <- [guide, storage_capabilities, profiles_guide] do
      assert doc =~ "Local/S3"
      assert doc =~ ":tus_upload"
      assert Regex.match?(~r/GCS\s+provider-direct/, doc)
    end

    assert storage_capabilities =~ "Cloudflare R2"
    assert storage_capabilities =~ "server-mediated tus edge is available through that adapter"

    assert guide =~ "no silent fallback"
    assert storage_capabilities =~ "silently falls back"
    assert Regex.match?(~r/does not\s+silently downgrade/, profiles_guide)
  end

  test "shipped storage adapters advertise the documented tus boundary" do
    assert :tus_upload in Rindle.Storage.Local.capabilities()
    assert :tus_upload in Rindle.Storage.S3.capabilities()
    refute :tus_upload in Rindle.Storage.GCS.capabilities()
  end
end
