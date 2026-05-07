# Phase 33 — Deferred Items

> Out-of-scope discoveries logged during plan execution. NOT fixed by the
> originating plan. Triage during phase wrap-up or spin into a follow-up plan.

> All four items below were independently confirmed pre-existing on base
> commit `c6aeead` by **Plan 33-01**, **Plan 33-02**, and **Plan 33-04** during
> their respective full-suite quality gates.

---

## 1. `Rindle.ApplicationTest` — baseline 2 failures

| Test | File | Symptom |
|---|---|---|
| `run_startup_checks warns when configured AV profiles boot on unsupported ephemeral runtimes` | `test/rindle/application_test.exs:41` | `affected_profiles` list contains `Rindle.Adopter.CanonicalApp.VideoProfile` in addition to the test-defined profile (assertion expects only the test profile). |
| `run_startup_checks stays quiet when configured profiles are image-only` | `test/rindle/application_test.exs:58` | Receives an unexpected `rindle.av.runtime_guard.unsupported_runtime` warning sourced from the canonical-app video profile bleeding into Application config. |

**Cause (suspected):** The Rindle adopter canonical-app profile module is being
discovered by the runtime guard's profile-walk regardless of test-app config
isolation. The adopter test fixtures load via `elixirc_paths(:test) =
["lib", "test/support", "test/adopter"]` (`mix.exs:46`), so
`Rindle.Adopter.CanonicalApp.VideoProfile` is present in
`Application.get_env(:rindle, :profiles)` during the assertion. Pre-existing on
base; not introduced by Phase 33.

**Reproduction:** `mix test test/rindle/application_test.exs --color` on
`c6aeead` (verified by checking out base and running the test in isolation).

**Disposition:** Out of scope for Phase 33. Likely an Application/profile
isolation regression introduced before this phase. Triage as a separate
follow-up.

## 2. AV / ffmpeg / ffprobe `:epipe` failures (parallelism flake)

| Tests | Files | Symptom |
|---|---|---|
| Various `process/3` and `probe/1` cases | `test/rindle/processor/av_test.exs`, `test/rindle/processor/waveform_test.exs`, `test/rindle/probe/av_probe_test.exs`, `test/rindle/av/ffprobe_test.exs` | `** (EXIT from #PID<...>) :epipe` — broken pipe to spawned ffmpeg/ffprobe Port. |

**Cause:** `mix test` runs with `max_cases: 16` (default = `System.schedulers_online() * 2`).
Each AV test spawns one or more ffmpeg/ffprobe Ports; under high parallelism the
OS-level pipe occasionally breaks (epipe) before the test can read the
subprocess output. Each affected test passes in isolation:

- `mix test test/rindle/processor/av_test.exs --color` → 13/13 green
- `mix test test/rindle/processor/waveform_test.exs --color` → 3/3 green
- `mix test test/rindle/probe/av_probe_test.exs --color` → 5/5 green

**Disposition:** Pre-existing parallelism flake, not caused by any Phase 33
plan. Recommended fix (out of scope here): tag AV-process tests with
`async: false` or reduce `max_cases` for those modules. Triage in a
maintenance plan.

---

## 3. Pre-existing `mix credo --strict` non-zero exit (47 issues)

`mix credo --strict --color` exits with code 14 on the **base commit `c6aeead`**
BEFORE any Phase 33 changes are applied. Phase 33 plans add zero new credo
issues — issue counts are byte-identical between baseline and HEAD:

> 10 refactoring opportunities, 21 code readability issues, 16 software design suggestions

None of the 47 issues touch any Phase 33 plan-modified files (verified via
grep against `lib/rindle/streaming/`, `lib/rindle/domain/media_provider_asset.ex`,
`lib/rindle/domain/provider_asset_fsm.ex`, `lib/rindle/error.ex`, or
`lib/rindle/capability.ex`).

Affected files (pre-existing): `lib/rindle/processor/ffmpeg.ex`,
`lib/rindle/live_view.ex`, `lib/rindle/ops/runtime_status.ex`,
`lib/rindle/av/capability.ex`, `lib/rindle/domain/media_asset.ex`,
`lib/rindle/processor/av/video.ex`, `lib/rindle/workers/process_variant.ex`,
`lib/rindle/ops/lifecycle_repair.ex`, etc.

**Disposition:** Out of scope for Phase 33. The acceptance criterion
"mix credo --strict must be clean" is unattainable without first cleaning up
pre-existing baseline issues — that work belongs to a maintenance plan.

## 4. Pre-existing `mix dialyzer` non-zero exit (11 errors)

`mix dialyzer` reports "Total errors: 11" on base. All 11 warnings are in
pre-existing files NOT touched by Phase 33:

- `lib/rindle/html.ex`
- `lib/rindle/ops/runtime_status.ex`
- `lib/rindle/workers/process_variant.ex`
- `lib/rindle/workers/promote_asset.ex`

Phase 33 plans add zero new dialyzer warnings (verified — `grep streaming`,
`grep provider_asset`, `grep capability` against the dialyzer log return
nothing relevant to plan files).

**Disposition:** Out of scope. Triage in a maintenance plan.

---

## Notes

- Phase 33 plan-modified files (verified zero-impact on the four issues above):
  - `lib/rindle/streaming/capabilities.ex` (Plan 01, new)
  - `lib/rindle/streaming/provider.ex` (Plan 01, rewrite)
  - `lib/rindle/domain/media_provider_asset.ex` (Plan 02, new)
  - `lib/rindle/domain/provider_asset_fsm.ex` (Plan 02, new)
  - `priv/repo/migrations/20260506120000_create_media_provider_assets.exs` (Plan 02, new)
  - `lib/rindle/error.ex` (Plan 04, additive only — 5 new bare-atom clauses)
  - `lib/rindle/capability.ex` (Plan 04, new)
  - `test/rindle/streaming/`, `test/rindle/domain/`, `test/rindle/error_streaming_freeze_test.exs`, `test/rindle/capability_test.exs` (test files)
  - `test/rindle/delivery_test.exs` (Plan 01 Rule 1 auto-fix — see 33-01-SUMMARY for the
    one assertion flip required by D-05 + D-08)
- None of these files touch FFmpeg/Port/Application-startup/credo/dialyzer paths.
- Plan-explicit tripwires all stay green: `delivery_test.exs:352-380`,
  `delivery_test.exs:382-391`, `error_test.exs`, `profile/validator_test.exs`.
