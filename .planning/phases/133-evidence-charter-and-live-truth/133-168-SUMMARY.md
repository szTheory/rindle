---
phase: 133-evidence-charter-and-live-truth
plan: "168"
subsystem: testing
tags: [node, offline-qualification, authorization, host-guard, terminal-receipts]
requires:
  - phase: 133-155
    provides: Authenticated signed registry supply and route
  - phase: 133-167
    provides: Detached staging and post-marker first-red receipt support
provides:
  - Fresh Plan 168 preflight, zero-fetch supply, and digest-only authorization
  - Tested repair for Node-runtime identity and shell authorization receipt validation
affects: [133-169, 133-121, 133-122, 133-123, registry-qualification]
actuals:
  tasks: 3
  commits: 2
plan_head_before: 72d298c99cac0e9e2a80c38300afce359076adc6
plan_head_after: 4b891172
duration: "halted during one-shot verification"
completed: 2026-10-11
tech-stack:
  added: []
  patterns: [digest-only authorization receipts, host-guard executable identity, fail-closed one-shot execution]
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-168-PREFLIGHT.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-168-SUPPLY.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-168-RETRIEVAL.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-168-QUALIFICATION-AUTHORIZATION.json
  modified:
    - scripts/maintainer/phase_133_qualification_168.mjs
    - scripts/maintainer/phase_133_qualification_168.test.mjs
    - scripts/maintainer/phase_133_local_gates.sh
    - scripts/maintainer/test_phase_133_local_gates.sh
key-decisions:
  - "The exact authorization is bound to preflight c03a8c034644870aed369d90ca9ba8b4ec2184cf42965240a39163079773a018; the receipt stores only decision digest ddaeba63c71d9c52fa1f5a89d6463ccfa5d003e6fbbac567f1a7b51c0b565fd2."
  - "The single run-qualification invocation failed before an attempt marker because the local shell resolved Node 26 while the host-guard report was created with Node 22. It must not be retried under Plan 168."
  - "The halted verifier fails because no attempt marker or terminal receipt exists. Do not synthesize either; qualification credit remains zero."
requirements-completed: []
coverage:
  - id: D1
    description: Fresh Plan 168 preflight and digest-only authorization bind the exact committed source and pass independent verification.
    verification:
      - kind: other
        ref: scripts/maintainer/phase_133_qualification_168.mjs verify-preflight --plan 133-168
        status: pass
      - kind: other
        ref: scripts/maintainer/phase_133_qualification_168.mjs verify-prerequisites --plan 133-168
        status: pass
      - kind: other
        ref: scripts/maintainer/phase_133_qualification_168.mjs verify-authorization --plan 133-168
        status: pass
  - id: D2
    description: One authorized invocation must produce independently verified green or first-red terminal evidence.
    verification:
      - kind: other
        ref: scripts/maintainer/phase_133_qualification_168.mjs run-qualification --plan 133-168
        status: fail
      - kind: other
        ref: scripts/maintainer/phase_133_qualification_168.mjs verify-halted --plan 133-168
        status: fail
status: halted
commits: 2
---

# Phase 133 Plan 168: Fresh Qualification Attempt Summary

**Plan 168 stopped before qualification because the local-gates shell recomputed the host guard under Node 26 instead of the Node 22 executable bound by preflight.**

## Source and Authorization

- The fresh preflight was generated for source `f5a549aa580346c6a25a34001370ad843d47a1df`, tree `71d5ef5c3f02864463a3d71f3bb481bf09c2e8af`, preflight digest `c03a8c034644870aed369d90ca9ba8b4ec2184cf42965240a39163079773a018`, and supply digest `6bdf71d17774f23b13eeda813c1d0107be415d3f58551ee16262f766b787f2a4`.
- The exact authorization was independently verified. Its receipt digest is `ddaeba63c71d9c52fa1f5a89d6463ccfa5d003e6fbbac567f1a7b51c0b565fd2`; the receipt contains `decision_sha256` and does not contain the literal.
- The first fix, committed as `f5a549aa`, changed authorization storage to digest-only. The later runner repair is `4b891172`.

## Halt Evidence

- The one `run-qualification --plan 133-168` invocation exited 1 with `report_recomputed_mismatch` during the local shell's authorization verification. The outer runner was Node 22.14.0, while bare `node` in `phase_133_local_gates.sh` resolved to Node 26.10.0; the host-guard report binds the Node executable.
- No `133-168-QUALIFICATION-ATTEMPT.json` or `133-168-LOCAL-GATES.json` was written, and no Mix child or network request ran.
- `verify-halted --plan 133-168` exited 1 with `ENOENT` for the missing attempt marker. This is not independently verified terminal evidence, so Plan 168 remains halted and cannot enable Plan 169.
- The repair now passes the runner's exact Node executable into the child shell and aligns shell/terminal checks with the digest-only authorization schema. It is post-attempt repair only; it does not authorize another Plan 168 invocation.
- The earlier unused preflight files were byte-preserved at `/private/tmp/phase133-plan168-stale-d36e686b3b79575a` before generating the corrected preflight.

## Verification

- Fresh `verify-preflight`, `verify-prerequisites`, `verify-decision`, and `verify-authorization` — passed before the one-shot invocation.
- Initial digest-only Plan 168 Node suite — 14 tests passed; focused reconciliation ExUnit suite — 126 tests passed; automation-first contract — passed.
- Post-repair Plan 168 Node suite — 15 tests passed; `bash -n` for both changed shell scripts and `git diff --check` — passed.
- The one-shot qualification and independent halted verifier — failed as recorded above. No retry was made.

## Next Step

Create a new gap plan for a fresh qualification route using the repaired runner and a new source-bound preflight and authorization. Do not reuse the Plan 168 authorization or rerun Plan 168. Keep Plans 121–123 blocked and all five requirements Pending until a new route produces independently verified green evidence.
