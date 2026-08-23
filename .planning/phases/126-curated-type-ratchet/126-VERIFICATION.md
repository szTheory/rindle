---
phase: 126-curated-type-ratchet
verified: 2026-08-23T16:15:00Z
status: gaps_found
score: 2/3 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "CI blocks newly introduced actionable Dialyzer findings through a curated gate."
    status: failed
    reason: "The permanent policy validator permits any nonempty string discriminator for any existing owner path. It has no immutable allowlist/subset comparison to the 45-entry receipt and no invalid fixture for a new strict-description filter, so a new actionable warning can be added to .dialyzer_ignore.exs and pass this policy gate."
    artifacts:
      - path: "test/install_smoke/dialyzer_ignore_policy_test.exs"
        issue: "valid_discriminator?/1 accepts every nonblank binary; the test only locks the four remaining atom filters."
    missing:
      - "A regression rule proving the live ignore set is a removal-only subset of the immutable approved inventory (or an equivalently auditable per-entry approval receipt)."
      - "A failing fixture for an otherwise well-formed new strict-description filter."
---

# Phase 126: Curated Type Ratchet Verification Report

**Phase Goal:** The supported Elixir/OTP cell has an actionable, enforced Dialyzer baseline with no retirement ambiguity.  
**Verified:** 2026-08-23T16:15:00Z  
**Status:** gaps_found  
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Supported Elixir 1.17 / OTP 27 passes Dialyzer; retained filters are justified and local output is not acceptance authority. | ✓ VERIFIED | Exact candidate `a36cd146cd40fe6dee0f0e4350a0fd1072f57ef8` has successful workflow-dispatch Nightly [32649101781](https://github.com/szTheory/rindle/actions/runs/32649101781), Dialyzer job [97217814904](https://github.com/szTheory/rindle/actions/runs/32649101781/job/97217814904), and Summary job [97218165366](https://github.com/szTheory/rindle/actions/runs/32649101781/job/97218165366). The Dialyzer annotation API returned `[]`; log shows Elixir 1.17.3 / OTP 27.3.4.16 and `mix dialyzer --format github`. The ledger contains 45 final dispositions, with no final pending/obsolete-retained/actionable-retained state. |
| 2 | CI blocks newly introduced actionable Dialyzer findings through a curated gate, and #76 closes with the baseline evidence. | ✗ FAILED | #76 is correctly closed with exact-head links, and PR #91 CI Summary [97219456449](https://github.com/szTheory/rindle/actions/runs/32649086802/job/97219456449) is successful. However, `valid_discriminator?/1` accepts any nonempty binary description and does not compare the live set with an approved inventory; the claimed curated gate therefore does not reject a new well-formed actionable filter. |
| 3 | SAFE-01: source/API/schema/migration/telemetry/error/Admin/dependency and CI/release behavior remain preserved. | ✓ VERIFIED | Candidate-vs-base diff changes six implementation files only for type/control-flow precision, adds the policy test, and has no forbidden mix/lock/workflow/migration/Admin/release-doc changes. Fresh SAFE-01 passed (92 tests), `mix ci` passed, format/compile passed, and hygiene passed 8/8. |

**Score:** 2/3 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/install_smoke/dialyzer_ignore_policy_test.exs` | Curated baseline policy and inventory-drift lock | ✗ INCOMPLETE | Exists, is run in the structural suite (34 passing tests), rejects malformed/duplicate/missing-owner/regex/atom fixtures, but accepts any nonblank strict description; it cannot prevent new strict suppressions. |
| `.dialyzer_ignore.exs` | Final exact evidenced baseline | ✓ VERIFIED | 35 exact filters remain. All are constrained to existing owners; the 45-row ledger reconciles 10 obsolete/actionable-fixed and 35 retained analyzer-noise entries. Grouped adjacent comments and ledger slice receipts identify supported run/job/rationale. |
| `126-TYPE-EVIDENCE.md` | Immutable starting and final disposition record | ✓ VERIFIED | 45 starting tuples across 18 owners; final table has exactly one disposition per E01–E45 and final supported run reports an empty warning multiset. |
| GitHub issue #76 comment | Immutable final external receipt | ✓ VERIFIED | Owner-authored final comment links candidate SHA, PR CI Summary, Nightly, Dialyzer, Nightly Summary, retention count/rationales, and is consistent with closed issue state. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `.github/workflows/nightly.yml` | `.dialyzer_ignore.exs` | Literal cache hash and gating Dialyzer command | ✓ WIRED | Nightly uses `hashFiles('mix.exs', 'mix.lock', '.dialyzer_ignore.exs')` in the literal `otp27-elixir1.17` PLT key and runs non-advisory `mix dialyzer --format github`. |
| Policy test | `.dialyzer_ignore.exs` | `Code.eval_file/1` | ⚠️ PARTIAL | The live list is loaded and structural properties are checked, but approved strict descriptions are not locked. |
| Issue #76 comment | PR CI + Nightly jobs | Same candidate SHA | ✓ WIRED | PR #91 head equals `a36cd146…`; CI run 32649086802 and Nightly run 32649101781 each report that exact head and required successful named jobs. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Nightly Dialyzer gate | `.dialyzer_ignore.exs` list | Checked-out candidate file, cache-hash input, Dialyxir `ignore_warnings` | Yes | ✓ FLOWING |
| Policy test | `ignores` | `Code.eval_file(@ignore_path)` | Yes, but validation has no approved-description source | ⚠️ HOLLOW POLICY |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Policy, lane topology, cache topology | `MIX_ENV=test mix test test/install_smoke/dialyzer_ignore_policy_test.exs test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_cache_hygiene_test.exs --seed 0` | 34 tests, 0 failures | ✓ PASS (does not prove new-filter rejection) |
| SAFE-01 preservation contract | `bash scripts/maintainer/refactor_contract.sh` | 92 tests, 0 failures | ✓ PASS |
| Format/compile/full CI | `mix format --check-formatted && MIX_ENV=test mix compile --warnings-as-errors && mix ci` | completed successfully | ✓ PASS |
| Release/repo hygiene | `./scripts/maintainer/repo_hygiene_check.sh --ci` | 8 PASS, 0 WARN, 0 BLOCK | ✓ PASS |
| Supported Dialyzer | GitHub run 32649101781 / job 97217814904 | success; zero warning annotations | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| TYPE-01 | 126-01 through 126-09 | Supported 1.17/27 passes after every retained ignore is justified or removed; local output is non-authoritative. | ✓ SATISFIED | Exact-head successful Nightly/Dialyzer/Summary; zero warnings; complete 45-entry ledger and supported receipts. |
| TYPE-02 | 126-01, 126-08, 126-09 | Curated gate blocks newly actionable findings and #76 closes with evidence. | ✗ BLOCKED | External receipt and issue close are valid, but the policy code does not reject newly added strict-description filters. |
| SAFE-01 | 126-02 through 126-09 | Preserve public signatures, migrations, telemetry, error shapes, and CI/release invariants. | ✓ SATISFIED | Fresh SAFE-01, `mix ci`, compile/format, hygiene, and forbidden-surface candidate diff audit pass. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/install_smoke/dialyzer_ignore_policy_test.exs` | 42–43 | Any nonblank description is approved | 🛑 BLOCKER | New actionable warnings can be suppressed by adding a well-formed exact tuple. |

### Gaps Summary

The baseline itself is real: the required supported Nightly, PR CI Summary, zero-warning Dialyzer result, clean candidate authority, issue receipt, ledger, preservation contract, full CI, and hygiene all check out. The phase still misses its TYPE-02 outcome because the enforcement layer does not protect the curated set from expansion. The current test explicitly avoids freezing the count, but supplies no removal-only/approved-inventory constraint to replace that freeze.

The required correction is narrow: make policy validation compare live entries against the immutable approved inventory while permitting removals, and add an invalid fixture showing that a new exact strict-description entry is rejected. Re-run the focused policy/topology tests and existing exact-head authority protocol on the corrected candidate.

---

_Verified: 2026-08-23T16:15:00Z_  
_Verifier: the agent (gsd-verifier)_
