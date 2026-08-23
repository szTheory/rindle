# Phase 126: Curated Type Ratchet — Pattern Map

## Scope and acceptance boundary

TYPE-01 is the Elixir 1.17 / OTP 27 home cell, not the local host toolchain. TYPE-02 keeps the existing Nightly Dialyzer job genuinely gating; SAFE-01 limits changes to typespec/control-flow precision and the curated ignore baseline—never product behavior, schemas, migrations, telemetry, error shapes, or release topology.

## Existing ownership and validation patterns

| Warning category / target | Closest existing pattern | Safest seam | Behavior tests to retain |
|---|---|---|---|
| `call_without_opaque` — `lib/rindle.ex`, `upload/broker.ex`, `workers/promote_asset.ex` | Public facade delegates and broker lifecycle contracts | Tighten types at the producer/consumer boundary; do not unwrap opaque Ecto/Oban values to silence Dialyzer | `test/rindle/convenience_api_test.exs`, `test/rindle/upload/broker_test.exs`, `test/rindle/workers/promote_asset_test.exs` |
| Migration no-return/call warnings — `migration.ex`, `migration/v1.ex`, host fixtures | `Rindle.Migration` public API with generated-app migration proof | Add explicit specs or narrow dispatcher result types; preserve generated host-Oban vs pinned-Rindle ownership | `test/rindle/migration_test.exs`, `migration_fast_test.exs`, generated-app migration contract/smoke tests |
| Storage stream/callback warnings — `storage/local.ex`, `storage/s3.ex`, `storage/gcs/client.ex` | Adapter behaviour/capability matrix and Local/S3/GCS tests | Correct stream callback/typespec contracts at adapter edges; never weaken runtime validation or turn streamed errors into raises | `test/rindle/storage/{local,s3,gcs,storage_adapter}_test.exs`, tus variants |
| Pattern-match warnings — process/promote workers, runtime checks, admin actions, mux workers | Explicit tagged worker result handling and error-shape tests | Make currently reachable clauses/type unions agree, or remove genuinely unreachable private clauses only after tests prove parity | respective worker tests; `ops/runtime_checks_streaming_test.exs`; Mux provider tests |
| Tus opaque/pattern warnings — `upload/tus_plug.ex` | Tus protocol boundary and LiveView upload tests | Preserve crypto hash-state opacity; introduce opaque-safe helper/spec instead of inspecting implementation state | `test/rindle/upload/tus_plug_test.exs`, `test/rindle/live_view_test.exs` |
| Existing description-strict ignore entries | `.dialyzer_ignore.exs` v0.4.1 baseline comments | Retire one exact `{file, warning-description}` entry only when its home-cell warning is absent; do not add file-wide ignores | Home-cell `mix dialyzer --format github` |

## Files that must remain unchanged

- `priv/repo/migrations/**`, schemas, and generated migration semantics.
- Public API/docs, telemetry events/metadata, CI/release workflow topology and `CI Summary` requirements.
- `.planning/phases/125-behavioral-test-support/125-VERIFICATION.md` (untracked preservation artifact).
- The Nightly home-cell identity (`Elixir 1.17`, `OTP 27`), PLT cache key ingredients, and the absence of `continue-on-error` on Dialyzer.

## Curated-gate contract

`mix.exs` already owns Dialyxir configuration (`priv/plts/dialyzer.plt`, optional-app PLT additions, and `.dialyzer_ignore.exs`). `.github/workflows/nightly.yml` owns the gating home-cell execution: restore/build/save PLT then `mix dialyzer --format github` with no `continue-on-error`. Phase work should modify those files only when needed to make the baseline explicit and enforced; do not move Dialyzer to PR CI.

## Exact validation commands

1. Home-cell-equivalent analysis: `MIX_ENV=test mix dialyzer --format github` (use Elixir 1.17 / OTP 27 authority, not local noise).
2. PLT cold path when required: `MIX_ENV=test mix dialyzer --plt` then the analysis command.
3. Targeted behavior suites for each changed boundary (see table), plus `bash scripts/maintainer/refactor_contract.sh` for SAFE-01.
4. Static workflow review: verify `nightly.yml` retains literal `otp27-elixir1.17`, hashes `mix.exs`, `mix.lock`, and `.dialyzer_ignore.exs`, and executes gating `mix dialyzer --format github`.

## Planning guidance

Treat each ignore entry as debt with a named source/test owner. Start with a tracer that proves the supported home-cell baseline and validates strict ignore specificity; then retire warning groups by cohesive type boundary. Do not use unsupported local Dialyzer output to create or preserve ignores.
