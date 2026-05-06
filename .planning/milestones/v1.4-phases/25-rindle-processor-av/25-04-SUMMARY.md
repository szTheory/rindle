# Phase 25 Plan 04 Summary

## Outcome

Plan `25-04` shipped the audio-output half of `Rindle.Processor.AV` and froze
the waveform contract.

- `Rindle.Processor.AV` now dispatches preset-led audio and waveform variants.
- `lib/rindle/processor/av/audio.ex` produces real AAC/m4a and MP3 outputs,
  supports optional channel reduction, uses single-pass `loudnorm` by default
  when `normalize: true`, and takes the explicit two-pass branch only when
  `two_pass: true`.
- `lib/rindle/processor/waveform.ex` emits exactly `%{length, sample_rate,
  peaks}` JSON for the `:overview` waveform preset and fails with
  `:missing_audio_track` for silent video inputs.
- `Rindle.Profile.Validator` now narrows the public waveform DSL to the
  preset-owned `:overview` surface and rejects extra waveform tuning knobs.

## Files Changed

- `lib/rindle/processor/av.ex`
- `lib/rindle/processor/av/audio.ex`
- `lib/rindle/processor/waveform.ex`
- `lib/rindle/profile/validator.ex`
- `test/rindle/processor/av_test.exs`
- `test/rindle/processor/waveform_test.exs`
- `test/rindle/profile/validator_test.exs`

## Verification

Executed:

```sh
mix test test/rindle/processor/av_test.exs
mix test test/rindle/processor/waveform_test.exs test/rindle/profile/validator_test.exs
mix test test/rindle/processor/av_test.exs test/rindle/processor/waveform_test.exs test/rindle/profile/validator_test.exs
```

Result:

- `13` AV processor tests passed.
- `24` waveform + validator tests passed.
- `37` owned verification tests passed together.

## Commits

- `f93b9ad` `test(25-04): add failing audio and waveform coverage`
- `ff32c65` `feat(25-04): implement preset audio transcodes`
- `6f95723` `feat(25-04): freeze waveform contract`

## Decisions

- Kept audio processing preset-led only; no raw codec/container/filter
  passthrough was added.
- Kept waveform public configuration at `preset: :overview` only.
- Fixed the waveform analysis rate internally at `8000` Hz so the emitted JSON
  stays bounded and deterministic without widening the public API.

## Deviations

None. The plan was implemented within the owned surface without changing
`STATE.md` or `ROADMAP.md`.
