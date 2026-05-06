# Phase 28 Plan 02 Summary

## Outcome

Promoted `mix rindle.doctor` into a profile-aware AV ship gate and wired it into CI, then added a narrow AV subprocess hygiene gate scoped to `lib/rindle/`.

## Files Changed

- `.github/workflows/ci.yml`
- `lib/mix/tasks/rindle.doctor.ex`
- `test/rindle/doctor_test.exs`
- `scripts/assert_av_hygiene.sh`

## Completed Tasks

### Task 1: Promote `mix rindle.doctor` into a fixture-aware AV ship gate and wire it into CI

- `mix rindle.doctor` now accepts explicit profile module arguments.
- The task validates canonical fixture/example profiles through the public profile API and AV runtime contract, then prints stable per-profile status lines.
- Doctor failures now raise `Mix.Error` with actionable `Rindle.Doctor failed: ...` output for CI instead of halting silently.
- CI now provisions FFmpeg with `FedericoCarboni/setup-ffmpeg@v3` in the AV-relevant `quality` and `adopter` jobs and runs the public doctor task against:
  - `Rindle.Adopter.CanonicalApp.Profile`
  - `Rindle.Adopter.CanonicalApp.VideoProfile`

### Task 2: Add the narrow AV anti-pattern hygiene gate to CI

- Added `scripts/assert_av_hygiene.sh` with `set -euo pipefail` and `rg`-first scanning.
- The script scans `lib/rindle/` only and fails on:
  - `System.shell/2`
  - `:os.cmd/1`
  - raw `Port.open/2`
  - string-interpolated `ffmpeg` / `ffprobe` argv strings
- Wired the script into the `contract` CI job as a dedicated named step.
- Replaced the stale adopter docs grep with a Phase-28 AV onboarding parity step that requires `README.md` and `guides/getting_started.md` to stay on:
  - `mix rindle.doctor`
  - `Rindle.Profile.Presets.Web`
  - `Rindle.initiate_upload`
  - `Rindle.verify_completion`
  - `Rindle.attach`
  - `Rindle.url`
  - and rejects stale `Broker.*` / `Rindle.Delivery.url` onboarding calls

## Verification

Passed:

```bash
mix test test/rindle/doctor_test.exs
mix rindle.doctor Rindle.Adopter.CanonicalApp.Profile Rindle.Adopter.CanonicalApp.VideoProfile
bash scripts/assert_av_hygiene.sh
```

Observed results:

- `mix test test/rindle/doctor_test.exs`: 3 tests, 0 failures
- `mix rindle.doctor ...`: FFmpeg OK; canonical image profile OK (`variants checked: 0`); canonical video profile OK (`variants checked: 2`)
- `bash scripts/assert_av_hygiene.sh`: `OK: AV hygiene gate passed for /Users/jon/projects/rindle/lib/rindle`

Additional local parity check passed for the new CI docs step against `README.md` and `guides/getting_started.md`.

## Commits

- `f7b1861` — `test(28-02): add failing doctor profile gate tests`
- `05e4402` — `feat(28-02): gate AV runtime with public doctor task`
- `7a1cb0c` — `feat(28-02): add AV hygiene ship gate`

## Deviations

### Rule 3 - Blocking Issue

- `mix rindle.doctor Rindle.Adopter.CanonicalApp.Profile ...` initially failed outside `MIX_ENV=test` because the canonical fixture profiles live under `test/adopter/`.
- Fixed by teaching the public doctor task to load requested profile modules from repo source when they are not already compiled, which preserves the public Mix task entrypoint required by the plan and keeps CI out of private internals.

## Known Stubs

None.
