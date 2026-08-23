---
phase: 126-curated-type-ratchet
plan: "01"
status: started
implementation_base_sha: 8d988841eff238f28489cc81b91c8a73d7f215bc
starting_ignore_sha256: e2bf046eee6723f35fb8f03009386696f9ef513f660386159f7bc2b119e2873f
starting_entries: 45
starting_owners: 18
legacy_atom_filters: 8
strict_description_filters: 37
supported_authority: Nightly Dialyzer on Elixir 1.17 / OTP 27
---

# Phase 126 Type Evidence Ledger

This is the immutable starting receipt for the curated Dialyzer baseline. Local
Dialyzer output (including the workstation's Elixir 1.19 / OTP 28 output) is
diagnostic only and must never create, remove, or justify a filter. Acceptance
authority is the exact-head `Nightly` `Dialyzer` job on Elixir 1.17 / OTP 27.

## Starting Inventory

`implementation_base_sha` is the repository head before this policy tracer.
`starting_ignore_sha256` is SHA-256 over the unmodified `.dialyzer_ignore.exs`
bytes. The inventory is 45 entries over 18 owner files: 8 closed historical
atom filters and 37 exact description filters.

| ID | Owner | Discriminator |
| --- | --- | --- |
| E01 | `lib/rindle.ex` | `:call_without_opaque` |
| E02 | `lib/rindle/upload/broker.ex` | `:call_without_opaque` |
| E03 | `lib/rindle/workers/promote_asset.ex` | `:call_without_opaque` |
| E04 | `lib/rindle/html.ex` | `:pattern_match` |
| E05 | `lib/rindle/ops/runtime_status.ex` | `:pattern_match_cov` |
| E06 | `lib/rindle/workers/process_variant.ex` | `:pattern_match` |
| E07 | `lib/rindle/workers/process_variant.ex` | `:pattern_match_cov` |
| E08 | `lib/rindle/workers/promote_asset.ex` | `:pattern_match_cov` |
| E09 | `lib/mix/tasks/rindle.batch_owner_erasure.ex` | `The function call message will not succeed.` |
| E10 | `lib/rindle/admin/live/actions_live.ex` | `The pattern pattern {'error', _} can never match the type, because it is covered by previous clauses.` |
| E11 | `lib/rindle/migration.ex` | `Function up/0 has no local return.` |
| E12 | `lib/rindle/migration.ex` | `Function up/1 has no local return.` |
| E13 | `lib/rindle/migration.ex` | `Function down/0 has no local return.` |
| E14 | `lib/rindle/migration.ex` | `Function down/1 has no local return.` |
| E15 | `lib/rindle/migration.ex` | `The function call move_public_to_rindle will not succeed.` |
| E16 | `lib/rindle/migration.ex` | `Function move_public_to_rindle/0 has no local return.` |
| E17 | `lib/rindle/migration.ex` | `The function call move_rindle_to_public will not succeed.` |
| E18 | `lib/rindle/migration.ex` | `Function move_rindle_to_public/0 has no local return.` |
| E19 | `lib/rindle/migration.ex` | `The function call up will not succeed.` |
| E20 | `lib/rindle/migration.ex` | `Function dispatch/2 has no local return.` |
| E21 | `lib/rindle/migration.ex` | `The function call down will not succeed.` |
| E22 | `lib/rindle/migration/v1.ex` | `Function raise_preflight_error!/1 has no local return.` |
| E23 | `lib/rindle/migration/v1.ex` | `The pattern can never match the type :database_create_denied | :mixed_state | :public_incomplete | :public_marker_invalid | :public_not_empty | :public_unusable | :rindle_incomplete | :rindle_marker_invalid | :rindle_not_empty | :rindle_unusable | :source_not_owned .` |
| E24 | `lib/rindle/ops/runtime_checks.ex` | `The pattern can never match the type :ok | {:already, :allowed | :owner}.` |
| E25 | `lib/rindle/storage/gcs/client.ex` | `The function call stream! will not succeed.` |
| E26 | `lib/rindle/storage/gcs/client.ex` | `The pattern can never match the type :resumable_upload, _, _, Keyword.t().` |
| E27 | `lib/rindle/storage/gcs/client.ex` | `The pattern pattern {'error', __other@1} can never match the type, because it is covered by previous clauses.` |
| E28 | `lib/rindle/storage/local.ex` | `Function upload_part_stream/5 has no local return.` |
| E29 | `lib/rindle/storage/local.ex` | `The function call stream! will not succeed.` |
| E30 | `lib/rindle/storage/local.ex` | `The created anonymous function has no local return.` |
| E31 | `lib/rindle/storage/s3.ex` | `The pattern can never match the type {:error, atom()}.` |
| E32 | `lib/rindle/storage/s3.ex` | `The function call stream! will not succeed.` |
| E33 | `lib/rindle/storage/s3.ex` | `Function drain_tail_parts/7 will never be called.` |
| E34 | `lib/rindle/storage/s3.ex` | `Function read_leading_part/1 will never be called.` |
| E35 | `lib/rindle/storage/s3.ex` | `Function truncate_tail_head/2 will never be called.` |
| E36 | `lib/rindle/storage/s3.ex` | `Function open_rest/2 will never be called.` |
| E37 | `lib/rindle/storage/s3.ex` | `Function copy_rest/2 will never be called.` |
| E38 | `lib/rindle/upload/tus_plug.ex` | `The pattern can never match the type {:error, _}.` |
| E39 | `lib/rindle/upload/tus_plug.ex` | `The guard test _@1::'nil' | crypto:hash_state() breaks the opaqueness of its argument.` |
| E40 | `lib/rindle/upload/tus_plug.ex` | `The guard clause can never succeed.` |
| E41 | `lib/rindle/workers/mux_ingest_variant.ex` | `The pattern pattern <__mux_response@1, __reason@1> can never match the type, because it is covered by previous clauses.` |
| E42 | `lib/rindle/workers/mux_sync_provider_asset.ex` | `The pattern variable _err@2 can never match the type, because it is covered by previous clauses.` |
| E43 | `test/support/host_rindle_migration.ex` | `Function up/0 has no local return.` |
| E44 | `test/support/host_rindle_migration.ex` | `Function down/0 has no local return.` |
| E45 | `test/support/host_rindle_migration.ex` | `Function install!/0 has no local return.` |

## Disposition Protocol

Every entry begins `pending`. It can transition only to `obsolete`,
`actionable-fixed`, or `retained-analyzer-noise` after this row records all of:
the supported-run URL, `Dialyzer` job identity, exact warning text, focused
owner test command, and SAFE-01 result. A status without every receipt field is
invalid evidence.

| IDs | Status | Supported run URL | Job identity | Exact warning | Owner test command | SAFE-01 |
| --- | --- | --- | --- | --- | --- | --- |
| E01–E45 | pending | pending | pending | inventory value above | pending | pending |

## Supported Policy-Tracer Receipt

Pending Task 2. The receipt must bind the pushed policy-tracer SHA to the
workflow-dispatch run's `headSha`, record both `Dialyzer` and `Nightly Summary`,
and state the Elixir 1.17 / OTP 27 home cell identity.
