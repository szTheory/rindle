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

  test "guide, helper seam, and generated-app proof freeze the Phase 50 Phoenix contract" do
    guide = File.read!(@guide_path)
    storage_capabilities = File.read!(@storage_capabilities_path)
    profiles_guide = File.read!(@profiles_guide_path)

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

    assert function_exported?(Rindle.LiveView, :allow_tus_upload, 4)
    assert function_exported?(Rindle.LiveView, :consume_uploaded_entries, 3)

    {:docs_v1, _, _, _, _, _, docs} = Code.fetch_docs(Rindle.LiveView)

    assert Enum.any?(docs, fn
             {{:function, :allow_tus_upload, 4}, _, _, documentation, _} ->
               inspect(documentation) =~ "tus"

             _ ->
               false
           end)

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
