---
phase: 133-evidence-charter-and-live-truth
plan: "97"
subsystem: maintainer-tooling
tags: [node, bash, native-build, Vix, Lexbor, evidence]
requires:
  - phase: 133-96
    provides: historical native-build diagnostic and source closure; neither supplies current-route authority
  - phase: 133-91
    provides: protected local-gate evidence baseline
provides:
  - deterministic read-only native-route collector and independent report verifier
  - fake-toolchain regression harness for exact-route and tamper cases
  - source-bound current native-route report with an explicit unavailable, zero-credit verdict
affects: [133-98, EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
actuals:
  tokens: 12248
  tasks: 2
  commits: 2
plan_head_before: 59aedf98248708f977ee32267508aabed50febc0
plan_head_after: 3c751d94e0f3f591541a98af735f298ccbf7b3a7
tech-stack:
  added: []
  patterns:
    - source-bound JSON evidence with independent read-only verification
    - exclusive no-clobber publication and fake committed-root fixtures
key-files:
  created:
    - scripts/maintainer/phase_133_native_route.mjs
    - scripts/maintainer/test_phase_133_native_route.sh
    - .planning/phases/133-evidence-charter-and-live-truth/133-97-NATIVE-ROUTE.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-97-SUMMARY.md
  modified: []
key-decisions:
  - "Classify the current route as unavailable when dependency metadata or a resolvable local Elixir/OTP identity is missing; do not infer a native route."
  - "Keep all five declared requirements pending; this prerequisite report grants no acceptance credit or authorization to fetch or run Mix."
requirements: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
requirements-completed: []
coverage:
  - id: D1
    description: Deterministic native-route collector, verifier, and adversarial fake-toolchain harness.
    verification:
      - kind: integration
        ref: bash scripts/maintainer/test_phase_133_native_route.sh
        status: pass
    human_judgment: false
  - id: D2
    description: Current-source route report with exact source bindings, unavailable reasons, and zero observed side effects.
    verification:
      - kind: other
        ref: node scripts/maintainer/phase_133_native_route.mjs verify --report .planning/phases/133-evidence-charter-and-live-truth/133-97-NATIVE-ROUTE.json
        status: pass
      - kind: other
        ref: ./scripts/maintainer/automation_first_contract.sh
        status: pass
    human_judgment: false
duration: "~20 min"
completed: 2026-10-07
status: complete
---

# Phase 133 Plan 97: Native Route Evidence Summary

**A source-bound native-build probe now verifies locked inputs and records that this isolated worktree has no usable native route.**

## Performance

- **Duration:** Approximately 20 minutes; plan start was not separately timestamped.
- **Started:** Approximately 2026-10-06T19:57:30-04:00.
- **Completed:** 2026-10-07T00:17:30Z.
- **Tasks:** 2.
- **Files modified:** 4 created; none modified.

## Accomplishments

- Added a read-only collector and independent verifier for locked Vix/LazyHTML inputs, local tool paths, runtime identity, and the pinned Lexbor source.
- Added a fake committed-root harness that proves a valid asset route through collection and verification and rejects missing checksums, unsupported architecture, unsafe tool/input paths, changed source or locked blobs, duplicate publication, and tampered reports.
- Collected and verified the current source report. It is explicitly `unavailable`: Vix and LazyHTML source metadata are absent, the Elixir identity probe cannot resolve the `erl` asdf version, pkg-config/pkgconf are absent, and the local LazyHTML metadata does not establish the pinned Lexbor commit.
- Preserved the source identity (`c0bf7c8d99b347c62d3ea0055ef05f9978625796`, tree `168b4c4494fdf8ff78a12dd3b8eed700d5af00c7`) and all five requirements as pending. The report records zero Mix, network, install, qualification, census, Nightly, issue-mutation, and Phase 134 child commands.

## Task Commits

1. **Task 1: Prove the local native-route probe** — `c0bf7c8d` (`feat(133-97): add native route evidence probe`).
2. **Task 2: Record the current native route and zero-credit outcome** — `3c751d94` (`docs(133-97): record native route evidence`).

**Plan metadata:** this summary commit; its hash is reported in the execution completion record.

## Files Created/Modified

- `scripts/maintainer/phase_133_native_route.mjs` — read-only collection, independent verification, and no-clobber report publication.
- `scripts/maintainer/test_phase_133_native_route.sh` — fake-root valid-route and adversarial regression fixtures.
- `.planning/phases/133-evidence-charter-and-live-truth/133-97-NATIVE-ROUTE.json` — verified unavailable route decision, source/blob bindings, tool inventory, prospective fetch scope, and zero-command counters.
- `.planning/phases/133-evidence-charter-and-live-truth/133-97-SUMMARY.md` — this plan outcome.

## Route and Protected Evidence

- The Vix asset URL, filename, checksum, platform-libvips route, and resolved Elixir/OTP/NIF target are unavailable; the report does not guess them.
- Lexbor pin: `244b84956a6dc7eec293781d051354f351274c46`; local checkout unavailable. One prospective fetch is recorded for the `lexbor_git_commit` scope at that exact Git commit. No fetch occurred.
- Report SHA-256: `497a93166a448e1849e823d44e9e2320a322ab45224f353e72c145a8036da5fb`.
- Plan 96 protected digests: summary `0ef9efd16baf1ecda48b8df85f1e9f4873b594082cabcf48116dcfc2e4d06d60`; diagnostic `1504956567b2222ba152d94cb21fc7a90eb68a8be16b8e32cb99fa6758a0ba16`; source closure `8fde2df317e1af51523f519b0f1e9594d5a421cd0ca25d9bb487263bb84e1dfc`.
- Plan 91 protected digests: summary `91d22eec8d998a3aa769779c03f9f54e6a4334a229524bfb29c0fa67ae1b0d2e`; local-gates report `aab57d83964d9d3433d472c3c7232ce5b4182dc9f091da7969b8c8b3362268ad`.
- Protected Nightly evidence digest: `133-NIGHTLY-EVIDENCE.json` `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`.
- These prior evidence files remain unchanged. `EVID-01`, `EVID-02`, `EVID-03`, `EVID-04`, and `TRUTH-08` remain pending; Plan 91 and Plan 96 remain zero-credit.

## Decisions Made

- Missing or incompatible local inputs produce an explicit `unavailable` result rather than an inferred route.
- This report is evidence only. It authorizes no dependency fetch, Mix command, qualification, census, Nightly run, issue mutation, or Phase 134 work.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

The isolated worktree does not contain the checked-out Vix/LazyHTML package sources, and its asdf shims cannot resolve an Erlang version. These expected missing prerequisites are recorded precisely in the verified report; they do not prevent completion of this zero-credit route probe.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 98 can consume the verified `unavailable` report and take its specified zero-command stop path. No native route or authorization to proceed is established.

## Self-Check: PASSED

- All four plan output files exist.
- Task commits `c0bf7c8d` and `3c751d94` are present.
- The native-route report independently verifies with its recorded SHA-256.
- `STATE.md`, `ROADMAP.md`, `REQUIREMENTS.md`, and the protected Plan 91/96/Nightly evidence files are unchanged from the plan base.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-07*
