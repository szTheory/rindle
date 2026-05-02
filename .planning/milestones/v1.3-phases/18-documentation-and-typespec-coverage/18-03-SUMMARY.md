---
phase: 18-documentation-and-typespec-coverage
plan: 03
subsystem: docs, behaviour, public-api
tags: [exdoc, callback-doc, behaviour, named-types, public-adapter, elixir, doctor]

# Dependency graph
requires:
  - phase: 18-documentation-and-typespec-coverage
    plan: 01
    provides: doctor harness + .doctor.exs baseline (still RED at 4/5 thresholds — Plan 18-05 ratchets)
  - phase: 18-documentation-and-typespec-coverage
    plan: 02
    provides: 6 Broker named-type aliases + 7 Storage named result types (referenced by 18-03's new @specs)
provides:
  - "14 new @doc blocks: 10 on Rindle.Storage @callbacks + 4 on single-callback behaviours (Authorizer, Analyzer, Scanner, Processor)"
  - "6 @spec lines on Rindle.Upload.Broker public functions (initiate_session/2, initiate_multipart_session/2, sign_url/2, sign_multipart_part/3, complete_multipart_upload/3, verify_completion/2) referencing the Plan 18-02 named-type aliases"
  - "Rindle.Processor.Image promoted to public adapter (D-27): expanded @moduledoc, @impl Rindle.Processor, @spec on process/3, redundant per-function @doc removed, added to api_surface_boundary_test @public_modules, mix.exs ExDoc group renamed to 'Storage and Processor Adapters'"
  - "test/rindle/behaviour_docs_test.exs (D-19 backstop): 5 tests asserting every @callback on the 5 behaviour modules has a non-:none/non-:hidden @doc — passes"
  - "Doctor Total Spec Coverage rose to 98.7% (Broker is 100% spec-covered; previously the largest gap)"
affects:
  - 18-04-add-spec-on-private-public-callable
  - 18-05-ratchet-doctor-thresholds-and-flip-test-green

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-callback @doc blocks on behaviours — adopters reading hexdocs see callback contracts inline (D-11)"
    - "Adapter implementations inherit callback @doc from the behaviour-level declaration; concrete adapters use @impl Module + @spec without duplicating prose"
    - "Code.fetch_docs/1 backstop test for callback doc convention (D-19) — doctor doesn't analyze callback declarations, so a custom ExUnit assertion plays the role"
    - "Bundled-reference public adapter posture (D-27): Rindle.Processor.Image sits in the same ExDoc group as Rindle.Storage{,.Local,.S3}, mirroring the symmetric storage-adapter convention"

key-files:
  created:
    - "test/rindle/behaviour_docs_test.exs (5-test D-19 backstop)"
  modified:
    - "lib/rindle/storage.ex (10 callback @doc blocks added)"
    - "lib/rindle/authorizer.ex (single-callback @doc)"
    - "lib/rindle/analyzer.ex (single-callback @doc)"
    - "lib/rindle/scanner.ex (single-callback @doc)"
    - "lib/rindle/processor.ex (single-callback @doc)"
    - "lib/rindle/upload/broker.ex (6 @spec lines)"
    - "lib/rindle/processor/image.ex (expanded @moduledoc + @impl + @spec; per-function @doc removed)"
    - "test/rindle/api_surface_boundary_test.exs (Rindle.Processor.Image added to @public_modules)"
    - "mix.exs (ExDoc group renamed Storage Adapters -> Storage and Processor Adapters; added Rindle.Processor.Image)"

key-decisions:
  - "Used the actual @callback parameter names from each behaviour file (e.g., `source` / `destination` for Processor, not plan's `source_path` / `destination_path`) when writing prose. The plan's prose was a guide; the behaviour signatures are authoritative."
  - "Force `mix compile --force` resolved a transient stale-BEAM `function_exported?(Rindle, :verify_completion, 2)` failure (same root cause documented in Plan 18-02 deviation #2). Logged as deviation here too."
  - "Removed the redundant per-function @doc on Rindle.Processor.Image.process/3 per D-11 — adapter implementations inherit the behaviour-level @callback @doc from Rindle.Processor (added in Task 1)."

patterns-established:
  - "@callback declarations in behaviours always carry a preceding @doc — enforced by the new behaviour_docs_test.exs (D-19) which Code.fetch_docs/1's every @callback across all 5 modules and refutes :none / :hidden."
  - "Public adapters use `@impl BehaviourModule` (named form, e.g. `@impl Rindle.Processor`) rather than `@impl true` — explicit form makes the contract relationship navigable in hexdocs."
  - "Public adapter @moduledoc structure: lead paragraph (what + library used), 'bundled reference adapter' positioning paragraph, then ## Recognized {opts} keys, ## Supported modes, ## Format inference subsections — copy from Rindle.Processor.Image."

requirements-completed: [API-06, API-07]

# Metrics
duration: 7min
completed: 2026-05-01
---

# Phase 18 Plan 03: Add Function @doc and @spec on Public Surface Summary

**14 callback @doc blocks landed across 5 behaviour modules, 6 missing Broker @specs added (closing D-02's biggest gap — Broker spec coverage now 100%), Rindle.Processor.Image promoted to formally public adapter (D-27), and behaviour_docs_test.exs (D-19) backstop committed and green at 5 tests, 0 failures.**

## Performance

- **Duration:** ~7 min
- **Started:** 2026-05-01T01:46:58Z
- **Completed:** 2026-05-01T01:53:05Z
- **Tasks:** 2
- **Files modified:** 9 (1 created, 8 modified)

## Accomplishments

- 10 new `@doc` blocks above the 10 `@callback`s on `Rindle.Storage` (`capabilities/0` already had `@doc` from before this plan).
- 4 new `@doc` blocks above the single `@callback` on each of `Rindle.Authorizer`, `Rindle.Analyzer`, `Rindle.Scanner`, `Rindle.Processor`.
- 6 new `@spec` lines on `Rindle.Upload.Broker` public functions, referencing the Plan 18-02 named-type aliases (`session_only_result/0`, `initiate_multipart_result/0`, `sign_url_result/0`, `sign_part_result/0`, `verify_result/0`).
- `Rindle.Processor.Image` promoted to formally public adapter:
  - Expanded `@moduledoc` (lead paragraph + bundled-reference positioning + `## Recognized variant_spec keys` + `## Supported modes` + `## Format inference`).
  - `@impl Rindle.Processor` and `@spec process(Path.t(), map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}` added on `process/3`.
  - Redundant per-function `@doc """Processes an image..."""` removed (D-11 — adapter inherits callback `@doc`).
  - Added to `test/rindle/api_surface_boundary_test.exs` `@public_modules` list (boundary test now guards visibility).
  - `mix.exs` ExDoc group `Storage Adapters` renamed to `Storage and Processor Adapters` and `Rindle.Processor.Image` added alongside `Rindle.Storage`, `Rindle.Storage.Local`, `Rindle.Storage.S3`.
- `test/rindle/behaviour_docs_test.exs` created — D-19 backstop using `Code.fetch_docs/1` over compiled BEAM. Iterates 5 behaviour modules, asserts every `@callback` has a non-`:none`/non-`:hidden` `@doc`. Reports `5 tests, 0 failures`.
- `mix compile --warnings-as-errors` exits 0.
- `mix dialyzer --format github` exits 0 (`Total errors: 5, Skipped: 5, Unnecessary Skips: 0` — same baseline as Plan 18-02; no new warnings).
- `mix docs --warnings-as-errors` exits 0 (callback docs render in ExDoc; new ExDoc group renders correctly).
- `mix test test/rindle/api_surface_boundary_test.exs` exits 0 (8 tests, 0 failures — boundary intact, `Rindle.Processor.Image` visibility guarded).
- `mix test test/rindle/behaviour_docs_test.exs` exits 0 (5 tests, 0 failures).
- `MIX_ENV=test mix doctor --full --raise` exits 0 with `Total Doc Coverage: 83.1%`, `Total Moduledoc Coverage: 100.0%`, `Total Spec Coverage: 98.7%`. `Rindle.Upload.Broker` is now 100% spec-covered (was the largest D-02 gap).
- Plan 18-01 RED harness `mix test test/rindle/doctor_thresholds_test.exs` still reports `5 tests, 4 failures` — Plan 18-05 ratchet target intact.

## Task Commits

Each task was committed atomically (single-repo, no sub_repos):

1. **Task 1: Add @doc to behaviour callbacks + behaviour_docs_test backstop** — `3929f25` (feat)
2. **Task 2: Add 6 Broker @specs + promote Rindle.Processor.Image (D-27)** — `f4fefbd` (feat)

## The 14 Callback @doc Topic Lines (committed verbatim)

### Rindle.Storage (10 callbacks)

| Callback | Topic line (first sentence) |
|----------|-----------------------------|
| `store/3` | "Stores the file at `source` under `key`, returning adapter-specific write metadata." |
| `download/3` | "Downloads the object at `key` to `destination`, returning the destination path." |
| `delete/2` | "Deletes the object at `key`." |
| `url/2` | "Resolves the delivery URL for `key`." |
| `presigned_put/3` | "Generates a presigned PUT URL adopters can hand to clients for direct uploads." |
| `initiate_multipart_upload/3` | "Initiates a multipart upload session for `key` with the given `part_size`." |
| `presigned_upload_part/5` | "Generates a presigned URL for one part of an in-progress multipart upload." |
| `complete_multipart_upload/4` | "Finalizes a multipart upload after all parts have been uploaded." |
| `abort_multipart_upload/3` | "Aborts an in-progress multipart upload, releasing storage-side resources." |
| `head/2` | "Returns object metadata (size, content-type) without downloading the body." |

`capabilities/0`'s pre-existing `@doc` was retained unchanged.

### Single-callback behaviours (4)

| Behaviour | Topic line |
|-----------|-----------|
| `Rindle.Authorizer.authorize/3` | "Authorizes a delivery action for an actor against a subject." |
| `Rindle.Analyzer.analyze/1` | "Analyzes the file at `source` and returns enrichment metadata." |
| `Rindle.Scanner.scan/1` | "Scans the file at `path` for malware or policy violations." |
| `Rindle.Processor.process/3` | "Processes a source file according to a variant spec, writing the result to `destination`." |

Each topic line is followed by 1-2 sentences explaining caller responsibility, capability requirements (e.g., `:multipart_upload`, `:presigned_put`, `:head`), and the Phase 17 D-08 storage-I/O-outside-DB-transactions invariant where applicable.

## The 6 Broker @spec Rewrites (committed verbatim)

```elixir
@spec initiate_session(module(), keyword()) :: session_only_result()
@spec initiate_multipart_session(module(), keyword()) :: initiate_multipart_result()
@spec sign_url(binary(), keyword()) :: sign_url_result()
@spec sign_multipart_part(binary(), pos_integer(), keyword()) :: sign_part_result()
@spec complete_multipart_upload(binary(), [map()], keyword()) :: verify_result()
@spec verify_completion(binary(), keyword()) :: verify_result()
```

Each `@spec` was placed immediately after the existing `@doc """..."""` block and immediately before the corresponding `def`, mirroring `lib/rindle/delivery.ex` placement. `grep -c '@spec ' lib/rindle/upload/broker.ex` reports `6`.

The named aliases (`session_only_result`, `initiate_multipart_result`, `sign_url_result`, `sign_part_result`, `verify_result`) were declared as module-local `@type`s in Plan 18-02 — they encode `{:ok, ...} | {:error, term()}` once per alias, preserving the Phase 17 D-08 semver guard.

## Rindle.Processor.Image Diff

### @moduledoc — before

```elixir
@moduledoc """
Image processor adapter using the Image library (powered by libvips/Vix).
"""
```

### @moduledoc — after

```elixir
@moduledoc """
Image processor adapter using the [Image](https://hex.pm/packages/image) library
(powered by libvips/Vix).

This is Rindle's bundled reference processor — symmetric with `Rindle.Storage.S3`
and `Rindle.Storage.Local` for the `Rindle.Storage` behaviour. Adopters can
swap in a custom processor by implementing `Rindle.Processor` and configuring
the profile's `:processor` option, but most use cases are well-served by this
adapter.

## Recognized variant_spec keys

The `variant_spec` map passed to `process/3` recognizes these keys:

  * `:width` — target width in pixels (`pos_integer()`)
  * `:height` — target height in pixels (`pos_integer()`)
  * `:mode` — resize strategy, one of `:fit`, `:crop`, `:fill` (default: `:fit`)
  * `:format` — output format, one of `:jpg`, `:png`, `:webp`, or a string
    extension. When omitted, format is inferred from `destination_path`'s extension.
  * `:quality` — output quality, `1..100` (default: `80`)

## Supported modes

  * `:fit` — resize the image to fit within `:width` x `:height`, preserving aspect ratio
  * `:crop` — crop the image to exactly `:width` x `:height`, centered
  * `:fill` — like `:crop` but optimized for filling the target dimensions

## Format inference

When `:format` is omitted from `variant_spec`, the adapter infers the format
from `destination_path`'s file extension via `Path.extname/1`. Recognized
extensions: `.jpg` / `.jpeg` -> JPEG, `.png` -> PNG, `.webp` -> WebP. Unknown
extensions fall back to libvips's default for the file extension.
"""
```

### @impl + @spec — before (per-function @doc, no @impl, no @spec)

```elixir
@behaviour Rindle.Processor

@doc """
Processes an image from source_path to destination_path according to variant_spec.
"""
def process(source_path, variant_spec, destination_path) do
```

### @impl + @spec — after (per-function @doc removed; @impl + @spec added)

```elixir
@behaviour Rindle.Processor

@impl Rindle.Processor
@spec process(Path.t(), map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}
def process(source_path, variant_spec, destination_path) do
```

The redundant `@doc """Processes an image..."""` was removed per D-11 (adapter inherits the behaviour-level `@callback`'s `@doc` added in Task 1, which now reads "Processes a source file according to a variant spec, writing the result to `destination`.").

## test/rindle/api_surface_boundary_test.exs Diff

```diff
     Rindle.Scanner,
     Rindle.Processor,
+    Rindle.Processor.Image,
     Mix.Tasks.Rindle.AbortIncompleteUploads,
```

The existing `visible_module?/1` test (under "compiled docs boundary" describe block) automatically guards `Rindle.Processor.Image`'s visibility against accidental hiding.

## mix.exs groups_for_modules Diff

```diff
-        "Storage Adapters": [
+        "Storage and Processor Adapters": [
           Rindle.Storage,
           Rindle.Storage.Local,
-          Rindle.Storage.S3
+          Rindle.Storage.S3,
+          Rindle.Processor.Image
         ],
```

The `Rindle.Processor` behaviour stays in the existing "Extension Points" group — only the *adapter* `Rindle.Processor.Image` joins the unified group, mirroring how `Rindle.Storage` (behaviour) sits with its adapters.

## behaviour_docs_test.exs Test Count and Pass Status

`test/rindle/behaviour_docs_test.exs` was created at the exact body specified in the plan (Step 3, Task 1). It iterates `@behaviour_modules = [Rindle.Storage, Rindle.Authorizer, Rindle.Analyzer, Rindle.Scanner, Rindle.Processor]` and dynamically generates one ExUnit `test "every @callback in #{inspect(module)} has a non-hidden @doc"` per module via `unquote/1` inside a `for` loop. Each test:

1. Loads compiled docs via `Code.fetch_docs/1`.
2. Filters the `docs` list for `{{:callback, _, _}, ...}` entries.
3. Asserts the callback list is non-empty.
4. Refutes `doc in [:none, :hidden]` for every callback.

```
$ mix test test/rindle/behaviour_docs_test.exs --color
Running ExUnit with seed: 991346, max_cases: 16
Excluding tags: [:integration, :minio, :contract, :adopter]

.....
Finished in 0.01 seconds (0.01s async, 0.00s sync)
5 tests, 0 failures
```

## Doctor Output Snapshot (Clean)

```
Summary:
Passed Modules: 34
Failed Modules: 0
Total Doc Coverage: 83.1%
Total Moduledoc Coverage: 100.0%
Total Spec Coverage: 98.7%

Doctor validation has passed!
```

`Rindle.Upload.Broker` row: `100%/100%` doc/spec coverage (was the largest D-02 gap before this plan).

## Decisions Made

- **Keep callback parameter names in @doc prose aligned with the actual @callback signatures.** The plan's prose used `source_path`/`destination_path` for `Rindle.Processor.process/3` but the actual `@callback` declares `source`/`destination`. Updated the @doc prose to refer to `source` and `destination` to match the signature; semantics unchanged.
- **Use `@impl Rindle.Processor` (named form) on Rindle.Processor.Image.** The named form makes the behaviour relationship navigable in hexdocs, matching the plan's literal acceptance criterion `grep -F '@impl Rindle.Processor'`. `Rindle.Storage.Local`/`Rindle.Storage.S3` use `@impl true`, but the plan asks for the named form here per D-27 acceptance criteria.
- **Force-rebuild on first verify run.** First test run after editing `lib/rindle.ex`-adjacent files showed a transient `function_exported?(Rindle, :verify_completion, 2)` false-fail — the same stale-BEAM artifact documented in Plan 18-02 deviation #2. `mix compile --force` rebuilt all 47 modules and the test went green: 8 tests, 0 failures.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Stale BEAM cache caused a transient `function_exported?(Rindle, :verify_completion, 2)` false-fail (same root cause as Plan 18-02 deviation #2)**
- **Found during:** Task 2 verification
- **Issue:** First run of `mix test test/rindle/api_surface_boundary_test.exs` after editing `mix.exs` (ExDoc group rename) and `test/rindle/api_surface_boundary_test.exs` (added `Rindle.Processor.Image` to `@public_modules`) reported `1 failure` on `assert function_exported?(Rindle, :verify_completion, 2)`. `Rindle.verify_completion/2` was unchanged in this plan and the source still defines `def verify_completion(session_id, opts \\ [])`.
- **Root cause:** Mix incremental compile reused a stale `Elixir.Rindle.beam`. Forcing a full rebuild with `mix compile --force` cleared the cache; the test then ran 8 tests, 0 failures.
- **Fix:** None at the source level — this is a build-cache transient, not a regression.
- **Files modified:** None (build-cache only)
- **Verification:** `mix compile --force && mix test test/rindle/api_surface_boundary_test.exs` exits 0 with 8 tests, 0 failures.
- **Committed in:** `f4fefbd` (Task 2 — no source change attributable to this issue; build cache only)

**2. [Rule 1 - Plan-prose-vs-source-signature mismatch] Adjusted `Rindle.Processor.process/3` callback @doc to use `source` and `destination` parameter names (not `source_path` / `destination_path`)**
- **Found during:** Task 1 (writing the `Rindle.Processor` callback @doc)
- **Issue:** The plan's prose used `source_path` and `destination_path`, but `lib/rindle/processor.ex` declares `@callback process(source :: Path.t(), variant_spec :: map(), destination :: Path.t())`. Writing prose that referred to `source_path`/`destination_path` would have left the @doc inconsistent with the parameter names visible in hexdocs from the `@callback` declaration.
- **Fix:** Substituted `source` and `destination` in the prose. Same semantic content, parameter names aligned with the canonical `@callback` declaration.
- **Files modified:** `lib/rindle/processor.ex`
- **Verification:** `mix test test/rindle/behaviour_docs_test.exs` exits 0; the @doc renders cleanly in `mix docs --warnings-as-errors`.
- **Committed in:** `3929f25` (Task 1)

---

**Total deviations:** 2 noted (1 stale-cache transient — Rule 1 documented, force-rebuild resolved; 1 plan-prose-vs-source-signature mismatch — Rule 1 documented, prose adjusted to match canonical signature).
**Impact on plan:** None on goals. Both deviations are bookkeeping notes — the must-haves and success criteria of the plan are met:
- 14 callback @doc blocks (10 + 4) ✓
- 6 Broker @specs ✓
- Rindle.Processor.Image promoted (expanded @moduledoc, @impl, @spec, @public_modules, ExDoc group) ✓
- behaviour_docs_test.exs exists, uses Code.fetch_docs/1, passes 5 tests ✓
- Dialyzer / ExDoc / boundary test / doctor all green ✓

## Issues Encountered

- **Stale BEAM caused a transient false-fail on `function_exported?` assertion.** Documented as deviation #1; `mix compile --force` resolved.
- **Plan 18-01 RED harness still reports `5 tests, 4 failures`.** This is the desired state — Plan 18-05 ratchets `.doctor.exs` thresholds to D-07 targets and turns these green. Confirmed unchanged by this plan.
- **First-run worktree `mix deps.get` was required** (worktree filesystem isolation — deps not yet fetched). Resolved automatically; no source changes.

## User Setup Required

None — documentation/typespec phase only, no external service or runtime change.

## Next Phase Readiness

- **Ready for Plan 18-04.** Plan 18-04 adds `@spec` annotations on private-but-public-callable functions; this plan closed the largest concentrated `@spec` gap (Broker), bringing `Total Spec Coverage` to `98.7%`. The remaining gaps are smaller and per-module.
- **Doctor remains GREEN at baseline.** `MIX_ENV=test mix doctor --full --raise` exits 0; the threshold ratchet is still owned by Plan 18-05.
- **D-19 backstop in place.** Any future regression that hides or removes a callback `@doc` will fail `test/rindle/behaviour_docs_test.exs` immediately, well before adopters see degraded hexdocs.

## Self-Check: PASSED

Verified:
- `lib/rindle/storage.ex` has 11 callbacks with preceding @doc blocks (10 added in this plan + 1 pre-existing capabilities/0): VERIFIED via `awk '/@doc """/{f=1; next} /@callback/{if(f){c++}; f=0} END{exit (c<10)?1:0}'` exits 0
- `lib/rindle/authorizer.ex` callback has preceding @doc: VERIFIED
- `lib/rindle/analyzer.ex` callback has preceding @doc: VERIFIED
- `lib/rindle/scanner.ex` callback has preceding @doc: VERIFIED
- `lib/rindle/processor.ex` callback has preceding @doc: VERIFIED
- `test/rindle/behaviour_docs_test.exs` FOUND
- `Rindle.BehaviourDocsTest` symbol present: VERIFIED
- `Code.fetch_docs` referenced in test: VERIFIED
- 6 @spec lines on `lib/rindle/upload/broker.ex` (`grep -c '@spec ' = 6`): VERIFIED
- All 6 named aliases referenced (session_only_result, initiate_multipart_result, sign_url_result, sign_part_result, verify_result): VERIFIED
- `@impl Rindle.Processor` and `@spec process(Path.t(), map(), Path.t())` on `lib/rindle/processor/image.ex`: VERIFIED
- "Recognized variant_spec keys", "Supported modes", `:fit` all present in `lib/rindle/processor/image.ex`: VERIFIED
- `Rindle.Processor.Image` in `test/rindle/api_surface_boundary_test.exs` `@public_modules`: VERIFIED
- `"Storage and Processor Adapters":` in `mix.exs` containing `Rindle.Processor.Image`: VERIFIED
- Old `"Storage Adapters":` group name removed: VERIFIED
- Commit `3929f25` (Task 1: feat — 14 callback @docs + behaviour_docs_test.exs): FOUND
- Commit `f4fefbd` (Task 2: feat — 6 Broker @specs + Rindle.Processor.Image promotion): FOUND
- `mix compile --warnings-as-errors` exits 0: VERIFIED
- `mix dialyzer --format github` exits 0 (Total errors: 5, Skipped: 5, Unnecessary Skips: 0): VERIFIED
- `mix docs --warnings-as-errors` exits 0: VERIFIED
- `mix test test/rindle/api_surface_boundary_test.exs` exits 0 (8 tests, 0 failures): VERIFIED
- `mix test test/rindle/behaviour_docs_test.exs` exits 0 (5 tests, 0 failures): VERIFIED
- `MIX_ENV=test mix doctor --full --raise` exits 0 (Total Spec Coverage 98.7%): VERIFIED
- Plan 18-01 RED harness `mix test test/rindle/doctor_thresholds_test.exs` still reports `5 tests, 4 failures`: VERIFIED (intentional — Plan 18-05 ratchets)

---
*Phase: 18-documentation-and-typespec-coverage*
*Completed: 2026-05-01*
