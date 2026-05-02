---
phase: 18-documentation-and-typespec-coverage
plan: 04
subsystem: docs, public-api, profile-dsl, html-helper, workers, mix-tasks
tags: [exdoc, doc, spec, macro, picture-tag, oban-worker, deprecated, mix-task, readme, doctor, elixir]

# Dependency graph
requires:
  - phase: 18-documentation-and-typespec-coverage
    plan: 02
    provides: named-type aliases (referenced indirectly — narrowed worker `@spec`s use Oban.Job.t() rather than Broker named types, but the pattern of narrowing was established by 18-02)
  - phase: 18-documentation-and-typespec-coverage
    plan: 03
    provides: behaviour `@doc` patterns mirrored in this plan (D-11) — adapter `@impl Module` (named form), `@spec` narrowing, `@moduledoc` as worker contract source
provides:
  - "Rindle.Profile.__using__/1: @doc with profile DSL example + @spec __using__(keyword()) :: Macro.t() (D-14)"
  - "Rindle.HTML.picture_tag/3: @doc with ## Options + ## Example (D-15)"
  - "Rindle.Workers.AbortIncompleteUploads.perform/1 + Rindle.Workers.CleanupOrphans.perform/1: narrowed @spec perform(Oban.Job.t()) :: :ok | {:error, term()} (D-13)"
  - "Rindle.log_variant_processing_failure/3: @deprecated attribute above @doc false (D-16) emitting compile-time deprecation warning"
  - "lib/rindle.ex internal caller (line 479) repointed from log_variant_processing_failure/3 to VariantFailureLogger.log/3 directly so mix compile --warnings-as-errors stays clean post-deprecation"
  - "README.md: ## Documentation conventions section with single-line @callback @doc convention note (D-20)"
  - "5 Mix.Tasks.Rindle.* modules verified canonical D-12 posture (no edits — @shortdoc + @moduledoc + use Mix.Task + @impl Mix.Task; no @doc/@spec on run/1)"
affects:
  - 18-05-ratchet-doctor-thresholds-and-flip-test-green

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Macro @doc/@spec pattern (thousand_island.handler.ex precedent — D-14): @doc above defmacro __using__/1 with `defmodule MyApp.* do use ... end` example block; @spec __using__(keyword()) :: Macro.t() avoids needing a doctor exemption"
    - "Picture-tag @doc with ## Options + ## Example (delivery.ex gold-standard voice — D-15): present-tense first sentence, options table, code example"
    - "Worker @spec narrowing without @doc (Plausible production pattern — D-13): @moduledoc is the contract source on Oban workers; perform/1 gets @spec narrowing Oban.Worker.result() but no per-function @doc"
    - "@deprecated attribute on hidden compatibility shims (D-16): emits compile-time warning at every call site; coexists distinctly with @doc deprecated: ExDoc badge on visible deprecations (Risk R-4 — DO NOT conflate)"

key-files:
  created: []
  modified:
    - "lib/rindle/profile.ex (+ 22 lines: @doc + @spec on __using__/1)"
    - "lib/rindle/html.ex (+ 21 lines: @doc on picture_tag/3 with ## Options and ## Example)"
    - "lib/rindle/workers/abort_incomplete_uploads.ex (+ 1 line: @spec perform/1)"
    - "lib/rindle/workers/cleanup_orphans.ex (+ 1 line: @spec perform/1)"
    - "lib/rindle.ex (+ 1 line @deprecated; 1 line repointed internal caller)"
    - "README.md (+ 4 lines: ## Documentation conventions section with @callback @doc convention)"

key-decisions:
  - "Repointed lib/rindle.ex line 479 from `log_variant_processing_failure(asset_id, variant_name, reason)` to `VariantFailureLogger.log(asset_id, variant_name, reason)` directly — this is the only internal caller of the now-@deprecated facade shim, and leaving it would have triggered `mix compile --warnings-as-errors` to fail. The plan anticipated this scenario (Task 2 Step 4 explicitly said: 'If a warning appears... fix the caller... within this task')."
  - "Used the literal D-20 line from the plan verbatim: 'Every public `@callback` must be preceded by `@doc \"\"\"...\"\"\"`. Use `@doc false` only for internal compatibility shims.' Placed under a new ## Documentation conventions section between '## GSD Hygiene' and '## License' (no Contributing section exists in README)."
  - "Used `@impl Oban.Worker` (named form) to remain consistent with each worker's existing posture (both already used the named form). The `@spec` line was placed *above* `@impl Oban.Worker` per the plan's exact placement instructions."

patterns-established:
  - "@deprecated above @doc false: the canonical posture for hidden compatibility shims kept for adopter Hex package compatibility — emits compile-time warning to any external caller while keeping the function out of hexdocs."
  - "Mix task canonical posture (D-12 verified): @shortdoc + @moduledoc + use Mix.Task + @impl Mix.Task on def run/1, with NO @doc and NO @spec on run/1. Doctor's `:ignore_paths` for `lib/mix/tasks/` already exempts these from coverage; the canonical posture means the exemption is a posture choice, not a coverage hack."
  - "Internal caller cleanup before adding @deprecated: when adding @deprecated to a function, scan `lib/` for any internal callers and repoint them to the underlying internal module FIRST — the @deprecated attribute itself becomes a build-breaking warning otherwise."

requirements-completed: [API-06]

# Metrics
duration: 5m2s
completed: 2026-05-01
---

# Phase 18 Plan 04: Add @doc/@spec on Private-but-Public-Callable + @deprecated Shim Summary

**1 macro doc/spec on Rindle.Profile.__using__/1, 1 helper doc on Rindle.HTML.picture_tag/3, 2 worker @spec narrowings (perform/1 → :ok | {:error, term()}), 1 @deprecated attribute on Rindle.log_variant_processing_failure/3 (with 1 internal caller repointed to keep mix compile --warnings-as-errors clean), 1 README convention line, and 5 Mix tasks verified canonical with no edits — closes the remaining D-02 gaps outside behaviour callbacks and the facade. Plan 18-05 now has nothing left blocking the threshold ratchet.**

## Performance

- **Duration:** ~5 minutes (302 seconds)
- **Started:** 2026-05-01T01:57:59Z
- **Completed:** 2026-05-01T02:03:01Z
- **Tasks:** 2
- **Files modified:** 6 (4 in Task 1; 2 in Task 2)

## Accomplishments

- `Rindle.Profile.__using__/1` now has `@doc """..."""` describing the profile DSL contract and a `@spec __using__(keyword()) :: Macro.t()` (D-14) — the doc example block uses literal `use Rindle.Profile, storage: ..., variants: ...` syntax, which renders as a hexdocs example block.
- `Rindle.HTML.picture_tag/3` now has `@doc """..."""` with `## Options` (3 documented option keys) and `## Example` (D-15) — preserving the existing `@spec` exactly.
- Both `Rindle.Workers.AbortIncompleteUploads.perform/1` and `Rindle.Workers.CleanupOrphans.perform/1` have a narrowed `@spec perform(Oban.Job.t()) :: :ok | {:error, term()}` placed above the existing `@impl Oban.Worker` (D-13). No `@doc` was added — per D-13, the `@moduledoc` is the contract source for Oban workers.
- `Rindle.log_variant_processing_failure/3` now has `@deprecated "Use Rindle.Internal.VariantFailureLogger.log/3 instead — facade shim kept for 0.1.x compatibility only"` immediately above `@doc false` (D-16), emitting a compile-time deprecation warning to any external caller.
- The only internal caller of `Rindle.log_variant_processing_failure/3` (lib/rindle.ex line 479, in `handle_variant_processing_result/3`) was repointed to `Rindle.Internal.VariantFailureLogger.log/3` directly so that `mix compile --warnings-as-errors` stays clean (the plan's Task 2 Step 4 anticipated this: "If a warning appears... fix the caller... within this task").
- All 5 `Mix.Tasks.Rindle.*` modules verified canonical (D-12 — verify only, no edits): each has `@shortdoc`, `@moduledoc`, `use Mix.Task`, `@impl Mix.Task`, and NO `@doc` or `@spec` on `def run/1`. (Files: `rindle.abort_incomplete_uploads.ex`, `rindle.backfill_metadata.ex`, `rindle.cleanup_orphans.ex`, `rindle.regenerate_variants.ex`, `rindle.verify_storage.ex`.)
- README.md gained a `## Documentation conventions` section between `## GSD Hygiene` and `## License` containing the single-line D-20 convention note: "Every public `@callback` must be preceded by `@doc \"\"\"...\"\"\"`. Use `@doc false` only for internal compatibility shims."
- Risk R-4 preserved: the existing `@doc deprecated: "Use verify_completion/2"` on `verify_upload/2` (lib/rindle.ex:103) is **unchanged**. The plan's distinction between `@deprecated` (compile-time warning, hidden shim) and `@doc deprecated:` (ExDoc badge, visible deprecation) was honored — these are distinct mechanisms applied to distinct shims.

### Gates (all green)

- `mix compile --warnings-as-errors` exits 0 (no compile-time deprecation warning slips through to break the build — internal caller repointed).
- `mix dialyzer --format github` exits 0 (`Total errors: 5, Skipped: 5, Unnecessary Skips: 0` — same baseline as Plans 18-02 and 18-03; the narrowed worker `@spec`s match actual returns).
- `mix docs --warnings-as-errors` exits 0 (Profile macro `@doc`, HTML helper `@doc`, and the new README section all render cleanly).
- `mix test test/rindle/api_surface_boundary_test.exs --color` exits 0 (8 tests, 0 failures — boundary intact, `verify_upload/2` Risk R-4 docs assertion unaffected).
- `mix test test/rindle/behaviour_docs_test.exs --color` exits 0 (5 tests, 0 failures — D-19 backstop still asserts every behaviour callback has a non-`:none`/`:hidden` `@doc`).
- `MIX_ENV=test mix doctor --full --raise` exits 0 (Total Doc Coverage **84.4%**, Total Moduledoc Coverage 100.0%, Total Spec Coverage 98.7%).

## Task Commits

Each task was committed atomically (single-repo, no sub_repos):

1. **Task 1: Add @doc/@spec to Profile macro and HTML helper, narrow worker @specs** — `5ae771a` (feat)
2. **Task 2: Add @deprecated to facade shim, repoint internal caller, add README convention note** — `ff9de1b` (feat)

## Verbatim Diffs

### `lib/rindle/profile.ex` — @doc + @spec added on __using__/1 (D-14)

```diff
   alias Rindle.Profile.Digest
   alias Rindle.Profile.Validator

+  @doc """
+  Declares a Rindle profile.
+
+  When `use`d, this macro validates the supplied options at compile time and
+  generates the `storage_adapter/0`, `variants/0`, `upload_policy/0`,
+  `validate_upload/1`, `delivery_policy/0`, and `recipe_digest/1` functions
+  that the rest of Rindle dispatches through.
+
+  ## Example
+
+      defmodule MyApp.AvatarProfile do
+        use Rindle.Profile,
+          storage: Rindle.Storage.S3,
+          allow_mime: ["image/png", "image/jpeg"],
+          max_bytes: 10_000_000,
+          delivery: %{public: false, signed_url_ttl_seconds: 900},
+          variants: %{thumb: %{width: 128, height: 128, format: :webp}}
+      end
+  """
+  @spec __using__(keyword()) :: Macro.t()
   defmacro __using__(opts) do
```

### `lib/rindle/html.ex` — @doc added on picture_tag/3 (D-15)

```diff
     import Phoenix.HTML, only: [raw: 1, html_escape: 1, safe_to_string: 1]

+    @doc """
+    Renders a `<picture>` element with `<source>` entries for each ready variant
+    and an `<img>` fallback to the original asset.
+
+    Variant order in `:variants` is preserved as the source order rendered into
+    the markup. Stale or non-ready variants are skipped — the fallback `<img>`
+    URL always resolves to the original asset.
+
+    ## Options
+
+      * `:variants` — list of `{name, media_query}` tuples, `%{name: ..., media: ...}`
+        maps, or bare atom variant names. Variants are rendered in the order given.
+      * `:placeholder` — string to use as the `src` attribute when no variant is
+        ready and the asset has no `:storage_key`.
+      * Any other key is rendered as a literal HTML attribute on the `<img>` tag.
+
+    ## Example
+
+        <%= Rindle.HTML.picture_tag(MyApp.AvatarProfile, asset,
+              variants: [{:thumb, "(max-width: 480px)"}, {:large, nil}],
+              alt: "User avatar"
+            ) %>
+    """
     @spec picture_tag(module(), map(), keyword()) :: Phoenix.HTML.safe()
     def picture_tag(profile, asset, opts \\ []) do
```

### `lib/rindle/workers/abort_incomplete_uploads.ex` — @spec added on perform/1 (D-13)

```diff
+  @spec perform(Oban.Job.t()) :: :ok | {:error, term()}
   @impl Oban.Worker
   def perform(%Oban.Job{}) do
```

### `lib/rindle/workers/cleanup_orphans.ex` — @spec added on perform/1 (D-13)

```diff
+  @spec perform(Oban.Job.t()) :: :ok | {:error, term()}
   @impl Oban.Worker
   def perform(%Oban.Job{args: args}) do
```

### `lib/rindle.ex` — @deprecated added on log_variant_processing_failure/3 (D-16) + internal caller repointed

```diff
       {:error, reason} = error ->
-        log_variant_processing_failure(asset_id, variant_name, reason)
+        VariantFailureLogger.log(asset_id, variant_name, reason)
         error
     end
   end

+  @deprecated "Use Rindle.Internal.VariantFailureLogger.log/3 instead — facade shim kept for 0.1.x compatibility only"
   @doc false
   @spec log_variant_processing_failure(term(), term(), term()) :: :ok
   def log_variant_processing_failure(asset_id, variant_name, reason) do
     VariantFailureLogger.log(asset_id, variant_name, reason)
   end
```

The repoint is functionally equivalent — `log_variant_processing_failure/3` itself just delegates to `VariantFailureLogger.log/3`. The change is purely about avoiding `mix compile --warnings-as-errors` tripping on the new `@deprecated` attribute.

### `README.md` — D-20 convention line added

```diff
+## Documentation conventions
+
+Every public `@callback` must be preceded by `@doc """..."""`. Use `@doc false` only for internal compatibility shims.
+
 ## License

 MIT
```

The new section is placed between `## GSD Hygiene` and `## License`. No existing "Contributing" section exists in README.md (verified by `grep -n "^##" README.md`), so a new heading was added per the plan's "If none exists, add a new section" guidance.

## Mix Tasks Verification (D-12 — no edits)

Each of the 5 task files was confirmed via automated assertions:

| File | `@shortdoc` | `@impl Mix.Task` | `@spec run(` | `@doc` before `def run/1` |
|------|-------------|------------------|--------------|---------------------------|
| `lib/mix/tasks/rindle.abort_incomplete_uploads.ex` | OK | OK | ABSENT (correct) | none (correct) |
| `lib/mix/tasks/rindle.backfill_metadata.ex` | OK | OK | ABSENT (correct) | none (correct) |
| `lib/mix/tasks/rindle.cleanup_orphans.ex` | OK | OK | ABSENT (correct) | none (correct) |
| `lib/mix/tasks/rindle.regenerate_variants.ex` | OK | OK | ABSENT (correct) | none (correct) |
| `lib/mix/tasks/rindle.verify_storage.ex` | OK | OK | ABSENT (correct) | none (correct) |

All 5 files match the canonical D-12 posture — no edits required.

## `mix compile --warnings-as-errors` Confirmation Re: @deprecated

The plan's Task 2 Step 4 explicitly noted: "The `@deprecated` attribute may emit a compile-time deprecation warning if any internal code calls `Rindle.log_variant_processing_failure/3` directly... If a warning appears, document the caller in the plan summary".

**An internal caller existed** at `lib/rindle.ex:479` inside `handle_variant_processing_result/3`:

```elixir
{:error, reason} = error ->
  log_variant_processing_failure(asset_id, variant_name, reason)
  error
```

Because the function was being defined and called within the same module, adding `@deprecated` would have caused `mix compile --warnings-as-errors` to fail. Per Task 2 Step 4's guidance ("If that happens, fix the caller (point to `Rindle.Internal.VariantFailureLogger.log/3` directly) within this task"), the caller was repointed to call `VariantFailureLogger.log/3` directly. Both call sites do the same thing — `log_variant_processing_failure/3` itself just delegates to `VariantFailureLogger.log/3` — so there is no behavior change.

After the repoint, `mix compile --warnings-as-errors` exits 0. No external Hex-API caller exists in `lib/`, so no other fix was needed.

## Doctor Output Snapshot (Clean)

```
Summary:
Passed Modules: 34
Failed Modules: 0
Total Doc Coverage: 84.4%
Total Moduledoc Coverage: 100.0%
Total Spec Coverage: 98.7%

Doctor validation has passed!
```

Notable per-module rows after this plan:

- `Rindle.HTML` row: `100% / 100%` doc/spec coverage (was missing `@doc` on `picture_tag/3` before this plan).
- `Rindle.Workers.AbortIncompleteUploads` row: `100% / 100%` doc/spec (was missing `@spec` on `perform/1`).
- `Rindle.Workers.CleanupOrphans` row: `100% / 100%` doc/spec (was missing `@spec` on `perform/1`).
- `Rindle.Profile` row: `0% / 100%` (the doc% in doctor's per-module column counts public function `@doc` blocks; the `__using__/1` macro is not counted there but the `@spec` raises the spec column). The macro `@doc` IS visible in hexdocs and IS counted by Total Doc Coverage — confirmed by the Total rising to 84.4% (was 83.1% in 18-03).

Total Doc Coverage rose from 83.1% (post-18-03) to **84.4%** (post-18-04) — 1.3pp improvement from this plan's `@doc` blocks on the macro and the HTML helper. This is well above the doctor baseline that Plan 18-05 will ratchet.

Plan 18-01 RED harness `mix test test/rindle/doctor_thresholds_test.exs` was NOT run in this plan's verification (the plan does not list it as a gate); per 18-03 it should still report `5 tests, 4 failures` — Plan 18-05's ratchet target.

## Decisions Made

- **Repointed lib/rindle.ex line 479 to call VariantFailureLogger.log/3 directly.** The plan's Task 2 Step 4 anticipated this and gave explicit guidance ("If a warning appears... fix the caller... within this task"). The change is functionally equivalent — `log_variant_processing_failure/3` itself only delegates to `VariantFailureLogger.log/3`. No behavior change; only the `@deprecated` build-failure prevention.
- **Placed README convention line under a new ## Documentation conventions section.** The plan offered two options (append to existing "Contributing" section if exists, or create new section). No "Contributing" section exists in README.md (verified by `grep -n "^##" README.md`), so the new section was created between `## GSD Hygiene` and `## License`. The section header avoids "Contributing" because the README never positions the project as accepting contributions in that format — `## Documentation conventions` is more accurate to what the line is.
- **Did not run mix test test/rindle/doctor_thresholds_test.exs.** It is the Plan 18-01 RED harness designed to remain RED until Plan 18-05 ratchets `.doctor.exs` thresholds. The plan's `<verification>` section explicitly notes: "mix test test/rindle/doctor_thresholds_test.exs still fails (RED harness — turns green only at Plan 18-05)". Running it would only confirm the expected RED state — not a verification gate for this plan.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Internal caller of @deprecated function would have broken `mix compile --warnings-as-errors`**
- **Found during:** Task 2 Step 1 (adding `@deprecated` to `log_variant_processing_failure/3`)
- **Issue:** Adding `@deprecated` to `log_variant_processing_failure/3` triggers a compile-time deprecation warning at every caller. `lib/rindle.ex:479` (inside `handle_variant_processing_result/3`) was calling `log_variant_processing_failure(asset_id, variant_name, reason)` directly — this would have caused `mix compile --warnings-as-errors` to fail.
- **Fix:** Repointed line 479 to call `VariantFailureLogger.log(asset_id, variant_name, reason)` directly. Functionally equivalent — `log_variant_processing_failure/3` itself just delegates to `VariantFailureLogger.log/3`.
- **Why this is a Rule 1 bug fix and not architectural (Rule 4):** Plan 18-04 Task 2 Step 4 explicitly anticipated this scenario and provided exact guidance: "If a warning appears, document the caller in the plan summary... `mix compile --warnings-as-errors` will fail if a real caller exists. If that happens, fix the caller (point to `Rindle.Internal.VariantFailureLogger.log/3` directly) within this task." So this isn't a deviation from the plan — it's an anticipated plan path being followed.
- **Files modified:** `lib/rindle.ex` (1 line repointed)
- **Verification:** `mix compile --warnings-as-errors` exits 0 after the repoint.
- **Committed in:** `ff9de1b` (Task 2 commit)

---

**Total deviations:** 1 noted (anticipated by the plan and explicitly handled per its Task 2 Step 4 guidance).

**Impact on plan:** None on goals. All must-haves and success criteria of the plan are met:

- Rindle.Profile.__using__/1 has @doc and @spec __using__(keyword()) :: Macro.t() ✓
- Rindle.HTML.picture_tag/3 has @doc with ## Options and ## Example ✓
- Both Rindle.Workers.* perform/1 have @spec perform(Oban.Job.t()) :: :ok | {:error, term()} ✓
- Rindle.log_variant_processing_failure/3 has @deprecated attribute above @doc false ✓
- 5 Mix tasks verified canonical (no edits — D-12 posture already correct) ✓
- README.md has the D-20 single-line callback @doc convention note ✓
- All gates green; doctor passes baseline thresholds ✓

## Issues Encountered

- **First-run worktree `mix deps.get` was required** (worktree filesystem isolation — deps not yet fetched). Resolved automatically; no source changes.
- **Internal caller of `log_variant_processing_failure/3` had to be repointed.** Documented as deviation #1 above; the plan anticipated this and the fix is functionally equivalent.

## User Setup Required

None — documentation/typespec phase only, no external service or runtime change. The new `@deprecated` attribute will emit a compile-time warning to **adopters** who call `Rindle.log_variant_processing_failure/3` directly from their codebase, which is the desired DX signal (the function was never advertised in the public API and was only kept for 0.1.x compatibility per its existing `@doc false`).

## Next Phase Readiness

- **Ready for Plan 18-05.** Phase 18's threshold-ratchet plan now has nothing left blocking it: every D-02 gap outside the doctor baseline has been closed (named result types in 18-02, behaviour callback @docs + Broker @specs in 18-03, macro/HTML/workers/shim/README in 18-04). Total Doc Coverage 84.4%, Total Spec Coverage 98.7%, Total Moduledoc Coverage 100% — well above any reasonable D-07 ratchet target.
- **Doctor remains GREEN at baseline.** `MIX_ENV=test mix doctor --full --raise` exits 0; the threshold ratchet is owned by Plan 18-05.
- **D-19 backstop still passes.** `mix test test/rindle/behaviour_docs_test.exs` reports 5 tests, 0 failures — Plan 18-04 did not regress any callback `@doc`.
- **Risk R-4 preserved.** The existing `@doc deprecated: "Use verify_completion/2"` on `verify_upload/2` is unchanged; the new `@deprecated` on `log_variant_processing_failure/3` is a *distinct* mechanism on a *distinct* shim.

## Self-Check: PASSED

Verified files:
- `lib/rindle/profile.ex` has @doc preceding `defmacro __using__` AND `@spec __using__(keyword()) :: Macro.t()`: FOUND
- `lib/rindle/html.ex` has @doc preceding `@spec picture_tag` AND contains `## Options` and `## Example`: FOUND
- `lib/rindle/workers/abort_incomplete_uploads.ex` has `@spec perform(Oban.Job.t()) :: :ok | {:error, term()}`: FOUND
- `lib/rindle/workers/cleanup_orphans.ex` has `@spec perform(Oban.Job.t()) :: :ok | {:error, term()}`: FOUND
- `lib/rindle.ex` has `@deprecated "Use Rindle.Internal.VariantFailureLogger.log/3 instead...` immediately above `@doc false`: FOUND
- `lib/rindle.ex` line 479 repointed to `VariantFailureLogger.log(asset_id, variant_name, reason)` (no internal call to `log_variant_processing_failure/3` remains): VERIFIED via `grep -n "log_variant_processing_failure" lib/rindle.ex` showing only the @spec and def lines (485-486)
- `lib/rindle.ex` line 103 still has `@doc deprecated: "Use verify_completion/2"` on verify_upload/2 (Risk R-4 preserved): FOUND
- 5 Mix task files all have `@shortdoc` + `@impl Mix.Task`, NO `@spec run(`, NO `@doc` preceding `def run/1`: VERIFIED
- `README.md` has `## Documentation conventions` section containing literal `@callback` line: FOUND

Verified commits:
- Commit `5ae771a` (Task 1: feat — Profile @doc/@spec, HTML @doc, both worker @specs): FOUND in `git log --oneline`
- Commit `ff9de1b` (Task 2: feat — @deprecated, repoint, README convention): FOUND in `git log --oneline`

Verified gates:
- `mix compile --warnings-as-errors` exits 0: VERIFIED
- `mix dialyzer --format github` exits 0 (Total errors: 5, Skipped: 5, Unnecessary Skips: 0): VERIFIED
- `mix docs --warnings-as-errors` exits 0: VERIFIED
- `mix test test/rindle/api_surface_boundary_test.exs --color` exits 0 (8 tests, 0 failures): VERIFIED
- `mix test test/rindle/behaviour_docs_test.exs --color` exits 0 (5 tests, 0 failures): VERIFIED
- `MIX_ENV=test mix doctor --full --raise` exits 0 (Total Doc Coverage 84.4%, Total Moduledoc Coverage 100%, Total Spec Coverage 98.7%): VERIFIED

---
*Phase: 18-documentation-and-typespec-coverage*
*Completed: 2026-05-01*
