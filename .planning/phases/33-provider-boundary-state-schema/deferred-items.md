# Phase 33 — Deferred Items

> Out-of-scope discoveries logged during plan execution. NOT fixed by the
> originating plan. Triage during phase wrap-up or spin into a follow-up plan.

---

## Pre-existing test failures (full-suite only)

Discovered during `mix test --color` for Plan 33-01 quality gate. Confirmed
pre-existing on base commit `c6aeead` BEFORE any Phase 33 changes were applied.

### 1. `Rindle.ApplicationTest` — baseline 2 failures

| Test | File | Symptom |
|---|---|---|
| `run_startup_checks warns when configured AV profiles boot on unsupported ephemeral runtimes` | `test/rindle/application_test.exs:41` | `affected_profiles` list contains `Rindle.Adopter.CanonicalApp.VideoProfile` in addition to the test-defined profile (assertion expects only the test profile). |
| `run_startup_checks stays quiet when configured profiles are image-only` | `test/rindle/application_test.exs:58` | Receives an unexpected `rindle.av.runtime_guard.unsupported_runtime` warning sourced from the canonical-app video profile bleeding into Application config. |

**Cause (suspected):** The Rindle adopter canonical-app profile module is being
discovered by the runtime guard's profile-walk regardless of test-app config
isolation. Pre-existing on base; not introduced by Plan 33-01.

**Reproduction:** `mix test test/rindle/application_test.exs --color` on
`c6aeead` (verified by checking out base and running the test in isolation).

**Disposition:** Out of scope for Phase 33. Likely an Application/profile
isolation regression introduced before this phase. Triage as a separate
follow-up (potentially a Phase 33 plan amendment if the verifier blocks on it,
otherwise hand-off to a maintenance plan).

### 2. AV / ffmpeg / ffprobe `:epipe` failures (parallelism flake)

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

**Disposition:** Pre-existing parallelism flake, not caused by Plan 33-01.
Recommended fix (out of scope here): tag AV-process tests with `async: false`
or reduce `max_cases` for those modules. Triage in a maintenance plan.

---

### 3. Pre-existing `mix credo --strict` non-zero exit (47 issues)

`mix credo --strict --color` exits with code 14 on the **base commit `c6aeead`**
BEFORE any Phase 33 changes are applied. Plan 33-01 adds zero new credo
issues — issue counts are byte-identical between baseline and HEAD:

> 10 refactoring opportunities, 21 code readability issues, 16 software design suggestions

None of the 47 issues touch `lib/rindle/streaming/capabilities.ex` or
`lib/rindle/streaming/provider.ex` (verified via grep).

**Disposition:** Out of scope for Plan 33-01. The plan acceptance criterion
"mix credo --strict must be clean" is unattainable without first cleaning up
pre-existing baseline issues — that work belongs to a maintenance plan, not
to a contract-extension-only plan.

### 4. Pre-existing `mix dialyzer` non-zero exit (11 errors)

`mix dialyzer` reports "Total errors: 11" on base. All 11 warnings are in
pre-existing files NOT touched by Plan 33-01:

- `lib/rindle/html.ex`
- `lib/rindle/ops/runtime_status.ex`
- `lib/rindle/workers/process_variant.ex`
- `lib/rindle/workers/promote_asset.ex`

Plan 33-01 adds zero new dialyzer warnings (verified — `grep streaming`
against the dialyzer log returns nothing).

**Disposition:** Out of scope. Triage in a maintenance plan.

---

## Notes

- Plan 33-01 modifies only:
  - `lib/rindle/streaming/capabilities.ex` (new)
  - `lib/rindle/streaming/provider.ex` (rewrite)
  - `test/rindle/streaming/capabilities_test.exs` (new)
  - `test/rindle/streaming/provider_test.exs` (new)
  - `test/rindle/delivery_test.exs` (Rule 1 auto-fix — see SUMMARY for the
    one assertion flip required by D-05 + D-08)
- None of these files touch FFmpeg/Port/Application-startup/credo/dialyzer paths.
- The plan's explicit tripwires (`delivery_test.exs:352-380`, `delivery_test.exs:382-391`,
  `error_test.exs`, `profile/validator_test.exs`) all stay green.
