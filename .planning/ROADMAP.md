# Roadmap: Rindle

## Milestones

- 🔄 **v1.18 Admin Console & Adoption Lab** — Phases 86–93 (in progress, charter 2026-06-10; ships as hex 0.3.0)
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

### 🔄 v1.18 Admin Console & Adoption Lab (Phases 86–93) — IN PROGRESS

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

- [ ] **Phase 86: Research & Architecture Lock** — parallel subagent research → locked ADRs:
  LiveDashboard/Oban Web packaging (router macro, asset serving, CSP, CSS isolation,
  optional-dep matrix); gov.uk/GDS information architecture → persona/JTBD-driven console
  IA map; emilkowal.ski animation principles → restrained motion spec tied to brand
  `motion` tokens; Docker multi-project DX (COMPOSE_PROJECT_NAME / env ports / traefik
  tradeoffs); CSS architecture lock (BEM + custom properties generated from
  `brandbook/tokens/tokens.json` for the console; Cohort keeps Tailwind/daisyUI momentum).
  Output includes the UI-principles doc linked from `AGENTS.md` (PRIN-01).
- [ ] **Phase 87: Docker & Demo DX** (early — every later UI phase iterates faster) —
  project namespacing, env-driven ports + conflict guidance, layer-cache fix
  (deps before source COPY), dev style-change path without rebuilds, launch URL map,
  reader-empathetic docs. (DX-01..03)
- [ ] **Phase 88: Admin Design System & UI Kit** — token-generated `rindle-admin` CSS
  (BEM), light/dark/system theme picker, core components (nav shell, tables,
  lifecycle-state chips, buttons, confirm dialog, drawer, toasts, empty states,
  skeletons), component-gallery screenshot harness, WCAG contrast gate.
  **Checkpoint: maintainer reviews rendered gallery.** (DS-01..03, ADMIN-02 groundwork)
- [ ] **Phase 89: Console Read Surfaces** — router macro + host-auth `on_mount` +
  asset-serving plug (safe by default); home, assets list/detail, upload sessions,
  variant/job activity, doctor + runtime status; pubsub live updates;
  `Rindle.Admin.Queries` isolation; optional-dep CI matrix. (ADMIN-01..03, 05, 06)
- [ ] **Phase 90: Console Ops Actions** — erasure preview/execute + batch with
  destructive-action UX (typed confirmation, collateral preview), variant regeneration,
  quarantine review, lifecycle repair. (ADMIN-04)
- [ ] **Phase 91: Cohort Demo Evolution** — Cohort's own lightweight brand
  (**rendered options checkpoint**), audio + document profiles, seeds expressing every
  lifecycle state, mounts the console, click-around walkthrough. (DEMO-01..03)
- [ ] **Phase 92: E2E & Screenshot-Driven Polish Loop** — deterministic console Playwright
  specs (happy/error/boundary/theme/destructive) in a merge-blocking lane; all-screens ×
  light/dark capture → analyze → fix polish passes. (E2E-01..02)
- [ ] **Phase 93: Truth, Docs & Milestone Audit** — `guides/admin_console.md`,
  user_flows + JTBD-MAP updates (T4 reversal), facade moduledoc truth fix
  (`lib/rindle.ex` "no admin UI" line), README/HexDocs, traceability closure,
  MILESTONE-AUDIT. (TRUTH-07)

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

## Demand-Gated Pause — Superseded for v1.18 (2026-06-10)

**Formalized:** 2026-05-27 | **Status:** Overridden by maintainer-pull v1.18 charter
(recorded in PAUSE-03 amendment, `.planning/REQUIREMENTS.md`). The demand gates themselves
remain intact for v1.19+:

- **LIFE-06** — compliance/legal ticket for force-delete shared assets, or
- **STREAM-10** — named adopter for second streaming provider

Pause posture resumes after v1.18 ships unless a new charter exists.
See [post-v116 assessment](threads/2026-05-27-post-v116-milestone-assessment.md).

## Deferred to v1.19+ / Later

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
*Last updated: 2026-06-10 — v1.18 Admin Console & Adoption Lab charter recorded (phases 86–93, maintainer-pull override of the pause; hex 0.3.0 target)*
