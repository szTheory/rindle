# Phase 134: Dependency, Security, and Inbox Disposition — Context

**Gathered:** 2026-10-15 (orchestrator-authored; the user directed "follow your recommendations")
**Requirements:** INBOX-01, INBOX-02, SEC-09, DEPS-01

## Snapshot at planning time (live, read-only)

- Open issues: **#42**, the async-isolation flake. It is evidence-gated, and TEST-08 in Phase 136 owns its experiment.
- Open PRs:
  - **#120**: `ci:` branch-protection guard fix. Ours, in CI.
  - **#113**: actions group.
  - **#112**: dev-dependencies group.
  - **#109**: ex_aws 2.7.0.
  - **#108**: req 0.7.4.
  - **#105**: ecto_sql 3.14.0.
  - **#95**: muontrap 2.0.0. The 2026-08-28 triage classified it as incompatible: Rindle passes v1-only `cgroup_controllers` and `cgroup_sets` options.
- Advisory sources:
  - `mix deps.audit` (mix_audit) runs in the Quality CI job.
  - `mix hex.audit` (retired packages) is not wired.
  - **GitHub Dependabot alerts are disabled** for the repo (HTTP 403).
  - The local `gh` token lacks `admin:repo_hook`, so code-scanning reads fail.
- Prior triage: `.planning/INBOX-TRIAGE.md` (2026-08-28), a prose table. It is superseded by this phase's machine-checkable ledger.

## Locked decisions

**D-134-01 Scope fence (lesson of Phase 133, which took 213 plans).**
- Target **≤6 plans**, and no plan over 3 tasks.
- No bespoke qualification, authorization or journal framework.
- The evidence authorities are live GitHub and GitHub Actions on `main`, read with `gh`, plus `mix` tasks.
- When a plan halts twice on the same gate, stop and rescope rather than add plans.

**D-134-02 No `.planning/phases/134-*` paths in live code.** Scripts, tests and workflows must not read the phase directory. Archiving it must not redden CI, which is the Phase 133 debt. Durable artifacts live at stable paths:
- Collectors and validators: `scripts/maintainer/`.
- Tests: `scripts/ci/test_*.sh` (fake `gh`, the existing pattern) and/or `test/install_smoke/`.
- The ledger: `.planning/INBOX-LEDGER.json`, a top-level stable path that replaces the `INBOX-TRIAGE.md` table, with a pointer left behind.

**D-134-03 INBOX-01 collector.** A single read-only script, `scripts/maintainer/collect_inbox.sh`, built on `gh` + `jq` + `mix`.
- **Output:** one timestamped JSON inventory with a schema id, `collected_at`, `repo` and `main_sha`. It covers:
  - open issues: number, title, labels, updated_at
  - open PRs: number, head SHA, author, base, mergeable state, `CI Summary` conclusion on that head, and changed manifest files
  - advisories: `mix deps.audit` and `mix hex.audit` results, plus GitHub Dependabot alerts **or an explicit `source_disabled` / `unreadable` record, never an implicit zero**
  - branch protection on `main`: required contexts, strict, enforce_admins, or `unreadable`
- **Read-only proof:** only GET calls are allowed. The fake-`gh` test fails on any `-X`/`--method` other than GET, and on any `gh pr|issue <mutating verb>`.
- **Fail closed:** missing `gh` auth or a failed API page is non-zero, not a partial inventory.

**D-134-04 INBOX-02 ledger and validator.**
- `scripts/maintainer/validate_inbox_ledger.sh` (or `.exs`) checks the ledger against a **fresh** inventory. Each open issue and PR has exactly one disposition from `merge | close | retain | supersede | defer`.
- `supersede` names its successor.
- `defer` carries an evidence gate and an executable trigger, either a date or a checkable condition.
- **Rejections:**
  - a missing item, or a ledger entry for an item no longer open, unless that entry records a terminal disposition matching the item's actual state
  - duplicates
  - an entry bound to a head SHA that differs from the PR's current head (stale)
  - an inventory older than a bound (default 24h)
- Inbox zero is **not** required.

**D-134-05 Remote mutations are authorized actions, never credit.**
- Merging, closing, commenting, relabelling and enabling repo settings each need the user's explicit go-ahead in chat (AGENTS.md automation-first).
- Merges are run by the user: `! gh pr merge N --squash --subject "<conventional>"`. Auto mode blocks agent merges, and the repo is squash-only.
- Requirement credit comes only from the validator and collector passing on fresh live data.

**D-134-06 SEC-09 advisories.**
- Each advisory gets a ledger record:
  - id (GHSA/CVE or a retired-package id)
  - package
  - dependency path (`mix deps.tree`)
  - supported-runtime reachability: runtime / dev-test-only / optional-dep, judged from `only:`/`optional:` in `mix.exs`, `mix.lock` and call sites
  - fix version
  - one of: **resolved**, verified by the advisory being absent from a fresh collector run, or **bounded exception**, which carries an expiry date and trigger that the validator enforces (an expired exception fails)
- Wire `mix hex.audit` alongside `mix deps.audit` in CI.
- **Enabling Dependabot alerts** (`gh api -X PUT repos/szTheory/rindle/vulnerability-alerts`) is an authorized-action checkpoint, and the plan must offer it. If it is declined, the collector records `source_disabled` and the validator accepts that only with a ledger-recorded rationale.

**D-134-07 DEPS-01 risk groups.**
- One Dependabot PR is one risk group. Runtime deps land individually: ecto_sql, req and ex_aws are separate. The actions and dev-dependencies groups stay grouped.
- A group lands only after both of these pass:
  - its PR's merge-blocking CI (Quality, Integration, Proof, Package Consumer, Adopter, behind `CI Summary`)
  - the **post-merge `main` push run**, which includes the main-only lanes (Package Consumer Full, Cohort Smoke, Adoption E2E). Those lanes skip on PRs; see the project memory note about CI lanes running only on main.
- **Twin gates:** no twin exists yet (that is Phase 137), so "relevant twin evidence" is recorded as `not-applicable: twin not built (Phase 137)`. It must not be claimed as passed.
- **Attribution:** each merge is one squash commit whose subject names the group. The ledger records merge SHA and post-merge run id.
- If a red appears after a merge, revert that single commit.
- **#95 (MuonTrap 2.0) is a major/breaking bump:**
  - disposition `close` with an explanatory comment, or `defer` with a trigger tied to a chartered cgroup-v2 migration
  - do **not** attempt the migration in this phase
- Dependabot rebases: use `@dependabot rebase` comments (an authorized action) or `gh pr update-branch`.

**D-134-08 Commit prefixes.**
- `ci:`, `build(deps):`, `docs:` and `test:` must not cut a release.
- Version-coupled assertions must derive the version from `mix.exs`. This is the 0.4.7 lesson.

## Out of scope

- The GitHub App migration for release PATs (`.planning/todos/pending/2026-10-15-replace-release-pats-with-github-app.md`, due about 2026-11-15).
- Repo-wide hygiene and craft work (Phase 135).
- The issue #42 experiment (TEST-08, Phase 136).

## Canonical refs

- `.planning/REQUIREMENTS.md` (INBOX-01, INBOX-02, SEC-09, DEPS-01)
- `.planning/ROADMAP.md`, Phase 134 success criteria
- `.planning/INBOX-TRIAGE.md` (prior dispositions)
- `.github/dependabot.yml`
- `.github/workflows/ci.yml`: Quality `mix deps.audit` step, CI Summary
- `scripts/ci/test_nightly_incident.sh`: the fake-`gh` test pattern
- `scripts/setup_branch_protection.sh`, `config/ci_required_checks.json`
- AGENTS.md: automation-first, green-main, PR-first
