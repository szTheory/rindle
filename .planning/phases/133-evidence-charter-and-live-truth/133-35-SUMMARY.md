---
phase: 133-evidence-charter-and-live-truth
plan: "35"
subsystem: evidence-qualification
tags: [elixir, exunit, github-actions, evidence, reconciliation]

requires:
  - phase: 133-34
    provides: branch-aware reconciliation and append-only validation mapping
provides:
  - Deterministic census bound to clean repaired subject 4ab38ab62878eea936f20bb76e2f7321da6c2e90
  - Durable historical Nightly receipt validation across monotonic incident updates
  - Fully green local Phase 133 qualification without remote publication
affects: [133-36, 133-37, phase-133-terminal-qualification]

actuals:
  tokens: 8875
  tasks: 2
  commits: 8
plan_head_before: 2021c47fb9862340fa618bfd459791c71ee4bcd6

tech-stack:
  added: []
  patterns:
    - Historical receipts validate immutable run identity plus monotonic incident history
    - Census authority binds a clean pre-ledger commit and regenerates in detached worktrees
    - Test-only quality ratchets load the compiled application module set before inspection

key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-35-SUMMARY.md
  modified:
    - .planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json
    - scripts/ci/verify_nightly_run.sh
    - scripts/ci/test_verify_nightly_run.sh
    - test/install_smoke/phase_133_completed_validation_test.exs
    - test/rindle/doctor_thresholds_test.exs

key-decisions:
  - "Reduce the branch-state fixture complexity by extracting branch-summary materialization instead of raising the reviewed Credo baseline."
  - "Validate historical Nightly incidents as monotonic append-only history while preserving exact databaseId, SHA, ref, workflow, job, and log identity."
  - "Keep EVID-01 through EVID-04 and TRUTH-08 pending until Plan 37 supplies a successful exact receipt and terminal reconciliation."

patterns-established:
  - "Mutable incident boundary: recorded issue identity and comments must remain present and uncontradicted; later comments and updatedAt growth are allowed."
  - "Qualification boundary: local green evidence does not create a ref, dispatch a workflow, promote a receipt, or close requirements."

requirements-completed: []

coverage:
  - id: D1
    description: The census binds the exact clean pre-ledger subject and regenerates byte-for-byte in two detached worktrees.
    requirement: EVID-01
    verification:
      - kind: integration
        ref: "evidence_census.exs plus validate_evidence_census.exs in two detached 4ab38ab6 worktrees"
        status: pass
    human_judgment: false
  - id: D2
    description: Historical receipt verification tolerates later incident history but rejects missing, contradictory, or foreign run identity.
    requirement: EVID-03
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_verify_nightly_run.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: Local correctness, maintainability, package, reconciliation, automation-first, and hygiene authorities pass on the repaired subject.
    requirement: EVID-04
    verification:
      - kind: integration
        ref: "mix ci; mix refactor_contract; validate_phase_133_reconciliation.exs; automation_first_contract.sh; repo_hygiene_check.sh"
        status: pass
    human_judgment: false
  - id: D4
    description: Canonical and failed historical Nightly identities remain separately attributable without granting completion credit.
    requirement: TRUTH-08
    verification:
      - kind: other
        ref: "verify-receipt run 34638437301 plus read-only identity check for run 34661043059"
        status: pass
    human_judgment: false

duration: 116min
completed: 2026-09-12
status: complete
---

# Phase 133 Plan 35: Exact-Subject Local Qualification Summary

**A clean repaired subject now has a deterministic twelve-dimension census and a fully green local qualification, while all remote and terminal acceptance authorities remain unchanged.**

## Performance

- **Duration:** 116 min
- **Started:** 2026-09-12T23:27:38Z
- **Completed:** 2026-09-13T01:22:57Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Repaired the Plan 34 Credo complexity finding with a behavior-preserving fixture extraction and no baseline increase.
- Changed historical Nightly validation from mutable issue-snapshot byte equality to fail-closed, monotonic incident-history verification while retaining exact immutable run attribution.
- Bound the final census to clean subject `4ab38ab62878eea936f20bb76e2f7321da6c2e90`; two detached generations validated and matched at SHA-256 `00b43878f9099c693a1b88c7fc69904b60474b2e8ddf5447609e500de87ab749`.
- Completed the repository-native local qualification matrix on Elixir 1.17.3 / OTP 27.3.4.15 without publishing the derived ref `phase-133-evidence-4ab38ab62878`.

## Task Commits

Plan history was preserved across the decision checkpoint and each superseding clean subject:

1. **Initial census binding** - `798fc5f0` (feat; superseded after qualification blockers)
2. **Initial qualification record** - `1fef9eb4` (fix; preserved failed evidence)
3. **Failed qualification evidence preservation** - `3e068c72` (fix)
4. **Credo fixture complexity repair** - `bc47cb47` (refactor)
5. **Historical Nightly incident validation repair** - `2112630b` (fix)
6. **Post-repair census binding** - `d3261811` (feat; superseded by Doctor stabilization)
7. **Doctor ratchet suite-order stabilization** - `4ab38ab6` (test)
8. **Final exact-subject census binding** - `5edbfbac` (feat)

## Files Created/Modified

- `.planning/phases/133-evidence-charter-and-live-truth/133-EVIDENCE-CENSUS.json` - Binds every reviewed candidate and transition to the final clean subject.
- `scripts/ci/verify_nightly_run.sh` - Accepts monotonic incident history while rejecting missing or contradictory durable evidence.
- `scripts/ci/test_verify_nightly_run.sh` - Adds later-comment success cases and missing, contradictory, and foreign-run adversarial failures.
- `test/install_smoke/phase_133_completed_validation_test.exs` - Extracts branch-summary fixture setup to stay within the reviewed complexity inventory.
- `test/rindle/doctor_thresholds_test.exs` - Loads compiled application modules before Doctor inspects generated protocol implementations.

`.planning/REQUIREMENTS.md` intentionally remains unchanged. EVID-01 through EVID-04 and TRUTH-08 are locally qualified but remain pending until Plan 37 proves the qualified-success branch.

## Verification Evidence

- Census contract: 20 tests, 0 failures.
- Nightly collector and receipt matrix: 158 passed, 0 failed.
- Focused reconciliation/package/incident suite: 40 tests, 0 failures.
- `mix ci`: 3 doctests and 1,621 tests, 0 failures, 87 excluded, 4 skipped; Credo quality, Doctor coverage, format, compile, contract, and brandbook gates also passed.
- Repository refactor contract: 97 tests, 0 failures.
- Live reconciliation: 32 completed, 2 halted, 3 pending plans; 34/37 summarized and 27 validation records.
- Automation-first contract: passed.
- Repository hygiene from clean detached `5edbfbac`: 11 PASS, 1 WARN, 0 BLOCK. The warning records existing local-main divergence only.
- Canonical receipt: run `34638437301`, attempt 1, subject `1470cf8cb0f111d0b233efbf77ee69e92f25fd68` revalidated read-only.
- Plan 32 history: run `34661043059`, attempt 1, ref `phase-133-evidence-0f8189ddeed7`, SHA `0f8189ddeed7e7a52b5c7464f17b70ab44596c33`, workflow `.github/workflows/nightly.yml` confirmed read-only without interpreting or changing its conclusion.

## Decisions Made

- Kept the curated complexity baseline fixed and reduced fixture complexity in code.
- Treated incident comments as append-only durable evidence: every recorded comment must still exist unchanged, while later comments and monotonic `updatedAt` values are valid.
- Preserved exact run, attempt, repository, workflow, ref, SHA, job, strict-verdict, log, census, and live-truth identities as immutable receipt authority.
- Kept local qualification distinct from authorization and acceptance; no Plan 36 or Plan 37 remote action was performed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Repaired mutable historical incident validation**
- **Found during:** Task 2 qualification
- **Issue:** A later append-only incident update invalidated an otherwise immutable historical receipt because validation required byte equality with the issue's current snapshot.
- **Fix:** Required preserved incident identity and recorded comments with monotonic history, while retaining fail-closed immutable run attribution.
- **Files modified:** `scripts/ci/verify_nightly_run.sh`, `scripts/ci/test_verify_nightly_run.sh`
- **Commit:** `2112630b`

**2. [Rule 3 - Blocking quality finding] Reduced branch-state fixture complexity**
- **Found during:** Task 2 qualification
- **Issue:** Plan 34's `set_branch_state!/2` exceeded the reviewed Credo complexity inventory.
- **Fix:** Extracted branch-summary materialization into a focused helper without changing fixture behavior or raising the baseline.
- **Files modified:** `test/install_smoke/phase_133_completed_validation_test.exs`
- **Commit:** `bc47cb47`

**3. [Rule 3 - Blocking test instability] Stabilized Doctor's generated-module inspection**
- **Found during:** Full `mix ci`
- **Issue:** Doctor's threshold test could inspect generated `Inspect` implementations before their compiled modules were loaded, invalidating two tests despite zero assertion failures.
- **Fix:** Loaded the application's compiled module list before invoking Doctor's report builder.
- **Files modified:** `test/rindle/doctor_thresholds_test.exs`
- **Commit:** `4ab38ab6`

**4. [Rule 3 - Plan command drift] Used the repository's documented refactor lane**
- **Found during:** Final verification
- **Issue:** The plan names `mix refactor`, but that task does not exist in this repository.
- **Fix:** Ran the documented `mix refactor_contract` lane from `RUNNING.md`, which passed 97 contract tests.
- **Files modified:** None
- **Commit:** None

---

**Total deviations:** 4 auto-fixed (1 Rule 1, 3 Rule 3)
**Impact on plan:** The repairs keep the OSS workflow small and executable, preserve historical attribution, and strengthen deterministic local qualification without expanding remote or compliance surface.

## Issues Encountered

- The pinned Erlang 27.2 is unavailable locally, so the supported lane used installed patch-compatible OTP 27.3.4.15 with Elixir 1.17.3-otp-27.
- Hex reported an expired optional user session but resolved all public locked dependencies successfully; no private resource or authentication gate was required.
- Local hygiene correctly saw the user's preserved `.planning/config.json` edit and untracked runtime files as dirty. The same check passed from a clean detached commit without altering those files.

## Known Stubs

None. Empty shell variables in the verifier are argument-parsing state, not UI or behavior placeholders.

## Threat Flags

None. The repair changes validation of an existing read-only GitHub evidence boundary and introduces no new endpoint, credential path, filesystem authority, or schema trust boundary.

## User Setup Required

None.

## Next Phase Readiness

Plan 36 may present the immutable-attempt authorization decision for derived ref `phase-133-evidence-4ab38ab62878`. This plan does not authorize or perform that remote action. Plans 27 and 32 remain immutable halted history, the canonical receipt remains unchanged, and all five requirements stay pending until Plan 37 terminal qualification.

## Self-Check: PASSED

The summary and census exist, the census names clean subject `4ab38ab62878eea936f20bb76e2f7321da6c2e90`, the plan ledger names base `2021c47fb9862340fa618bfd459791c71ee4bcd6`, and all eight task/deviation commits are present in repository history.

---
*Phase: 133-evidence-charter-and-live-truth*
*Completed: 2026-09-12*
