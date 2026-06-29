---
gsd_state_version: 1.0
milestone: v1.22
milestone_name: OSS Quality & Trust Hardening
current_phase: 113
current_phase_name: roadmap created — ready to plan Phase 113
status: planning
stopped_at: Phase 113 context gathered
last_updated: "2026-06-29T23:26:53.075Z"
last_activity: 2026-06-29
last_activity_desc: v1.22 ROADMAP.md created
progress:
  total_phases: 1
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-06-29 after chartering v1.22)

**Core value:** Media, made durable.
**Current focus:** Phase 113 — Evaluation Baseline & Release Hygiene (roadmap created, ready to plan)

## Current Position

Phase: Not started (roadmap created — ready to plan Phase 113)
Plan: —
Status: Roadmap created — 14/14 v1.22 requirements mapped across 4 phases (113–116)
Last activity: 2026-06-29 — v1.22 ROADMAP.md created

### v1.22 roadmap (Phases 113–116) — natural-grouping order

Chartered 2026-06-29 from SEED-005, the non-feature signal for the two-milestone software-quality
consolidation arc (v1.22 trust hardening → v1.23 Postgres schema isolation). Phase numbering continues
from v1.21's Phase 112. Non-feature/DX milestone; ships a **0.3.x minor** (0.4.0 reserved for v1.23's
breaking schema isolation). Low risk, mostly-independent requirements — phases group naturally rather
than form a deep dependency chain. Two ordering notes are load-bearing: the time-sensitive release
unstick (HYGIENE-01) lands EARLY (Phase 113) to reach adopters; the versioned `Rindle.Migration`
substrate (the only real code change, the v1.23 foundation) lands LAST (Phase 116) so its install/upgrade
docs converge with the 115 README/VERSION work.

- **Phase 113 — Evaluation Baseline & Release Hygiene** (EVAL-01, HYGIENE-01, HYGIENE-02): the
  milestone's opening artifact — a concise, evidence-cited scored-weakness summary (right-sized, not
  the full 36-dimension report). Cut the stuck Hex **0.3.2** release so the merged-but-unreleased v1.21
  `lib/` fixes (`:epipe` absorb, `$callers` config override) reach adopters — and investigate WHY
  release-please never opened a 0.3.2 PR (Hex live = 0.3.1). Reconcile PROJECT.md / MILESTONES "ships as
  Hex 0.3.2" aspirational prose with reality. Fix stale SEED-003 / SEED-004 `status: open` → `consumed`.

- **Phase 114 — OSS Trust & Governance** (TRUST-01..03, META-01..02): `SECURITY.md`
  (untrusted-uploads/MIME-sniffing/signed-delivery/webhook-HMAC disclosure policy), `CODE_OF_CONDUCT.md`,
  `.github/ISSUE_TEMPLATE/` + `PULL_REQUEST_TEMPLATE.md` newcomer on-ramp, and Hex `package.links`
  "Changelog"/"Docs" + `maintainers`. Doc/metadata only; no `lib/` change.

- **Phase 115 — Versioning & README Positioning** (VERSION-01..02, README-01..02): stated SemVer/pre-1.0
  stability contract (README + CONTRIBUTING) + what 1.0 will mean; generalize `guides/upgrading.md` into a
  reusable versioned-sections structure; lead the README with an image-only "first attachment in ~2
  minutes" path (demote the FFmpeg/libvips-heavy AV quickstart) + a "what Rindle is NOT / when not to use"
  block lifted from `guides/user_flows.md`. Docs only; no `lib/` change.

- **Phase 116 — Versioned `Rindle.Migration` Module** (MIGRATE-01..02): the only real code change. Ship a
  versioned, idempotent, Oban-style `Rindle.Migration.up/1` + `down/1` replacing the raw 15-file
  `Ecto.Migrator` copy-paste install path (README/getting-started/upgrading show the new ~3-line
  migration); stop creating the shared `oban_jobs` table (adopter owns `Oban.Migration`). **Non-breaking**
  — default schema stays `public`, existing adopters' applied migrations stay valid. This is the
  load-bearing foundation v1.23 builds the schema prefix onto. Touches `lib/` + `priv/`; doctor /
  runtime_status migration-inspection must keep working alongside legacy 15-file installs.

**Hard invariants (carry from v1.20/v1.21, highest blast radius):** never rename `ci.yml` / `name: CI`
(release-train coupling via `release-please-automerge.yml` + `gate-ci-green`); `CI Summary` keeps
`skipped`==pass and stays the sole required check; never weaken the release full-verification gate. The
MIGRATE phase (116) is the only one that touches `lib/` + `priv/` and must keep the existing test suite
green (135 test files; the async-safety meta-test governs `async: true`).

## Next Step

**Plan Phase 113 (Evaluation Baseline & Release Hygiene):** `/gsd-plan-phase 113`. It is the milestone's
opening phase and carries the one time-sensitive, independent item — cutting the stuck Hex 0.3.2 release
so adopter-facing v1.21 `lib/` fixes reach adopters. EVAL-01 (the scored-weakness summary) is the opening
artifact that becomes the prioritized work list for Phases 114/115. HYGIENE-01 must investigate why
release-please did not open a 0.3.2 PR (reference: `reference_release_please_autopublish` — a merged
release PR stuck on `autorelease: pending` blocks auto-publish). The remaining phases follow:
governance/metadata (114) → positioning/docs (115) → `Rindle.Migration` LAST (116) so its docs converge
with the 115 README/VERSION work.

## Recently Shipped Milestone

**v1.21 CI/DX Reliability Tail** (SEED-004) — shipped 2026-06-29, archived at
`milestones/v1.21-ROADMAP.md`. Non-feature/DX milestone making the merge gate deterministic and
trustworthy — a green PR reliably means a green `main`. 24/24 requirements across 5/5 verified phases
(108–112): single-run coverage (COV-01..04), subprocess `:epipe` hardening + invariant-13 truth
correction (EPIPE-01..05, TRUTH-01), `$callers`-aware process-scoped repo override (ISO-01..05), five
shipped-artifact regression-lock meta-tests (LOCK-01..05), and the lean `adoption-demo-e2e-smoke` PR lane
wired into `CI Summary` LAST (GATE-01..04).

> **Release-state note carried into v1.22:** the two v1.21 `lib/` `fix:` patches are merged to `main`
> but **0.3.2 was never published** (Hex live = 0.3.1; `mix.exs` / manifest / CHANGELOG all = 0.3.1; no
> open release-please PR). The "ships as Hex 0.3.2" prose is aspirational. **v1.22 Phase 113 (HYGIENE-01)
> cuts the stuck release and reconciles the claim.**

<details>
<summary>v1.21 roadmap (Phases 108–112) — shipped, load-bearing order (collapsed)</summary>

Chartered 2026-06-26 from SEED-004 + the 2026-06-26 flake cluster. Ships Hex **0.3.2** via two
adopter-invisible `lib/` `fix:` patches (D-v1.21-01). The order was research-locked: de-flake (108
coverage single-run → 109 `:epipe` hardening → 110 async-isolation) → lock (111 regression locks) →
shift-left LAST (112 PR↔main gate). All hard release-coupling invariants held.

</details>

<details>
<summary>v1.20 roadmap (Phases 103–107) — shipped, load-bearing order (collapsed)</summary>

Chartered 2026-06-20 from SEED-003. Non-feature / DX-infrastructure milestone — ZERO `lib/` public-API
change. Order: observability (103) → cache & tooling (104) → aggregate required check + branch-protection
flip (105) → trigger split + lane refinement (106) → reliability/security/DX hardening (107). All hard
release-coupling invariants held.

</details>

## Accumulated Context

### Pending Todos

- [2026-06-19] Fix Docker demo startup warnings — `./scripts/demo/up.sh` logs missing Mox warnings from `AdoptionDemo.MuxCassette` and missing `inotify-tools` / `fs_inotify_bootstrap_error` for Phoenix live-reload inside the Cohort demo container. (Carried across v1.20/v1.21; outside both scopes; future DX milestone.)

### v1.22 charter context (carried from SEED-005 + recon, 2026-06-29)

- **Two false premises corrected in recon:** (1) szTheory dep bumps → **empty** (Rindle depends on zero
  szTheory-owned packages); (2) CI/CD performance → **already done** by v1.20 + v1.21 (the pasted audit
  prompt *is* SEED-003). Only deferred CI lever is `mix test --partitions`, gated on measured core-starvation.

- **Weak dimensions the recon found (5=strong):** OSS governance/trust 2/5 (→ Phase 114), versioning/
  path-to-1.0 2/5 + README positioning 2.5/5 (→ Phase 115), host-app respectfulness 3.5/5 whose one real
  gap is the Postgres schema issue (→ the `Rindle.Migration` substrate in Phase 116, then v1.23's flip).
  Already-strong, left alone: telemetry 5/5, docs/ExDoc IA 4.5/5, public API + `Rindle.Error` 4/5, CI/testing.

- **`Rindle.Migration` is pulled into v1.22 (not v1.23) deliberately** — a "good-guest" fix in its own
  right that de-risks the v1.23 breaking schema flip. Full arc: SEED-005 +
  `/Users/jon/.claude/plans/software-quality-evaluation-prompt-txt-gleaming-sifakis.md`.

- **HYGIENE-01 release-please investigation:** Hex live = 0.3.1, no `release rindle 0.3.2` commit, no open
  release-please PR. See `reference_release_please_autopublish` — green main auto-publishes; a release PR
  stuck on `autorelease: pending` stalls it (relabel to `tagged`). Pre-1.0 `feat:` → patch bump.

### Next milestone after v1.22

**v1.23 Postgres Schema Isolation** (breaking → 0.4.0): `rindle` schema default via config-driven
`@schema_prefix`; 4 manual escapes (2 raw-SQL `runtime_checks.ex` + 2 Oban-binding queries); one-line
`prefix: "public"` opt-out + `ALTER TABLE … SET SCHEMA` move migration. Requirements ISO23-01..04 tracked
in REQUIREMENTS.md (Future Requirements section). Builds on the v1.22 `Rindle.Migration` substrate.

## Decisions

_(v1.22 phase-execution decisions accumulate here as phases are planned and executed.)_

## Blockers/Concerns

_(none open for v1.22 at roadmap creation)_

## Deferred Items

| Category | Item | Status |
|----------|------|--------|
| schema | Postgres schema isolation / `@schema_prefix` default flip (ISO23-01..04) | v1.23 (0.4.0 breaking); builds on v1.22 `Rindle.Migration` substrate |
| lifecycle | Force-delete policy (LIFE-06) | demand-gated (compliance ticket) |
| streaming | Second provider (Cloudflare/Bunny) | demand-gated (named adopter) |
| testing | `mix test --partitions` parallelization | evidence-gated on measured core-starvation (DEFER-02) |
| tus | IETF RUFH / tus 2.0; GCS-as-tus-backend; standalone tus JS client; richer uploader abstractions | deferred / out of scope |
| polish | Signed dynamic image transforms (TRANS-01); EXIF privacy stripping (PRIV-01) | deferred |
| tooling | `2026-06-19-fix-docker-demo-startup-warnings.md` todo | deferred — Cohort demo Docker startup warnings (Mox compile warnings + `inotify-tools` live-reload); cosmetic; future DX milestone |

## Session Continuity

Last session: 2026-06-29T23:26:53.065Z
Stopped at: Phase 113 context gathered
Resume file: .planning/phases/113-evaluation-baseline-release-hygiene/113-CONTEXT.md
