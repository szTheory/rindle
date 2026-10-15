# Phase 134: Dependency, Security, and Inbox Disposition - Research

**Researched:** 2026-10-15
**Domain:** GitHub-state inventory (gh + jq), Hex advisory auditing (`mix hex.audit`), Dependabot PR landing hygiene, executable disposition ledger
**Confidence:** HIGH on live state and tooling behavior (every number below was read live this session); MEDIUM on Dependabot command semantics and release-please treatment of `build(deps)` (training/partial docs, tagged `[ASSUMED]`)

All GitHub access was read-only (GET). No commits, comments, labels, merges or setting changes were made. Probes that needed `mix deps.get` used scratchpad deps paths; `mix.lock` files in the worktree are unchanged (`git status` clean apart from the untracked phase dir).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-134-01 Scope fence (lesson of Phase 133, which took 213 plans).**
- Target **<=6 plans**, and no plan over 3 tasks.
- No bespoke qualification, authorization or journal framework.
- The evidence authorities are live GitHub and GitHub Actions on `main`, read with `gh`, plus `mix` tasks.
- When a plan halts twice on the same gate, stop and rescope rather than add plans.

**D-134-02 No `.planning/phases/134-*` paths in live code.** Scripts, tests and workflows must not read the phase directory. Archiving it must not redden CI, which is the Phase 133 debt. Durable artifacts live at stable paths:
- Collectors and validators: `scripts/maintainer/`.
- Tests: `scripts/ci/test_*.sh` (fake `gh`, the existing pattern) and/or `test/install_smoke/`.
- The ledger: `.planning/INBOX-LEDGER.json`, a top-level stable path that replaces the `INBOX-TRIAGE.md` table, with a pointer left behind.

**D-134-03 INBOX-01 collector.** A single read-only script, `scripts/maintainer/collect_inbox.sh`, built on `gh` + `jq` + `mix`.
- **Output:** one timestamped JSON inventory with a schema id, `collected_at`, `repo` and `main_sha`. It covers: open issues (number, title, labels, updated_at); open PRs (number, head SHA, author, base, mergeable state, `CI Summary` conclusion on that head, and changed manifest files); advisories (`mix deps.audit` and `mix hex.audit` results, plus GitHub Dependabot alerts **or an explicit `source_disabled` / `unreadable` record, never an implicit zero**); branch protection on `main` (required contexts, strict, enforce_admins, or `unreadable`).
- **Read-only proof:** only GET calls are allowed. The fake-`gh` test fails on any `-X`/`--method` other than GET, and on any `gh pr|issue <mutating verb>`.
- **Fail closed:** missing `gh` auth or a failed API page is non-zero, not a partial inventory.

**D-134-04 INBOX-02 ledger and validator.**
- `scripts/maintainer/validate_inbox_ledger.sh` (or `.exs`) checks the ledger against a **fresh** inventory. Each open issue and PR has exactly one disposition from `merge | close | retain | supersede | defer`.
- `supersede` names its successor.
- `defer` carries an evidence gate and an executable trigger, either a date or a checkable condition.
- **Rejections:** a missing item, or a ledger entry for an item no longer open, unless that entry records a terminal disposition matching the item's actual state; duplicates; an entry bound to a head SHA that differs from the PR's current head (stale); an inventory older than a bound (default 24h).
- Inbox zero is **not** required.

**D-134-05 Remote mutations are authorized actions, never credit.**
- Merging, closing, commenting, relabelling and enabling repo settings each need the user's explicit go-ahead in chat (AGENTS.md automation-first).
- Merges are run by the user: `! gh pr merge N --squash --subject "<conventional>"`. Auto mode blocks agent merges, and the repo is squash-only.
- Requirement credit comes only from the validator and collector passing on fresh live data.

**D-134-06 SEC-09 advisories.**
- Each advisory gets a ledger record: id (GHSA/CVE or a retired-package id); package; dependency path (`mix deps.tree`); supported-runtime reachability: runtime / dev-test-only / optional-dep, judged from `only:`/`optional:` in `mix.exs`, `mix.lock` and call sites; fix version; one of: **resolved**, verified by the advisory being absent from a fresh collector run, or **bounded exception**, which carries an expiry date and trigger that the validator enforces (an expired exception fails).
- Wire `mix hex.audit` alongside `mix deps.audit` in CI.
- **Enabling Dependabot alerts** (`gh api -X PUT repos/szTheory/rindle/vulnerability-alerts`) is an authorized-action checkpoint, and the plan must offer it. If it is declined, the collector records `source_disabled` and the validator accepts that only with a ledger-recorded rationale.

**D-134-07 DEPS-01 risk groups.**
- One Dependabot PR is one risk group. Runtime deps land individually: ecto_sql, req and ex_aws are separate. The actions and dev-dependencies groups stay grouped.
- A group lands only after both of these pass: its PR's merge-blocking CI (Quality, Integration, Proof, Package Consumer, Adopter, behind `CI Summary`), and the **post-merge `main` push run**, which includes the main-only lanes (Package Consumer Full, Cohort Smoke, Adoption E2E). Those lanes skip on PRs; see the project memory note about CI lanes running only on main.
- **Twin gates:** no twin exists yet (that is Phase 137), so "relevant twin evidence" is recorded as `not-applicable: twin not built (Phase 137)`. It must not be claimed as passed.
- **Attribution:** each merge is one squash commit whose subject names the group. The ledger records merge SHA and post-merge run id.
- If a red appears after a merge, revert that single commit.
- **#95 (MuonTrap 2.0) is a major/breaking bump:** disposition `close` with an explanatory comment, or `defer` with a trigger tied to a chartered cgroup-v2 migration; do **not** attempt the migration in this phase.
- Dependabot rebases: use `@dependabot rebase` comments (an authorized action) or `gh pr update-branch`.

**D-134-08 Commit prefixes.**
- `ci:`, `build(deps):`, `docs:` and `test:` must not cut a release.
- Version-coupled assertions must derive the version from `mix.exs`. This is the 0.4.7 lesson.

### Claude's Discretion
CONTEXT.md has no explicit "Claude's Discretion" section. Open to recommendation (not locked): collector run location, ledger JSON shape, bash vs `.exs`, freshness bounds, executable-trigger vocabulary, landing order, plan/wave breakdown.

### Deferred Ideas (OUT OF SCOPE)
- The GitHub App migration for release PATs (`.planning/todos/pending/2026-10-15-replace-release-pats-with-github-app.md`, due about 2026-11-15).
- Repo-wide hygiene and craft work (Phase 135).
- The issue #42 experiment (TEST-08, Phase 136).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INBOX-01 | Timestamped read-only inventory of every open issue, PR, check state, advisory, branch-protection setting | Collector design (Q4): REST pagination, per-head `CI Summary` selection by max `completed_at`, `/protection` with partial fallback, advisory source records |
| INBOX-02 | Every open issue/PR has exactly one merge/close/retain/supersede/evidence-gated defer disposition | Ledger + validator design (Q5): head-SHA binding, terminal-entry lookups, executable triggers, bash+jq harness |
| SEC-09 | Every reported advisory has dependency path, reachability, fix version, resolved/bounded exception | Live `mix hex.audit` finding set (12 distinct advisories), reachability table, fix versions from OSV, `ignore_advisories` + expiry binding |
| DEPS-01 | Dependency updates land in independently attributable risk groups after toolchain/package-consumer/contract/twin evidence | Per-PR lock-delta analysis (overlaps found), gate-to-job map, post-merge run lookup by squash SHA, landing order |
</phase_requirements>

## Summary

The live state differs from CONTEXT.md's snapshot in four ways that change the plan. (1) **`mix hex.audit` (Hex 2.5.1) reports 11 advisories on the root `mix.lock` and exits 1, while `mix deps.audit` (mix_audit 2.1.5) reports "No vulnerabilities found."** The two sources disagree; `deps.audit` silence is not evidence of absence. The demo lock (`examples/adoption_demo/mix.lock`, not covered by Dependabot or by any audit) adds a 12th, HIGH-severity `bandit` advisory with **no released fix**. (2) **GitHub's native dependency graph has no Hex/mix.lock parser** (sources agree; `dependency-graph/sbom` is 404 here), so enabling Dependabot alerts alone would most likely still yield zero Elixir alerts. `mix hex.audit` is the real advisory source; Dependabot alerts is a low-value, optional source that the collector must record as `source_disabled`. (3) **Three of the six Dependabot PRs are not independently attributable as opened**: #109's lock delta contains #108's (req+mint), and #112's "dev-dependencies" delta contains #105's (ecto+ecto_sql) plus runtime `decimal`. They shrink only after the earlier PR lands and Dependabot rebases. (4) **Every Dependabot head is `behind` main** (strict protection is on), so the existing green `CI Summary` results are stale evidence; #113 and #109 are red; and the latest `main` push run (6ef86d38) is red on the main-only `Adoption Demo E2E` lane (a MuonTrap-timeout flake on a docs-only commit) while `CI Summary` is green. Post-merge attribution therefore needs per-job comparison against a baseline, not "run is green".

The standard approach is bash + jq + `gh` for the collector and validator (they must run in `ci-script-tests`, which has no Elixir toolchain), a fake-`gh` + fake-`mix` PATH-shim harness following `scripts/ci/test_nightly_incident.sh`, and a top-level `.planning/INBOX-LEDGER.json`. Merge-blocking CI tests exercise behavior with fixtures; the freshness/expiry/live-binding checks run only against live data at phase closure, because putting live-data or wall-clock checks in the PR lane would redden unrelated PRs.

**Primary recommendation:** Build `collect_inbox.sh` + `validate_inbox_ledger.sh` + a small `dep_landing_evidence.sh` (lock delta + per-job post-merge conclusions for a squash SHA) in bash/jq with fake-gh harnesses wired into `ci-script-tests`; wire `mix hex.audit` as an advisory (non-failing) Quality step; clear the 11 root advisories with maintainer-authored per-package lock-only `build(deps):` PRs and land the Dependabot PRs one at a time, serially, after rebasing; close #95 via a `dependabot.yml` major-version ignore plus an authorized close comment.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Inventory collection (issues/PRs/checks/protection) | Maintainer CLI (`scripts/maintainer`, local, admin `gh` token) | CI read-only job (degraded: protection/alerts `unreadable`) | Only a maintainer token reads `/protection` and Dependabot alerts; `github.token` cannot |
| Advisory detection | `mix hex.audit` (Hex/OSV EEF data) in Quality + collector | `mix deps.audit` (mirego DB, lagging) | hex.audit saw 11 findings deps.audit missed |
| Disposition ledger | Repo file `.planning/INBOX-LEDGER.json` | — | Stable top-level path, survives phase archiving |
| Ledger validation | Maintainer CLI against fresh inventory | Fixture harness in `ci-script-tests` (merge-blocking) | Live data and wall-clock must not gate PRs |
| Dependency landing | Dependabot PRs + maintainer lock-only PRs through squash merge | `ci.yml` PR lane, then push:main run | Strict protection forces serial up-to-date merges |
| Post-merge evidence | GitHub Actions push:main run, read via REST | `dep_landing_evidence.sh` | Main-only lanes never run on PRs |
| Remote mutations (merge/close/comment/settings) | User (authorized, chat-confirmed) | — | D-134-05 |

## Standard Stack

### Core
| Tool | Version (verified) | Purpose | Why Standard |
|------|--------------------|---------|--------------|
| `gh` | 2.101.0 [VERIFIED: `gh --version`] | All GitHub reads (`gh api` GET) | Existing pattern (`manage_nightly_incident.sh`, `setup_branch_protection.sh`) |
| `jq` | local 1.7.1-apple; GitHub ubuntu-22.04 runner likely 1.6 [ASSUMED] | JSON assembly, `-S` deterministic output | Existing pattern; **avoid jq 1.7-only builtins** (`pick`, `abs`, `toarray`, `trim`) |
| `mix hex.audit` | Hex 2.5.1 on Elixir 1.17.3/OTP 27 [VERIFIED: `mix hex.info`] | Advisory + retirement audit | Reports EEF/OSV advisories; supports `ignore_advisories` |
| `mix deps.audit` | mix_audit 2.1.5 [VERIFIED: mix.lock:41] | Existing advisory step (non-failing) | Already in Quality; keep, do not rely on |
| bash | 3.2-compatible code (macOS system) / 5.x | Scripts | Existing harness style (`set -euo pipefail`, `local`, no `mapfile`/assoc arrays) |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `api.osv.dev/v1/vulns/<id>` | Fix versions for ledger records | Research/ledger authoring only; not in CI (network, non-GitHub) |
| `hex.pm/api/packages/<pkg>` | Latest/fixed release verification | Same |
| `mix deps.tree [--only prod]` | Dependency path + reachability | Ledger authoring; `--only prod` is the discriminator |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| bash+jq validator | `.exs` (like `validate_evidence_census.exs`) | `.exs` needs the Elixir toolchain; `ci-script-tests` is "pure bash + jq, no project toolchain" [CITED: .github/workflows/ci.yml:1453-1455]. Use bash+jq. |
| Dependabot alerts | `erlef/mix-dependency-submission` Action | Would feed mix.lock to GitHub's graph so alerts work; adds a third-party Action, a workflow, and a token permission. Out of the <=6-plan fence; record as a deferred option. |
| GHSA global DB cross-check (`GET /advisories?ecosystem=erlang`) | skip | Works unauthenticated and is `erlang`-ecosystem aware [VERIFIED: gh api output, cowlib GHSAs], but duplicates hex.audit; optional only. |

**Installation:** nothing new. No new packages are introduced in this phase; only existing locked packages move. All target versions below were confirmed against `hex.pm/api` this session.

## Package Legitimacy Audit

No external package is newly installed by this phase (lock-only bumps of already-locked, long-established packages). `gsd-tools package-legitimacy check` was therefore not run. Version targets verified directly against the registry:

| Package | Locked | Target | Registry fact | Disposition |
|---------|--------|--------|---------------|-------------|
| cowlib | 2.19.0 | 2.21.0 (latest) | hex.pm API latest_stable_version 2.21.0 | Approved (existing dep) |
| mint | 1.9.3 | 1.10.2+ (latest 1.11.0) | hex.pm API | Approved |
| decimal | 3.1.1 | 3.1.2+ (latest 3.2.0) | hex.pm API | Approved |
| lazy_html | 0.1.12 | 0.1.13 | hex.pm API | Approved |
| muontrap | 1.7.0 | (stay 1.x) | 2.0.0 and 2.0.1 (2026-10-06) exist; 1.8.0 exists | Hold |
| req | 0.7.3 | 0.7.4 proposed; **0.7.5 exists (2026-10-06)** | hex.pm API / hexdocs changelog | Approved |

**Packages removed (SLOP):** none. **Flagged (SUS):** none.

## Live State Findings (answers to Q1, with evidence)

### Open items (all read this session at main = `6ef86d38`, equal to `origin/main`)

Open issues: only **#42** (labels `[]`, updated 2026-08-28) [VERIFIED: `gh issue list`]. Previously-triaged #88 (closed 2026-10-13/15, `state_reason: completed`), #93 (PR, closed unmerged 2026-10-13), #98 (PR, closed unmerged 2026-08-28) are no longer open [VERIFIED: `gh api repos/.../issues/N`]. `INBOX-TRIAGE.md` is stale: its rows #93/#98/#88 are all terminal.

### Dependabot / open PR matrix

| PR | Head SHA (short) | Files | Lock delta (exact packages) | mergeable_state | Latest `CI Summary` on head | Notes |
|----|------------------|-------|-----------------------------|-----------------|------------------------------|-------|
| #95 muontrap | d76291a2 | `mix.exs`, `mix.lock` | muontrap 1.7.0 -> 2.0.0; `mix.exs` `{:muontrap, "~> 1.7"}` -> `"~> 2.0"` | behind | success (cgroups disabled in CI, so breaking path unexercised) | Public-contract change (mix.exs requirement). 2.0.1 already out (2026-10-06). |
| #105 ecto_sql | e373b3e2 | `mix.lock` | ecto 3.13.6->3.14.2, ecto_sql 3.13.5->3.14.0 | behind | success | base f2ecc92a (Aug 28). Runtime core dep. |
| #108 req | a9f6b293 | `mix.lock` | mint 1.9.3->1.10.0, req 0.7.3->0.7.4 | behind | **two check-runs: failure (cancelled run) then success (later run)** | Optional dep (`optional: true`). Req 0.7.5 exists. |
| #109 ex_aws | a919a4d6 | `mix.lock` | ex_aws 2.6.1->2.7.0 **+ mint + req (same as #108)** | behind | **failure x2; `Package Consumer Proof Matrix` failed**; job log unavailable ("log not found") | Not attributable as opened. |
| #112 dev-dependencies | c57e9e7c | `mix.lock` | credo, dialyxir, earmark_parser, erlex, ex_doc, ex_machina, lazy_html, makeup, mox **+ decimal 3.1.1->3.2.0 (runtime) + ecto + ecto_sql (same as #105)** | behind (base 46e4dbc3) | success | Mixed group. `mix.exs` untouched. |
| #113 actions | 748e20a9 | ci.yml, nightly.yml, release.yml, release-train-drift.yml, branch-protection-apply.yml | checkout 7.0.0->7.0.1, upload-artifact 7.0.1->7.0.2, setup-node 7.0.0->7.1.0, setup-beam 1.24.0->1.24.1 | behind | **failure** | See Pitfall 1: version-coupled pins in tests. |
| #120 (ours) | c2e0f05a | ci.yml, `scripts/setup_branch_protection.sh`, new `test_setup_branch_protection.sh`, a todo | n/a | blocked (no check-runs yet at read time) | none yet | Adds a step to `ci-script-tests` (hunk adjacent to where Phase 134 will add harness steps). |

[VERIFIED: `gh pr diff N`, `gh api repos/szTheory/rindle/pulls/N`, `.../commits/<sha>/check-runs`] for every cell above. `rebaseable` is `false` for all, `mergeable` is `true`.

**#112 and #113 root causes of red/mixed:**
- #113 failure: `Quality (1.15, 26)` and `Quality (1.17, 27, true)` step "Run tests with coverage" failed in `Rindle.InstallSmoke.NightlyPolicyTest` because tests pin the old `upload-artifact` SHA:
  `test/install_smoke/nightly_policy_test.exs:143` and `:213` contain `"actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"`; PR head has `...@cf430e030ddbb5b0abf93d22962f4752f3646cd9` [VERIFIED: CI log of run 38667397298 plus grep of the test file]. Checkout is only matched by prefix (`=~ "actions/checkout@"`, line 44), so only upload-artifact is pinned. This is exactly the "version-coupled literal" class (D-134-08, OBS-02 memory).
- Duplicate check-runs: CI `concurrency` has `cancel-in-progress` on `pull_request` and the trigger list includes `labeled` [CITED: .github/workflows/ci.yml:4-27], so label events cancel an in-flight run and leave a cancelled run's `CI Summary` = failure beside the later run's success on the same head (#108). **The collector must choose the `CI Summary` check-run with the greatest `completed_at` (equivalently the highest workflow run id), not "any"/"first".** `check_name=CI%20Summary&filter=latest` did **not** de-duplicate (returned both) [VERIFIED: live call].

### #95 incompatibility claim: CONFIRMED against current `lib/`

`lib/rindle/av/subprocess.ex:150-162` [VERIFIED: Read this session]:
```elixir
    if :os.type() == {:unix, :linux} and Keyword.get(opts, :use_cgroups, true) do
      cgroup_sets = [
        {"memory", "memory.limit_in_bytes", "536870912"},
        {"cpu", "cpu.cfs_period_us", "100000"},
        {"cpu", "cpu.cfs_quota_us", "50000"}
      ]

      base ++
        [
          cgroup_controllers: ["memory", "cpu"],
          cgroup_base: @cgroup_base,
          cgroup_sets: cgroup_sets
        ]
```
MuonTrap 2.0.0 changelog: "Cgroup v1 support is removed, and v2 replaces it"; `:cgroup_controllers` and `:cgroup_sets` are replaced by a single `:cgroup` map; non-cgroup users unaffected [CITED: raw.githubusercontent.com/fhunleth/muontrap/main/CHANGELOG.md]. CI/test run with `use_cgroups: false` (`config/test.exs:67`) so green CI does not exercise it [CITED: shell grep of config/test.exs]. Because `mix.exs` is changed (`~> 2.0`), merging #95 would force every consumer onto MuonTrap 2 while Rindle still passes v1 options: a public-contract break. MuonTrap 2.0.1 exists (2026-10-06), so Dependabot will likely open a fresh PR for it after #95 is closed unless ignored. MuonTrap issue #98 (the `:epipe` race Rindle works around at `lib/rindle/av/subprocess.ex:20-24`) is now **closed** upstream (2026-07-21) [VERIFIED: `gh api repos/fhunleth/muontrap/issues/98`]; removing the workaround belongs to the future cgroup-v2 migration, not here. MuonTrap 1.8.0 is also available inside the existing `~> 1.7` range (the demo lock already has 1.8.0), but nothing requires it.

### Upstream changelogs (per runtime PR)

| Package | Change | Breaking? | Rindle affected? |
|---------|--------|-----------|------------------|
| ecto_sql 3.14.0 | Enhancements only (UNLOGGED tables, safe-migration guides, sandbox owner label, `unsafe_fragment` in RETURNING, etc.) [CITED: ecto_sql CHANGELOG.md] | No | Low. Demo lock already runs ecto 3.14.2/ecto_sql 3.14.0 [VERIFIED: examples/adoption_demo/mix.lock] and the main-run Adoption E2E trace shows `ecto_sql 3.14.0` in use. `mix.exs` keeps `~> 3.11`. |
| req 0.7.4 | `put_params` allows explicit duplicates (fixes a 0.7.0 regression); `put_path_params` redirect fix [CITED: hexdocs.pm/req/changelog.html]. **0.7.5 (2026-10-06) is out** (SigV4 retry fix, 303 redirect -> GET). The repo CHANGELOG on `main` lacks a 0.7.4 entry; use hexdocs. | No | Low. `req` is `optional: true`; used as the ExAws HTTP client in test (`config/test.exs:54`, `http_client: ExAws.Request.Req`). Only `lib/rindle/storage/s3.ex` references `ExAws.`/`Req.`. |
| ex_aws 2.7.0 | "Upgrade hackney to 3.x"; "pod identity authorization when using Req adapter" [CITED: ex_aws CHANGELOG.md]. Registry shows optional `hackney ~> 4.0`, `req ~> 0.5.10 or ~> 0.6 or ~> 1.0` [VERIFIED: hex.pm release API] | No (none listed) | Low. Rindle uses Req transport in test; hackney is optional and absent from the lock beyond optional-requirement lines. Failing `Package Consumer` job on the stale head needs a fresh run to judge. |

### Dispositions and landing order recommended

| PR | Disposition | Rationale |
|----|-------------|-----------|
| #120 | **merge** (ours, `ci:`) | Prerequisite hygiene; fixes the red daily Branch Protection Apply; its `ci.yml` hunk conflicts with Phase 134's harness wiring, so land it first. |
| #113 | **merge** after a `test:` decoupling PR, then `@dependabot rebase` | Needs the pinned-SHA test literals loosened first (see Pitfall 1). Rebase afterward; do not push commits onto the Dependabot branch (stops auto-rebase). `nightly.yml`/`release.yml` changes are not exercised on PRs (see Pitfall 4). |
| #105 | **merge** (runtime core; lands alone) | Rebase; lock delta must equal exactly `{ecto, ecto_sql}`. |
| #108 | **merge** (req; optional runtime) | After rebase, expect Dependabot may retarget to 0.7.5; delta should be `{req}` plus whatever `mint` move remains. |
| #109 | **merge** after #108 | Shrinks to `{ex_aws}` once req/mint are on main. If it still shows red `Package Consumer`, treat the rebased run as the only valid evidence. |
| #112 | **merge** after #105 and a decimal PR | Shrinks to dev tooling + `lazy_html`. Keep decimal out of it (runtime core). |
| #95 | **close** (explanatory comment) **and** durable ignore | Add `ignore: [{dependency-name: "muontrap", update-types: ["version-update:semver-major"]}]` to the mix entry of `.github/dependabot.yml` (extend `test/install_smoke/dependabot_policy_test.exs`), because plain close alone may re-open for 2.0.1 [ASSUMED: Dependabot behavior]; the ledger records the trigger "re-evaluate when a cgroup-v2 migration is chartered". `@dependabot ignore this major version` is an alternative authorized comment. |
| #42 | **retain** | Evidence-gated, owned by TEST-08 (Phase 136). |

**Maintainer-authored lock-only PRs** (needed because Dependabot does not propose purely transitive bumps): per-package `mix deps.update <pkg>` (all inside existing `~>` ranges, `mix.exs` unchanged), prefix `build(deps):`:
1. `cowlib` -> 2.21.0 (test-only: bypass -> plug_cowboy -> cowboy -> cowlib).
2. `mint` -> latest within `~> 1.8` (>=1.10.2 needed to clear all six).
3. `decimal` -> >=3.1.2 (3.2.0 latest).
`lazy_html` (test-only) rides with #112.

## Advisory Findings (Q2) and SEC-09 ledger seed

### `mix hex.audit` on root `mix.lock` (run locally, Hex 2.5.1) [VERIFIED: command output]
Exit code **1**. Format is human text, no JSON flag (`mix help hex.audit` lists none): header `Advisories:`, then per finding `  <pkg> <ver> - <ID> (<SEVERITY>)`, `    aka: ...`, a title line, an `https://osv.dev/vulnerability/<ID>` line; trailer `Found packages with security advisories`. A stderr line "Your authentication session has expired..." is local noise. With ignores the section becomes `Ignored advisories:` and the exit code is **0** [VERIFIED: ran with `HEX_IGNORE_ADVISORIES=<all ids>,CVE-BOGUS-1`, exit 0; an unmatched ignore only warns]. `mix deps.get` already prints the same set (`VULNERABLE!` lines in the "Install dependencies (lock-verified)" step), without failing [VERIFIED: CI log run 38762602374].

`mix deps.audit` on the same lock: "No vulnerabilities found.", exit 0, locally and in CI main run 38762602374 [VERIFIED]. `ci.yml:194-197` runs it as `Audit dependencies (advisory)` with `continue-on-error: true` [CITED: ci.yml:194-197]. mix_audit reads the `mirego/elixir-security-advisories` repo [CITED: deps/mix_audit/lib/mix_audit/repo.ex:2].

### Findings (root lock) with reachability, path, fix

Reachability from `mix.exs` `only:`/`optional:` and `mix deps.tree --only prod` (prod tree contains decimal and mint, excludes cowlib and lazy_html) [VERIFIED: command output]. No `lib/` call sites for `Decimal.`, `Mint.`, `LazyHTML` or `:cow_` [VERIFIED: grep of lib/ returned nothing]; all exposure is transitive.

| Advisory (OSV/EEF id) | Pkg@locked | Sev | Dependency path | Reachability | Fix version [api.osv.dev] |
|-----------------------|-----------|-----|-----------------|--------------|----------------------------|
| EEF-CVE-2026-43971 | cowlib 2.19.0 | MED | bypass(`only: :test`) -> plug_cowboy -> cowboy -> cowlib | dev-test-only | 2.20.0 |
| EEF-CVE-2026-43966 | cowlib 2.19.0 | MED | same | dev-test-only | OSV lists a commit only; confirm by re-running hex.audit on cowlib 2.21.0 |
| EEF-CVE-2026-43969 | cowlib 2.19.0 | LOW | same | dev-test-only | 2.21.0 |
| EEF-CVE-2026-82729 | mint 1.9.3 | MED | finch(optional) / mux(optional) / req(optional) -> mint | optional-dep | 1.10.0 |
| EEF-CVE-2026-82728 | mint 1.9.3 | HIGH | same | optional-dep | 1.10.0 |
| EEF-CVE-2026-82672 | mint 1.9.3 | MED | same | optional-dep | 1.10.1 |
| EEF-CVE-2026-91043 | mint 1.9.3 | HIGH | same | optional-dep | 1.10.2 |
| EEF-CVE-2026-92103 | mint 1.9.3 | MED | same | optional-dep | 1.10.2 |
| EEF-CVE-2026-94194 | mint 1.9.3 | MED | same | optional-dep | 1.10.2 |
| EEF-CVE-2026-97853 | decimal 3.1.1 | MED | ecto_sql/ecto, postgrex, jason -> decimal | runtime (core) | 3.1.2 |
| EEF-CVE-2026-92106 | lazy_html 0.1.12 | LOW | lazy_html(`only: :test`); also phoenix_live_view test dep | dev-test-only | 0.1.13 |

Retirements: none reported (no `Retirements` section). Library note: Rindle's `mix.lock` only governs Rindle's own dev/CI; the published Hex package carries `~>` requirements only (`files:` list, `mix.exs:277-278`), and none of Rindle's declared ranges exclude a fixed version, so consumers resolve their own versions. Reachability for the ledger should therefore say "runtime (consumer-resolved; Rindle lock affects CI/dev only)".

### Demo lock (not audited, not Dependabot-covered) [VERIFIED: `mix deps.get --check-locked` + `mix hex.audit` in `examples/adoption_demo` with scratchpad deps/build paths; lock unchanged]
Same mint(6), decimal, lazy_html findings, no cowlib, **plus `bandit 1.12.5` EEF-CVE-2026-105659 (HIGH, HTTP/2 blocked-send deadline reset)**. OSV lists a fix **commit only** and `hex.pm` latest is 1.12.5: **no released fix exists**, so this is the natural **bounded exception** (demo-only; `examples/` is not in the Hex `files:` list). `.github/dependabot.yml` only covers `directory: "/"`, so the demo lock and `brandbook`/`examples` npm locks get no updates. Demo audit requires fetching deps first (`mix deps.get` took under the 200 s timeout used); keep it as a second advisory source entry with `unreadable` on failure.

### GitHub-side advisory sources (Q2)
- Dependabot alerts: `GET /repos/szTheory/rindle/dependabot/alerts` -> **403 "Dependabot alerts are disabled for this repository."** [VERIFIED]. The local token has scopes `gist, read:org, repo, workflow` and a separate message says "needs the admin:repo_hook scope" for code-scanning-style reads [VERIFIED].
- `GET /repos/.../vulnerability-alerts` returns 204 if enabled and 404 if not; `PUT` enables and requires **admin** access [CITED: docs.github.com/en/rest/repos/repos]. Live: 404 (disabled). This is a cheap, distinct "is it enabled" probe the collector should record. The token is repo admin (`permissions.admin: true`) [VERIFIED]. `security_and_analysis.dependabot_security_updates` is `disabled`; secret scanning is enabled [VERIFIED].
- Hex coverage: the GitHub Advisory Database does carry Hex packages under ecosystem `erlang` (`GET /advisories?ecosystem=erlang` returned cowlib GHSAs) [VERIFIED]. But **the dependency graph does not parse `mix.lock`**: GitHub staff said Elixir support has no timeline and the workaround is the dependency-submission API (`erlef/mix-dependency-submission`); the repo's `dependency-graph/sbom` is 404 [CITED: web search results, elixirforum + github/advisory-database#1661, possibly dated; VERIFIED: sbom 404]. Enabling alerts is therefore unlikely to produce Elixir alerts by itself. [ASSUMED: current docs not retrievable; the supported-ecosystems page fetched did not mention Elixir/Hex.]
- Actions advisories: "For GitHub Actions, alerts are only generated for actions that use semantic versioning, not SHA versioning" [CITED: docs.github.com dependency-graph supported ecosystems]. Rindle pins every action by SHA, so Actions alerts would also be silent. Record `actions: not-applicable (SHA-pinned)`.

**Minimal source set (recommended):** (1) `mix hex.audit` root, (2) `mix hex.audit` demo, (3) `mix deps.audit` kept as a recorded second opinion, (4) Dependabot alerts recorded as `{status: source_disabled, http: 403}` with a ledger rationale unless the user authorizes enabling. Offer the enable action at a checkpoint (D-134-06) but present the finding that it will not add Hex coverage by itself.

## Branch protection read (Q3)

- `GET /repos/szTheory/rindle/branches/main/protection` works with the local admin `gh` token: `required_status_checks.strict: true`, `contexts: ["CI Summary"]`, `checks: [{context: "CI Summary", app_id: 15368}]`, `enforce_admins.enabled: false` [VERIFIED: live call]. Documented requirement is repository **Administration: read** (admin) [ASSUMED: from `github.token`/PAT docs; not fetched this session]. A workflow `github.token` cannot hold it.
- **Safe "unreadable" fallback:** `GET /repos/{r}/branches/main` is readable by any reader and returns `protected: true` plus `protection.required_status_checks.{contexts, checks, enforcement_level: "non_admins"}`, but **not** `strict` and **not** a real `enforce_admins` [VERIFIED: live call]. Record `{source: "protection"|"branches-partial"|"unreadable", http: <status>, strict: <bool|"unreadable">, enforce_admins: <bool|"unreadable">, contexts: [...]}`. Rulesets (`/rules/branches/main`) returned `[]`.
- Compare against the in-repo policy: `config/ci_required_checks.json` has `"contexts": ["CI Summary"]` [CITED: file]; `scripts/setup_branch_protection.sh --print-expected-json` already prints the expected non-context fields.

## Collector design (Q4)

### Endpoints and pagination (all `gh api`, GET)
- Issues: `repos/{r}/issues?state=open&per_page=100`; **this endpoint includes PRs**, filter `.pull_request == null`.
- PRs: `repos/{r}/pulls?state=open&per_page=100` for the list, then `repos/{r}/pulls/{n}` per PR for `mergeable`/`mergeable_state`/`rebaseable`/`head.sha`/`base.sha`. Do **not** use `gh pr list --json mergeable`: it returned `UNKNOWN` for 6 of 7 PRs [VERIFIED]; the REST per-PR call returned real values. REST can also return `mergeable: null` while computing; retry a bounded number of times, else record `"unknown"` (never coerce).
- Files: `repos/{r}/pulls/{n}/files?per_page=100` (paginate) or `gh pr view --json files`; extract manifest files (`mix.exs`, `mix.lock`, `.github/workflows/*`, `package*.json`).
- CI Summary per head: `repos/{r}/commits/{head_sha}/check-runs?check_name=CI%20Summary&per_page=100`; pick `max_by(.completed_at)` among `app.slug == "github-actions"`; record `{conclusion, completed_at, check_run_id, superseded_count}`. No runs -> `{conclusion: null, reason: "no_check_runs"}` (PR #120 at read time).
- Behind main: use `mergeable_state == "behind"` or `compare/{base}...{head}` `.behind_by`.
- Main CI baseline: `repos/{r}/actions/workflows/ci.yml/runs?branch=main&event=push&per_page=5`, and for the latest run `actions/runs/{id}/jobs?per_page=100` -> `failed_jobs`. Record this in the inventory (`main_ci`); it is what exposed the red `Adoption Demo E2E` at `6ef86d38`.
- `gh api --paginate --slurp` **cannot be combined with `--jq`** ("the `--slurp` option is not supported with `--jq`") [VERIFIED]; pipe to `jq`: `gh api --paginate --slurp "<path>" | jq -S '[.[][]]'`. `manage_nightly_incident.sh:81` already uses `--paginate --slurp` without `--jq`.
- Rate limit used was ~400 of 5000 in this whole research session; the collector's per-PR fan-out (about 4 calls/PR) is trivial.

### Determinism, read-only proof, fail-closed
- Emit with `jq -S`; the only volatile fields are `collected_at` and values read from live state. Inject the clock (`INBOX_NOW_EPOCH`, via a fake `date` as in `test_nightly_incident.sh`).
- Read-only enforcement: route every GitHub call through one `gh_get()` wrapper that refuses anything but `gh api <path>` GET (no `-X`/`--method`/`-f`/`--input`), then a harness fake `gh` that exits non-zero and logs on any `-X`/`--method` other than GET and on `gh (pr|issue|run|label|repo|workflow|release) <verb>` where verb is not in a read allowlist (`list|view|diff|checks|status`).
- Fail closed: `set -euo pipefail`; `gh auth status` (or first API call) failure exits non-zero; any page failure exits non-zero; **no partial JSON file is left behind** (write to temp, `mv` on success). Distinguish *source unavailable* (recorded, collector still exits 0) from *collection failure* (exit 1): 403-disabled alerts and 403 protection become records; network/5xx/JSON-parse failures abort.
- `mix hex.audit` parse: exit 0 + no advisory lines -> `{status: "clean"}`; exit 1 + parseable `Advisories:` -> `{status: "findings", findings: [...]}`; exit !=0 with **no** recognizable marker -> collection failure (hex.audit exits 1 for network errors too, so exit code alone is ambiguous). Also parse `Ignored advisories:` and tag `ignored: true`. Run the collector's audit with ignores cleared so mix.exs `ignore_advisories` cannot mask the raw set.
- Terminal ledger entries: the collector accepts `--include N [N...]` (the validator derives them from the ledger) and records `state`/`state_reason`/`merged` for those numbers via `repos/{r}/issues/N` + `pulls/N`, so "a ledger entry for an item no longer open" can be checked against actual state.

### Where it runs (recommendation)
**Local maintainer command** (primary, authoritative for closure credit): needs admin for `/protection` and Dependabot alerts, plus `mix` for the audits. Optionally a `workflow_dispatch`/scheduled read-only job later; in CI with `github.token` the fields `branch_protection` (full), `dependabot_alerts` and `vulnerability_alerts` become `unreadable` by design (token lacks Administration/Dependabot-alerts permissions) while issues/PRs/check-runs/main_ci remain readable (`contents: read`, `pull-requests: read`, `actions: read`, `checks: read`, `issues: read`). A scheduled job is **not** recommended inside this phase (scope fence; Nightly is Phase 133's surface). The merge-blocking part is the fixture harness only.

### Fake-gh test pattern (to reuse)
`scripts/ci/test_nightly_incident.sh` writes a PATH-shim `gh` from `printf '%s\n' ...` lines, logs every invocation to `FAKE_GH_LOG`, answers by pattern (`*"actions/runs/"*"/attempts/"*`, `issue list`), supports failure injection (`FAKE_GH_FAIL=api|list|mutation|download`) and a fake `date` driven by `FAKE_NOW_EPOCH`; it records `ok`/`FAIL` counts and exits non-zero on any failure [CITED: scripts/ci/test_nightly_incident.sh:1-195]. `scripts/ci/test_setup_branch_protection.sh` (PR #120, read via `gh pr diff 120`) uses a heredoc `gh` with `FAKE_DIR` fixture files, `case "${args}"` routing, `exit 99` on any unexpected call, and logs `-X PUT` calls to a `puts` file [CITED: gh pr diff 120]. Reuse the second style (fixture directory + `unexpected gh call -> exit 99`) and add a **mutation tripwire**: every non-GET or mutating-verb call appends to a `mutations` file and the harness asserts it is empty. Also add a fake `mix` shim on PATH returning canned `hex.audit`/`deps.audit` text and exit codes. Both harnesses are wired as named steps in `ci-script-tests` (lookups elsewhere are by step name, not position: `nightly_policy_test.exs` uses `step(job(workflow, "ci-script-tests"), "<name>")`), but **#120 also appends a step in the same hunk (`ci.yml:1463-1466`)**, so land #120 first or rebase.

## Ledger and validator design (Q5)

### Ledger shape (`.planning/INBOX-LEDGER.json`, `jq -S` sorted, schema id `rindle-inbox-ledger-v1`)

```json
{
  "schema": "rindle-inbox-ledger-v1",
  "repo": "szTheory/rindle",
  "items": [
    {"kind": "pr", "number": 105, "disposition": "merge",
     "head_sha": "<40-hex of PR head when decided>",
     "risk_group": "ecto_sql", "group_packages": ["ecto", "ecto_sql"],
     "rationale": "lock-only runtime minor; enhancements only"},
    {"kind": "pr", "number": 95, "disposition": "close",
     "head_sha": "d76291a2...", "rationale": "v1-only cgroup options (lib/rindle/av/subprocess.ex)",
     "ignore_policy": ".github/dependabot.yml muontrap major"},
    {"kind": "issue", "number": 42, "disposition": "defer",
     "gate": "TEST-08 experiment (Phase 136)",
     "trigger": {"type": "date", "not_after": "2026-12-31"}},
    {"kind": "pr", "number": 93, "disposition": "close", "terminal": {"state": "closed", "merged": false}}
  ],
  "advisories": [
    {"id": "EEF-CVE-2026-97853", "package": "decimal", "locked": "3.1.1",
     "scope": "root", "path": ["ecto_sql", "decimal"], "reachability": "runtime",
     "fix_version": "3.1.2", "status": "resolved"},
    {"id": "EEF-CVE-2026-105659", "package": "bandit", "locked": "1.12.5",
     "scope": "examples/adoption_demo", "path": ["bandit"], "reachability": "dev-test-only",
     "fix_version": null, "status": "exception",
     "exception": {"expires": "2026-11-30",
                   "trigger": {"type": "hex_version_gte", "package": "bandit", "version": "1.12.6"},
                   "rationale": "demo-only; no released fix"}}
  ],
  "sources": {"dependabot_alerts": {"status": "source_disabled", "rationale": "..."}},
  "landings": [
    {"number": 105, "merge_sha": "<squash sha>", "ci_run_id": 0,
     "gates": {"supported_toolchain": "pass", "public_contract": "pass",
               "package_consumer": "pass", "twin": "not-applicable: twin not built (Phase 137)"}}
  ]
}
```
Dispositions: `merge | close | retain | supersede | defer`. `supersede` requires `successor` (number or `"#N"`). `defer` requires `gate` and `trigger` where `trigger.type` is from a **closed vocabulary implemented in the validator** (`date` -> `not_after`; `hex_version_gte`; `gh_issue_closed`), never an arbitrary shell string. Terminal entries carry `terminal.state` (`closed`/`merged`) that must equal the collector's `--include` lookup.

### Validator rules (each is a rejection, each gets a failing fixture)
1. Inventory `collected_at` older than the bound (default 24 h, `--max-age-seconds`) or from the future -> reject. Inventory `repo` must equal ledger `repo`.
2. Every open issue/PR has **exactly one** ledger item; zero (missing) or >1 (duplicate) rejects. A ledger item for a non-open number without a matching `terminal` record rejects.
3. PR items bind `head_sha`; mismatch with inventory head rejects as stale. Items with `merge` disposition additionally require the inventory's `CI Summary` conclusion for that head to be `success` and **not `behind`**, or an explicit `pending_action: "rebase"` (recorded, not credited).
4. Disposition-specific fields (above). A `merge` PR whose lock delta contains packages outside `group_packages` rejects (this is the executable attribution check; the collector records `lock_delta` per dependency PR by diffing `mix.lock` package names/versions from `pulls/N/files` patch or a `compare` call).
5. Advisories: every finding in the inventory (`ignored` or not) must have a ledger record; `status: resolved` is accepted only if the id is **absent** from the inventory; `status: exception` requires `expires` >= now (an expired one rejects) and a valid trigger (a satisfied trigger rejects as "resolve now"); stale ledger advisory records (id no longer reported and not marked resolved) reject. Every id in `mix.exs` `hex: [ignore_advisories: ...]` (if used) must have an unexpired exception record, and vice versa.
6. `sources.dependabot_alerts.status: source_disabled` is accepted only with a non-empty `rationale`.
7. Clock injected via `INBOX_NOW_EPOCH` for tests; jq `fromdateiso8601`/`now` for date math (avoid `date -d`, which differs on macOS vs GNU).

### Tests: bash harness, not ExUnit
Fixture harnesses (`scripts/ci/test_collect_inbox.sh`, `scripts/ci/test_validate_inbox_ledger.sh`) run in `ci-script-tests`. An ExUnit test in `test/install_smoke` would need the Quality toolchain and would tempt reading `.planning/` paths (project memory: archiving breaks those). The one acceptable `.planning` read is the **top-level** `.planning/INBOX-LEDGER.json` (stable, not archived by `gsd-cleanup`), but still avoid a merge-blocking test that validates the committed ledger against live data or the wall clock. Merge-blocking = fixtures + a static shape check of the committed ledger (`--offline`: JSON valid, schema id, enum values, required fields, **no time/live checks**). Live freshness and expiry run at phase closure from the maintainer machine (and could later join Nightly or Phase 136 ratchets).

## DEPS-01 evidence (Q6)

### Gate-to-job map (names are the check-run/job `name`, verified from `ci.yml` and live job lists)

| DEPS-01 gate | PR lane (merge-blocking via `CI Summary`) | Post-merge push:main only |
|--------------|-------------------------------------------|---------------------------|
| Supported toolchain | `Quality (1.15, 26)`, `Quality (1.17, 27, true)`, `ADMIN-06 Optional Dependencies (1.15, 26)`, `ADMIN-06 Optional Dependencies (1.17, 27)` | — (broad OTPxElixir `compat-matrix` is Nightly, not CI) |
| Public contract | `Contract`, `Proof`, `Integration`, `CI Script Tests` | — |
| Built-package consumer | `Package Consumer Proof Matrix + Release Preflight` (lean, image-only), `Adopter`, `Adoption Demo Unit`, `Adoption Demo E2E Smoke` | `Package Consumer Full Matrix + Release Preflight (image|video|tus|gcs|mux)`, `Cohort Demo Smoke`, `Adoption Demo E2E` |
| Twin | — | `not-applicable: twin not built (Phase 137)` (never "pass") |

`CI Summary` `needs:` lists quality, optional-dependencies, integration, contract, proof, package-consumer, adoption-demo-unit, adoption-demo-e2e-smoke, adopter, brandbook-tokens, ci-script-tests and **intentionally omits** `package-consumer-full`, `cohort-demo-smoke`, `adoption-demo-e2e`, `mux-soak`, `ci-observability` [CITED: ci.yml comments, lines ~1467-1495]. So the push:main **workflow-run conclusion** can be `failure` while `CI Summary` is `success`; this is the live situation at `6ef86d38` (run 38762602374: `CI Summary` success, `Adoption Demo E2E` failure) [VERIFIED].

### Reading the post-merge run for a squash SHA
```
gh api "repos/szTheory/rindle/actions/workflows/ci.yml/runs?head_sha=<squash_sha>&event=push&per_page=5"
gh api "repos/szTheory/rindle/actions/runs/<id>/jobs?per_page=100"   # per-job name + conclusion
```
Both verified live for `6ef86d38`. The push:main concurrency group does not cancel main runs (`cancel-in-progress` is false off-PR), so each squash SHA gets its own complete run. `dep_landing_evidence.sh <sha> [--baseline-sha <sha>]` should emit per-gate JSON from the job list, and a lane counts against the group only if it is red here **and** was green on the baseline SHA's run (or fails again on rerun). Run durations: PR run about 8 min (#108: 12:11:31 -> 12:19:50); push:main run about 23 min (15:41:54 -> 16:04:58) [VERIFIED].

**Baseline caveat (act before landing anything):** the current main run is red on `Adoption Demo E2E` for a docs-only commit; the failing log shows `Rindle.AV.Subprocess: MuonTrap closed its port at the command timeout; retrying the AV call once` followed by `(ArgumentError)` in another process and `DBConnection.ConnectionError`. Prior main runs (46e4dbc3, 98c049be, ecd4d5a0) were green. A rerun (`gh run rerun <id> --failed`, an authorized action, not performed) is needed to establish whether the baseline is flaky or broken; otherwise the first dependency merge inherits an ambiguous red. The release workflow's `gate-ci-green` keys off the push:main run conclusion [CITED: ci.yml comments, lines 15-26], so this red also blocks the Hex publish path.

### Attribution evidence to record per landing
`git show --stat`/`gh api repos/{r}/commits/<sha>` for `mix.lock` + `mix.exs` delta (package-level), the squash subject naming the group, post-merge `run_id` and per-gate job conclusions, baseline run id. Dependabot PRs that overlap (see matrix) are attributable **only after** the earlier PR is on main and the later one is rebased: record the *post-rebase* delta, and reject if it contains a package outside `group_packages`.

## Architecture Patterns

### System Architecture Diagram
```
 maintainer (admin gh token, mix toolchain)
        |
        v
 collect_inbox.sh --include <terminal numbers from ledger>
   |-- gh api (GET only, paginated) --> issues, PRs(+REST mergeable), files, check-runs(CI Summary max completed_at),
   |                                    commits main, actions runs/jobs (main_ci), branches/main(+/protection), vulnerability-alerts probe, dependabot/alerts
   |-- mix hex.audit (root, demo) / mix deps.audit  --> parsed findings OR error(abort)
   v
 inventory.json  (schema, collected_at, repo, main_sha, items, advisories{sources}, branch_protection, main_ci)   [written atomically]
        |
        v
 validate_inbox_ledger.sh --inventory inventory.json --ledger .planning/INBOX-LEDGER.json [--now|--max-age]
   |-- rules 1-7 (missing/dup/stale/expired/terminal mismatch) --> exit 0 | exit 1 + reasons
        ^
        |  human-authorized actions only: merge / close / comment / rebase / enable alerts
 dep_landing_evidence.sh <squash_sha> --> lock delta + post-merge per-job gate JSON --> ledger.landings[]

 merge-blocking CI (ci-script-tests): fake gh + fake mix harnesses over the same scripts (behavior only, no live data)
```

### Recommended Project Structure
```
scripts/maintainer/
  collect_inbox.sh              # INBOX-01
  validate_inbox_ledger.sh      # INBOX-02 / SEC-09 / DEPS-01 attribution checks
  dep_landing_evidence.sh       # DEPS-01 per-landing evidence
scripts/ci/
  test_collect_inbox.sh         # fake gh + fake mix; mutation tripwire
  test_validate_inbox_ledger.sh # one failing fixture per rejection rule
.planning/
  INBOX-LEDGER.json             # top-level, stable
  INBOX-TRIAGE.md               # reduced to a pointer to the ledger
```

### Anti-Patterns to Avoid
- **Treating `deps.audit` silence as clean.** It disagrees with `hex.audit` today.
- **Using `gh pr list --json mergeable`** (UNKNOWN) or "any `CI Summary` success" (stale/duplicate check-runs).
- **Gating PRs on live data/time** (advisory drift or an expiring exception would red unrelated PRs).
- **Editing Dependabot branches** (stops its rebases; use `@dependabot rebase`/`gh pr update-branch`).
- **Pinning action SHAs literally in tests** (breaks #113 and every future actions bump).
- **Reading `.planning/phases/134-*` from scripts/tests** (D-134-02).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Advisory matching | Own OSV/GHSA matcher against `mix.lock` | `mix hex.audit` | Maintained, matches aliases, supports `ignore_advisories` |
| Bounded exception mechanism | Custom suppressions file | `hex: [ignore_advisories: [...]]` in `mix.exs` (or `HEX_IGNORE_ADVISORIES`) + ledger expiry | Built in; unmatched entries produce a "can be removed" warning |
| Pagination | Manual `Link` header loops | `gh api --paginate --slurp ... \| jq` | Existing project pattern |
| Dependency graph for Hex | Local graph parser | `mix deps.tree [--only prod]` | Authoritative for reachability |
| Attribution of a merge | Prose in a ledger | Script-computed lock delta from the merge commit | Executable, rejects drift |
| Trigger language | Eval of shell/jq expressions in ledger | Closed vocabulary (`date`, `hex_version_gte`, `gh_issue_closed`) | No injection surface, testable |

**Key insight:** every "requirement closes on evidence" predicate here reduces to comparing a fresh GET-only inventory with a small declarative file; nothing needs a framework.

## Runtime State Inventory

Not a rename/migration phase. Omitted. (Adjacent note: existing `scripts/maintainer/check_phase_133_landing_closure.sh` default manifest and `evidence_census.exs`/`validate_evidence_census.exs` detector paths reference `.planning/phases/133-*` and `.planning/milestones/v1.25-phases/*` paths [CITED: those files]; that is Phase 135 hygiene debt, not touched here.)

## Common Pitfalls

### Pitfall 1: Version-pinned literals in tests turn Dependabot Actions PRs red
**What goes wrong:** #113 fails `Quality` (both legs) because `nightly_policy_test.exs:143,213` hard-code the old upload-artifact SHA.
**Why:** SHA pins are intentionally literal in workflows; the tests copied them.
**Avoid:** land a `test:` PR first that asserts `~r/^actions\/upload-artifact@[0-9a-f]{40}$/` and equality with the pin parsed from `ci.yml` (derive, don't hard-code), then rebase #113. Grep `test/install_smoke` for any other pinned action SHAs in the same PR (only the two found: `9c091bb2`, `043fb46d`, `82076278`, `fc68ffb9` otherwise appear only in workflows).
**Warning signs:** `Assertion with == failed ... actions/upload-artifact@` in Quality.

### Pitfall 2: Overlapping Dependabot lock deltas break "independently attributable"
**What:** #109 contains #108's req+mint; #112 contains #105's ecto/ecto_sql and runtime decimal.
**Avoid:** serial landing + `@dependabot rebase` after each merge; validate post-rebase lock delta equals `group_packages`; peel `decimal`/`mint` into maintainer lock-only PRs.

### Pitfall 3: Strict protection means every merge makes all others `behind`
All heads are `behind` now. Each landing needs rebase -> new PR run (~8 min) -> merge -> push:main run (~23 min). About 10 landings is hours of wall clock. Because off-PR main runs serialize (not cancel) and are per-SHA, the user may pipeline the next merge once its own PR run is green on top of the prior SHA; a red post-merge run still reverts only its own commit. Dependabot `rebase-strategy: auto` only rebases on conflict, so request `@dependabot rebase` explicitly [ASSUMED].

### Pitfall 4: CI-lanes-only-on-main gap
`package-consumer-full`, `cohort-demo-smoke`, `adoption-demo-e2e` skip on PRs; `nightly.yml`/`release.yml` edits in #113 (and Nightly's PLT key `hashFiles('mix.exs','mix.lock','.dialyzer_ignore.exs')`, `test/install_smoke/ci_cache_hygiene_test.exs:156`) are exercised only after merge. After #113, read the next scheduled Nightly run (existing `scripts/ci/verify_nightly_run.sh`) before calling the group clean; after any `mix.lock` merge expect a cold Dialyzer PLT.

### Pitfall 5: Duplicate/cancelled `CI Summary` check-runs
See collector section; select by max `completed_at`. A `cancelled` earlier run shows `CI Summary` = failure.

### Pitfall 6: `mix hex.audit` exit code is ambiguous
Exit 1 = findings **or** operational error. Require a recognized section marker before treating exit 1 as findings; otherwise abort.

### Pitfall 7: release-please and dependency commits
Prefixes `build(deps)`/`ci(deps)` come from `commit-message.prefix` in `dependabot.yml` [CITED: .github/dependabot.yml, comment "MUST be a NON-release Conventional-Commits type"]; the policy test locks the dev group only. `release-please-config.json` uses `release-type: elixir` with `bump-minor-pre-major` and `bump-patch-for-minor-pre-major` [CITED: file]. That `build`/`ci`/`test`/`docs` types do not trigger a release is the standard conventional-commit behavior [ASSUMED: release-please docs fetched did not enumerate hidden types]; no `build(deps)` squash has yet landed on `main` since 0.4.5 to observe it (`git log` shows none), so **the first landing is the live test**: after it, confirm no release PR is opened or changed (`gh pr list --label "autorelease: pending"`, `check_release_please_progress.sh`). Squash subjects for maintainer PRs must be `build(deps): ...`, `ci: ...`, `test: ...`, never `fix:`/`feat:`. Also remember release-please-driven version bumps change `mix.exs`; version-coupled assertions must derive from `mix.exs` (D-134-08).

### Pitfall 8: Dependabot commands and grouping
Known commands (training, not fetched: the commands doc page 404'd): `@dependabot rebase`, `recreate`, `merge`/`squash and merge`, `close`, `ignore this major version`/`minor`/`dependency` [ASSUMED]. Verified: Dependabot stops rebasing after extra commits unless `[dependabot skip]` is in them [CITED: docs.github.com managing-pull-requests-for-dependency-updates]. `groups.dev-dependencies` uses `dependency-type: development` with minor/patch only [CITED: .github/dependabot.yml, `dependabot_policy_test.exs`], which still moved runtime transitives (decimal/ecto) because lock resolution pulls them along. `open-pull-requests-limit: 5` per ecosystem; the GitHub-actions entry covers only `directory: "/"`.

### Pitfall 9: Stale triage and lock coverage gaps
`INBOX-TRIAGE.md` references closed items. The demo `mix.lock` and npm locks have no Dependabot coverage; at minimum record them in the ledger scope (and optionally add a `directory: "/examples/adoption_demo"` mix entry, `ci:`/`build:` prefix).

## Code Examples

### Select the authoritative `CI Summary` per head
```bash
# jq 1.6-compatible; $runs is the .check_runs array for one head SHA
jq -S '[ .check_runs[] | select(.name=="CI Summary" and .app.slug=="github-actions") ]
  | if length==0 then {conclusion:null, reason:"no_check_runs"}
    else (max_by(.completed_at // "")) as $r
      | {conclusion:$r.conclusion, completed_at:$r.completed_at, check_run_id:$r.id,
         superseded_count:(length-1)} end' <<<"$checks"
# Source: live behavior observed on #108 (two runs: failure 12:11:41Z, success 12:19:50Z)
```

### Read-only `gh` wrapper
```bash
gh_get() {  # only `gh api <path>` GET is permitted
  case "$1" in -*|"") echo "gh_get: bad path" >&2; return 2;; esac
  gh api -H "Accept: application/vnd.github+json" "$@"
}
```

### Parse `hex.audit` text
```bash
# findings: "  cowlib 2.19.0 - EEF-CVE-2026-43971 (MEDIUM)"
sed -nE 's/^  ([a-z0-9_]+) ([0-9][^ ]*) - ([A-Za-z0-9-]+) \(([A-Z]+)\)$/\1\t\2\t\3\t\4/p'
# section markers: "Advisories:" -> ignored=false ; "Ignored advisories:" -> ignored=true
```

### Lock delta for a merge commit
```bash
git diff "${sha}^" "${sha}" -- mix.lock \
  | sed -nE 's/^([-+])  "([a-z_0-9]+)": \{:hex, :[a-z_0-9]+, "([^"]+)".*/\1 \2 \3/p'
# yields "- mint 1.9.3 / + mint 1.10.0" pairs; group by package and compare to group_packages
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `mix deps.audit` (mirego DB) as the advisory check | `mix hex.audit` with built-in EEF/OSV advisories and `ignore_advisories` | Hex 2.5.x (installed 2.5.1) | hex.audit sees findings deps.audit does not |
| Dependabot alerts for security visibility | Not available for Hex via native graph | ongoing (GitHub has no Hex/mix.lock parser per sources) | Do not count on alerts |
| `gh pr list --json mergeable` | REST `pulls/N` | n/a | Avoid `UNKNOWN` |

**Deprecated/outdated:** MuonTrap v1 cgroup options (v1 cgroup removed in 2.0); `INBOX-TRIAGE.md` prose table (superseded by ledger).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | GitHub ubuntu-22.04 runner ships jq 1.6 | Standard Stack | A 1.7-only builtin would pass locally and fail in CI; mitigate by running the harness under `jq` 1.6 or avoiding new builtins |
| A2 | Closing a Dependabot PR without an ignore may re-open for a newer version (2.0.1) | Dispositions | If it never re-opens, the `dependabot.yml` ignore is harmless redundancy |
| A3 | `build`/`ci`/`test`/`docs` squash commits do not trigger a release-please release | Pitfall 7 | A release PR could be cut by a dependency landing; verify after the first landing |
| A4 | `@dependabot rebase|recreate|ignore this major version` command set and `rebase-strategy: auto` rebasing only on conflict | Pitfall 3/8 | Wrong command wording; user can use `gh pr update-branch` instead (D-134-07 allows both) |
| A5 | `/protection` read needs repository Administration: read; `github.token` cannot hold it | Branch protection | If CI can read it, `unreadable` would be pessimistic only |
| A6 | GitHub dependency graph still lacks mix.lock parsing | Advisory sources | If it now parses Hex, enabling alerts becomes valuable; the sbom 404 and enable-offer checkpoint cover this: after enabling, re-read `dependabot/alerts` before deciding |
| A7 | cowlib advisory EEF-CVE-2026-43966 is fixed by cowlib 2.21.0 (OSV lists only a commit) | Advisory table | Would need a bounded exception; confirm by re-running `mix hex.audit` after the bump |
| A8 | Req 0.7.5 / MuonTrap 2.0.1 will be what Dependabot proposes after rebase | Dispositions | Delta/version in the ledger must be re-read post-rebase, not trusted from this table |

## Open Questions (RESOLVED)

1. **Is the `Adoption Demo E2E` red on main at 6ef86d38 a flake or a regression?**
   - Known: prior three main runs green; failure is a MuonTrap timeout-retry then `ArgumentError`/`DBConnection` closure on a docs-only commit.
   - Unclear: whether a rerun passes.
   - Recommendation: authorized `gh run rerun 38762602374 --failed` as the first remote action; record both runs in the baseline.
   - **RESOLVED:** the authorized rerun is the first remote action, at the 134-04 Task 1 checkpoint; if the red persists it is a blocking baseline issue diagnosed before any landing (134-04 Task 2).
2. **Bounded exception vs landing for decimal 3.2.0 (a minor bump in runtime core)?** Recommend landing `decimal` as its own maintainer PR; 3.1.2 is the minimal fix, 3.2.0 is what Dependabot proposed.
   - **RESOLVED:** decimal lands in its own maintainer lock-only `build(deps):` PR (134-04 queue entry A5), at #112's decimal version if #112 still carries it, else 3.1.2.
3. **Include the demo lock in the collector?** Recommended (it holds the only unfixed HIGH, bandit), at the cost of a `mix deps.get` per run; the planner may instead record demo findings by reading the demo lock once and keeping them in the ledger with `scope: examples/adoption_demo` and exceptions.
   - **RESOLVED:** the demo lock is included with `scope: examples/adoption_demo` (134-01 collector), its fixable advisories are resolved by a lock-only refresh (134-05 entry B5), and bandit is a bounded exception with a `hex_version_gte` trigger (134-06).
4. **Enable Dependabot alerts?** Recommend offering it but expecting no Hex alerts; default to `source_disabled` + rationale.
   - **RESOLVED:** the enable action is offered at the 134-06 Task 1 checkpoint; the default is `source_disabled` with a ledger rationale.
5. **Number of landings (about 10) versus the plan fence.** Resolved by compressing into plans that each contain a repeatable "land one group, verify, record" loop driven by `dep_landing_evidence.sh`; the planner should confirm the user accepts the wall-clock cost or authorizes pipelined merges.
   - **RESOLVED by orchestrator:** serial landings accepted (the user directed "follow your recommendations"); the wall-clock cost is surfaced to the user again at the pre-execution checkpoint. The loop is defined once in 134-04 and iterated by 134-05.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| gh CLI (authed, `repo` + `workflow` scopes, repo admin) | collector | yes | 2.101.0 | none (fail closed) |
| jq | collector/validator/harness | yes | 1.7.1-apple local; runner likely 1.6 | write jq 1.6-compatible |
| Elixir/OTP + Hex | hex.audit, deps.tree | yes | 1.17.3 / OTP 27.3.4.15 / Hex 2.5.1 | none |
| Network to hex.pm, osv.dev | hex.audit, ledger authoring | yes | n/a | `unreadable` record; abort collection |
| bash | scripts | yes | 5.2 local (target 3.2-safe) | n/a |
| `mix` in `ci-script-tests` job | harness | no (job has no toolchain) | n/a | fake `mix` PATH shim |

**Missing dependencies with no fallback:** none. **With fallback:** `mix` in the script-test job (shim).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | bash harness (fake `gh`, fake `mix`, fake `date`) wired into `ci-script-tests`; ExUnit (`mix test test/install_smoke/dependabot_policy_test.exs`) for the one Dependabot-config lock |
| Config file | none (scripts self-contained) |
| Quick run command | `bash scripts/ci/test_collect_inbox.sh && bash scripts/ci/test_validate_inbox_ledger.sh` |
| Full suite command | `bash scripts/ci/test_collect_inbox.sh && bash scripts/ci/test_validate_inbox_ledger.sh && bash scripts/ci/test_dep_landing_evidence.sh && mix test test/install_smoke/dependabot_policy_test.exs test/install_smoke/nightly_policy_test.exs test/install_smoke/ci_observability_test.exs test/install_smoke/ci_lane_split_test.exs` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | Failing direction | File Exists? |
|--------|----------|-----------|-------------------|-------------------|-------------|
| INBOX-01 | Inventory has schema, `collected_at`, `repo`, `main_sha`, issues, PRs (head, mergeable_state, CI Summary by max `completed_at`, manifest files), advisories w/ source records, protection | harness | `bash scripts/ci/test_collect_inbox.sh` | Fixture with duplicate CI Summary check-runs -> must pick latest; failure to pick = FAIL | Wave 0 |
| INBOX-01 | Read-only: no `-X`/`--method` non-GET, no mutating `gh pr|issue` verb | harness (mutation tripwire) | same | Introduce a PUT in the script -> `mutations` file non-empty -> FAIL | Wave 0 |
| INBOX-01 | Fail closed: missing auth, a failed page, `hex.audit` exit 1 with no marker -> non-zero and no output file | harness | same | Each of `FAKE_GH_FAIL=api|page2|auth`, `FAKE_MIX_FAIL=garbage` must exit non-zero | Wave 0 |
| INBOX-01 | 403-disabled alerts and 403 protection become `source_disabled`/`unreadable` records, never zero | harness | same | Missing record or `0` count -> FAIL | Wave 0 |
| INBOX-01 | Live: collector against real repo produces valid inventory | live (closure) | `bash scripts/maintainer/collect_inbox.sh --out <tmp> && jq -e '.schema and .collected_at and .repo=="szTheory/rindle" and (.main_sha|length==40)' <tmp>` | Non-zero exit or missing key | Wave 0 |
| INBOX-02 | Missing item, duplicate, stale head SHA, stale inventory (>24h), terminal-state mismatch, `supersede` without successor, `defer` without gate/trigger, unknown disposition each rejected | harness | `bash scripts/ci/test_validate_inbox_ledger.sh` | One fixture per rule; validator must exit 1 with the rule's reason; a clean fixture must exit 0 | Wave 0 |
| INBOX-02 | Committed ledger shape (offline, no time/live) | harness `--offline` | `bash scripts/maintainer/validate_inbox_ledger.sh --offline --ledger .planning/INBOX-LEDGER.json` | Invalid enum/missing field -> exit 1 | Wave 0 |
| INBOX-02 | Live: ledger vs fresh inventory | live (closure) | `collect_inbox.sh --include <terminal nums> --out inv.json && validate_inbox_ledger.sh --inventory inv.json --ledger .planning/INBOX-LEDGER.json` | Any rejection, or inventory older than bound | Wave 0 |
| SEC-09 | Every finding in inventory has ledger record; `resolved` only if absent; exception needs unexpired expiry + valid trigger; expired -> reject; `ignore_advisories` ids match exceptions | harness | `bash scripts/ci/test_validate_inbox_ledger.sh` | Expired-exception fixture (clock injected via `INBOX_NOW_EPOCH`) must exit 1 | Wave 0 |
| SEC-09 | `mix hex.audit` wired in Quality as advisory | ExUnit/grep | `grep -n "mix hex.audit" .github/workflows/ci.yml` plus `mix test test/install_smoke/ci_observability_test.exs` | Step missing, or step lacks `continue-on-error`/runs on a non-lint leg | Wave 0 |
| SEC-09 | Live: advisories resolved/bounded | live (closure) | `mix hex.audit` (root) exits 0 **or** every remaining id has an unexpired ledger exception; same in `examples/adoption_demo` | Unrecorded finding -> validator exit 1 | n/a |
| DEPS-01 | Lock delta of a landing equals declared group packages | harness | `bash scripts/ci/test_dep_landing_evidence.sh` | Fixture merge commit with extra package -> exit 1 | Wave 0 |
| DEPS-01 | Post-merge per-job gate map (Quality both legs, Contract, Proof, Package Consumer lean/full, Adopter, Adoption Demo E2E, Cohort Demo Smoke); twin = `not-applicable: twin not built (Phase 137)` | harness | same | Twin reported `pass` or a missing main-only job -> FAIL | Wave 0 |
| DEPS-01 | #95 not merged; muontrap major ignored | ExUnit | `mix test test/install_smoke/dependabot_policy_test.exs` (extended) | ignore entry absent -> FAIL | extend existing |
| D-134-08 | Tests do not pin action SHAs; no phase-dir paths in live code | grep/ExUnit | `! grep -rn "043fb46d1a93c77aae656e7c1c64a875d1fc6a0a" test` ; `! grep -rn "\.planning/phases/134" scripts test .github` | Match found -> FAIL | n/a |

### Sampling Rate
- **Per task commit:** the relevant `bash scripts/ci/test_*.sh` harness plus `./scripts/maintainer/automation_first_contract.sh`.
- **Per wave merge:** full suite command above and `bash scripts/ci/test_nightly_incident.sh` (adjacent harness, same job).
- **Phase gate:** live collector + validator on fresh data (<24 h), `mix hex.audit` root and demo accounted for, `./scripts/maintainer/repo_hygiene_check.sh`, full CI green on the PR lane and post-merge push:main run read via `dep_landing_evidence.sh`.

### Wave 0 Gaps
- [ ] `scripts/maintainer/collect_inbox.sh`, `scripts/ci/test_collect_inbox.sh` (INBOX-01)
- [ ] `scripts/maintainer/validate_inbox_ledger.sh`, `scripts/ci/test_validate_inbox_ledger.sh` (INBOX-02, SEC-09)
- [ ] `scripts/maintainer/dep_landing_evidence.sh`, `scripts/ci/test_dep_landing_evidence.sh` (DEPS-01)
- [ ] `.planning/INBOX-LEDGER.json` initial (shape-valid)
- [ ] `ci.yml`: new `ci-script-tests` steps (after #120 lands), `mix hex.audit` advisory step in Quality; no new jobs and no change to `ci-summary.needs` (locked by `nightly_policy_test.exs`)
- [ ] `test/install_smoke/dependabot_policy_test.exs`: muontrap-major ignore assertion; `nightly_policy_test.exs:143,213` literal decoupling

## Security Domain

`security_enforcement` is not set to `false` in `.planning/config.json` (key absent), so this section applies.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (tooling uses the maintainer's existing `gh` auth) | fail closed on missing auth |
| V3 Session Management | no | n/a |
| V4 Access Control | yes | read-only token usage; no write scopes needed; GET-only wrapper + tripwire test; remote mutations require chat go-ahead |
| V5 Input Validation | yes | treat issue/PR titles, branch names and `hex.audit` text as untrusted: never `eval`/interpolate into shell; closed-vocabulary triggers; strict sed/jq parsing; `jq --arg` for all values |
| V6 Cryptography | no | n/a |
| V14 Configuration | yes | least-privilege workflow permissions if a CI collector is ever added (`contents: read`, `pull-requests: read`, `actions: read`, `checks: read`, `issues: read`) |
| Supply chain (SEC-09) | yes | `mix hex.audit` clean or bounded exceptions with expiry; pin actions by SHA (already) |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Command/argument injection via PR titles or branch names in scripts | Tampering | never expand untrusted fields into shell; pass through `jq --arg`; quote everything |
| Silent advisory suppression (implicit zero when a source is down or masked by ignores) | Repudiation / Information disclosure | explicit `source_disabled`/`unreadable` records; collector runs audit with ignores cleared; validator requires rationale |
| Stale evidence replay (old inventory/CI result presented as fresh) | Spoofing | `collected_at` bound, `head_sha` binding, `main_sha` in inventory |
| Over-privileged token leaking into CI | Elevation of privilege | collector is a maintainer-local command; CI variant gets only read permissions and records unreadable fields |
| Credential/PAT expiry silently masking release-train state | Denial of service | out of scope (GitHub App todo, due about 2026-11-15) |
| Malicious dependency bump | Tampering | per-risk-group landing, lock delta check, hex.audit, lock-only changes verified against registry |

## Recommended Plan Breakdown (<=6 plans, <=3 tasks each)

| Plan | Wave | Delivers | Reqs | Remote actions needing user go-ahead |
|------|------|----------|------|---------------------------------------|
| 01 Collector | 1 | `collect_inbox.sh` + `test_collect_inbox.sh` (fake gh/mix, tripwire, fail-closed cases); live dry run (read-only) | INBOX-01 | none |
| 02 Ledger + validator | 2 | `validate_inbox_ledger.sh` + harness (all 8 rejection fixtures, `--offline`); `.planning/INBOX-LEDGER.json` skeleton; `INBOX-TRIAGE.md` pointer; advisory/exception/landing record rules | INBOX-02, SEC-09 (rules) | none |
| 03 Advisory wiring + landing evidence | 2 (parallel with 02) | `dep_landing_evidence.sh` + harness; `ci.yml`: `mix hex.audit` advisory step + `ci-script-tests` harness steps (after #120 on main); `dependabot.yml` muontrap-major ignore + policy test | DEPS-01, SEC-09 (wiring) | none to author; the PR itself is user-merged |
| 04 Landing batch A | 3 | Rerun/establish main baseline; land #120, the `test:` decoupling PR, #113 (rebase), cowlib lock-only PR; record each landing | DEPS-01 | `gh run rerun`, `@dependabot rebase`, each `! gh pr merge N --squash --subject "..."` |
| 05 Landing batch B | 4 | mint and decimal lock-only PRs, then #105, #108, #109, #112 each rebased and landed serially (optionally pipelined); record post-rebase lock deltas and main-run job gates; demo lock refresh decision | DEPS-01, SEC-09 | same as above |
| 06 Disposition closure | 5 | #95 close (+ ignore live) and #42 retain; bandit bounded exception with expiry trigger; Dependabot-alerts offer (enable or `source_disabled` + rationale); populate ledger from fresh inventory; run collector + validator live; update REQUIREMENTS/ROADMAP credit | INBOX-01, INBOX-02, SEC-09, DEPS-01 | `gh pr close 95` + comment (or `@dependabot ignore this major version`), optional `gh api -X PUT repos/szTheory/rindle/vulnerability-alerts` |

Rules for the planner: plans 04/05 are the "stop and rescope after two halts on the same gate" risk surface; define the repeatable per-group loop once (rebase -> PR CI green on the *current* head -> user merge -> `dep_landing_evidence.sh <sha>` -> ledger record) so each plan is at most three tasks (author/verify, user-merge checkpoint, record). Any plan touching `ci.yml` goes after #120 lands to avoid the `ci-script-tests` hunk conflict.

## Project Constraints (from AGENTS.md)

- Automation-first acceptance: requirements close through executable tests/probes/collectors; human checkpoints may authorize credentials or irreversible actions but never satisfy a requirement. Run `./scripts/maintainer/automation_first_contract.sh` after changing planning artifacts (passes at baseline: exit 0 [VERIFIED]).
- Green-main posture: keep merge-blocking jobs green; PR-first for serious work; `./scripts/maintainer/repo_hygiene_check.sh` before release prep.
- Project memory constraints applied: squash merges with conventional subject; do not use `.planning`-filtering PR branches (CI reads `.planning` at runtime); CI lanes E2E/Cohort Smoke/Package-Consumer-Full run only on main; `install_smoke` tests that read `.planning` phase paths break on archiving; `ci.yml`-literal meta-tests (OBS-02 class) must be grepped in the same change that edits `ci.yml`.
- Note: the worktree `AGENTS.md` surfaced by a tool hook differs from the session-provided `AGENTS.md` in its model-routing section only (Cursor vs Claude/Codex overlay); the workflow rules above are identical in both. Phase 134 did not need either routing section.

## Sources

### Primary (HIGH confidence)
- Live `gh api` GET reads of szTheory/rindle (issues, pulls, check-runs, actions runs/jobs, branches, protection, vulnerability-alerts, dependabot/alerts, advisories) on 2026-10-15.
- Local `mix hex.audit`, `mix deps.audit`, `mix deps.tree`, `mix hex.info`, `mix help hex.audit` (Hex 2.5.1, Elixir 1.17.3/OTP 27).
- `api.osv.dev/v1/vulns/<id>` and `hex.pm/api/packages/<pkg>[/releases/<v>]` (fix versions, requirements).
- Repo files: `.github/workflows/ci.yml`, `.github/dependabot.yml`, `config/ci_required_checks.json`, `release-please-config.json`, `lib/rindle/av/subprocess.ex` (Read), `test/install_smoke/{nightly_policy,dependabot_policy,ci_observability}_test.exs`, `scripts/ci/test_nightly_incident.sh`, `gh pr diff 120`.

### Secondary (MEDIUM confidence)
- raw.githubusercontent.com changelogs: fhunleth/muontrap, elixir-ecto/ecto_sql, ex-aws/ex_aws; hexdocs.pm/req/changelog.html.
- docs.github.com: REST repos (vulnerability-alerts endpoints), dependency-graph supported ecosystems (Actions SHA note), managing Dependabot PRs.

### Tertiary (LOW confidence)
- Web search result summary on GitHub dependency graph lacking Elixir (elixirforum, github/advisory-database#1661); possibly dated.
- Training knowledge for Dependabot comment commands and release-please hidden commit types (tagged `[ASSUMED]`).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH, all tools exercised this session.
- Architecture: HIGH for collector/validator/test patterns (mirrors existing in-repo harnesses); MEDIUM for executable-trigger vocabulary (design recommendation).
- Pitfalls: HIGH for items 1, 2, 5, 6 (observed live); MEDIUM for 3, 7, 8 (partly assumed).

**Research date:** 2026-10-15
**Valid until:** 2026-10-22 for live state (Dependabot PR heads, advisory set, main CI move daily); 30 days for tooling/design guidance.
