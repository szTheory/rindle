---
phase: 105
slug: aggregate-required-check-branch-protection-flip
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-06-21
---

# Phase 105 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
>
> Defining tension (from RESEARCH `## Validation Architecture`): the *code* change is fully
> PR-CI-automatable, but the *live branch-protection flip* (D-11) is an admin-PAT mutation that
> **cannot** run in PR CI — it is a human/post-merge go/no-go. The map below draws that line
> explicitly per requirement.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | none — static YAML/shell structure assertions (no ExUnit/test framework added; zero `lib/`/test change) |
| **Config file** | none — assertions are shell + python one-liners over `ci.yml` and `setup_branch_protection.sh` |
| **Quick run command** | `bash -n scripts/setup_branch_protection.sh && python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` |
| **Full suite command** | The repo's existing `CI` workflow run on the PR (the 11 gating jobs + the new `CI Summary` job running as a non-required check, D-10) |
| **Estimated runtime** | ~2 seconds (static assertions); the live `CI` workflow run is the PR's own CI |

---

## Sampling Rate

- **After every task commit:** Run the quick command — `bash -n scripts/setup_branch_protection.sh` + YAML parse of `ci.yml` + the `--print-expected-json == ["CI Summary"]` assertion.
- **After every plan wave:** The full `CI` workflow run on the PR (proves the new `CI Summary` job runs green as a non-required check, D-10).
- **Before `/gsd-verify-work`:** All static assertions green; the PR's `CI` run green.
- **Max feedback latency:** ~2 seconds for static assertions; one PR CI run for the live-check side.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 105-01-01 | 01 | 1 | GATE-01 | T-105-01 / T-105-02 / T-105-03 / T-105-06 | Pure, network-free, zero-permission aggregate gate; explicit `needs.*.result` eval (no "green checkmark lie"); `success`+`skipped`→pass, `failure`+`cancelled`→fail over exactly the 11 gating jobs (soak/live excluded) | structural (yaml/CLI assertion) | `python3 -c "import yaml,sys; d=yaml.safe_load(open('.github/workflows/ci.yml')); j=d['jobs']['ci-summary']; assert d['name']=='CI'; assert j['name']=='CI Summary'; assert set(j['needs'])=={'quality','optional-dependencies','integration','contract','proof','package-consumer','adoption-demo-unit','cohort-demo-smoke','adoption-demo-e2e','adopter','brandbook-tokens'}; assert 'mux-soak' not in j['needs'] and 'gcs-soak' not in j['needs'] and 'package-consumer-gcs-live' not in j['needs']; assert 'permissions' not in j"` + the `if: always()` / no-`gh api` / no-`permissions` job-mapping assertion + the `skipped` skip-as-pass grep | ✅ assert-only | ⬜ pending |
| 105-01-02 | 01 | 1 | GATE-02 | — | Required-check source of truth collapses to exactly `["CI Summary"]`; generic JSON builder + live-PUT path untouched; `name: CI`/filename preserved | structural (shell/CLI assertion) | `bash -n scripts/setup_branch_protection.sh` + `bash scripts/setup_branch_protection.sh --print-expected-json \| jq -e '.required_status_checks.contexts == ["CI Summary"]'` + the section-scoped single-bullet `awk`/`grep -c` check | ✅ assert-only | ⬜ pending |
| 105-01-03 | 01 | 1 | GATE-02 | T-105-04 | Committed runbook enforces flip-AFTER-first-run + check-run-name confirmation (closes pending-forever trap); surfaces the D-09 brandbook-tokens tightening; documents but does not perform the live mutation | structural (file/content assertion) | `test -f .planning/phases/105-aggregate-required-check-branch-protection-flip/105-FLIP-RUNBOOK.md` + `grep -q 'check_required_checks.sh main' / 'setup_branch_protection.sh main' / 'check-runs' / 'brandbook-tokens'` | ✅ assert-only | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

> Test Type for every task in this phase is a **structural assertion** (YAML parse + shell/CLI),
> not a unit test — this phase adds no test framework. GATE-01 maps to Task 1 (105-01-01);
> GATE-02 maps to Tasks 2 + 3 (105-01-02 collapses the required-check set; 105-01-03 ships the
> cutover runbook that closes the fork/pending-forever side of GATE-02). Each `Automated Command`
> is the literal `<automated>` verify from the corresponding PLAN task.

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements.

- No new test file needed — assertions are inline shell/python one-liners over committed YAML/scripts (RESEARCH `## Validation Architecture` → *Wave 0 Gaps*).
- `scripts/setup_branch_protection.sh` (`--print-expected` / `--print-expected-json`) and `scripts/ci/check_required_checks.sh` already exist and are reused as the verification harness — no framework install, no fixtures, no scaffold.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live branch-protection flip — required `.contexts[]` becomes exactly `["CI Summary"]` (D-11/D-13) | GATE-02 | Admin-PAT mutation of `/branches/main/protection`; cannot run in PR CI by design (D-10/D-11). Must run only AFTER the `ci-summary` job has run on `main` at least once (D-12 pending-forever trap). | Post-merge, admin `gh` session: (1) `bash scripts/ci/check_required_checks.sh main` (pre-flip dump, D-09); (2) `gh api repos/szTheory/rindle/commits/"$(git rev-parse origin/main)"/check-runs --jq '.check_runs[].name' \| grep -Fx 'CI Summary'` (confirm name produced, D-13); (3) `GH_TOKEN=<admin-PAT> bash scripts/setup_branch_protection.sh main` (apply flip, D-11); (4) `bash scripts/ci/check_required_checks.sh main` → live `.contexts[]` == `["CI Summary"]`, empty diff (D-13). Full procedure: `105-FLIP-RUNBOOK.md`. |
| Fork PR reports `CI Summary` success rather than hanging on fork-skipped jobs | GATE-02 | No in-repo automation can manufacture a real fork run; logic-provable from D-05 (the three fork-gated jobs skip and skip→pass) but truly observable only via an actual fork PR. | Open a fork PR; confirm `CI Summary` reports success (not "Expected — Waiting for status to be reported"). Logic-provable from D-05 + Pitfall 3 (both dependency roots are directly in `needs:`). |

> Both items are recorded as the milestone's post-merge human go/no-go (RESEARCH `## Validation
> Architecture` → *Automatable vs Human/Post-Merge*). They are tracked here, in the PLAN Task 4
> blocking checkpoint, and as VERIFICATION/UAT items — not as PR-CI assertions.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (Tasks 1–3 are fully assert-automated; Task 4 is the by-design human/post-merge flip captured under Manual-Only Verifications)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (Tasks 1–3 each carry structural `<automated>` checks)
- [x] Wave 0 covers all MISSING references (none — existing infrastructure covers all requirements)
- [x] No watch-mode flags
- [x] Feedback latency < 5s (static assertions ~2s)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-06-21
