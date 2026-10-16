---
phase: 134-dependency-security-and-inbox-disposition
verified: 2026-10-16T17:45:00Z
status: passed
score: 4/4 must-haves verified
covered_files: [".github/dependabot.yml", ".github/workflows/ci.yml", ".planning/INBOX-LEDGER.json", ".planning/INBOX-TRIAGE.md", ".planning/phases/134-dependency-security-and-inbox-disposition/134-01-PLAN.md", ".planning/phases/134-dependency-security-and-inbox-disposition/134-01-SUMMARY.md", ".planning/phases/134-dependency-security-and-inbox-disposition/134-02-PLAN.md", ".planning/phases/134-dependency-security-and-inbox-disposition/134-02-SUMMARY.md", ".planning/phases/134-dependency-security-and-inbox-disposition/134-03-PLAN.md", ".planning/phases/134-dependency-security-and-inbox-disposition/134-03-SUMMARY.md", ".planning/phases/134-dependency-security-and-inbox-disposition/134-04-PLAN.md", ".planning/phases/134-dependency-security-and-inbox-disposition/134-04-SUMMARY.md", ".planning/phases/134-dependency-security-and-inbox-disposition/134-05-PLAN.md", ".planning/phases/134-dependency-security-and-inbox-disposition/134-05-SUMMARY.md", ".planning/phases/134-dependency-security-and-inbox-disposition/134-06-PLAN.md", ".planning/phases/134-dependency-security-and-inbox-disposition/134-06-SUMMARY.md", "scripts/ci/test_collect_inbox.sh", "scripts/ci/test_dep_landing_evidence.sh", "scripts/ci/test_validate_inbox_ledger.sh", "scripts/maintainer/collect_inbox.sh", "scripts/maintainer/dep_landing_evidence.sh", "scripts/maintainer/validate_inbox_ledger.sh", "test/install_smoke/dependabot_policy_test.exs", "test/install_smoke/nightly_policy_test.exs", "test/install_smoke/quality_signal_policy_test.exs"]
covered_digest: "v3:sha256:be72c8b0fd84447ab1106a8c7c443174dace914170bf2ace46e04a01004be761"
behavior_unverified: 0
overrides_applied: 0
coincidental_reliance_items:
  - truth: "Each landed dependency risk group is independently attributable and passes the gates before its remote disposition can close"
    reason: undeclared-precondition
    harden: "validate_inbox_ledger.sh accepts a terminal merged dependency PR with no landings[] record (probe: deleting the #105 landing still prints ok (live)). Every landing has a record except #122, and that holds only because the maintainers wrote them. Add a rule: a merge item with terminal merged=true whose squash changes a lock needs a landings[] record or an explicit equivalence record (descendant run + no-change proof), as #122 needs."
---

# Phase 134: Dependency, Security, and Inbox Disposition Verification Report

**Phase Goal:** Maintainers can account for every current remote item and dependency risk without bulk mutation or ambiguous rollback.
**Verified:** 2026-10-16T17:45:00Z
**Status:** passed (with warnings)
**Re-verification:** No. This is the initial verification.

All evidence below comes from commands the verifier ran itself in the worktree on branch `docs/phase-134-closeout` (HEAD 4fa0dad4, origin/main 9d046059). The verifier did not use SUMMARY claims as evidence. It made no remote mutation: every `gh` call was a GET.

## Goal Achievement

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A timestamped, read-only collector inventories every open issue, pull request, check state, reported advisory, and relevant branch-protection setting without mutating GitHub state | VERIFIED | **Fresh live run:** `collect_inbox.sh` with the validator's collector args exited 0 at 2026-10-16T17:33:06Z (main 9d046059). It recorded:<br>- issues #42 and #131<br>- PR #139 with head, CI Summary and lock_delta<br>- 25 terminal lookups<br>- branch protection: http 200, contexts [CI Summary], strict true, enforce_admins false<br>- advisory sources: hex_audit root findings, demo clean, deps_audit clean, Dependabot source_disabled (403), vulnerability-alerts source_disabled (404)<br>- main_ci<br>**Read-only:** the GitHub wrappers run only `gh api <path>`. The harness tripwire passed 70/70. `git status` was unchanged after the run (the lock fingerprint guard held). |
| 2 | A machine-checkable ledger assigns each open issue and PR exactly one disposition and rejects missing or stale entries | VERIFIED | **Live validation:** `validate_inbox_ledger.sh --inventory closureV.json` printed `ok (live)`. `--offline` printed `ok (offline)`. The harness passed 72/72.<br>**Mutation probes against the fresh inventory** each rejected with exit 1:<br>- #131 removed: missing<br>- #139 head_sha zeroed: stale<br>- #42 duplicated: duplicate<br>- #122 terminal.merged flipped: terminal mismatch<br>- clock +25 h: stale inventory<br>**Wiring:** ci-script-tests runs it (ci.yml:1477-1483). |
| 3 | Every reported advisory records dependency path, supported-runtime reachability, fix version, and verified resolution or a bounded exception with an executable expiry trigger | VERIFIED | **Ledger:** 23 advisory records. 20 are resolved; the validator checks each is absent from fresh hex.audit (a probe that marked 43966 resolved was rejected). The other 3 are cowlib root exceptions, expiring 2027-01-15 with a date trigger; the expired-exception probe was rejected.<br>**Reachability matches mix.exs:**<br>- bypass is `only: :test`, so cowlib is dev-test-only<br>- req and finch are `optional: true`, so root mint is optional-dep<br>- the demo has req and bandit unconditionally, so they are runtime<br>**Fresh inventory:** root findings are only the 3 cowlib ids; the demo is clean.<br>**CI:** the hex.audit step is wired as advisory (ci.yml:202-205). |
| 4 | Each landed dependency risk group is independently attributable and passes supported-toolchain, public-contract, built-package consumer, and relevant twin gates before its remote disposition can close | VERIFIED (coincidental-reliance) | **Seven landings re-derived:** the verifier re-ran `dep_landing_evidence.sh --group ... --baseline-sha ...` live for all 7 `landings[]` records (#123, #113, #129, #109, #105, #112, #130). Each returned verdict pass, exit 0, attributable true and mix_exs_changed false. Each run id matches the ledger, and twin is the not-applicable literal.<br>**#122 (req/mint/decimal):** attributable (the lock delta equals the declared packages). Its own run 38809962966 is a `regression`: the Package Consumer Full legs failed at the repo hygiene step and skipped the built-package proof, and Proof was cancelled. The descendant run 38828155392 on dc75ab83 passes all three gates. The only changes between the two commits are 3 planning docs (verified with `git diff`).<br>**Other merged PRs:** none without a landing record touched a lock. #125 and #136 are release mix.exs bumps. |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `scripts/maintainer/collect_inbox.sh` | VERIFIED | 480 lines. GET-only wrappers, fail-closed. Run live by the verifier. |
| `scripts/maintainer/validate_inbox_ledger.sh` | VERIFIED | 357 lines. All rules live in one jq program; trigger vocabulary is closed. Wired into ci-script-tests (offline). |
| `scripts/maintainer/dep_landing_evidence.sh` | VERIFIED | 280 lines. Re-run live on 8 SHAs by the verifier. |
| `scripts/ci/test_{collect_inbox,validate_inbox_ledger,dep_landing_evidence}.sh` | VERIFIED | 70/70, 72/72 and 58/58 locally. Steps at ci.yml:1477-1481. |
| `.planning/INBOX-LEDGER.json` | VERIFIED | 29 items, 23 advisories, 7 landings, 1 source record. |
| `.planning/INBOX-TRIAGE.md` | VERIFIED | Reduced to a pointer to the ledger. |
| `.github/dependabot.yml` muontrap semver-major ignore | VERIFIED | Lines 46-47. Locked by dependabot_policy_test. |
| ci.yml `Audit Hex advisories (advisory)` step | VERIFIED | Lines 202-205. Locked by quality_signal_policy_test. |

### Key Link Verification

| From | To | Via | Status |
|------|----|-----|--------|
| validate_inbox_ledger `--print-collector-args` | collect_inbox `--include` | terminal lookups | WIRED (25 terminal records collected and matched) |
| collect_inbox inventory | validator live rules | `--inventory` | WIRED (ok live, and the probes reject) |
| dep_landing_evidence output | ledger `landings[]` | maintainer transcription | WIRED, but by hand: the validator checks only the shape of a landing and does not re-query GitHub. The verifier re-derived all 7 records. |
| ci.yml ci-script-tests | the 3 harnesses + offline ledger | named steps | WIRED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Collector harness | `bash scripts/ci/test_collect_inbox.sh` | 70 passed, 0 failed | PASS |
| Validator harness | `bash scripts/ci/test_validate_inbox_ledger.sh` | 72 passed, 0 failed | PASS |
| Landing harness | `bash scripts/ci/test_dep_landing_evidence.sh` | 58 passed, 0 failed | PASS |
| Live collect and validate | `collect_inbox.sh` then `validate_inbox_ledger.sh --inventory` | exit 0, `ok (live)` | PASS |
| Offline ledger | `validate_inbox_ledger.sh --offline` | `ok (offline)` | PASS |
| Live negative probes | 8 mutated ledgers against the fresh inventory | 7 reject as expected; the deleted-landing case is accepted (see Warnings) | PASS (with warning) |
| Landing re-derivation | `dep_landing_evidence.sh` on 7 landing SHAs, #122 and dc75ab83 | 7 pass; #122 regression; dc75ab83 pass | PASS |
| Policy tests | `mix test` on quality_signal, dependabot and nightly policy tests | 17 tests, 0 failures | PASS |
| Automation-first contract | `scripts/maintainer/automation_first_contract.sh` | exit 0 | PASS |
| D-134-02 path fence | `grep -rn .planning/phases scripts test .github` | no 134 paths; the only hits are pre-existing Phase 133 references | PASS |

### Probe Execution

No `scripts/*/tests/probe-*.sh` is declared for this phase. Step 7c does not apply.

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| INBOX-01 | Timestamped read-only inventory | SATISFIED | Truth 1 |
| INBOX-02 | Explicit disposition per open issue and PR | SATISFIED | Truth 2. Open at collection: #42 retain, #131 retain, #139 retain. |
| SEC-09 | Advisory path, reachability, fix version, resolution or bounded exception | SATISFIED | Truth 3 |
| DEPS-01 | Independently attributable risk groups land after gates pass | SATISFIED (warning) | Truth 4 |

No requirement is orphaned. REQUIREMENTS.md maps exactly these 4 IDs to Phase 134.

### Anti-Patterns and Warnings

| File | Issue | Severity |
|------|-------|----------|
| `scripts/maintainer/validate_inbox_ledger.sh` | Has no rule that a terminal merged dependency PR has a `landings[]` record. A probe that deleted the #105 landing still printed `ok (live)`. #122 is the live instance. | WARNING |
| `.planning/INBOX-LEDGER.json` #122 rationale | Says its own run "went red only at the hex-baseline hygiene BLOCK". In fact the built-package consumer proof was skipped on every Full Matrix leg, and Proof was cancelled at the drift gate. The conclusion still holds because the descendant dc75ab83 passes with identical code. | WARNING (accuracy) |
| `scripts/maintainer/collect_inbox.sh:306` | `main_ci.failed_jobs` uses `conclusion != success`, so jobs still in progress (conclusion null) are listed as failed. Observed on run 38940010020: 6 "failed" jobs at 17:29Z, while gh showed them in progress or succeeded. The validator does not consume this field. | WARNING |
| Ledger advisory EEF-CVE-2026-43966 | `fix_version: null` (RESEARCH: OSV lists only a commit), while the exception rationale says "every fixed release (2.20.0, 2.21.0)". It is covered by the bounded exception. | INFO |
| PR #139 (release 0.4.10) | CI Summary `failure` on head 6bb6153c. Main run 38940010020 on 9d046059 was still in progress. #139 is retained and does not affect the phase verdict. | INFO |

There are no TBD, FIXME or XXX markers in the phase-modified scripts.

### Human Verification Required

None. Every truth closed from executable evidence (automation-first).

### Gaps Summary

There are no blocking gaps. The inventory, ledger, advisory accounting and landing evidence all pass on fresh live data that the verifier collected and re-derived itself.

The main weakness is DEPS-01 enforcement. The validator does not require a gate record for each landed dependency group, and it does not re-check a recorded gate against GitHub. #122 rests on prose plus equivalence evidence: the descendant run, with no code change in between. Re-running the tool confirms that evidence, but the validator does not enforce it. A small follow-up rule would close this. Fixing the `failed_jobs` in-progress miscount would make the collector's check-state field accurate.

---

_Verified: 2026-10-16T17:45:00Z_
_Verifier: Claude (gsd-verifier)_
