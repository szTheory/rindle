Code.require_file("support/generated_app_helper.ex", __DIR__)

defmodule Rindle.InstallSmoke.GeneratedAppSmokeAssertions do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      defp assert_install_source!(report) do
        assert File.dir?(report.generated_app_root)
        assert report.profile_mode in [:image, :video, :tus, :upgrade, :mux, :gcs]
        assert report.install_mode in [:package, :network]
        assert report.install_source

        if report.install_mode == :package do
          assert File.dir?(report.package_root)
          assert report.install_source == report.package_root
        else
          assert report.network_mode?
          assert String.starts_with?(report.install_source, "hex:")
        end

        refute report.deps_rindle_present?
        assert report.compile_exit_code == 0
        assert report.boot_exit_code == 0
      end

      defp assert_tus_guide_parity! do
        guide = File.read!("guides/resumable_uploads.md")

        assert guide =~ "plug Plug.Parsers,"
        assert guide =~ ~s(pass: ["application/offset+octet-stream", "*/*"])
        assert guide =~ ~s("Upload-Offset")
        assert guide =~ ~s("Location")
        assert guide =~ ~s("Upload-Length")
        assert guide =~ ~s("Tus-Resumable")
        assert guide =~ ~s("Upload-Expires")
        assert guide =~ "no-silent-downgrade"
        assert guide =~ "raises at init time"
        assert guide =~ "bearer credential"
        assert guide =~ "config :rindle, :tus_resume_authorizer, MyApp.TusAuth"
        assert guide =~ "@uppy/tus"
        assert guide =~ "tus-js-client"

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
        assert guide =~ "sticky-session or single-node"
        assert Regex.scan(~r/removeFingerprintOnSuccess: true/, guide) |> length() == 3
      end

      defp tus_failure_details(report) do
        """
        tus smoke failed
        workspace: #{report.generated_app_root}
        report: #{report.tus_report_path}
        debug_report: #{report.tus_debug_report_path}
        phase: #{inspect(report.tus_failure_phase)}
        mode: #{inspect(report.tus_failure_mode)}
        endpoint: #{inspect(report.tus_failure_endpoint)}
        summary: #{inspect(report.tus_failure_summary)}
        """
      end
    end
  end
end

alias Rindle.InstallSmoke.GeneratedAppHelper

if GeneratedAppHelper.profile_enabled?(:gcs) do
  defmodule Rindle.InstallSmoke.GeneratedAppSmokeGCSTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions

    setup_all do
      report = GeneratedAppHelper.prove_package_install!(:gcs)
      on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
      {:ok, report: report}
    end

    test "generated Phoenix app installs the GCS-enabled profile from the configured package source without repo-local fallback",
         %{report: report} do
      assert_install_source!(report)
    end

    test "generated Phoenix app exposes a first-class GCS path with doctor and resumable status proof surfaces",
         %{report: report} do
      assert report.host_migration_ran?
      assert report.migration_resolution == :application_app_dir
      assert String.ends_with?(report.rindle_migration_path, "/priv/repo/migrations")
      refute String.contains?(report.rindle_migration_path, "deps/rindle")
      assert report.smoke_exit_code == 0
      assert report.lifecycle_proved?
      assert report.doctor_command =~ "mix rindle.doctor"
      assert report.gcs_status_surface == "Rindle.resumable_session_status/2"
    end

    test "generated Phoenix app proves the live GCS resumable lifecycle only when bucket secrets are present",
         %{report: report} do
      if report.gcs_live_enabled? do
        assert report.doctor_success?
        assert report.gcs_status_state == "complete"
        assert is_integer(report.gcs_status_committed_bytes)
        assert report.gcs_status_committed_bytes > 0
        assert report.gcs_asset_state_after_verify == "validating"
        assert report.gcs_asset_state_after_promote in ["available", "processing", "ready"]
        assert is_binary(report.gcs_upload_key)
      else
        refute report.doctor_success?
        assert is_nil(report.gcs_status_state)
        assert is_nil(report.gcs_asset_state_after_promote)
      end
    end
  end
end

if GeneratedAppHelper.profile_enabled?(:image) do
  defmodule Rindle.InstallSmoke.GeneratedAppSmokeImageTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions
    @moduletag :minio

    setup_all do
      report = GeneratedAppHelper.prove_package_install!(:image)
      on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
      {:ok, report: report}
    end

    test "generated Phoenix app installs Rindle from the configured package source and never falls back to repo-local deps",
         %{report: report} do
      assert_install_source!(report)
    end

    test "generated Phoenix app runs host plus Rindle migrations explicitly and proves the canonical presigned PUT lifecycle",
         %{report: report} do
      assert report.host_migration_ran?
      assert report.migration_resolution == :application_app_dir
      assert String.ends_with?(report.rindle_migration_path, "/priv/repo/migrations")
      refute String.contains?(report.rindle_migration_path, "deps/rindle")
      assert report.smoke_exit_code == 0
      assert report.lifecycle_proved?
    end
  end
end

if GeneratedAppHelper.profile_enabled?(:video) do
  defmodule Rindle.InstallSmoke.GeneratedAppSmokeVideoTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions
    @moduletag :minio

    setup_all do
      report = GeneratedAppHelper.prove_package_install!(:video)
      on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
      {:ok, report: report}
    end

    test "generated Phoenix app installs the AV-enabled profile from the configured package source without repo-local fallback",
         %{report: report} do
      assert_install_source!(report)
    end

    test "generated Phoenix app proves the canonical AV path with web_720p, poster, and signed delivery",
         %{report: report} do
      assert report.host_migration_ran?
      assert report.migration_resolution == :application_app_dir
      assert String.ends_with?(report.rindle_migration_path, "/priv/repo/migrations")
      refute String.contains?(report.rindle_migration_path, "deps/rindle")
      assert report.smoke_exit_code == 0
      assert report.lifecycle_proved?
      assert report.av_ready_variants == ["poster", "web_720p"]
      assert is_binary(report.av_playback_storage_key)
      assert String.contains?(report.av_playback_storage_key, "web_720p")
      assert is_binary(report.av_delivery_path)
      assert String.contains?(report.av_delivery_path, report.av_playback_storage_key)
    end
  end
end

if GeneratedAppHelper.profile_enabled?(:tus) do
  defmodule Rindle.InstallSmoke.GeneratedAppSmokeTusTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions
    @moduletag :minio

    setup_all do
      report = GeneratedAppHelper.prove_package_install!(:tus)
      on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
      {:ok, report: report}
    end

    test "generated Phoenix app installs the tus-enabled profile from the configured package source without repo-local fallback",
         %{report: report} do
      assert_install_source!(report)
    end

    test "generated Phoenix app proves a real-socket tus-js-client drop-and-resume flow against MinIO",
         %{report: report} do
      assert report.host_migration_ran?
      assert report.migration_resolution == :application_app_dir
      assert String.ends_with?(report.rindle_migration_path, "/priv/repo/migrations")
      refute String.contains?(report.rindle_migration_path, "deps/rindle")
      assert report.smoke_exit_code == 0, tus_failure_details(report)
      assert report.lifecycle_proved?, tus_failure_details(report)
      assert report.phoenix_helper_uploader == "RindleTus"

      assert report.phoenix_helper_endpoint == "/uploads/tus" or
               String.contains?(report.phoenix_helper_endpoint || "", "/uploads/tus")

      assert is_binary(report.phoenix_helper_upload_url)
      assert String.contains?(report.phoenix_helper_upload_url, "/uploads/tus/")
      assert is_binary(report.phoenix_helper_session_id)
      assert is_binary(report.phoenix_helper_asset_id)
      assert report.completion_surface == "consume_uploaded_entries->verify_completion"
      assert report.phoenix_state_sequence == ["uploading", "verifying", "ready"]

      assert if(report.tus_failure_phase in [nil, "none"],
               do: is_nil(report.phoenix_error_state),
               else: report.phoenix_error_state == "error"
             )

      assert is_binary(report.tus_upload_url)
      assert String.contains?(report.tus_upload_url, "/uploads/tus/")
      assert report.tus_previous_uploads >= 1
      assert report.tus_byte_size >= 200 * 1024 * 1024
      assert report.tus_content_type == "video/mp4"
      assert report.tus_ready_variants == ["poster", "web_720p"]

      assert is_map(report.extensions), tus_failure_details(report)

      assert report.tus_report_data["extensions"] == report.extensions,
             tus_failure_details(report)

      extensions = report.extensions
      concatenation = extensions["concatenation"] || %{}
      creation_defer_length = extensions["creation_defer_length"] || %{}
      checksum = extensions["checksum"] || %{}

      assert concatenation["proved"] == true, tus_failure_details(report)
      assert concatenation["parallel_uploads"] == 2, tus_failure_details(report)
      assert concatenation["status"] in [201, 204], tus_failure_details(report)

      assert creation_defer_length["proved"] == true, tus_failure_details(report)

      assert creation_defer_length["used_upload_defer_length"] == true,
             tus_failure_details(report)

      assert creation_defer_length["status"] == 204, tus_failure_details(report)

      assert checksum["proved"] == true, tus_failure_details(report)
      assert checksum["algorithm"] in ["sha1", "sha256"], tus_failure_details(report)
      assert checksum["status"] == 204, tus_failure_details(report)
      assert_tus_guide_parity!()
    end
  end
end

if GeneratedAppHelper.profile_enabled?(:mux) do
  defmodule Rindle.InstallSmoke.GeneratedAppSmokeMuxTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions
    @moduletag :minio

    setup_all do
      report = GeneratedAppHelper.prove_package_install!(:mux)
      on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
      {:ok, report: report}
    end

    test "generated Phoenix app installs the Mux-enabled profile from the configured package source without repo-local fallback",
         %{report: report} do
      assert_install_source!(report)
    end

    test "generated Phoenix app proves the canonical AV path PLUS Mux-signed HLS streaming URL via cassette",
         %{report: report} do
      assert report.host_migration_ran?
      assert report.migration_resolution == :application_app_dir
      assert String.ends_with?(report.rindle_migration_path, "/priv/repo/migrations")
      refute String.contains?(report.rindle_migration_path, "deps/rindle")
      assert report.smoke_exit_code == 0
      assert report.lifecycle_proved?
      assert report.av_ready_variants == ["poster", "web_720p"]
      assert is_binary(report.av_playback_storage_key)
      assert String.contains?(report.av_playback_storage_key, "web_720p")
      assert is_binary(report.delivery_path)
      assert report.streaming_url_kind == "hls"
      assert String.contains?(report.delivery_path, ".m3u8")
    end
  end
end

if GeneratedAppHelper.profile_enabled?(:video) do
  defmodule Rindle.InstallSmoke.GeneratedAppSmokeUpgradeTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions
    @moduletag :minio

    setup_all do
      report = GeneratedAppHelper.prove_upgrade_install!()
      on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
      {:ok, report: report}
    end

    test "generated Phoenix app upgrades a pre-v1.4 image-only adopter through the public migration path",
         %{report: report} do
      assert_install_source!(report)
      assert report.host_migration_ran?
      assert report.migration_resolution == :application_app_dir
      assert report.legacy_migration_cutoff == "20260428110000"
      assert String.ends_with?(report.rindle_migration_path, "/priv/repo/migrations")
      refute String.contains?(report.rindle_migration_path, "deps/rindle")
      assert report.legacy_asset_kind == "image"
      assert report.legacy_asset_profile =~ ".RindleProfile"
      assert report.legacy_asset_upgrade_safe?

      assert Enum.map(report.legacy_ready_variants, & &1["name"]) == ["thumb"]
      assert Enum.map(report.legacy_ready_variants, & &1["output_kind"]) == ["image"]
      assert report.smoke_exit_code == 0
      assert report.lifecycle_proved?
    end

    test "generated Phoenix app proves doctor, runtime-status, and asset-scoped cancelled-work requeue after upgrade",
         %{report: report} do
      assert report.doctor_passed?
      assert "cancelled_work" in report.runtime_status_classes
      assert "requeue" in report.runtime_status_recommendation_actions
      assert "Rindle.requeue_variants/2" in report.runtime_status_recommendation_surfaces
      assert report.requeue_selected == 1
      assert report.requeue_enqueued + report.requeue_skipped == 1
      assert report.repaired_variant_state == "ready"
      assert report.ready_sibling_state == "ready"

      assert Enum.map(report.canonical_upgrade_step_sequence, & &1.proof) == [
               "FFmpeg >= 6.0",
               "Application.app_dir(:rindle, \"priv/repo/migrations\")",
               "mix rindle.doctor",
               "mix rindle.runtime_status",
               "Rindle.requeue_variants/2",
               "mix rindle.regenerate_variants"
             ]
    end
  end
end
