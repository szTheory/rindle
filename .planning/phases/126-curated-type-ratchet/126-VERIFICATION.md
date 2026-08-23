---
phase: 126-curated-type-ratchet
verified: 2026-08-23T17:00:34Z
status: passed
score: 3/3 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/3
  gaps_closed:
    - "CI blocks newly introduced actionable Dialyzer findings through a curated gate."
  gaps_remaining: []
  regressions: []
---

# Phase 126: Curated Type Ratchet Verification Report

**Phase Goal:** The supported Elixir/OTP cell has an actionable, enforced Dialyzer baseline with no retirement ambiguity.
**Verified:** 2026-08-23T17:00:34Z
**Status:** passed
**Re-verification:** Yes — after TYPE-02 gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | The supported Elixir 1.17 / OTP 27 home cell passes Dialyzer; every retained ignore is justified; local toolchain output is not authority. | ✓ VERIFIED | The gating, literal `1.17` / `27` Nightly Dialyzer job runs `mix dialyzer --format github`. Exact candidate `fa7020cb9b0ffc1814278ec8d0422d395f46ca25` has successful [Nightly](https://github.com/szTheory/rindle/actions/runs/32652855020), [Dialyzer job](https://github.com/szTheory/rindle/actions/runs/32652855020/job/97227448695), and [Nightly Summary](https://github.com/szTheory/rindle/actions/runs/32652855020/job/97227760748); all Dialyzer annotation pages aggregate to `0`. The 45-row ledger resolves every starting tuple: 35 retained analyzer-noise entries, 7 actionable fixes, and 3 obsolete entries. |
| 2 | CI blocks newly introduced actionable Dialyzer findings through a curated gate, and issue #76 closes with the resulting baseline evidence. | ✓ VERIFIED | The permanent policy test evaluates the live list and requires `MapSet.subset?` of a literal 35-tuple approved universe. Its executed fixtures reject both a well-formed novel exact string for existing `lib/rindle.ex` and an unapproved atom; its removal fixture accepts deletion of an approved tuple. Exact candidate [PR #91 CI Summary](https://github.com/szTheory/rindle/actions/runs/32652020419/job/97226955190) and the supported Nightly receipts all succeeded. Issue [#76](https://github.com/szTheory/rindle/issues/76) is closed; its final owner-authored receipt names the same SHA, the three named jobs, and zero annotations. |
| 3 | SAFE-01: public signatures, schema/migration behavior, telemetry, errors, Admin behavior, dependencies, CI/release topology, and supported behavior remain preserved. | ✓ VERIFIED | Fresh `bash scripts/maintainer/refactor_contract.sh` passed 92 tests; `mix format --check-formatted && MIX_ENV=test mix compile --warnings-as-errors && mix ci` exited 0; hygiene passed 8/8. Candidate-parent diff changes only the policy test (no source, ignore file, dependency, workflow, migration, Admin, release, or config surface); candidate-to-local-HEAD diff contains only Phase 126 planning metadata. |

**Score:** 3/3 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/install_smoke/dialyzer_ignore_policy_test.exs` | Closed approved-filter universe and removal-only policy ratchet | ✓ VERIFIED | Substantive 97-line ExUnit implementation: literal 35-tuple approval data, unique/owner/discriminator checks, `MapSet.subset?`, explicit novel-string and unapproved-atom invalid fixtures, and approved-removal fixture. Its focused execution passed. |
| `.dialyzer_ignore.exs` | Exact, justified 35-entry live baseline | ✓ VERIFIED | Evaluated list contains 35 unique entries: 4 atom and 31 strict string discriminators. Every retained tuple has an adjacent supported Nightly/Dialyzer rationale; the policy test verifies it as an approved subset. |
| `126-TYPE-EVIDENCE.md` | Complete immutable disposition ledger | ✓ VERIFIED | Final ledger has exactly 45 E01–E45 rows, each with one permitted terminal disposition: 35 `retained-analyzer-noise`, 7 `actionable-fixed`, 3 `obsolete`; no pending or retention-ambiguity disposition remains. |
| GitHub issue #76 receipt | Sanitized exact-head closure authority | ✓ VERIFIED | Closed issue's final comment by `szTheory` binds `fa7020…` to CI Summary 97226955190, Nightly 32652855020, Dialyzer 97227448695, Nightly Summary 97227760748, `DIALYZER: success`, and zero annotations. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Policy test | `.dialyzer_ignore.exs` | `Code.eval_file/1`, validation, then `MapSet.subset?` | ✓ WIRED | The executed test reads the real live file, validates shape/owner/duplicates/discriminator, and rejects any tuple outside the test-local approval set. No planning file is read at test runtime. |
| `.github/workflows/nightly.yml` | `.dialyzer_ignore.exs` | Literal `otp27-elixir1.17` cache hash and gating Dialyzer command | ✓ WIRED | The workflow hashes `mix.exs`, `mix.lock`, and `.dialyzer_ignore.exs` in the PLT key and runs non-advisory `mix dialyzer --format github` in the literal 1.17/27 job. |
| PR #91 and issue #76 | CI Summary, Nightly Dialyzer, Nightly Summary | One exact candidate SHA plus complete annotation API pagination | ✓ WIRED | PR head, CI run, and Nightly run each report `fa7020…`; named jobs are successful, annotations total zero, and the final issue receipt cites those exact authorities. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Policy test | `ignores` | `Code.eval_file(@ignore_path)` | The actual repository ignore list is evaluated, then tested against immutable literal approval data. | ✓ FLOWING |
| Nightly Dialyzer gate | `ignore_warnings` / PLT hash input | Candidate checkout's `.dialyzer_ignore.exs` | The exact candidate file participates in the cache identity and the successful gating Dialyzer invocation. | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Live subset, novel exact strict string rejection, unapproved atom rejection, approved removal, CI/cache topology | `MIX_ENV=test mix test test/install_smoke/dialyzer_ignore_policy_test.exs test/install_smoke/ci_lane_split_test.exs test/install_smoke/ci_cache_hygiene_test.exs --seed 0 --trace` | 35 tests, 0 failures. Trace includes all three TYPE-02 policy cases. | ✓ PASS |
| SAFE-01 preservation contract | `bash scripts/maintainer/refactor_contract.sh` | 92 tests, 0 failures. | ✓ PASS |
| Formatting, compilation, and workspace CI | `mix format --check-formatted && MIX_ENV=test mix compile --warnings-as-errors && mix ci` | Exit 0; contract and CI gates completed successfully. | ✓ PASS |
| Repository/release hygiene | `./scripts/maintainer/repo_hygiene_check.sh --ci` | 8 PASS, 0 WARN, 0 BLOCK. | ✓ PASS |
| Supported authority | GitHub Nightly 32652855020 / Dialyzer 97227448695 | Overall, Dialyzer, and Summary successful; API annotation aggregate is empty. | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| TYPE-01 | 126-01 through 126-10 | Supported 1.17/27 passes after retained ignores are justified or removed; local output is non-authoritative. | ✓ SATISFIED | Gating exact-head supported Nightly is green with zero annotations; full 45-row disposition ledger supplies retained rationales. |
| TYPE-02 | 126-01, 126-08 through 126-10 | Curated gate blocks newly actionable findings and #76 closes with evidence. | ✓ SATISFIED | Immutable 35-tuple approval universe rejects expansion/rewrite fixtures while allowing removal; same-SHA PR/Nightly evidence and closed final issue receipt verify the closure predicate. |
| SAFE-01 | 126-02 through 126-10 | Preserve public signatures, migration/schema, telemetry, errors, Admin, dependencies, CI, and release invariants. | ✓ SATISFIED | Fresh SAFE-01, full CI, compile/format, hygiene, topology tests, and the test-only candidate diff all pass. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| — | — | No unresolved debt markers, placeholder behavior, empty implementation, or hardcoded live data detected in the phase policy artifact. | ℹ️ None | No blocker. |

### Re-verification Disconfirmation Pass

The prior failure mode was deliberately attacked rather than inferred away: commit `8fe6371` added the otherwise valid new strict filter fixture against the old validator; `fa7020c` adds the immutable subset rule, and the fresh test run executes the fixture successfully as a rejection. The policy does not merely count filters, so a removal remains valid while a changed strict string or any unapproved atom is invalid. No untested error path remains in this policy behavior; external-toolchain acceptance remains bound only to the exact supported Nightly, not local Dialyzer output.

### Scope and Authority Audit

- Candidate `fa7020…` changes exactly one file relative to its parent: `test/install_smoke/dialyzer_ignore_policy_test.exs` (49 insertions, 6 deletions); forbidden-surface diff count is zero.
- Local `HEAD` `fa7995d` is not authority: candidate-to-HEAD changes only `.planning/ROADMAP.md`, `.planning/STATE.md`, and `126-10-SUMMARY.md` before this report.
- PR #91 remains open and its `headRefOid` equals the candidate SHA. The successful CI run is a `pull_request` run; the successful Nightly is an exact-head `workflow_dispatch` run.

### Gaps Summary

None. The previous TYPE-02 blocker is closed by executable removal-only policy behavior, fresh local preservation checks, and exact-head external authorities.

---

_Verified: 2026-08-23T17:00:34Z_
_Verifier: the agent (gsd-verifier)_
