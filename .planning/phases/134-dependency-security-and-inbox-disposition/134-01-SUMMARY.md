---
phase: 134-dependency-security-and-inbox-disposition
plan: 01
subsystem: infra
tags: [bash, jq, gh, hex-audit, inventory, fake-gh-harness]
status: complete

requires:
  - phase: 133
    provides: fake-gh PATH-shim harness pattern (test_nightly_incident.sh)
provides:
  - "scripts/maintainer/collect_inbox.sh: read-only, fail-closed INBOX-01 inventory collector (schema rindle-inbox-inventory-v1)"
  - "scripts/ci/test_collect_inbox.sh: fake gh/mix/date harness with mutation tripwire (70 checks)"
affects: [134-02, 134-03, 134-04, 134-05, 134-06]

actuals:
  tokens: 13100
  tasks: 3
  commits: 3
plan_head_before: 9cd4acf06686ad430c52d1a1e26790a82783f714
plan_head_after: 818399d9b4ba334b93840e020e3aa57b9b853e5f

tech-stack:
  added: []
  patterns:
    - "single gh_get / gh_paged / gh_get_opt wrapper set: only `gh api <path>` with no method or field flag"
    - "section files sec-*.json merged by `jq -S -s add`, written to a temp file and mv'd (atomic, no partial inventory)"
    - "fake gh keyed by sanitized request path with per-fixture status files and a mutations tripwire file"

key-files:
  created:
    - scripts/maintainer/collect_inbox.sh
    - scripts/ci/test_collect_inbox.sh
  modified: []

key-decisions:
  - "Lock-file change guard uses a cksum fingerprint of mix.lock and examples/adoption_demo/mix.lock taken before and after the audits (equivalent to the plan's git diff check, but also works in the fixture tree and does not trip on pre-existing local edits)"
  - "INBOX_ROOT_DIR env var lets the harness point the collector at a fixture project tree instead of the real repo"
  - "A hex.audit run that exits 0 with a marker but no findings, or exits non-zero without both a section marker and a parseable finding, aborts the collection (retirement-only output also aborts, fail closed)"

requirements-completed: []
requirements-advanced: [INBOX-01, SEC-09]

coverage:
  - id: D1
    description: "Collector emits one schema-tagged inventory of open issues, open PRs (head, CI Summary by greatest completed_at, manifest files, lock_delta), terminal lookups, branch protection and main CI baseline"
    requirement: INBOX-01
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_collect_inbox.sh"
        status: pass
    human_judgment: false
  - id: D2
    description: "Collector is provably read-only (mutation tripwire) and fails closed on auth, page, 5xx, malformed JSON, unparseable hex.audit, and lock change"
    requirement: INBOX-01
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_collect_inbox.sh"
        status: pass
    human_judgment: false
  - id: D3
    description: "Advisory sources (hex.audit root and demo, deps.audit, Dependabot alerts, vulnerability-alerts probe, actions) are explicit records; a disabled or unreadable source is never a zero count"
    requirement: SEC-09
    verification:
      - kind: integration
        ref: "bash scripts/ci/test_collect_inbox.sh"
        status: pass
    human_judgment: false
---

# Phase 134 Plan 01: Inbox Collector Summary

**Read-only, fail-closed `collect_inbox.sh` that writes one jq-sorted inventory of issues, PRs (per-head authoritative CI Summary, lock delta), advisory source records, branch protection and the main CI baseline, proven by a 70-check fake-gh/fake-mix harness with a mutation tripwire.**

Duration: about 25 min (started 2026-10-15T17:40Z, finished 2026-10-15T18:06Z). Tasks: 3. Files: 2 created.

## Accomplishments

- **Task 1 (tracer, 9dbeae4e):** CLI parsing (unknown flag exits 64), `gh auth status` precheck, the `gh_get`/`gh_paged` wrappers, issues slice, atomic temp-file plus `mv`, EXIT trap that removes temp files and maps any non-usage failure to exit 1. Harness with fake `gh`, `mix`, `date`, a tripwire self-test (proves the tripwire flags `-X POST`, `--method=PUT`, `-f`, `-XDELETE`, `pr merge`, `issue close`, `run rerun`) and auth/page2 failure cases.
- **Task 2 (861812d5):** per-PR REST read with 3 bounded mergeable retries (stays `"unknown"`), paginated files, `manifest_files`, `lock_delta` parsed from `mix.lock` patches, CI Summary chosen by `max_by(.completed_at)` filtered to `github-actions` with `superseded_count`, `--include` terminal lookups, protection 200 / `branches-partial` / `unreadable`, 5xx abort, `main_ci.failed_jobs`.
- **Task 3 (818399d9):** `mix hex.audit` for root and demo with `HEX_IGNORE_ADVISORIES=""`, demo deps fetched lock-verified into a scratch path, strict finding parser with `Advisories:` / `Ignored advisories:` tagging, `deps.audit` second opinion, Dependabot alerts (`source_disabled` only when GitHub says "disabled for this repository"), `vulnerability-alerts` probe, `actions: not-applicable`, `--hex-package` via `mix hex.info`, `--skip-demo-audit` as `unreadable/skipped`, lock fingerprint guard.

## Verification

- `bash scripts/ci/test_collect_inbox.sh`: **70 passed, 0 failed**. Also green under `/bin/bash` 3.2.57 and in `ubuntu:22.04` (jq 1.6, mawk 1.3.4, GNU userland).
- Acceptance greps: `rindle-inbox-inventory-v1` present; no `-X|--method POST|PUT|PATCH|DELETE` in the collector; no `.planning/phases` paths in either script; `max_by` and `HEX_IGNORE_ADVISORIES` present; no `json mergeable` text.
- `! grep -rn "\.planning/phases/134" scripts test .github`: no matches.
- `./scripts/maintainer/automation_first_contract.sh`: exit 0.
- Live read-only dry run (collector against szTheory/rindle, scratchpad output, both locks unchanged): exit 0 in about 42 s, `jq -e` shape check true.

### Live dry-run record (evidence of the tool only; no requirement credit)

Collected 2026-10-15T18:05:03Z at main `ae08818ab45d779f906de04a92b6770679871e70`.

- Open issues: 1 (#42). Open PRs: 6 (#95, #105, #108, #109, #112, #113). #120 is no longer open.
- CI Summary per head (superseded_count in parentheses): #95 d76291a2 success (1); #105 e373b3e2 success (0); #108 a9f6b293 success (1); #109 a919a4d6 failure (1); #112 c57e9e7c success (0); #113 cf9f80c4 failure (0, mergeable_state blocked, not behind). All other PRs are `behind`.
- Lock deltas: #95 muontrap 1.7.0>2.0.0 (plus mix.exs); #105 ecto, ecto_sql; #108 mint, req; #109 ex_aws + mint + req (overlap with #108 confirmed); #112 12 packages incl. decimal 3.1.1>3.2.0, ecto, ecto_sql (overlap with #105 confirmed); #113 workflows only.
- Terminal lookups: #88 issue closed/completed; #93 and #98 PRs closed, merged false.
- `hex_latest.bandit` = 1.12.5 (no fixed release).
- Advisory sources: `hex_audit_root` findings; `hex_audit_demo` findings; `deps_audit` clean (disagrees with hex.audit, as researched); `dependabot_alerts` source_disabled (http 403); `vulnerability_alerts` source_disabled (http 404); `actions` not-applicable.
- Root finding ids (11): EEF-CVE-2026-43971, -43966, -43969 (cowlib); -82729, -82672, -91043, -92103, -94194, -82728 (mint); -97853 (decimal); -92106 (lazy_html).
- Demo finding ids (9): the mint six, -97853, -92106, plus bandit EEF-CVE-2026-105659.
- Branch protection: source `protection`, http 200, contexts ["CI Summary"], strict true, enforce_admins false.
- main_ci: run 38775015070 at ae08818a, conclusion success, failed_jobs [] (the earlier red `Adoption Demo E2E` baseline is no longer the latest push run).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Pre-commit branch guard vs. sequential-on-worktree execution**
- **Found during:** Task 1 commit
- **Issue:** The executor's worktree guard requires an `agent-*` branch name; this run is sequential on the designated `gsd/phase-134` branch (orchestrator instruction: no branch creation or switching).
- **Fix:** Kept the protected/default-branch assertion (branch is not main/master/develop/trunk/release/*) and skipped the agent-namespace allow-list as inapplicable to the orchestrator-assigned phase branch.
- **Files modified:** none

**2. [Rule 2 - Missing critical] Lock guard via fingerprint instead of git diff**
- **Found during:** Task 3
- **Issue:** `git diff --quiet` cannot cover the fixture tree and would fail on pre-existing local edits unrelated to the collector.
- **Fix:** before/after `cksum` fingerprint of both lock files with abort on change, plus a harness case (`touchlock`) proving the abort.
- **Files modified:** scripts/maintainer/collect_inbox.sh, scripts/ci/test_collect_inbox.sh
- **Commit:** 818399d9

**3. [Rule 2 - Missing critical] Extra fail-closed and robustness checks**
- Alerts response of 100 entries aborts (a full single page could hide more); ANSI escapes stripped before parsing hex.audit/hex.info output (real output starts with an auth-expiry colour line on stdout); scratch dirs made writable before cleanup.

**Total deviations:** 3 (1 blocking-guard adaptation, 2 hardening). **Impact:** none on scope or interfaces.

## Notes for downstream plans

- Inventory interface matches the plan exactly. Extras: `ci_summary.completed_at`, advisory `findings[].source` is `hex_audit` or `dependabot`, `deps_audit.output_tail`.
- `INBOX_ROOT_DIR` (fixture tree) and `INBOX_MERGEABLE_SLEEP` (retry sleep) are test hooks.
- Collector needs `mix` on PATH always (root audit); use `--skip-demo-audit` for a fast run (records `hex_audit_demo` unreadable, which the validator must reject at closure). A full run takes about 42 s.
- Plan 03 owns the `ci-script-tests` wiring of `scripts/ci/test_collect_inbox.sh`; the harness needs only bash, jq, awk, sed, cksum (no Elixir, network or gh login).
- `mix hex.audit` writes its auth-expiry notice to stdout and "Found packages with security advisories" to stderr; parsers key on the section markers, not the exit code alone.

## Known Stubs

None.

## Threat Flags

None. No new network endpoint, auth path or schema; all GitHub access is GET-only and proven by the tripwire.

## Self-Check: PASSED

- scripts/maintainer/collect_inbox.sh and scripts/ci/test_collect_inbox.sh exist.
- Commits 9dbeae4e, 861812d5, 818399d9 are ancestors of HEAD.
