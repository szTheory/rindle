---
phase: 139-exact-head-readiness-closure
reviewed: 2026-10-29T17:21:37Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - lib/rindle/ops/runtime_checks.ex
  - lib/rindle/ops/runtime_checks/ownership_checks.ex
  - scripts/maintainer/exact_head_readiness.py
  - scripts/maintainer/readiness_acceptance.py
  - scripts/maintainer/readiness_retention.py
  - scripts/maintainer/readiness_github.py
  - scripts/maintainer/readiness_process.py
  - scripts/maintainer/readiness_subject.py
  - scripts/maintainer/readiness_nightly_capture.py
  - scripts/maintainer/readiness_closure.py
  - scripts/maintainer/readiness_adoption.py
  - scripts/maintainer/collect_readiness_runs.py
  - scripts/maintainer/collect_readiness_remote.py
  - scripts/maintainer/validate_exact_head_readiness.exs
  - scripts/maintainer/readiness_workflow.exs
  - scripts/maintainer/readiness_nightly.exs
  - .github/workflows/readiness-retention.yml
findings:
  critical: 0
  warning: 2
  info: 0
  total: 2
status: issues_found
---

# Phase 139: Code Review Report

**Reviewed:** 2026-10-29T17:21:37Z  
**Depth:** standard  
**Files Reviewed:** 17  
**Status:** issues_found

## Summary

Reviewed the requested Doctor ownership checks and readiness qualification, collection, validation, retention, and acceptance paths. The two schema-check false-green paths are preexisting defects, not Phase 139 regressions: `git blame` attributes both to `47d1d5dc` (2026-08-22), and the `16bb76a7^..16bb76a7` diff changes neither function. Phase 139 changed the legacy migration-history handling in this file, not these predicates.

The retained execution is not shown to be affected. The accepted subject's shipped migration declares `last_known_offset` as `NOT NULL DEFAULT 0` and creates the expiry index with `WHERE upload_strategy = 'resumable'`. Its retained execution-mode bundle binds the run-built package, records the generated consumer as passed, and records `mix rindle.doctor` as passed with exit 0. Thus there is no evidence that either permissive predicate admitted a bad schema in the accepted run. The defects remain relevant to future diagnosis of externally drifted schemas; they do not establish an unmet Phase 139 must-have or a reason to reopen the historical verdict. This report does not assert readiness for the current worktree.

## Warnings

### WR-01: A nonzero offset default can satisfy the Doctor check (preexisting)

**File:** `lib/rindle/ops/runtime_checks/ownership_checks.ex:363-366`  
**Issue:** This code, present since `47d1d5dc` and unchanged by Phase 139, accepts any `column_default` containing the character `0`. PostgreSQL defaults such as `10` or `100` therefore pass the `last_known_offset must be NOT NULL DEFAULT 0` requirement. This can misdiagnose an externally drifted schema, although the retained accepted package declares default zero and its real qualification passed.
**Fix:** As a follow-up schema-drift hardening change, normalize PostgreSQL's rendered default expression and require exactly zero (including only explicitly supported equivalent casts), for example by parsing the integer expression or matching `^0(?:::bigint)?$` after whitespace normalization.

### WR-02: An unfiltered expiry index can satisfy the Doctor check (preexisting)

**File:** `lib/rindle/ops/runtime_checks/ownership_checks.ex:386-392`  
**Issue:** This code, present since `47d1d5dc` and unchanged by Phase 139, checks only that the index definition contains `session_uri_expires_at`, `upload_strategy`, and `resumable`. A regular index such as `CREATE INDEX resumable_idx ON media_upload_sessions (session_uri_expires_at, upload_strategy)` passes without the required `WHERE upload_strategy = 'resumable'` predicate. This can misdiagnose an externally drifted schema; the accepted subject's shipped migration creates the filtered index and the retained real qualification passed.
**Fix:** As a follow-up schema-drift hardening change, parse or normalize the `pg_indexes.indexdef` predicate and require the expiry column plus the actual `WHERE upload_strategy = 'resumable'` clause; do not infer the predicate from the index name or indexed columns.

---

_Reviewed: 2026-10-29T17:21:37Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
