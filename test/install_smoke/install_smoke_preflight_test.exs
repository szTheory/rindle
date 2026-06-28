defmodule Rindle.InstallSmoke.InstallSmokePreflightTest do
  @moduledoc """
  Phase 111 (Regression Locks) LOCK-01 regression lock for the
  `scripts/install_smoke.sh` cold-runner phx.new self-install guard.

  The 2026-06-26 flake cluster included an install-smoke failure where the
  `phx.new` archive was missing on a cold CI runner. The fix added a probe
  (`mix phx.new --version`) plus a self-install
  (`MIX_ENV=dev mix archive.install hex phx_new --force`) BEFORE the
  generated-app smoke runs. This lock makes that guard undeletable: a future
  edit that drops the probe, drops the self-install, or moves the install
  AFTER the smoke fails CI on the PR, not silently on `main`.

  Deliberately asserts SHIPPED artifacts ONLY (`scripts/install_smoke.sh`). It
  does NOT couple to internal `.planning/` doc paths, which move when a
  milestone is archived (gsd-cleanup) and would break this suite for a
  non-shipped reason (LOCK-05 globally enforces that decoupling). No exclude
  tag → default suite → merge-blocking `quality` lane, mirroring the sibling
  install_smoke parity tests.
  """
  use ExUnit.Case, async: true

  @repo_root Path.expand("../..", __DIR__)
  @install_smoke_script Path.join(@repo_root, "scripts/install_smoke.sh")

  setup_all do
    {:ok, %{install_smoke_script: File.read!(@install_smoke_script)}}
  end

  test "install_smoke.sh self-installs phx.new before the generated-app smoke (cold-runner guard)",
       %{install_smoke_script: script} do
    assert script =~ "mix phx.new --version",
           "install_smoke.sh must probe for the phx.new archive before using it " <>
             "(the cold-runner self-install guard's presence check)"

    assert script =~ "mix archive.install hex phx_new --force",
           "install_smoke.sh must self-install the phx.new archive when absent " <>
             "(the cold-runner self-install guard)"

    # ORDER-INDEX uses the bare "mix archive.install hex phx_new" substring (NO
    # `MIX_ENV=dev ` prefix, NO `--force` suffix) so cosmetic edits to the live
    # line don't break the order check. `:binary.match/2` RAISES if the substring
    # is absent — that is the intended loud failure for a deleted guard.
    install_idx = :binary.match(script, "mix archive.install hex phx_new") |> elem(0)
    smoke_idx = :binary.match(script, "generated_app_smoke_test.exs") |> elem(0)

    assert install_idx < smoke_idx,
           "the phx.new archive must be installed BEFORE the generated-app smoke runs " <>
             "(install_idx=#{install_idx}, smoke_idx=#{smoke_idx})"
  end
end
