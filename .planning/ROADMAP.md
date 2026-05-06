# Roadmap: Rindle

## Milestones

- 🚧 **v1.5 Adopter Hardening & Lifecycle Repair** — Phases 29–32 (active)
- ✅ **v1.0 MVP** — Phases 1–5 (shipped 2026-04-xx, see archive)
- ✅ **v1.1 Adopter Hardening** — Phases 6–9 (shipped 2026-04-28, see archive)
- ✅ **v1.2 First Hex Publish** — Phases 10–14 (shipped 2026-04-29, see archive)
- ✅ **v1.3 Live Publish & API Ergonomics** — Phases 15–22 (shipped 2026-05-02, see archive)
- ✅ **v1.4 Video & Audio Wedge** — Phases 23–28 (shipped 2026-05-05, see archive)

## Phases

- [ ] **Phase 29: Adopter Proof Matrix** - Published package-consumer flows
  prove image-only and AV-enabled adoption outside the repo.
- [ ] **Phase 30: Lifecycle Repair Operations** - Operators can explicitly
  repair, requeue, regenerate, and sweep drifted lifecycle state.
- [ ] **Phase 31: Runtime Diagnostics & Drift Visibility** - Runtime
  misconfiguration, capability drift, and stuck work become visible before
  adopters guess.
- [ ] **Phase 32: Upgrade & Migration Safety** - Existing adopters can move
  into the AV-aware lifecycle shape and recover partial upgrades safely.

## Phase Details

### Phase 29: Adopter Proof Matrix
**Goal**: Published Rindle artifacts prove the real adopter happy path for both
image-only and AV-enabled consumers, with docs locked to that outside-in proof.
**Depends on**: Phase 28
**Requirements**: PROOF-01, PROOF-02, PROOF-03, PROOF-04
**Success Criteria** (what must be TRUE):
1. Maintainer can generate a fresh package-consumer Phoenix app for an
   image-only profile and complete install, upload, processing, and signed
   delivery from the published artifact.
2. Maintainer can generate a fresh package-consumer Phoenix app for an
   AV-enabled profile and complete install, probe, transcode, local playback,
   and signed delivery from the published artifact.
3. CI proves the canonical adopter matrix across local storage and at least one
   real S3-compatible path without regressing the existing happy path.
4. README, getting-started, AV onboarding, and ops guidance stay in executable
   parity with the proved package-consumer flows.
**Plans**:
- `29-01-PLAN.md` — stabilize the image-only generated-app package-consumer proof for built and published artifacts
- `29-02-PLAN.md` — extend the generated-app harness to prove the AV-enabled package-consumer path
- `29-03-PLAN.md` — wire the package-consumer image/AV proof matrix into CI and release-facing entrypoints
- `29-04-PLAN.md` — lock README/getting-started/operations docs to the proved package-consumer matrix

### Phase 30: Lifecycle Repair Operations
**Goal**: Operators have explicit, auditable public operations to repair failed,
cancelled, or drifted media lifecycle state.
**Depends on**: Phase 29
**Requirements**: REPAIR-01, REPAIR-02, REPAIR-03, REPAIR-04, REPAIR-05
**Success Criteria** (what must be TRUE):
1. Operator can re-probe an asset and see refreshed probe fields persisted
   without unrelated lifecycle state changing.
2. Operator can requeue failed or cancelled variants for a specific asset
   through an idempotent public repair surface.
3. Operator can regenerate a variant set after preset or profile changes
   through an explicit, auditable operation.
4. Operator can sweep orphaned temp files, stale lifecycle rows, and other
   repairable residue both on demand and through scheduled maintenance.
5. Repair operations emit tagged, operator-readable failure reasons instead of
   silently hiding partial failure.
**Plans**: TBD

### Phase 31: Runtime Diagnostics & Drift Visibility
**Goal**: Operators can detect capability drift, queue or delivery
misconfiguration, and stuck lifecycle work from supported diagnostics instead of
guesswork.
**Depends on**: Phase 30
**Requirements**: DIAG-01, DIAG-02, DIAG-03
**Success Criteria** (what must be TRUE):
1. `mix rindle.doctor` flags runtime capability drift, missing queues, delivery
   plug misconfiguration, and stale migration state with actionable fix
   guidance.
2. Operator can run a documented runtime status report or equivalent query path
   to inspect stuck or failed assets, variants, and upload sessions.
3. Telemetry for repair flows, runtime refusals, and operational drift is
   stable, documented, and usable for dashboards and alerts.
**Plans**: TBD

### Phase 32: Upgrade & Migration Safety
**Goal**: Existing adopters can upgrade from pre-v1.4 installs into the current
AV-aware lifecycle shape with additive migrations, recovery steps, and guide
parity.
**Depends on**: Phase 29, Phase 30, Phase 31
**Requirements**: UPGRADE-01, UPGRADE-02, UPGRADE-03
**Success Criteria** (what must be TRUE):
1. Maintainer can upgrade a pre-v1.4 adopter app into the current AV-aware
   schema and runtime shape using additive migrations and documented steps
   only.
2. Interrupted AV processing and partial-upgrade states can be recovered
   through documented repair commands that are proved in CI.
3. Release and upgrade guides teach both greenfield install and
   existing-adopter upgrade paths without assuming a fresh app.
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 29. Adopter Proof Matrix | 1/4 | In progress | 2026-05-05 |
| 30. Lifecycle Repair Operations | 0/0 | Not started | - |
| 31. Runtime Diagnostics & Drift Visibility | 0/0 | Not started | - |
| 32. Upgrade & Migration Safety | 0/0 | Not started | - |

## Archive

<details>
<summary>✅ v1.4 Video & Audio Wedge (Phases 23–28) — SHIPPED 2026-05-05</summary>

Full archive: [.planning/milestones/v1.4-ROADMAP.md](.planning/milestones/v1.4-ROADMAP.md)

</details>

<details>
<summary>✅ v1.3 Live Publish & API Ergonomics (Phases 15–22) — SHIPPED 2026-05-02</summary>

Full archive: [.planning/milestones/v1.3-ROADMAP.md](.planning/milestones/v1.3-ROADMAP.md)

</details>

<details>
<summary>✅ v1.2 First Hex Publish (Phases 10–14) — SHIPPED 2026-04-29</summary>

Full archive: [.planning/milestones/v1.2-ROADMAP.md](.planning/milestones/v1.2-ROADMAP.md)

</details>

<details>
<summary>✅ v1.1 Adopter Hardening (Phases 6–9) — SHIPPED 2026-04-28</summary>

Full archive: [.planning/milestones/v1.1-ROADMAP.md](.planning/milestones/v1.1-ROADMAP.md)

</details>

<details>
<summary>✅ v1.0 MVP (Phases 1–5) — SHIPPED</summary>

Full archive: [.planning/milestones/v1.0-ROADMAP.md](.planning/milestones/v1.0-ROADMAP.md)

</details>
