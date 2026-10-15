---
phase: "134"
slug: "dependency-security-and-inbox-disposition"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-10-15"
---

# Phase 134 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Derived from the `## Validation Architecture` section of 134-RESEARCH.md.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash harnesses using fake `gh`, `mix` and `date` on PATH, run in the `ci-script-tests` job. ExUnit covers the config locks (`test/install_smoke/`). |
| **Config file** | none (the harnesses are self-contained) |
| **Quick run command** | `bash scripts/ci/test_collect_inbox.sh && bash scripts/ci/test_validate_inbox_ledger.sh` |
| **Full suite command** | `bash scripts/ci/test_collect_inbox.sh && bash scripts/ci/test_validate_inbox_ledger.sh && bash scripts/ci/test_dep_landing_evidence.sh && mix test test/install_smoke/dependabot_policy_test.exs test/install_smoke/nightly_policy_test.exs test/install_smoke/ci_observability_test.exs test/install_smoke/ci_lane_split_test.exs` |
| **Estimated runtime** | ~5 s (harnesses) and ~90 s (ExUnit subset) |

---

## Sampling Rate

- **After every task commit:** the relevant `bash scripts/ci/test_*.sh` harness, plus `./scripts/maintainer/automation_first_contract.sh`.
- **After every plan wave:** the full suite command and `bash scripts/ci/test_nightly_incident.sh`.
- **Before `/gsd-verify-work`:**
  - the live collector and validator on fresh data (< 24 h)
  - `mix hex.audit` for both the root lock and the demo lock, with every finding accounted for
  - `./scripts/maintainer/repo_hygiene_check.sh`
  - the post-merge main push runs, read with `dep_landing_evidence.sh`
- **Max feedback latency:** 120 s locally. A PR CI run takes about 8 min and a main push run about 23 min.

---

## Per-Task Verification Map

The planner fills in task IDs. These are the requirement-level checks every plan must map to:

| Requirement | Behavior | Test Type | Automated Command | Fails when | File Exists | Status |
|-------------|----------|-----------|-------------------|------------|-------------|--------|
| INBOX-01 | The inventory has the schema id, `collected_at`, `repo` and `main_sha`, plus issues, PRs, advisories with source records, and branch protection. The CI Summary row is the one with the latest `completed_at`. | harness | `bash scripts/ci/test_collect_inbox.sh` | Given duplicate check-runs, it does not pick the latest one | ❌ W0 | ⬜ pending |
| INBOX-01 | It is read-only: no non-GET method and no mutating `gh pr\|issue` verb. | harness tripwire | same | The mutations log is non-empty | ❌ W0 | ⬜ pending |
| INBOX-01 | It fails closed on auth, page or audit-parse failure. | harness | same | It exits 0 or writes output | ❌ W0 | ⬜ pending |
| INBOX-01 | A 403 or a disabled source becomes a `source_disabled` or `unreadable` record. | harness | same | A source is recorded as a zero count, or its record is missing | ❌ W0 | ⬜ pending |
| INBOX-02 | Each rejection rule works: missing, duplicate, stale head, stale inventory, terminal mismatch, supersede without successor, defer without trigger, unknown disposition. | harness | `bash scripts/ci/test_validate_inbox_ledger.sh` | A bad fixture exits 0, or the clean fixture exits non-zero | ❌ W0 | ⬜ pending |
| INBOX-02 | The committed ledger has the right shape. | harness | `bash scripts/maintainer/validate_inbox_ledger.sh --offline --ledger .planning/INBOX-LEDGER.json` | It exits non-zero | ❌ W0 | ⬜ pending |
| SEC-09 | Every advisory has a record. `resolved` means the advisory is absent. Exceptions are unexpired and have a valid trigger. | harness | `bash scripts/ci/test_validate_inbox_ledger.sh` | An expired-exception fixture (`INBOX_NOW_EPOCH`) exits 0 | ❌ W0 | ⬜ pending |
| SEC-09 | `mix hex.audit` is wired into Quality. | ExUnit | `mix test test/install_smoke/ci_observability_test.exs` | The step is absent | ❌ W0 | ⬜ pending |
| DEPS-01 | A landing's lock delta equals its declared group, and the gate map covers the main-only lanes. The twin is `not-applicable`. | harness | `bash scripts/ci/test_dep_landing_evidence.sh` | An extra-package fixture, or a twin reported as passed, exits 0 | ❌ W0 | ⬜ pending |
| DEPS-01 | MuonTrap major-version updates are ignored. | ExUnit | `mix test test/install_smoke/dependabot_policy_test.exs` | The ignore entry is absent | extend | ⬜ pending |
| D-134-02/08 | Live code has no phase-dir paths and no pinned action SHAs. | grep | `! grep -rn "\.planning/phases/134" scripts test .github` | Any match | n/a | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `scripts/maintainer/collect_inbox.sh` and `scripts/ci/test_collect_inbox.sh` (INBOX-01)
- [ ] `scripts/maintainer/validate_inbox_ledger.sh` and `scripts/ci/test_validate_inbox_ledger.sh` (INBOX-02, SEC-09)
- [ ] `scripts/maintainer/dep_landing_evidence.sh` and `scripts/ci/test_dep_landing_evidence.sh` (DEPS-01)
- [ ] `.planning/INBOX-LEDGER.json`, initially shape-valid only
- [ ] `ci.yml`: new `ci-script-tests` steps, added after #120 lands, and a `mix hex.audit` step in Quality
- [ ] `dependabot_policy_test.exs` gets the MuonTrap-major assertion. The pinned SHAs in `nightly_policy_test.exs:143,213` are decoupled.

---

## Manual-Only Verifications

None. Remote merges, closes, reruns and setting changes are user-authorized **actions** only (D-134-05). Every behavior is verified automatically.

---

## Validation Sign-Off

- [ ] Every task has an `<automated>` verify or a Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 120 s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
