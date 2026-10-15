---
phase: 133-evidence-charter-and-live-truth
plan: "30"
subsystem: planning-evidence
tags: [evidence-census, exact-sha, detached-worktree, nightly, automation-first]
status: complete
requires:
  - phase: 133-28
    provides: deterministic lower-bound package compatibility and lifecycle-attribution repairs
  - phase: 133-29
    provides: bounded reconciliation with immutable halted-plan authority and the ordered repair graph
provides:
  - deterministic twelve-candidate evidence census bound to exact local repair subject e70623e9ea956c750904af574f47221cc472d2f2
  - complete local qualification across affected package, Nightly, CI, refactor, reconciliation, automation-first, and detached-hygiene authorities
  - read-only preservation proof for the failed remote ref/run and prior valid canonical Nightly receipt
affects: [133-31, 133-32, EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
plan_head_before: e90947687d30edd3d545bd2c15c48e3f6adfa15c
actuals:
  tokens: 5589
  tasks: 2
  commits: 3
tech-stack:
  added: []
  patterns:
    - bind evidence to a clean pre-ledger commit and validate every detector input from its detached bytes
    - distinguish immutable historical failure identity from the separate prior-valid live receipt authority
    - require repeatable collection and exact receipt hashes before accepting a census correction
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-30-SUMMARY.md
  modified:
    - .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json
    - test/install_smoke/nightly_policy_test.exs
key-decisions:
  - "Bind the final census to e70623e9ea956c750904af574f47221cc472d2f2, the clean implementation commit immediately before the corrected ledger commit."
  - "Keep failed run 34661043059 at 0f8189ddeed7e7a52b5c7464f17b70ab44596c33 as historical failure evidence and keep run 34638437301 at 1470cf8cb0f111d0b233efbf77ee69e92f25fd68 as the distinct live receipt authority."
  - "Treat local green qualification as eligibility for a later publication decision only; publish no ref, dispatch no workflow, and replace no canonical receipt in Plan 30."
  - "Preserve Plan 133-27 as halted evidence without completion credit while the normal reconciler reports the live 28-complete, one-halted, three-pending state."
patterns-established:
  - "Anti-self-reference: the census names the implementation subject before the ledger commit that records it."
  - "Correction discipline: a gate-repair commit is followed by an explicit census rebind and full detached revalidation."
requirements-completed: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
coverage:
  - id: D1
    description: "The twelve-candidate census preserves IDs and dispositions, records five explicit repair transitions, and is repeatably derived from exact detached subject bytes."
    requirement: EVID-01
    verification:
      - kind: integration
        ref: "test/install_smoke/evidence_census_test.exs --seed 0 (20 tests, 0 failures)"
        status: pass
      - kind: other
        ref: "detached evidence_census.exs double-generation plus validate_evidence_census.exs"
        status: pass
    human_judgment: false
  - id: D2
    description: "The repaired subject passes affected package/reconciliation fixtures and the complete local release-train qualification set."
    requirement: EVID-03
    verification:
      - kind: integration
        ref: "package-authority fixtures (19 included tests) and reconciliation regressions (35 tests)"
        status: pass
      - kind: integration
        ref: "Phase 133 shell fixtures (230 cases) and eight-file authority suite (169 tests)"
        status: pass
      - kind: other
        ref: "mix ci; refactor_contract.sh; validate_phase_133_reconciliation.exs; automation_first_contract.sh"
        status: pass
      - kind: other
        ref: "detached e70623e repository hygiene (11 PASS, 0 BLOCK)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The failed remote ref/run and prior canonical receipt retain their exact, separate identities throughout local qualification."
    requirement: EVID-04
    verification:
      - kind: other
        ref: "read-only git ls-remote, gh run view 34661043059, and canonical receipt tuple assertions"
        status: pass
    human_judgment: false
metrics:
  duration: 40m
  completed: 2026-09-12
---

# Phase 133 Plan 30: Exact-Subject Census and Local Qualification Summary

**A deterministic twelve-candidate census now names the clean `e70623e` repair subject, whose package, Nightly, CI, reconciliation, automation, and detached-hygiene authorities are fully green without publishing or rewriting remote evidence.**

## Performance

- **Duration:** 40 minutes
- **Started:** 2026-09-12T02:09:54Z
- **Completed:** 2026-09-12T02:49:33Z
- **Tasks:** 2
- **Files modified:** 2 evidence/gate files plus this summary

## Accomplishments

- Rebound all five repair-owned census transitions to exact pre-ledger subject `e70623e9ea956c750904af574f47221cc472d2f2` while preserving all twelve candidate IDs, reviewed dispositions, and distinct historical/live evidence roles.
- Generated the detached census twice with byte identity, validated all 21 physical detector inputs and 12 normalized observations, and fixed the final receipt SHA-256 at `90dab4d8e39bfc915b090bca50778d7f4a2c3d4732ce27fbb2fd216ae31a2d6a` with candidate digest `f74be04f17544c08554f0b2c57f92f1d57931c262fcdee1a1eb650fcdb77ab08`.
- Passed the exact package, Nightly, full CI, refactor, reconciliation, automation-first, remote-identity, and detached-hygiene gates on the supported Elixir 1.17.3 / OTP 27.3.4.15 pair.
- Preserved failed ref/run `phase-133-evidence-0f8189ddeed7` / `34661043059` and canonical receipt run `34638437301` without any remote write, dispatch, publication, or receipt edit.

## Task Commits

1. **Task 1: Rebind one census path to the clean repaired subject** - `106f238`
2. **Rule 3 gate repair: Restore supported formatter gate** - `e70623e`
3. **Task 1 correction: Rebind census after formatter repair** - `3060898`
4. **Task 2: Qualify the repaired subject locally across every affected authority** - verification-only; no file commit

## Files Created/Modified

- `.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json` — exact subject binding, repaired observations, stable dispositions, and explicit failed-to-repaired transitions.
- `test/install_smoke/nightly_policy_test.exs` — deterministic formatter-only indentation repair required by the supported toolchain gate.
- `.planning/phases/133-evidence-charter-and-live-truth/133-30-SUMMARY.md` — qualification results, identities, deviations, and closure metadata.

## Decisions Made

- The census authority is the clean implementation commit `e70623e`, not the later ledger commit `3060898`, preserving the anti-self-referential evidence contract.
- The Plan 27 failed run is immutable historical evidence, never completion evidence; the prior valid canonical receipt remains the separate live authority until an explicitly authorized future publication succeeds.
- A passing local qualification authorizes no external mutation. Plan 30 performed only read-only remote checks and local verification.
- The supported runtime pair was selected explicitly through asdf (`Elixir 1.17.3-otp-27`, `Erlang/OTP 27.3.4.15`) so formatter and CI evidence match the repository support contract.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used the shipped detached receipt validator interface**
- **Found during:** Task 1 detached census verification
- **Issue:** The plan's literal validator command supplied obsolete `--census` input, while the shipped fail-closed validator requires both `--ledger` and a generated `--receipt`.
- **Fix:** Generated the receipt from the detached subject with `evidence_census.exs`, supplied the current ledger and generated receipt to `validate_evidence_census.exs`, and required byte identity across two runs.
- **Files modified:** None.
- **Verification:** The validator printed `evidence census valid for e70623e9ea956c750904af574f47221cc472d2f2`; both receipt bytes and SHA-256 matched.
- **Committed in:** No source change required.

**2. [Rule 3 - Blocking] Repaired a supported-toolchain formatter failure**
- **Found during:** Task 2 `mix ci`
- **Issue:** `mix format --check-formatted` rejected three indentation-only lines in `test/install_smoke/nightly_policy_test.exs`; the same failure reproduced on the supported Elixir/OTP pair and blocked all later qualification.
- **Fix:** Applied only the deterministic formatter output, proved the diff empty under `--ignore-all-space`, reran the affected test, committed the repair, and rebound the census to that post-fix subject.
- **Files modified:** `test/install_smoke/nightly_policy_test.exs`, `.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json`.
- **Verification:** Supported `mix format --check-formatted` passed; the affected file passed 7 tests; the corrected census passed 20 tests plus detached double-generation and validation.
- **Committed in:** `e70623e`, `3060898`.

**3. [Rule 3 - Blocking] Restored halted-plan Roadmap semantics after the generic progress update**
- **Found during:** Final supported tracking updates
- **Issue:** `roadmap.update-plan-progress` counted summaries generically, rechecked halted Plan 133-27, and left the semantic annotation at 28 complete / three pending after Plan 30.
- **Fix:** Kept the handler's 30/32 summary total, restored Plan 27 to unchecked, and recorded the actual 29 complete / one halted / two pending topology.
- **Files modified:** `.planning/ROADMAP.md`.
- **Verification:** The exact Roadmap rows and semantic totals were inspected after correction; Plan 27 remains halted without completion credit.
- **Committed in:** Final plan metadata commit.

**Total deviations:** 3 auto-fixed blocking issues.
**Impact on plan:** Both changes were necessary to run the planned authorities exactly and preserve exact-subject truth. The only source-file change is formatter-deterministic whitespace; no product behavior, remote state, or publication scope changed.

## Issues Encountered

- The repository MinIO bootstrap process did not persist across isolated shell calls, so the repo-owned downloaded MinIO binary ran in one supervised foreground session for the package-authority tests; it was stopped after qualification.
- An early authenticated `gh run view` precondition probe encountered a transient API rate limit. The public read-only API confirmed the tuple at that boundary, and the final required `gh run view` assertion later passed directly.
- The first temporary census cleanup trap used zsh's reserved `status` name. The exact registered worktree and receipt files were removed individually, a corrected `rc` trap was installed, and all later census and hygiene runs left no residue.
- `mix ci` reported the repository's existing cowlib and Mint advisory inventory, then completed successfully under the configured dependency policy; Plan 30 changed no dependency bytes.

## Known Stubs

None. The census and formatter-only test change contain no placeholder, TODO, FIXME, unwired mock, or UI-flow empty value.

## Threat Flags

None. Exact-subject binding, detached detector containment, immutable remote readback, and failure-safe worktree cleanup are the planned mitigations for T-133-30-01 through T-133-30-05; no endpoint, authentication path, schema, or new external-write surface was introduced.

## User Setup Required

None - no external service configuration required.

## Verification

- `mix test test/install_smoke/live_truth_parity_test.exs --only package_authority --seed 0` — 19 included tests passed, 14 excluded.
- `mix test test/install_smoke/phase_133_reconciliation_test.exs test/install_smoke/phase_133_completed_validation_test.exs --seed 0` — 35 tests, 0 failures.
- Phase 133 shell fixtures — 130 + 17 + 49 + 34 = 230 cases, 0 failures.
- Eight-file Phase 133 authority suite — 169 tests, 0 failures, 17 excluded.
- `mix ci` — 3 doctests and 1,616 tests, 0 failures, 87 excluded, 4 pre-existing skips; formatting, quality, docs, contract, token, and accessibility gates passed.
- `bash scripts/maintainer/refactor_contract.sh` — 97 contract tests, 0 failures.
- Live reconciliation — 28 complete, one halted, three pending, 29/32 summarized, 29 validation records.
- `./scripts/maintainer/automation_first_contract.sh` — passed.
- Detached repository hygiene at `e70623e` — 11 PASS, one expected local-main divergence WARN, 0 BLOCK; worktree cleanup left no registered or filesystem residue.
- Remote identity assertions — failed ref/run remained `0f8189d…`, attempt one, failure; canonical receipt remained `1470cf8…` / run `34638437301` with blob `f7d5d6f981e9119751ea460e657fc3241f5b896f`.

## Next Phase Readiness

- Plan 133-31 may now reason from one exact locally green subject and deterministic census without granting authority to halted Plan 27.
- Publication remains deliberately unavailable until a later explicit human decision; this plan created no ref, workflow run, or replacement Nightly receipt.
- No execution blocker remains.

## Self-Check: PASSED

The census, formatter-only repair, summary, three plan commits, exact subject, deterministic receipt identity, immutable failed evidence, unchanged canonical receipt, and zero-residue detached checks were all verified after execution.
