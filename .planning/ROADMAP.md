# Roadmap: Rindle

## Milestones

- **v1.16 CI Enforcement & Planning Hygiene** — Phases 75–77 (gap closure from [v1.15 audit](milestones/v1.15-MILESTONE-AUDIT.md); **execute order: 77 → 76 → 75**)
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

### Phase 75: Merge-Blocking Proof Lanes

**Goal:** Close the v1.15 automated CI proof path gap with a dedicated merge-blocking `proof` job.

**Requirements:** CI-03

**Gap Closure:** Closes CI-01 integration depth, PROOF-06 integration depth, and "Automated CI proof path" flow gap from v1.15 audit.

**Execute after:** Phases 76–77 (TusPlug parity lock and planning truth should land first).

**Success criteria:**

1. New `proof` job in `ci.yml` runs `docs_parity_test.exs` and `batch_owner_erasure_task_test.exs` merge-blocking (`needs: quality`, Postgres, Elixir 1.17/OTP 27).
2. Adopter partial doc grep superseded by full docs parity suite (grep block removed; adopter stays lifecycle-only).
3. `RUNNING.md` CI lane severity matrix documents `proof` as merge-blocking; adopter row no longer claims doc parity.
4. Post-merge checklist mentions branch protection should require `Proof` alongside `package-consumer` and `adopter`.
5. `quality` coveralls/dialyzer/credo remain advisory (Phase 71 policy preserved).

---

### Phase 76: TusPlug Doc Parity Lock

**Goal:** Automate TusPlug moduledoc scope regression lock in `docs_parity_test.exs`.

**Requirements:** TRUTH-05

**Gap Closure:** Closes TRUTH-04 integration depth (moduledoc verified manually only).

**Execute after:** Phase 77; **before** Phase 75 (proof job should include the new parity test).

**Success criteria:**

1. `@tus_extensions` interpolated in `@moduledoc` (single source of truth with OPTIONS header).
2. `docs_parity_test.exs` uses `Code.fetch_docs/1` contract test (token asserts + stale-phrase refutes).
3. `mix test test/install_smoke/docs_parity_test.exs` green with new TusPlug test.
4. Runtime OPTIONS truth remains in `tus_plug_test.exs` (no duplication).

---

### Phase 77: Planning Artifact Cleanup

**Goal:** Close v1.15 post-ship planning truth drift (Nyquist metadata + STATE position block).

**Requirements:** PLAN-01

**Gap Closure:** Closes tech-debt items in phases 71, 72, and STATE.md from v1.15 audit.

**Execute first** (docs-only; zero `ci.yml` conflict).

**Success criteria:**

1. `71-VALIDATION.md` — all task rows ✅ green, sign-off complete, `nyquist_compliant: true`.
2. `72-VALIDATION.md` — `72-01-01` row ✅ green (evidence from `72-VERIFICATION.md`).
3. `.planning/STATE.md` position block reflects shipped v1.15 / between milestones (no `Plan: Not started`).
4. Optional: v1.15 audit tech-debt section updated to reflect closure.

---

### Phase 71: CI Proof Honesty

**Goal:** Document CI lane severity and make highest-signal proof lanes merge-blocking.

**Requirements:** CI-01, CI-02

**Success criteria:**

1. `RUNNING.md` contains a lane severity matrix (blocking vs advisory vs secret-gated soak).
2. `package-consumer` job no longer uses job-level `continue-on-error: true`.
3. `adopter` job no longer uses job-level `continue-on-error: true` (if present).
4. Workflow comments explain why optional soak lanes remain non-blocking.

---

### Phase 72: Mix Batch Failure Proof

**Goal:** Close the v1.14 operator proof gap for partial batch failure via mix task.

**Requirements:** PROOF-06

**Success criteria:**

1. Integration test drives `Mix.Tasks.Rindle.BatchOwnerErasure` through a mid-batch failure.
2. Test asserts partial report printed before exit 1.
3. Test asserts `batch_owner_failed` error message emitted.
4. `mix test test/rindle/batch_owner_erasure_task_test.exs` passes.

---

### Phase 73: Nyquist Validation Closure

**Goal:** Bring phases 68–70 validation artifacts to Nyquist-compliant state.

**Requirements:** VAL-01

**Success criteria:**

1. Phase 68 VALIDATION.md marked Nyquist-compliant or gap-filled.
2. Phase 69 VALIDATION.md marked Nyquist-compliant or gap-filled.
3. Phase 70 VALIDATION.md marked Nyquist-compliant or gap-filled.
4. No open discovery-only Nyquist gaps remain for v1.14 erasure phases.

---

### Phase 74: Support Truth & Milestone Audit

**Goal:** Fix doc drift and close milestone with audit.

**Requirements:** TRUTH-04, AUDIT-01

**Success criteria:**

1. `guides/operations.md` lists all nine shipped mix tasks accurately.
2. `Rindle.Upload.TusPlug` moduledoc scope matches implemented extensions.
3. Milestone audit confirms 6/6 requirements validated.
4. Planning truth (PROJECT, STATE, JTBD-MAP) aligned post-ship.

---

## Deferred to v1.16+ / Later

- Force-delete semantics for still-shared assets (LIFE-06)
- Second streaming provider (Cloudflare/Bunny)
- IETF RUFH / tus 2.0
- GCS-as-tus-backend / R2-native tus proxying
- Rindle-owned standalone tus JS client package
- Richer reusable uploader component abstractions
- Signed dynamic image transforms / EXIF privacy stripping

## Archive

- [.planning/milestones/v1.14-ROADMAP.md](milestones/v1.14-ROADMAP.md)
- [.planning/milestones/v1.14-REQUIREMENTS.md](milestones/v1.14-REQUIREMENTS.md)
- [.planning/milestones/v1.14-MILESTONE-AUDIT.md](milestones/v1.14-MILESTONE-AUDIT.md)

---
*Roadmap created: 2026-05-27 — milestone v1.15*
*Gap closure phases added: 2026-05-27 — milestone v1.16 (from v1.15 audit)*
