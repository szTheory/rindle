# Phase135 deferred items

Original discoveries retained; explicit pending status does not assert a current reproduction.

## 135-13 docs-truth guard

- **`ci.yml` docs-truth guard: negated greps do not fail the step.** In the Quality
  job step `TRUTH-01 docs-truth guard (PROJECT.md invariant 13)`, the two
  `! grep -q ...` lines run under `set -euo pipefail`. Bash does not apply errexit to a
  `!`-negated pipeline, so a regression that reintroduces `FFmpex + MuonTrap` or
  `Rambo on macOS` would print nothing and the step would still pass. Only the positive
  `grep -q` line actually gates. actionlint/shellcheck flags both lines as SC2251. The
  same finding is present on origin/main 30a59ef5. A follow-up fix would be
  `if grep -q ...; then exit 1; fi`, which is a non-comment workflow change. That is
  outside the comment-only 135-13 tranche, and a fix there would need a `fix:`-free
  subject plus a check that `quality_signal_policy_test` or `live_truth_parity_test`
  is not pinned to the exact `!` lines.
  status: pending
  next_action: Reproduce and resolve in a separately scoped follow-up; preserve the frozen Phase136 source.

## 135-13 timing heading

- **`ci.yml` run-summary heading keeps a decision id.** `echo "## CI per-step timing
  (D-04 long-pole jobs)"` in the CI Observability job is printed text. No consumer
  reads it, but it is executable workflow text, so the comment-only tranche kept it
  and classed it `contract`. Rewording it, for example to `(long-pole jobs)`, is a
  one-line follow-up that also removes its allowlist entry.
  status: pending
  next_action: Reproduce and resolve in a separately scoped follow-up; preserve the frozen Phase136 source.

## 135-14 DoctorThresholds build-path ordering

- **`Rindle.DoctorThresholdsTest` setup_all is order-dependent on this host.** With
  `MIX_BUILD_PATH` outside the worktree, running it in the same `mix test` invocation
  as `test/install_smoke` sometimes invalidates its two tests with
  `FunctionClauseError` in `Doctor.ModuleInformation.build/2`
  (`{:error, :module_not_found}` for `Mix.Tasks.Rindle.AbortIncompleteUploads`). The
  file passes alone, and the same invalidation shows up in the pre-edit baseline on
  e8f6895a. Whether CI's in-tree build path shows it was not checked.
  status: pending
  next_action: Reproduce and resolve in a separately scoped follow-up; preserve the frozen Phase136 source.

## 135-14 generated-app compatibility

- **Generated-app `:public_compatibility_scenario` fails locally with
  `smoke_exit_code` 2** on this branch and identically on origin/main 65395f2c
  (`--only phase_120_public_compat`), MinIO running via `scripts/ensure_minio.sh`.
  Exporting `MIX_DEPS_PATH`/`MIX_BUILD_PATH` for that scenario also leaks them into the
  generated app, which then fetches its own newer deps into the shared deps dir.
  status: pending
  next_action: Reproduce and resolve in a separately scoped follow-up; preserve the frozen Phase136 source.

## 135-11 Docker compatibility harness

- **`scripts/ci/test_compat_115_26.sh` is a Docker toolchain repro, not a fixture harness.**
  It runs `mix coveralls` in the `hexpm/elixir:1.15.8` image against a throwaway Postgres
  container and is not wired into any CI job. On this host it exits 2 with the same 4
  failures (`Rindle.DoctorTest` profile-aware success output and three
  `Rindle.Workers.ProcessVariantTest` AV cases, because the plain image has no FFmpeg)
  in an unarchived clone and in archive simulation A, so archiving is not the cause. The
  archive simulation's "every `scripts/ci/test_*.sh`" loop should either skip this script
  or the script should move out of the `test_*` harness namespace.
  status: pending
  next_action: Reproduce and resolve in a separately scoped follow-up; preserve the frozen Phase136 source.

## 135-11 scheduled Nightly follow-up

- **Scheduled Nightly has concluded `failure` on its last three runs** (39218639562 on
  e76adde8, 39108080256 and 39014057417 on 4b7b8e33). No scheduled run has yet landed on
  a Phase 135 descendant, so the collector records `nightly_followup.status: pending`.
  status: pending
  next_action: Reproduce and resolve in a separately scoped follow-up; preserve the frozen Phase136 source.
