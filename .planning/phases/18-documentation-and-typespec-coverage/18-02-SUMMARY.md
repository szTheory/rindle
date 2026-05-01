---
phase: 18-documentation-and-typespec-coverage
plan: 02
subsystem: storage, upload, public-facade
tags: [typespec, dialyzer, named-types, semver-guard, behaviour, public-api, elixir]

# Dependency graph
requires:
  - phase: 17-api-surface-boundary-audit
    provides: locked public surface (boundary test guards visibility)
  - phase: 18-documentation-and-typespec-coverage
    plan: 01
    provides: doctor baseline + RED threshold harness (still 4/5 RED, unaffected)
provides:
  - "Rindle.Storage: 7 behaviour-level named result types (put_result, delete_result, url_result, presign_result, multipart_init_result, multipart_complete_result, head_result)"
  - "Rindle.Storage: 10 of 11 @callback declarations reference the named types"
  - "Rindle.Upload.Broker: 6 module-level @type aliases (session_only_result, initiate_multipart_result, presigned_payload, sign_url_result, sign_part_result, verify_result)"
  - "Rindle: 8 facade @specs tightened to use MediaAsset.t() / MediaUploadSession.t() / MediaAttachment.t() / Broker.* result types"
affects:
  - 18-03-add-function-doc-and-spec-public (per-callback @doc + Broker @spec land here)
  - 18-04-add-spec-on-private-public-callable
  - 18-05-ratchet-doctor-thresholds-and-flip-test-green

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Named-result-type aliases on behaviours (D-04): callbacks reference t-named types instead of inline map()"
    - "Open-map shape (`%{required(:key) => ..., optional(atom()) => term()}`) admits heterogeneous adapter return values without forcing adapter-side rewrites"
    - "{:error, term()} preserved on every error branch — narrowing is a Dialyzer-breaking change for adopters per Phase 17 D-08"

key-files:
  created: []
  modified:
    - "lib/rindle/storage.ex (added 7 typedocs, rewrote 10 @callbacks)"
    - "lib/rindle/upload/broker.ex (added 6 module-level @type aliases)"
    - "lib/rindle.ex (added MediaUploadSession alias + tightened 8 @specs)"

key-decisions:
  - "Encode {:error, term()} once inside each named result type alias (Broker.verify_result, Broker.initiate_multipart_result, Broker.sign_part_result) rather than repeating it in every @spec — preserves the semver guard with less line-by-line duplication."
  - "Add `Rindle.Domain.MediaUploadSession` to lib/rindle.ex aliases (was missing; MediaAsset and MediaAttachment were already aliased)."
  - "Tighten `upload/3` arg type from `map() | struct()` to `map() | Plug.Upload.t()` — `Plug.Upload.t()` is the actual wire shape adopters pass."

patterns-established:
  - "Behaviour-level named result types use `optional(atom()) => term()` to admit heterogeneous adapter return shapes (Local returns method:\"PUT\" headers:[]; S3 returns method::put headers:%{}). The behaviour declares the contract loosely enough to accommodate both without lying to Dialyzer."
  - "Sub-aliases for siblings: `sign_part_result :: sign_url_result()` — keeps the wire shape definition in one place when two specs return the identical structure."

requirements-completed: [API-07]

# Metrics
duration: 5min
completed: 2026-05-01
---

# Phase 18 Plan 02: Tighten @specs with Named Result Types Summary

**Replaced opaque `map()` / `struct()` returns in 8 public `@spec`s and 10 storage `@callback`s with named schema/result types — `{:ok, MediaAsset.t()}`, `Rindle.Storage.put_result()`, `Broker.verify_result()` — while preserving `{:error, term()}` on every error branch.**

## Performance

- **Duration:** 5 minutes
- **Started:** 2026-05-01T01:36:34Z
- **Completed:** 2026-05-01T01:42:03Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- 7 behaviour-level named result types declared on `Rindle.Storage` (`put_result`, `delete_result`, `url_result`, `presign_result`, `multipart_init_result`, `multipart_complete_result`, `head_result`).
- 10 of 11 `@callback` declarations on `Rindle.Storage` rewritten to reference the named types (`capabilities/0` retained unchanged).
- 6 module-level `@type` aliases declared on `Rindle.Upload.Broker` (`session_only_result`, `initiate_multipart_result`, `presigned_payload`, `sign_url_result`, `sign_part_result`, `verify_result`).
- 8 public `@spec`s in `lib/rindle.ex` tightened to use schema struct types (`MediaAsset.t()`, `MediaUploadSession.t()`, `MediaAttachment.t()`, `Plug.Upload.t()`) and Broker result-type aliases (`Broker.verify_result()`, `Broker.initiate_multipart_result()`, `Broker.sign_part_result()`).
- `Rindle.Domain.MediaUploadSession` added to the `lib/rindle.ex` alias block (was missing).
- `mix compile --warnings-as-errors` exits 0.
- `mix dialyzer --format github` exits 0 (`Total errors: 5, Skipped: 5, Unnecessary Skips: 0`) against tightened specs — Local and S3 adapters still satisfy the behaviour.
- `mix docs --warnings-as-errors` exits 0 (named-type cross-links resolve).
- `mix test test/rindle/api_surface_boundary_test.exs` exits 0 (8 tests, 0 failures — boundary unaffected).
- `MIX_ENV=test mix doctor --full --raise` exits 0 (baseline thresholds still pass).
- Plan 18-01's RED harness `mix test test/rindle/doctor_thresholds_test.exs` still reports `5 tests, 4 failures` — Plan 18-05's ratchet target unchanged by this typespec tightening.

## Task Commits

Each task was committed atomically:

1. **Task 1: Define behaviour-level named result types on Rindle.Storage and rewrite all 11 @callbacks** — `fc5e173` (feat)
2. **Task 2: Define Broker named-type aliases and tighten Rindle facade @specs** — `2e3a4a5` (feat)

## Files Modified

### `lib/rindle/storage.ex`

Added 7 `@typedoc`/`@type` declarations after the existing `capability` typedoc and rewrote 10 of 11 `@callback` declarations to reference them. The 7 result types are committed verbatim:

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

The 10 rewritten `@callback`s now reference these named types:

| Callback | New return |
|----------|-----------|
| `store/3` | `{:ok, put_result()} \| {:error, term()}` |
| `download/3` | `{:ok, Path.t()} \| {:error, term()}` |
| `delete/2` | `{:ok, delete_result()} \| {:error, term()}` |
| `url/2` | `{:ok, url_result()} \| {:error, term()}` |
| `presigned_put/3` | `{:ok, presign_result()} \| {:error, term()}` |
| `initiate_multipart_upload/3` | `{:ok, multipart_init_result()} \| {:error, term()}` |
| `presigned_upload_part/5` | `{:ok, presign_result()} \| {:error, term()}` |
| `complete_multipart_upload/4` | `{:ok, multipart_complete_result()} \| {:error, term()}` |
| `abort_multipart_upload/3` | `{:ok, term()} \| {:error, term()}` (intentionally loose — Local returns `{:error, ...}` only and S3 returns the raw ExAws response map) |
| `head/2` | `{:ok, head_result()} \| {:error, term()}` |

`@callback capabilities/0 :: [capability()]` retained unchanged.

### `lib/rindle/upload/broker.ex`

Added 6 module-level `@type` aliases between the `@default_multipart_part_size` module attribute and the first `@doc`. Committed verbatim:

```elixir
@typedoc "Tagged result wrapping just an upload session."
@type session_only_result :: {:ok, MediaUploadSession.t()} | {:error, term()}

@typedoc "Tagged result of `initiate_multipart_session/2` — session plus multipart upload metadata."
@type initiate_multipart_result ::
        {:ok,
         %{
           session: MediaUploadSession.t(),
           multipart: %{
             upload_id: String.t(),
             upload_key: String.t(),
             part_size: pos_integer(),
             part_headers: map()
           }
         }}
        | {:error, term()}

@typedoc "Presigned upload payload returned by sign_url and sign_multipart_part."
@type presigned_payload :: %{
        required(:url) => String.t(),
        required(:method) => atom() | String.t(),
        required(:headers) => map() | list(),
        optional(:part_number) => pos_integer(),
        optional(:upload_id) => String.t()
      }

@typedoc "Tagged result of `sign_url/2` — session plus presigned PUT payload."
@type sign_url_result ::
        {:ok, %{session: MediaUploadSession.t(), presigned: presigned_payload()}}
        | {:error, term()}

@typedoc "Tagged result of `sign_multipart_part/3` — session plus presigned part payload."
@type sign_part_result :: sign_url_result()

@typedoc "Tagged result of `verify_completion/2` and `complete_multipart_upload/3` — session plus promoted asset."
@type verify_result ::
        {:ok, %{session: MediaUploadSession.t(), asset: MediaAsset.t()}}
        | {:error, term()}
```

The `MediaAsset.t()` and `MediaUploadSession.t()` references resolve via the existing `alias Rindle.Domain.{AssetFSM, MediaAsset, MediaUploadSession, UploadSessionFSM}` at line 7. No public function `@spec`s added on Broker — those land in Plan 18-03 per D-24.

### `lib/rindle.ex`

Added `alias Rindle.Domain.MediaUploadSession` (other domain aliases — `MediaAsset`, `MediaAttachment` — were already present). Tightened 8 `@spec`s with before/after pairs:

| Function | Before | After |
|----------|--------|-------|
| `initiate_upload/2` | `(module(), keyword()) :: {:ok, map()} \| {:error, term()}` | `(module(), keyword()) :: {:ok, MediaUploadSession.t()} \| {:error, term()}` |
| `initiate_multipart_upload/2` | `(module(), keyword()) :: {:ok, map()} \| {:error, term()}` | `(module(), keyword()) :: Broker.initiate_multipart_result()` |
| `sign_multipart_part/3` | `(binary(), pos_integer(), keyword()) :: {:ok, map()} \| {:error, term()}` | `(binary(), pos_integer(), keyword()) :: Broker.sign_part_result()` |
| `complete_multipart_upload/3` | `(binary(), [map()], keyword()) :: {:ok, map()} \| {:error, term()}` | `(binary(), [map()], keyword()) :: Broker.verify_result()` |
| `verify_completion/2` | `(binary(), keyword()) :: {:ok, map()} \| {:error, term()}` | `(binary(), keyword()) :: Broker.verify_result()` |
| `verify_upload/2` | `(binary(), keyword()) :: {:ok, map()} \| {:error, term()}` | `(binary(), keyword()) :: Broker.verify_result()` |
| `attach/4` | `(struct() \| binary(), struct(), String.t(), keyword()) :: {:ok, struct()} \| {:error, term()}` | `(MediaAsset.t() \| binary(), struct(), String.t(), keyword()) :: {:ok, MediaAttachment.t()} \| {:error, term()}` |
| `upload/3` | `(module(), map() \| struct(), keyword()) :: {:ok, struct()} \| {:error, term()}` | `(module(), map() \| Plug.Upload.t(), keyword()) :: {:ok, MediaAsset.t()} \| {:error, term()}` |

The 4 specs intentionally untouched (`storage_result`-typed: `store/4`, `download/4`, `delete/3`, `url/3`, `variant_url/4`, `head/3`, `presigned_put/4`, `store_variant/4`) and the `version/0`, `storage_adapter_for/1`, `detach/3`, `log_variant_processing_failure/3` specs were already correctly typed and remained unchanged.

## Dialyzer Output Snapshot (Clean)

```
Starting Dialyzer
[
  check_plt: false,
  init_plt: ~c"…/priv/plts/dialyzer.plt",
  files: [~c"…/Elixir.Rindle.Domain.MediaProcessingRun.beam",
          ~c"…/Elixir.Rindle.Domain.MediaAttachment.beam",
          ~c"…/Elixir.Rindle.Ops.UploadMaintenance.beam",
          ~c"…/Elixir.Rindle.Ops.VariantMaintenance.beam",
          ~c"…/Elixir.Rindle.Domain.StalePolicy.beam",
          ...],
]
Total errors: 5, Skipped: 5, Unnecessary Skips: 0
done in 0m2.21s
done (passed successfully)
```

The 5 `Skipped` errors are pre-existing entries in `.dialyzer_ignore.exs`, untouched by this plan; `Unnecessary Skips: 0` confirms the tightened types did not eliminate any skip entry. The plan's named-type aliases passed Dialyzer's behaviour-conformance checks against both `Rindle.Storage.Local` and `Rindle.Storage.S3` adapter implementations on first try — the open-map shapes (`optional(atom()) => term()`) admitted both adapters' heterogeneous return shapes without forcing any adapter-side rewrites.

## Decisions Made

- **Encode `{:error, term()}` once inside each named result-type alias.** Plan acceptance criterion ≥ 12 occurrences of `{:error, term()}` literally in `lib/rindle.ex` was an artifact of a per-spec literal count; the chosen D-05 implementation pushes the error branch into the named type aliases (`Broker.verify_result/0`, `Broker.initiate_multipart_result/0`, `Broker.sign_part_result/0`), which still preserve `{:error, term()}` on every error branch — the semver guard is intact, just collapsed into 6 alias declarations instead of repeated 12+ times. See deviation #1 below for full details.
- **Add `Rindle.Domain.MediaUploadSession` to the lib/rindle.ex alias block.** The plan called this out as "may need adding"; it was missing. Added directly in the alphabetical alias group after `MediaAttachment`.
- **Use `Plug.Upload.t()` instead of bare `struct()` for `upload/3`'s second arg.** Plan called for `map() | struct()` → `map() | Plug.Upload.t()` and that's exactly what adopters pass — no looser-than-necessary type. (`@spec upload(module(), map() | Plug.Upload.t(), keyword()) :: …`).
- **Keep `abort_multipart_upload/3` callback return as `{:ok, term()}`.** The current Local adapter returns `{:error, ...}` only and the S3 adapter returns the raw ExAws response map; declaring a tighter named type for it would create a misleading contract for `Local` (which never actually returns success). Loose `term()` honestly reflects "result is adapter-specific and not normalized" without mis-typing.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Acceptance criterion mismatch] `{:error, term()}` literal count in `lib/rindle.ex` is 5, not ≥ 12**
- **Found during:** Task 2 verification
- **Issue:** Plan acceptance criterion required `grep -c '{:error, term()}' lib/rindle.ex` ≥ 12. After tightening, the literal count is 5 because 6 of the 8 tightened `@spec`s now reference Broker named-type aliases (`Broker.verify_result()`, `Broker.initiate_multipart_result()`, `Broker.sign_part_result()`) — those types each encode `{:error, term()}` once inside the alias body in `lib/rindle/upload/broker.ex` rather than per-call site in `lib/rindle.ex`.
- **Why this is correct, not a regression:** The semver guard in Phase 17 D-08 says "every error branch must remain `{:error, term()}`". That invariant is preserved — every public function still resolves to a tagged result with `{:error, term()}` on the error branch, just expressed via a named type alias instead of an inline literal. Counting literals undercounts because the same wire contract is now expressed via reference. This is the entire point of D-05 ("named result-type aliases") and the plan itself instructed the use of `Broker.verify_result()` for 4 of the 8 specs.
- **Fix:** None required — the implementation is what the plan asked for, the literal-count acceptance check was a proxy that doesn't translate cleanly when D-05 collapses repeated `{:error, term()}` into named aliases. Verified the underlying invariant holds: 4 occurrences in `lib/rindle/upload/broker.ex` (one per result-type alias that encodes an error branch — the 6th type `sign_part_result :: sign_url_result()` inherits via alias chain) plus 5 occurrences in `lib/rindle.ex` (across the unchanged `storage_result`, `detach/3`, and the two `attach/4` / `upload/3` `@spec`s that DON'T resolve to a Broker alias) covers all 8 tightened public functions plus all storage facade functions plus `detach/3`. No error branch lost the semver guard.
- **Files modified:** None (criterion interpretation only)
- **Verification:**
  - `mix dialyzer --format github` exits 0 with `Unnecessary Skips: 0` — Dialyzer accepts the named-type chain.
  - `mix docs --warnings-as-errors` exits 0 — autolinks resolve.
  - `mix test test/rindle/api_surface_boundary_test.exs` exits 0 — boundary intact.
- **Committed in:** `2e3a4a5` (Task 2 commit)

**2. [Rule 1 - Bug] Stale BEAM cache caused a transient false-fail on `function_exported?(Rindle, :verify_completion, 2)`**
- **Found during:** Task 2 verification
- **Issue:** First run of `mix test test/rindle/api_surface_boundary_test.exs` after editing `lib/rindle.ex` reported `1 failure` on the assertion `assert function_exported?(Rindle, :verify_completion, 2)`. The `verify_completion/2` function was unchanged in this plan (only its `@spec` was tightened) and the source unambiguously has `def verify_completion(session_id, opts \\ [])` which generates `verify_completion/1` and `verify_completion/2` from the default arg.
- **Root cause:** Mix incremental compile reused a stale BEAM. `mix compile --force` rebuilt all 47 modules and the test went green: 8 tests, 0 failures.
- **Fix:** None required at the source level; this was a build-cache artifact, not a regression. Logged here so future agents recognize the symptom (transient `function_exported?` false-fail right after a `@spec`-only change) and run `mix compile --force` before debugging the source.
- **Files modified:** None (build-cache transient)
- **Verification:** `mix compile --force && mix test test/rindle/api_surface_boundary_test.exs` exits 0.
- **Committed in:** `2e3a4a5` (Task 2 commit — no source change attributable to this issue)

---

**Total deviations:** 2 noted (1 acceptance-criterion proxy mismatch — Rule 1 documented but no source change required; 1 stale-cache transient — Rule 1 documented, force-rebuild resolved).
**Impact on plan:** None. Both deviations are bookkeeping notes — the must-haves and success criteria of the plan are met:
- 7 named result types on `Rindle.Storage` ✓
- 6 `@type` aliases on `Rindle.Upload.Broker` ✓
- 8 facade `@specs` use schema struct types ✓
- All error branches retain `{:error, term()}` (encoded directly in 5 places + via named aliases in 4 places — semver guard intact) ✓
- Dialyzer / ExDoc / boundary test all green ✓

## Issues Encountered

- **Acceptance-criterion literal count was 5, not ≥ 12.** Documented as deviation #1 with full reasoning — the criterion was a proxy that the chosen D-05 named-alias implementation collapses; the underlying semver invariant is preserved.
- **Stale BEAM caused a transient false-fail.** Documented as deviation #2; `mix compile --force` resolved.
- **Plan 18-01 RED harness still reports `5 tests, 4 failures`.** This is the desired state — Plan 18-05 ratchets `.doctor.exs` to D-07 thresholds and turns those green. Confirmed unchanged by this plan.

## User Setup Required

None — type-spec tightening only, no external service or runtime change.

## Next Phase Readiness

- **Ready for Plan 18-03.** The named result-type aliases on `Rindle.Storage` (`presign_result`, `multipart_init_result`, etc.) and on `Rindle.Upload.Broker` (`verify_result`, `sign_url_result`, etc.) are the named return types Plan 18-03 will reference when adding per-callback `@doc`s and Broker public-function `@spec`s. No additional groundwork needed.
- **Dialyzer baseline tightened in adopter favor.** Adopters running Dialyzer against the published Hex package on next release will see `MediaAsset.t()` / `MediaUploadSession.t()` / `Broker.verify_result()` instead of opaque `map()` / `struct()`. This was the entire purpose of API-07 and D-03.
- **Semver posture (Phase 17 D-08) preserved.** Every error branch still resolves to `{:error, term()}`; no narrowing means no Dialyzer-breaking change for adopters pattern-matching on error terms.

## Self-Check: PASSED

Verified:
- `lib/rindle/storage.ex` still exists with 7 named typedocs: FOUND
- `lib/rindle/upload/broker.ex` still exists with 6 module-level `@type` aliases: FOUND
- `lib/rindle.ex` still exists with `MediaUploadSession` alias and 8 tightened `@spec`s: FOUND
- Commit `fc5e173` (Task 1: feat — 7 named result types on Rindle.Storage): FOUND
- Commit `2e3a4a5` (Task 2: feat — 6 Broker `@type` aliases + 8 tightened facade `@spec`s): FOUND
- `mix compile --warnings-as-errors` exits 0: VERIFIED
- `mix dialyzer --format github` exits 0 (Total errors: 5, Skipped: 5, Unnecessary Skips: 0): VERIFIED
- `mix docs --warnings-as-errors` exits 0: VERIFIED
- `mix test test/rindle/api_surface_boundary_test.exs` exits 0 (8 tests, 0 failures): VERIFIED
- `MIX_ENV=test mix doctor --full --raise` exits 0 (baseline thresholds still pass): VERIFIED
- Plan 18-01 RED harness `mix test test/rindle/doctor_thresholds_test.exs` still reports `5 tests, 4 failures`: VERIFIED (intentional — Plan 18-05 ratchets)

---
*Phase: 18-documentation-and-typespec-coverage*
*Completed: 2026-05-01*
