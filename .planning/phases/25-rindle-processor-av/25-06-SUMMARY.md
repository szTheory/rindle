# Phase 25 Plan 06 Summary

Stock AV contract closure for Phase 25: public `:media/:transcode` telemetry, bounded variant/asset progress broadcasts, and a reusable `Rindle.Profile.Presets.Web` onboarding story proved through the canonical adopter video lifecycle.

## Completed Work

- Froze the public AV telemetry family at `[:rindle, :media, :transcode, :start | :stop | :exception]` with contract coverage for event names, measurements, and metadata shape.
- Added explicit PubSub progress fan-out from `Rindle.Workers.ProcessVariant` to both `rindle:variant:#{variant_id}` and `rindle:asset:#{asset_id}` with bounded start/final updates.
- Added the public `Rindle.Profile.Presets.Web` module with the explicit `web_720p` + `poster` story and opt-in `scrub_strip`.
- Extended the canonical adopter fixtures to consume the stock preset and proved the video/poster round-trip through the MinIO-backed lifecycle test.

## Verification

- `mix test test/rindle/contracts/telemetry_contract_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/workers/process_variant_test.exs --include contract`
- `mix test test/rindle/profile/presets_web_test.exs test/adopter/canonical_app/lifecycle_test.exs test/rindle/api_surface_boundary_test.exs --include adopter`
- `mix test test/rindle/contracts/telemetry_contract_test.exs test/rindle/api_surface_boundary_test.exs test/rindle/workers/process_variant_test.exs test/rindle/profile/presets_web_test.exs test/adopter/canonical_app/lifecycle_test.exs --include contract --include adopter`

## Deviations

- Added `{Phoenix.PubSub, name: Rindle.PubSub}` to [lib/rindle/application.ex](/Users/jon/projects/rindle/lib/rindle/application.ex) so the public AV progress topics exist at runtime instead of only in tests.
- Extended [lib/rindle/profile/validator.ex](/Users/jon/projects/rindle/lib/rindle/profile/validator.ex) to accept explicit AV image presets (`:video_poster_scene`, `:video_thumbnail_strip`), which was required for the documented `poster` story to compile through `use Rindle.Profile`.
- Extended [lib/rindle/processor/av.ex](/Users/jon/projects/rindle/lib/rindle/processor/av.ex) to normalize AV image presets from `:preset` alone, preserving the existing image digest behavior while routing poster/strip variants through the AV processor path.

## Commits

- `8865aef` `test(25-rindle-processor-av-06): add failing AV contract coverage`
- `4d02ade` `feat(25-rindle-processor-av-06): freeze AV telemetry and progress contract`
- `7cbf726` `test(25-rindle-processor-av-06): add failing stock preset coverage`
- `76b8dcb` `feat(25-rindle-processor-av-06): ship stock web preset and adopter proof`
