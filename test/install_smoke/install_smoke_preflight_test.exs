defmodule Rindle.InstallSmoke.InstallSmokePreflightTest do
  @moduledoc """
  Executable contract for the generated-app Phoenix installer.

  Every install-smoke entry point delegates to one pinned installer helper. The
  helper must work on a cold runner, leave a compatible archive alone, and fail
  with an actionable message when installation does not produce the requested
  version.
  """

  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)
  @install_smoke_script Path.join(@repo_root, "scripts/install_smoke.sh")
  @installer_script Path.join(@repo_root, "scripts/ci/ensure_phx_new.sh")
  @expected_version "Phoenix installer v1.8.9"

  setup_all do
    {:ok,
     %{
       install_smoke_script: File.read!(@install_smoke_script),
       installer_script: File.read!(@installer_script)
     }}
  end

  test "install smoke delegates to the pinned installer before generating an app", %{
    install_smoke_script: install_smoke,
    installer_script: installer
  } do
    assert install_smoke =~ ~s(bash "$SCRIPT_DIR/ci/ensure_phx_new.sh")
    assert installer =~ ~s(PHX_NEW_VERSION="1.8.9")
    assert installer =~ ~s(mix archive.install hex phx_new "$PHX_NEW_VERSION" --force)

    installer_index = :binary.match(install_smoke, "ensure_phx_new.sh") |> elem(0)
    smoke_index = :binary.match(install_smoke, "generated_app_smoke_test.exs") |> elem(0)
    assert installer_index < smoke_index
  end

  @tag :tmp_dir
  test "a cold runner installs the pinned generator", %{tmp_dir: tmp_dir} do
    fake = install_fake_mix(tmp_dir)
    state = Path.join(tmp_dir, "state")
    log = Path.join(tmp_dir, "calls")

    {output, 0} = run_installer(fake, state, log)

    assert output =~ "Installing #{@expected_version}"
    assert state |> File.read!() |> String.trim() == @expected_version
    assert File.read!(log) =~ "archive.install hex phx_new 1.8.9 --force"
  end

  @tag :tmp_dir
  test "a matching generator is reused without reinstalling", %{tmp_dir: tmp_dir} do
    fake = install_fake_mix(tmp_dir)
    state = Path.join(tmp_dir, "state")
    log = Path.join(tmp_dir, "calls")
    File.write!(state, @expected_version)

    {_output, 0} = run_installer(fake, state, log)

    refute File.read!(log) =~ "archive.install"
  end

  @tag :tmp_dir
  test "a failed replacement reports the expected and actual versions", %{tmp_dir: tmp_dir} do
    fake = install_fake_mix(tmp_dir)
    state = Path.join(tmp_dir, "state")
    log = Path.join(tmp_dir, "calls")
    File.write!(state, "Phoenix installer v1.7.0")

    {output, 1} = run_installer(fake, state, log, "broken")

    assert output =~ "expected '#{@expected_version}'"
    assert output =~ "Phoenix installer v0.0.0"
  end

  defp install_fake_mix(tmp_dir) do
    path = Path.join(tmp_dir, "mix")

    File.write!(path, """
    #!/usr/bin/env bash
    set -euo pipefail
    echo "$*" >> "$FAKE_MIX_LOG"
    if [ "$*" = "phx.new --version" ]; then
      if [ -f "$FAKE_MIX_STATE" ]; then
        cat "$FAKE_MIX_STATE"
      else
        exit 1
      fi
    elif [ "$*" = "archive.install hex phx_new 1.8.9 --force" ]; then
      if [ "${FAKE_INSTALL_RESULT:-ok}" = "broken" ]; then
        echo "Phoenix installer v0.0.0" > "$FAKE_MIX_STATE"
      else
        echo "#{@expected_version}" > "$FAKE_MIX_STATE"
      fi
    else
      exit 64
    fi
    """)

    File.chmod!(path, 0o755)
    path
  end

  defp run_installer(fake, state, log, result \\ "ok") do
    env = [
      {"PATH", Path.dirname(fake) <> ":" <> System.fetch_env!("PATH")},
      {"FAKE_MIX_STATE", state},
      {"FAKE_MIX_LOG", log},
      {"FAKE_INSTALL_RESULT", result}
    ]

    System.cmd("bash", [@installer_script], env: env, stderr_to_stdout: true)
  end
end
