# Roadmap: Rindle

## Milestones

- 🚧 **b1.0 Brand Foundations** — Phases 81–85 (brand track, non-feature; opened 2026-06-10)
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

### 🚧 b1.0 Brand Foundations (Phases 81–85) — ACTIVE

> b1.0 is a non-feature brand-track milestone. Zero public API, zero `lib/` changes. The
> demand-gated pause for feature work (PAUSE-01..03) remains active; v1.18+ remains
> reserved for LIFE-06/STREAM-10.

**Goal:** Pressure-test the AI-generated brand book seed (`prompts/rindle-brand-book.md`)
and build the committed brand system: user-selected logo system, verified design tokens,
self-contained HTML brand book in `brandbook/`, and public-surface integration
(README / HexDocs / social preview).

- [x] Phase 81: Brand Audit & Direction Lock (2/2 plans) — BRAND-01, BRAND-02 — completed 2026-06-10
  **Goal:** Seed pressure-tested into one locked direction (ten-lens
  KEEP/TIGHTEN/REWORK/ADD/REMOVE audit; placeholder-logo conflict resolved; name risk
  flagged human-review-only). Audit: `.planning/research/b1.0-brand-audit.md`.
- [x] Phase 82: Logo Candidates & User Selection (2/2 plans) — BRAND-03 — completed 2026-06-10 (user pick: E Confluence, execution e1)
  **Goal:** User picks the logo direction from 5 genuinely distinct committed SVG
  candidates (≥2 integrated typemarks; no containers; tight type; no subtitle on main
  lockups) presented via a visual contact sheet.
- [x] Phase 83: Logo System Refinement (2/2 plans) — BRAND-04 — completed 2026-06-10
  **Goal:** Winner refined into the full system — lockups (primary/mono/dark/subtitle),
  icon-only mark, favicon set, social avatar — 16px-legible, constraint-checked.
- [ ] Phase 84: Design Tokens & HTML Brand Book (0/3 plans) — BRAND-05, BRAND-06, BRAND-07
  **Goal:** tokens.json/tokens.css (raw + semantic + states + dark mode + focus) with a
  passing WCAG AA contrast gate, rendered live by a professional self-contained
  single-page `brandbook/index.html` within a 1.5 MB budget.
- [ ] Phase 85: Repo Surface Integration (0/2 plans) — BRAND-08 — *separable*
  **Goal:** ex_doc logo/favicon, README header lockup (light/dark), regenerable 1280×640
  GitHub social preview; `mix docs` + proof lanes green; zero `lib/` changes.

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

## Demand-Gated Pause — Feature Work (active)

**Formalized:** 2026-05-27 | **Status:** No feature phases (brand-track phases 81–85 run concurrently)

Maintainer mode for feature work: patch/minor Hex releases and issue-driven fixes only.
Feature work resumes when `/gsd-new-milestone` opens a charter with:

- **LIFE-06** — compliance/legal ticket for force-delete shared assets, or
- **STREAM-10** — named adopter for second streaming provider

See `.planning/REQUIREMENTS.md` and
[post-v116 assessment](threads/2026-05-27-post-v116-milestone-assessment.md).

**Do not** run `/gsd-plan-phase` for feature work until a feature milestone exists —
**brand-track phases 81–85 (b1.0) are the sanctioned exception**.

## Deferred to v1.18+ / Later

- Force-delete semantics for still-shared assets (LIFE-06) — compliance pull only
- Second streaming provider (Cloudflare/Bunny) — explicit adopter demand only
- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Richer reusable uploader component abstractions
- Signed dynamic image transforms / EXIF privacy stripping

## Archive

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
*Last updated: 2026-06-10 — b1.0 Brand Foundations opened (brand track, phases 81–85); feature pause unchanged*
