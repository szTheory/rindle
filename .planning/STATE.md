---
gsd_state_version: 1.0
milestone: v1.24
milestone_name: Core Clarity & Quality Ratchet
current_phase: 126
current_phase_name: curated-type-ratchet
status: complete
stopped_at: Completed 126-10-PLAN.md (local metadata non-authority)
last_updated: "2026-08-23T16:02:37Z"
last_activity: 2026-08-23
last_activity_desc: Planned bounded TYPE-02 removal-only policy gap closure
progress:
  total_phases: 6
  completed_phases: 5
  total_plans: 40
  completed_plans: 40
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-22 for v1.24)

**Core value:** Media, made durable.
**Current focus:** Phase 126 — curated-type-ratchet

## Current Position

Phase: 126 (curated-type-ratchet) — COMPLETE
Plan: 10 of 10
Status: TYPE-02 gap closed by exact-head authorities
Last activity: 2026-08-23 — Planned bounded TYPE-02 removal-only policy gap closure

### v1.24 charter

Finite, behavior-preserving maintenance only: restore truthful quality signals, remove live planning
residue and a schema compile cycle, decompose enumerated core hotspots, rebuild oversized/self-inspecting
test support, reconcile async-isolation evidence, and retire the curated Dialyzer baseline. No public
contract, data-model, telemetry, error-vocabulary, admin-feature, dependency-major, or forced-release
scope is approved.

### v1.23 shipped summary

v1.23 Postgres Schema Isolation shipped 2026-08-20 and is archived at
`.planning/milestones/v1.23-ROADMAP.md`, `.planning/milestones/v1.23-REQUIREMENTS.md`, and
`.planning/milestones/v1.23-MILESTONE-AUDIT.md`. It satisfied 12/12 requirements across four verified
phases (117–120) and released Hex 0.4.0 from frozen source `78349c1…`: default `rindle` ownership,
explicit-public compatibility, bounded populated-install migration/reversal, independent Oban ownership,
bounded diagnostics, and packed/Cohort/public-artifact proof.

**Hard invariants (carry from v1.20/v1.21, highest blast radius):** never rename `ci.yml` / `name: CI`
(release-train coupling via `release-please-automerge.yml` + `gate-ci-green`); `CI Summary` keeps
`skipped`==pass and stays the sole required check; never weaken the release full-verification gate. The
release-docs parity test now derives the active version from the manifest while separately preserving
the historical 0.4.0 contract; do not regress either side of that invariant.

## Next Step

Phase 126 complete; metadata is local-only and non-authoritative.

## Prior Milestone

**v1.22 OSS Quality & Trust Hardening** — shipped 2026-07-02 and archived at
`milestones/v1.22-ROADMAP.md`. It delivered the versioned `Rindle.Migration` and host-owned Oban boundary
that v1.23 extended into the breaking schema-isolation contract.

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

- [Phase 121]: v1.24 roadmap order is locked: restore truthful signals and establish SAFE-01 first;
  reconcile live truth and remove the schema compile cycle next; then decompose runtime operations,
  upload paths, and test support; retire the curated Dialyzer baseline last. The whole milestone preserves
  public API, schema/migration, telemetry, error-shape, CI/release, and supported behavior contracts.

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
- [Phase ?]: Phase 120 Plan 01 derives its fixed schema-qualified Rindle relation catalog from Rindle.Migration.V1.owned_relations/0 and keeps policy assertions in repository ExUnit.
- [Phase ?]: Cohort now owns distinct pinned Oban and default Rindle host migrations; all active setup paths run normal ecto.migrate.
- [Phase ?]: Release Please must promote the sole Unreleased / 0.4.0 staging block into generated [0.4.0] notes and remove the marker.
- [Phase ?]: Exact-SHA CI and Release workflow gates authorize 0.4.0; local package/demo/Cohort checks remain diagnostic.
- [Phase ?]: Phase 120 Plan 10: generated reports no longer project host migration provenance as Oban evidence; complete catalog snapshot equality is the sole preservation decision.
- [Phase 122]: Rindle.Schema uses a closed canonical caller-name allowlist with fail-closed validation, removing reverse compile references while retaining macro, prefix, and callback contracts.
- [Phase ?]: Docs parity support is read-once mechanics only; install/migration assertions are domain-owned.
- [Phase ?]: Docs parity assigns adopter onboarding and maintainer operations to separate read-once domain suites.
- [Phase ?]: Proof now explicitly executes the four docs-parity domains in one unchanged topology step.
- [Phase ?]: Issue #42 remains open because its sole authorized matrix attempt completed only 1/25 runs; exact-head CI cannot override incomplete local evidence.
- [Phase ?]: Phase 126 Plan 01: Nightly Elixir 1.17 / OTP 27 is the sole Dialyzer acceptance authority; local output remains diagnostic.
- [Phase ?]: Phase 126 Plan 01: E38-E40 stay pending after exact-head supported CI emitted the unchanged tus_plug warnings.
- [Phase ?]: Migration Ecto callback and intentional-raise warnings remain exact supported analyzer-noise filters.
- [Phase ?]: E09, E10, and E24 remain exact supported analyzer-noise filters to preserve task output, Admin fallback, and runtime diagnostics.
- [Phase ?]: E04-E07 remain exact supported analyzer-noise filters because their fallback clauses preserve optional HTML, runtime diagnostics, and ProcessVariant lifecycle behavior.
- [Phase ?]: Intermediate exact-head Nightly acceptance remains the complete E38-E40 TUS-only multiset with Dialyzer failure and Nightly Summary success.
- [Phase ?]: GCS and Local stream warnings remain exact supported filters when bounded streams, tagged errors, cleanup, or opaque dependency boundaries make a behavior-preserving correction unsafe.
- [Phase ?]: GCS collapsed the duplicate private auth-error pattern; E26 remains exact supported analyzer noise because the broker-exercised resumable URL mode stays inferred unreachable on the home cell.
- [Phase ?]: S3 stream and tail warnings remain exact supported analyzer-noise filters because the accepted home cell proves bounded stream, tagged-error, ordered-slicing, and cleanup paths are reachable.
- [Phase ?]: Intermediate exact-head Nightly acceptance remains E38-E40 only, with Dialyzer failure honestly surfaced by Nightly Summary success.
- [Phase ?]: E38-E40 preserve immutable tus_plug filter history separately from extracted creation/stream owners; all five Tus/Mux candidates are actionable-fixed on supported Nightly.
- [Phase ?]: E01-E03 are obsolete only after the source-unchanged supported probe emitted no matching facade/Broker/PromoteAsset warnings.
- [Phase ?]: E08 removes only an unreachable private PromoteAsset fallback; the four retained atom filters are E04-E07.
- [Phase ?]: Phase 126 Plan 09: exact-head Nightly 1.17/27 Dialyzer, Nightly Summary, and PR CI Summary accepted candidate a36cd146; issue #76 closed only after all 45 dispositions qualified.

## Blockers/Concerns

- Phase 126 TYPE-02 remains open after adversarial verification: the current policy accepts a new nonblank strict description for an existing owner. Plan 126-10 is the bounded test-only closure; issue #76 remains open until corrected exact-head authorities pass.

## Deferred Items

| Category | Item | Status |
|----------|------|--------|
| lifecycle | Force-delete policy (LIFE-06) | demand-gated (compliance ticket) |
| streaming | Second provider (Cloudflare/Bunny) | demand-gated (named adopter) |
| testing | `mix test --partitions` parallelization | evidence-gated on measured core-starvation (DEFER-02) |
| tus | IETF RUFH / tus 2.0; GCS-as-tus-backend; standalone tus JS client; richer uploader abstractions | deferred / out of scope |
| polish | Signed dynamic image transforms (TRANS-01); EXIF privacy stripping (PRIV-01) | deferred |

## Session Continuity

Last session: 2026-08-23T15:52:07.553Z
Stopped at: Completed 126-09-PLAN.md
Resume file: None

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
| Phase 120 P01 | 5 min | 2 tasks | 2 files |
| Phase 120 P03 | 8m | 3 tasks | 12 files |
| Phase 120 P06 | 4h 18m | 2 tasks | 3 files |
| Phase 120 P10 | 8m | 1 tasks | 2 files |
| Phase 122 P01 | 12 min | 2 tasks | 4 files |
| Phase 125-behavioral-test-support P07 | 27min | 2 tasks | 3 files |
| Phase 125-behavioral-test-support P08 | 24min | 2 tasks | 3 files |
| Phase 125-behavioral-test-support P09 | 16min | 2 tasks | 4 files |
| Phase 125 P10 | 45min | 2 tasks | 8 files |
| Phase 126 P01 | ~15 min | 2 tasks | 2 files |
| Phase 126-curated-type-ratchet P02 | 45 min | 3 tasks | 4 files |
| Phase 126 P03 | 31min | 2 tasks | 2 files |
| Phase 126 P04 | 14min | 2 tasks | 3 files |
| Phase 126 P05 | 19min | 2 tasks | 3 files |
| Phase 126 P06 | 13min | 2 tasks | 3 files |
| Phase 126 P07 | 47min | 2 tasks | 7 files |
| Phase 126 P08 | 15min | 2 tasks | 4 files |
| Phase 126 P09 | 24min | 2 tasks | 3 files |
| Phase 126 P10 | planned | 2 tasks | 1 implementation file |

## Operator Next Steps

- Execute only the Phase 126 gap closure with `/gsd-execute-phase 126 --gaps-only`; do not start a demand-gated milestone until TYPE-02 is reverified.
