# Phase 25 Plan 05 Summary

Implemented AV runtime hardening in the owned worker path: centralized FFmpeg cap overrides, runtime admission checks, post-process output verification before upload/ready, and a dedicated recursive `Rindle.tmp/` sweeper with orphan-count telemetry.

## Scope Completed

- Added `Rindle.Processor.AV.RuntimeGuard` for:
  - `2 x max_output_bytes` disk headroom enforcement
  - unsupported ephemeral runtime refusal for video work
  - explicit unsupported-runtime warning helper for AV-capable profiles
- Added `Rindle.Processor.AV.OutputProbe` and wired it into `ProcessVariant` before upload/ready promotion.
- Hardened `Rindle.AV.Subprocess` so FFmpeg cap values remain centralized but can be overridden per invocation.
- Updated `ProcessVariant` to:
  - run runtime admission checks before AV processing
  - dispatch already-normalized AV specs directly to the underlying AV processors
  - persist verified output metadata on ready variants
- Updated `PromoteAsset` to emit the unsupported-runtime warning at AV enqueue time for AV-capable profiles.
- Added `Rindle.Ops.SweepOrphanedTempFiles` as a dedicated recursive AV temp sweeper with `[:rindle, :media, :sweep_orphans, :stop]` telemetry including orphan count.

## Verification

Command:

```sh
mix test test/rindle/av/subprocess_test.exs test/rindle/workers/process_variant_test.exs test/rindle/processor/av_runtime_guard_test.exs test/rindle/ops/sweep_orphaned_temp_files_test.exs
```

Result: `19 tests, 0 failures`

## Commits

- `71ccc50` `test(25-05): add failing AV runtime safety coverage`
- `0f45fd5` `feat(25-05): harden AV runtime admission and output verification`
- `eed280f` `feat(25-05): add dedicated AV temp sweeper`

## Deviations

- The unsupported-runtime warning was wired at the AV enqueue seam in [`lib/rindle/workers/promote_asset.ex`](/Users/jon/projects/rindle/lib/rindle/workers/promote_asset.ex) via `RuntimeGuard.warn_unsupported_runtime/2`, not at `Rindle.Application` boot. Reason: the boot supervisor file was outside the explicit owned change set for this execution.

## Changed Files

- `lib/rindle/av/subprocess.ex`
- `lib/rindle/processor/av/output_probe.ex`
- `lib/rindle/processor/av/runtime_guard.ex`
- `lib/rindle/workers/process_variant.ex`
- `lib/rindle/workers/promote_asset.ex`
- `lib/rindle/ops/sweep_orphaned_temp_files.ex`
- `test/rindle/av/subprocess_test.exs`
- `test/rindle/workers/process_variant_test.exs`
- `test/rindle/ops/sweep_orphaned_temp_files_test.exs`
- `test/rindle/processor/av_runtime_guard_test.exs`
