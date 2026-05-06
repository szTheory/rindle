# Phase 32: Upgrade & Migration Safety - Research

**Researched:** 2026-05-06
**Domain:** Generated-app upgrade proof, additive AV migration safety, deterministic partial-upgrade recovery, and upgrade-guide docs parity for Rindle.
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** The canonical proof lane is the existing generated Phoenix package-consumer harness extended to start from a simulated pre-v1.4 adopter shape.
- **D-02:** The proof lane must use the same public migration/runtime path the docs teach, including `Application.app_dir(:rindle, "priv/repo/migrations")`, adopter-owned Repo wiring, and public Mix/task/facade surfaces.
- **D-03:** Do not introduce a full pinned fixture adopter app unless the generated-app lane cannot model a required state truthfully.
- **D-04:** Keep backward-compat guardrails intact. Image-only upgrade safety must preserve legacy digest/data expectations.
- **D-05:** The canonical recovery story is one narrative: legacy image-only data upgrades safely, then newly introduced AV work is interrupted and recovered through explicit repair verbs.
- **D-06:** Use deterministic seeded failed/cancelled/drift state, not timing-heavy stuck-worker simulation.
- **D-07:** Use asset-scoped `Rindle.requeue_variants/2` as the sharp repair surface for one-asset interrupted AV work.
- **D-08:** `mix rindle.regenerate_variants` remains the broad maintenance lane for drift and must not replace the single-asset recovery story.
- **D-09:** `mix rindle.doctor` and `mix rindle.runtime_status` remain read-only verification/reporting surfaces.
- **D-10:** Ship one dedicated, linear, checkpointed upgrade runbook for existing adopters.
- **D-11:** The runbook sequence should be explicit: dependencies/config/runtime expectations, explicit migrations, `mix rindle.doctor`, optional `mix rindle.runtime_status`, then the right repair verb.
- **D-12:** The runbook must be copy-pasteable and parity-testable.
- **D-13:** The runbook should deep-link to `guides/operations.md` and `guides/troubleshooting.md` rather than duplicate them.
- **D-14** through **D-17:** Preserve a clean greenfield vs upgrade docs split with a dedicated `guides/upgrading.md` plus discoverable cross-links from README, getting-started, and release docs.
- **D-18** through **D-20:** Keep the ecosystem posture explicit, additive, migration-first, and free of hidden remediation.
- **D-21** and **D-22:** Decide by default; escalate only for high-blast-radius changes.

### Deferred Ideas (OUT OF SCOPE)

- Automatic repair or mutation inside diagnostics
- A second dashboard or control-plane surface
- Broad rollout orchestration outside Rindle-owned migrations, diagnostics, and repair verbs
- A frozen fixture host app as the primary proof lane
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UPGRADE-01 | Maintainer can upgrade a pre-v1.4 adopter app into the current AV-aware schema/runtime shape using additive migrations and documented steps only. | Extend the generated-app smoke harness to create a legacy schema/runtime state, then run the same explicit migration snippet already taught in README/getting-started and assert the upgraded app boots and preserves image-only behavior. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`, `test/install_smoke/generated_app_smoke_test.exs`, `README.md`, `guides/getting_started.md`, `priv/repo/migrations/20260502120000_extend_media_for_av.exs`] |
| UPGRADE-02 | Interrupted AV processing and partial-upgrade states can be recovered through documented repair commands that are proven in CI. | Seed one deterministic post-upgrade asset/variant failure shape and prove operator recovery through `mix rindle.doctor`, optional `mix rindle.runtime_status`, and `Rindle.requeue_variants/2`, while keeping regeneration as a separate drift lane. [VERIFIED: `lib/rindle/ops/lifecycle_repair.ex`, `lib/rindle/ops/runtime_checks.ex`, `lib/rindle/ops/runtime_status.ex`, `lib/mix/tasks/rindle.runtime_status.ex`, `lib/mix/tasks/rindle.regenerate_variants.ex`] |
| UPGRADE-03 | Release and upgrade guides teach both greenfield install and existing-adopter upgrade paths without assuming a fresh app. | Add a dedicated `guides/upgrading.md`, then lock discoverability and wording parity through docs tests rather than sprinkling upgrade steps through every guide. [VERIFIED: `README.md`, `guides/getting_started.md`, `guides/operations.md`, `guides/troubleshooting.md`, `guides/release_publish.md`, `test/install_smoke/docs_parity_test.exs`] |
</phase_requirements>

## Summary

Phase 32 should not invent a new upgrade framework. The repo already has the right outside-in seam in `Rindle.InstallSmoke.GeneratedAppHelper`: it creates a real Phoenix adopter app, patches runtime/config/migrations, and proves the public package-consumer path from installed artifacts. The correct move is to extend that harness to model a truthful pre-v1.4 starting point, then run the same explicit migration snippet the docs already teach. [VERIFIED: `test/install_smoke/support/generated_app_helper.ex`, `README.md`, `guides/getting_started.md`]

The migration risk is narrowly defined and already visible in the codebase. Phase 24 added `media_assets.kind` and `media_variants.output_kind` as additive columns with `default: "image"`, and a load-bearing backward-compat test already guards the v1.3 image digest against accidental AV-era drift. Phase 32 should build on that posture instead of widening scope into schema-diff tooling or hidden data rewrites. [VERIFIED: `priv/repo/migrations/20260502120000_extend_media_for_av.exs`, `test/rindle/backward_compat/v13_digest_snapshot_test.exs`]

The best recovery proof is post-upgrade and deterministic: create a legacy-upgraded asset, seed one failed or cancelled AV variant after upgrade, verify diagnosis through read-only commands, and recover through the asset-scoped repair API already introduced in Phase 30. That keeps the story honest, CI-friendly, and aligned with the operator vocabulary the docs already use. [VERIFIED: `lib/rindle/ops/lifecycle_repair.ex`, `lib/rindle/ops/runtime_status.ex`, `guides/operations.md`, `guides/troubleshooting.md`]

**Primary recommendation:** split Phase 32 into three plans: 1) generated-app upgrade proof plus legacy-data safety, 2) deterministic partial-upgrade recovery proof and CI wiring, 3) dedicated upgrade guide plus docs parity and release-facing cross-links. That decomposition maps one-to-one to `UPGRADE-01` through `UPGRADE-03` while keeping docs work downstream of implemented proof. 

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Pre-v1.4 generated-app simulation | Test harness | Database / migrations | The upgrade starting state is best modeled in the existing generated Phoenix app helper, not by a frozen fixture app. |
| Explicit migration proof | Mix/runtime + Ecto | Docs | The proof must exercise the same `Ecto.Migrator` path the public docs teach. |
| Legacy image-only safety | Backward-compat tests | Install smoke | Digest and image-default invariants already exist and should be extended, not replaced. |
| Deterministic interrupted AV recovery | Public repair API + diagnostics | Install smoke | Recovery should reuse `doctor`, `runtime_status`, and `requeue_variants`, not introduce bespoke test-only verbs. |
| Upgrade-guide parity | Docs + docs tests | Release docs | One canonical upgrade guide should feed discoverability from README/getting-started/release surfaces. |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir | repo toolchain | Generated-app harness, Mix tasks, docs-parity tests | All current proof lanes already live in ExUnit/Mix. |
| Ecto SQL | repo-locked | Explicit migration execution and schema state | The current adopter contract is explicit `Ecto.Migrator` use, not hidden automation. |
| Oban | repo-locked | Truthful queue/runtime shape for post-upgrade AV work | Recovery proof must use the real job/runtime assumptions Rindle already owns. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extend generated-app helper | Pinned fixture adopter app | Rejected because it creates a second truth source and violates D-03 unless the helper proves insufficient. |
| Deterministic failed/cancelled seeded state | Timing-based stuck-job simulation | Rejected because CI should prove operator workflow, not race the scheduler. |
| Dedicated `guides/upgrading.md` | Scatter upgrade steps through README/getting-started/release notes | Rejected because it muddies the greenfield path and becomes hard to parity-test. |
| Asset-scoped `Rindle.requeue_variants/2` recovery | `mix rindle.regenerate_variants` everywhere | Rejected because regeneration is the broad maintenance lane, not the safest single-asset recovery verb. |

## Architecture Patterns

### Recommended Execution Shape

```text
generated Phoenix app
    -> patch to legacy pre-v1.4 runtime shape
    -> run host + packaged Rindle migrations explicitly
    -> verify image-only legacy data still behaves correctly
    -> upgrade to AV-capable profile/runtime
    -> seed deterministic AV failure on one asset
    -> run doctor / runtime_status
    -> repair with requeue_variants
    -> assert successful recovery and docs parity
```

## Suggested Plan Decomposition

### Plan 32-01

Extend the generated-app harness to create a truthful pre-v1.4 starting point, execute the documented migration handoff, and assert legacy image-only safety after upgrade.

### Plan 32-02

Reuse the upgraded generated app to seed one deterministic failed/cancelled AV-work scenario, then prove diagnosis and recovery through existing public diagnostics and repair surfaces in CI.

### Plan 32-03

Publish `guides/upgrading.md`, add discoverability links from README/getting-started/release docs, and lock the split with docs-parity assertions.

## Risks and Mitigations

1. The helper may accidentally simulate a state that no real pre-v1.4 adopter could have reached.
Mitigation: build the starting point from the actual pre-AV migration set and public config contract, not by ad hoc DB mutation alone.

2. Upgrade proof could validate schema only while missing image-default compatibility.
Mitigation: extend the existing digest/backward-compat posture and assert legacy image-only lifecycle behavior after upgrade.

3. Recovery proof could drift into broad regeneration or implicit fixes.
Mitigation: force the proof narrative through read-only diagnosis first, then asset-scoped `requeue_variants/2`.

4. Docs could regress into greenfield/upgrade conflation.
Mitigation: keep all full upgrade procedure text in `guides/upgrading.md` and test only cross-links elsewhere.
