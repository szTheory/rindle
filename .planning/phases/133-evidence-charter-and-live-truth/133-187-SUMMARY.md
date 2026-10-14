---
phase: 133-evidence-charter-and-live-truth
plan: "187"
subsystem: evidence
tags: [actual-host-guard, control-diagnostic, zero-credit]
requires:
  - phase: 133-186
    provides: immutable blocked-preflight diagnostic and source-bound closeout
provides:
  - Bounded unsandboxed Node, exact deny-profile, and permissive-profile comparison
  - Actual-host observation and deterministic byte-bound zero-credit closeout
affects: [phase-133-evidence, registry-preparation]
actuals:
  tasks: 2
  commits: 3
  plan_head_before: d4c7d18c429704ae85c1ebb66a6503e3f10366ab
  plan_head_after: f12d9e937489a387b9a45048d1ea3db4b31bd337
tech-stack:
  added: []
  patterns: [actual-host control provenance, exclusive byte-bound report, deterministic closeout]
key-files:
  created:
    - scripts/maintainer/phase_133_guard_control_diagnostic_187.mjs
    - scripts/maintainer/phase_133_guard_control_diagnostic_187.test.mjs
    - .planning/phases/133-evidence-charter-and-live-truth/133-187-GUARD-DIAGNOSTIC.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-187-SUMMARY.md
  modified: []
key-decisions:
  - "A permissive profile never proves network denial; only the exact-profile local witness can establish guard readiness."
  - "All five requirements stay Pending, eleven edges unresolved, and qualification credit zero."
requirements: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
requirements-completed: []
coverage:
  - id: D1
    description: "Bounded actual-host comparison records only statuses and output fingerprints."
    verification:
      - kind: integration
        ref: "node --test scripts/maintainer/phase_133_guard_control_diagnostic_187.test.mjs"
        status: pass
    human_judgment: false
  - id: D2
    description: "Source-bound diagnostic and deterministic closeout preserve zero authority."
    verification:
      - kind: other
        ref: "verify --require-actual-host --summary 133-187-SUMMARY.md"
        status: pass
    human_judgment: false
code_size_estimate_chars: 33387
duration: not measured
completed: 2026-10-12
status: complete
source_sha: f12d9e937489a387b9a45048d1ea3db4b31bd337
source_tree: 18b58300bc94446b93b275dcc0d2bb226de71a02
source_code_sha256: b76ac28e89778b3936f0751ada03356639de6f10d55786590e80b6481cdab8db
plan186_diagnostic_raw_sha256: 3fd94b169106f2fb783d86677861fa5025b36e256c5239641a15f7a8dae0682e
plan186_diagnostic_report_sha256: fb1b8840668701304909c62643649e26d4ed3d554545ca0fab050a91117b6d11
plan186_summary_sha256: 0c10c0b4f4366b0835ccb99e20ef99ebf944b7182ba09e0f134e5740ce9ecb4f
diagnostic_raw_sha256: 42cc6a14dc951a49a2d4175efa34f96c54e573427503237d4622e40307a78967
diagnostic_report_sha256: dd70bea45362e123d456f93f33c77a3282ab59bb83ffa24dc01002c2518dbea0
actual_host_provenance: actual-host
classification: sandbox_controls_failed
guard_ready: false
historical_observation_anchor: exact raw report bytes, canonical digest, source commit/tree, and recorded runtime identity are pinned in verifier code.
recorded_node_identity: Node 20.18.1; executable SHA-256 4bf6a3eae3f992debd66e6c418438b5c608bcde575cf8aefa90858f36c37de7f.
verification_runtime_claim: this verifies the historical publication; it does not claim the current cwd or Node installation made the observation.
observed_control_tuple: [unsandboxed=passed:0, exact=failed:71, permissive=failed:71]
local_loopback_witness_attempted: false
local_loopback_witness_status: not_attempted
producer_invocations: 0
producer_children: 0
authorization: 0
attempt_markers: 0
qualification_children: 0
external_network_requests: 0
remote_requests: 0
remote_mutations: 0
qualification_credit: 0
requirements_pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
unresolved_edge_rows: 11
---

# Phase 133 Plan 187: Guard-Control Diagnostic Summary

**One actual-host comparison distinguishes sandbox controls while preserving Plan 186 exit-71 evidence and zero acceptance credit.**

## Performance

- **Duration:** Not measured
- **Started:** Not measured
- **Completed:** 2026-10-12
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Observed tuple: unsandboxed Node passed (exit 0), exact profile failed (exit 71), permissive profile failed (exit 71).
- Both sandbox controls failed; sandbox startup versus enclosing host policy remains undetermined; no code defect is asserted.
- Bound the report and complete summary to committed source, exact Plan 186 bytes, and zero-credit state.

## Post-Observation Verifier Correction

- After the immutable observation, renderer/verifier corrections added an independently pinned publication anchor and removed comparison to the verifier process current cwd and Node installation. The original report bytes were not modified.
- The renderer now labels code size as an estimate and omits measured duration; earlier values derived from source size and a zero duration were not execution measurements.
- This correction changes only how the unchanged observation is authenticated and rendered. It adds no host observation or qualification claim.

## Task Commits

1. **Task 1 RED: behavior tests** - bc40c7f40e361a971afc2644f5e41449c25c68b1
2. **Task 1 GREEN: diagnostic implementation** - f12d9e937489a387b9a45048d1ea3db4b31bd337
3. **Task 2: actual-host report and deterministic closeout** - 91439b0b

## Files Created/Modified

- `scripts/maintainer/phase_133_guard_control_diagnostic_187.mjs` - bounded controls, verifier, and renderer.
- `scripts/maintainer/phase_133_guard_control_diagnostic_187.test.mjs` - fixture branch and tamper tests.
- `.planning/phases/133-evidence-charter-and-live-truth/133-187-GUARD-DIAGNOSTIC.json` - exclusive observation.
- `.planning/phases/133-evidence-charter-and-live-truth/133-187-SUMMARY.md` - deterministic closeout.

## Decisions Made

- Classify only observed outcomes; do not infer an unobserved host cause.
- A permissive-profile pass cannot establish the production network guard.

## Deviations from Plan

Post-observation verifier and renderer correction: added an immutable publication anchor, historical runtime semantics, stronger shape checks, no-clobber-before-spawn ordering, and accurate labels for unmeasured duration/code size. The unchanged report bytes were preserved.

## Issues Encountered

None.

## Authentication Gates

None.

## Evidence Boundary

- Five requirements remain Pending: EVID-01, EVID-02, EVID-03, EVID-04, and TRUTH-08.
- All eleven evidence edges remain unresolved, including both unclassified rows.
- Qualification credit is zero. No producer child, clone, Mix gate, registry HTTP, remote request, authorization, or qualification action occurred.
- Local loopback witness attempted=false; status=not_attempted. External network requests remain zero.
- Plan 186 raw digest remains 3fd94b169106f2fb783d86677861fa5025b36e256c5239641a15f7a8dae0682e; original bytes were unchanged.

## Next Phase Readiness

The next automated prerequisite is a passing real exact-profile control plus a positive local loopback denial guard proof. Do not retry the unchanged producer; no producer collection is authorized by this closeout.

## Self-Check: PASSED

- The unchanged production report matches its tracked immutable byte and identity anchor; its historical identity is not presented as the verifier host identity.
- This complete summary matches the deterministic renderer byte-for-byte.
- Plan 186 blocked closeout and automation-first checks pass; all five requirements and eleven edges remain open.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-10-12*
