---
phase: 133-evidence-charter-and-live-truth
plan: "75"
subsystem: ci-diagnostics
tags: [phase-133, causal-evidence, jose, doctor, halted]
requires:
  - phase: 133-74
    provides:
      - Per-call JOSE snapshots and two local CI observations
provides:
  - Two immutable Plan 75 collection attempts with exact subject identity and terminal CI results
  - A precise collector-validation blocker for the next gap plan
affects: [phase-133-causal-evidence, local-ci, cause-backed-repair-planning]
requirements-completed: []
requirements-pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
qualification: diagnostic_only
status: halted
terminal_automation: halted
subject_sha: 7b7b5269f46e273760e653d3010b6b489ab91d62
subject_tree: 4eb4b038801fd23775822f5da3d5e60651f028f7
report_a: .planning/phases/133-evidence-charter-and-live-truth/133-75-A.json
report_a_sha256: 856d11337ec18675d0067763e95468039cfef97c30f91d29d4293c8b27e54daf
report_b: .planning/phases/133-evidence-charter-and-live-truth/133-75-B.json
report_b_sha256: 2c6a1e81f9db54cf3204c7f4988882500b8c3f3af9ccfe9600f2d1a755fe7ce2
canonical_receipt_sha256: 1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4
report_verification: blocked
pair_verification: blocked
summary_verification: blocked
causal_outcome: blocked
remote_action: none
completed: 2026-10-03
---

# Phase 133 Plan 75: Causal Evidence Collection Halt

**Two full CI observations were collected on one subject, but the committed report verifier rejected both worktrees and no causal gate receives credit.**

## Accomplishments

- The committed collector and fixture harness remained byte-identical to the selected subject throughout both collections. The focused fixture harness passed before subject selection.
- Collected reports A and B in separate detached worktrees at subject `7b7b5269f46e273760e653d3010b6b489ab91d62`, tree `4eb4b038801fd23775822f5da3d5e60651f028f7`. Each report binds the same helper and harness blobs, lock digest, toolchain, and canonical receipt digest.
- Both `mix ci` commands reached a terminal full-suite summary and exited 2. A reported 3 doctests, 1,710 tests, 8 failures, 87 excluded, and 4 skipped. B reported 3 doctests, 1,710 tests, 8 failures, 87 excluded, 2 invalid, and 4 skipped.
- Both raw reports classify the JOSE cause as unresolved because no readable-local-to-absent-or-dangling transition was observed. That finding is not accepted as a verified causal gate because report validation failed.
- B contains a complete `FunctionClauseError` Doctor fingerprint matching Plan 73. A contains no complete Doctor fingerprint, so even a structurally valid pair would not meet the two-report Doctor gate.
- The canonical Nightly receipt remains SHA-256 `1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4`. All five requirements remain pending with zero credit.

## Verification and Halt

- `--verify-report` rejected A and B with exit 65: `causal report lacks exact clean detached subject identity`.
- Both reports record a clean detached start and exact subject, but `worktree.final_clean` is `false`.
- Both reports also record the outer Mix process environment as `test` while `jose_provenance.environment.mix_env` is `prod`; the committed verifier requires the resolved JOSE provenance to report `test`.
- `--verify-pair` therefore cannot establish an accepted pair. The summary, outcome, and causal assertion verifiers cannot grant a gate result from these reports.
- The exact paths responsible for the dirty final status are not recorded. The worktree-owned `.hex` directory is a likely source because the collector directs `HEX_HOME` there and the selected subject does not ignore `.hex`; this is an inference, not a collected dirty-path observation.

Plan 75 halts here. The two reports are retained unchanged as rejected diagnostic attempts. No source repair, qualification, Nightly run, remote action, ref mutation, or downstream Plan 71 execution occurred.

## Required Follow-up

Create a separate gap-closure plan to correct the collector before selecting a new subject. It should record the root-process `Mix.env` outside the dependency context, distinguish that value from any dependency-local environment, safely clean collector-owned Hex cache content after collection, and retain sanitized final dirty paths when cleanup is incomplete. Extend the focused harness to exercise these cases. Then select a fresh immutable subject and collect a new independent pair; do not reuse or rewrite Plan 75 reports.

Plans 71, 67, and 68 remain blocked. The new pair must pass report, pair, summary, and outcome verification before any cause-backed repair or qualification work proceeds.
