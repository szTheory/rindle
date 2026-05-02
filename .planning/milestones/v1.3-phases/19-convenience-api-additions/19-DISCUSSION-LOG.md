# Phase 19: Convenience API Additions - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `19-CONTEXT.md` — this log preserves the analysis.

**Date:** 2026-04-30
**Phase:** 19-convenience-api-additions
**Mode:** assumptions (research-driven one-shot per saved feedback memory)
**Areas analyzed:** `attachment_for/2` semantics, `ready_variants_for/1` semantics, bang variant convention + error semantics, specs/docs/tests/plan-slicing
**Subagents spawned (parallel):** `gsd-assumptions-analyzer` (codebase), `general-purpose` × 2 (Elixir bang idioms; cross-language helper patterns)

## Assumptions Presented

### `attachment_for/2` semantics

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Returns `MediaAttachment.t() \| nil` (not tagged tuple) | Confident | `Repo.get_by/2` precedent; Shrine / Spatie return nil; Active Storage proxy pattern widely cited as footgun |
| Auto-preloads `:asset` by default | Likely (resolved via cross-language research) | Active Storage N+1 issues (Rails #46770); join row alone is inert; helper's stated purpose is rendering |
| 3-arity with `opts` keyword for `:preload` override | Confident | `Ecto.Repo.get/3` keyword opts idiom |
| Owner identification reuses existing `get_owner_info/1` | Confident | `lib/rindle.ex:284-286` already used by `attach/4` and `detach/3` |
| Multi-row tie-break by `inserted_at desc` | Confident | Matches existing `attach/4` last-write-wins replacement semantics |

### `ready_variants_for/1` semantics

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Returns `[MediaVariant.t()]` empty-list-on-none | Confident | `Repo.all/1` ecosystem convention; existing internal queries at `lib/rindle/workers/purge_storage.ex:17` |
| State filter `"ready"` only | Confident | `lib/rindle/delivery.ex:146-149` confirms only `"ready"` returns variant URL directly |
| Accepts `%MediaAsset{}` OR binary id | Likely | Mirrors `get_asset_id/1` polymorphism at `lib/rindle.ex:281-282` |
| Order by `:name` ascending | Likely | Stable doctest order; matches `(asset_id, name)` unique constraint |
| No fallback to original asset URL | Confident | Spatie's `getAvailableUrl` fallback widely cited as hiding processing failures |

### Bang variant convention + error semantics

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Define `Rindle.Error` (single exception module) | Likely (chosen over codebase analyzer's "no new module" alternative) | File.Error / ExAws.Error / Oban precedents; strictly additive (no Phase 17 D-08 violation); structured rescue ergonomics |
| Reuse `Ecto.InvalidChangesetError` for changeset failures | Confident | Direct Oban `insert!/3` precedent (`deps/oban/lib/oban.ex:686-687`) |
| Re-raise underlying exception for `{:storage_adapter_exception, _}` | Confident | Preserves debuggability; existing 2-arity tuple unchanged (Phase 17 D-08) |
| Thin wrapper over non-bang (no duplicated logic) | Confident | Universal Elixir convention (Ecto, Oban, File, Req, ExAws) |
| Bang return shapes unwrap success value | Confident | Ecto.Repo.insert!/2 / File.read!/1 / Oban.insert!/3 convention |
| Arity exactly mirrors non-bang | Confident | No surveyed lib breaks this rule |
| One-line `@doc` for bangs | Confident | Plug.Conn.inform!/3 precedent + `mix doctor` checks presence not depth (Phase 18 D-08) |
| `@spec` returns success type only (no `no_return()`) | Confident | Universal ecosystem convention |

### Specs, docs, tests, and plan slicing

| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| All 8 new functions get full `@doc` + `@spec` | Confident | Phase 18 D-07 thresholds 100/100/100/95/95 |
| Use named schema types (`MediaAttachment.t()`, etc.) not `storage_result` | Confident | Phase 18 D-03 / D-05; existing `@type t` already defined for all five domain schemas |
| Tests in `test/rindle/convenience_api_test.exs` | Confident | Reuses existing `defmodule User do defstruct [:id] end` pattern from `test/rindle/attach_detach_test.exs:19-21` |
| 2 plans (RED harness + GREEN impl) | Confident | Phase 17 P01 / Phase 18 P01 RED-harness rhythm; mechanical add-functions work fits 2-plan pattern |
| Defensive split clause if 19-02 spans > 6 files | Confident | Phase 18 D-25 precedent; default is single 19-02 |

## Corrections Made

No user corrections. The user selected "Yes, proceed (Recommended)" on the single confirmation question. All locked decisions stand as presented.

## Conflicts Resolved Internally

Three subagent recommendations conflicted; resolved with documented rationale before presenting to user:

1. **Exception module (D-11):** codebase analyzer recommended generic `RuntimeError`; bang-idioms research recommended `Rindle.Error`. Chose `Rindle.Error` based on overwhelming ecosystem precedent (File.Error, ExAws.Error, Oban's mixed approach reusing `Ecto.InvalidChangesetError`). Codebase analyzer's "scope creep" objection was dismissed because the new module is strictly additive and Phase 17 D-08 only forbids breaking changes on `0.1.x`.
2. **Auto-preload `:asset` (D-02):** codebase analyzer recommended no auto-preload (`Repo.get_by`-style); cross-language research recommended auto-preload (Active Storage N+1 lessons). Chose auto-preload because the helper's stated use case (API-09: "fetch an attachment without writing a raw Ecto query") is rendering, not existence-checking, and the join row alone is inert.
3. **`:storage_adapter_exception` tuple shape (D-13):** bang-idioms research recommended evolving to a 3-arity tuple to preserve stacktraces for `reraise`. Rejected — that would break adopters pattern-matching the existing 2-arity tuple (Phase 17 D-08 violation). Chose `raise exception` at the bang call site (fresh stacktrace) as an acceptable compromise.

## External Research

External research was performed by two parallel `general-purpose` subagents and merged into the assumption set above. No further research was needed beyond what those subagents surfaced.

**Key findings used to lock decisions:**
- Bang variant: thin-wrapper pattern is universal; success-type-only `@spec` is universal; one-line `@doc` is doctor-acceptable.
- Helper APIs: nil-on-empty + auto-preload-the-related-record is the cross-language consensus; lazy / never-nil / fallback-to-original are widely-cited footguns.
- Doctor coverage: only checks doc presence, not depth — confirmed by reading `deps/doctor/lib/reporters/module_explain.ex:203-211` (carried from Phase 18 research).

## Auto-Resolved

Not applicable — no Unclear assumptions; --auto was not used.
