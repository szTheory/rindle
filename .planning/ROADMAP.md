# Roadmap: Rindle

## Milestones

- 🚧 **v1.20 CI/CD Performance** — Phases 103–107 (active, chartered 2026-06-20 from SEED-003; non-feature / DX-infra, ZERO `lib/` public-API change; 18 reqs)
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

### 🚧 v1.20 CI/CD Performance (Phases 103–107) — ACTIVE

**Milestone goal:** Cut PR CI feedback time and harden gate determinism/reliability — without
dropping real quality signal — via a measure → classify → restructure pass shipped as stepwise PRs.
Non-feature / DX-infrastructure milestone: **ZERO `lib/` public-API change**. Chartered from
SEED-003; the dependency order below is **load-bearing** (research-unanimous):
observability → cache/tooling → aggregate required check → lane split → reliability/security/DX.

**Hard invariants (carry into every phase):** never rename `ci.yml`'s file or `name: CI`
(release-train coupling via `release-please-automerge.yml` + `gate-ci-green`); the `CI Summary`
aggregate must treat `skipped` as pass (fork-PR safety); never weaken the release full-verification gate.

- [ ] **Phase 103: Observability / Baseline** — surface CI timing/cache/slowest-tests; capture the committed baseline + live required-check names before any change (no behavior change).
- [ ] **Phase 104: Cache & Tooling Hygiene** — composite setup action, correct cache keys, PLT restore/save split, lockfile drift gates, lint de-dup (single-workflow shape; low-risk).
- [ ] **Phase 105: Aggregate Required Check + Branch-Protection Flip** — land `CI Summary` and make it the sole required check, in one isolated PR, before any lane rename.
- [ ] **Phase 106: Trigger Split + Matrix/Lane Refinement** — fast PR lane + scoped package-consumer + nightly lane + concurrency groups (the headline 15→≤7min cut).
- [ ] **Phase 107: Reliability, Security & DX Hardening** — async-safety guard/partitioning, action pinning + supply-chain, `mix ci` + CONTRIBUTING, faithful Linux-Chromium repro.

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

### v1.18 Admin Console & Adoption Lab (Phases 86–93)

**Charter (2026-06-10):** Maintainer-pull feature milestone — explicit, recorded override
of the PAUSE-03 v1.18+ reservation (LIFE-06/STREAM-10 stay demand-gated, now v1.19+).
Reverses the JTBD T4 "admin UI out of scope" exclusion as a deliberate scope change.
Ships as hex **0.3.0** (brand work releases separately as 0.2.0 first).

**Locked decisions:** D-v1.18-01 console ships in the `rindle` package, mountable
Oban-Web/LiveDashboard-style with self-contained assets; D-v1.18-02 hex 0.3.0 after the
0.2.0 brand release; D-v1.18-03 Cohort stays the demo domain, extended (audio + documents

+ full state-space seeds) — no E2E churn for its own sake.

Each phase runs full GSD: discuss → research → plan → execute → verify, with a
maintainer go/no-go gate between phases.

- [x] **Phase 86: Research & Architecture Lock** — parallel subagent research → locked ADRs: (completed 2026-06-11)
  LiveDashboard/Oban Web packaging (router macro, asset serving, CSP, CSS isolation,
  optional-dep matrix); gov.uk/GDS information architecture → persona/JTBD-driven console
  IA map; emilkowal.ski animation principles → restrained motion spec tied to brand
  `motion` tokens; Docker multi-project DX (COMPOSE_PROJECT_NAME / env ports / traefik
  tradeoffs); CSS architecture lock (BEM + custom properties generated from
  `brandbook/tokens/tokens.json` for the console; Cohort keeps Tailwind/daisyUI momentum).
  Output includes the UI-principles doc linked from `AGENTS.md` (PRIN-01).

- [x] **Phase 87: Docker & Demo DX** (early — every later UI phase iterates faster) — (completed 2026-06-11)
  project namespacing, env-driven ports + conflict guidance, layer-cache fix
  (deps before source COPY), dev style-change path without rebuilds, launch URL map,
  reader-empathetic docs. (DX-01..03)

- [x] **Phase 88: Admin Design System & UI Kit** — token-generated `rindle-admin` CSS
  (BEM), light/dark/system theme picker, core components (nav shell, tables,
  lifecycle-state chips, buttons, confirm dialog, drawer, toasts, empty states,
  skeletons), component-gallery screenshot harness, WCAG contrast gate.
  **Checkpoint: maintainer reviewed rendered gallery; requested anchor-navigation fix is
  implemented and regression-covered.** (completed 2026-06-11; DS-01..03, ADMIN-02 groundwork)

- [x] **Phase 89: Console Read Surfaces** — router macro + host-auth `on_mount` + (completed 2026-06-12)
  asset-serving plug (safe by default); home, assets list/detail, upload sessions,
  variant/job activity, doctor + runtime status; pubsub live updates;
  `Rindle.Admin.Queries` isolation; optional-dep CI matrix. (ADMIN-01..03, 05, 06)

- [x] **Phase 90: Console Ops Actions** — erasure preview/execute + batch with (completed 2026-06-13; UAT complete 2026-06-14 — destructive-UX gate automated into merge-blocking CI)
  destructive-action UX (typed confirmation, collateral preview), variant regeneration,
  quarantine review, lifecycle repair. (ADMIN-04)

- [x] **Phase 91: Cohort Demo Evolution** — Cohort's own lightweight brand (completed 2026-06-12)
  (**rendered options checkpoint**), audio + document profiles, seeds expressing every
  lifecycle state, mounts the console, click-around walkthrough. (DEMO-01..03)

- [x] **Phase 92: E2E & Screenshot-Driven Polish Loop** — deterministic console Playwright (completed 2026-06-13; UAT complete 2026-06-14 — screenshot visual-polish review automated into the merge-blocking CI lane via `admin-polish.js`; 0 human UAT)
  specs (happy/error/boundary/theme/destructive) in a merge-blocking lane; all-screens ×
  light/dark capture → analyze → fix polish passes. (E2E-01..02)

- [x] **Phase 93: Truth, Docs & Milestone Audit** — `guides/admin_console.md`, (completed 2026-06-13)
  user_flows + JTBD-MAP updates (T4 reversal), facade moduledoc truth fix
  (`lib/rindle.ex` "no admin UI" line), README/HexDocs, traceability closure,
  MILESTONE-AUDIT. (TRUTH-07)

## Phase Details

### v1.20 CI/CD Performance (Phase Details) — Phases 103–107

---

### Phase 103: Observability / Baseline

**Goal:** Make the existing pipeline self-reporting and capture a committed baseline so every later
restructuring decision is evidence-backed — with **zero gate-behavior and zero topology change**.

**Depends on:** Nothing (first phase of v1.20; runs against the current 14-job `ci.yml` as-is).

**Requirements:** OBS-01, OBS-02, OBS-03

**Success criteria** (what must be TRUE):

1. A baseline table (per-job avg + p95 + rerun/flake rate) **and** the *actual* live
   branch-protection required-check names are captured and committed **before any restructuring
   change is made** (OBS-03).

2. A PR run summary (`$GITHUB_STEP_SUMMARY`) shows per-job and per-step timing plus cache hit/miss,
   with no change to which checks pass or fail (OBS-01).

3. The run summary surfaces `mix test --slowest 20`, a `mix compile` time profile,
   `System.schedulers_online()` (runner cores), and the ExUnit seed; JUnit + coverage artifacts are
   uploaded for inspection (OBS-02).

4. Gate behavior is provably unchanged: the same checks are required and the same PRs pass/fail as
   on the pre-phase baseline.

**Plans:** 4 (planned 2026-06-20)

**Wave 1** *(no deps, parallel — disjoint files):*

- 103-01 — OBS-02 test harness: test-only `junit_formatter` + ExUnit JUnit/coverage wiring (`mix.exs`, `test/test_helper.exs`).
- 103-02 — OBS-03 read-only collectors: baseline (avg/p95/rerun) + live-vs-expected required-check diff (`scripts/ci/*.sh`).

**Wave 2** *(blocked on Wave 1 — parallel, disjoint files):*

- 103-03 *(needs 103-01)* — OBS-01 + OBS-02 instrumentation in `ci.yml`: cache `id:`s/hit-miss, per-job + per-step timing via job-scoped `ci-observability` aggregator, slowest/compile/schedulers/seed, JUnit+coverage upload.
- 103-04 *(needs 103-02)* — OBS-03 capture: commit internal `103-BASELINE.md` + verbatim live required-check names (records `brandbook-tokens` drift) before any restructuring.

**Cross-cutting constraints** (asserted across multiple plans): never rename `ci.yml`/`name: CI` (D-13);
zero gate-behavior change — observability/aggregator job never added to required checks (D-14);
`actions: read` job-scoped only, never workflow-level (D-03); no composite action this phase (D-12).

**Research flag:** This phase must *produce* the missing data (runner vCPU/`schedulers_online`, real
p95/rerun, per-step `package-consumer` timing, slowest tests) and read live GitHub
branch-protection required-check names — these are unknowns, not patterns. Required before the
Phase 105 flip.

**Plans:** 4 plans

Plans:

**Wave 1** *(harness / Wave 0 — no deps; parallel)*

- [x] 103-01-PLAN.md — Add test-only `junit_formatter` + wire `test_helper.exs`; verify JUnit XML + coverage artifacts produced (OBS-02 foundation).
- [x] 103-02-PLAN.md — Create the two read-only `scripts/ci/` collectors (baseline avg/p95/rerun + live-vs-expected required-check diff) (OBS-03 tooling).

**Wave 2** *(blocked on Wave 1; parallel — disjoint files)*

- [ ] 103-03-PLAN.md — Instrument `ci.yml`: cache `id:`s + summary, OBS-02 evidence steps, JUnit/coverage upload, `ci-observability` aggregator (OBS-01, OBS-02). *(depends on 103-01)*
- [ ] 103-04-PLAN.md — Run the collectors and commit internal `103-BASELINE.md` (timing baseline + live required-check names + drift) before any restructuring (OBS-03). *(depends on 103-02)*

---

### Phase 104: Cache & Tooling Hygiene

**Goal:** Remove low-risk waste and fix cache correctness while keeping the single-workflow shape —
no required-check rename yet. This is the precondition for safely reshaping lanes later.

**Depends on:** Phase 103 (baseline + slowest/timing evidence; confirms current stable Elixir minor
and `mix.lock` resolved versions before pinning the new primary pair).

**Requirements:** CACHE-01, CACHE-02, CACHE-03, CACHE-04, CACHE-05

**Success criteria** (what must be TRUE):

1. A `.github/actions/setup-elixir` composite action (plus a shared MinIO setup step) is the single
   source of truth for environment setup and cache keys across the jobs that duplicate that block
   today (CACHE-01).

2. Cache keys include OS+arch, OTP, Elixir, `MIX_ENV`, the `mix.lock` hash, and a version buster;
   deps, `_build`, and PLT caches are separate and never restored across incompatible dimensions
   (CACHE-02).

3. The Dialyzer PLT uses an `actions/cache` restore/save split that persists the built PLT even when
   analysis fails, with the PLT key hashing `mix.exs`/`.dialyzer_ignore.exs` (CACHE-03).

4. `mix deps.get --check-locked` and `mix deps.unlock --check-unused` fail the build on lockfile
   drift, so a stale or unused lock cannot pass via broad restore keys (CACHE-04).

5. Version-invariant lint (`format --check-formatted`, Credo, doctor) runs once on the primary pair
   instead of on every matrix cell; `.tool-versions` lands and the stray `setup-ffmpeg` action in
   `release.yml` is aligned to the repo's ffmpeg install path (CACHE-05).

**Plans:** TBD

---

### Phase 105: Aggregate Required Check + Branch-Protection Flip

**Goal:** Isolate the single highest-blast-radius migration — making one stable aggregate the sole
required check — into one reviewable PR, landed **before** any matrix/lane rename so subsequent
renames never touch branch protection again.

**Depends on:** Phase 104 (single-workflow shape stable) and Phase 103's captured live required-check
names. MUST precede Phase 106.

**Requirements:** GATE-01, GATE-02

**Success criteria** (what must be TRUE):

1. A single stable `CI Summary` aggregate job (`needs:` all jobs, `if: always()`, treating `skipped`
   as pass) is the sole signal that represents overall CI status (GATE-01).

2. `scripts/setup_branch_protection.sh` and the nightly re-assert workflow are updated in the **same
   change** so branch protection requires **only** `CI Summary`; confirmed via the script's expected
   list (GATE-02).

3. The fork-PR "pending forever" trap is closed: PRs from forks (where repo-gated jobs skip) report
   `CI Summary` as success rather than hanging (GATE-01, GATE-02).

4. The `CI` workflow file name and `name: CI` are preserved, keeping the release-train coupling
   (`release-please-automerge.yml` + `gate-ci-green`) intact (GATE-02).

**Plans:** TBD

---

### Phase 106: Trigger Split + Matrix/Lane Refinement

**Goal:** Deliver the headline wall-clock win — now that only `CI Summary` is required, split work by
trigger so the PR lane carries representative signal and release-readiness breadth moves to
main/nightly/release.

**Depends on:** Phase 105 (only `CI Summary` required, so lanes can be renamed/split freely) and
Phase 103's per-step `package-consumer` timing + slowest-test evidence.

**Requirements:** LANE-01, LANE-02, LANE-03, LANE-04

**Success criteria** (what must be TRUE):

1. A fast PR lane with a `concurrency` group that cancels stale in-progress PR runs targets a
   representative gate at roughly ≤7 minutes on a representative change; main and release lanes
   serialize and never cancel (LANE-01).

2. The `package-consumer` long pole is scoped by trigger — one representative `image` install-smoke
   on PR; the full 5-profile matrix + `release_preflight` + `hex.publish --dry-run` on
   `push:main`/nightly/release — with the release full-verification gate provably still satisfied by
   a run that ran the full matrix (LANE-02).

3. A nightly lane carries the broad OTP×Elixir compatibility matrix, `gcs-soak`,
   `package-consumer-gcs-live`, and an owned Dialyzer lane off the PR critical path (LANE-03).

4. A documented keep / optimize / move-to-nightly / quarantine / delete (buckets A–E)
   classification backs every lane placement, coverage is moved off the PR critical path, and any
   trust/speed tradeoff is labeled explicitly in CONTRIBUTING and the PR (LANE-04).

5. `ci.yml` keeps its file name and `name: CI` on `push:main`, and the release gate is not weakened.

**Plans:** TBD

---

### Phase 107: Reliability, Security & DX Hardening

**Goal:** Settle the pipeline — concurrency/async correctness, supply-chain posture, a faithful
local repro, and the DX docs that describe the *settled* fast-PR check set.

**Depends on:** Phase 106 (lane numbers settled; async-first before partitioning; DX docs the final
shape).

**Requirements:** HARD-01, HARD-02, HARD-03, HARD-04

**Success criteria** (what must be TRUE):

1. An ExUnit async-safety static guard lands before any conversion; verified-safe modules are
   converted to `async: true`, and `--partitions` (with DB-per-partition + merged coverage) is
   adopted only where Phase 103 measurement and runner cores justify it (HARD-01).

2. All third-party actions are pinned to immutable SHAs, `dependabot.yml` (`github-actions` + `mix`)
   lands, `{:mix_audit, "~> 2.1"}` is added to the audit lane, and each job declares least-privilege
   `permissions:` (HARD-02).

3. A single local `mix ci` alias runs the same merge-blocking checks as the PR gate;
   `CONTRIBUTING.md` documents the lanes, the required check, and the local command; the README badge
   points at the meaningful (`CI Summary`) check (HARD-03).

4. A faithful Linux-Chromium local repro lands (pinned Playwright container + `scripts/ci/e2e_local.sh`
   + exact `@playwright/test` and font pins), and the divergent token-pair vs runtime contrast
   thresholds are reconciled to one shared constant (HARD-04).

**Plans:** TBD

**Research flag:** Which of the non-async test modules are *genuinely* unsafe vs conservatively
marked requires reading `test/` + sandbox/Oban config; partitioning payoff is evidence-gated
(Phase 103 cores + slowest-test data), not assumed.

---

### Phase 86: Research & Architecture Lock

**Goal:** Lock the architecture, information architecture, animation, Docker DX, CSS, and
UI-principles decisions that downstream v1.18 phases must follow.

**Depends on:** v1.18 charter recorded; b1.0 brand assets and tokens available.

**Requirements:** PRIN-01

**Success criteria:**

1. LiveDashboard/Oban Web packaging decisions are recorded for router macro, asset serving,
   CSP, CSS isolation, and optional-dependency matrix.

2. Console information architecture is mapped from persona/JTBD lenses, with gov.uk/GDS
   research translated into maintainer-facing Rindle surfaces.

3. Motion principles are tied to brand `motion` tokens and remain restrained for an
   operational console.

4. Docker multi-project DX decisions cover `COMPOSE_PROJECT_NAME`, env-driven ports, and
   traefik tradeoffs.

5. CSS architecture is locked: console uses BEM + generated custom properties from
   `brandbook/tokens/tokens.json`; Cohort keeps Tailwind/daisyUI momentum.

6. UI-principles document is linked from `AGENTS.md`.

**Plans:** 3/3 plans complete

Plans:

- [x] 86-01-PLAN.md — Lock mountable console architecture and task-first IA.
- [x] 86-02-PLAN.md — Lock console CSS architecture and operational motion.
- [x] 86-03-PLAN.md — Lock Docker demo DX and link UI principles from `AGENTS.md`.

---

### Phase 87: Docker & Demo DX

**Goal:** Make the demo stack fast and conflict-free before the UI-heavy phases iterate on it.

**Depends on:** Phase 86

**Requirements:** DX-01, DX-02, DX-03

**Success criteria:**

1. Compose stack can run alongside sibling projects via namespacing and env-driven ports.
2. Port conflict guidance is documented with sane defaults.
3. Dockerfile layer cache fetches deps before source COPY.
4. Dev iteration path supports style/template changes without rebuilding deps.
5. Launch flow prints a copy-pasteable URL map for app, admin console, and MinIO console.

**Plans:** 3/3 plans complete

Plans:

**Wave 1**

- [x] 87-01-PLAN.md - Env-driven compose ports and launch URL map.
- [x] 87-02-PLAN.md - Dockerfile dependency-cache ordering.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 87-03-PLAN.md - Docker quick-try and proof-matrix docs.

---

### Phase 88: Admin Design System & UI Kit

**Goal:** Ship the token-generated `rindle-admin` design system and component kit that the
console implementation will use.

**Depends on:** Phase 86 and Phase 87

**Requirements:** DS-01, DS-02, DS-03, ADMIN-02 groundwork

**Success criteria:**

1. `rindle-admin` CSS is generated from `brandbook/tokens/tokens.json` using BEM and CSS
   custom properties.

2. Light/dark/system theme picker is implemented as a first-class component.
3. Core components exist for nav shell, tables, lifecycle-state chips, buttons, confirm
   dialog, drawer, toasts, empty states, and skeletons.

4. Component-gallery screenshot harness exists for maintainer review.
5. Mechanical WCAG AA contrast gate covers console token pairs.
6. Maintainer reviews rendered gallery before later console phases rely on it.

**Plans:** 3/3 plans complete

Plans:

**Wave 1**

- [x] 88-01-PLAN.md — Generate `rindle-admin` CSS and console contrast gates.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 88-02-PLAN.md — Generate component gallery and screenshot/theme harness.

**Wave 3** *(blocked on Waves 1–2 completion)*

- [x] 88-03-PLAN.md — Document design-system operation and run maintainer gallery review.

---

### Phase 89: Console Read Surfaces

**Goal:** Ship the mountable console read experience with safe host integration, self-contained
assets, live updates, and isolated admin queries.

**Depends on:** Phase 88

**Requirements:** ADMIN-01, ADMIN-02, ADMIN-03, ADMIN-05, ADMIN-06

**Success criteria:**

1. Host app mounts the console via router macro with host auth pipeline and `on_mount` hook.
2. Console asset-serving plug is safe by default and self-contained.
3. Home, assets list/detail, upload sessions, variant/job activity, doctor, and runtime status
   read surfaces are available.

4. PubSub live updates use existing `:asset`, `:variant`, and `:upload_session` topics.
5. Queries remain isolated in `Rindle.Admin.Queries`, not added to the public facade.
6. Optional-dependency CI matrix proves `phoenix_live_view` compiles away cleanly when absent.

**Plans:** 7/7 plans complete

Plans:

**Wave 1**

- [x] 89-01-PLAN.md — Mount router macro and safe host-auth boundary.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 89-02-PLAN.md — Package and prove self-contained admin assets.
- [x] 89-03-PLAN.md — Build isolated admin read query boundary.

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 89-04-PLAN.md — Implement shell, Home/Status, Assets, and Upload Sessions.

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 89-05-PLAN.md — Complete Variants/Jobs, Runtime/Doctor, and Actions read surfaces.

**Wave 5** *(blocked on Wave 4 completion)*

- [x] 89-06-PLAN.md — Add upload-session PubSub broadcasts and invalidation proof.

**Wave 6** *(blocked on Wave 5 completion)*

- [x] 89-07-PLAN.md — Add optional LiveView compile-away CI proof.

---

### Phase 90: Console Ops Actions

**Goal:** Add operational console actions for existing lifecycle capabilities without adding new
lifecycle semantics.

**Depends on:** Phase 89

**Requirements:** ADMIN-04

**Success criteria:**

1. Owner erasure preview/execute and batch erasure are exposed with deliberate destructive UX.
2. Typed confirmation and collateral preview are required for destructive actions.
3. Variant regeneration, quarantine review, and lifecycle repair reuse existing facade
   capabilities.

4. Console actions do not introduce new lifecycle semantics beyond recorded v1.18 scope.

**Plans:** 2/2 plans complete

Plans:

**Wave 1**

- [x] 90-01-PLAN.md — Owner erasure and batch erasure with typed-confirmation destructive UX.
- [x] 90-02-PLAN.md — Variant regeneration, lifecycle repair, and quarantine-review triage.

**Status:** Complete — 8/8 must-haves verified; HUMAN-UAT (destructive-action UX) signed off 2026-06-20.

---

### Phase 91: Cohort Demo Evolution

**Goal:** Evolve Cohort into the adoption lab that proves the console across branded demo
surfaces, media types, and lifecycle states.

**Depends on:** Phase 90

**Requirements:** DEMO-01, DEMO-02, DEMO-03

**Success criteria:**

1. Cohort gets a lightweight brand distinct from Rindle after a rendered options checkpoint.
2. Demo covers audio and document media profiles.
3. Seeds express every asset, variant, and upload-session lifecycle state, including degraded,
   quarantined, failed, stale, and expired.

4. Cohort mounts the admin console.
5. Click-around walkthrough is documented.

**Plans:** 3/3 plans complete

Plans:

**Wave 1**

- [x] 91-01-PLAN.md — Replace default Phoenix logo with new distinct Cohort brand.
- [x] 91-02-PLAN.md — Define Audio/Document profiles and seed database with lifecycle edge cases.
- [x] 91-03-PLAN.md — Mount Rindle Admin console in Cohort and document walkthrough.

---

### Phase 92: E2E & Screenshot-Driven Polish Loop

**Goal:** Make console behavior and polish deterministic through merge-blocking Playwright and
all-screens screenshot iteration.

**Depends on:** Phase 91

**Requirements:** E2E-01, E2E-02

**Success criteria:**

1. Deterministic Playwright specs cover happy paths, main error cases, boundary conditions,
   theme switching, and destructive flows.

2. Console E2E lane is merge-blocking.
3. Automated screenshot capture covers all screens in light and dark mode.
4. Screenshot analyze-to-fix polish passes are run until visual regressions are resolved.

**Plans:** 5/5 plans complete

Plans:

**Wave 1**

- [x] 92-01-PLAN.md — Create admin E2E helper and stable selector foundation.

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 92-02-PLAN.md — Add admin surface, boundary, detail, redaction, and theme specs.
- [x] 92-03-PLAN.md — Add destructive and non-destructive admin action specs.

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 92-04-PLAN.md — Add live all-screen screenshots and run screenshot polish iteration.

**Wave 4** *(blocked on Wave 3 completion)*

- [x] 92-05-PLAN.md — Wire specs into proof matrix, drift gate, docs, and CI lane truth.

---

### Phase 93: Truth, Docs & Milestone Audit

**Goal:** Close v1.18 with truthful docs, public-surface parity, traceability closure, and a
milestone audit.

**Depends on:** Phase 92

**Requirements:** TRUTH-07

**Success criteria:**

1. `guides/admin_console.md` documents the console accurately.
2. `user_flows` and `JTBD-MAP` reflect the T4 admin UI reversal.
3. `lib/rindle.ex` no longer claims there is no admin UI.
4. README and HexDocs describe the shipped console truthfully.
5. Requirements traceability is closed.
6. v1.18 milestone audit is written.

**Plans:** 4/4 plans complete

Plans:

- [x] 93-01-PLAN.md — Fix facade moduledoc + operations/troubleshooting/user_flows admin-UI denials (F1–F5).
- [x] 93-02-PLAN.md — Reverse JTBD-MAP T4 admin-UI exclusion (idempotent anchor) + close REQUIREMENTS traceability.
- [x] 93-03-PLAN.md — Author guides/admin_console.md, wire into mix.exs extras, add README mention.
- [x] 93-04-PLAN.md — Parity-test lock (Nyquist) + regenerate v1.18 milestone audit + UAT-status checkpoint.

**Audit:** [.planning/milestones/v1.18-MILESTONE-AUDIT.md](milestones/v1.18-MILESTONE-AUDIT.md) — status `shipped` (19/19 reqs + 8/8 phases verified; HUMAN-UAT for phases 90/91/92 signed off 2026-06-20).

</details>

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 103. Observability / Baseline | 2/4 | In Progress|  |
| 104. Cache & Tooling Hygiene | 0/TBD | Not started | - |
| 105. Aggregate Required Check + Branch-Protection Flip | 0/TBD | Not started | - |
| 106. Trigger Split + Matrix/Lane Refinement | 0/TBD | Not started | - |
| 107. Reliability, Security & DX Hardening | 0/TBD | Not started | - |
| 94. Foundation — Token Pipeline CI Gate & New Categories | 5/5 | Complete    | 2026-06-15 |
| 95. Admin Level-1 Component Audit [A] | 5/5 | Complete   | 2026-06-16 |
| 96. Cohort Component Layer + Dark/Reduced-Motion [B] | 5/5 | Complete    | 2026-06-17 |
| 97. Admin Level-2 Meta-Components [A] | 4/4 | Complete    | 2026-06-17 |
| 98. Admin Level-3 Pages + Motion/Mobile/A11y/IA/Microcopy [A] | 5/5 | Complete    | 2026-06-18 |
| 99. Cohort Page Migrations (small 7) [B] | 5/5 | Complete    | 2026-06-18 |
| 100. Cohort /upload Migration [B] | 2/2 | Complete    | 2026-06-18 |
| 101. daisyUI Retirement [B] | 4/4 | Complete    | 2026-06-18 |
| 102. Re-Converge — Visual Matrix, Idempotency & Audit | 6/6 | Complete    | 2026-06-19 |

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

## Demand-Gated Pause — Superseded for v1.18/v1.19 (2026-06-10 / 2026-06-14)

**Formalized:** 2026-05-27 | **Status:** Overridden by maintainer-pull v1.18 charter
(recorded in PAUSE-03 amendment, `.planning/REQUIREMENTS.md`) and extended by the v1.19
Design-System Stress-Test quality milestone (2026-06-14). The demand gates themselves
remain intact for v1.20+:

- **LIFE-06** — compliance/legal ticket for force-delete shared assets, or
- **STREAM-10** — named adopter for second streaming provider

Pause posture resumes after v1.19 ships unless a new charter exists.
See [post-v116 assessment](threads/2026-05-27-post-v116-milestone-assessment.md).

## Deferred to v1.20+ / Later

- Force-delete semantics for still-shared assets (LIFE-06) — compliance pull only
- Second streaming provider (Cloudflare/Bunny) — explicit adopter demand only
- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Richer reusable uploader component abstractions
- Signed dynamic image transforms / EXIF privacy stripping

## Archive

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

---
*Last updated: 2026-06-20 — chartered v1.20 CI/CD Performance (SEED-003): Phases 103–107, 18/18 requirements mapped. Non-feature / DX-infra milestone (ZERO `lib/` public-API change). Load-bearing dependency order: observability → cache → aggregate-check → lane-split → hardening. v1.18 and v1.19 shipped & archived.*
