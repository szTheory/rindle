Code.require_file("support/generated_app_helper.ex", __DIR__)

defmodule Rindle.InstallSmoke.GeneratedAppSmokeAssertions do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      @moduletag :minio

      defp assert_install_source!(report) do
        assert File.dir?(report.generated_app_root)
        assert report.profile_mode in [:image, :video]
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
    end
  end
end

alias Rindle.InstallSmoke.GeneratedAppHelper

if GeneratedAppHelper.profile_enabled?(:image) do
  defmodule Rindle.InstallSmoke.GeneratedAppSmokeImageTest do
    use ExUnit.Case, async: false
    use Rindle.InstallSmoke.GeneratedAppSmokeAssertions

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
