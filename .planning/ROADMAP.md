# Roadmap: Rindle

## Milestones

- 🔵 **v1.22 OSS Quality & Trust Hardening** — Phases 113–116 (active, chartered 2026-06-29 from SEED-005; non-feature/DX, ships a 0.3.x minor; 14 reqs EVAL/TRUST/META/VERSION/README/MIGRATE/HYGIENE; [requirements](REQUIREMENTS.md))
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

v1.22 OSS Quality & Trust Hardening (active). Phases continue from v1.21's Phase 112.

This is a low-risk, mostly-independent hardening milestone. Most requirements do not hard-depend on
each other; the phases group naturally rather than impose a deep dependency chain. Two ordering notes:
the time-sensitive release unstick (HYGIENE-01) lands EARLY in Phase 113 to reach adopters; the
versioned `Rindle.Migration` substrate (the only real code change, the v1.23 foundation) lands LAST in
Phase 116 so its new install/upgrade docs converge coherently with the README/VERSION doc work in 115.

- [ ] **Phase 113: Evaluation Baseline & Release Hygiene** - Opening scored-weakness summary, cut the stuck Hex 0.3.2 release to reach adopters, and reconcile planning truth
- [ ] **Phase 114: OSS Trust & Governance** - SECURITY.md / CODE_OF_CONDUCT.md / issue+PR templates plus Hex `package` links + maintainers
- [ ] **Phase 115: Versioning & README Positioning** - SemVer/pre-1.0 stability contract, generalized upgrade guide, image-first skimmable README + "when not to use"
- [ ] **Phase 116: Versioned `Rindle.Migration` Module** - Oban-style versioned `up/1`+`down/1` install path; adopter owns `oban_jobs`; non-breaking, defaults to `public`

## Phase Details

### Phase 113: Evaluation Baseline & Release Hygiene

**Goal**: Open the milestone with an evidence-cited scored-weakness summary, unstick the
merged-but-unreleased v1.21 adopter fixes by cutting the 0.3.2 release, and reconcile the planning
truth those gaps created.

**Depends on**: Nothing (first phase of v1.22; continues from shipped Phase 112)

**Requirements**: EVAL-01, HYGIENE-01, HYGIENE-02

**Success Criteria** (what must be TRUE):
  1. A maintainer can read a concise, right-sized, evidence-cited scored-weakness summary of Rindle's
     OSS quality (the milestone's opening artifact) naming the weak dimensions (governance/trust,
     versioning/positioning, host-app respectfulness) vs. the already-strong ones — not the full
     36-dimension report.
  2. Hex 0.3.2 is published so the merged-but-unreleased v1.21 `lib/` fixes (`:epipe` absorb,
     `$callers` config override) reach adopters; `mix.exs`, `.release-please-manifest.json`, and
     CHANGELOG all reflect the released version and the root cause (why release-please did not open a
     0.3.2 PR) is investigated and recorded.
  3. PROJECT.md / MILESTONES reconcile the prior aspirational "ships as Hex 0.3.2" claim with reality
     (released vs. previously unshipped).
  4. SEED-003 and SEED-004 frontmatter `status:` is corrected from stale `open` to `consumed` (they
     shipped as v1.20 / v1.21).

**Plans**: TBD

### Phase 114: OSS Trust & Governance

**Goal**: Close the OSS governance/trust gap so a newcomer or security researcher lands on a project
that signals it is maintained, safe to report to, and welcoming to contribute to — and so hex.pm
surfaces the conventional package links and maintainers.

**Depends on**: Phase 113 (uses the EVAL-01 scored-weakness summary as the prioritized work list)

**Requirements**: TRUST-01, TRUST-02, TRUST-03, META-01, META-02

**Success Criteria** (what must be TRUE):
  1. The repo has a `SECURITY.md` with a vulnerability-disclosure policy appropriate for a library
     handling untrusted uploads, MIME sniffing, signed delivery, and webhook HMAC verification.
  2. The repo has a `CODE_OF_CONDUCT.md`.
  3. A newcomer opening an issue or PR is guided by `.github/ISSUE_TEMPLATE/` templates (bug report /
     feature proposal) and a `PULL_REQUEST_TEMPLATE.md` (the existing CONTRIBUTING is CI-only — these
     add the on-ramp).
  4. hex.pm surfaces "Changelog" and "Docs" links (HexDocs convention) alongside the existing GitHub
     link via `package.links`.
  5. The Hex `package` declares `maintainers`.

**Plans**: TBD

### Phase 115: Versioning & README Positioning

**Goal**: Set adopter expectations correctly — state the pre-1.0 stability contract and give every
future change a documented upgrade home — and make the README skimmable with an image-first first-run
and an honest "when not to use it" boundary.

**Depends on**: Phase 113 (EVAL-01 names the positioning/versioning weaknesses this phase closes)

**Requirements**: VERSION-01, VERSION-02, README-01, README-02

**Success Criteria** (what must be TRUE):
  1. README and CONTRIBUTING state the SemVer / pre-1.0 stability contract ("0.x: API may change
     between minor versions; see CHANGELOG") plus a short note on what 1.0 will mean.
  2. `guides/upgrading.md` is a reusable, versioned upgrade-notes structure — not just the single
     pre-0.1.4 image-only→AV case — so every future change has a documented home.
  3. The README leads with an image-only "first attachment in ~2 minutes" path that needs no
     FFmpeg/libvips; the heavier AV quickstart is demoted below it.
  4. The README has a clear "what Rindle is NOT / when not to use it" block (lifted from
     `guides/user_flows.md`).

**Plans**: TBD
**UI hint**: yes

### Phase 116: Versioned `Rindle.Migration` Module

**Goal**: Replace the raw 15-file `Ecto.Migrator` copy-paste install path with a versioned,
idempotent, Oban-style `Rindle.Migration` module and stop creating the shared `oban_jobs` table on the
adopter's behalf — non-breaking, and the load-bearing foundation v1.23 builds the schema prefix onto.

**Depends on**: Phase 115 (its new install/upgrade docs converge with the README/VERSION/`upgrading.md`
work landed in 115)

**Requirements**: MIGRATE-01, MIGRATE-02

**Success Criteria** (what must be TRUE):
  1. Adopters install Rindle's tables via a versioned, idempotent `Rindle.Migration.up/1` + `down/1`
     module (Oban-style) instead of the raw 15-file copy-paste path; README, getting-started, and
     `upgrading.md` show the new ~3-line migration. Non-breaking — the default schema stays `public`
     and existing adopters' already-applied migrations remain valid.
  2. Rindle no longer creates the shared `oban_jobs` table; the adopter owns `Oban.Migration`,
     documented in the install/upgrade guides (removes the latent host-Oban collision).
  3. The existing test suite stays green (135 test files; the async-safety meta-test still governs
     `async: true`), and doctor / runtime_status migration-inspection logic keeps working alongside
     legacy 15-file installs.
  4. Hard release-coupling invariants are preserved: `ci.yml` / `name: CI` unchanged, `CI Summary`
     keeps `skipped`==pass, and the release full-verification gate is not weakened.

**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 113. Evaluation Baseline & Release Hygiene | 0/? | Not started | - |
| 114. OSS Trust & Governance | 0/? | Not started | - |
| 115. Versioning & README Positioning | 0/? | Not started | - |
| 116. Versioned `Rindle.Migration` Module | 0/? | Not started | - |

## Phases (shipped — collapsed history)

<details>
<summary>✅ v1.21 CI/DX Reliability Tail (Phases 108–112) — SHIPPED 2026-06-29</summary>

Non-feature/DX milestone making the merge gate deterministic and trustworthy — a green PR reliably
means a green `main`. Chartered from SEED-004 + the 2026-06-26 flake cluster. Load-bearing order
delivered intact (de-flake 108→109→110 → lock 111 → shift-left 112 LAST). Ships Hex **0.3.2** via two
adopter-invisible `lib/` `fix:` patches (D-v1.21-01: `av/subprocess.ex` EPIPE; `config.ex` ISO). All
hard release-coupling invariants preserved: `ci.yml` filename + `name: CI` byte-unchanged; `CI Summary`
treats `skipped` as pass and stays the sole required check.

> Note: the v1.21 `lib/` fixes are merged but **0.3.2 was never published** (Hex live = 0.3.1). v1.22
> Phase 113 (HYGIENE-01) cuts the stuck release and reconciles the claim.

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

## Demand-Gated Pause — Non-feature arc in progress (v1.22/v1.23)

**Formalized:** 2026-05-27 | **Status:** The demand gates remain intact for the next *feature*
milestone, but the current v1.22→v1.23 software-quality consolidation arc (SEED-005) is non-feature/DX,
so `block_feature_milestone_without_signal` does not apply. Feature work still requires:

- **LIFE-06** — compliance/legal ticket for force-delete shared assets, or
- **STREAM-10** — named adopter for second streaming provider

See [post-v116 assessment](threads/2026-05-27-post-v116-milestone-assessment.md).

## Deferred to v1.23+ / Later

- **v1.23 Postgres Schema Isolation** (breaking → 0.4.0): `rindle` schema default via config-driven
  `@schema_prefix`; 4 manual escapes; `prefix: "public"` opt-out + `ALTER TABLE … SET SCHEMA` move
  migration (ISO23-01..04 in REQUIREMENTS.md). Builds on v1.22's `Rindle.Migration` substrate.
- Force-delete semantics for still-shared assets (LIFE-06) — compliance pull only
- Second streaming provider (Cloudflare/Bunny) — explicit adopter demand only
- IETF RUFH / tus 2.0; GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package; richer reusable uploader component abstractions
- Signed dynamic image transforms / EXIF privacy stripping
- `mix test --partitions` parallelization — evidence-gated on a measured core-starvation showing (DEFER-02)

## Archive

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
*Last updated: 2026-06-29 — chartered **v1.22 OSS Quality & Trust Hardening** (Phases 113–116, 14/14 requirements mapped: EVAL+HYGIENE→113, TRUST+META→114, VERSION+README→115, MIGRATE→116). Non-feature/DX arc from SEED-005; ships a 0.3.x minor (0.4.0 reserved for v1.23's breaking schema isolation). Time-sensitive release unstick (HYGIENE-01) lands early in 113; the versioned `Rindle.Migration` substrate (the only real code change, the v1.23 foundation) lands last in 116 so its install/upgrade docs converge with the 115 README/VERSION work. v1.21 CI/DX Reliability Tail shipped & archived (Phases 108–112, 24/24); v1.21 `lib/` fixes merged but 0.3.2 unpublished — Phase 113 cuts it.*
