# Phase 19: Convenience API Additions - Context

**Gathered:** 2026-04-30 (assumptions mode + 3 parallel research subagents: codebase analysis, Elixir bang-variant idioms, cross-language helper patterns)
**Status:** Ready for planning

<domain>
## Phase Boundary

Add concise read-side helpers (`Rindle.attachment_for/2`, `Rindle.ready_variants_for/1`) and bang variants (`attach!/4`, `detach!/3`, `upload!/3`, `url!/3`, `variant_url!/4`) to the locked Phase 17 public surface so adopters do not need to write raw Ecto queries or manually unwrap `{:ok, _} | {:error, _}` tuples on the happy path.

This phase does **not** rename anything (Phase 17 D-08 / D-09 stand), does **not** alter existing function signatures (additive only on `0.1.x`), does **not** change observability posture (Phase 17 D-13 stands — telemetry-first, not a logging-helper expansion), does **not** introduce write-side helpers beyond the bangs (e.g., no `attach_or_replace/4`, no `upload_async/3`), and does **not** broaden the operational surface (Phase 17 D-06 keeps `Rindle.Ops.*` hidden).
</domain>

<decisions>
## Implementation Decisions

### `attachment_for/2` semantics (API-09)

- **D-01:** `Rindle.attachment_for(owner, slot, opts \\ [])` is a 3-arity public function on the `Rindle` facade. Returns `MediaAttachment.t() | nil` — `nil` when no attachment exists for the `(owner_type, owner_id, slot)` tuple. This matches `Ecto.Repo.get_by/2`, Shrine (`user.image` → `nil`), and Spatie Media Library (`getFirstMedia` → `null`). It explicitly **rejects** the Active Storage "always-a-proxy / never-nil" pattern, which is widely cited as a footgun (forces `attached?` checks; conflates "not attached" with "broken attachment").
- **D-02:** `attachment_for/2` **auto-preloads `:asset` by default**. The join row alone is inert (only `asset_id` / `owner_*` / `slot`); the helper's stated purpose in API-09 is "fetch an attachment without writing a raw Ecto query," and the only useful thing to do with the result is render or query the attached asset. Pre-empts Active Storage's #1 cited footgun (forgetting to preload). Callers performing existence-only checks pay one extra query — acceptable cost for the dominant use case.
- **D-03:** The `opts` keyword accepts `:preload` to extend or override preloading (e.g., `attachment_for(user, "avatar", preload: [asset: :variants])`). When `:preload` is passed explicitly, it **replaces** the default `[:asset]` rather than merging — the planner can document this clearly. This matches `Ecto.Repo.get/3`'s `preload:` opts shape.
- **D-04:** Owner identification reuses the existing private `Rindle.get_owner_info/1` (`lib/rindle.ex:284-286`): owner_type is `to_string(owner.__struct__)` (e.g., `"Elixir.MyApp.User"`), owner_id is `owner.id`. Same convention `attach/4` (line 175) and `detach/3` (line 247) already use. No new owner-identification surface.
- **D-05:** When multiple `MediaAttachment` rows exist for the same `(owner_type, owner_id, slot)` (possible because the join schema has no enforced uniqueness constraint at the DB level — only the application-level last-write-wins replacement in `attach/4`), return the most recent by `inserted_at` (`order_by: [desc: :inserted_at], limit: 1`). Never raises. Matches `attach/4`'s last-write-wins semantics.

### `ready_variants_for/1` semantics (API-10)

- **D-06:** `Rindle.ready_variants_for(asset_or_id)` is a 1-arity public function on the `Rindle` facade. Returns `[MediaVariant.t()]` — empty list when none ready. No tagged tuple wrap (matches `Repo.all/1` ecosystem convention and existing internal variant queries at `lib/rindle/workers/purge_storage.ex:17` and `lib/rindle/ops/variant_maintenance.ex:71-81`).
- **D-07:** State filter is **`state == "ready"` only**. Not `"stale"`, not `"processing"`, not `"failed"` — the name on the function is literal. This is the only state for which `Rindle.Delivery.do_variant_url/4` (`lib/rindle/delivery.ex:146-149`) returns the variant URL directly without falling back to the original asset. Adopters wanting fallback behavior should call `Rindle.variant_url/4`, which already orchestrates the stale-policy fallback.
- **D-08:** Accepts `%MediaAsset{}` struct OR binary id. Mirrors the existing `get_asset_id/1` polymorphism at `lib/rindle.ex:281-282` that `attach/4` already uses. The id branch issues exactly one query; the struct branch issues exactly one query (no preload assumption — caller already has the asset).
- **D-09:** Order by `:name` ascending. Stable order makes ExDoc doctests deterministic and matches the existing `(asset_id, name)` unique constraint (`lib/rindle/domain/media_variant.ex:78`). Adopters iterating the result list get predictable order across reads.
- **D-10:** Do **not** add a sibling predicate `Rindle.variant_ready?(asset, name)` in this phase. Adopters can `Enum.any?(ready_variants_for(asset), & &1.name == name)` if needed. Keep the surface minimal until adopter feedback demands a predicate.

### Bang variants (API-11)

- **D-11:** Define a single module-level exception, **`Rindle.Error`**, in `lib/rindle/error.ex`:
  - `defexception [:action, :reason]`
  - `message/1` branches on common reason shapes: `:not_found` → `"could not <action>: not found"`; `{:quarantine, why}` → `"could not <action>: upload quarantined (#{inspect(why)})"`; fallback → `"could not <action>: #{inspect(reason)}"`.
  - Direct File.Error / ExAws.Error precedent: one module-level exception with structured fields and a dynamic `message/1`. **Strictly additive** to the public surface — no Phase 17 D-08 violation (additive on `0.1.x` is allowed; only **breaking** changes are deferred to `v0.2.0`).
  - `Rindle.Error` is a **public module**: add it to `@public_modules` in `test/rindle/api_surface_boundary_test.exs` and place it in a sensible `mix.exs` `groups_for_modules` slot (planner discretion: either "Facade" alongside `Rindle` or a new "Errors" group — default is to add it to the Facade group; see Claude's Discretion).
- **D-12:** Reuse `Ecto.InvalidChangesetError` directly for `{:error, %Ecto.Changeset{}}` failures in `attach!/4` and `upload!/3`. This is the Oban `insert!/3` precedent (`deps/oban/lib/oban.ex:686-687`); Ecto's `message/1` is the gold-standard changeset diagnostic in the ecosystem and re-doing it would diverge.
- **D-13:** For `{:error, {:storage_adapter_exception, exception}}` returned by `lib/rindle.ex:498`: in the bang variant, when `Exception.exception?(exception)`, `raise exception` (fresh stacktrace at the bang call site). **Do NOT change the existing 2-arity tuple shape** to a 3-arity `{:storage_adapter_exception, exception, stacktrace}` form — that would break adopters pattern-matching on the existing 2-arity (Phase 17 D-08). Fresh stacktrace at the bang call site is acceptable; for full-context debugging adopters can call the non-bang.
- **D-14:** All bangs are **thin wrappers** over the non-bang versions, never duplicated logic. Wrapping `Ecto.Multi`-based functions like `attach/4` (50+ LOC) is the only sane approach — duplication invites drift. Pattern (universal across Ecto, Oban, File, Req, ExAws):
  ```elixir
  def attach!(asset_or_id, owner, slot, opts \\ []) do
    case attach(asset_or_id, owner, slot, opts) do
      {:ok, attachment} -> attachment
      {:error, %Ecto.Changeset{} = cs} ->
        raise Ecto.InvalidChangesetError, action: :insert, changeset: cs
      {:error, {:storage_adapter_exception, exception}} when is_exception(exception) ->
        raise exception
      {:error, reason} ->
        raise Rindle.Error, action: :attach, reason: reason
    end
  end
  ```
- **D-15:** Bang return shapes (unwrapped from the `:ok` tuple):
  - `attach!/4` → `MediaAttachment.t()`
  - `detach!/3` → `:ok` (preserves the non-bang's `:ok | {:error, _}` shape; no struct to unwrap)
  - `upload!/3` → `MediaAsset.t()`
  - `url!/3` → `String.t()`
  - `variant_url!/4` → `String.t()`
- **D-16:** Bang arity exactly mirrors the non-bang twin. No bang has a different arity. Default-args (`opts \\ []`) produce two `@spec` entries per Oban convention but a single `def`.
- **D-17:** Bang `@doc` is the **one-line "Same as `foo/N` but ..." form** — Plug.Conn `inform!/3` precedent (`deps/plug/lib/plug/conn.ex:1371-1374`). Example: `@doc "Same as `attach/4` but raises `Rindle.Error` on failure or `Ecto.InvalidChangesetError` for changeset failures."`. Passes doctor 100% doc threshold per Phase 18 D-08 (verified: doctor only checks doc presence, not depth, per `deps/doctor/lib/reporters/module_explain.ex:203-211`).
- **D-18:** Bang `@spec` returns the **success type only** (no `no_return()` on the error path). Universal ecosystem convention (Ecto, Oban, File, ExAws all do this); `no_return()` would complicate Dialyzer at call sites that bind the result.

### Specs, types, and DocTest budget

- **D-19:** All 8 new public functions plus `Rindle.Error` get `@doc` + `@spec` to satisfy Phase 18 D-07's 100/100/100/95/95 doctor thresholds. Bangs use the one-line `@doc` from D-17; non-bangs (`attachment_for/2,3`, `ready_variants_for/1`) get full `@doc` blocks with `## Examples` per the existing `Rindle` facade convention (`lib/rindle.ex:25-37`).
- **D-20:** `@spec` shapes use existing named schema types (Phase 18 D-03 / D-05): `MediaAttachment.t()`, `MediaVariant.t()`, `MediaAsset.t()`. The existing `@type storage_result :: {:ok, term()} | {:error, term()}` alias at `lib/rindle.ex:23` is **not** suitable for these specs (too opaque); use named schema types directly.
- **D-21:** New doctests are optional but encouraged for `attachment_for/2` and `ready_variants_for/1` to demonstrate the empty-result and populated-result cases. Bang variants do **not** need doctests (no useful test of `raise` via doctest); their unit tests live in the existing test suite.

### Test surface and fixtures

- **D-22:** New tests live in `test/rindle/convenience_api_test.exs`. Reuses the `Rindle.DataCase` Sandbox setup (`test/support/data_case.ex` already exists; no factory library) and the existing inline-fixture pattern from `test/rindle/attach_detach_test.exs:19-21` (`defmodule User do defstruct [:id] end`). No new test infrastructure is introduced.
- **D-23:** Test coverage targets:
  - `attachment_for/2`: nil case (no attachment), happy path (returns `%MediaAttachment{}` with `:asset` preloaded), `preload:` opt override, multi-row tie-breaking by `inserted_at desc`.
  - `attachment_for/3` with `preload: false` (or empty list — planner decides exact override semantics).
  - `ready_variants_for/1`: empty list (no variants), only `"ready"` returned (verify a `"processing"` row is excluded), order by `:name`, struct OR id input.
  - Each bang: success path returns unwrapped value, `{:error, :not_found}` raises `Rindle.Error`, `{:error, %Ecto.Changeset{}}` raises `Ecto.InvalidChangesetError`, `{:error, {:storage_adapter_exception, exception}}` re-raises the underlying exception, `{:error, {:quarantine, _}}` raises `Rindle.Error` with a quarantine-formatted message (for `upload!/3`).
- **D-24:** `Rindle.Error` exception itself gets unit tests covering its `message/1` branches (the three reason shapes from D-11).

### Plan slicing

- **D-25:** Phase 19 ships as **2 plans**, mirroring the Phase 17 P01 / Phase 18 P01 RED-harness rhythm but compressed because Phase 19 is mechanical add-functions work:
  1. **19-01 — RED-only failing test harness:** Create `test/rindle/convenience_api_test.exs` with all the test cases from D-23, all asserting against functions that do not yet exist. Update `test/rindle/api_surface_boundary_test.exs` to include the new public functions and `Rindle.Error` in `@public_modules`. RED-only commit.
  2. **19-02 — GREEN implementation + closure:** Implement `attachment_for/2`, `ready_variants_for/1`, `Rindle.Error`, and the five bang variants in `lib/rindle.ex` (and `lib/rindle/error.ex`). Add `Rindle.Error` to `mix.exs` `groups_for_modules`. CHANGELOG entry summarizing the convenience surface. Verify `mix doctor --full --raise` stays green and `mix test` is fully green.
- **D-26:** **Defensive split clause:** if at planning time the implementation work in 19-02 spans more than ~6 files (e.g., if extracting helpers becomes warranted), split into 19-02a (`Rindle.Error` + helpers `attachment_for`, `ready_variants_for`) and 19-02b (5 bang variants). Default is single-plan 19-02 since the implementation is concentrated in `lib/rindle.ex` + new `lib/rindle/error.ex`.

### Decision-making preference (carried)

- **D-27:** Continue the project's existing GSD preference (saved feedback memory + STATE.md "Decision-Making Preference" block): the agent decides by default with deep subagent research and locked recommendations; escalate only for VERY impactful items. Phase 19 has zero such items — every decision above is mechanical or strictly additive. The one borderline-impactful decision (introducing `Rindle.Error`) was confirmed in this discussion.

### Claude's Discretion

- Exact `mix.exs` `groups_for_modules` placement for `Rindle.Error` (default: same group as `Rindle` itself; alternative: a new "Errors" group is acceptable if the planner prefers).
- Exact `Rindle.Error.message/1` format strings (the three branch shapes are locked; the prose is the planner's call).
- Exact `attachment_for/3` `:preload` opt semantics — replace-vs-merge with the default `[:asset]`. Default recommendation: replace (matches Ecto convention); planner may switch to merge if doctest examples read better that way.
- Whether to land doctests on `attachment_for/2` and `ready_variants_for/1`. Default: yes; defer if they slow down test execution materially.
- Whether to introduce a `lib/rindle/queries.ex` private helper module to host the new query functions. Default: keep them inline in `lib/rindle.ex` per existing facade convention; extract only if file length becomes unwieldy (>700 LOC; current is ~520).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and project context
- `/Users/jon/projects/rindle/.planning/ROADMAP.md` — Phase 19 goal, success criteria, requirements API-09/API-10/API-11
- `/Users/jon/projects/rindle/.planning/REQUIREMENTS.md` — exact requirement text for API-09, API-10, API-11
- `/Users/jon/projects/rindle/.planning/PROJECT.md` — milestone intent (`v1.3 — Live Publish & API Ergonomics`), "clean up the public API surface before adoption grows"
- `/Users/jon/projects/rindle/.planning/STATE.md` — accumulated decisions, decision-making preference

### Locked prior phase boundaries that Phase 19 extends
- `/Users/jon/projects/rindle/.planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md` — public-vs-internal module set, semver posture (D-08 additive-only on 0.1.x), facade-first IA, `verify_completion` vs `verify_upload` shim
- `/Users/jon/projects/rindle/.planning/phases/18-documentation-and-typespec-coverage/18-CONTEXT.md` — named schema types pattern (D-03/D-04/D-05), doctor thresholds 100/100/100/95/95 (D-07), one-line bang doc convention (D-08 verification)

### Code surface affected
- `/Users/jon/projects/rindle/lib/rindle.ex` — facade; new functions land here. Existing private helpers `get_owner_info/1` (line 284-286) and `get_asset_id/1` (line 281-282) are reused; `@type storage_result` (line 23) is **not** used for the new specs.
- `/Users/jon/projects/rindle/lib/rindle/error.ex` — **new file**: `Rindle.Error` exception module.
- `/Users/jon/projects/rindle/lib/rindle/upload/broker.ex` — broker patterns (read-only reference; no changes)
- `/Users/jon/projects/rindle/lib/rindle/delivery.ex` — `do_variant_url/4` at line 146-149 confirms `"ready"` is the only state that returns the variant URL directly (read-only reference)
- `/Users/jon/projects/rindle/lib/rindle/domain/media_attachment.ex` — `MediaAttachment.t()` at line 29 is the named return type for `attachment_for/2`
- `/Users/jon/projects/rindle/lib/rindle/domain/media_asset.ex` — `MediaAsset.t()` at line 47 is the named return type for `upload!/3` and the input for `ready_variants_for/1`
- `/Users/jon/projects/rindle/lib/rindle/domain/media_variant.ex` — `MediaVariant.t()` at line 35 is the named return type for `ready_variants_for/1`; state vocabulary at line 33 confirms `"ready"` is one of eight states; unique constraint at line 78 is on `(asset_id, name)`
- `/Users/jon/projects/rindle/lib/rindle/config.ex` — `Rindle.Config.repo()` is the canonical Repo accessor (used by `attach/4` and `detach/3` already; reuse for new helpers)
- `/Users/jon/projects/rindle/mix.exs` — `groups_for_modules` already configured by Phase 17/18; add `Rindle.Error` to a sensible group in Plan 19-02
- `/Users/jon/projects/rindle/test/rindle/api_surface_boundary_test.exs` — `@public_modules` allowlist (lines 4-31): add `Rindle.Error` in 19-01
- `/Users/jon/projects/rindle/test/rindle/attach_detach_test.exs` (lines 19-31) — fixture template for `defmodule User do defstruct [:id] end` and direct-changeset asset creation; reuse pattern in `test/rindle/convenience_api_test.exs`
- `/Users/jon/projects/rindle/test/support/data_case.ex` — Sandbox setup; no factories
- `/Users/jon/projects/rindle/CHANGELOG.md` — entry in Plan 19-02 summarizing API-09/10/11 deliverables

### Authoritative external references for Phase 19 patterns

**Bang variant precedents (locked D-11 through D-18):**
- `https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/exceptions.ex` — `Ecto.InvalidChangesetError` (lines 85-140), `Ecto.NoResultsError` (lines 199-213): per-operation exception family, dynamic `message/1`
- `https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/repo/schema.ex` (lines 377-414) — `insert!/2` thin-wrapper pattern over `insert/2`
- `https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/repo.ex` (lines 944-972) — full `@doc` block + `@spec` of success type only on `Repo.get!/3`
- `https://github.com/oban-bg/oban/blob/main/lib/oban.ex` (lines 681-692) — `insert!/3` reuses `Ecto.InvalidChangesetError`, raises `RuntimeError, inspect(reason)` for everything else; thin wrapper over `insert/3`
- `https://github.com/elixir-lang/elixir/blob/main/lib/elixir/lib/file.ex` — `File.Error` single module-level exception with `:reason`/`:action`/`:path` fields and dynamic `message/1`
- `https://github.com/elixir-plug/plug/blob/main/lib/plug/conn.ex` (lines 1371-1392) — `inform!/3` short docstring + inline `RuntimeError` (chosen because failure is misconfiguration, not data error)
- `https://github.com/wojtekmach/req/blob/main/lib/req.ex` — `Req.request!/2` `{:error, exception} -> raise exception` pattern (works when error tuples wrap exception structs)
- `https://github.com/ex-aws/ex_aws/blob/master/lib/ex_aws.ex` (lines 71-96) — `request!/2` raises single `ExAws.Error` with `inspect(error)` interpolated
- `https://hexdocs.pm/elixir/naming-conventions.html` — Elixir trailing-bang naming convention

**Helper API precedents (locked D-01 through D-10):**
- `https://api.rubyonrails.org/classes/ActiveStorage/Attached/Model.html` — `has_one_attached`, never-nil proxy (rejected as footgun)
- `https://guides.rubyonrails.org/active_storage_overview.html` — variant lazy-processing model (lessons drove D-07's no-fallback decision)
- `https://github.com/rails/rails/issues/46770` — N+1 listing attachments and variants (drove D-02's auto-preload decision)
- `https://justin.searls.co/posts/drive-by-active-storage-advice/` — `feed_ready?` predicate workaround for AS variants
- `https://blog.saeloun.com/2020/03/06/eagerload-active-storage-models.html` — eager-loading AS models (N+1 mitigation context)
- `https://shrinerb.com/docs/getting-started` — `user.image` accessor returns nil when nothing attached
- `https://shrinerb.com/docs/plugins/derivatives` — derivatives JSON column; presence == ready
- `https://spatie.be/docs/laravel-medialibrary/v11/retrieving-media/getting-files` — `getFirstMedia` / `getMedia` singular-vs-plural pattern; null on empty
- `https://github.com/spatie/laravel-medialibrary/blob/main/src/MediaCollections/Models/Media.php` — `hasGeneratedConversion` predicate, `generated_conversions` JSON column
- `https://github.com/carrierwaveuploader/carrierwave` — never-nil mounted uploader (rejected pattern)
- `https://hexdocs.pm/ecto/Ecto.Repo.html` — `Repo.get_by/2` returns `nil` (idiom Rindle adopts)
- `https://hexdocs.pm/phoenix/Phoenix.Controller.html` — `get_session/2` naming convention reference

**Doctor coverage and bang-doc convention (carried from Phase 18 D-08):**
- `https://github.com/akoutmos/doctor/blob/master/lib/reporters/module_explain.ex` (lines 203-215) — `mix doctor` only checks `doc != :none`; one-line `@doc` passes

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle` facade (`lib/rindle.ex`) is the destination for all 8 new public functions plus the `Rindle.Error` alias. Existing private helpers `get_owner_info/1` (lines 284-286) and `get_asset_id/1` (lines 281-282) are reused for owner identification and asset polymorphism — no new private helper logic needed.
- `Rindle.Config.repo()` is the canonical Repo accessor; both `attach/4` (line 173) and `detach/3` (line 246) already use it. New helpers must use the same accessor.
- `MediaAttachment`, `MediaAsset`, `MediaVariant` schemas all already define `@type t :: %__MODULE__{}` — the named return types for new `@spec`s are zero-cost reuse.
- `Rindle.Delivery.do_variant_url/4` (lib/rindle/delivery.ex:146-149) is the authoritative source for "ready means deliverable directly" — `ready_variants_for/1`'s state filter is consistent with it.
- `test/rindle/attach_detach_test.exs` lines 19-31 are the canonical fixture template (`defmodule User do defstruct [:id] end` + direct-changeset asset creation). Reuse in `test/rindle/convenience_api_test.exs`.
- `test/rindle/api_surface_boundary_test.exs` `@public_modules` allowlist (lines 4-31) is the boundary contract. Add `Rindle.Error` in Plan 19-01.

### Established Patterns
- The facade-first IA (Phase 17 D-02 / D-15) already centers adopter docs on `Rindle` and `Rindle.Profile`. New helpers and bangs land on `Rindle` directly — no new module surface required for the helpers themselves.
- All existing facade functions have `@doc` + `@spec` (verified by Phase 18); the convention is preserved by D-19 / D-20.
- Wrapper-over-non-bang for bang variants is universal in the Elixir ecosystem (Ecto, Oban, File, Req, ExAws). Phase 19's bang implementations follow that convention exactly.
- Doctor thresholds 100/100/100/95/95 (Phase 18 D-07) hold; the new `Rindle.Error` module needs a `@moduledoc` and the new functions need `@doc` + `@spec` to keep CI green. Bangs use one-line `@doc` per D-17 — already verified to pass doctor.
- `@impl true` annotations are used consistently in adapter implementations; `Rindle.Error.message/1` will use `@impl true` against `Exception`.

### Integration Points
- `lib/rindle.ex` — primary insertion point. New functions land at the bottom of the facade, near the existing `log_variant_processing_failure/3` shim.
- `lib/rindle/error.ex` — **new file**. Single module, ~30 LOC.
- `mix.exs` `groups_for_modules` — Plan 19-02 adds `Rindle.Error` to a sensible group (default: Facade).
- `test/rindle/convenience_api_test.exs` — **new file**. Plan 19-01 ships failing tests covering all 8 functions + `Rindle.Error.message/1`.
- `test/rindle/api_surface_boundary_test.exs` — Plan 19-01 adds `Rindle.Error` to `@public_modules`. New `Rindle.attachment_for/2,3`, `Rindle.ready_variants_for/1`, and the 5 bang variants are already covered by the existing `@public_functions` allowlist (or its equivalent — planner verifies in 19-01).
- `CHANGELOG.md` — Plan 19-02 entry summarizing API-09/API-10/API-11 deliverables.

### What is NOT changing
- No existing function signatures change. No existing module's `@moduledoc` or `@doc` is modified beyond the new functions.
- The `verify_upload/2` and `log_variant_processing_failure/3` deprecation/`@doc false` posture (Phase 17 D-09 / D-12) is unchanged.
- `mix.exs` deps list does not gain a new dependency (no factory library, no new test helpers).
- CI thresholds, the `quality` job, and the `mix doctor --full --raise` step (Phase 18 D-09 / D-10) are unchanged. The new functions ride the existing CI gate.

</code_context>

<specifics>
## Specific Ideas

- Prefer the term **"convenience helpers"** in CHANGELOG and ExDoc prose, not "shortcuts" or "syntactic sugar." API-09/10/11 describe these as adopter-facing ergonomics, not abbreviations.
- When writing `Rindle.Error.message/1`, keep the prose terse and actionable in the File.Error idiom: `"could not <action>: <reason-formatted>"`. Adopters see this in stacktraces and rescue clauses; brevity matters.
- The `:storage_adapter_exception` re-raise in bangs (D-13) intentionally surfaces the underlying S3/disk exception's class to adopters. This is the right tradeoff for debuggability — adopters rescuing for `Rindle.Error` and getting an `S3.HTTPError` instead is *more* informative, not a leak.
- For the doctest order question on `ready_variants_for/1` (D-09): if `:name` ordering proves unstable across SQLite vs Postgres adapters in CI, switch to `order_by: [:name, :inserted_at]` as a tiebreaker. The current schema uses Postgres only; this is a defensive note for future adapters.
- The `attachment_for/3` opts override semantics for `:preload` (Claude's Discretion): the cleanest implementation is `Keyword.get(opts, :preload, [:asset])` — replaces. Adopters who want both `:asset` and something else write `preload: [asset: :variants]`. This matches Ecto's `Repo.get/3, opts` keyword semantics.

</specifics>

<deferred>
## Deferred Ideas

- **`attachments_for/2` (plural helper for multi-valued slots)** — useful when an owner has multiple attachments at the same slot or attachments across multiple slots. Defer to a future phase; document the gap in `attachment_for/2`'s `@doc`.
- **`Rindle.url_for(owner, slot, opts)` higher-level convenience** — combines `attachment_for/2` + `Rindle.url/3` in a single call. Tempting but expands scope; defer until adopter feedback demands it.
- **`Rindle.attached?(owner, slot)` predicate** — returns boolean. Adopters can `attachment_for(owner, slot) != nil` for now.
- **`Rindle.variant_ready?(asset, name)` predicate** — adopters can `Enum.any?(ready_variants_for(asset), & &1.name == name)`.
- **Batched `attachments_for_owners/2`** — neutralizes N+1 in list-rendering use cases (the single most-cited Active Storage complaint). High-leverage future addition; defer until adopter feedback.
- **Per-operation exception types (`Rindle.AttachError`, `Rindle.UploadError`, etc.)** — Ecto-style exception family. Defer; the `:action` field on `Rindle.Error` already discriminates for any rescue clause that needs it. Rindle's surface is too small to justify proliferation.
- **3-arity `{:storage_adapter_exception, exception, stacktrace}` tuple shape** — would preserve original-site stacktraces for `reraise`. Breaking change to existing pattern-matchers; defer to v0.2.0 or later if debugging needs grow.
- **Custom bang-variant doc generation via macro** — over-engineering for 5 bangs. If the count grows substantially in a future phase, revisit.

### Reviewed Todos (not folded)
None — the two pending todos in STATE.md (`Plan GCS adapter resumable upload flow (GCS-01)`, `Evaluate tus/resumable protocol once release distribution is routine (TUS-01)`) are unrelated to convenience-API additions and stay parked.

</deferred>

---

*Phase: 19-convenience-api-additions*
*Context gathered: 2026-04-30 (assumptions mode + 3 parallel research subagents: codebase analysis, Elixir bang-variant idioms, cross-language helper patterns)*
