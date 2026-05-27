defmodule Rindle.InstallSmoke.PhoenixTusTruthParityTest do
  use ExUnit.Case, async: true

  @guide_path Path.expand("../../guides/resumable_uploads.md", __DIR__)
  @live_view_path Path.expand("../../lib/rindle/live_view.ex", __DIR__)
  @generated_helper_path Path.expand("support/generated_app_helper.ex", __DIR__)
  @project_path Path.expand("../../.planning/PROJECT.md", __DIR__)
  # Between milestones there is no root REQUIREMENTS.md; latest shipped charter lives in milestones/.
  @requirements_path Path.expand("../../.planning/milestones/v1.16-REQUIREMENTS.md", __DIR__)
  @roadmap_path Path.expand("../../.planning/ROADMAP.md", __DIR__)
  @state_path Path.expand("../../.planning/STATE.md", __DIR__)
  @v18_roadmap_path Path.expand("../../.planning/milestones/v1.8-ROADMAP.md", __DIR__)
  @v18_strategy_path Path.expand("../../.planning/research/v1.8/STRATEGY-SEQUENCING.md", __DIR__)
  @v18_tus_research_path Path.expand("../../.planning/research/v1.8/TUS-RESEARCH.md", __DIR__)

  test "guide, helper seam, and generated-app proof freeze the Phase 50 Phoenix contract" do
    guide = File.read!(@guide_path)
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
  end

  test "active truth surfaces and historical v1.8 redirects stay aligned with the Phase 48 contract" do
    active_truth_surfaces =
      Enum.map([@project_path, @requirements_path, @roadmap_path, @state_path], &File.read!/1)

    active_truth = Enum.join(active_truth_surfaces, "\n")

    historical_surfaces =
      Enum.map([@v18_roadmap_path, @v18_strategy_path, @v18_tus_research_path], &File.read!/1)

    assert active_truth =~ "Rindle.LiveView.allow_tus_upload/4"
    assert active_truth =~ ~s(uploader: "RindleTus")
    assert active_truth =~ "verify_completion/2"

    for doc <- active_truth_surfaces do
      refute doc =~ "LiveView tus uploader component"
    end

    for doc <- historical_surfaces do
      assert doc =~ "Historical v1.8 note"
      assert doc =~ ".planning/PROJECT.md"
      assert doc =~ ".planning/REQUIREMENTS.md"
      assert doc =~ ".planning/ROADMAP.md"
      assert doc =~ "guides/resumable_uploads.md"
      assert doc =~ "LiveView tus uploader component"
    end
  end
end
