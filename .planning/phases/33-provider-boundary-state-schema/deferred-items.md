# Deferred Items — Phase 33

Out-of-scope test failures discovered during Plan 02 execution. These are
pre-existing on the phase base commit (`c6aeead docs(33): create phase plan`)
and are unrelated to the Plan 02 file changes (verified via
`git diff c6aeead HEAD -- test/rindle/application_test.exs test/rindle/av/ffprobe_test.exs`
returning zero diff).

## Pre-existing test failures (NOT caused by Plan 02)

### 1. `Rindle.AV.FfprobeTest test probe/1 handles ffprobe failure on invalid file`

- **File:** `test/rindle/av/ffprobe_test.exs:13`
- **Symptom:** `** (EXIT from #PID<...>) :epipe`
- **Cause:** Local ffprobe binary behavior on this machine — environment-specific.
- **Phase 33 file dependency:** none.
- **Action:** Out of scope for Plan 02. Already-broken on base commit.

### 2-3. `Rindle.ApplicationTest run_startup_checks` (2 tests)

- **File:** `test/rindle/application_test.exs:41` and `:58`
- **Symptom:** Test environment leaks `Rindle.Adopter.CanonicalApp.VideoProfile`
  into `Application.get_env(:rindle, :profiles)` from the adopter test fixtures
  loaded via `elixirc_paths(:test)` (`["lib", "test/support", "test/adopter"]` —
  see `mix.exs:46`). The expected `["Elixir.Rindle.ApplicationTest.AVProfile"]`
  no longer matches because the canonical-app fixture profile is also
  configured.
- **Phase 33 file dependency:** none.
- **Action:** Out of scope for Plan 02. Already-broken on base commit (no
  changes to `lib/rindle/application.ex`, `test/rindle/application_test.exs`,
  or `test/adopter/`).

---

*Added by Plan 02 executor: 2026-05-06*
