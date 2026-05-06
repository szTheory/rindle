# Phase 25 Plan 01 Summary

## Outcome

Established `Rindle.Processor.AV` as the public preset-led AV seam, added canonical recipe normalization, narrowed the compile-time AV DSL surface, and preserved image digest stability while making AV digests normalize before hashing.

## Completed Work

- Added `Rindle.Processor.AV` with `capabilities/0`, `normalize/1`, `normalize!/1`, and preset-led `process/3`.
- Added `Rindle.Processor.AV.Recipe` to canonicalize video, audio, and waveform recipes and reject unsupported raw passthrough keys.
- Reduced `Rindle.Processor.Ffmpeg` to a compatibility wrapper for non-legacy preset-led AV calls while preserving its legacy capability-based path.
- Narrowed `Rindle.Profile.Validator` so AV variants compile on the flat DSL with `preset` as the public knob and only the approved override envelope.
- Updated `Rindle.Profile.Digest` to hash canonical AV recipes while preserving the existing image digest path.
- Added AV boundary tests, validator/digest normalization tests, and backward-compat coverage proving AV siblings do not perturb the v1.3 image snapshot.

## Verification

- `mix test test/rindle/processor/av_test.exs`
- `mix test test/rindle/profile/validator_test.exs test/rindle/backward_compat/v13_digest_snapshot_test.exs`
- `mix test test/rindle/processor/av_test.exs test/rindle/profile/validator_test.exs test/rindle/backward_compat/v13_digest_snapshot_test.exs`

All scoped plan verification passed.

## Commits

- `a0e643f` `test(25-01): add failing av boundary tests`
- `84f2dbe` `feat(25-01): add av processor boundary`
- `64d320b` `test(25-01): add failing av validator and digest tests`
- `773c039` `feat(25-01): normalize av recipes in validator and digest path`

## Deviations

None.
