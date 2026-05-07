# Phase 35 — Deferred Items

Out-of-scope discoveries surfaced during execution but not addressed.

## From Plan 35-03 execution (2026-05-07)

### Pre-existing `mix format --check-formatted` violations

`mix format --check-formatted` reports unrelated formatting drift in
production source files that were NOT touched by Plan 35-03:

- `lib/rindle/ops/lifecycle_repair.ex`
- `lib/rindle/processor/av/video.ex`
- (and likely more — exit 1 across the run)

These are pre-existing on `main` (commit 1768567 base) and were not
introduced by Plan 35-03. Per execute-plan scope boundary, leaving these
to a future cleanup pass (`mix format` repo-wide) or v1.7 polish.

Plan 35-03's own added/modified files (`test/support/mux_webhook_fixtures.ex`,
`test/rindle/test/mux_webhook_fixtures_test.exs`,
`test/rindle/streaming/provider/mux/mux_test.exs`, and the 5 fixture JSONs)
all pass `mix format --check-formatted` cleanly.

## From Plan 35-02 execution (2026-05-07)

### Pre-existing `Rindle.ApplicationTest` failures

Two tests in `test/rindle/application_test.exs` fail on the base branch
(commit 72a515a) BEFORE any Plan 35-02 changes are applied:

- `test run_startup_checks warns when configured AV profiles boot on unsupported ephemeral runtimes`
- `test run_startup_checks stays quiet when configured profiles are image-only`

Root cause: `Rindle.Config.profile_modules/0` discovers
`Rindle.Adopter.CanonicalApp.VideoProfile` (an adopter test profile) in
addition to the test-local AV profile, so `affected_profiles` is `[adopter,
test_local]` instead of the expected `[test_local]`. This is a pre-existing
test isolation issue unrelated to Phase 35 / webhook ingest. Confirmed
reproducible by stashing Plan 35-02 changes and running the test in
isolation.

Out of Plan 35-02 scope per execute-plan scope boundary — log only.
Track for v1.6/v1.7 polish: scope `Rindle.Application.run_startup_checks/1`
to test-supplied profile lists, or filter discovery to a configured
allowlist in test envs.

## From Plan 35-04 execution (2026-05-07)

### Pre-existing test failures (not introduced by 35-04)

`mix test` (full suite) reports 3 failures on the worktree base. Verified
pre-existing by `git stash` + re-run on the bare base:

1. `test/rindle/application_test.exs:41` — `run_startup_checks warns when
   configured AV profiles boot on unsupported ephemeral runtimes`. The
   adopter `Rindle.Adopter.CanonicalApp.VideoProfile` is configured in
   `:rindle, :profiles` and pollutes the assertion that expects only the
   test-defined profile.
2. `test/rindle/application_test.exs:58` — `run_startup_checks stays
   quiet when configured profiles are image-only`. Same cause: an AV
   profile leaks into the image-only test scenario.
3. `test/rindle/probe/av_probe_test.exs:58` — `propagates ffprobe
   failures for invalid input`. Passes in isolation; order-sensitive.

All three reproduce on the base branch before any 35-04 changes. Out of
scope for Plan 35-04; track for a v1.7 polish pass or address via
`/gsd-code-review`.

### Plan-04 referenced wrong test path

`35-04-PLAN.md` `<files>` referenced `test/mix/tasks/rindle.runtime_status_test.exs`,
but the actual Mix-task test file lives at
`test/rindle/runtime_status_task_test.exs`. The executor extended the
real file (Rule 3 — fix blocking issue). No new file was created.
