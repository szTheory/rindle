# Roadmap: Rindle

## Milestones

- ✅ **v1.22 OSS Quality & Trust Hardening** — Phases 113–116 (shipped 2026-07-02, 14/14 reqs EVAL/TRUST/META/VERSION/README/MIGRATE/HYGIENE; [archive](milestones/v1.22-ROADMAP.md), [requirements](milestones/v1.22-REQUIREMENTS.md), [audit](milestones/v1.22-MILESTONE-AUDIT.md))
- ✅ **v1.21 CI/DX Reliability Tail** — Phases 108–112 (shipped 2026-06-29, non-feature/DX, ships Hex 0.3.2 via two adopter-invisible `lib/` `fix:` patches D-v1.21-01; 24/24 reqs COV/EPIPE/GATE/ISO/LOCK/TRUTH; [archive](milestones/v1.21-ROADMAP.md), [requirements](milestones/v1.21-REQUIREMENTS.md), [audit](milestones/v1.21-MILESTONE-AUDIT.md))
- ✅ **v1.20 CI/CD Performance** — Phases 103–107 (shipped 2026-06-22, non-feature / DX-infra, ZERO `lib/` change, 18/18 reqs; [archive](milestones/v1.20-ROADMAP.md), [requirements](milestones/v1.20-REQUIREMENTS.md), [audit](milestones/v1.20-MILESTONE-AUDIT.md))
- ✅ **v1.19 Design-System Stress-Test** — Phases 94-102 (shipped 2026-06-19, [archive](milestones/v1.19-ROADMAP.md), [audit](milestones/v1.19-MILESTONE-AUDIT.md))
- ✅ **v1.18 Admin Console & Adoption Lab** — Phases 86–93 (shipped 2026-06-20 after HUMAN-UAT sign-off; 19/19 reqs + 8/8 phases; charter 2026-06-10; hex 0.3.0; [archive](milestones/v1.18-ROADMAP.md), [requirements](milestones/v1.18-REQUIREMENTS.md), [audit](milestones/v1.18-MILESTONE-AUDIT.md))
- ✅ **b1.0 Brand Foundations** — Phases 81–85 (brand track, non-feature; shipped 2026-06-10, [archive](milestones/b1.0-ROADMAP.md), [audit](milestones/b1.0-MILESTONE-AUDIT.md))
- ✅ **v1.17 Adopter-Confidence Hygiene** — Phases 78–80 (shipped 2026-05-27, [archive](milestones/v1.17-ROADMAP.md), [audit](milestones/v1.17-MILESTONE-AUDIT.md))
- ✅ **v1.16 CI Enforcement & Planning Hygiene** — Phases 75–77 (shipped 2026-05-27, [archive](milestones/v1.16-ROADMAP.md))
- ✅ **v1.15 Maintenance & Proof Honesty** — Phases 71–74 (shipped 2026-05-27, [audit](milestones/v1.15-MILESTONE-AUDIT.md))
- ✅ **v1.14 Bulk Owner-Erasure Orchestration** — Phases 67–70 (shipped 2026-05-27, [archive](milestones/v1.14-ROADMAP.md))
- ✅ **v1.13 Cancel Direct Upload** — Phases 64–66 (shipped 2026-05-27, [archive](milestones/v1.13-ROADMAP.md))
- ✅ **v1.12 Adopter Truth & Maintenance Hygiene** — Phases 60–63 (shipped 2026-05-27, [archive](milestones/v1.12-ROADMAP.md))
- ✅ **v1.11 Tus Protocol Completion** — Phases 56–59 (shipped 2026-05-27, [archive](milestones/v1.11-ROADMAP.md))
- ✅ **v1.10 Owner Account Erasure** — Phases 53–55 (shipped 2026-05-26, [archive](milestones/v1.10-ROADMAP.md))
- ✅ **v1.9 Phoenix Tus DX Completion** — Phases 48–52 (shipped 2026-05-25, [archive](milestones/v1.9-ROADMAP.md))
- ✅ **v1.8 Resumable Browser Ingest** — Phases 42–47 (shipped 2026-05-25, [archive](milestones/v1.8-ROADMAP.md))
- ✅ **v1.7 GCS Resumable Adapter** — Phases 37–41 (shipped 2026-05-08, [archive](milestones/v1.7-ROADMAP.md))
- ✅ **v1.6 Provider Boundary + Mux** — Phases 33–36 (shipped 2026-05-07, [archive](milestones/v1.6-ROADMAP.md))
- ✅ **v1.5 Adopter Hardening & Lifecycle Repair** — Phases 29–32 (shipped 2026-05-06, [archive](milestones/v1.5-ROADMAP.md))
- ✅ **v1.4 Video & Audio Wedge** — Phases 23–28 (shipped 2026-05-05, [archive](milestones/v1.4-ROADMAP.md))
- ✅ **v1.3 Live Publish & API Ergonomics** — Phases 15–22 (shipped 2026-05-02, [archive](milestones/v1.3-ROADMAP.md))
- ✅ **v1.2 First Hex Publish** — Phases 10–14 (shipped 2026-04-29, [archive](milestones/v1.2-ROADMAP.md))
- ✅ **v1.1 Adopter Hardening** — Phases 6–9 (shipped 2026-04-28, [archive](milestones/v1.1-ROADMAP.md))
- ✅ **v1.0 MVP** — Phases 1–5 (shipped 2026-04-xx, [archive](milestones/v1.0-ROADMAP.md))

## Phases

### v1.23 Postgres Schema Isolation (0.4.0)

- [x] **Phase 117: Prefix Routing Architecture** - Prove and deliver one explicit schema-routing model for all normal Rindle data paths. (completed 2026-08-08)
- [x] **Phase 118: Isolated Migration & Safe Upgrade** - Provision `rindle` by default and give populated public installs a bounded move path. (completed 2026-08-09)
- [x] **Phase 119: Ownership Boundaries & Diagnostics** - Keep Rindle and Oban schemas independent and make prefix faults actionable. (completed 2026-08-09)
- [ ] **Phase 120: Adoption Proof & Release Truth** - Prove the 0.4.0 contract in generated apps, Cohort, documentation, and release artifacts.

## Phase Details

### Phase 117: Prefix Routing Architecture

**Goal**: Adopters can rely on one explicit, proven Rindle schema-routing model: `rindle` by default or an intentional `public` compatibility configuration, with no normal data path silently falling back.
**Depends on**: Phase 116
**Requirements**: PREFIX-01, PREFIX-02, PREFIX-03
**Success Criteria** (what must be TRUE):

  1. A fresh configured application can use Rindle without manually adding query prefixes, and its normal Rindle reads and writes resolve to `rindle`.
  2. An adopter can select the documented `public` compatibility configuration and receive the same normal Rindle behavior against `public`.
  3. Facade operations, background work, Ecto.Multi callbacks, and both loaded and newly created Rindle structs consistently use the selected prefix, including when decoy public tables exist.
  4. The project has one tested architectural decision—compile-time schema macro or runtime routing helper—with its configuration/release implications explicit; mixed routing semantics are not exposed to adopters.

**Plans**: TBD

### Phase 118: Isolated Migration & Safe Upgrade

**Goal**: Adopters can create a fresh isolated install or move a populated legacy install to `rindle` without losing Rindle data or taking ownership of host infrastructure.
**Depends on**: Phase 117
**Requirements**: MIGRATE-01, MIGRATE-02, MIGRATE-03
**Success Criteria** (what must be TRUE):

  1. A fresh host migration provisions the selected schema, all six Rindle tables, and Rindle's marker state idempotently.
  2. An adopter can run a host-owned public-to-`rindle` upgrade that moves exactly the six Rindle tables and `rindle_migration_versions` while preserving rows, indexes, and relationships.
  3. Mixed, incomplete, or insufficient-permission database states stop before an unsafe move and provide bounded corrective guidance.
  4. Upgrade instructions state the required maintenance window and the limited, host-controlled rollback path truthfully.

**Plans**: 4 plans

Plans:
**Wave 1**

- [x] 118-01-PLAN.md — Trace fresh `rindle` provisioning and explicit `public` compatibility.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 118-02-PLAN.md — Preflight and move the populated fixed seven-relation set.

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 118-03-PLAN.md — Prove refusal/rollback/lock safety and add the guarded reverse.

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 118-04-PLAN.md — Publish and lock maintenance-window upgrade guidance.

### Phase 119: Ownership Boundaries & Diagnostics

**Goal**: Operators can distinguish Rindle's configured schema from independently configured host Oban infrastructure and resolve prefix problems without raw database failures.
**Depends on**: Phase 118
**Requirements**: BOUNDARY-01, BOUNDARY-02, OPS-01
**Success Criteria** (what must be TRUE):

  1. Rindle never creates, moves, drops, or prefixes `oban_jobs` or the host `schema_migrations` ledger; Oban keeps its independently configured (normally `public`) prefix.
  2. Rindle catalog checks, raw SQL, and Oban-binding queries resolve the correct respective schema using validated, safely quoted or bound identifiers.
  3. `mix rindle.doctor` reports expected Rindle and Oban prefixes separately and identifies an installation or migration-prefix mismatch with actionable guidance.
  4. `mix rindle.runtime_status` detects missing or mismatched Rindle/Oban state before report queries and returns a bounded setup failure rather than a raw database exception.

**Plans**: TBD

### Phase 120: Adoption Proof & Release Truth

**Goal**: Adopters and maintainers can verify the breaking 0.4.0 schema contract end-to-end from packaged installation through upgrade, demo operation, and documentation.
**Depends on**: Phase 119
**Requirements**: PROOF-01, PROOF-02, DOCS-01
**Success Criteria** (what must be TRUE):

  1. Automated proof covers fresh `rindle` installs, explicit `public` compatibility, populated public-to-`rindle` upgrades, runtime routing, and the untouched public Oban boundary.
  2. A packed-artifact generated Phoenix application and the Cohort adoption demo provision and run with Rindle in `rindle` and Oban in `public`.
  3. README, getting-started, migration API docs, upgrading guide, docs-parity tests, and 0.4.0 release notes agree on the breaking default, escape hatch, order of operations, permissions, downtime, and Oban ownership.
  4. Release verification demonstrates that packaged artifacts—not only the repository checkout—honor the documented isolation contract.

**Plans**: 9 plans

Plans:
- [x] 120-01-PLAN.md — packed default install, schema ownership, boot, and persistence proof
- [x] 120-02-PLAN.md — explicit-public compatibility and populated public-to-rindle upgrade proof
- [x] 120-03-PLAN.md — Cohort host-owned migration and cold-start proof
- [x] 120-04-PLAN.md — fresh-install documentation and migration API parity
- [x] 120-05-PLAN.md — populated-upgrade and troubleshooting operational truth
- [x] 120-06-PLAN.md — 0.4.0 release notes and exact-SHA signoff contract
- [ ] 120-07-PLAN.md — exact marker, FK, index, and Oban catalog proof
- [ ] 120-08-PLAN.md — explicit-public down-prefix and both-direction docs parity
- [ ] 120-09-PLAN.md — packed public/upgrade, Cohort, and immutable exact-SHA evidence

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 117. Prefix Routing Architecture | 5/5 | Complete    | 2026-08-08 |
| 118. Isolated Migration & Safe Upgrade | 6/6 | Complete    | 2026-08-09 |
| 119. Ownership Boundaries & Diagnostics | 5/5 | Complete    | 2026-08-09 |
| 120. Adoption Proof & Release Truth | 1/6 | In Progress | - |

## Phases (shipped — collapsed history)

<details>
<summary>✅ v1.22 OSS Quality & Trust Hardening (Phases 113–116) — SHIPPED 2026-07-02</summary>

Non-feature/DX hardening milestone from SEED-005. Delivered the concise OSS-quality weakness summary,
cut and reconciled the stuck Hex 0.3.2 release, added OSS governance and Hex metadata trust signals,
locked pre-1.0 versioning and README positioning, and shipped the non-breaking versioned
`Rindle.Migration` substrate with host-owned `oban_jobs`. 14/14 requirements, 4/4 phases, 14 plans,
audit passed.

- [x] Phase 113: Evaluation Baseline & Release Hygiene (4/4 plans) — completed 2026-06-30
- [x] Phase 114: OSS Trust & Governance (2/2 plans) — completed 2026-07-01
- [x] Phase 115: Versioning & README Positioning (1/1 plan) — completed 2026-07-01
- [x] Phase 116: Versioned `Rindle.Migration` Module (7/7 plans) — completed 2026-07-01

Archive: [milestones/v1.22-ROADMAP.md](milestones/v1.22-ROADMAP.md); requirements: [milestones/v1.22-REQUIREMENTS.md](milestones/v1.22-REQUIREMENTS.md); audit: [milestones/v1.22-MILESTONE-AUDIT.md](milestones/v1.22-MILESTONE-AUDIT.md).

</details>

<details>
<summary>✅ v1.21 CI/DX Reliability Tail (Phases 108–112) — SHIPPED 2026-06-29</summary>

Non-feature/DX milestone making the merge gate deterministic and trustworthy — a green PR reliably
means a green `main`. Chartered from SEED-004 + the 2026-06-26 flake cluster. Load-bearing order
delivered intact (de-flake 108→109→110 → lock 111 → shift-left 112 LAST). Ships Hex **0.3.2** via two
adopter-invisible `lib/` `fix:` patches (D-v1.21-01: `av/subprocess.ex` EPIPE; `config.ex` ISO). All
hard release-coupling invariants preserved: `ci.yml` filename + `name: CI` byte-unchanged; `CI Summary`
treats `skipped` as pass and stays the sole required check.

> Release note: the v1.21 `lib/` fixes are now live as Hex **0.3.2** after v1.22 Phase 113
> (HYGIENE-01) unstuck release-please and reconciled the release-train claim.

- [x] Phase 108: Coverage single-run (1/1 plan) — completed 2026-06-28
- [x] Phase 109: Subprocess `:epipe` hardening (2/2 plans) — completed 2026-06-28
- [x] Phase 110: Async-isolation hardening (4/4 plans) — completed 2026-06-28
- [x] Phase 111: Regression locks (4/4 plans) — completed 2026-06-28
- [x] Phase 112: PR↔main gate shift-left (2/2 plans) — completed 2026-06-29

Archive: [milestones/v1.21-ROADMAP.md](milestones/v1.21-ROADMAP.md); requirements: [milestones/v1.21-REQUIREMENTS.md](milestones/v1.21-REQUIREMENTS.md); audit: [milestones/v1.21-MILESTONE-AUDIT.md](milestones/v1.21-MILESTONE-AUDIT.md).

</details>

<details>
<summary>✅ v1.20 CI/CD Performance (Phases 103–107) — SHIPPED 2026-06-22</summary>

Non-feature / DX-infrastructure milestone — **ZERO `lib/` public-API change**. Chartered from
SEED-003; load-bearing dependency order delivered intact (observability → cache/tooling →
aggregate required check → lane split → reliability/security/DX). All three hard release-coupling
invariants preserved: `ci.yml` filename + `name: CI` byte-unchanged; `CI Summary` treats `skipped`
as pass; the release full-verification gate never weakened.

- [x] Phase 103: Observability / Baseline (4/4 plans) — completed 2026-06-20
- [x] Phase 104: Cache & Tooling Hygiene (4/4 plans) — completed 2026-06-21
- [x] Phase 105: Aggregate Required Check + Branch-Protection Flip (1/1 plan) — completed 2026-06-21
- [x] Phase 106: Trigger Split + Matrix/Lane Refinement (4/4 plans) — completed 2026-06-22
- [x] Phase 107: Reliability, Security & DX Hardening (4/4 plans) — completed 2026-06-22

Archive: [milestones/v1.20-ROADMAP.md](milestones/v1.20-ROADMAP.md); audit: [milestones/v1.20-MILESTONE-AUDIT.md](milestones/v1.20-MILESTONE-AUDIT.md).

</details>

<details>
<summary>✅ v1.19 Design-System Stress-Test (Phases 94-102) — SHIPPED 2026-06-19</summary>

- [x] Phase 94: Foundation — Token Pipeline CI Gate & New Token Categories (5/5 plans) — completed 2026-06-15
- [x] Phase 95: Admin Level-1 Component Audit (5/5 plans) — completed 2026-06-16
- [x] Phase 96: Cohort Component Layer + Dark / Reduced-Motion Contract (5/5 plans) — completed 2026-06-17
- [x] Phase 97: Admin Level-2 Meta-Components (4/4 plans) — completed 2026-06-17
- [x] Phase 98: Admin Level-3 Page Composition + Motion / Mobile / A11y / IA / Microcopy (5/5 plans) — completed 2026-06-18
- [x] Phase 99: Cohort Page Migrations (5/5 plans) — completed 2026-06-18
- [x] Phase 100: Cohort /upload Migration (2/2 plans) — completed 2026-06-18
- [x] Phase 101: daisyUI Retirement (4/4 plans) — completed 2026-06-18
- [x] Phase 102: Re-Converge — Visual Matrix, Idempotency Gate & Milestone Audit (6/6 plans) — completed 2026-06-19

Archive: [milestones/v1.19-ROADMAP.md](milestones/v1.19-ROADMAP.md); audit: [milestones/v1.19-MILESTONE-AUDIT.md](milestones/v1.19-MILESTONE-AUDIT.md).

</details>

<details>
<summary>✅ v1.18 Admin Console & Adoption Lab (Phases 86–93) — SHIPPED 2026-06-20 · full detail in <a href="milestones/v1.18-ROADMAP.md">archive</a></summary>

Mountable token-generated admin console (ADMIN-01..06, DS-01..03), Cohort adoption-lab demo with full
media-type + lifecycle-state coverage (DEMO-01..03), deterministic console E2E + screenshot polish loop
(E2E-01..02), port-conflict-free Docker DX (DX-01..03), durable UI-principles doc (PRIN-01), and
scope-reversal docs parity (TRUTH-07). 19/19 reqs across 8 phases. Full phase details + per-plan
breakdown in the archive.

- [x] Phase 86: Research & Architecture Lock — completed 2026-06-11
- [x] Phase 87: Docker & Demo DX — completed 2026-06-11
- [x] Phase 88: Admin Design System & UI Kit — completed 2026-06-11
- [x] Phase 89: Console Read Surfaces — completed 2026-06-12
- [x] Phase 90: Console Ops Actions — completed 2026-06-13 (HUMAN-UAT signed off 2026-06-20)
- [x] Phase 91: Cohort Demo Evolution — completed 2026-06-12
- [x] Phase 92: E2E & Screenshot-Driven Polish Loop — completed 2026-06-13 (HUMAN-UAT signed off 2026-06-20)
- [x] Phase 93: Truth, Docs & Milestone Audit — completed 2026-06-13

Audit: [.planning/milestones/v1.18-MILESTONE-AUDIT.md](milestones/v1.18-MILESTONE-AUDIT.md) — status `shipped`.

</details>

<details>
<summary>✅ b1.0 Brand Foundations (Phases 81–85) — SHIPPED 2026-06-10</summary>

- [x] Phase 81: Brand Audit & Direction Lock (2/2 plans) — completed 2026-06-10
- [x] Phase 82: Logo Candidates & User Selection (2/2 plans) — completed 2026-06-10 (user pick: E Confluence, e1)
- [x] Phase 83: Logo System Refinement (2/2 plans) — completed 2026-06-10
- [x] Phase 84: Design Tokens & HTML Brand Book (3/3 plans) — completed 2026-06-10
- [x] Phase 85: Repo Surface Integration (2/2 plans) — completed 2026-06-10

Full phase details: [.planning/milestones/b1.0-ROADMAP.md](milestones/b1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v1.17 Adopter-Confidence Hygiene (Phases 78–80) — SHIPPED 2026-05-27</summary>

- [x] Phase 78: Assessment & Planning Truth (2/2 plans) — completed 2026-05-27
- [x] Phase 79: CI Static-Analysis Policy Closure (2/2 plans) — completed 2026-05-27
- [x] Phase 80: Post-Ship Planning Hygiene (2/2 plans) — completed 2026-05-27

Full phase details: [.planning/milestones/v1.17-ROADMAP.md](milestones/v1.17-ROADMAP.md)

</details>

<details>
<summary>✅ v1.16 CI Enforcement & Planning Hygiene (Phases 75–77) — SHIPPED 2026-05-27</summary>

- [x] Phase 77: Planning Artifact Cleanup (3/3 plans) — completed 2026-05-27
- [x] Phase 76: TusPlug Doc Parity Lock (2/2 plans) — completed 2026-05-27
- [x] Phase 75: Merge-Blocking Proof Lanes (5/5 plans) — completed 2026-05-27

Full phase details: [.planning/milestones/v1.16-ROADMAP.md](milestones/v1.16-ROADMAP.md)

</details>

<details>
<summary>✅ v1.15 Maintenance & Proof Honesty (Phases 71–74) — SHIPPED 2026-05-27</summary>

- [x] Phase 71: CI Proof Honesty (2/2 plans) — completed 2026-05-27
- [x] Phase 72: Mix Batch Failure Proof (1/1 plan) — completed 2026-05-27
- [x] Phase 73: Nyquist Validation Closure (4/4 plans) — completed 2026-05-27
- [x] Phase 74: Support Truth & Milestone Audit (2/2 plans) — completed 2026-05-27

Audit: [.planning/milestones/v1.15-MILESTONE-AUDIT.md](milestones/v1.15-MILESTONE-AUDIT.md)

</details>

## Demand-Gated Pause — Next Candidate: v1.23 Schema Isolation

**Formalized:** 2026-05-27 | **Status:** v1.22 shipped the non-feature OSS-quality/trust half of the
SEED-005 software-quality arc. v1.23 Postgres Schema Isolation remains the named non-feature/breaking
candidate and should be re-chartered with fresh requirements before phases are added. Feature work still
requires:

- **LIFE-06** — compliance/legal ticket for force-delete shared assets, or
- **STREAM-10** — named adopter for second streaming provider

See [post-v116 assessment](threads/2026-05-27-post-v116-milestone-assessment.md).

## Deferred to v1.23+ / Later

- **v1.23 Postgres Schema Isolation** (breaking → 0.4.0): `rindle` schema default via config-driven
  `@schema_prefix`; 4 manual escapes; `prefix: "public"` opt-out + `ALTER TABLE … SET SCHEMA` move
  migration. Re-charter from the ISO23 notes in the v1.22 requirements archive; builds on v1.22's
  `Rindle.Migration` substrate.

- Force-delete semantics for still-shared assets (LIFE-06) — compliance pull only
- Second streaming provider (Cloudflare/Bunny) — explicit adopter demand only
- IETF RUFH / tus 2.0; GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package; richer reusable uploader component abstractions
- Signed dynamic image transforms / EXIF privacy stripping
- `mix test --partitions` parallelization — evidence-gated on a measured core-starvation showing (DEFER-02)

## Archive

- [.planning/milestones/v1.22-ROADMAP.md](milestones/v1.22-ROADMAP.md)
- [.planning/milestones/v1.22-REQUIREMENTS.md](milestones/v1.22-REQUIREMENTS.md)
- [.planning/milestones/v1.22-MILESTONE-AUDIT.md](milestones/v1.22-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.21-ROADMAP.md](milestones/v1.21-ROADMAP.md)
- [.planning/milestones/v1.21-REQUIREMENTS.md](milestones/v1.21-REQUIREMENTS.md)
- [.planning/milestones/v1.21-MILESTONE-AUDIT.md](milestones/v1.21-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.20-ROADMAP.md](milestones/v1.20-ROADMAP.md)
- [.planning/milestones/v1.20-REQUIREMENTS.md](milestones/v1.20-REQUIREMENTS.md)
- [.planning/milestones/v1.20-MILESTONE-AUDIT.md](milestones/v1.20-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.19-ROADMAP.md](milestones/v1.19-ROADMAP.md)
- [.planning/milestones/v1.19-MILESTONE-AUDIT.md](milestones/v1.19-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.18-ROADMAP.md](milestones/v1.18-ROADMAP.md)
- [.planning/milestones/v1.18-REQUIREMENTS.md](milestones/v1.18-REQUIREMENTS.md)
- [.planning/milestones/v1.18-MILESTONE-AUDIT.md](milestones/v1.18-MILESTONE-AUDIT.md)
- [.planning/milestones/b1.0-ROADMAP.md](milestones/b1.0-ROADMAP.md)
- [.planning/milestones/b1.0-REQUIREMENTS.md](milestones/b1.0-REQUIREMENTS.md)
- [.planning/milestones/b1.0-MILESTONE-AUDIT.md](milestones/b1.0-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.17-ROADMAP.md](milestones/v1.17-ROADMAP.md)
- [.planning/milestones/v1.17-REQUIREMENTS.md](milestones/v1.17-REQUIREMENTS.md)
- [.planning/milestones/v1.17-MILESTONE-AUDIT.md](milestones/v1.17-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.16-ROADMAP.md](milestones/v1.16-ROADMAP.md)
- [.planning/milestones/v1.16-REQUIREMENTS.md](milestones/v1.16-REQUIREMENTS.md)
- [.planning/milestones/v1.15-MILESTONE-AUDIT.md](milestones/v1.15-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.14-ROADMAP.md](milestones/v1.14-ROADMAP.md)
- [.planning/milestones/v1.14-REQUIREMENTS.md](milestones/v1.14-REQUIREMENTS.md)
- [.planning/milestones/v1.14-MILESTONE-AUDIT.md](milestones/v1.14-MILESTONE-AUDIT.md)

## Backlog

_(empty — no open backlog items)_

---
*Last updated: 2026-07-02 — shipped and archived **v1.22 OSS Quality & Trust Hardening** (Phases 113–116, 14/14 requirements, audit passed). No active milestone; v1.23 Postgres Schema Isolation remains the named candidate and needs fresh requirements before phases are added.*
