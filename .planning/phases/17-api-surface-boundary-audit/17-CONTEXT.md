# Phase 17: API Surface Boundary Audit - Context

**Gathered:** 2026-04-30 (assumptions mode, research-driven via 4 parallel subagents)
**Status:** Ready for planning

<domain>
## Phase Boundary

Lock Rindle's public-vs-internal API boundary before the documentation/typespec sprint. This phase decides which modules and functions are intentionally supported, hides implementation-only modules from ExDoc, resolves or safely stages naming inconsistencies, and records the semver posture for any cleanup that would otherwise surprise adopters on the already-published `0.1.x` line.

This phase does **not** expand feature scope. It narrows and clarifies the existing surface so Phase 18 can document the right API instead of accidental internals.
</domain>

<decisions>
## Implementation Decisions

### Public surface architecture
- **D-01:** Rindle will use a **layered public surface**: `Rindle` as the primary first-run facade, plus a small set of explicitly supported subsystem modules for advanced and operational use. Do not treat the entire visible namespace as public.
- **D-02:** First-tier adopter docs must start with exactly two concepts: `Rindle` and `Rindle.Profile`. README and getting-started content should teach the facade-first path, not lower-level modules by default.
- **D-03:** The following modules remain intentionally public because adopters are expected to reference them directly: `Rindle`, `Rindle.Profile`, `Rindle.Upload.Broker`, `Rindle.Delivery`, `Rindle.Storage`, `Rindle.Storage.S3`, `Rindle.Storage.Local`, `Rindle.Authorizer`, `Rindle.Analyzer`, `Rindle.Scanner`, `Rindle.Processor`, `Rindle.LiveView`, `Rindle.HTML`, `Mix.Tasks.Rindle.*`, `Rindle.Workers.AbortIncompleteUploads`, and `Rindle.Workers.CleanupOrphans`.
- **D-04:** Domain schema modules (`Rindle.Domain.MediaAsset`, `MediaAttachment`, `MediaUploadSession`, `MediaVariant`, and `MediaProcessingRun`) remain public **as queryable/reference data types only**. Lifecycle mutation and orchestration stay on `Rindle` and the explicitly supported advanced modules, not on FSM internals.

### Hidden/internal boundary
- **D-05:** Hide implementation-only modules from ExDoc with `@moduledoc false`. This includes `Rindle.Config`, `Rindle.Repo`, `Rindle.Security.*`, `Rindle.Profile.Validator`, `Rindle.Profile.Digest`, `Rindle.Storage.Capabilities`, `Rindle.Domain.AssetFSM`, `Rindle.Domain.UploadSessionFSM`, `Rindle.Domain.VariantFSM`, `Rindle.Domain.StalePolicy`, `Rindle.Workers.PromoteAsset`, `Rindle.Workers.ProcessVariant`, and `Rindle.Workers.PurgeStorage`.
- **D-06:** `Rindle.Ops.*` should be treated as hidden/internal for now. Keep the public operational story on `mix rindle.*` tasks and the two adopter-scheduled maintenance workers, rather than supporting direct in-process `Rindle.Ops.*` invocation as long-term contract.
- **D-07:** Do not rely on `@doc false` alone to define module boundaries. If a module is implementation-only, hide the module itself; `@doc false` is only for narrow compatibility shims on otherwise-public modules.

### Naming and semver posture
- **D-08:** No breaking renames or removals land on `0.1.x` unless they are additive-compatible. Phase 17 should prefer additive aliases, hidden compatibility shims, and explicit deferral over surprising published adopters.
- **D-09:** Add `Rindle.verify_completion/2` now as the preferred public name for the direct-upload verification boundary. Keep `Rindle.verify_upload/2` as a compatibility shim during `0.1.x`, and teach `verify_completion/2` in docs going forward.
- **D-10:** Keep `Rindle.complete_multipart_upload/3` unchanged. It names a transport-specific multipart completion step and should not be forced into false symmetry with the direct-upload verification concept.
- **D-11:** Record `verify_upload/2` as legacy compatibility surface, not the canonical future-facing verb. Any hard removal belongs to `v0.2.0` or later.

### Observability and helper exposure
- **D-12:** `Rindle.log_variant_processing_failure/3` should stop being part of the documented public facade. Move its implementation behind a hidden internal module, keep a thin `Rindle` compatibility shim in `0.1.x`, and mark the facade entrypoint `@doc false` with explicit rationale.
- **D-13:** Rindle's public observability posture stays **telemetry-first**, not “call this logging helper” first. If richer adopter-facing observability is needed later, add stable telemetry or documented operator hooks instead of promoting internal logging helpers.

### Documentation IA and DX
- **D-14:** ExDoc should reflect tiers explicitly via `groups_for_modules`. Recommended groups: `Facade`, `Profiles`, `Upload`, `Delivery`, `Optional Integrations`, `Extension Points`, `Storage Adapters`, `Operations`, and `Data Types`.
- **D-15:** Getting-started docs should show the facade path (`Rindle.initiate_upload` / `Rindle.verify_completion` or `Rindle.upload`, `Rindle.attach`, `Rindle.url`) and only branch into `Rindle.Upload.Broker`, `Rindle.Delivery`, `LiveView`, adapter, and extension-point material in advanced sections.
- **D-16:** Do not leave real `@moduledoc` text on implementation modules just because the docs read well. In this ecosystem, visible docs are an API promise; ExDoc output must match the intended support boundary.

### Decision-making preference
- **D-17:** Planning and implementation should continue to use the repo's existing preference: agent decides by default, with escalation only for genuinely high-impact choices such as public semver breaks, destructive data/security changes, irreversible infra/cost moves, or product-scope shifts. This phase's boundary recommendations are locked accordingly without further blocking questions.

### the agent's Discretion
- Exact `groups_for_modules` naming and grouping order in `mix.exs`, as long as the layered IA remains clear.
- Exact compatibility-shim wording for deprecated or hidden functions in `Rindle`.
- Exact file/module name for the hidden observability helper behind `log_variant_processing_failure/3`.
- Exact guide split between onboarding, optional integrations, operations, and reference material, as long as the facade-first path stays primary.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and requirements
- `.planning/ROADMAP.md` — Phase 17 goal, success criteria, and boundary against Phase 18 docs/typespec work
- `.planning/REQUIREMENTS.md` — `API-01` through `API-05`, especially the breakage and internal-surface requirements
- `.planning/PROJECT.md` — current milestone intent, `0.1.4` publish reality, and “clean up the public API surface before adoption grows”
- `.planning/STATE.md` — decision-making preference (`agent decides`; escalate only high-impact items)

### Existing public-story docs that define current expectations
- `README.md` — current quickstart and current lower-level API teaching posture
- `guides/getting_started.md` — canonical deep adopter guide; currently teaches broker-first direct upload
- `guides/profiles.md` — profile DSL and extension surface
- `guides/secure_delivery.md` — `Rindle.Delivery` and authorizer-facing delivery contract
- `guides/background_processing.md` — worker and telemetry story
- `guides/operations.md` — public operational surface via Mix tasks and scheduled maintenance
- `guides/core_concepts.md` — domain types and lifecycle concepts that constrain what can be hidden cleanly

### Existing code surface under audit
- `lib/rindle.ex` — top-level facade; contains the naming inconsistency and accidental helper exposure
- `lib/rindle/upload/broker.ex` — lower-level upload orchestration API and canonical `verify_completion/2` naming
- `lib/rindle/delivery.ex` — delivery subsystem public boundary
- `lib/rindle/profile.ex` — first-tier profile DSL surface
- `lib/rindle/storage.ex` — storage behaviour contract
- `lib/rindle/storage/local.ex` — local adapter
- `lib/rindle/storage/s3.ex` — S3-compatible adapter
- `lib/rindle/live_view.ex` — optional Phoenix integration
- `lib/rindle/html.ex` — optional Phoenix HTML integration
- `lib/rindle/authorizer.ex` — delivery authorization extension seam
- `lib/rindle/analyzer.ex` — metadata analyzer extension seam
- `lib/rindle/scanner.ex` — scanning extension seam
- `mix.exs` — ExDoc config surface and public docs layout controls

### Ecosystem references that informed the locked decisions
- `https://hexdocs.pm/elixir/1.19.0-rc.0/writing-documentation.html` — docs as API contract; internal-module hiding guidance
- `https://hexdocs.pm/ex_doc/ExDoc.html` — ExDoc grouping and module visibility posture
- `https://hexdocs.pm/phoenix/api-reference.html` — intentionally broad-but-supported framework module surface
- `https://hexdocs.pm/plug/api-reference.html` — supported extension seams and public module organization
- `https://hexdocs.pm/ecto_sql/api-reference.html` — layered public surface and “used internally” caution patterns
- `https://hexdocs.pm/oban/Oban.Worker.html` — worker modules as public only when callers are meant to schedule/enqueue them
- `https://hexdocs.pm/elixir/compatibility-and-deprecations.html` — soft-deprecation compatibility posture
- `https://hexdocs.pm/elixir/1.14.1/Version.html` — `~>` semantics, relevant to future breaking-release guidance
- `https://shrinerb.com/docs/getting-started` — layered library DX and extension seams
- `https://edgeguides.rubyonrails.org/active_storage_overview.html` — first-run ergonomics vs hidden-seam footguns

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/rindle.ex` already contains enough common lifecycle entrypoints to support a facade-first onboarding story; the docs simply are not centered on it yet.
- `lib/rindle/upload/broker.ex` already uses the clearer `verify_completion/2` terminology that should be lifted to the public facade.
- `mix.exs` already owns ExDoc configuration, so Phase 17 can enforce the new IA without inventing a separate docs system.
- Existing guides already segment onboarding, delivery, profiles, operations, and background processing; this structure can be tightened rather than replaced.

### Established Patterns
- The project already distinguishes adopter-facing runtime seams from implementation detail in architecture, but that distinction is inconsistently reflected in module docs visibility.
- Telemetry is already the real observability contract in guides and tests; the facade-level logging helper is an exception, not the rule.
- Scheduler-facing maintenance workers (`AbortIncompleteUploads`, `CleanupOrphans`) are materially different from internal pipeline workers (`PromoteAsset`, `ProcessVariant`, `PurgeStorage`) and should be documented differently.
- Domain schemas are valuable query/reference types for adopters, but FSM modules are implementation invariants and should not be treated as equivalent public API.

### Integration Points
- `mix.exs` ExDoc configuration will need module grouping and possibly guide ordering changes to reflect the new layered public surface.
- `README.md` and `guides/getting_started.md` need to switch from broker-first examples to facade-first examples.
- `lib/rindle.ex` is the implementation point for `verify_completion/2`, the compatibility stance for `verify_upload/2`, and the hidden shim stance for `log_variant_processing_failure/3`.
- Internal modules listed above need `@moduledoc false` so ExDoc no longer advertises them as public contract.

</code_context>

<specifics>
## Specific Ideas

- Prefer the term **“facade-first, layered public surface”** in planning and docs rather than “minimal API” or “everything public.” It better matches how Elixir libraries like Ecto, Phoenix, and Req balance beginner and expert paths.
- When documenting the domain schema modules, state plainly that they are **queryable/reference types**, not invitation to bypass lifecycle APIs.
- When planning any future breaking cleanup, remember that current install docs use `{:rindle, "~> 0.1"}` and that range admits `0.2.0`; any future breaking release should revisit dependency guidance and changelog posture deliberately.
- If planning chooses to add deprecation annotations, keep them terse and actionable: “Use `verify_completion/2`” is enough.

</specifics>

<deferred>
## Deferred Ideas

- Remove the `verify_upload/2` compatibility shim in `v0.2.0` or later once the facade/docs/test surface has fully converged on `verify_completion/2`.
- Remove the `Rindle.log_variant_processing_failure/3` compatibility shim in `v0.2.0` or later if no adopter need emerges.
- Revisit whether `Rindle.Ops.*` should become intentionally supported operator APIs only if a real adopter use case appears; default is hidden for now.
- If Phase 18 or later wants stronger “public API manifest” guarantees, consider adding explicit contract tests around visible modules/functions instead of relying on ExDoc visibility alone.
- Project-wide GSD preference shifting is already effectively present via `.planning/STATE.md` plus saved feedback-memory precedent; no new config mechanism should be invented in this phase without a broader workflow change.

</deferred>

---

*Phase: 17-api-surface-boundary-audit*
*Context gathered: 2026-04-30 (assumptions mode + 4 parallel research subagents)*
