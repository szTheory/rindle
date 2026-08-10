# Phase 120: Adoption Proof & Release Truth - Context

**Gathered:** 2026-08-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Prove the shipped 0.4.0 schema-isolation contract through packed artifacts, generated Phoenix applications, the Cohort/adoption demos, and public documentation. This phase validates and explains the completed routing, migration, and diagnostic contracts; it does not redesign them.

</domain>

<decisions>
## Implementation Decisions

### Proof topology
- **D-120-01:** Treat the packed Hex-equivalent artifact as the release authority. Generated-app proof must install the packed artifact, run a host-owned `Oban.Migration` in `public`, run `Rindle.Migration` with its default `rindle` prefix, boot, and exercise a real Rindle persistence path. — **Reversibility:** costly — weakening this proof would allow checkout-only behavior to ship.
- **D-120-02:** Keep an explicit compatibility proof for `Rindle.Migration.up(version: 1, prefix: "public")`; do not turn compatibility into a third routing mode or imply arbitrary schema support.
- **D-120-03:** Reuse the existing generated-app helper, install-smoke conventions, Cohort/adoption-demo migration harnesses, and docs-parity tests. Extend their assertions instead of creating a competing release test system.

### Documentation and release truth
- **D-120-04:** Make README, getting-started, migration API docs, upgrading guidance, troubleshooting, generated-app fixtures, and release notes agree: `rindle` is the 0.4.0 default; `public` is the intentional compatibility escape hatch; populated upgrades require a host-owned maintenance-window migration; Oban and the host Ecto ledger remain host-owned in `public`.
- **D-120-05:** Documentation must be operationally honest: name the required ordering (backup/quiesce, host migration, matching deploy, doctor/runtime verification), required permissions and lock behavior, and the narrow guarded rollback truth. Do not promise online or automatic migration.

### Scope fences
- **D-120-06:** Do not alter Phase 117 routing authority, Phase 118 move semantics, or Phase 119 diagnostic classification except where a proof exposes an actual defect. Do not create, move, configure, or prefix `oban_jobs` or host `schema_migrations`.

### the agent's Discretion
- Split proof and documentation work into dependency-safe vertical slices, select focused command invocations, and use existing fixture conventions while retaining real packed-artifact coverage.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone contracts
- `.planning/ROADMAP.md` §Phase 120 — goal, requirements, and success criteria.
- `.planning/REQUIREMENTS.md` §Adoption Proof & Release Truth — PROOF-01, PROOF-02, and DOCS-01.
- `.planning/phases/118-isolated-migration-safe-upgrade/118-CONTEXT.md` — selected-prefix provisioning, exact move scope, maintenance-window, rollback, and Oban ownership contract.
- `.planning/phases/119-ownership-boundaries-diagnostics/119-CONTEXT.md` — bounded doctor/runtime status and independent Oban boundary.

### Existing proof and documentation surfaces
- `test/install_smoke/generated_app_smoke_test.exs` and `test/install_smoke/support/generated_app_helper.ex` — packed generated Phoenix application proof harness.
- `test/install_smoke/docs_parity_test.exs` — public documentation contract assertions.
- `examples/adoption_demo/priv/rindle_migrate.exs` and `examples/adoption_demo/priv/repo/migrations/20260528120100_add_oban.exs` — demo migration boundaries.
- `README.md`, `guides/getting_started.md`, `guides/upgrading.md`, `guides/troubleshooting.md`, and `guides/release_publish.md` — adopter and release-facing truth.
- `RUNNING.md` — required CI lanes and release gates.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/install_smoke/support/generated_app_helper.ex`: writes host and Rindle migrations, installs a packed artifact, and inspects schema ownership.
- `test/install_smoke/docs_parity_test.exs`: validates repeatable public documentation snippets and policy text.
- `examples/adoption_demo`: already owns its Oban migration and Rindle migration runner.

### Established Patterns
- Host apps own `Oban.Migration`, `oban_jobs`, and the Ecto ledger; Rindle owns only its fixed relation set.
- The only supported Rindle prefixes are `rindle` by default and explicit `public` compatibility.
- Release proof must exercise generated/packed consumers, not merely repository source.

### Integration Points
- Packed generated-app smoke, Cohort/adoption-demo startup, migration snippets, docs-parity coverage, and release documentation must describe the same install contract.

</code_context>

<specifics>
## Specific Ideas

No additional product capability is requested; use calm, concrete developer/operator language and demonstrate the real released contract.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within Phase 120 proof and release-truth scope.

</deferred>

---

*Phase: 120-Adoption Proof & Release Truth*
*Context gathered: 2026-08-09*
