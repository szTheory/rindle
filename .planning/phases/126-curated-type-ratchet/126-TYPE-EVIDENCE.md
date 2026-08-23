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
the immutable starting tuple path/discriminator, any distinct supported emitted
path/message, the supported-run URL, `Dialyzer` job identity, focused owner test
command, and SAFE-01 result. A status without every receipt field is invalid
evidence. When extraction changes the emitted owner, the ledger preserves the
starting tuple identity and records a separate derived finding; it never rewrites
the starting inventory to make the paths appear identical.

| IDs | Status | Supported run URL | Job identity | Exact warning | Owner test command | SAFE-01 |
| --- | --- | --- | --- | --- | --- | --- |
| E01–E45 | pending | pending | pending | inventory value above | pending | pending |

## Supported Policy-Tracer Receipt

- Policy-tracer commit: `b3263d096071ff51912eb4f31bb8e5c9473b16c1`
- [Exact-head Nightly run 32637068060](https://github.com/szTheory/rindle/actions/runs/32637068060)
  (`workflow_dispatch`; `headSha` exactly equals the policy-tracer commit)
- Toolchain: Elixir 1.17.3, OTP 27.3.4.16, Ubuntu 22.04
- [Dialyzer job 97188327765](https://github.com/szTheory/rindle/actions/runs/32637068060/job/97188327765):
  **failure** (completed 2026-08-23T11:38:47Z)
- [Nightly Summary job 97188615049](https://github.com/szTheory/rindle/actions/runs/32637068060/job/97188615049):
  **success** (completed 2026-08-23T11:40:15Z); its `Dialyzer` row is `failure`.

This is an authority/topology receipt, not an acceptance-green claim. With the
starting suppressions unchanged, the job reported 46 errors, skipped 43, and
emitted the following exact remaining warnings:

1. `The pattern can never match the type {:error, _}.`
2. `The guard clause can never succeed.`
3. `The guard test _@1::'nil' | crypto:hash_state() breaks the opaqueness of its argument.`

The warning texts correspond to the three immutable E38–E40 discriminators, but
the supported annotations do **not** use their starting `tus_plug.ex` paths. The
extracted identities are E38 text at `lib/rindle/upload/tus_creation.ex` and
E39–E40 text at `lib/rindle/upload/tus_stream.ex`. E38–E40 remain `pending` as
starting filter identities, and Plan 126-07 owns the separately recorded derived
findings at the emitted paths. It must determine whether the original
`tus_plug.ex` tuples are obsolete while correcting or explicitly retaining the
actual creation/stream findings; neither identity may erase the other.

| Starting ID | Immutable filter path | Supported emitted path | Warning discriminator | Derived owner status |
| --- | --- | --- | --- | --- |
| E38 | `lib/rindle/upload/tus_plug.ex` | `lib/rindle/upload/tus_creation.ex` | `The pattern can never match the type {:error, _}.` | pending Plan 126-07 disposition |
| E39 | `lib/rindle/upload/tus_plug.ex` | `lib/rindle/upload/tus_stream.ex` | `The guard test _@1::'nil' \| crypto:hash_state() breaks the opaqueness of its argument.` | pending Plan 126-07 disposition |
| E40 | `lib/rindle/upload/tus_plug.ex` | `lib/rindle/upload/tus_stream.ex` | `The guard clause can never succeed.` | pending Plan 126-07 disposition |

## Supported Migration/Host Probe Receipt

- Probe commit: `f29f5b14e1834c8572c8e98fd4f05b78e4bed1c4`
- [Exact-head Nightly run 32637455725](https://github.com/szTheory/rindle/actions/runs/32637455725)
  (`workflow_dispatch`; `headSha` exactly equals the probe commit)
- Toolchain: Elixir 1.17.3, OTP 27.3.4.16, Ubuntu 22.04
- [Dialyzer job 97189240234](https://github.com/szTheory/rindle/actions/runs/32637455725/job/97189240234):
  **failure** (46 errors, 26 skipped)
- [Nightly Summary job 97189700144](https://github.com/szTheory/rindle/actions/runs/32637455725/job/97189700144):
  **success**; its `Dialyzer` row is `failure`.

The probe removed only E11–E23 and E43–E45 and made no `lib/` migration edit.
All 16 exact descriptions reproduced, so none is obsolete. They are candidate
findings only: local Elixir 1.19 / OTP 28 output is not used to classify them.

| IDs | Probe disposition | Exact supported observation |
| --- | --- | --- |
| E11–E14 | reproduced candidate | `Function up/0`, `up/1`, `down/0`, and `down/1` each have no local return. |
| E15–E21 | reproduced candidate | `move_public_to_rindle`, `move_rindle_to_public`, `up`, `down`, and `dispatch/2` each reproduce the exact call/no-local-return description in the starting inventory. |
| E22 | reproduced candidate | `Function raise_preflight_error!/1 has no local return.` |
| E23 | reproduced candidate | The starting preflight-refusal union description reproduced twice, once for each directional move. |
| E43–E45 | reproduced candidate | Host fixture `up/0`, `down/0`, and `install!/0` each have no local return. |

No candidate has left `pending`: a final `obsolete`, `actionable-fixed`, or
`retained-analyzer-noise` disposition still requires the focused owner tests
and SAFE-01 result specified by the ledger protocol.

## Final Migration Slice Receipt

- [Exact-head Nightly run 32640649625](https://github.com/szTheory/rindle/actions/runs/32640649625) for `bf8bc1bdcac96027b4ce7be337ac0fbfb4ca9dbe`
- [Dialyzer job 97197110357](https://github.com/szTheory/rindle/actions/runs/32640649625/job/97197110357): failure only for the three later-owned Tus annotations.
- [Nightly Summary job 97197608165](https://github.com/szTheory/rindle/actions/runs/32640649625/job/97197608165): success, `DIALYZER: failure`.
- Focused migration suites and `bash scripts/maintainer/refactor_contract.sh`: passed.

| IDs | Final status | Supported rationale |
| --- | --- | --- |
| E11–E21 | retained-analyzer-noise | Public Ecto.Migration callbacks and host transaction DSL have dynamic execution not statically modeled; API, DDL, transaction, and reversal contracts were preserved. |
| E22 | retained-analyzer-noise | `raise_preflight_error!/1` intentionally never returns; changing that would weaken the refusal path. |
| E23 | retained-analyzer-noise | Preflight’s directional exhaustive refusal patterns are intentionally narrower than the shared classifier’s atom result. |
| E43–E45 | retained-analyzer-noise | The host fixture is a real Ecto.Migration runner callback with dynamic lifecycle execution. |

## Supported Operational/Runtime Probe Receipt

- Probe commit: `7397e3791aa9fbad5b1292b06e76ddc654327c96`
- [Exact-head Nightly run 32640992583](https://github.com/szTheory/rindle/actions/runs/32640992583)
  (`workflow_dispatch`; `headSha` exactly equals the probe commit)
- [Dialyzer job 97197944599](https://github.com/szTheory/rindle/actions/runs/32640992583/job/97197944599):
  **failure** (completed 2026-08-23T13:03:46Z; 46 errors, 39 skipped)
- [Nightly Summary job 97198472813](https://github.com/szTheory/rindle/actions/runs/32640992583/job/97198472813):
  **success**; its `Dialyzer` row is `failure`.

Only E09, E10, and E24 were exposed for this source-unchanged probe. All four
owned annotations reproduced, including E09 twice at its two result-error
printing branches. The three later-owned TUS annotations also remained; no
other owner warning was emitted. These are candidate findings only: the local
Elixir 1.19 / OTP 28 result was not used to classify them.

| IDs | Probe disposition | Exact supported observation |
| --- | --- | --- |
| E09 | reproduced candidate | `The function call message will not succeed.` at `batch_owner_erasure.ex:112` and `:116`. |
| E10 | reproduced candidate | The exact covered `{'error', _}` pattern at `actions_live.ex:85`. |
| E24 | reproduced candidate | The exact `:ok | {:already, :allowed | :owner}` pattern at `runtime_checks.ex:294`. |

## Final Operational/Runtime Slice Receipt

- [Exact-head Nightly run 32641395080](https://github.com/szTheory/rindle/actions/runs/32641395080)
  for `19c53b2c37452ccaa0a0de685758cf0bfaf2feb0` (`workflow_dispatch`)
- [Dialyzer job 97198921550](https://github.com/szTheory/rindle/actions/runs/32641395080/job/97198921550):
  **failure**, with exactly three annotations, all later-owned E38–E40.
- [Nightly Summary job 97199446324](https://github.com/szTheory/rindle/actions/runs/32641395080/job/97199446324):
  **success**, explicitly recording `DIALYZER: failure`.
- Focused batch task/Admin/runtime-check suites and
  `bash scripts/maintainer/refactor_contract.sh`: passed.

| IDs | Final status | Supported rationale |
| --- | --- | --- |
| E09 | retained-analyzer-noise | Both facade result-error branches retain distinct task output and `{:shutdown, 1}` behavior; `Rindle.Error.message/1` accepts the behaviorally correct error map. |
| E10 | retained-analyzer-noise | The non-binary facade-error fallback preserves the existing Admin failure copy without narrowing reachable errors. |
| E24 | retained-analyzer-noise | Sandbox checkout can return `{:error, reason}` at runtime; retaining the branch preserves runtime diagnostics and error shapes. |

The exact final annotation multiset is E38 at
`lib/rindle/upload/tus_creation.ex:35`, E39 at
`lib/rindle/upload/tus_stream.ex:163`, and E40 at
`lib/rindle/upload/tus_stream.ex:66`. No operational, migration/support, or
unowned warning is emitted. This remains an intentionally red intermediate
Nightly result until Plan 126-07 owns the three TUS findings.

## Supported Runtime, HTML, and ProcessVariant Probe Receipt

- Probe commit: `f446e68c9dea5df27a4544fed2d7c9d8b65031d3`
- [Exact-head Nightly run 32642668846](https://github.com/szTheory/rindle/actions/runs/32642668846)
  (`workflow_dispatch`; `headSha` exactly equals the probe commit)
- [Dialyzer job 97202060703](https://github.com/szTheory/rindle/actions/runs/32642668846/job/97202060703):
  **failure** with eight warnings; [Nightly Summary job
  97202596326](https://github.com/szTheory/rindle/actions/runs/32642668846/job/97202596326)
  was **success** and recorded `DIALYZER: failure`.

Only E04-E07 were exposed on this source-unchanged probe. All four historical
filters reproduced alongside the three later-owned TUS warnings; no earlier or
unowned path appeared. The source owners were unchanged.

| IDs | Probe disposition | Exact supported observation |
| --- | --- | --- |
| E04 | reproduced candidate | `lib/rindle/html.ex:273`: `The pattern can never match the type binary().` |
| E05 | reproduced candidate | `lib/rindle/ops/runtime_status.ex:349` and `:350`: the `__reason@1` and `_reason@1` clauses are each covered by previous clauses. |
| E06 | reproduced candidate | `lib/rindle/workers/process_variant.ex:157`: `The pattern can never match the type {:error, _}.` |
| E07 | reproduced candidate | `lib/rindle/workers/process_variant.ex:449`: `The pattern variable __variant_spec@1 can never match the type, because it is covered by previous clauses.` |

## Final Runtime, HTML, and ProcessVariant Slice Receipt

- [Exact-head Nightly run 32642989666](https://github.com/szTheory/rindle/actions/runs/32642989666)
  for `82f8c557d4e32831ce4a0fa61160b35b35bc632d` (`workflow_dispatch`).
- [Dialyzer job 97202854464](https://github.com/szTheory/rindle/actions/runs/32642989666/job/97202854464):
  **failure** only for the three later-owned TUS annotations.
- [Nightly Summary job 97203393276](https://github.com/szTheory/rindle/actions/runs/32642989666/job/97203393276):
  **success**, explicitly recording `DIALYZER: failure`.
- Focused runtime-status/task/HTML/ProcessVariant suites (65 tests) and
  `bash scripts/maintainer/refactor_contract.sh` (92 contract tests): passed.

| IDs | Final status | Supported rationale |
| --- | --- | --- |
| E04 | retained-analyzer-noise | The `nil` MIME fallback is an intentional optional-integration safe path; removing it would change valid HTML helper output. |
| E05 | retained-analyzer-noise | Runtime-status accepts arbitrary refusal terms at its private telemetry boundary; the fallbacks preserve diagnostics and task/API failure behavior. |
| E06 | retained-analyzer-noise | ProcessVariant retains its cancel/error branch for dynamic processor outcomes, preserving lifecycle transitions, retry/discard behavior, telemetry, and error terms. |
| E07 | retained-analyzer-noise | The non-map fallback remains defensive for dynamic profile inputs; removing it would narrow worker behavior outside Dialyzer's inferred internal map flow. |

The complete final annotation multiset is E38 at
`lib/rindle/upload/tus_creation.ex:35`, E39 at
`lib/rindle/upload/tus_stream.ex:163`, and E40 at
`lib/rindle/upload/tus_stream.ex:66`. No runtime-status, HTML, ProcessVariant,
earlier, or unowned warning is emitted. This is an intentionally red
intermediate Nightly result until Plan 126-07 owns E38-E40.

## Supported GCS and Local Probe Receipt

- Probe commit: `634e817f7a6910802953faf4b5b178e9160058a7`; only the six
  strict E25–E30 filters were removed. `lib/rindle/storage/gcs/client.ex` and
  `lib/rindle/storage/local.ex` were unchanged.
- [Exact-head Nightly run 32643457947](https://github.com/szTheory/rindle/actions/runs/32643457947)
  (`workflow_dispatch`; `headSha` exactly equals the probe commit).
- [Dialyzer job 97203998038](https://github.com/szTheory/rindle/actions/runs/32643457947/job/97203998038):
  **failure** with ten warnings; [Nightly Summary job
  97204524549](https://github.com/szTheory/rindle/actions/runs/32643457947/job/97204524549)
  was **success** and recorded `DIALYZER: failure`.
- `MIX_ENV=test mix test test/install_smoke/dialyzer_ignore_policy_test.exs --seed 0`:
  passed (2 tests).

Only E25–E30 were exposed. Their seven emitted annotations reproduced beside
the three later-owned E38–E40 annotations; no earlier or unowned warning
appeared. The single strict Local `stream!` discriminator emits at both stream
call sites and is therefore one immutable filter identity with two supported
locations.

| IDs | Probe disposition | Exact supported observation |
| --- | --- | --- |
| E25 | reproduced candidate | `gcs/client.ex:78`: `The function call stream! will not succeed.` |
| E26 | reproduced candidate | `gcs/client.ex:396`: `The pattern can never match the type :resumable_upload, _, _, Keyword.t().` |
| E27 | reproduced candidate | `gcs/client.ex:431`: the exact covered `{'error', __other@1}` pattern. |
| E28 | reproduced candidate | `local.ex:88`: `Function upload_part_stream/5 has no local return.` |
| E29 | reproduced candidate | `local.ex:99` and `:140`: `The function call stream! will not succeed.` |
| E30 | reproduced candidate | `local.ex:136`: `The created anonymous function has no local return.` |
