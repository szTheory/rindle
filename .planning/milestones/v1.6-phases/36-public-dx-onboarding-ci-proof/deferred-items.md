# Phase 36 — Deferred Items

Out-of-scope discoveries surfaced during execution but not addressed.

## From Plan 36-01 execution (2026-05-07)

### Pre-existing `Rindle.ApplicationTest` failures

Two tests in `test/rindle/application_test.exs` fail on the base branch
(commit `22ec9a1` and below) BEFORE any Plan 36-01 changes are applied:

- `test run_startup_checks warns when configured AV profiles boot on
  unsupported ephemeral runtimes`
- `test run_startup_checks stays quiet when configured profiles are image-only`

Confirmed pre-existing by `git stash` of Plan 36-01 modifications and
re-running on the clean base — both failures persist. Already documented
in Phase 35's `deferred-items.md` (Plan 35-02 entry). Root cause:
`Rindle.Config.profile_modules/0` test isolation issue —
`Rindle.Adopter.CanonicalApp.VideoProfile` is discovered alongside the
test-local AV profile, so `affected_profiles` is `[adopter, test_local]`
instead of the expected `[test_local]`.

Tracked for v1.7 polish; out of scope for Phase 36.

### Pre-existing AV probe / processor tests fail intermittently

`test/rindle/probe/av_probe_test.exs` and `test/rindle/processor/av_test.exs`
show occasional failures across the broader `mix test test/rindle/` sweep
on this base. These are FFmpeg-runtime-dependent tests that have shown
intermittent behavior in prior phases. Not introduced by Plan 36-01;
unrelated to the public DX onboarding scope.
