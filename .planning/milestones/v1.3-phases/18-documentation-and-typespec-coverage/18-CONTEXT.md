# Phase 18: Documentation and Typespec Coverage - Context

**Gathered:** 2026-04-30 (assumptions mode + 3 parallel research subagents on callback enforcement, plan slicing, and ecosystem cross-validation)
**Status:** Ready for planning

<domain>
## Phase Boundary

Land full `@doc` and `@spec` coverage on the locked public surface from Phase 17, replace opaque return types with named schema/result types so Dialyzer and ExDoc both teach adopters the real contract, and gate coverage in CI via `mix doctor --raise` so future drift fails the build.

This phase does **not** expand the public surface (Phase 17 owns that), does **not** rename anything published on `0.1.x` (semver posture from Phase 17 D-08 stands), and does **not** introduce new convenience helpers (those land in Phase 19). It documents what exists.
</domain>

<decisions>
## Implementation Decisions

### Public surface scope (carried from Phase 17 D-03/D-04/D-06)

- **D-01:** Phase 18 documents only the intentionally public modules locked in `.planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md`. Internal modules already hidden via `@moduledoc false` (D-05 there) stay out of scope. The public set: `Rindle`, `Rindle.Profile`, `Rindle.Upload.Broker`, `Rindle.Delivery`, `Rindle.Storage` + `Local`/`S3`, the four extension behaviours (`Authorizer`/`Analyzer`/`Scanner`/`Processor`), **`Rindle.Processor.Image` (added in Phase 18 — see D-27)**, `Rindle.LiveView`, `Rindle.HTML`, all `Mix.Tasks.Rindle.*`, `Rindle.Workers.AbortIncompleteUploads`, `Rindle.Workers.CleanupOrphans`, and the five `Rindle.Domain.*` schema modules.
- **D-02:** Coverage starting state (verified by direct grep on the codebase): `Rindle` facade + `Rindle.Delivery` + all five `Rindle.Domain.*` schemas are already complete on `@doc`/`@spec`/`@type t`. Largest gaps: `Rindle.Upload.Broker` has `@doc` on every public function but **zero `@spec`**; the four extension behaviours plus `Rindle.Storage` have `@callback`s without per-callback `@doc`; all five `Mix.Tasks.Rindle.*` lack any `@spec`; both cron workers lack `@doc`/`@spec` on `perform/1`; `Rindle.HTML.picture_tag/3` lacks `@doc`; `Rindle.Profile.__using__/1` macro lacks `@doc`/`@spec`.

### Named struct types (API-07)

- **D-03:** Replace opaque `{:ok, map()}` / `{:ok, struct()}` / `{:ok, term()}` returns in `Rindle` and `Rindle.Upload.Broker` public `@spec`s with named schema types — `{:ok, MediaAsset.t()}`, `{:ok, MediaUploadSession.t()}`, `{:ok, MediaAttachment.t()}`, etc. This matches `Ecto.Repo.insert/2`'s spec shape (`{:ok, Ecto.Schema.t()} | {:error, Ecto.Changeset.t()}`) — adopters dispatch through the schema-aware facade and deserve schema-aware specs.
- **D-04:** Define behaviour-level named result types on `Rindle.Storage`: `@type put_result :: %{key: String.t(), ...}`, `@type delete_result :: ...`, `@type url_result :: ...`. Adapter callbacks (`Rindle.Storage.S3`, `Rindle.Storage.Local`) spec to those behaviour-defined types via `@impl true`. This is the `Tesla.Adapter` / `Ecto.Adapter.Schema` pattern — heterogeneous adapter return shapes converge at the behaviour, not at the call site. Per-adapter `t/0` types are the wrong unit because callers dispatch dynamically.
- **D-05:** Multi-key public result maps (`%{session: MediaUploadSession.t(), asset: MediaAsset.t()}` returned by `verify_completion/2`; `%{session: ..., presigned: %{url: ..., method: ..., headers: ...}}` returned by multipart helpers) get named `@type` aliases at the module level (e.g. `@type verify_result :: %{...}`) and are referenced by name in the function `@spec`. Inline anonymous map types in `@spec` make ExDoc unreadable — naming them is the Phoenix/Ecto convention for any multi-key result.

### `mix doctor` configuration

- **D-06:** Add `{:doctor, "~> 0.22.0", only: [:dev, :test], runtime: false}` to `mix.exs` deps. Generate initial `.doctor.exs` via `mix doctor.gen.config` to baseline current-state thresholds (Plan 18-01), then ratchet to final values in Plan 18-05.
- **D-07:** Final `.doctor.exs` thresholds (locked target — landing in Plan 18-05): `min_module_doc_coverage: 100`, `min_overall_doc_coverage: 100`, `min_overall_moduledoc_coverage: 100` for the documentation side; `min_module_spec_coverage: 95`, `min_overall_spec_coverage: 95` for the spec side. Spec thresholds at 95 (not 100) accept the `@impl true` callback-inheritance pattern that Ecto, Phoenix, Hex, and Elixir core all use for Mix tasks (`run/1`) and Oban workers (`perform/1`) — see D-12 / D-13. This matches `prom_ex`'s threshold set (90/90/90/90/100) one notch stricter; significantly stricter than the Ash family (40/0/50/0/100) without forcing per-module exemptions for callback-implementing modules.
- **D-08:** `mix doctor` does **not** auto-skip `@moduledoc false` modules ([open issue #67](https://github.com/akoutmos/doctor/issues/67) — confirmed by reading `lib/cli/cli.ex` source). The `.doctor.exs` `ignore_modules:` list MUST explicitly cover every internal hidden by Phase 17 D-05. Use the Ash-family idiom: lead with conventional regexes (`~r/^Inspect\./` for protocol implementations), then a `~r/^Rindle\..*\.Internal\./`-style namespace regex for any Phase-17 hidden modules that share a namespace prefix, then an explicit list for the rest with a comment explaining each. Real-world precedents: `ash_authentication`, `cinder`, `pgflow`, `jido` all use this shape.
- **D-09:** Doctor's `--raise` flag is belt-and-suspenders in 0.22.0 — the task's `System.at_exit` hook already exits non-zero on failure (verified by reading `lib/mix/tasks/doctor.ex`), but `--raise` produces a louder Mix.raise error message. CI invocation is `mix doctor --full --raise`. `--full` (not `--summary`) gives a per-module table on failure, which is far more useful in CI logs than a one-liner. Matches `team-alembic/staple-actions/actions/mix-doctor` and `buildkite/test_collector_elixir`.

### CI integration

- **D-10:** Add the doctor step to the `quality` job in `.github/workflows/ci.yml` between `Credo (strict)` (line 84-85) and `Run tests with coverage` (line 87-88). Run as `MIX_ENV=test mix doctor --full --raise`. `MIX_ENV=test` is **required**: `Rindle.LiveView` and `Rindle.HTML` are wrapped in `if Code.ensure_loaded?(...)` because their `phoenix_live_view` / `phoenix_html` deps are `optional: true`; in `:dev` env those modules don't exist and doctor would silently skip them. Test env loads them via the test-suite's transitive deps. Runs on both Elixir 1.15 and 1.17 matrix lanes. No `continue-on-error` — failure blocks merge same as credo and dialyzer.

### Documentation patterns by module type

- **D-11:** Behaviour modules (`Rindle.Storage`, `Rindle.Authorizer`, `Rindle.Analyzer`, `Rindle.Scanner`, `Rindle.Processor`) — place `@doc """..."""` **immediately preceding** every `@callback` declaration. This is the universal Elixir pattern (Phoenix.Endpoint, Ecto.Adapter.*, Oban.Worker, Tesla.Adapter, Plug.Session.Store, Broadway.Producer all do exactly this). For callbacks introduced after `0.1.0`, optionally annotate with `@doc since: "0.x.y"` (Broadway / Oban convention). Adapter implementations (`Storage.Local`, `Storage.S3`) use `@impl Rindle.Storage` and inherit docs from the behaviour — do not duplicate `@doc` on `@impl` callback implementations.
- **D-12:** Mix tasks (`Mix.Tasks.Rindle.*`) — use `@shortdoc` + `@moduledoc` + `@impl true` only. **Do NOT add `@doc` or `@spec` to `run/1`.** Verified across `Mix.Tasks.Ecto.Migrate`, `Mix.Tasks.Phx.New`, `Mix.Tasks.Hex.Publish`, and Elixir core's own `Mix.Tasks.Run` — none `@doc` or `@spec` their `run/1`. The `@impl true` is the documentation pointer to `Mix.Task.run/1`'s behaviour-defined contract. Doctor passes these via D-07's 95% spec threshold + `@impl` inheritance.
- **D-13:** Oban workers (`Rindle.Workers.AbortIncompleteUploads`, `Rindle.Workers.CleanupOrphans`) — invest in a rich `@moduledoc` (what the worker does, its scheduling cadence, observable telemetry, side effects). **Drop `@doc` from `perform/1`.** Add `@spec perform(Oban.Job.t()) :: ...` only if Rindle's worker narrows the return type beyond `Oban.Worker.result()`. This matches the Plausible production pattern and avoids duplicating `Oban.Worker`'s behaviour-level docs.
- **D-14:** `Rindle.Profile.__using__/1` — keep `@doc` directly above `defmacro __using__(opts)` describing the `use Rindle.Profile` API contract (the Phoenix.Controller / Phoenix.LiveView pattern). Use `@spec __using__(keyword()) :: Macro.t()` (the `thousand_island` / `ash_reactor` pattern). This avoids needing an `ignore_modules:` exemption for `Rindle.Profile`.
- **D-15:** `Rindle.HTML.picture_tag/3` — add `@doc """..."""` describing the helper's purpose, options, and example output. The function already has `@spec`.

### Compatibility shim documentation

- **D-16:** `Rindle.log_variant_processing_failure/3` (the Phase 17 D-12 hidden facade shim) gets the **Phoenix.Controller compatibility-shim shape**: `@doc false` + `@deprecated "Use ..."` + existing `@spec`. The `@deprecated` attribute makes the compiler emit a deprecation warning to any caller still depending on the old function — strictly stronger guarantee than `@doc false` alone, and free. Confirmed `@doc false` exempts the function from doctor's `@doc` coverage but counts it toward `@spec` coverage (verified by reading doctor's `lib/module_report.ex`). Concrete deprecation message text is at the implementer's discretion (Claude's Discretion below).
- **D-17:** `Rindle.verify_upload/2` (the Phase 17 D-09 / D-11 legacy public name kept for `0.1.x` compatibility) keeps its current visible `@doc` + `@doc deprecated: "Use verify_completion/2"` metadata. This is the Ecto.Repo.transaction/2 pattern (`@doc deprecated: "Use Repo.transact/2"`) — visible in ExDoc, soft-deprecation warning at compile time. Distinct from D-16's hidden shim.

### Callback documentation enforcement

- **D-18:** Adopt **honor-system** enforcement for `@doc` on `@callback` declarations. Doctor does not analyze callback declarations at all (verified by reading `lib/module_information.ex`); ExDoc `--warnings-as-errors` does not catch missing callback docs either. **Do NOT** build a custom Credo check. Every reference Elixir lib in this space (Ecto.Adapter, Oban.Worker, Phoenix.Channel, Phoenix.Endpoint, Plug.Session.Store, Tesla.Adapter, Broadway.Producer, Membrane.Source) relies on the convention plus code review and ships zero callback-doc enforcement tooling. Building one would make Rindle the first.
- **D-19:** Add a low-cost ExUnit backstop test (`test/rindle/behaviour_docs_test.exs`, ~15 LOC) that uses `Code.fetch_docs/1` on each behaviour module's compiled BEAM and asserts every `:callback` doc is neither `:none` nor `:hidden`. This is ecosystem-idiomatic (uses public Elixir API, the same one ExDoc uses), maintenance-free across Credo upgrades, and gives identical CI-time feedback as a custom Credo check at a fraction of the cost. Lives in the test suite, runs as part of the existing `mix test` step, no new tooling.
- **D-20:** Add a single line to `CONTRIBUTING.md` (or `README.md`'s contributing section if no `CONTRIBUTING.md` exists) documenting the convention: "Every public `@callback` must be preceded by `@doc \"\"\"...\"\"\"`. Use `@doc false` only for internal compatibility shims." Single line, zero ceremony.
- **D-21:** Optional DX add-on (lower priority; agent's discretion to include in Phase 18 or defer): adopt a Membrane-style `@moduledoc` callback summary on each of the five behaviour modules — a brief list of callbacks at the top of `@moduledoc` so adopters see the contract surface in the first ExDoc panel before scrolling. Hand-written is fine at five behaviours.

### Plan slicing (5 plans, baseline-then-ratchet)

- **D-22:** Phase 18 ships as **5 plans** mirroring Phase 17's RED-harness-first rhythm but with one critical refinement. Plan 18-01 lands `:doctor` with thresholds **at current-state baseline** (generated by `mix doctor.gen.config`), NOT at the final 100/95 target. Plan 18-05 ratchets to the final thresholds. Rationale: Sorbet's adoption playbook at Shopify and the Notion ESLint ratcheting pattern both warn that introducing a static-analysis tool with thresholds set at the *target* state blocks unrelated PRs and creates desensitization noise. The Phase 17 P01 RED-only worked because its window was 7 minutes; if Phase 18's plan 1 → plan 5 spans days, that approach backfires. Baseline-then-ratchet keeps the failing-test discipline (a unit test asserts the *target* thresholds — see D-23) without making CI itself the failing harness.
- **D-23:** Plan 18-01 ships a failing ExUnit test (`test/rindle/doctor_thresholds_test.exs`) that reads `.doctor.exs` and asserts the configured thresholds equal the target values from D-07. This test fails at plan 1 (because plan 1 ships baseline thresholds, not target). It turns green at plan 18-05 when thresholds ratchet up. RED-only commit lives in plan 1; the failing test is the harness, not the CI gate. Same TDD invariant as Phase 17 P01, different surface.
- **D-24:** Locked plan order:
  1. **18-01 — Failing harness + baseline doctor:** add `:doctor` dep, run `mix doctor.gen.config`, commit `.doctor.exs` with current-state thresholds, add `MIX_ENV=test mix doctor --full --raise` step to CI's `quality` job, write the failing `doctor_thresholds_test.exs` asserting target. CI passes (because thresholds match current state); test fails (because thresholds don't yet equal target). RED-only commit.
  2. **18-02 — Named-types tightening:** D-03 / D-04 / D-05 — replace opaque returns in `Rindle` and `Rindle.Upload.Broker` with `MediaAsset.t()` etc.; define `Rindle.Storage` behaviour result types and adapter `@impl` references; name multi-key result aliases.
  3. **18-03 — Behaviours + Broker:** D-11 — add per-`@callback` `@doc` to all five behaviour modules; add the missing `@spec`s on every public function in `Rindle.Upload.Broker`; add the D-19 backstop test.
  4. **18-04 — Ops, integrations, macro, and shims:** D-12 (Mix tasks `@moduledoc`/`@shortdoc`/`@impl` posture), D-13 (worker `@moduledoc` enrichment, drop `@doc` from `perform/1`), D-14 (`Rindle.Profile.__using__/1` doc + spec), D-15 (`Rindle.HTML.picture_tag/3` doc), D-16 (compatibility shim `@deprecated` annotation), and the D-20 CONTRIBUTING note.
  5. **18-05 — Closure / ratchet:** ratchet `.doctor.exs` thresholds from baseline to target (D-07), turn the D-23 failing test green, add CHANGELOG entry summarizing the doc/spec sweep, run `mix doctor --full` locally + CI green, optional D-21 callback summaries.
- **D-25:** **Defensive split clause:** if at planning time the file count for plan 18-04 exceeds 10 files, split it into 18-04a (Mix tasks only) and 18-04b (workers, integrations, macro, compatibility shims). Phase 17's average plan size was ~10 files (P02: 15, P03: 12, P05: 13); 18-04 should stay in that range.

### Decision-making preference (carried)

- **D-26:** Continue the project's existing GSD preference (saved feedback memory + STATE.md "Decision-Making Preference" block): the agent decides by default with deep subagent research and locked recommendations; escalate only for VERY impactful items (public API / module / function renames touching the published surface, semver-affecting changes, deletion of git history or hex versions, secret/auth scope changes, cost-bearing infra, milestone/scope reshape). Phase 18 has zero such items — every decision above is mechanical and recoverable.

### Phase 17 boundary correction: `Rindle.Processor.Image` becomes public

- **D-27:** **`Rindle.Processor.Image` is intentionally public** — promote to documented adapter symmetric with `Rindle.Storage.S3` and `Rindle.Storage.Local`. Locked via 2 parallel research subagents (ecosystem precedent + DX/UX walkthrough; reports archived at `/tmp/processor-image-ecosystem-research.md` and `/tmp/processor-image-dx-ux-analysis.md`). Rationale:
  1. **Ecosystem precedent (overwhelming):** Every major Elixir library that ships a behaviour + bundled reference adapter documents the adapter publicly — Tesla (`Tesla.Adapter.Hackney/Mint/Httpc/Finch`), Ecto (`Ecto.Adapters.Postgres/MyXQL/SQLite3`), Plug (`Plug.Session.COOKIE/ETS`), Oban (`Oban.Notifiers.Postgres/PG`, `Oban.Engines.Basic/Lite/Inline`), Broadway (`Broadway.DummyProducer/NoopAcknowledger`), Bamboo (`Bamboo.SMTPAdapter` etc.), Swoosh (`Swoosh.Adapters.SMTP/Mailgun/Sendgrid`), Waffle (`Waffle.Storage.S3/Local`), Nx (`Nx.BinaryBackend`, `EXLA.Backend`), Membrane (every element). **Zero precedents found** for hiding a sole bundled adapter behind `@moduledoc false`.
  2. **Symmetry with Phase 17:** Phase 17 D-03 made `Rindle.Storage.S3` and `Rindle.Storage.Local` public alongside the `Rindle.Storage` behaviour but did not name any `Rindle.Processor.*` adapter. This was an oversight (Storage was the more frontline configuration surface), not a deliberate asymmetric posture. Adopters trained on the Storage pattern will reasonably expect Processor parity.
  3. **Adopter discovery:** The `variant_spec` map keys (`:width`, `:height`, `:mode`, `:format`, `:quality`) and supported modes (`:fit`, `:crop`, `:fill`) are the *actual API* of the bundled processor. The `Rindle.Processor` callback signature shows them only as `map()` — there is currently nowhere in ExDoc to discover them without source-diving. Documenting them on the adapter is the only way to surface them.
  4. **Worst-quadrant escape:** Current state (option C / Defer per the analysis) leaves a visible `@moduledoc` on a module that's NOT in `@public_modules` and NOT in `groups_for_modules` — adopters who navigate to it directly see docs implying support, while CI's boundary test does not enforce stability. That's the genuinely worst posture; Phase 18 is the natural place to resolve it.
  5. **No semver impact:** `0.1.4` already publishes the module with a visible `@moduledoc`. Promoting it to formally-documented surface is **additive**.

  **What Phase 18 must do for D-27 (lands in Plan 18-03 alongside the other behaviours/adapters):**
  - Expand `@moduledoc` on `Rindle.Processor.Image` to document the recognized `variant_spec` keys (`:width`, `:height`, `:mode`, `:format`, `:quality`) and the supported modes (`:fit`, `:crop`, `:fill`).
  - Add `@impl Rindle.Processor` annotation on `process/3`.
  - Add `@spec process(Path.t(), map(), Path.t()) :: {:ok, Path.t()} | {:error, term()}` (the `{:error, term()}` branch matches the `Rindle.Processor` callback contract — see "Specifics" note re: not narrowing error terms in `0.1.x`).
  - Add `Rindle.Processor.Image` to `@public_modules` in `test/rindle/api_surface_boundary_test.exs`.
  - Add `Rindle.Processor.Image` to `mix.exs` `groups_for_modules` — preferred slot is **"Storage and Processor Adapters"** (rename the existing "Storage Adapters" group) symmetric across both adapter families. Alternative: keep "Storage Adapters" + add new "Processor Adapters" group. **Claude's discretion** (default: rename to a unified group; if `groups_for_modules` already pluralizes by family, keep symmetry).

  **Risks accepted:**
  - The libvips/Vix-specific option shape is now part of the public contract. Renaming a `variant_spec` key would be a soft-deprecation event. Mitigation: keys are already de facto contract (consumed by `Rindle.Workers.ProcessVariant`).
  - A future `Rindle.Processor.Vips` rename would be a breaking change. Mitigation: name `Image` is generic enough to survive backend swaps; if a real backend split happens, ship `Rindle.Processor.Image` as a delegating wrapper.

  **Footgun-2 acknowledgment:** `Rindle.Workers.ProcessVariant` (itself `@moduledoc false`) currently calls `Rindle.Processor.Image.process/3` with a hardcoded module reference. The internal pipeline depends on the `{:ok, dest_path}` shape plus extension-driven format inference from the destination path. Both are reasonable to commit to publicly. Plan 18-03 expands the `@moduledoc` to cover format inference behavior so adopter expectations match pipeline expectations.

### Claude's Discretion

- Exact `.doctor.exs` baseline numbers (Plan 18-01 captures these via `mix doctor.gen.config` rather than hand-rolling).
- Exact wording of the `@deprecated` message on `Rindle.log_variant_processing_failure/3` (D-16) and any other shim added later.
- Exact phrasing of the `@moduledoc` on each behaviour and the optional D-21 callback summaries.
- Whether the D-21 Membrane-style callback summaries land in Plan 18-05 (closure) or get deferred to a later DX-polish phase. Default: include in 18-05 if the closure plan stays small; defer otherwise.
- Whether the D-20 CONTRIBUTING line lands in 18-04 or a separate small commit.
- Exact regex composition in `.doctor.exs` `ignore_modules:` — the **list** of modules to ignore is fully specified by Phase 17 D-05; the **regex shape** (e.g. `~r/^Rindle\.Security\./` vs explicit list) is at the planner's discretion.
- Naming of the `Rindle.Storage` behaviour-level result types (`put_result` / `delete_result` / `url_result` are placeholders; `Rindle.Storage.put_result/0` or `Rindle.Storage.put/0` style is fine).
- Whether to set `failed: true` in `.doctor.exs` (cosmetic — filters output to failing modules; does not affect exit code).
- Whether to add `mix docs --warnings-as-errors` as a complementary CI step in 18-01 (research found this catches autolink/extras issues but NOT missing `@callback` docs; modest DX value, ~1 line of CI config).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and project context
- `/Users/jon/projects/rindle/.planning/ROADMAP.md` — Phase 18 goal, success criteria, requirements API-06/API-07/API-08
- `/Users/jon/projects/rindle/.planning/REQUIREMENTS.md` — exact requirement text for API-06, API-07, API-08
- `/Users/jon/projects/rindle/.planning/PROJECT.md` — milestone intent (`v1.3 — Live Publish & API Ergonomics`), `0.1.4` reality, "clean up the public API surface before adoption grows"
- `/Users/jon/projects/rindle/.planning/STATE.md` — accumulated decisions, decision-making preference, doctor-version intent (`doctor ~> 0.22.0`)

### Locked Phase 17 boundary that Phase 18 documents
- `/Users/jon/projects/rindle/.planning/phases/17-api-surface-boundary-audit/17-CONTEXT.md` — public-vs-internal module set, hidden-module list, semver posture, ExDoc grouping decisions
- `/Users/jon/projects/rindle/.planning/phases/17-api-surface-boundary-audit/17-VERIFICATION.md` — boundary verification artifacts
- `/Users/jon/projects/rindle/.planning/phases/17-api-surface-boundary-audit/17-BREAKING-CHANGE-DECISION.md` — semver decision record

### Code surface under documentation
- `/Users/jon/projects/rindle/mix.exs` — deps + `groups_for_modules` already configured by Phase 17; `:doctor` to be added in Plan 18-01; Phase 18 D-27 adds `Rindle.Processor.Image` to the adapter group
- `/Users/jon/projects/rindle/.github/workflows/ci.yml` — `quality` job is the insertion point for the doctor step
- `/Users/jon/projects/rindle/lib/rindle.ex` — facade; opaque return types to tighten + `@doc false` shim with `@deprecated` to add
- `/Users/jon/projects/rindle/lib/rindle/upload/broker.ex` — every public function lacks `@spec` (largest single gap)
- `/Users/jon/projects/rindle/lib/rindle/delivery.ex` — already complete; reference for what good looks like
- `/Users/jon/projects/rindle/lib/rindle/profile.ex` — `__using__/1` macro lacks doc/spec
- `/Users/jon/projects/rindle/lib/rindle/storage.ex` — 10+ `@callback`s without per-callback `@doc`; behaviour-level result types to define
- `/Users/jon/projects/rindle/lib/rindle/storage/local.ex`, `/Users/jon/projects/rindle/lib/rindle/storage/s3.ex` — adapter implementations; `@impl` callbacks reference the behaviour types
- `/Users/jon/projects/rindle/lib/rindle/authorizer.ex`, `/Users/jon/projects/rindle/lib/rindle/analyzer.ex`, `/Users/jon/projects/rindle/lib/rindle/scanner.ex`, `/Users/jon/projects/rindle/lib/rindle/processor.ex` — each has one `@callback` without `@doc`
- `/Users/jon/projects/rindle/lib/rindle/processor/image.ex` — Phase 18 D-27: promote to public adapter (expand `@moduledoc`, add `@impl`, add `@spec`)
- `/Users/jon/projects/rindle/test/rindle/api_surface_boundary_test.exs` — Phase 18 D-27: add `Rindle.Processor.Image` to `@public_modules`
- `/Users/jon/projects/rindle/lib/rindle/live_view.ex`, `/Users/jon/projects/rindle/lib/rindle/html.ex` — conditional-compile modules; `picture_tag/3` lacks `@doc`
- `/Users/jon/projects/rindle/lib/rindle/workers/abort_incomplete_uploads.ex`, `/Users/jon/projects/rindle/lib/rindle/workers/cleanup_orphans.ex` — `@moduledoc` enrichment + drop `@doc` on `perform/1`
- `/Users/jon/projects/rindle/lib/mix/tasks/rindle.*.ex` — five Mix tasks; `@shortdoc` + `@moduledoc` + `@impl true` only
- `/Users/jon/projects/rindle/lib/rindle/domain/media_asset.ex`, `media_attachment.ex`, `media_upload_session.ex`, `media_variant.ex`, `media_processing_run.ex` — five schema modules already complete with `@type t`; reference for what the named-type targets are

### Authoritative external references for Phase 18 patterns

**`mix doctor` behavior (research-validated, used to lock D-06 through D-10):**
- `https://hex.pm/packages/doctor` — version `0.22.0` (current stable as of April 2026)
- `https://hexdocs.pm/doctor/Mix.Tasks.Doctor.html` — CLI flags reference
- `https://github.com/akoutmos/doctor/blob/master/lib/cli/cli.ex` — `@moduledoc false` is NOT auto-skipped; `ignore_modules:` is required
- `https://github.com/akoutmos/doctor/blob/master/lib/config.ex` — full threshold defaults reference
- `https://github.com/akoutmos/doctor/blob/master/lib/module_information.ex` — `@callback` declarations are not analyzed
- `https://github.com/akoutmos/doctor/blob/master/lib/module_report.ex` — `@doc false` exempts from doc coverage but counts toward spec coverage
- `https://github.com/akoutmos/doctor/issues/67` — open issue confirming the `@moduledoc false` non-auto-skip behavior

**Documentation pattern precedents (used to lock D-11 through D-17):**
- `https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/repo.ex` — `Ecto.Repo.insert/2` schema `t()` return spec; `@doc deprecated:` metadata pattern
- `https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/adapter/schema.ex` — adapter behaviour callback shapes
- `https://github.com/elixir-tesla/tesla/blob/master/lib/tesla/adapter.ex` — behaviour-level result type alias (`Tesla.Env.result()`)
- `https://github.com/oban-bg/oban/blob/main/lib/oban/worker.ex` — `@callback` per-callback `@doc` pattern, `@doc since:` versioning
- `https://github.com/phoenixframework/phoenix/blob/main/lib/phoenix/endpoint.ex` — `@doc` immediately preceding `@callback` (22+ instances)
- `https://github.com/phoenixframework/phoenix/blob/main/lib/phoenix/controller.ex` — `@doc false` + `@deprecated` + `@spec` shim pattern; `__using__/1` doc placement
- `https://github.com/phoenixframework/phoenix_live_view/blob/main/lib/phoenix_live_view.ex` — `__using__/1` doc placement
- `https://github.com/elixir-ecto/ecto_sql/blob/master/lib/mix/tasks/ecto.migrate.ex` — Mix task pattern (`@shortdoc` + `@moduledoc` + `@impl true`, no `@doc`/`@spec` on `run/1`)
- `https://github.com/phoenixframework/phoenix/blob/main/installer/lib/mix/tasks/phx.new.ex` — Mix task pattern confirmation
- `https://github.com/hexpm/hex/blob/main/lib/mix/tasks/hex.publish.ex` — Mix task pattern confirmation
- `https://github.com/elixir-lang/elixir/blob/main/lib/mix/lib/mix/tasks/run.ex` — Elixir core's own Mix task pattern
- `https://github.com/plausible/analytics/blob/master/lib/workers/clean_user_sessions.ex` — production Oban `perform/1` pattern (no `@doc`)
- `https://github.com/mtrudel/thousand_island/blob/main/lib/thousand_island/handler.ex` — `@spec __using__(any) :: Macro.t()` precedent

**Real `.doctor.exs` configurations (used to lock D-07 / D-08):**
- `https://github.com/akoutmos/prom_ex/blob/master/.doctor.exs` — 90/90/90/90/100 thresholds (close to Rindle's chosen 100/100/95/95/100)
- `https://github.com/team-alembic/ash_authentication/blob/main/.doctor.exs` — Ash-family ignore_modules idiom (regex + explicit list)
- `https://github.com/agoodway/pgflow/blob/main/.doctor.exs` — comments explaining macro-module exemptions
- `https://github.com/agentjido/jido/blob/main/.doctor.exs` — comments explaining `quote do` traversal limitations

**CI integration precedents (used to lock D-09 / D-10):**
- `https://github.com/team-alembic/staple-actions/blob/main/actions/mix-doctor/action.yml` — canonical Ash-family `MIX_ENV=test mix doctor --full --raise` action
- `https://github.com/buildkite/test_collector_elixir/blob/main/.github/workflows/mix_doctor.yml` — same pattern, separate workflow file
- `https://github.com/ash-project/ash/blob/main/.github/workflows/ash-ci.yml` — full Ash CI showing doctor placement in a quality lane

**Ratchet / failing-harness pattern (used to lock D-22 / D-23):**
- `https://shopify.engineering/adopting-sorbet` — Sorbet rollout playbook (baseline-then-ratchet, avoid escape hatches)
- `https://www.notion.com/blog/how-we-evolved-our-code-notions-ratcheting-system-using-custom-eslint-rules` — Notion ESLint ratchet
- `https://mainmatter.com/blog/2025/03/03/lttf-process/` — Lint-to-the-Future ratchet pattern
- `https://rust-unofficial.github.io/patterns/anti_patterns/deny-warnings.html` — `#[warn(missing_docs)]` first, `#[deny(missing_docs)]` second

**Callback enforcement honor-system precedent (used to lock D-18 / D-19):**
- `https://github.com/elixir-ecto/ecto/blob/master/lib/ecto/adapter.ex` — Ecto.Adapter callback `@doc` convention (no enforcement)
- `https://github.com/elixir-plug/plug/blob/main/lib/plug/session/store.ex` — Plug.Session.Store callback `@doc` convention (no enforcement)
- `https://github.com/sorentwo/oban/blob/main/.credo.exs` — Oban ships stock Credo (no custom callback-doc check)
- `https://github.com/dashbitco/broadway/blob/main/lib/broadway/producer.ex` — Broadway.Producer callback docs
- `https://github.com/elixir-waffle/waffle/blob/master/lib/waffle/behaviors/storage_behaviour.ex` — counter-example (no per-callback `@doc`; widely considered weaker DX vs Shrine)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle` facade and `Rindle.Delivery` are already exemplar — every public function has `@doc` + `@spec`. Use them as the template for what "complete" looks like in Plans 18-02 / 18-03 / 18-04.
- All five `Rindle.Domain.*` schemas already define `@type t :: %__MODULE__{}` and `@spec changeset/2`. The named-type work in Plan 18-02 / D-03 is consuming these existing types from the facade and broker — not creating new ones.
- `mix.exs` already has the right deps shape (`{:credo, "~> 1.7", only: [:dev, :test], runtime: false}`) so `:doctor` lands in the same convention without disrupting anything.
- The Phase 17 `groups_for_modules` ExDoc configuration is correct as-is — Phase 18 doesn't change module visibility, only adds `@doc`/`@spec` to already-visible modules.
- The CI `quality` job (lines 78-107 of `.github/workflows/ci.yml`) already runs across an Elixir 1.15 + 1.17 matrix — the new doctor step inherits that matrix coverage for free.

### Established Patterns
- Phase 17 used the **failing-harness-first** rhythm successfully (17-01 was RED-only). Phase 18 mirrors it but with the harness as a unit test rather than a CI gate (D-22 / D-23) — the CI gate ships passing from day one with baseline thresholds, the failing test asserts the target.
- Project conventions are stable: `@spec` types use named types (Ecto pattern), telemetry is the observability primary (per Phase 17 D-13), `@moduledoc false` is the boundary marker (per Phase 17 D-05/D-07).
- `@impl` annotations are used consistently in adapter implementations, which means D-12 (Mix tasks) and D-13 (Oban workers) plug in cleanly without retrofitting `@impl` discipline.

### Integration Points
- `mix.exs` deps list — Plan 18-01 adds the `:doctor` line.
- `.github/workflows/ci.yml` `quality` job — Plan 18-01 adds the `mix doctor --full --raise` step.
- New file: `.doctor.exs` at project root — Plan 18-01 generates baseline; Plan 18-05 ratchets to target.
- New file: `test/rindle/doctor_thresholds_test.exs` — Plan 18-01 ships failing test; Plan 18-05 turns green.
- New file: `test/rindle/behaviour_docs_test.exs` — Plan 18-03 ships D-19 backstop using `Code.fetch_docs/1`.
- Optional: `CONTRIBUTING.md` (or new section in `README.md`) — Plan 18-04 / D-20 adds the single-line callback-doc convention.
- Updated: every public module from D-01 list across plans 18-02, 18-03, 18-04 — see plan order in D-24.

</code_context>

<specifics>
## Specific Ideas

- Prefer the term **"named result type"** over "named struct type" in planning and ExDoc prose, because not every result is a struct — some are multi-key result maps with named `@type` aliases (D-05). "Named struct type" comes from API-07's wording but the implementation is broader.
- When tightening `@spec` returns in Plan 18-02, retain `{:error, term()}` (or `{:error, atom()}` where the error vocabulary is fully enumerated) on the error branch — narrowing the error term is a Dialyzer-breaking change for any adopter pattern-matching on it, and `0.1.x` semver posture (Phase 17 D-08) blocks that.
- For the optional D-21 Membrane-style callback summary, prefer hand-written summaries over a macro-driven approach. Five behaviours × ~3 callbacks each is small enough; introducing a `DocsHelper` macro for ~15 callback names is over-engineering at this scale.
- When writing the `@deprecated "..."` attribute (D-16), keep the message terse and actionable in the Phoenix.Controller idiom — e.g. `@deprecated "Use Rindle.Internal.VariantFailureLogger.log/3 instead — this facade shim is kept for 0.1.x compatibility only"`. Adopters see this at compile time; brevity matters.
- The D-23 failing-test contract is intentionally narrow: it reads `.doctor.exs` and asserts `min_module_doc_coverage == 100`, etc. against the values from D-07. Don't over-design — three or four assertions is enough. The test is a failing harness, not a doctor reimplementation.

</specifics>

<deferred>
## Deferred Ideas

- **Stricter callback-doc enforcement** (custom Credo check or Elixir-side static check beyond the D-19 ExUnit backstop) — defer until ecosystem demand or actual drift incidents emerge. Rindle's behaviour count (5 modules, ~10 callbacks) is too small to justify novel tooling.
- **`mix docs --warnings-as-errors`** as a complementary CI step — research found this catches autolink/extras-link issues but NOT missing `@callback` docs. Modest DX value; defer to Phase 19 or later if extras/guides churn warrants it.
- **Per-module `min_module_*` overrides** in `.doctor.exs` — defer until D-07's strict 100/95 thresholds prove problematic in practice. If a specific module needs lower thresholds, address in a focused fix-up rather than baking exemptions into Phase 18.
- **`@doc since:` annotations on every existing callback** — D-11 keeps this optional and only for *new* callbacks introduced after `0.1.0`. Retroactive `@doc since: "0.1.0"` everywhere is noise. If versioning discipline becomes valuable later, address in a separate small phase.
- **`Rindle.Storage.Adapter` as a separate behaviour module** — D-04 places the result types directly on `Rindle.Storage`, which currently holds both adapter behaviour and dispatch logic. Splitting `Storage` from `Storage.Adapter` is a Phase 17-class boundary change and belongs to a future cleanup, not Phase 18.
- **Removing `Rindle.verify_upload/2` and `Rindle.log_variant_processing_failure/3` shims entirely** — Phase 17 D-11 / 17-CONTEXT deferred deferred ideas already; both compatibility shims live until `0.2.0` per the locked semver posture. Phase 18 only adds the `@deprecated` annotation (D-16) and keeps the existing `@doc deprecated:` metadata (D-17).
- **Membrane-style auto-injected callback list macro** — D-21 keeps the option of hand-written summaries; macro-driven generation is over-engineering for five behaviours but could become valuable if the behaviour count grows substantially.

### Reviewed Todos (not folded)
None — the two pending todos in STATE.md (`Plan GCS adapter resumable upload flow (GCS-01)`, `Evaluate tus/resumable protocol once release distribution is routine (TUS-01)`) are unrelated to documentation/typespec coverage and stay parked.

</deferred>

---

*Phase: 18-documentation-and-typespec-coverage*
*Context gathered: 2026-04-30 (assumptions mode + 3 parallel research subagents: callback-enforcement, plan-slicing, ecosystem-cross-validation)*
