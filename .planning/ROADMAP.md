# Roadmap: Rindle

## Milestones

- **v1.17 Adopter-Confidence Hygiene** — Phases 78–80 (shipped 2026-05-27); ready for milestone archive
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

### Phase 78: Assessment & Planning Truth

**Goal:** Adopters and maintainers read one honest CI/planning story with no stale assessment drift.

**Depends on:** v1.16 shipped

**Requirements:** TRUTH-06, PLAN-02

**Success criteria:**

1. Post-v116 assessment thread has zero phrases contradicting `ci.yml` on coveralls/proof severity
2. Path-to-done roadmap cross-references match assessment thread after edits
3. JTBD-MAP anchor reflects v1.16 shipped boundary (verified, not assumed)
4. PROJECT.md and STATE.md describe v1.17 charter and v1.18+ demand gates consistently

**Plans:** 2/2 plans complete

- [x] 78-01: TRUTH-06 thread truth (assessment + path-to-done)
- [x] 78-02: PLAN-02 JTBD anchor + charter alignment + verification closure

---

### Phase 79: CI Static-Analysis Policy Closure

**Goal:** Close the deferred Credo/Dialyzer severity decision with documented rationale.

**Depends on:** Phase 78

**Requirements:** CI-04

**Success criteria:**

1. RUNNING.md records explicit Credo and Dialyzer severity (merge-blocking or advisory)
2. `ci.yml` comments match RUNNING.md; no matrix row contradicts live wiring
3. Assessment thread "Open concerns" section reflects the recorded decision (not "deferred")
4. No new public API or `lib/` changes required to satisfy CI-04

**Plans:** 2/2 plans complete

- [x] 79-01: RUNNING.md CI-04 policy + ci.yml comment alignment
- [x] 79-02: Thread closure + REQUIREMENTS/STATE/ROADMAP traceability + verification gate

---

### Phase 80: Post-Ship Planning Hygiene

**Goal:** Align planning threads and charter artifacts with v1.17 shipped reality so maintainers read one honest post-ship story before milestone archive.

**Depends on:** Phase 79 (v1.17 audit complete)

**Requirements:** None (tech-debt closure from [v1.17 audit](milestones/v1.17-MILESTONE-AUDIT.md))

**Gap Closure:** Closes post-ship narrative drift flagged in audit `tech_debt.planning-hygiene`

**Success criteria:**

1. Path-to-done thread uses past/shipped tense for Branch C and v1.17; no "remains Phase 79" or "active/current" labels for completed work
2. Assessment thread "Active micro milestone" section reflects v1.17 shipped (not in-flight)
3. PROJECT.md moves TRUTH-06, PLAN-02, CI-04 from Active to Validated; Active section reflects demand-gated pause
4. STATE.md Current Position shows Phase 80 (or completed) with accurate Plan status — no stale "Plan: Not started" for Phase 79
5. Grep audit: zero "Branch C (selected — active)" / "Active micro milestone" / "remains Phase 79" in thread files

**Plans:** 2/2 plans complete

- [x] 80-01: Thread post-ship tense alignment (path-to-done + assessment)
- [x] 80-02: PROJECT/STATE charter cleanup + verification gate

---

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

## Deferred to v1.18+ / Later

- Force-delete semantics for still-shared assets (LIFE-06) — compliance pull only
- Second streaming provider (Cloudflare/Bunny) — explicit adopter demand only
- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Richer reusable uploader component abstractions
- Signed dynamic image transforms / EXIF privacy stripping

## Archive

- [.planning/milestones/v1.16-ROADMAP.md](milestones/v1.16-ROADMAP.md)
- [.planning/milestones/v1.16-REQUIREMENTS.md](milestones/v1.16-REQUIREMENTS.md)
- [.planning/milestones/v1.15-MILESTONE-AUDIT.md](milestones/v1.15-MILESTONE-AUDIT.md)
- [.planning/milestones/v1.14-ROADMAP.md](milestones/v1.14-ROADMAP.md)
- [.planning/milestones/v1.14-REQUIREMENTS.md](milestones/v1.14-REQUIREMENTS.md)
- [.planning/milestones/v1.14-MILESTONE-AUDIT.md](milestones/v1.14-MILESTONE-AUDIT.md)

---
*Last updated: 2026-05-27 — Phase 80 complete (v1.17 post-ship planning hygiene)*
