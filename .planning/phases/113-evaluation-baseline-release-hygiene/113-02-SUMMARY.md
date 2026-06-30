---
phase: 113-evaluation-baseline-release-hygiene
plan: 02
subsystem: infra
tags: [github-actions, release-please, ci, release-hygiene, jasonetco, actionlint, install-smoke]

# Dependency graph
requires:
  - phase: 113-01
    provides: EVAL baseline + Track-A release-hygiene context (D-06/D-09 decisions)
provides:
  - "Release-train drift guard workflow (.github/workflows/release-train-drift.yml): daily cron + dispatch, self-files/closes a rolling issue when main drifts ahead of the last rindle-v* tag with no open release PR (D-06a)"
  - "Issue template (.github/ISSUE_TEMPLATE/release-train-drift.md) with the close-step's searchable title substring"
  - "RELEASE_PLEASE_TOKEN validity guard step in release.yml (gh api user auth check + Actions-scope probe) that fails loud on a present-but-invalid token (D-06b)"
  - "install_smoke meta-test (release_guard_meta_test.exs) locking both guards OFF the required CI path and ci.yml name: CI / CI Summary byte-stable (D-09)"
affects: [release, ci, release-hygiene, 113-03, 113-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Non-required cron+dispatch drift guard with JasonEtco/create-an-issue open-update-close rolling-issue lifecycle (sibling verify-published-release.yml idiom)"
    - "Token-validity preflight: secret read via env: only, gh api user + Actions-API probe, fail-loud ::error:: with rotation hint, never echoed"
    - "Grep-meta install_smoke test locking a release-coupling invariant inside mix test (OBS-02 pattern)"

key-files:
  created:
    - .github/workflows/release-train-drift.yml
    - .github/ISSUE_TEMPLATE/release-train-drift.md
    - test/install_smoke/release_guard_meta_test.exs
  modified:
    - .github/workflows/release.yml

key-decisions:
  - "Used the run-body emptiness check (read secret via env:, exit 0 when empty) instead of a step-level `if: secrets.RELEASE_PLEASE_TOKEN != ''` — Pitfall 5 (secrets-in-if may not evaluate; bar is zero new actionlint findings)"
  - "Token guard probes BOTH gh api user (auth) AND repos/$GH_REPO/actions/permissions (Actions scope) — a fine-grained PAT can pass auth yet lack Actions:write, the confirmed 0.3.2 dispatch-403 gap"
  - "Drift guard pinned to contents:read + issues:write (least-privilege, T-113-05); predicate keyed on `git describe --match rindle-v*` + `gh pr list` for the release-please component branch"

patterns-established:
  - "Pattern 1: rolling-issue drift guard — cron+dispatch, JasonEtco SHA-pinned open-update on schedule, close-on-recovery via gh issue close, fail-on-drift for manual dispatch visibility"
  - "Pattern 2: token-validity preflight inside an existing release job (additive step, no new required check)"
  - "Pattern 3: meta-test isolates the ci-summary needs: block and refutes guard presence + asserts name: CI / CI Summary byte-stability"

requirements-completed: [HYGIENE-01]

coverage:
  - id: D1
    description: "release-train-drift.yml ships (cron+dispatch, contents:read/issues:write, rindle-v* predicate, JasonEtco-wired) + issue template with searchable title"
    requirement: "HYGIENE-01"
    verification:
      - kind: integration
        ref: "test/install_smoke/release_guard_meta_test.exs#D-06a: release-train-drift.yml ships, runs on cron + dispatch, least-privilege, JasonEtco-wired"
        status: pass
      - kind: integration
        ref: "test/install_smoke/release_guard_meta_test.exs#D-06a: the issue template ships with the close-step's searchable title substring"
        status: pass
    human_judgment: false
  - id: D2
    description: "release.yml token-validity guard (gh api user auth + Actions-scope probe) fails loud, token line + secret-non-echo preserved"
    requirement: "HYGIENE-01"
    verification:
      - kind: integration
        ref: "test/install_smoke/release_guard_meta_test.exs#D-06b: release.yml validates RELEASE_PLEASE_TOKEN (auth + Actions scope) before Run Release Please"
        status: pass
      - kind: integration
        ref: "test/install_smoke/release_guard_meta_test.exs#D-06b: the token guard is a STEP, not a new top-level job / required check name"
        status: pass
    human_judgment: false
  - id: D3
    description: "D-09 invariant locked: neither guard in ci-summary needs:, ci.yml name: CI line 1 + CI Summary byte-stable, zero new actionlint findings"
    requirement: "HYGIENE-01"
    verification:
      - kind: integration
        ref: "test/install_smoke/release_guard_meta_test.exs#D-09: the ci-summary `needs:` block does NOT reference release-train-drift"
        status: pass
      - kind: integration
        ref: "test/install_smoke/release_guard_meta_test.exs#D-09 GATE-BYTE-STABLE: ci.yml line 1 is `name: CI` and the ci-summary job carries `name: CI Summary`"
        status: pass
      - kind: other
        ref: "actionlint .github/workflows/ — total findings unchanged at 7 (zero new); release.yml + release-train-drift.yml both clean"
        status: pass
    human_judgment: false

# Metrics
duration: 5min
completed: 2026-06-30
status: complete
---

# Phase 113 Plan 02: D-06 Release-Recurrence Guards + D-09 Required-Path Lock Summary

**Two D-06 release-train recurrence guards (a cron drift workflow that self-files a rolling issue, and a RELEASE_PLEASE_TOKEN validity preflight that fails loud on an invalid/Actions-scopeless token) plus an install_smoke meta-test that locks both OFF the sole required CI path.**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-06-30T11:32:58Z
- **Completed:** 2026-06-30T11:37:51Z
- **Tasks:** 3
- **Files modified:** 4 (3 created, 1 modified)

## Accomplishments
- **D-06a drift guard:** a non-required `release-train-drift.yml` (daily cron `23 7 * * *` + `workflow_dispatch`, `contents:read`/`issues:write` only) that resolves the last `rindle-v*` tag, counts releasable `feat:`/`fix:` commits ahead, checks for an open release-please PR, and on drift opens/updates a rolling issue (JasonEtco SHA-pinned `1b14a70…`), closes it on recovery, and fails red on manual dispatch.
- **D-06b token guard:** an additive step in `release.yml`'s `release-please` job, before "Run Release Please", that validates `RELEASE_PLEASE_TOKEN` via `gh api user` AND probes `repos/$GH_REPO/actions/permissions` — catching the confirmed 0.3.2 dispatch-403 gap where a PAT authenticates but lacks `Actions:write`. Fails loud with a rotation hint; the secret is read via `env:` only and never echoed.
- **D-09 lock:** `release_guard_meta_test.exs` (6 tests, all green in default `mix test`) asserts the guards ship + are wired, refutes `release-train-drift` in the `ci-summary` `needs:` list, and confirms `ci.yml` `name: CI` (line 1) + `CI Summary` are byte-stable.
- Zero new actionlint findings (held at the 7 pre-existing); `ci.yml` byte-untouched.

## Task Commits

Each task was committed atomically:

1. **Task 1: release-train-drift workflow + issue template** - `9c4c5bf` (feat)
2. **Task 2: RELEASE_PLEASE_TOKEN validity guard in release.yml** - `b76a55a` (feat)
3. **Task 3: install_smoke meta-test locking D-06/D-09** - `dff44a9` (test)

## Files Created/Modified
- `.github/workflows/release-train-drift.yml` (created) - daily cron + dispatch drift guard; JasonEtco open-update-close rolling-issue lifecycle; least-privilege.
- `.github/ISSUE_TEMPLATE/release-train-drift.md` (created) - rolling-issue template with the close-step's searchable title substring; also creates the new `.github/ISSUE_TEMPLATE/` dir.
- `.github/workflows/release.yml` (modified) - additive token-validity guard step (auth + Actions-scope probe) before Run Release Please; original `secrets.RELEASE_PLEASE_TOKEN || github.token` line unchanged.
- `test/install_smoke/release_guard_meta_test.exs` (created) - 6-test grep-meta lock for D-06a, D-06b, and the D-09 required-path invariant.

## Decisions Made
- **Run-body emptiness check over step-level `if: secrets.* != ''`** (Pitfall 5): secrets in a step `if:` may not evaluate on all runners and risked a new actionlint finding. The guard reads the secret via `env: GH_TOKEN` and `exit 0`s when empty (relying on `github.token`), preserving the zero-new-findings bar.
- **Dual probe (auth + Actions scope)** per the updated Task 2: `gh api user` alone passes for a PAT lacking `Actions:write`, which is exactly what 403'd the 0.3.2 publish-dispatch. The Actions-API probe is an additional capability check, not a replacement.
- **Least-privilege drift permissions** (`contents:read` + `issues:write`): the predicate is read-only `git log`/`gh pr list`; the only write is the rolling issue (T-113-05).

## Deviations from Plan

None - plan executed exactly as written. No Rule 1-4 deviations; no auto-fixes required.

## Issues Encountered
- The Task 2 `<verify>` block's `head -1 release.yml | grep 'name: Release'` and `grep -q 'token: ${{ ... }}'` both reported non-OK on a literal run — but this is a **verify-harness artifact**, not a defect: `release.yml` opens with a leading topology comment block (line 1 is `#`, `name: Release` is on line 9), and `grep -q` (BRE) mis-handles the `${{ }}`/`||` metacharacters. Confirmed the real intent with `grep -Eq '^name: Release$'` (present) and `grep -Fq 'token: ${{ secrets.RELEASE_PLEASE_TOKEN || github.token }}'` (unchanged). No file change was warranted; the `done` criteria are all met.

## User Setup Required
None - no external service configuration required. (The guards become operative on the next scheduled run / next push to main; no secrets or dashboard changes are introduced by this plan.)

## Next Phase Readiness
- Both D-06 recurrence guards and the D-09 lock are shipped and merge-blocking-test-covered. The remaining 113 plans (03/04) cover the EVAL doc, the truth-sweep, SEED frontmatter, and the operational 0.3.2 cut (rotate token → observe pipeline) — this plan's token guard is the preflight that will surface a bad token loudly during that cut.
- No blockers.

---
*Phase: 113-evaluation-baseline-release-hygiene*
*Completed: 2026-06-30*

## Self-Check: PASSED
- FOUND: .github/workflows/release-train-drift.yml
- FOUND: .github/ISSUE_TEMPLATE/release-train-drift.md
- FOUND: .github/workflows/release.yml (modified)
- FOUND: test/install_smoke/release_guard_meta_test.exs
- FOUND commit: 9c4c5bf (Task 1)
- FOUND commit: b76a55a (Task 2)
- FOUND commit: dff44a9 (Task 3)
