defmodule Rindle.InstallSmoke.GeneratedAppSmokeTest do
  use ExUnit.Case, async: false

  alias Rindle.InstallSmoke.GeneratedAppHelper

  @moduletag :minio

  setup_all do
    {:ok, report: GeneratedAppHelper.prove_package_install!()}
  end

  test "generated Phoenix app installs Rindle from the unpacked artifact and never falls back to repo-local deps", %{
    report: report
  } do
    assert File.dir?(report.generated_app_root)
    assert File.dir?(report.package_root)
    refute File.exists?(Path.join(report.generated_app_root, "deps/rindle"))
    assert report.compile_exit_code == 0
  end

  test "generated Phoenix app runs host plus Rindle migrations explicitly and proves the canonical presigned PUT lifecycle",
       %{report: report} do
    assert report.host_migration_ran?
    assert report.rindle_migration_path == Application.app_dir(:rindle, "priv/repo/migrations")
    assert report.smoke_exit_code == 0
    assert report.lifecycle_proved?
  end
end
