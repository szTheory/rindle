---
gsd_state_version: 1.0
milestone: v1.23
milestone_name: Postgres Schema Isolation
current_phase: 120
current_phase_name: Adoption Proof & Release Truth
status: planning
stopped_at: Phase 119 context gathered (assumptions mode)
last_updated: "2026-08-10T02:49:28.459Z"
last_activity: 2026-08-09
last_activity_desc: Phase 119 complete, transitioned to Phase 120
progress:
  total_phases: 4
  completed_phases: 3
  total_plans: 16
  completed_plans: 16
  percent: 75
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-07-02 after shipping v1.22)

**Core value:** Media, made durable.
**Current focus:** Phase 119 — ownership-boundaries-diagnostics

## Current Position

Phase: 120 — Adoption Proof & Release Truth
Plan: Not started
Status: Ready to plan
Last activity: 2026-08-09 — Phase 119 complete, transitioned to Phase 120

### v1.22 shipped summary

v1.22 OSS Quality & Trust Hardening shipped 2026-07-02 and is archived at
`.planning/milestones/v1.22-ROADMAP.md`, `.planning/milestones/v1.22-REQUIREMENTS.md`, and
`.planning/milestones/v1.22-MILESTONE-AUDIT.md`. It satisfied 14/14 requirements across Phases 113–116:
EVAL/HYGIENE release truth, OSS governance and Hex metadata trust signals, versioning/README positioning,
and the non-breaking versioned `Rindle.Migration` substrate with host-owned Oban setup.

**Hard invariants (carry from v1.20/v1.21, highest blast radius):** never rename `ci.yml` / `name: CI`
(release-train coupling via `release-please-automerge.yml` + `gate-ci-green`); `CI Summary` keeps
`skipped`==pass and stays the sole required check; never weaken the release full-verification gate. The
MIGRATE phase (116) is the only one that touches `lib/` + `priv/` and must keep the existing test suite
green (135 test files; the async-safety meta-test governs `async: true`).

## Next Step

Discuss and plan Phase 118 before execution. Its plan must pair Phase 117's compile-time `rindle`/
`public` routing authority with idempotent selected-schema provisioning and a host-owned, bounded
public-to-`rindle` move for the six Rindle tables plus `rindle_migration_versions`.

## Prior Milestone

**v1.21 CI/DX Reliability Tail** (SEED-004) — shipped 2026-06-29, archived at
`milestones/v1.21-ROADMAP.md`. Non-feature/DX milestone making the merge gate deterministic and
trustworthy — a green PR reliably means a green `main`. 24/24 requirements across 5/5 verified phases
(108–112): single-run coverage (COV-01..04), subprocess `:epipe` hardening + invariant-13 truth
correction (EPIPE-01..05, TRUTH-01), `$callers`-aware process-scoped repo override (ISO-01..05), five
shipped-artifact regression-lock meta-tests (LOCK-01..05), and the lean `adoption-demo-e2e-smoke` PR lane
wired into `CI Summary` LAST (GATE-01..04).

> **Release-state reconciliation:** the two v1.21 `lib/` `fix:` patches are now live as Hex **0.3.2**.
> v1.22 Phase 113 (HYGIENE-01) rotated the expired release token, unstuck release-please, cut the release,
> and reconciled the planning claim against live Hex state.

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

_(none)_

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

- **HYGIENE-01 release-please investigation:** at charter, Hex live was 0.3.1 with no `release rindle
  0.3.2` commit and no open release-please PR. Phase 113 resolved it: Hex 0.3.2 is live, the release-train
  notes are reconciled, and the remaining durable improvement is an Actions-capable release token or GitHub
  App token.

### Next milestone after v1.22

**v1.23 Postgres Schema Isolation** (breaking → 0.4.0): `rindle` schema default via config-driven
`@schema_prefix`; 4 manual escapes (2 raw-SQL `runtime_checks.ex` + 2 Oban-binding queries); one-line
`prefix: "public"` opt-out + `ALTER TABLE … SET SCHEMA` move migration. Re-charter from the ISO23 notes in
the v1.22 requirements archive. Builds on the v1.22 `Rindle.Migration` substrate.

### v1.23 roadmap (2026-08-08)

- Phase 117 decides and proves the single routing architecture for the default `rindle` prefix and
  explicit `public` compatibility; it is intentionally first because Ecto schema-prefix configuration
  and runtime routing cannot be mixed casually.

- Phase 118 provisions the selected schema and performs the narrow, data-preserving public-to-`rindle`
  move for only the six Rindle tables plus `rindle_migration_versions`.

- Phase 119 hardens the manual raw-SQL/catalog/Oban boundaries and exposes separate-prefix diagnostics
  through doctor and runtime status.

- Phase 120 proves the full breaking contract in packed generated applications, Cohort, docs parity,
  and 0.4.0 release truth.

## Decisions

_(Key v1.22 execution decisions recorded at milestone close.)_

- [Phase 113]: EVAL-01 — v1.22-OSS-QUALITY-EVAL.md authored; weakness→closing-phase column mapped byte-faithful to REQUIREMENTS.md (governance→114, versioning/README→115, host-respect→116, schema-flip→v1.23 ISO23); scores lifted from SEED-005, not re-derived.
- [Phase 113]: HYGIENE-02 — SEED-003/004 frontmatter corrected status: open→consumed with consumed:/consumed_by: attribution (D-14).
- [Phase ?]: D-08: harden public_smoke.sh junit write path via env -u CI on the install-smoke shell-out (option c) so abnormal exits stay legible
- [Phase ?]: D-07: recorded the CORRECTED stuck-release root cause (PR #40 = the 0.3.1 PR; fixes merged 2026-06-28; run 28399407429 401'd on expired RELEASE_PLEASE_TOKEN) in runbook + ledger; refuted the superseded PR-#40-was-0.3.2 framing
- [Phase ?]: [Phase 113]: HYGIENE-01 — Hex 0.3.2 cut live (run 28420598348, merge d228b67) after a THREE-fix unstick (rotate expired RELEASE_PLEASE_TOKEN + relabel #40 pending->tagged + manual publish-dispatch since PAT lacked Actions:write); D-12 honored — live-truth edits committed only after publish observed. Durable fix pending: add Actions:write to PAT or move to GitHub App token.
- [Phase 114]: Phase 114 Plan 01 kept governance artifacts repo-only and did not touch mix.exs or package metadata scope.
- [Phase 114]: Phase 114 Plan 02 verifies META-02 maintainers from Hex owner-derived public API data because Hex 2.5 unpacked tarball metadata does not serialize `:maintainers` for this package. — Preserves the maintainer trust signal while keeping generated metadata assertions focused on links that Hex emits locally.
- [Phase 115]: Phase 115 stayed docs-only with no runtime, migration API, release-version, dependency, CSS, or JS changes. — The plan and phase context scoped this as README, CONTRIBUTING, upgrading guide, and docs parity work only.
- [Phase 115]: guides/upgrading.md is the reusable action-oriented upgrade home; CHANGELOG.md remains release history. — This closes VERSION-02 and gives Phase 116 a versioned docs structure for migration upgrade notes.
- [Phase 115]: README first-run onboarding now leads with an original-only image attachment path before AV setup. — This closes README-01 while keeping FFmpeg/libvips dependency details linked from RUNNING.md.
- [Phase 116]: Plan 116-02 stayed RED-only and used injected doctor/runtime readiness fixtures to lock hybrid migration health before implementation. — The phase plan requires failing tests first for marker/catalog/legacy/Oban readiness semantics.
- [Phase 116]: Plan 116-03 stayed RED-only and locked docs/generated-app migration ownership before implementation. — Docs parity now requires pinned Rindle.Migration host snippets and generated-app proof now expects separate host-owned Oban.Migration plus Rindle.Migration files with no Rindle-created oban_jobs.
- [Phase 116]: Plan 04 implemented Rindle.Migration with validated :version/:prefix options and hidden V1 DDL helpers. — Keeps the fresh-install API public while preserving helper modules as internal implementation.
- [Phase 116]: The legacy CreateObanTables migration filename remains packaged as a no-op compatibility stub. — Preserves legacy schema_migrations history while removing Rindle authority over host-owned job storage.
- [Phase 116]: Doctor readiness now separates Rindle-owned schema readiness from host-owned Oban readiness.
- [Phase 116]: Runtime status returns setup_incomplete before report queries touch missing Rindle or Oban tables.
- [Phase 116]: Public install docs now teach normal host migrations: host-owned Oban.Migration for oban_jobs and pinned Rindle.Migration for Rindle-owned tables.
- [Phase 116]: Legacy package-directory migration replay remains documented only in the historical 0.1.3-and-earlier upgrade path.
- [Phase 116]: Troubleshooting treats missing oban_jobs as host-owned Oban setup, not as a Rindle migration responsibility.
- [Phase 116]: Plan 116-07 closed Phase 116 with focused tests, generated-app image smoke, mix ci, release-train audit, and schema-push audit all passing. — Final evidence for MIGRATE-01 and MIGRATE-02: no workflow diffs, no configured schema-push path matches, and direct key-link grep proves the pinned README/generated-app migration pattern.
- [Phase ?]: Phase 117 Plan 01: all six Rindle-owned schemas use a validated compile-time Rindle.Schema prefix; only rindle and public are supported, while Oban stays independent.
- [Phase ?]: Phase 117 Plan 02: Prefix isolation tests use public as the selected compatibility build and rindle as the decoy until Phase 118 provisions rindle.
- [Phase ?]: Phase 117 Plan 02: AST contract tests prohibit owned schemas from bypassing Rindle.Schema with direct Ecto.Schema or @schema_prefix.
- [Phase ?]: Phase 117 Plan 03: Rindle.Schema binds its compiled prefix before consumer expansion and rejects final Ecto metadata mutations after compilation.
- [Phase ?]: Phase 117 Plan 03: Runtime application-env changes cannot retarget Rindle schema metadata; Oban remains host-owned and independent.
- [Phase ?]: Rindle.Schema.schema/2 reasserts the compiled prefix at declaration time; after-compile validation is defense in depth for raw Ecto declarations.
- [Phase ?]: Rindle.Schema is internal to the six owned domain schemas; validate macro callers before emitting Ecto setup.
- [Phase ?]: Phase 118 Plan 01: approved rindle as the migration default; only explicit public compatibility remains supported.
- [Phase ?]: Approved D-118-06: transactional fixed public-to-rindle ALTER TABLE move after complete preflight.
- [Phase ?]: 118-02 pins move_public_to_rindle/1 to version: 1 and excludes generic schema moves.
- [Phase ?]: Approved D-118-08 guarded move_rindle_to_public/1 for quiesced, exactly reversible host migration down paths; it never drops rindle or calls destructive down/1.
- [Phase ?]: Phase 118 Plan 04 locks the rindle default, public-only compatibility pairing, and host-owned maintenance-window upgrade contract in docs parity.

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

## Session Continuity

Last session: 2026-08-10T01:01:39.227Z
Stopped at: Phase 119 context gathered (assumptions mode)
Resume file: .planning/phases/119-ownership-boundaries-diagnostics/119-CONTEXT.md

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 113 P01 | 2 | 2 tasks | 3 files |
| Phase 113 P02 | 5min | 3 tasks | 4 files |
| Phase 113 P03 | ~2m | 2 tasks | 3 files |
| Phase 113 P04 | ~3min | 2 tasks | 5 files |
| Phase 114 P01 | 4 min | 3 tasks | 7 files |
| Phase 114 P02 | 4 min | 1 tasks | 3 files |
| Phase 115 P01 | 6 min | 3 tasks | 4 files |
| Phase 116 P01 | 4 min | 2 tasks | 3 files |
| Phase 116 P02 | 6 min | 2 tasks | 4 files |
| Phase 116 P03 | 9 min | 2 tasks | 3 files |
| Phase 116 P04 | 8 min | 3 tasks | 4 files |
| Phase 116 P05 | 11 min | 2 tasks | 4 files |
| Phase 116 P06 | 10 min | 3 tasks | 5 files |
| Phase 116 P07 | 5 min | 2 tasks | 1 files |
**Per-Plan Metrics:**

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 117 P01 | 4 min | 2 tasks | 12 files |
| Phase 117 P02 | 3 min | 3 tasks | 3 files |
| Phase 117 P03 | 4min | 2 tasks | 3 files |
| Phase 117 P04 | 3 min | 2 tasks | 2 files |
| Phase 117 P05 | 7min | 2 tasks | 3 files |
| Phase 118 P01 | 18 min | 2 tasks | 6 files |
| Phase 118 P02 | 31 min | 2 tasks | 5 files |
| Phase 118 P03 | 15 min | 2 tasks | 5 files |
| Phase 118 P04 | ~13 min | 2 tasks | 5 files |

## Operator Next Steps

- Start the next milestone with /gsd-new-milestone
