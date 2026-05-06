# Phase 28 Plan 03 Summary

## Outcome

Locked the final AV onboarding proof to a realistic smartphone-source adopter lane:

- `test/adopter/canonical_app/lifecycle_test.exs` now drives the stock
  `Rindle.Profile.Presets.Web` story through a two-fixture matrix using public
  `Rindle.initiate_upload/2`, `Rindle.verify_completion/2`, and `Rindle.url/3`
  calls around the real MinIO/Postgres harness.
- `test/support/fixtures/smartphone/` now contains the narrow committed proof
  set:
  - `portrait_rotation.mov` — QuickTime MOV with rotation side-data
  - `android_capture.webm` — WebM/VP9 + Opus capture from a second
    container/codec family
- The canonical adopter AV profile remains rooted in
  `Rindle.Profile.Presets.Web`, and the focused preset test now locks the same
  `web_720p` + `poster` + `video/mp4` / `video/quicktime` / `video/webm`
  onboarding posture the adopter lane proves end to end.

## Verification

Passed:

```bash
mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs --warnings-as-errors
mix test test/rindle/profile/presets_web_test.exs --warnings-as-errors
mix test test/rindle/profile/presets_web_test.exs test/adopter/canonical_app/lifecycle_test.exs --warnings-as-errors --include adopter
```

Observed results:

- `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs --warnings-as-errors`
  → `7 tests, 0 failures`
- `mix test test/rindle/profile/presets_web_test.exs --warnings-as-errors`
  → `5 tests, 0 failures`
- Combined plan-task verification
  → `12 tests, 0 failures`

## Commits

- `b6474e5` — `test(28-03): add failing smartphone adopter proof`
- `5737ac3` — `feat(28-03): prove smartphone AV lifecycle in adopter lane`
- `fbedd8c` — `test(28-03): add failing stock preset contract coverage`
- `3224a4e` — `feat(28-03): align stock preset contract with adopter AV story`

## Deviations

### Rule 3 - Blocking Issue

- The canonical adopter video profile originally allowed only `video/mp4`,
  which blocked the plan-mandated MOV/WebM smartphone matrix from ever passing.
- Fixed by widening `Rindle.Adopter.CanonicalApp.VideoProfile` to the same
  public onboarding MIME set already taught in `README.md` and
  `guides/getting_started.md`: `video/mp4`, `video/quicktime`, and
  `video/webm`.

## Known Stubs

None.
