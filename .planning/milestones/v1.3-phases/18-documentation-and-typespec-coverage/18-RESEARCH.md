# Phase 18: Documentation and Typespec Coverage - Research

**Researched:** 2026-04-30
**Domain:** Elixir documentation/typespec discipline; `mix doctor` configuration; named result-type design.
**Confidence:** HIGH (every numeric claim tagged with file:line; D-XX claims confirmed/flagged against locked CONTEXT.md).

## Summary

CONTEXT.md (`18-CONTEXT.md`) has 26 locked decisions (D-01 through D-26) gathered via assumptions
mode plus three parallel research subagents. This RESEARCH.md does not re-derive any decision; it
verifies the factual claims behind each (counts, line numbers, file existence), surfaces the
implementation-level details a planner needs (exact lines for every `@spec` to be added or tightened,
exact `@type` shapes for the named-result types, exact CI insertion point), and produces the Validation
Architecture the Nyquist downstream agent expects.

**Primary recommendation for the planner:** Take CONTEXT.md as locked input. Land Plan 18-01 to add
`{:doctor, "~> 0.22.0"}`, run `mix doctor.gen.config`, generate `.doctor.exs` at baseline, add the
`MIX_ENV=test mix doctor --full --raise` step to the `quality` job between lines 86 and 87 of
`.github/workflows/ci.yml`, and ship the failing `test/rindle/doctor_thresholds_test.exs` harness.
Plans 18-02 through 18-05 then ratchet — see the Per-File Implementation Sketch and Validation
Architecture sections below for exact mechanical guidance.

## Source-of-Truth Confirmation

For each locked decision in `18-CONTEXT.md`. Status legend: `CONFIRMED` (verified in code/file),
`FLAG` (factual claim incorrect or stale and planner must adjust), `NEEDS CLARIFICATION` (claim is
plausible but cannot be verified mechanically — planner judgment).

| ID | Status | Evidence |
|----|--------|----------|
| D-01 (public surface set) | CONFIRMED | All 22 modules in CONTEXT.md D-01 exist and match `test/rindle/api_surface_boundary_test.exs:5-30` `@public_modules` list. **GAP:** `Rindle.Processor.Image` has visible `@moduledoc """..."""` (`lib/rindle/processor/image.ex:2-4`) but is not in the D-01 public set or in the boundary test allowlist — see Risk Register R-1. |
| D-02 (coverage starting state) | CONFIRMED with refinement | `Rindle` facade has 20 `def` and 20 `@spec` (`lib/rindle.ex:34-484`); `Rindle.Delivery` is fully covered (`lib/rindle/delivery.ex:24-135`); all 5 schemas have `@type t` and `@spec changeset/2` (`lib/rindle/domain/*.ex`). **`Rindle.Upload.Broker` has 6 public `def`s and 0 `@spec`s** (`lib/rindle/upload/broker.ex:29,66,128,155,184,230`) — confirms "biggest gap." All 4 extension behaviours have `@callback`s without per-callback `@doc` (`authorizer.ex:9`, `analyzer.ex:9`, `scanner.ex:9`, `processor.ex:9`); `Rindle.Storage` has 11 `@callback` declarations, only `capabilities/0` carries a `@doc` (`storage.ex:71-76`). All 5 Mix tasks lack `@spec` on `run/1` (none present per grep). Both workers have rich `@moduledoc` and `@impl true` on `perform/1` but no `@doc`/`@spec` (`abort_incomplete_uploads.ex:71`, `cleanup_orphans.ex:65`). `Rindle.HTML.picture_tag/3` has `@spec` (`html.ex:12`) but no `@doc`. `Rindle.Profile.__using__/1` lacks `@doc`/`@spec` (`profile.ex:15`). |
| D-03 (named schema types in `Rindle` and `Rindle.Upload.Broker`) | CONFIRMED | 11 of `Rindle`'s 20 `@spec`s use `{:ok, map()}` / `{:ok, struct()}` / `storage_result()` (the `term()` alias). See "Named-types proposal" tables below for the per-function rewrite. |
| D-04 (behaviour-level `Rindle.Storage` result types) | CONFIRMED | `Rindle.Storage` declares 11 `@callback`s with `{:ok, map()}` or `{:ok, term()}` returns (`storage.ex:26-69`). `Rindle.Storage.Local` and `Rindle.Storage.S3` return concrete `%{key: ..., ...}` / `%{url: ..., method: ..., headers: ...}` shapes — see "`Rindle.Storage` named-result-types proposal" for the verified shapes. |
| D-05 (multi-key result aliases) | CONFIRMED | `Rindle.Upload.Broker.initiate_multipart_session/2` returns `%{session: ..., multipart: %{upload_id: ..., upload_key: ..., part_size: ..., part_headers: ...}}` (`broker.ex:97-105`). `Broker.sign_url/2` and `Broker.sign_multipart_part/3` return `%{session: ..., presigned: %{url: ..., method: ..., headers: ...}}` (`broker.ex:144`, `broker.ex:174`). `Broker.verify_completion/2` returns `%{session: ..., asset: ...}` (`broker.ex:291`). All four shapes need named module-level `@type` aliases. |
| D-06 (`{:doctor, "~> 0.22.0", only: [:dev, :test], runtime: false}`) | CONFIRMED | `doctor 0.22.0` is current stable on Hex.pm (verified via `https://hex.pm/api/packages/doctor`). `mix.exs:51-94` deps list shows the same `only: [:dev, :test], runtime: false` shape used for `:credo` and `:dialyxir` (lines 89-90), so `:doctor` lands cleanly. No `.doctor.exs` exists yet (verified via `ls`). |
| D-07 (final thresholds 100/100/100/95/95) | CONFIRMED as a target | Locked target stays. Plan 18-01 captures baseline; Plan 18-05 ratchets. See `## Validation Architecture` for the threshold-target test contract. |
| D-08 (`@moduledoc false` not auto-skipped, ignore_modules required) | CONFIRMED | Phase 17 D-05 hidden-module list verified by direct grep: 18 `lib/` files carry `@moduledoc false` (see "`.doctor.exs` ignore_modules inventory" below). |
| D-09 (`mix doctor --full --raise` is the canonical CI invocation) | CONFIRMED | `--raise` is belt-and-suspenders per CONTEXT.md research; `--full` is preferred over `--summary` for failure visibility in CI logs. |
| D-10 (CI insertion point in `quality` job between Credo and tests) | CONFIRMED | `.github/workflows/ci.yml:84-85` is the Credo step; line 87-88 is the tests step. The new step lands between them (after line 85 `mix credo --strict`, before line 87 `Run tests with coverage`). `MIX_ENV=test` is required because `Rindle.LiveView` (`live_view.ex:1`) and `Rindle.HTML` (`html.ex:1`) are wrapped in `if Code.ensure_loaded?(...) do` — without test deps, the modules don't compile and doctor would silently skip them. |
| D-11 (per-`@callback` `@doc` on behaviours) | CONFIRMED | All 5 behaviour modules have `@callback`s without `@doc` (except `Rindle.Storage.capabilities/0`); 11 + 1 + 1 + 1 + 1 = 15 callbacks total need per-callback `@doc`. |
| D-12 (Mix tasks: `@shortdoc` + `@moduledoc` + `@impl true` only — no `@doc`/`@spec` on `run/1`) | CONFIRMED | All 5 Mix tasks already follow this pattern: `@shortdoc` present (e.g. `rindle.abort_incomplete_uploads.ex:2`), rich `@moduledoc`, and `@impl Mix.Task` on `run/1` (e.g. `rindle.abort_incomplete_uploads.ex:43`). Plan 18-04 confirms the existing posture is correct — no edits required to satisfy D-12 itself; the `@impl` annotation already provides the contract. |
| D-13 (Oban workers: rich `@moduledoc`, drop `@doc` from `perform/1`) | CONFIRMED | Both workers already have rich `@moduledoc` (`abort_incomplete_uploads.ex:2-63`, `cleanup_orphans.ex:2-57`) and `@impl Oban.Worker` on `perform/1` (`abort_incomplete_uploads.ex:71`, `cleanup_orphans.ex:65`). Neither has `@doc` on `perform/1`. **D-13 says drop `@doc` — there is none to drop. The work in 18-04 is to add an optional `@spec perform(Oban.Job.t()) :: :ok | {:error, term()}` if the planner wants to narrow the behaviour-level return.** The current return values are `:ok` and `{:error, reason}`. |
| D-14 (`Rindle.Profile.__using__/1` doc + spec) | CONFIRMED | `lib/rindle/profile.ex:15` declares `defmacro __using__(opts)` with no preceding `@doc` and no `@spec`. The 6 generated functions inside the `quote` block (lines 39-67) already have `@spec`. |
| D-15 (`Rindle.HTML.picture_tag/3` `@doc`) | CONFIRMED | `lib/rindle/html.ex:12` has `@spec picture_tag(module(), map(), keyword()) :: Phoenix.HTML.safe()` and no `@doc`. |
| D-16 (`Rindle.log_variant_processing_failure/3` shim with `@deprecated` + `@doc false` + `@spec`) | CONFIRMED | `lib/rindle.ex:482-484` already has `@doc false` and `@spec log_variant_processing_failure(term(), term(), term()) :: :ok`. **Missing piece:** the `@deprecated "..."` attribute. Plan 18-04 adds exactly one new line above line 482. |
| D-17 (`Rindle.verify_upload/2` keeps `@doc deprecated:` metadata) | CONFIRMED | `lib/rindle.ex:102` has `@doc deprecated: "Use verify_completion/2"` immediately above the `@doc """..."""` block at lines 103-118. The boundary test (`api_surface_boundary_test.exs:test/legacy verify_upload/2 stays documented...`) already asserts this with `deprecated_function_doc?(Rindle, :verify_upload, 2, "Use verify_completion/2")`. |
| D-18 (honor-system enforcement for `@callback @doc`) | CONFIRMED | doctor `lib/module_information.ex` does not analyze callbacks (per CONTEXT.md research); ExDoc warnings-as-errors does not flag missing callback docs. No custom Credo check needed. |
| D-19 (ExUnit backstop in `test/rindle/behaviour_docs_test.exs`) | CONFIRMED | New test file, ~15 LOC, uses `Code.fetch_docs/1` — same pattern already used in `test/rindle/api_surface_boundary_test.exs:fetch_docs!/1` (lines tail of file). Reuse the fetcher idiom for consistency. |
| D-20 (one-line CONTRIBUTING note) | CONFIRMED with adjustment | **No CONTRIBUTING.md exists** (verified `ls CONTRIBUTING.md` — file not present). Per CONTEXT.md D-20: "Add a single line to CONTRIBUTING.md (or `README.md`'s contributing section if no `CONTRIBUTING.md` exists)" — add to README.md. Planner picks the section; suggest adding under a "Contributing" or "Documentation conventions" heading near the bottom. |
| D-21 (optional Membrane-style callback summary in `@moduledoc`) | CONFIRMED as optional | 5 behaviour modules × ~3 callbacks each. Hand-written summaries are appropriate at this scale. Defer or include in Plan 18-05 per CONTEXT.md guidance. |
| D-22 (5-plan slice, baseline-then-ratchet) | CONFIRMED | Plan-slice rationale is locked. |
| D-23 (failing `doctor_thresholds_test.exs` ratchet contract) | CONFIRMED | Plan 18-01 ships failing test asserting D-07 target values; Plan 18-05 turns it green when thresholds ratchet. See `## Validation Architecture` for the exact assertion list. |
| D-24 (locked plan order 18-01 → 18-05) | CONFIRMED | All 5 plan boundaries are mechanically clean — see Per-File Implementation Sketch for which file changes belong in which plan. |
| D-25 (defensive split clause if 18-04 > 10 files) | CONFIRMED | Computed file count for 18-04: 5 Mix tasks + 2 workers + 1 Profile + 1 HTML + 1 Rindle (shim + readme) = **9-10 files**. Stays at the boundary. Recommend the planner re-count at planning time and only split if the count exceeds 10 after the README/CONTRIBUTING line decision. |
| D-26 (decision-making preference) | CONFIRMED | No high-impact items in Phase 18. Agent decides; escalate nothing. |

## File Inventory

Exhaustive table of every file Phase 18 touches. Plan column maps to the 5-plan slice in D-24.

| File | Role | What changes | Plan | Risk |
|------|------|-------------|------|------|
| `mix.exs` | dep | Add `{:doctor, "~> 0.22.0", only: [:dev, :test], runtime: false}` to deps list (after line 90, alongside other `:dev/:test` tools) | 18-01 | low |
| `mix.lock` | dep-lock | Auto-updated by `mix deps.get` after 18-01 dep change | 18-01 | low |
| `.doctor.exs` | config (new) | Created by `mix doctor.gen.config`; baseline thresholds from current state; `ignore_modules:` populated per Phase 17 D-05 list (see inventory below) | 18-01 (baseline), 18-05 (ratchet) | low |
| `.github/workflows/ci.yml` | CI | Insert `Run mix doctor` step in `quality` job between line 85 (`mix credo --strict`) and line 87 (`Run tests with coverage`). Inherits Elixir 1.15 + 1.17 matrix automatically | 18-01 | low |
| `test/rindle/doctor_thresholds_test.exs` | test (new) | RED harness: read `.doctor.exs`, assert thresholds equal D-07 target values. Fails on Plan 18-01 (because baseline ≠ target). Turns green on Plan 18-05 | 18-01 (RED), 18-05 (green) | low |
| `test/rindle/behaviour_docs_test.exs` | test (new) | D-19 backstop: assert every `@callback` on the 5 behaviour modules has `@doc` neither `:none` nor `:hidden` via `Code.fetch_docs/1` | 18-03 | low |
| `lib/rindle.ex` | facade | Tighten 11 `@spec`s with named schema types per D-03; add `@deprecated` attribute on `log_variant_processing_failure/3` per D-16 | 18-02 (tightening), 18-04 (`@deprecated`) | medium |
| `lib/rindle/upload/broker.ex` | facade | Add 6 missing `@spec`s (one per public function); add named-type aliases (`@type initiate_multipart_result/0`, `@type sign_url_result/0`, `@type verify_result/0`, etc.) per D-05 | 18-02 (named types), 18-03 (specs) | medium |
| `lib/rindle/storage.ex` | behaviour | Add `@type put_result/0`, `@type delete_result/0`, `@type url_result/0`, `@type presign_result/0`, `@type multipart_init_result/0`, `@type multipart_part_result/0`, `@type multipart_complete_result/0`, `@type head_result/0` per D-04; rewrite all 11 `@callback`s to reference the named types; add per-callback `@doc` per D-11 | 18-02 (named types), 18-03 (`@doc`) | medium |
| `lib/rindle/storage/local.ex` | adapter | Already uses `@impl true` consistently (`local.ex:8,20,32,40,45,51,56,61,66,71,82`); inherits behaviour-level docs and types per D-04. No edits required if behaviour-level types exactly match `Local` return shapes (see proposal below — `Local.store/3` returns `%{key: ..., path: ...}`, `Local.head/2` returns `%{size: ...}`). Verify after 18-02 lands. | 18-02 (verify only) | low |
| `lib/rindle/storage/s3.ex` | adapter | Same as Local — already `@impl true`-consistent. `S3.store/3` returns `%{key: ..., bucket: ..., response: ...}`; `S3.head/2` returns `%{size: ..., content_type: ...}`. Behaviour-level result types must be loose enough to admit both shapes (use `String.t() => term()` map keys with required `:key` / `:size`). | 18-02 (verify only) | low |
| `lib/rindle/authorizer.ex` | behaviour | Add `@doc """..."""` immediately preceding the single `@callback authorize/3` (line 9). | 18-03 | low |
| `lib/rindle/analyzer.ex` | behaviour | Add `@doc """..."""` immediately preceding the single `@callback analyze/1` (line 9). | 18-03 | low |
| `lib/rindle/scanner.ex` | behaviour | Add `@doc """..."""` immediately preceding the single `@callback scan/1` (line 9). | 18-03 | low |
| `lib/rindle/processor.ex` | behaviour | Add `@doc """..."""` immediately preceding the single `@callback process/3` (line 9). | 18-03 | low |
| `lib/rindle/profile.ex` | macro | Add `@doc """..."""` and `@spec __using__(keyword()) :: Macro.t()` immediately preceding `defmacro __using__(opts)` at line 15 per D-14. | 18-04 | low |
| `lib/rindle/html.ex` | optional integration | Add `@doc """..."""` preceding `@spec picture_tag/3` at line 12 per D-15. | 18-04 | low |
| `lib/rindle/live_view.ex` | optional integration | No edits — `allow_upload/4` and `consume_uploaded_entries/3` already have `@doc` and `@spec` (`live_view.ex:40-67,102-127`). Verify only. | 18-04 (verify only) | low |
| `lib/rindle/workers/abort_incomplete_uploads.ex` | worker | Optionally add `@spec perform(Oban.Job.t()) :: :ok \| {:error, term()}` if narrowing `Oban.Worker.result()`. `@moduledoc` already rich. Do NOT add `@doc` to `perform/1` per D-13. | 18-04 | low |
| `lib/rindle/workers/cleanup_orphans.ex` | worker | Same as above. | 18-04 | low |
| `lib/mix/tasks/rindle.abort_incomplete_uploads.ex` | mix task | Verify `@shortdoc` + `@moduledoc` + `@impl Mix.Task` posture — already correct (`rindle.abort_incomplete_uploads.ex:2-43`). NO `@doc`/`@spec` on `run/1` per D-12. | 18-04 (verify only) | low |
| `lib/mix/tasks/rindle.backfill_metadata.ex` | mix task | Same — already correct. | 18-04 (verify only) | low |
| `lib/mix/tasks/rindle.cleanup_orphans.ex` | mix task | Same — already correct. | 18-04 (verify only) | low |
| `lib/mix/tasks/rindle.regenerate_variants.ex` | mix task | Same — already correct. | 18-04 (verify only) | low |
| `lib/mix/tasks/rindle.verify_storage.ex` | mix task | Same — already correct. | 18-04 (verify only) | low |
| `README.md` | docs | Add D-20 line to a "Contributing" or "Documentation conventions" section near the bottom (no `CONTRIBUTING.md` exists). | 18-04 | low |
| `CHANGELOG.md` | docs | Add a `0.2.0`-pending or `0.1.5`-pending entry summarizing the doc/spec sweep, named-type tightening, and CI doctor gate. | 18-05 | low |
| `lib/rindle/domain/media_asset.ex` | schema | Verify only — already complete. | 18-02 (verify only) | low |
| `lib/rindle/domain/media_attachment.ex` | schema | Verify only — already complete. | 18-02 (verify only) | low |
| `lib/rindle/domain/media_upload_session.ex` | schema | Verify only — already complete. | 18-02 (verify only) | low |
| `lib/rindle/domain/media_variant.ex` | schema | Verify only — already complete. | 18-02 (verify only) | low |
| `lib/rindle/domain/media_processing_run.ex` | schema | Verify only — already complete. | 18-02 (verify only) | low |
| `lib/rindle/delivery.ex` | facade | Verify only — fully complete (`delivery.ex:14-135`). Reference template. | (none) | low |

**Plan 18-04 file count tally** (per D-25 split clause):
- 5 Mix tasks (verify only — counts as touched if planner reads to confirm)
- 2 workers
- 1 Profile macro
- 1 HTML
- 1 LiveView (verify only)
- 1 Rindle (`@deprecated` line)
- 1 README
- = **5 + 2 + 4 = 11 files if all "verify only" count as touched**, or **5 if only edits count**.

Recommendation: count the 5 Mix tasks + 1 LiveView as "verify only" (no edits), giving 6 edited files (`profile.ex`, `html.ex`, 2 workers, `rindle.ex`, `README.md`). Do NOT split 18-04 — defensive split is unnecessary.

## Per-File Implementation Sketch

Use `Rindle.Delivery` as the canonical "good" template — every public function already has `@doc` + `@spec` with `{:ok, T} | {:error, term()}` shapes (`delivery.ex:14-135`).

### `lib/rindle.ex` — facade (`@spec` tightening + `@deprecated`)

Plan 18-02 rewrites the following `@spec`s (line numbers from current file):

| Line | Current `@spec` | Plan-18-02 replacement |
|------|----------------|-----------------------|
| 52 | `initiate_upload(module(), keyword()) :: {:ok, map()} \| {:error, term()}` | `initiate_upload(module(), keyword()) :: {:ok, MediaUploadSession.t()} \| {:error, term()}` |
| 60 | `initiate_multipart_upload(module(), keyword()) :: {:ok, map()} \| {:error, term()}` | `initiate_multipart_upload(module(), keyword()) :: {:ok, Broker.initiate_multipart_result()} \| {:error, term()}` (uses Broker-level named alias from D-05) |
| 68 | `sign_multipart_part(binary(), pos_integer(), keyword()) :: {:ok, map()} \| {:error, term()}` | `sign_multipart_part(binary(), pos_integer(), keyword()) :: {:ok, Broker.sign_part_result()} \| {:error, term()}` |
| 76 | `complete_multipart_upload(binary(), [map()], keyword()) :: {:ok, map()} \| {:error, term()}` | `complete_multipart_upload(binary(), [map()], keyword()) :: {:ok, Broker.verify_result()} \| {:error, term()}` (delegates to verify_completion path) |
| 97 | `verify_completion(binary(), keyword()) :: {:ok, map()} \| {:error, term()}` | `verify_completion(binary(), keyword()) :: {:ok, Broker.verify_result()} \| {:error, term()}` |
| 119 | `verify_upload(binary(), keyword()) :: {:ok, map()} \| {:error, term()}` | `verify_upload(binary(), keyword()) :: {:ok, Broker.verify_result()} \| {:error, term()}` |
| 169-170 | `attach(struct() \| binary(), struct(), String.t(), keyword()) :: {:ok, struct()} \| {:error, term()}` | `attach(MediaAsset.t() \| binary(), struct(), String.t(), keyword()) :: {:ok, MediaAttachment.t()} \| {:error, term()}` |
| 372 | `upload(module(), map() \| struct(), keyword()) :: {:ok, struct()} \| {:error, term()}` | `upload(module(), map() \| Plug.Upload.t(), keyword()) :: {:ok, MediaAsset.t()} \| {:error, term()}` |

Already-fine specs (no rewrite needed):
- `version/0` (line 33), `sign_multipart_part` arg shape, `storage_adapter_for/1` (line 134), `detach/3` (line 243), `download/4` (298), `delete/3` (314), `url/3` (332), `variant_url/4` (351), `head/3` (431), `presigned_put/4` (447), `store/4` (150), `store_variant/4` (466), `log_variant_processing_failure/3` (483).

The `storage_result()` alias (`rindle.ex:22`) currently expands to `{:ok, term()} | {:error, term()}` — leave as-is for storage adapter dispatch (heterogeneous adapter return shapes; tightening here would force a per-call narrowing that hurts more than helps).

**`@deprecated` on the shim (D-16, Plan 18-04):**
At `rindle.ex:482`, insert one line above `@doc false`:

```elixir
@deprecated "Use Rindle.Internal.VariantFailureLogger.log/3 instead — facade shim kept for 0.1.x compatibility only"
@doc false
@spec log_variant_processing_failure(term(), term(), term()) :: :ok
def log_variant_processing_failure(asset_id, variant_name, reason) do
  VariantFailureLogger.log(asset_id, variant_name, reason)
end
```

### `lib/rindle/upload/broker.ex` — 6 missing `@spec`s + named-type aliases

Plan 18-02 adds module-level `@type` aliases at the top of the module (after the `@default_multipart_part_size` declaration around line 12):

```elixir
@type session_only_result :: {:ok, MediaUploadSession.t()} | {:error, term()}

@type initiate_multipart_result :: {:ok, %{
  session: MediaUploadSession.t(),
  multipart: %{
    upload_id: String.t(),
    upload_key: String.t(),
    part_size: pos_integer(),
    part_headers: map()
  }
}} | {:error, term()}

@type presigned_payload :: %{
  url: String.t(),
  method: :put | String.t(),
  headers: map(),
  optional(:part_number) => pos_integer(),
  optional(:upload_id) => String.t()
}

@type sign_url_result :: {:ok, %{session: MediaUploadSession.t(), presigned: presigned_payload()}} | {:error, term()}

@type sign_part_result :: sign_url_result()

@type verify_result :: {:ok, %{session: MediaUploadSession.t(), asset: MediaAsset.t()}} | {:error, term()}
```

Plan 18-03 adds the 6 missing `@spec`s, each above the existing `@doc` block:

| Function (line) | Proposed `@spec` |
|-----------------|------------------|
| `initiate_session/2` (line 29) | `@spec initiate_session(module(), keyword()) :: session_only_result()` |
| `initiate_multipart_session/2` (line 66) | `@spec initiate_multipart_session(module(), keyword()) :: initiate_multipart_result()` |
| `sign_url/2` (line 128) | `@spec sign_url(binary(), keyword()) :: sign_url_result()` |
| `sign_multipart_part/3` (line 155) | `@spec sign_multipart_part(binary(), pos_integer(), keyword()) :: sign_part_result()` |
| `complete_multipart_upload/3` (line 184) | `@spec complete_multipart_upload(binary(), [map()], keyword()) :: verify_result()` |
| `verify_completion/2` (line 230) | `@spec verify_completion(binary(), keyword()) :: verify_result()` |

### `lib/rindle/storage.ex` — named-result-types + per-callback `@doc`

See dedicated section "`Rindle.Storage` named-result-types proposal" below.

Plan 18-03 adds `@doc """..."""` immediately preceding each of the 11 `@callback` lines:
- line 26 (`store/3`)
- line 29 (`download/3`)
- line 32 (`delete/2`)
- line 35 (`url/2`)
- line 38 (`presigned_put/3`)
- line 41 (`initiate_multipart_upload/3`)
- line 47 (`presigned_upload_part/5`)
- line 55 (`complete_multipart_upload/4`)
- line 62 (`abort_multipart_upload/3`)
- line 68 (`head/2`)

Line 76 (`capabilities/0`) already has `@doc` (line 71-75) — no change.

### `lib/rindle/authorizer.ex`, `analyzer.ex`, `scanner.ex`, `processor.ex` — single-callback behaviours

Each file: add `@doc """..."""` immediately preceding the single `@callback` (line 9). Example for `lib/rindle/authorizer.ex:9`:

```elixir
@doc """
Authorizes a delivery action for an actor against a subject.

Implementations should return `:ok` to permit the action or `{:error, :unauthorized}`
(or another term) to deny it. Authorization runs before any URL is issued and
before any storage I/O is attempted.
"""
@callback authorize(actor :: term(), action :: atom(), subject :: term()) ::
            :ok | {:error, :unauthorized | term()}
```

Same template applies to the 3 sibling behaviours.

### `lib/rindle/profile.ex` — `__using__/1` macro doc + spec

Insert at `profile.ex:14` (above the `defmacro __using__(opts)` at line 15):

```elixir
@doc """
Declares a Rindle profile.

When `use`d, this macro validates the supplied options at compile time and
generates the `storage_adapter/0`, `variants/0`, `upload_policy/0`,
`validate_upload/1`, `delivery_policy/0`, and `recipe_digest/1` functions
that the rest of Rindle dispatches through.

## Example

    defmodule MyApp.AvatarProfile do
      use Rindle.Profile,
        storage: Rindle.Storage.S3,
        allow_mime: ["image/png", "image/jpeg"],
        max_bytes: 10_000_000,
        delivery: %{public: false, signed_url_ttl_seconds: 900},
        variants: %{thumb: %{width: 128, height: 128, format: :webp}}
    end
"""
@spec __using__(keyword()) :: Macro.t()
defmacro __using__(opts) do
  ...
end
```

### `lib/rindle/html.ex` — `picture_tag/3` doc

Insert at `html.ex:11` (above `@spec picture_tag/3` at line 12):

```elixir
@doc """
Renders a `<picture>` element with `<source>` entries for each ready variant
and an `<img>` fallback to the original asset.

Variant order in `:variants` is preserved as the source order rendered into
the markup. Stale or non-ready variants are skipped — the fallback `<img>`
URL always resolves to the original asset.

## Options

  * `:variants` — list of `{name, media_query}` tuples, `%{name: ..., media: ...}`
    maps, or bare atom variant names. Variants are rendered in the order given.
  * `:placeholder` — string to use as the `src` attribute when no variant is
    ready and the asset has no `:storage_key`.
  * Any other key is rendered as a literal HTML attribute on the `<img>` tag.

## Example

    <%= Rindle.HTML.picture_tag(MyApp.AvatarProfile, asset,
          variants: [{:thumb, "(max-width: 480px)"}, {:large, nil}],
          alt: "User avatar"
        ) %>
"""
@spec picture_tag(module(), map(), keyword()) :: Phoenix.HTML.safe()
def picture_tag(profile, asset, opts \\ []) do
```

### `lib/rindle/workers/*.ex` — optional `@spec perform/1`

If the planner wants to narrow `Oban.Worker.result()` (which is `:ok | {:cancel, term()} | {:discard, term()} | {:error, term()} | {:snooze, pos_integer()} | :discard`), add at `abort_incomplete_uploads.ex:70` and `cleanup_orphans.ex:64`:

```elixir
@spec perform(Oban.Job.t()) :: :ok | {:error, term()}
@impl Oban.Worker
def perform(...) do
```

This narrows to the actual returned types (verified in code: only `:ok` and `{:error, reason}` are returned). Optional per D-13.

## `Rindle.Storage` named-result-types proposal

Per D-04, place these `@type` declarations at the top of `lib/rindle/storage.ex` (before the existing `@type capability ::` at line 17), then rewrite each `@callback` to reference them. All shapes verified by reading `Local` and `S3` adapter return values.

### Verified adapter return shapes

| Callback | `Rindle.Storage.Local` returns | `Rindle.Storage.S3` returns |
|----------|-------------------------------|----------------------------|
| `store/3` | `%{key: key, path: destination_path}` (`local.ex:14`) | `%{key: key, bucket: bucket, response: response}` (`s3.ex:20`) |
| `download/3` | `destination_path` (just the path) (`local.ex:26`) | `destination_path` (just the path) (`s3.ex:38`) |
| `delete/2` | `%{key: key}` (`local.ex:35`) | the raw ExAws result map (`s3.ex:48`) |
| `url/2` | `"file://" <> path` (string) (`local.ex:42`) | presigned URL string (`s3.ex:58`) |
| `presigned_put/3` | `%{url: ..., method: "PUT", headers: []}` (`local.ex:48`) | `%{url: ..., method: :put, headers: %{}}` (`s3.ex:68`) — note the `method` value type differs (`"PUT"` string vs. `:put` atom); the named type must admit both |
| `initiate_multipart_upload/3` | `{:error, {:upload_unsupported, :multipart_upload}}` only (`local.ex:53`) | `%{upload_id: ..., upload_key: key, bucket: bucket, part_size: part_size}` (`s3.ex:77`) |
| `presigned_upload_part/5` | `{:error, ...}` only (`local.ex:58`) | `%{url: ..., method: :put, headers: %{}, part_number: ..., upload_id: ...}` (`s3.ex:94-101`) |
| `complete_multipart_upload/4` | `{:error, ...}` only (`local.ex:63`) | `%{upload_id: ..., upload_key: key, bucket: bucket, ...}` (`s3.ex:113`) |
| `abort_multipart_upload/3` | `{:error, ...}` only (`local.ex:68`) | `%{response: ..., upload_id: ..., upload_key: ..., bucket: ...}` (`s3.ex:123`) |
| `head/2` | `%{size: byte_size}` (`local.ex:76`) | `%{size: ..., content_type: ...}` (`s3.ex:140-144`) |

### Proposed `@type` declarations

```elixir
@typedoc "Successful storage write metadata. Adapters MUST include `:key`; other fields are adapter-specific."
@type put_result :: %{:key => String.t(), optional(atom()) => term()}

@typedoc "Successful storage delete metadata. Adapters MUST include `:key` when known."
@type delete_result :: %{optional(:key) => String.t(), optional(atom()) => term()}

@typedoc "Resolved delivery URL string."
@type url_result :: String.t()

@typedoc "Presigned upload payload. `:url`, `:method`, and `:headers` are required; multipart variants add `:part_number` and `:upload_id`."
@type presign_result :: %{
  required(:url) => String.t(),
  required(:method) => atom() | String.t(),
  required(:headers) => map() | list(),
  optional(:part_number) => pos_integer(),
  optional(:upload_id) => String.t()
}

@typedoc "Multipart-upload initiation metadata. `:upload_id` is required; other fields are adapter-specific."
@type multipart_init_result :: %{
  required(:upload_id) => String.t(),
  optional(:upload_key) => String.t(),
  optional(:bucket) => String.t(),
  optional(:part_size) => pos_integer(),
  optional(atom()) => term()
}

@typedoc "Multipart-upload completion metadata. `:upload_id` and `:upload_key` are required."
@type multipart_complete_result :: %{
  required(:upload_id) => String.t(),
  required(:upload_key) => String.t(),
  optional(atom()) => term()
}

@typedoc "Storage object metadata returned by HEAD. `:size` is required; `:content_type` is best-effort."
@type head_result :: %{
  required(:size) => non_neg_integer(),
  optional(:content_type) => String.t() | nil,
  optional(atom()) => term()
}
```

### Rewritten `@callback`s

```elixir
@callback store(key :: String.t(), source :: Path.t(), opts :: keyword()) ::
            {:ok, put_result()} | {:error, term()}

@callback download(key :: String.t(), destination :: Path.t(), opts :: keyword()) ::
            {:ok, Path.t()} | {:error, term()}

@callback delete(key :: String.t(), opts :: keyword()) ::
            {:ok, delete_result()} | {:error, term()}

@callback url(key :: String.t(), opts :: keyword()) ::
            {:ok, url_result()} | {:error, term()}

@callback presigned_put(key :: String.t(), expires_in :: pos_integer(), opts :: keyword()) ::
            {:ok, presign_result()} | {:error, term()}

@callback initiate_multipart_upload(key :: String.t(), part_size :: pos_integer(), opts :: keyword()) ::
            {:ok, multipart_init_result()} | {:error, term()}

@callback presigned_upload_part(key :: String.t(), upload_id :: String.t(), part_number :: pos_integer(),
                                 expires_in :: pos_integer(), opts :: keyword()) ::
            {:ok, presign_result()} | {:error, term()}

@callback complete_multipart_upload(key :: String.t(), upload_id :: String.t(),
                                     parts :: [map() | {pos_integer(), String.t()}], opts :: keyword()) ::
            {:ok, multipart_complete_result()} | {:error, term()}

@callback abort_multipart_upload(key :: String.t(), upload_id :: String.t(), opts :: keyword()) ::
            {:ok, term()} | {:error, term()}

@callback head(key :: String.t(), opts :: keyword()) ::
            {:ok, head_result()} | {:error, term()}
```

**Adapter-side change:** `Rindle.Storage.Local` and `Rindle.Storage.S3` both already use `@impl true` on every callback (no `@impl Rindle.Storage` qualified form needed — the unqualified form is current Elixir convention). Per D-04, no `@spec` is added at the adapter level — the behaviour-level callback signatures via `@impl true` are the contract, and the doctor pass at 95% spec threshold accepts callback inheritance. Verify after Plan 18-02 that Dialyzer is still clean against the new behaviour types.

## `Rindle` and `Rindle.Upload.Broker` named-types proposal

See "Per-File Implementation Sketch" above for the full rewrite tables. Summary:

**`Rindle` (facade):** 8 `@spec`s tightened. New named types are mostly schema struct types (`MediaAsset.t()`, `MediaUploadSession.t()`, `MediaAttachment.t()` — all already declared in `lib/rindle/domain/*.ex`). Multi-key result aliases (`Broker.initiate_multipart_result/0`, `Broker.sign_part_result/0`, `Broker.verify_result/0`) are referenced from `Broker` rather than re-declared in `Rindle` — single source of truth at the broker.

**`Rindle.Upload.Broker`:** 6 new module-level `@type` aliases, 6 new `@spec`s. The aliases are referenced from `Rindle` via the dot-qualified form (`Broker.verify_result()`).

**Error branch posture (per CONTEXT.md `<specifics>`):** Keep `{:error, term()}` on every error tuple — narrowing the error term is a Dialyzer-breaking change for adopters pattern-matching on it, and the locked semver posture (Phase 17 D-08) blocks that. Do NOT promote any error tuples to atom-only or specific union forms.

## `.doctor.exs` ignore_modules inventory

Per Phase 17 D-05 (verified by direct grep of `@moduledoc false` across `lib/`), the following 18 modules MUST be in `ignore_modules:`:

### By namespace prefix (regex-friendly)

```elixir
ignore_modules: [
  # Application
  Rindle.Application,
  
  # Internal namespace (regex catches future additions)
  ~r/^Rindle\.Internal\./,            # currently: Rindle.Internal.VariantFailureLogger
  
  # Security namespace
  ~r/^Rindle\.Security\./,            # currently: Filename, Mime, StorageKey, UploadValidation
  
  # Ops namespace
  ~r/^Rindle\.Ops\./,                 # currently: MetadataBackfill, UploadMaintenance, VariantMaintenance
  
  # Domain FSM and stale-policy modules (NOT the schemas)
  Rindle.Domain.AssetFSM,
  Rindle.Domain.UploadSessionFSM,
  Rindle.Domain.VariantFSM,
  Rindle.Domain.StalePolicy,
  
  # Profile internal helpers (NOT Rindle.Profile itself)
  Rindle.Profile.Validator,
  Rindle.Profile.Digest,
  
  # Infrastructure helpers
  Rindle.Config,
  Rindle.Repo,
  Rindle.Storage.Capabilities,
  
  # Internal pipeline workers (NOT AbortIncompleteUploads / CleanupOrphans)
  Rindle.Workers.PromoteAsset,
  Rindle.Workers.ProcessVariant,
  Rindle.Workers.PurgeStorage,
  
  # Processor implementations not in the public set (see R-1 below)
  # Rindle.Processor.Image  # FLAG: see Risk Register R-1
]
```

**Verified hidden module list** (from `grep -lR "@moduledoc false" lib/`):
- `lib/rindle/application.ex`
- `lib/rindle/config.ex`
- `lib/rindle/domain/asset_fsm.ex`
- `lib/rindle/domain/stale_policy.ex`
- `lib/rindle/domain/upload_session_fsm.ex`
- `lib/rindle/domain/variant_fsm.ex`
- `lib/rindle/internal/variant_failure_logger.ex`
- `lib/rindle/ops/metadata_backfill.ex`
- `lib/rindle/ops/upload_maintenance.ex`
- `lib/rindle/ops/variant_maintenance.ex`
- `lib/rindle/profile/digest.ex`
- `lib/rindle/profile/validator.ex`
- `lib/rindle/repo.ex`
- `lib/rindle/security/filename.ex`
- `lib/rindle/security/mime.ex`
- `lib/rindle/security/storage_key.ex`
- `lib/rindle/security/upload_validation.ex`
- `lib/rindle/storage/capabilities.ex`
- `lib/rindle/workers/process_variant.ex`
- `lib/rindle/workers/promote_asset.ex`
- `lib/rindle/workers/purge_storage.ex`

That's 21 hidden modules. The regex shape above covers `Rindle.Internal.*` (1 module), `Rindle.Security.*` (4 modules), `Rindle.Ops.*` (3 modules), with the remaining 13 listed explicitly.

**Conventional protocol regexes (recommended additions per CONTEXT.md D-08):**
```elixir
~r/^Inspect\./,                        # any auto-generated Inspect protocol impls
```

## CI insertion point

Current `.github/workflows/ci.yml` `quality` job structure (lines 84-88):

```yaml
84:      - name: Credo (strict)
85:        run: mix credo --strict
86:
87:      - name: Run tests with coverage
88:        run: mix coveralls
```

Insert the new step between line 85 and line 87:

```yaml
      - name: Credo (strict)
        run: mix credo --strict

      - name: Doctor (full, raise)
        run: MIX_ENV=test mix doctor --full --raise

      - name: Run tests with coverage
        run: mix coveralls
```

Notes:
- Inherits the existing Elixir 1.15 / OTP 26 + Elixir 1.17 / OTP 27 matrix automatically (matrix is on the `quality` job at lines 19-26).
- Inherits the existing `MIX_ENV: test` job-level env (line 10) — the explicit `MIX_ENV=test` prefix in the step is belt-and-suspenders per D-10's research; matches the `team-alembic/staple-actions/actions/mix-doctor` canonical action.
- No `continue-on-error` per D-10 — failures block merge same as Credo and Dialyzer.
- The step order (Credo → Doctor → tests) matches the canonical Ash CI lane (`https://github.com/ash-project/ash/blob/main/.github/workflows/ash-ci.yml` per CONTEXT.md canonical refs).

## Validation Architecture

Phase 18 has Nyquist enabled (`.planning/config.json` does not opt out via `workflow.nyquist_validation: false`). The validation surfaces below feed `18-VALIDATION.md`.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (`mix test`) — Elixir 1.15+ stdlib |
| Config file | `test/test_helper.exs` (existing) |
| Quick run command | `mix test test/rindle/doctor_thresholds_test.exs test/rindle/behaviour_docs_test.exs --color` |
| Full suite command | `mix test` (chains via `mix.exs` `aliases :test`: `ecto.create --quiet`, `ecto.migrate --quiet`, `test`) |
| Doctor gate command | `MIX_ENV=test mix doctor --full --raise` |
| Dialyzer command | `mix dialyzer --format github` (existing PLT cached in CI) |

### Validation surfaces

1. **ExUnit — `test/rindle/doctor_thresholds_test.exs`** (D-23 ratchet harness): reads `.doctor.exs` and asserts the configured thresholds equal the D-07 target values (100/100/100/95/95). Fails on Plan 18-01 (because `.doctor.exs` ships at baseline). Turns green on Plan 18-05.
2. **ExUnit — `test/rindle/behaviour_docs_test.exs`** (D-19 backstop): uses `Code.fetch_docs/1` on each of `Rindle.Storage`, `Rindle.Authorizer`, `Rindle.Analyzer`, `Rindle.Scanner`, `Rindle.Processor`. Iterates each `:callback` entry in the docs chunk and asserts the doc state is neither `:none` nor `:hidden`. Reuses the same idiom as `test/rindle/api_surface_boundary_test.exs:fetch_docs!/1`. Lands green on Plan 18-03 (after callback `@doc`s are added).
3. **CI gate — `MIX_ENV=test mix doctor --full --raise`**: runs every CI build in the `quality` job. Configured thresholds enforced via `.doctor.exs`. Lands at baseline on Plan 18-01 (passing); ratchets to target on Plan 18-05 (still passing).
4. **Dialyzer — `mix dialyzer`**: PLT regen happens automatically in CI (`.github/workflows/ci.yml:90-104`). Tightened `@spec`s in Plan 18-02 must pass Dialyzer cleanly. Run locally before Plan 18-02 commit: `mix dialyzer`.
5. **ExDoc — `mix docs --warnings-as-errors`** (existing in Phase 17): regression-guards docs autolinks. Plan 18-02 / 18-03 named-type changes might affect cross-module type links — re-run after each.
6. **Existing boundary test — `test/rindle/api_surface_boundary_test.exs`** (Phase 17): regression-guards the public/hidden split. Doctor's `ignore_modules:` list is derived from this test's hidden-module sets; if Plan 18-01 picks the wrong list, this test stays green but doctor's coverage report mis-counts.

### Test inventory (per requirement)

#### API-06 — `@doc` on every public module/function/callback

| Test ID | Surface | Test/Assertion | Lands |
|---------|---------|---------------|-------|
| API-06-T1 | doctor `--full` | `min_module_doc_coverage: 100` and `min_overall_doc_coverage: 100` against `.doctor.exs` thresholds | Plan 18-05 (target) |
| API-06-T2 | ExUnit `behaviour_docs_test.exs` | For each behaviour module, every `@callback` has non-`:none`/non-`:hidden` doc | Plan 18-03 |
| API-06-T3 | ExDoc | `mix docs --warnings-as-errors` — autolink regressions | Plan 18-02 onward |

#### API-07 — Named struct types in `@spec`

| Test ID | Surface | Test/Assertion | Lands |
|---------|---------|---------------|-------|
| API-07-T1 | Dialyzer | `mix dialyzer` clean against tightened `Rindle` specs | Plan 18-02 |
| API-07-T2 | Dialyzer | `mix dialyzer` clean against `Rindle.Upload.Broker` named-type aliases | Plan 18-02 / 18-03 |
| API-07-T3 | Dialyzer | `mix dialyzer` clean against `Rindle.Storage` behaviour-level result types | Plan 18-02 |
| API-07-T4 | doctor `--full` | `min_module_spec_coverage: 95` and `min_overall_spec_coverage: 95` | Plan 18-05 (target) |
| API-07-T5 | ExUnit `doctor_thresholds_test.exs` | Asserts `.doctor.exs` configures spec thresholds at 95/95 | Plan 18-01 (RED), Plan 18-05 (green) |

#### API-08 — CI enforces coverage via `mix doctor --raise`

| Test ID | Surface | Test/Assertion | Lands |
|---------|---------|---------------|-------|
| API-08-T1 | CI workflow | Step `Doctor (full, raise)` exists in `.github/workflows/ci.yml` `quality` job | Plan 18-01 |
| API-08-T2 | CI runtime | A failing `@doc`/`@spec` regression makes `mix doctor --full --raise` exit non-zero (verified by manually downgrading a `@doc` and observing CI red) | Plan 18-05 |
| API-08-T3 | CI matrix | The doctor step runs on both Elixir 1.15/OTP 26 and Elixir 1.17/OTP 27 matrix lanes | Plan 18-01 |
| API-08-T4 | ExUnit `doctor_thresholds_test.exs` | Asserts `.doctor.exs` configures `min_module_doc_coverage`, `min_overall_doc_coverage`, `min_overall_moduledoc_coverage` at 100, and spec thresholds at 95 | Plan 18-01 RED, Plan 18-05 green |

### Sampling cadence

- **Per CI build (every commit on PR/push):** `MIX_ENV=test mix doctor --full --raise` runs in `quality` job on both matrix lanes.
- **Per `mix test` run (every test invocation):** `behaviour_docs_test.exs` and `doctor_thresholds_test.exs` execute as part of the unit suite.
- **Per Plan boundary:** doctor pass + Dialyzer pass + ExDoc warnings-as-errors pass — these three together are the merge gate.
- **Phase gate (Plan 18-05):** thresholds at target; D-23 test green; CHANGELOG updated; CI green on both matrix lanes.

### Coverage matrix — REQ × surface

| Requirement | doctor CI gate | ExUnit doctor_thresholds | ExUnit behaviour_docs | Dialyzer | ExDoc warn-as-error |
|-------------|----------------|--------------------------|----------------------|----------|---------------------|
| API-06 (`@doc` everywhere) | ✓ (primary) | — | ✓ (callbacks only) | — | ✓ (autolinks only) |
| API-07 (named struct types) | ✓ (`@spec` count) | — | — | ✓ (primary — type correctness) | — |
| API-08 (CI gate) | ✓ (primary — the gate itself) | ✓ (asserts the config) | — | — | — |

### Wave 0 gaps

Plan 18-01 (the failing-harness wave) is responsible for these new test-infrastructure files:
- [ ] `test/rindle/doctor_thresholds_test.exs` — D-23 RED harness (Plan 18-01 ships failing; Plan 18-05 turns green)
- [ ] `.doctor.exs` — generated by `mix doctor.gen.config` then hand-edited for `ignore_modules:` regex shape
- [ ] `:doctor` dep entry in `mix.exs` line ~91-92
- [ ] CI step in `.github/workflows/ci.yml` between line 85 and 87

Plan 18-03 ships:
- [ ] `test/rindle/behaviour_docs_test.exs` — D-19 backstop (lands green; covers callback-doc honor system)

No additional ExUnit framework install required — `mix test` is already wired and used across Phases 1-17.

## Risk Register

Non-blocking risks the planner should design around:

- **R-1: `Rindle.Processor.Image` boundary classification.** `lib/rindle/processor/image.ex:2-4` has visible `@moduledoc """..."""` text but is not in the Phase 17 D-03 public set, not in the `test/rindle/api_surface_boundary_test.exs` `@public_modules` allowlist, and not in the D-05 hidden list. Two ways forward, planner picks:
  - **(a)** Treat as intentionally public — adds it to D-01's set, gives it `@doc` on `process/3` (already has one — `image.ex:8-10`), declares it explicit in `mix.exs` `groups_for_modules` (e.g. under "Extension Points" or "Processors"), and adds it to the boundary test allowlist.
  - **(b)** Treat as internal — applies `@moduledoc false` and adds it to `.doctor.exs` `ignore_modules:`. Backward-compatible per Phase 17 D-08 only if the module is genuinely not adopter-facing. The current `@behaviour Rindle.Processor` posture suggests adopters might dispatch through it, but D-03 didn't list it.
  - **Recommendation for the planner:** route this to the user before Plan 18-02 lands, since it could affect Phase 17's recorded boundary contract. Default to **(b)** if no escalation is desired.

- **R-2: Optional-dep conditional compilation.** `Rindle.LiveView` (`live_view.ex:1`) and `Rindle.HTML` (`html.ex:1`) are wrapped in `if Code.ensure_loaded?(...) do`. In `:dev` env without test deps, those modules don't compile, and `mix doctor` would silently skip them — its coverage numbers would be wrong. **Mitigation:** D-10 already mandates `MIX_ENV=test` in CI; the plan-checker should also recommend running `MIX_ENV=test mix doctor --full --raise` locally pre-commit.

- **R-3: doctor #67 (`@moduledoc false` not auto-skipped).** Confirmed open issue (CONTEXT.md canonical refs). Plan 18-01's `ignore_modules:` list MUST cover every `@moduledoc false` module or doctor will emit "missing moduledoc" errors for hidden modules. The 21-module verified list above is exhaustive as of 2026-04-30; if a future Plan-17-style boundary edit hides more modules, `.doctor.exs` must be updated in the same PR (consider a CI assertion that grep'd `@moduledoc false` matches `.doctor.exs` `ignore_modules:` — out of scope for Phase 18, defer to a future polish phase).

- **R-4: `@doc deprecated:` vs `@deprecated` semantic distinction.** D-16 uses `@deprecated "..."` (compiler-emitted warning at call site) while D-17 uses `@doc deprecated: "..."` (ExDoc badge, no compiler warning). Both apply to different shims: D-16's `log_variant_processing_failure/3` is `@doc false` (hidden) AND `@deprecated`; D-17's `verify_upload/2` is visible AND `@doc deprecated:`. Plan 18-04 must not conflate them — verify against the existing D-17 assertion in `test/rindle/api_surface_boundary_test.exs:test/legacy verify_upload/2 stays documented...`.

- **R-5: Membrane callback-summary deferral.** D-21 keeps the option open. If Plan 18-05 stays small, include hand-written `@moduledoc` callback summaries on the 5 behaviour modules (5 × ~3 callbacks = 15 callback names, ~1-2 lines per behaviour). If the closure plan grows past ~10 file edits, defer to a polish phase.

- **R-6: Doctor threshold target is ambitious.** 100/100/100/95/95 (D-07) is one notch stricter than `prom_ex` (90/90/90/90/100). At target, every visible `Rindle.*` module needs `@moduledoc` and every visible function needs `@doc`. The 5% spec slack accommodates `@impl true` callback inheritance for Mix tasks (`run/1`) and Oban workers (`perform/1`). If after Plan 18-05 doctor reports < 100% module-doc on a module, the most likely culprit is an empty `@moduledoc` (string `""`) — those count as "missing." Verify by `mix doctor --full` locally before merging Plan 18-05.

## Open Questions for Planner

1. **R-1 (`Rindle.Processor.Image` classification):** is this module intentionally public or internal? Ask the user before Plan 18-02 if escalating; otherwise default to internal (apply `@moduledoc false`, add to `.doctor.exs` `ignore_modules:`).
2. **CONTRIBUTING.md vs README.md placement for D-20:** no `CONTRIBUTING.md` exists. The single line goes to README.md per D-20's fallback — but where in README.md? Suggest a new "Documentation conventions" subsection near the bottom (alongside any existing "Contributing" content), or inline under an existing contributing section if one exists. Planner picks.
3. **Optional `@spec perform/1` on workers (D-13):** narrow to `:ok | {:error, term()}` (matches actual return) or leave inheriting `Oban.Worker.result()`? Both are acceptable per D-13. Recommendation: narrow, because the actual return is provably narrower and Dialyzer will catch any future widening.
4. **D-21 callback summaries: in 18-05 or defer?** Recommendation: include in 18-05 if the closure plan stays at ≤ 6 file edits; defer otherwise. Mechanical decision at planning time.
5. **`mix docs --warnings-as-errors` as a separate CI step:** CONTEXT.md `<discretion>` lists this as optional. It catches autolink/extras drift but not callback-doc drift. Modest DX value; defer unless extras/guides churn warrants it.

## Sources

### Primary (HIGH confidence)
- `lib/rindle.ex:22,33-484` — facade `@spec` audit, `@deprecated` insertion point, `storage_result()` alias
- `lib/rindle/upload/broker.ex:29,66,128,155,184,230` — 6 missing `@spec` insertion points; named-result-type shapes at lines 97-105, 144, 174, 291
- `lib/rindle/storage.ex:17-77` — 11 `@callback` declarations, type tightening targets
- `lib/rindle/storage/local.ex:14,26,35,42,48,53,58,63,68,76` — adapter return shapes
- `lib/rindle/storage/s3.ex:20,38,48,58,68,77,94-101,113,123,140-144` — adapter return shapes
- `lib/rindle/{authorizer,analyzer,scanner,processor}.ex:9` — single-callback behaviour `@doc` insertion points
- `lib/rindle/profile.ex:14-15` — `__using__/1` macro doc/spec insertion point
- `lib/rindle/html.ex:11-12` — `picture_tag/3` `@doc` insertion point
- `lib/rindle/live_view.ex:40-67,102-127` — verification baseline (already complete)
- `lib/rindle/workers/abort_incomplete_uploads.ex:71`, `lib/rindle/workers/cleanup_orphans.ex:65` — worker `@impl Oban.Worker` posture
- `lib/mix/tasks/rindle.*.ex:43,67,67,69,87` — 5 `@impl Mix.Task` posture verifications
- `lib/rindle/domain/{media_asset,media_attachment,media_upload_session,media_variant,media_processing_run}.ex:47,29,45,35,24` — `@type t :: %__MODULE__{}` already present
- `mix.exs:51-94,125-168` — deps shape and `groups_for_modules` baseline
- `.github/workflows/ci.yml:84-88` — exact `quality` job insertion point
- `test/rindle/api_surface_boundary_test.exs:5-30` — Phase 17 public-set source of truth
- `.planning/phases/17-api-surface-boundary-audit/17-VERIFICATION.md` — Phase 17 verified state

### Secondary (MEDIUM confidence)
- `https://hex.pm/api/packages/doctor` — confirmed `doctor 0.22.0` is current stable (verified live)
- All canonical references in `18-CONTEXT.md` (deferred to CONTEXT.md, not re-verified)

### Tertiary (LOW confidence)
- None — Phase 18 is a documentation/typespec sweep with mechanical evidence available for every claim.

## Metadata

**Confidence breakdown:**
- Source-of-truth confirmation: HIGH — every D-XX claim verified against file:line
- File inventory: HIGH — exhaustive grep of `lib/`, `test/`, `mix.exs`, `.github/workflows/`
- Per-file implementation sketch: HIGH — line numbers verified; named-type shapes derived from current adapter code
- Named-result-type proposal: HIGH — both adapter return shapes inspected directly
- ignore_modules inventory: HIGH — `grep -lR "@moduledoc false"` confirms all 21 hidden modules
- CI insertion point: HIGH — line numbers from current `ci.yml` snapshot
- Validation Architecture: HIGH — D-23 / D-19 contracts already locked in CONTEXT.md
- Risk register: MEDIUM — R-1 (`Processor.Image`) needs human confirmation; R-2..R-6 are mechanical
- Open questions: HIGH — limited and bounded

**Research date:** 2026-04-30
**Valid until:** 2026-05-30 (mostly stable; doctor 0.22.0 stability and Elixir 1.17 stability are the variables)
