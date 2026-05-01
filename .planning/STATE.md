---
gsd_state_version: 1.0
milestone: v1.3
milestone_name: Live Publish & API Ergonomics
status: ready
stopped_at: Completed 22-01-PLAN.md
last_updated: "2026-05-01T21:21:24Z"
last_activity: 2026-05-01
progress:
  total_phases: 8
  completed_phases: 5
  total_plans: 20
  completed_plans: 15
  percent: 75
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-29)

**Core value:** Media, made durable.
**Current focus:** Phase 21 — hexdocs reachability probe

## Current Position

Phase: 21
Plan: Not started
Status: Phase 22 complete; milestone in progress
Last activity: 2026-05-01

Progress: [███████░░░] 75%

## Performance Metrics

**Velocity:**

- Total plans completed: 20 (v1.3)
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 17 | 5 | - | - |
| 19 | 2 | - | - |
| 20 | 3 | - | - |
| 22 | 1 | - | - |

*Updated after each plan completion*
| Phase 17 P01 | 7min | 2 tasks | 2 files |
| Phase 17 P02 | 4min | 2 tasks | 15 files |
| Phase 17 P03 | 2min | 2 tasks | 12 files |
| Phase 17 P05 | 4min | 2 tasks | 13 files |
| Phase 17-api-surface-boundary-audit P04 | 5min | 2 tasks | 8 files |
| Phase 19 P01 | 3min | 3 tasks | 2 files |
| Phase 19 P02 | 12min | 6 tasks | 4 files |
| Phase 20 P20-01 | 14min | 6 tasks | 5 files |
| Phase 20-v1.3-verification-and-metadata-closure P20-02 | 3min | 3 tasks | 2 files |
| Phase 20-v1.3-verification-and-metadata-closure P20-03 | 5min | 5 tasks | 3 files |
| Phase 22 P01 | 10min | 2 tasks | 4 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.

Recent decisions affecting current work (v1.2 close / v1.3 start):

- Publish first, then run API audit as separate phases — breaking changes go to v0.2.0, not v0.1.x
- Boundary audit (Phase 17) must precede documentation sprint (Phase 18) — internal modules must be hidden before any @doc additions
- Live publish closure (Phase 16) must precede API renaming (Phase 17) so the release workflow and runbook are stable before public-surface changes
- `@spec` types must be tightened before the next semver-sensitive public surface change — narrowing after publish is a Dialyzer breaking change
- `doctor ~> 0.22.0` added as dev dependency to fill @doc/@spec coverage gap that Credo/Dialyxir leave open
- Keep plan 17-01 as RED-only TDD commits because this plan delivers failing harness coverage before implementation.
- Use mix test --trace for focused verification on Mix 1.19.5 because the plan's legacy -x flag is invalid.
- Hide D-05 helper modules with @moduledoc false instead of relying on ExDoc omission or per-function hiding.
- Keep Rindle.Storage, Rindle.Storage.Local, and Rindle.Storage.S3 explicitly visible in the Storage Adapters ExDoc group per D-03.
- Remove public docs links to hidden helper modules and inline the public storage capability type instead of re-exposing internal modules.
- Hide domain invariant modules with @moduledoc false so public schema docs remain the only documented domain API.
- Rewrite public docs to describe lifecycle tables and stale-serving policy instead of linking to hidden domain internals.
- Hide Rindle.Ops.* and internal promote/process/purge workers from ExDoc while keeping Mix tasks plus CleanupOrphans and AbortIncompleteUploads as the public operational surface.
- When public docs still reference newly hidden modules, rewrite those docs around supported entrypoints instead of linking to internal services or pipeline workers.
- Keep verify_upload/2 documented on 0.1.x with deprecation metadata instead of hiding it.
- Keep Rindle.Upload.Broker.sign_url/1 as the transport-specific presign step while onboarding stays centered on Rindle and Rindle.Profile.
- Hide variant failure logging behind Rindle.Internal.VariantFailureLogger and leave only an undocumented facade shim.
- 19-01: Use struct!/2 (runtime resolution) instead of %Rindle.Error{} struct literals in test fixtures so test files compile before forward-referenced modules exist — preserves RED signal as runtime UndefinedFunctionError, not compile error.
- 19-02: attach!/4 raises Rindle.Error for ALL non-success outcomes (including DB constraint changesets) — Ecto.InvalidChangesetError reserved for the four other bangs whose non-bang twins can produce pure validation changesets independent of FK constraint failures.
- 19-02: url!/3 and variant_url!/4 test fixtures use explicit Mox expect on Rindle.StorageMock.capabilities/0 (returns [:signed_url] for url tests, [] for variant_url failure test) — required because TestProfile is private and require_delivery_support short-circuits before reaching adapter.url unless capabilities are advertised.
- 20-01: Used Phase 18 Success-Criteria-driven VERIFICATION format for both 15 and 16 retrofits because both ROADMAP blocks declare explicit success criteria
- 20-01: VERIFY-02 marked SATISFIED (functional) with forward_reference: phase-21 in 16-VERIFICATION.md — never 'partial' (D-03), to prevent re-flagging G4 in next milestone audit
- 20-01: Single atomic docs(20) commit for all five files; LiveView corrective patch (lib/rindle/live_view.ex + test/rindle/live_view_test.exs) preserved unstaged for Plan 20-02 (D-16 atomic-commit discipline)
- 20-01: VERIFY-02 stays Pending in REQUIREMENTS.md (Active checkbox + traceability row) because Phase 21 has not yet shipped (D-09); preempting would falsely declare closure earned
- 20-02: Working-tree LiveView corrective patch committed AS-IS in single Phase 20 commit per D-11/D-12; Phase 17 history verified unchanged at original SHAs (D-11 satisfied)
- 20-03: README brief / guide deeper prose split honored per existing README-vs-guide convention; Rindle.Error contract surfaced once in README and twice in guide (section-9 prose + try/rescue example) per D-13/D-14
- 20-03: Single docs(20) commit shipped 3 files atomically per D-16; doctor gate re-verified 100/100/100 across 34 modules to prove onboarding-prose edits did not affect lib/-scoped doctor coverage
- Verification failures in consume_uploaded_entries/3 now postpone entries instead of consuming them.
- Repeated LiveView consume callbacks short-circuit already-completed sessions in the wrapper.
- Onboarding attachment examples must branch on nil before looking up variants.

### Pending Todos

- Plan GCS adapter resumable upload flow (GCS-01)
- Evaluate tus/resumable protocol once release distribution is routine (TUS-01)

### Blockers/Concerns

- **Reality reconciliation closed in planning, still open in code/docs**: v1.3 assumed `0.1.0` was upcoming, but `0.1.4` is already live on Hex.pm. Phase 16 is now the cleanup phase for the shipped release window rather than a literal first-publish execution.
- **Release pipeline regression**: most recent `Release` workflow `workflow_dispatch` run (`25135467509`, 2026-04-29T21:43Z) failed after the publish lane attempted to republish an already-live version. Phase 16 closes this with an idempotency probe and rerun rehearsal.
- First 60 minutes post-publish are a hot observation window (24h revert window closes to 1h for subsequent versions) — moot for 0.1.4 (window closed 2026-04-30T21:43Z); applies fresh on every future release.

## Session Continuity

Last session: 2026-05-01T21:11:37.352Z
Stopped at: Completed 22-01-PLAN.md
Resume file: None

### Decision-Making Preference

- Default: agent decides discussion/planning details.
- Escalate only for high-impact decisions (public API/semver, destructive data
  changes, security/compliance, irreversible infra/cost, major product-scope
  shifts).

- If escalation is not possible in-session, use a reversible default and log
  the assumption.

- Workflow preference: skip discuss by default and move directly into
  planning/execution unless a high-impact ambiguity is detected.

**Last Completed Milestone:** v1.2 (Phases 10–14) — archived 2026-04-29

**Next Step:** Plan or execute Phase 21 (`VERIFY-02` hexdocs.pm reachability probe), then re-run `/gsd-audit-milestone v1.3`.

**Planned Phase:** 21 (VERIFY-02 hexdocs.pm Reachability Probe) — plans TBD
