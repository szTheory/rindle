# Phase 25 Plan 05 Summary

Implemented AV runtime hardening in the owned worker path: centralized FFmpeg cap overrides, runtime admission checks, post-process output verification before upload/ready, and a dedicated recursive `Rindle.tmp/` sweeper with orphan-count telemetry.

## Scope Completed

- Added `Rindle.Processor.AV.RuntimeGuard` for:
  - `2 x max_output_bytes` disk headroom enforcement
  - unsupported ephemeral runtime refusal for video work
  - explicit unsupported-runtime warning helper for AV-capable profiles
- Added `Rindle.Processor.AV.OutputProbe` and wired it into `ProcessVariant` before upload/ready promotion.
- Hardened `Rindle.AV.Subprocess` so FFmpeg cap values remain centralized but can be overridden per invocation.
- Wired `Rindle.Application.start/2` through a boot-time startup check that discovers configured Rindle profile modules and emits the unsupported-runtime warning before jobs enqueue.
- Updated `ProcessVariant` to:
  - run runtime admission checks before AV processing
  - dispatch already-normalized AV specs directly to the underlying AV processors
  - persist verified output metadata on ready variants
- Updated `PromoteAsset` to preserve the enqueue-time warning path while boot-time startup checks cover the stricter plan contract.
- Added `Rindle.Ops.SweepOrphanedTempFiles` as a dedicated recursive AV temp sweeper with `[:rindle, :media, :sweep_orphans, :stop]` telemetry including orphan count.
- Added startup-warning coverage in `test/rindle/application_test.exs` and fixed `RuntimeGuard.warn_unsupported_runtime/2` so it recognizes real profile `variants/0` tuple entries.

## Verification

Command:

```sh
mix test test/rindle/av/subprocess_test.exs test/rindle/workers/process_variant_test.exs test/rindle/processor/av_runtime_guard_test.exs test/rindle/ops/sweep_orphaned_temp_files_test.exs
```

Result: `21 tests, 0 failures`

## Commits

- `71ccc50` `test(25-05): add failing AV runtime safety coverage`
- `0f45fd5` `feat(25-05): harden AV runtime admission and output verification`
- `eed280f` `feat(25-05): add dedicated AV temp sweeper`
- `f9cd67d` `fix(25-05): warn on unsupported runtimes at boot`

## Deviations

None.

## Changed Files

- `lib/rindle/av/subprocess.ex`
- `lib/rindle/application.ex`
- `lib/rindle/config.ex`
- `lib/rindle/processor/av/output_probe.ex`
- `lib/rindle/processor/av/runtime_guard.ex`
- `lib/rindle/profile.ex`
- `lib/rindle/workers/process_variant.ex`
- `lib/rindle/workers/promote_asset.ex`
- `lib/rindle/ops/sweep_orphaned_temp_files.ex`
- `test/rindle/application_test.exs`
- `test/rindle/av/subprocess_test.exs`
- `test/rindle/workers/process_variant_test.exs`
- `test/rindle/ops/sweep_orphaned_temp_files_test.exs`
- `test/rindle/processor/av_runtime_guard_test.exs`
