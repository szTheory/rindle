Code.require_file("support/generated_app_helper.ex", __DIR__)

defmodule Rindle.InstallSmoke.GeneratedAppSmokeTest do
  use ExUnit.Case, async: false

  alias Rindle.InstallSmoke.GeneratedAppHelper

  @moduletag :minio

  setup_all do
    report = GeneratedAppHelper.prove_package_install!()
    on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
    {:ok, report: report}
  end

  test "generated Phoenix app installs Rindle from the unpacked artifact and never falls back to repo-local deps",
       %{
         report: report
       } do
    assert File.dir?(report.generated_app_root)

    if not report.network_mode? do
      assert File.dir?(report.package_root)
    end

    refute File.exists?(Path.join(report.generated_app_root, "deps/rindle"))
    assert report.compile_exit_code == 0
    assert report.boot_exit_code == 0
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
