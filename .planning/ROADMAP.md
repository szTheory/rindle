# Roadmap: Rindle

## Milestones

- 🚧 **v1.21 CI/DX Reliability Tail** — Phases 108–112 (in flight, chartered 2026-06-26 from SEED-004 + the 2026-06-26 flake cluster; non-feature/DX, ships Hex 0.3.2 via two adopter-invisible `lib/` `fix:` patches, D-v1.21-01; 24 reqs COV/EPIPE/GATE/ISO/LOCK/TRUTH)
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

### v1.21 CI/DX Reliability Tail (Phases 108–112) — IN FLIGHT

**Charter (2026-06-26):** SEED-004 + the 2026-06-26 flake cluster. Non-feature/DX milestone making
the merge gate deterministic and trustworthy — kill the double-suite-run, fix the subprocess
`:epipe` race, close the PR↔main gate-coverage gap, and harden the last async-isolation smell — so a
green PR reliably means a green `main`. Ships Hex **0.3.2** via two adopter-invisible `lib/` `fix:`
patches (D-v1.21-01: `av/subprocess.ex` EPIPE; `config.ex` ISO).

**Load-bearing dependency order (must not be reversed):** de-flake first (108 Coverage single-run →
109 Subprocess `:epipe` → 110 Async isolation) → lock it down (111 Regression locks) → shift-left
LAST (112 PR↔main gate). The lean `adoption-demo-e2e-smoke` enters `CI Summary.needs` ONLY after the
de-flake phases land AND N consecutive green push:main `adoption-demo-e2e` runs are observed —
gating a still-live flake would import it into the required gate.

**Hard invariants (every phase respects):** never rename `ci.yml` / `name: CI` (release-train
coupling via `release-please-automerge.yml` + `gate-ci-green`); `CI Summary` keeps `skipped`==pass
and stays the SOLE required check (`setup_branch_protection.sh` byte-unchanged); never weaken the
release full-verification gate; security invariants 8–13 byte-equivalent at argv for the EPIPE phase.

- [ ] **Phase 108: Coverage single-run** — one ExUnit suite execution per lane; `quality` emits both the gate and the JSON artifact, integration/adoption drop their redundant coverage run (COV-01..04)
- [ ] **Phase 109: Subprocess `:epipe` hardening** — absorb MuonTrap #98 broken-pipe in `Subprocess.run/3` + correct the stale invariant-13 truth (EPIPE-01..05, TRUTH-01)
- [ ] **Phase 110: Async-isolation hardening** — process-scoped repo override replaces the global swap; guard closes the cross-pool gap (ISO-01..05)
- [ ] **Phase 111: Regression locks** — durable shipped-artifact meta-tests lock the 2026-06-26 cluster so it cannot regress (LOCK-01..05)
- [ ] **Phase 112: PR↔main gate shift-left** — lean `adoption-demo-e2e-smoke` joins the PR gate AFTER de-flake + N green main runs (GATE-01..04)

## Phase Details

### Phase 108: Coverage single-run

**Goal:** Every default-suite lane runs the ExUnit suite exactly once, emitting both the
merge-blocking console gate and `cover/excoveralls.json` from that single run — halving test
wall-clock and halving `:epipe` exposure on the PR critical path.

**Depends on:** Nothing (first phase of the milestone; safe de-flake foundation, CI/mix-config only).

**Requirements:** COV-01, COV-02, COV-03, COV-04

**Success criteria:**

1. Each default-suite lane (`quality`, `integration`, install-smoke/adoption) runs the ExUnit suite
   exactly once per matrix cell. The `quality` lane's single run uses
   `mix coveralls.multiple --type local --type json --slowest 20`, producing both the console gate
   and `cover/excoveralls.json` from that one run; the `integration` and install-smoke/adoption lanes
   drop their redundant standalone coverage run entirely (decision 2b — no artifact consumer exists),
   leaving each with exactly one suite execution.

2. The merge-blocking coverage gate still runs the `local` analyzer (`ensure_minimum_coverage`
   exercised); the gate's pass/fail is never derived from `coveralls.json`'s exit code.

3. The redundant standalone coverage run is removed from all three lanes (the `Generate coverage JSON
   artifact` step on `quality`, the standalone `mix coveralls.json` step on `integration`/adoption).
   `cover/excoveralls.json` is still produced at the same path on the `quality` lane and uploaded;
   the integration/adoption upload steps tolerate its absence (`if-no-files-found: warn` preserved).

4. A contributor reproduces the CI coverage step locally with one documented command and `mix ci`
   reflects the single-run invocation (local↔CI parity).

**Invariants:** zero `lib/` change; `ci.yml` / `name: CI` unrenamed; `CI Summary` untouched; release
full-verification gate unchanged.

**Plans:** 1 plan

- [ ] 108-01-PLAN.md — single-run coverage across all 3 default-suite lanes (ci.yml + mix.exs + RUNNING.md)

---

### Phase 109: Subprocess `:epipe` hardening

**Goal:** `Rindle.AV.Subprocess.run/3` never lets a broken-pipe transport exit (MuonTrap #98) kill
its caller — making every AV invocation deterministic in tests AND in adopter Oban workers — and the
stale security-invariant-13 prose is corrected to the actual MuonTrap-only path.

**Depends on:** Phase 108 (de-flake foundation; with the redundant run removed, the remaining single
run's broken-pipe race is the only `:epipe` source left to fix).

**Requirements:** EPIPE-01, EPIPE-02, EPIPE-03, EPIPE-04, EPIPE-05, TRUTH-01

**Success criteria:**

1. `Subprocess.run/3` never propagates `:epipe` (or any broken-pipe transport exit) to its caller;
   the caller still receives the real `{output, status}`.

2. The exact contract is preserved (`{collectable, status | :timeout}`, `into: ""`,
   `stderr_to_stdout: true`) and security invariants 8–13 are byte-equivalent at argv
   (`build_args`/`build_opts` unchanged; no shell; `Ffmpeg`/`Ffprobe` call sites unchanged).

3. A legitimate ffmpeg cap-hit early-exit (`-t`/`-fs`/`-timelimit`) is reported via its real exit
   status and never surfaces `:epipe`.

4. A deterministic `@tag :regression` repro fails unpatched and passes patched; the two
   originally-flaking tests (`ffmpeg_test.exs:32`, `lifecycle_repair_test.exs:122`) pass unmodified;
   the shim is forward-compatible with an upstream #98 resolution (degrades to a no-op, no leaked
   monitors/processes; a code comment cites #98).

5. PROJECT.md security-invariant 13's stale "Rambo on macOS/Windows dev" clause is corrected to
   reflect the actual MuonTrap-only subprocess path (no Rambo in `mix.lock`).

**Invariants:** authorized adopter-invisible `lib/rindle/av/subprocess.ex` touch (D-v1.21-01), ships
`fix:` → 0.3.2; security invariants 8–13 byte-equivalent; no public API / error-vocab change.

**Plans:** TBD

---

### Phase 110: Async-isolation hardening

**Goal:** `Rindle.Config.repo/0` consults a `$callers`-aware process-dictionary override before the
application env, eliminating the global `Application.put_env(:rindle, :repo, …)` in the counting-repo
double — so the failing-txn double is process-scoped (like Sandbox/Mox) and can never pollute a
concurrent async reader — and the v1.20 async-safety guard gains a rule that makes the footgun
un-reintroducible.

**Depends on:** Phase 109 (continues the de-flake group; all three de-flake phases must land before
the gate shift-left in Phase 112).

**Requirements:** ISO-01, ISO-02, ISO-03, ISO-04, ISO-05

**Success criteria:**

1. `Config.repo/0` consults a `$callers`-aware process-dictionary override (covering spawned Tasks /
   inline Oban) before the application env; behavior is byte-unchanged when no override is set.

2. Test-only `Config.put_repo_override/1` + `delete_repo_override/0` set/clear the per-process
   override (process-dictionary only; no global state).

3. `with_counting_repo/2` uses the process override and performs no `Application.put_env(:rindle,
   :repo, …)`; defensive `async: false` demotions caused by the old global swap are reverted (e.g.
   `StreamingDispatchTest` restored to `async: true`).

4. The async-safety guard gains a `:global_repo_swap` rule flagging
   `Application.put_env/delete_env(:rindle, :repo, …)` in any test module, with a message pointing at
   `put_repo_override/1`.

5. A concurrency regression test proves isolation: the counting double in process A force-fails its
   transaction while an unrelated spawned process B reads `Config.repo() == Rindle.Repo` and its
   transaction succeeds; the test fails on the old impl and passes on the new.

**Invariants:** authorized adopter-invisible `lib/rindle/config.ex` touch (D-v1.21-01), default
branch byte-unchanged, ships `fix:` → 0.3.2; adopter-first repo ownership preserved.

**Plans:** TBD

---

### Phase 111: Regression locks

**Goal:** The already-fixed 2026-06-26 cluster gets durable, merge-blocking, shipped-artifact-only
locks so it cannot silently regress — asserting SHIPPED artifacts only, never `.planning/` paths.

**Depends on:** Phase 110 (the flakes are dead — coverage single-run, `:epipe`, async isolation — so
the locks ride a deterministic suite and assert closed state, not in-flight fixes).

**Requirements:** LOCK-01, LOCK-02, LOCK-03, LOCK-04, LOCK-05

**Success criteria:**

1. A merge-blocking `quality` meta-test asserts `scripts/install_smoke.sh` keeps the `phx.new` probe
   + self-install before the smoke proceeds.

2. A `package-consumer` CI step purges the `phx.new` archive before the smoke so the cold-cache
   self-install path is exercised on every PR.

3. The keyboard-modality (`:focus-visible` Tab-first) helper is deduped into one shared exported
   function consumed by both `examples/adoption_demo/e2e/support/admin-polish.js` and
   `brandbook/src/admin-gallery-check.mjs`.

4. A merge-blocking `quality` meta-test asserts the Tab-first modality is present at every
   `focus({focusVisible:true})` site (post-dedupe, asserting the shared helper).

5. A merge-blocking `quality` meta-test globbing `test/**/*.exs` fails if any test reads a
   `.planning/` path (keeping the decoupled hygiene from regressing).

**Invariants:** every lock rides the already-required `quality`/`package-consumer` lanes; no new
required checks; asserts shipped artifacts only — never `.planning/`.

**UI hint:** yes

**Plans:** TBD

---

### Phase 112: PR↔main gate shift-left

**Goal:** Close the PR↔main gate-coverage gap by adding ONE lean deterministic
`adoption-demo-e2e-smoke` PR job to `CI Summary.needs`, so the render-regression class that reached
`main` on 2026-06-26 is caught pre-merge — without giving back the v1.20 wall-clock win and only
after the flakes are provably dead (LOAD-BEARING: this phase is LAST).

**Depends on:** Phases 108, 109, 110 (de-flake must land first) AND N consecutive green push:main
`adoption-demo-e2e` runs observed — the gate must not import a still-live flake. Builds on the
Phase 111 locks.

**Requirements:** GATE-01, GATE-02, GATE-03, GATE-04

**Success criteria:**

1. A lean, deterministic `adoption-demo-e2e-smoke` job runs on every PR (Chromium-only, MinIO-local,
   no secrets, pinned Playwright container, deterministic specs only — excludes the screenshot spec)
   and is part of `CI Summary.needs` and `ci-observability.needs`.

2. PR p95 wall-clock stays ≤ ~7.5 min (the new lane runs as a parallel chain at/under the existing
   image-smoke long pole); this is observed/guarded, not assumed.

3. `cohort-demo-smoke`, `package-consumer-full`, and `mux-soak` stay off the PR gate with documented
   rationale; `setup_branch_protection.sh` is byte-unchanged (`CI Summary` remains the sole required
   check; no second required context).

4. The lean lane enters `CI Summary.needs` ONLY after COV/EPIPE/ISO land and N consecutive green
   push:main `adoption-demo-e2e` runs are observed (the gate must not import a still-live flake).

**Invariants:** `ci.yml` / `name: CI` unrenamed; `CI Summary` stays the sole required check
(`setup_branch_protection.sh` byte-unchanged); skip==pass preserved (lean lane always runs on PR →
plain success/fail); release full-verification gate untouched; no `lib/` change.

**UI hint:** yes

**Plans:** TBD

---

## Phases (shipped — collapsed history)

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
| 108. Coverage single-run | 0/? | Not started | - |
| 109. Subprocess `:epipe` hardening | 0/? | Not started | - |
| 110. Async-isolation hardening | 0/? | Not started | - |
| 111. Regression locks | 0/? | Not started | - |
| 112. PR↔main gate shift-left | 0/? | Not started | - |
| 103. Observability / Baseline | 4/4 | Complete    | 2026-06-20 |
| 104. Cache & Tooling Hygiene | 4/4 | Complete    | 2026-06-21 |
| 105. Aggregate Required Check + Branch-Protection Flip | 1/1 | Complete   | 2026-06-21 |
| 106. Trigger Split + Matrix/Lane Refinement | 4/4 | Complete    | 2026-06-22 |
| 107. Reliability, Security & DX Hardening | 4/4 | Complete    | 2026-06-22 |
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

## Backlog

_(empty — no open backlog items)_

---
*Last updated: 2026-06-26 — chartered **v1.21 CI/DX Reliability Tail** (Phases 108–112, 24/24 requirements mapped: COV→108, EPIPE+TRUTH→109, ISO→110, LOCK→111, GATE→112); research-locked load-bearing order (de-flake 108–110 → lock 111 → shift-left 112 LAST). Ships Hex 0.3.2 via two adopter-invisible `lib/` `fix:` patches (D-v1.21-01). Prior: backlog review removed resolved item 999.1 (v1.20 CI green-up — CI green, 0.3.1 shipped, branch-protection flip already fired). Backlog now empty. v1.20 CI/CD Performance SHIPPED & archived (Phases 103–107, 18/18 requirements, 5/5 phases, ZERO `lib/` change); phase details in [milestones/v1.20-ROADMAP.md](milestones/v1.20-ROADMAP.md). No active milestone — next via `/gsd-new-milestone`. v1.18 and v1.19 shipped & archived.*
