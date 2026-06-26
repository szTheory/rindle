# Phase 105: Aggregate Required Check + Branch-Protection Flip - Research

**Researched:** 2026-06-21
**Domain:** GitHub Actions CI topology — single aggregate required-status-check ("CI Summary") + branch-protection reconciliation
**Confidence:** HIGH

## Summary

This phase lands ONE additive `CI Summary` aggregate job in `.github/workflows/ci.yml` and
makes it the **sole** required status check on `main`, replacing the current 12 live required
contexts. The change is split into a code PR (additive, reversible, no live mutation) and a
post-merge human go/no-go flip of branch protection. The implementation knowledge is already
fully locked in `105-CONTEXT.md` (D-01..D-13), backed by three prior research passes. This
RESEARCH.md's job is to (1) **verify the load-bearing file/line claims against the live code**
and (2) consolidate an **implementation-ready + validation-ready** view for the planner — most
critically the `## Validation Architecture` section that distinguishes automatable checks from
the human/post-merge live-API flip.

**Verification result: all canonical_refs in CONTEXT.md hold against the live code.** Every
load-bearing line reference (ci-observability `:1243-1315`, its 11-job `needs:` set, the
REQUIRED_CHECKS array `:17-31` + heredoc `:36-48`, the release coupling, the fork-gated jobs,
`name: CI` at `:1`) was confirmed byte-accurate. One minor advisory: D-06 prescribes a
`toJSON(needs)` jq-iteration idiom as the "house default," but the literal sibling repos
(lattice_stripe, sigra) use **per-lane env-var enumeration**, and only sigra treats `skipped`
as pass — see *State of the Art* and *Open Questions* for the (non-blocking) reconciliation.

**Primary recommendation:** Implement exactly per D-01..D-13. Add a pure, zero-permission,
network-free `ci-summary` job (`name: CI Summary`, `needs:` the same 11 jobs as
`ci-observability`, `if: always()`, explicit `needs.*.result` evaluation treating
`success`+`skipped` as pass) after `ci.yml:1315`; collapse `REQUIRED_CHECKS` and the heredoc
to the single `"CI Summary"` context; keep the live flip as a separate post-merge human step
verified by `scripts/ci/check_required_checks.sh main`.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

> Backed by three parallel research passes (GitHub Actions ecosystem best-practice; szTheory
> sibling-repo prior art; Rindle-internal code grounding). Honor verbatim — do not re-litigate.

**A. `CI Summary` is a NEW dedicated job, separate from `ci-observability`**
- **D-01:** Add a brand-new top-level job `ci-summary` with **`name: CI Summary`** (the exact
  string that becomes the required context). Place it last, after `ci-observability`
  (`ci.yml:1315`). Purely additive.
- **D-02:** The gate is **pure and network-free** — it evaluates only the `needs` context.
  Makes **no `gh api` call** and declares **no `permissions:`** (inherits workflow default
  `contents: read`). Do NOT extend `ci-observability` to gate: that job runs a
  `set -euo pipefail` paginated `gh api .../jobs` read (`ci.yml:1272-1275`, needs `actions: read`)
  and **can exit non-zero for infra reasons** — the 401-class flake recorded in
  `103-BASELINE.md:73-77`. A required check must not false-red on a GitHub API hiccup.
  `ci-observability` stays a separate, non-required telemetry job.

**B. `needs:` set + result-evaluation semantics**
- **D-03:** `CI Summary` **`needs:` the 11 deterministic gating jobs** — same set
  `ci-observability` already depends on: `quality, optional-dependencies, integration, contract,
  proof, package-consumer, adoption-demo-unit, cohort-demo-smoke, adoption-demo-e2e, adopter,
  brandbook-tokens`.
- **D-04:** **Exclude the three real-API soak/live lanes** (`mux-soak`, `gcs-soak`,
  `package-consumer-gcs-live`) from `needs:`. Rationale: (1) `package-consumer-gcs-live` is
  `continue-on-error: true` (`ci.yml:1072`) so its `result` is masked to `success` — gating on
  it is meaningless; (2) `mux-soak`/`gcs-soak` hit live third-party services with real
  credentials — gating every merge on them violates "a gate must not fail for reasons unrelated
  to code health," and a provider outage would block all merges; (3) Phase 106 moves soak/live
  to nightly. Matches the existing `ci-observability` omission (`103-PATTERNS.md:113-117`).
- **D-05:** **Skip semantics:** treat `success` **and** `skipped` as pass; treat `failure`
  and `cancelled` as fail. Skipped-as-pass is **mandatory** — `cohort-demo-smoke`,
  `adoption-demo-e2e`, `brandbook-tokens` are repo-gated (`if: github.repository ==
  'szTheory/rindle'`) and **skip on forks**; treating their skip as pass closes the fork trap.
  Safe because every dependency *root* (`quality`, `optional-dependencies`) is directly in
  `needs:`, so a real root failure is always caught.
- **D-06:** **Evaluate `needs.*.result` EXPLICITLY** — do not rely on implicit success. Avoid
  the "green checkmark lie" (an `if: always()` job that doesn't check results reports success
  even when a dependency failed). House idiom: an inline `run:` bash gate that iterates results
  and `exit 1`s on any non-pass, collecting **all** failing jobs first. Prefer iterating
  `toJSON(needs)` via `jq` (drift-proof — auto-covers whatever is in `needs:`) and append a
  `| Job | Result |` table to `$GITHUB_STEP_SUMMARY` using the repo's existing append idiom
  (`ci.yml:1278-1291`). Prefer over `re-actors/alls-green` (no szTheory repo adopted it; keeps a
  third-party action out of the merge-gate critical path).
- **D-07 (naming, locked by roadmap):** Job display name is **`CI Summary`** (GATE-01 names it
  verbatim). Do NOT adopt the siblings' `ci-gate`/`release_gate` name.

**C. Branch-protection list reconciliation**
- **D-08:** Collapse `setup_branch_protection.sh` `REQUIRED_CHECKS` from 13 entries to the single
  context **`"CI Summary"`**. Edit the **two** in-lockstep spots in that one file: the
  `REQUIRED_CHECKS=(...)` array (`:17-31`) AND the cosmetic `print_expected_text()` heredoc
  bullets (`:36-48`). `expected_json()`, `--print-expected*`, and the `gh api -X PUT` body read
  the array generically and need no change. `branch-protection-apply.yml` needs no edit.
- **D-09 (drift reconciliation, deliberate):** `brandbook-tokens` is currently in the script's
  expected list but **absent from the live required set** (`103-BASELINE.md:120-133`). After the
  flip it leaves the required list entirely but **keeps running** as a job, and becomes
  **transitively gated** for the first time via `CI Summary`'s `needs: [... brandbook-tokens]`.
  Intended tightening — **surface it explicitly in the PR description.** Before flipping, dump the
  live applied set (`scripts/ci/check_required_checks.sh main`).

**D. Rollout safety (highest blast radius) — two-step cutover, do not reorder**
- **D-10:** **The PR makes NO live branch-protection mutation.** It only (a) adds the `ci-summary`
  job and (b) edits the script's array + heredoc. During the PR the 12 individual contexts remain
  the live gate; `CI Summary` runs as a **new, non-required** check — fully reversible.
- **D-11:** **Apply the live flip only AFTER the job has run on `main` at least once.** A
  maintainer runs `GH_TOKEN=<admin-PAT> scripts/setup_branch_protection.sh main` (or dispatches
  `branch-protection-apply.yml`, or waits for the `17 7 * * *` nightly). **Human go/no-go.**
- **D-12 (the gotcha this avoids):** GitHub does NOT verify a required context name was ever
  produced — requiring `CI Summary` *before* any run posts it (or with a mismatched name) leaves
  every PR pending **forever** ("Expected — Waiting for status to be reported"). Merge-job-first /
  flip-second avoids it. The `if: always()` gate also fixes the latent fork trap (`Cohort Demo
  Smoke` is a live required context AND fork-gated today at `ci.yml:740`).
- **D-13 (verify the cutover):** Reuse `scripts/ci/check_required_checks.sh main` (read-only) to
  confirm live `.contexts[]` is exactly `CI Summary` and the diff vs `--print-expected-json` is
  empty. Also confirm the verbatim reported check-run name via
  `gh api repos/szTheory/rindle/commits/<main-sha>/check-runs` shows `CI Summary` before the flip.

### Claude's Discretion
- Exact bash/jq phrasing of the result loop, the `$GITHUB_STEP_SUMMARY` table wording, and
  `runs-on` pin (`ubuntu-22.04`, matching the repo) — planner's/executor's to finalize, as long
  as D-05/D-06 semantics hold.
- Whether to also adopt mailglass's read-only `verify-branch-protection.sh` is optional polish —
  `check_required_checks.sh` already covers verification (D-13).

### Deferred Ideas (OUT OF SCOPE)
- Soak/live lanes → nightly / off PR critical path — Phase 106 (LANE-03). Excluded from `needs:`
  here precisely because they are bound for nightly.
- Conditional skip-normalization for path-filtered lanes (rulestead's `release_gate.sh` pattern) —
  revisit in Phase 106 IF the trigger/lane split introduces `paths:`-filtered jobs. Not needed now.
- mailglass `verify-branch-protection.sh` adoption — optional read-only polish.
- Trigger/lane split, concurrency groups, scoping `package-consumer` matrix (Phase 106);
  async-safety / partitioning / action-pinning / `mix ci` / Dialyzer-lane (Phase 107).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GATE-01 | A single stable `CI Summary` aggregate job (`needs:` all jobs, `if: always()`, treating `skipped` as pass) becomes the sole signal representing overall CI status. | `ci-observability` (`ci.yml:1243-1315`) verified as the exact structural template: 11-job `needs:` (`:1246-1257`), `if: always()` (`:1258`), `$GITHUB_STEP_SUMMARY` append idiom (`:1278-1291`). New `ci-summary` job copies that shape minus the `gh api` read and `permissions:` (D-02). Sibling bash-loop idioms verified in lattice_stripe `:262-291` and sigra `:1325-1376` (skip-as-pass at `:1366`). |
| GATE-02 | `setup_branch_protection.sh` + nightly re-assert updated in the same change to require only `CI Summary`; fork-PR pending-forever trap closed; `CI` workflow name/filename + release coupling preserved. | `REQUIRED_CHECKS` array (`:17-31`, 13 entries) + heredoc (`:36-48`) verified as the two edit spots; `expected_json()` (`:64-85`) reads generically (no edit). `branch-protection-apply.yml:46` runs the script verbatim (no edit). Release coupling verified workflow-level only: `release.yml` `gate-ci-green` keys off `workflow_id: 'ci.yml'`+`conclusion` (`:180,:202`); `release-please-automerge.yml` keys off `on: workflow_run: workflows: [CI]`+`conclusion` (`:5-6,:22`) — neither references any job/check name. `name: CI` at `ci.yml:1`. Fork-gated jobs verified: `cohort-demo-smoke:750`, `adoption-demo-e2e:765`, `brandbook-tokens:1186`. |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Aggregate result evaluation (`CI Summary` job) | CI workflow (GitHub Actions) | — | Pure `needs.*.result` evaluation; no app code, no network. Lives entirely in `ci.yml`. |
| Required-check set declaration | Maintainer script (`setup_branch_protection.sh`) | CI workflow (nightly re-assert) | Single source of truth for the required-context list; `branch-protection-apply.yml` is the scheduled executor. |
| Live branch-protection mutation | GitHub REST API (`/branches/main/protection`) | Maintainer / human | Admin-PAT-gated write; deliberately a post-merge human step (D-11), never in PR CI. |
| Cutover verification | Maintainer script (`check_required_checks.sh`, read-only) | GitHub REST API (read) | Read-only GET + diff vs `--print-expected-json`; no mutation. |
| Release-train coupling | GitHub Actions workflow-run events | — | Consumes workflow run `conclusion` + name `CI`, never job/check names — invisible to this flip. |

## Canonical Reference Verification (drift audit)

> Every load-bearing file/line claim in `105-CONTEXT.md` was checked against the live tree on
> 2026-06-21. **No drift found.** Details below for the planner's confidence.

| CONTEXT.md claim | Live verification | Status |
|------------------|-------------------|--------|
| `ci.yml` is 1315 lines; `ci-observability` ends at `:1315` (file end) | `wc -l` = 1315; `ci-observability` last line is `:1315` | ✅ VERIFIED — new job appends at EOF [VERIFIED: codebase] |
| `ci-observability` at `:1243-1315` | Job block `:1243` (`ci-observability:`) → `:1315` | ✅ [VERIFIED: codebase] |
| `ci-observability` `needs:` = 11 named jobs | `:1246-1257`: quality, optional-dependencies, integration, contract, proof, package-consumer, adoption-demo-unit, cohort-demo-smoke, adoption-demo-e2e, adopter, brandbook-tokens | ✅ exact match to D-03 [VERIFIED: codebase] |
| `ci-observability` `if: always()` | `:1258` | ✅ [VERIFIED: codebase] |
| `ci-observability` runs paginated `gh api .../jobs`, needs `actions: read` (D-02 rationale) | `permissions: actions: read` (`:1259-1260`); `gh api --paginate .../actions/runs/${RUN_ID}/jobs` (`:1272-1275`); `set -euo pipefail` (`:1268`) | ✅ confirms the false-red risk D-02 cites [VERIFIED: codebase] |
| `$GITHUB_STEP_SUMMARY` brace-group append idiom at `:1278-1291` | Confirmed (`{ echo "## CI per-job timing..." ... } >> "$GITHUB_STEP_SUMMARY"`) | ✅ reusable for `CI Summary` table [VERIFIED: codebase] |
| `name: CI` at `ci.yml:1`; filename `ci.yml` | `:1` is `name: CI`; file is `.github/workflows/ci.yml` | ✅ LOCKED — do not touch [VERIFIED: codebase] |
| `REQUIRED_CHECKS` array at `:17-31` (13 entries) | `setup_branch_protection.sh:17-31` — exactly 13 entries | ✅ [VERIFIED: codebase] |
| Heredoc bullets at `:36-48` | `print_expected_text()` heredoc `:34-61`; the 13 bullet lines are `:36-48` | ✅ both edit spots confirmed [VERIFIED: codebase] |
| `expected_json()` at `:64-85`, reads array generically | `:64-85`; builds `contexts` from `${REQUIRED_CHECKS[@]}` via jq — no per-name encoding | ✅ no edit needed [VERIFIED: codebase] |
| `branch-protection-apply.yml` runs script verbatim, no edit | `:46` = `run: bash scripts/setup_branch_protection.sh main`; cron `17 7 * * *` (`:8`) | ✅ [VERIFIED: codebase] |
| `check_required_checks.sh` read-only, reuses `--print-expected-json` | GETs `/required_status_checks` `.contexts[]` (`:44-48`); expected via `--print-expected-json` (`:51-52`); diff tolerant (`:62`) | ✅ reusable as-is for D-13 [VERIFIED: codebase] |
| `release.yml` `gate-ci-green` keys off `workflow_id: 'ci.yml'` + `conclusion`, not job name | `:96` `gate-ci-green`; `workflow_id: 'ci.yml'` (`:180`); `conclusion !== 'success'` check (`:202-203`) | ✅ flip invisible [VERIFIED: codebase] |
| `release-please-automerge.yml` keys off `on: workflow_run: workflows: [CI]` + `conclusion` | `:4-6` `workflow_run: workflows: - CI`; `:22` `workflow_run.conclusion == 'success'` | ✅ flip invisible [VERIFIED: codebase] |
| Fork-gated skip-on-fork jobs | `cohort-demo-smoke` `if: github.repository == 'szTheory/rindle'` (`:750`); `adoption-demo-e2e` (`:765`); `brandbook-tokens` (`:1186`) | ✅ these are the D-05 skips that close the fork trap [VERIFIED: codebase] |
| `package-consumer-gcs-live` is `continue-on-error: true` (D-04 rationale 1) | `:1072` | ✅ result masked to success — gating meaningless [VERIFIED: codebase] |
| Soak lanes present & excluded from aggregator | `mux-soak` (`:925`), `gcs-soak` (`:998`) — both absent from `ci-observability` `needs:` | ✅ D-04 omission consistent [VERIFIED: codebase] |
| `103-BASELINE.md`: 12 live required contexts; `brandbook-tokens` drift | §2 lists exactly 12 contexts (`:94-106`); §3 diff `13d12 < brandbook-tokens` (`:119-122`) | ✅ pre-change gate confirmed [VERIFIED: codebase] |

**Drift found:** None in file/line references. One *idiom* divergence (not a CONTEXT.md error):
see *State of the Art* — D-06's preferred `toJSON(needs)` jq form differs from what the sibling
repos literally implement (per-lane env enumeration), but D-06 explicitly elects the jq form as
the superior house default and the difference is within Claude's Discretion.

## Standard Stack

> Pure GitHub Actions + bash/jq. No external packages installed. No npm/pip/cargo dependency.
> The `## Package Legitimacy Audit` and `## Environment Availability` sections are intentionally
> omitted — this phase installs nothing and adds no external tool dependency (it reuses `gh` +
> `jq`, already required by the existing scripts at `setup_branch_protection.sh:100-108`).

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| GitHub Actions `needs:` + `if: always()` + `${{ needs.*.result }}` | platform | Aggregate gate sees every upstream job's result even when one fails | Native dependency/result mechanism; the only correct way to build an aggregate gate [CITED: docs.github.com/actions — contexts/needs] |
| `toJSON(needs)` (GitHub Actions expression fn) | platform | Serialize the entire `needs` context to JSON for drift-proof iteration | D-06's elected idiom; auto-covers whatever is in `needs:` with no per-lane env var to maintain [CITED: docs.github.com/actions/learn-github-actions/expressions] |
| `jq` | repo-pinned (runner default) | Parse `toJSON(needs)` and iterate `.<job>.result` | Already a hard dependency of the existing scripts [VERIFIED: codebase setup_branch_protection.sh:105-108] |
| `gh` CLI | runner default / maintainer-local | `setup_branch_protection.sh` PUT + `check_required_checks.sh` read + `check-runs` confirm (D-13) | Already the repo's branch-protection tooling [VERIFIED: codebase] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Inline bash result-loop | `re-actors/alls-green` action | D-06 rejects: no szTheory repo adopted it; adds a third-party action to the merge-gate critical path (supply-chain surface). Planner may still choose it pinned-by-SHA only if named `allowed-skips` documentation is wanted. |
| `toJSON(needs)` jq iteration | Per-lane env-var enumeration (what siblings literally do) | Env enumeration must be hand-edited whenever `needs:` changes — drift-prone. D-06 prefers jq. (Both are valid; this is Claude's Discretion on phrasing.) |
| Extend `ci-observability` to gate | Separate `ci-summary` job | D-02 rejects extending: `ci-observability` makes a `gh api` call that can 401-flake (`103-BASELINE.md:73-77`) → would false-red the required check. |

## Architecture Patterns

### System Architecture Diagram

```
                    ┌─────────────────── ci.yml (name: CI) ───────────────────┐
  PR / push:main →  │  11 gating jobs (quality, optional-dependencies,         │
                    │  integration, contract, proof, package-consumer,         │
                    │  adoption-demo-unit, cohort-demo-smoke*, adoption-demo-  │
                    │  e2e*, adopter, brandbook-tokens*)   (* fork-skip)       │
                    │            │ each emits needs.<job>.result               │
                    │            ▼                                             │
                    │   ┌──────────────────┐      ┌──────────────────────┐    │
                    │   │  ci-observability │      │  ci-summary (NEW)    │    │
                    │   │  (telemetry,      │      │  name: CI Summary    │    │
                    │   │   gh api read,    │      │  if: always()        │    │
                    │   │   actions:read,   │      │  no permissions,     │    │
                    │   │   NOT required)   │      │  no network          │    │
                    │   └──────────────────┘      │  iterate toJSON(needs)│   │
                    │                             │  success|skipped→pass │   │
                    │                             │  failure|cancelled→x  │   │
                    │                             │  append summary table │   │
                    │                             └──────────┬───────────┘    │
                    └──────────────────────────────────────│────────────────┘
                                                            │ posts check-run "CI Summary"
                                                            ▼
   workflow run "CI" conclusion ──┐            ┌─── branch protection on main ───┐
   ├─ release.yml gate-ci-green   │  (D-11     │  required_status_checks.contexts │
   │  (workflow_id: ci.yml +      │   human    │  BEFORE flip: [12 individual]    │
   │   conclusion)                │   flip,    │  AFTER  flip: ["CI Summary"]     │
   └─ release-please-automerge    │   post-    └──────────────▲──────────────────┘
      (workflow_run: [CI] +       │   merge)                  │ gh api -X PUT
      conclusion)                 └──────────────► setup_branch_protection.sh
      ↑ NEITHER references job/check names — flip invisible    (REQUIRED_CHECKS=["CI Summary"])
                                                               ▲ nightly re-assert
                                                  branch-protection-apply.yml (17 7 * * *)
                                                               │ verify (read-only)
                                                  check_required_checks.sh main → diff == empty
```

### Pattern 1: Pure aggregate gate over `toJSON(needs)` (D-06 house idiom)
**What:** A final job that depends on all gating jobs, runs `if: always()`, and explicitly
iterates each `needs.<job>.result`, collecting all non-pass jobs before `exit 1`.
**When to use:** Whenever one stable required context must proxy "every gating lane is green."
**Skip-as-pass semantics (D-05):** `success` and `skipped` pass; `failure` and `cancelled` fail.
**Example (planner-finalizable; matches D-05/D-06 semantics):**
```yaml
# Source: derived from ci.yml:1243-1315 (structure) + sigra ci.yml:1325-1376 (skip-as-pass)
# + GitHub Actions toJSON(needs) (D-06 elected idiom). [VERIFIED: codebase + CITED: docs.github.com]
  ci-summary:
    name: CI Summary
    runs-on: ubuntu-22.04
    needs:
      - quality
      - optional-dependencies
      - integration
      - contract
      - proof
      - package-consumer
      - adoption-demo-unit
      - cohort-demo-smoke
      - adoption-demo-e2e
      - adopter
      - brandbook-tokens
    if: always()
    # NO permissions: block — inherits workflow default contents: read (D-02). No network call.
    steps:
      - name: Evaluate gating job results
        env:
          NEEDS_JSON: ${{ toJSON(needs) }}
        run: |
          set -euo pipefail
          failed=0
          {
            echo "## CI Summary"
            echo ""
            echo "| Job | Result |"
            echo "| --- | --- |"
          } >> "$GITHUB_STEP_SUMMARY"
          # Iterate every job in needs (drift-proof: auto-covers whatever is in needs:).
          while IFS=$'\t' read -r job result; do
            echo "| ${job} | ${result} |" >> "$GITHUB_STEP_SUMMARY"
            case "${result}" in
              success|skipped) ;;                       # D-05: pass
              *) echo "Gating job '${job}': ${result}"; failed=1 ;;  # failure|cancelled → fail
            esac
          done < <(jq -r 'to_entries[] | "\(.key)\t\(.value.result)"' <<<"${NEEDS_JSON}")
          if [ "${failed}" -ne 0 ]; then
            echo "CI Summary: one or more gating jobs did not pass." >&2
            exit 1
          fi
          echo "CI Summary: all gating jobs passed (success or intentional skip)."
```

### Pattern 2: Two-step cutover (code PR, then human flip)
**What:** PR adds the job + edits the script (no live mutation). After merge & first `main`
run, a maintainer applies the flip; then verify.
**Why it's the only safe order (D-12):** GitHub never validates that a required context name was
ever produced. Flipping protection to require `CI Summary` *before* a run posts that exact name
→ every PR hangs forever ("Expected — Waiting for status to be reported"). Merge-job-first /
flip-second is mandatory.

### Anti-Patterns to Avoid
- **The "green checkmark lie":** an `if: always()` aggregate whose steps don't *check*
  `needs.*.result` reports success even when a dependency failed. Must evaluate results
  explicitly and `exit 1` (D-06).
- **Gating on a `continue-on-error: true` job:** its `result` is masked to `success`
  (`package-consumer-gcs-live`, `:1072`) — gating on it is meaningless (D-04).
- **Putting a network call in the required gate:** `ci-observability`'s `gh api` read can 401-flake
  → never make the required check depend on an API call (D-02).
- **Flipping protection before the named check has ever run:** the pending-forever trap (D-12).
- **Renaming `name: CI` or `ci.yml`:** breaks `release.yml gate-ci-green` + `release-please-automerge.yml` (D-08/GATE-02).
- **Re-encoding the required-check name in a second file:** the list lives in ONE file, two spots — edit both, add no third (D-08).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Knowing which lanes failed | Per-lane `if:` chains across jobs | One aggregate `ci-summary` over `needs.*.result` | Native, drift-proof; one required context immune to matrix-name churn. |
| Live required-check verification | New verifier script | `scripts/ci/check_required_checks.sh main` (read-only, exists) | Already reads `.contexts[]` and diffs vs `--print-expected-json` (D-13). |
| Required-set source of truth | Hardcode contexts in the apply workflow | `setup_branch_protection.sh REQUIRED_CHECKS` array | `expected_json()` + `--print-expected-json` already read it generically. |
| Iterating the needs set | Maintain a per-lane env-var list | `toJSON(needs)` + `jq to_entries` | Auto-covers whatever is in `needs:`; no hand-edit on lane changes (D-06). |

**Key insight:** The whole phase is *removal of bespoke surface*, not addition. Collapsing 12
contexts to 1 makes the gate durable; everything else (verifier, source-of-truth, summary idiom)
already exists in-repo and is reused verbatim.

## Common Pitfalls

### Pitfall 1: Pending-forever after the flip (D-12)
**What goes wrong:** Branch protection requires `CI Summary` but no run has posted that exact
check-run name → every PR shows "Expected — Waiting for status to be reported," unmergeable.
**Why it happens:** GitHub does not verify a required context name was ever produced.
**How to avoid:** Merge-job-first / flip-second (D-10/D-11). Before flipping, confirm the check-run
name via `gh api repos/szTheory/rindle/commits/<main-sha>/check-runs` shows `CI Summary` (D-13).
**Warning signs:** A PR's checks tab lists `CI Summary` as "Expected" with no run linked.

### Pitfall 2: Name-string mismatch (job `name:` ≠ required context)
**What goes wrong:** The required context is the **`name:`** value (`CI Summary`), not the job id
(`ci-summary`). A mismatch (e.g. requiring `ci-summary`) reproduces Pitfall 1.
**How to avoid:** Job id `ci-summary`, `name: CI Summary` (D-01/D-07). The required-check string
in `REQUIRED_CHECKS` must be exactly `"CI Summary"` (matching the `name:`).
**Warning signs:** `check_required_checks.sh` diff is non-empty after the flip.

### Pitfall 3: Skip masking a real root failure
**What goes wrong:** Blanket skip-as-pass could "merge through" if a failed root only surfaced as a
skipped downstream dependent.
**Why it's safe here (D-05):** Every dependency root (`quality`, `optional-dependencies`) is
*directly* in `needs:`, so a real root failure is caught directly — it can't hide behind a skip.
The only skips are deterministic fork-gates (`if: github.repository ==`).
**Warning signs (future):** If Phase 106 adds `paths:`-filtered jobs, revisit with rulestead's
conditional skip-normalization (deferred). Not applicable in this phase.

### Pitfall 4: Gating on skip-prone / live-API lanes (D-04)
**What goes wrong:** Including `mux-soak`/`gcs-soak`/`package-consumer-gcs-live` in `needs:` makes
the gate fail on provider outages or always-pass on `continue-on-error`.
**How to avoid:** Exclude all three — mirror the existing `ci-observability` omission.
**Warning signs:** A merge blocked by a third-party provider outage, or a green gate despite a
real `package-consumer-gcs-live` failure.

### Pitfall 5: brandbook-tokens silent tightening (D-09)
**What goes wrong:** `brandbook-tokens` goes from non-gating (live drift) to *transitively* gating
via `CI Summary`'s `needs:` — a behavior change that could surprise contributors.
**How to avoid:** Call it out explicitly in the PR description as a deliberate tightening. Dump the
live set first (`check_required_checks.sh main`) so the cutover starts from a known state.

## Validation Architecture

> `workflow.nyquist_validation` is **absent** from `.planning/config.json` → treated as **enabled**.
> This section drives VALIDATION.md / Dimension 8. The defining tension of this phase: the *code*
> change is fully PR-CI-automatable, but the *live branch-protection flip* (D-11) is an admin-PAT
> mutation that **cannot** run in PR CI — it is a human/post-merge go/no-go. The map below draws
> that line explicitly per success criterion.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | YAML/shell structural assertions + GitHub API read-back (no ExUnit involvement — zero `lib/`/test change) |
| Config file | none — assertions are shell one-liners over `ci.yml` and the two scripts |
| Quick run command | `bash -n scripts/setup_branch_protection.sh && python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"` |
| Full suite command | The repo's existing `CI` workflow run on the PR (the 11 gating jobs + the new `CI Summary` job running as a non-required check, D-10) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GATE-01 | `ci-summary` job exists with `name: CI Summary` | structural | `python3 -c "import yaml; d=yaml.safe_load(open('.github/workflows/ci.yml')); assert d['jobs']['ci-summary']['name']=='CI Summary'"` | ✅ assert-only |
| GATE-01 | `needs:` is exactly the 11 gating jobs (not soak/live) | structural | `python3 -c "import yaml; n=set(yaml.safe_load(open('.github/workflows/ci.yml'))['jobs']['ci-summary']['needs']); assert n=={'quality','optional-dependencies','integration','contract','proof','package-consumer','adoption-demo-unit','cohort-demo-smoke','adoption-demo-e2e','adopter','brandbook-tokens'}, n"` | ✅ assert-only |
| GATE-01 | Job has `if: always()` | structural | `python3 -c "import yaml; j=yaml.safe_load(open('.github/workflows/ci.yml'))['jobs']['ci-summary']; assert j['if']=='always()' or j.get('if')==True"` (note: `if: always()` may parse as a string — assert the raw text) | ✅ assert-only |
| GATE-01 | Gate has **no `permissions:`** block and **no `gh api`** call (D-02 purity) | structural | `python3 -c "import yaml; j=yaml.safe_load(open('.github/workflows/ci.yml'))['jobs']['ci-summary']; assert 'permissions' not in j"` + `grep -A60 'ci-summary:' .github/workflows/ci.yml | grep -q 'gh api' && echo FAIL || echo OK` | ✅ assert-only |
| GATE-01 | Skip-as-pass semantics present (D-05) | structural | `grep -A60 'ci-summary:' .github/workflows/ci.yml | grep -q 'skipped'` (the result loop references skipped) | ✅ assert-only |
| GATE-01 | Gate fails red on a real failure (behavior) | **runtime (PR CI)** | Observed: on the PR, if any gating job fails, `CI Summary` reports failure. Cannot be unit-forced offline; relies on the live PR run. Optional: a throwaway branch that forces one job to fail to prove red. | runtime / manual |
| GATE-01 | Fork PR reports `CI Summary` success, not hang | **runtime (fork PR)** | Hard to automate in-repo (needs an actual fork PR). Logic-provable: the three fork-gated jobs skip and D-05 maps skip→pass, so `CI Summary` runs and passes. Validate by reasoning + (optional) a real fork test PR. | manual / logic |
| GATE-02 | `REQUIRED_CHECKS` array == single `"CI Summary"` | structural | `bash scripts/setup_branch_protection.sh --print-expected-json | jq -e '.required_status_checks.contexts == ["CI Summary"]'` | ✅ assert-only |
| GATE-02 | Heredoc bullets collapsed to one (cosmetic, in lockstep) | structural | `bash scripts/setup_branch_protection.sh --print-expected | grep -c '^  - '` returns `1` | ✅ assert-only |
| GATE-02 | `name: CI` and filename preserved | structural | `python3 -c "import yaml; assert yaml.safe_load(open('.github/workflows/ci.yml'))['name']=='CI'"` + `test -f .github/workflows/ci.yml` | ✅ assert-only |
| GATE-02 | Release coupling references workflow run, not job/check name | structural | `grep -q "workflow_id: 'ci.yml'" .github/workflows/release.yml` + `grep -Pzoq 'workflows:\s*\n\s*- CI' .github/workflows/release-please-automerge.yml` (and confirm neither file greps for `CI Summary`/job names) | ✅ assert-only |
| GATE-02 | `branch-protection-apply.yml` unchanged (still runs script verbatim) | structural | `grep -q 'bash scripts/setup_branch_protection.sh main' .github/workflows/branch-protection-apply.yml` | ✅ assert-only |
| GATE-02 | **Live required set == ["CI Summary"] after flip (D-13)** | **post-merge, human** | `bash scripts/ci/check_required_checks.sh main` → live `.contexts[]` is exactly `CI Summary` AND the diff vs `--print-expected-json` is empty. Requires admin-read `gh` session + the flip already applied. **Cannot run in PR CI.** | runtime / human |
| GATE-02 | **Reported check-run name is verbatim `CI Summary` before flip (D-13)** | **post-merge, human** | `gh api repos/szTheory/rindle/commits/<main-sha>/check-runs --jq '.check_runs[].name' | grep -Fx 'CI Summary'` | runtime / human |

### Automatable vs Human/Post-Merge (the load-bearing distinction)
**Fully automatable in PR CI / as static assertions (no live mutation):**
- All YAML-structure assertions on the `ci-summary` job (name, `needs:` set, `if: always()`,
  no-`permissions`, no-`gh api`, skip-as-pass reference).
- `setup_branch_protection.sh --print-expected-json` == `["CI Summary"]` and the heredoc bullet count.
- `name: CI` / filename preservation; release-coupling-references-workflow-not-jobname assertions.
- The new `CI Summary` job *running green on the PR as a non-required check* (D-10) — visible in the PR's checks tab.

**Human / post-merge go/no-go (cannot run in PR CI — by design, D-11):**
- The actual `gh api -X PUT .../protection` flip (admin-PAT mutation). This is the single
  highest-blast-radius step and is deliberately gated behind a maintainer.
- `check_required_checks.sh main` read-back confirming live `.contexts[]` == `["CI Summary"]`
  with empty diff (D-13) — requires the flip to have happened and admin-read auth.
- `commits/<main-sha>/check-runs` name confirmation before the flip (D-13).
- The fork-PR "reports success not hang" behavior — logic-provable from D-05, but truly observable
  only via a real fork PR (no in-repo automation can manufacture a fork run).

### Sampling Rate
- **Per task commit:** `bash -n scripts/setup_branch_protection.sh` + YAML parse of `ci.yml` + the
  `--print-expected-json == ["CI Summary"]` assertion.
- **Per wave / PR:** the full `CI` workflow run on the PR (proves the new job runs green as a
  non-required check, D-10).
- **Phase gate (post-merge, human):** the D-11 flip + D-13 read-back. This is the milestone's
  between-step human checkpoint — record it as a VERIFICATION/UAT item, not a CI assertion.

### Wave 0 Gaps
- [ ] No new test file needed — assertions are inline shell/python one-liners over committed YAML/scripts.
- [ ] (Optional) A tiny `scripts/ci/assert_ci_summary_shape.sh` could wrap the GATE-01/GATE-02
      structural assertions for a single `bash` invocation — planner discretion; not required (the
      one-liners above suffice and the existing `check_required_checks.sh` covers the live side).

*If the planner wants one automatable wrapper, the structural assertions above are the contents.*

## Runtime State Inventory

> This phase edits CI config + a maintainer script and performs ONE live branch-protection
> mutation (post-merge). The "renamed string" analog here is the **required-check context set**.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no datastore keys reference the check names. (Verified: only `setup_branch_protection.sh` encodes them.) | None |
| Live service config | **GitHub branch protection on `main`** stores the required `.contexts[]` (12 today) in GitHub's config, NOT in git. After the code merges, GitHub still requires the OLD 12 contexts until the D-11 flip runs. | **Live API flip (D-11):** `setup_branch_protection.sh main` with admin PAT, post-merge, human-gated. This is the data migration, distinct from the code edit. |
| OS-registered state | None (no Task Scheduler / cron outside the repo). The `17 7 * * *` nightly is GitHub-side and re-runs the script (auto-picks up the new array). | None — nightly self-heals to the new set. |
| Secrets/env vars | `BRANCH_PROTECTION_PAT` (used by `branch-protection-apply.yml:43`) and the maintainer's admin `gh` session — names unchanged, only the value's *effect* (which contexts it sets) changes. | None — secret unchanged. |
| Build artifacts | None — no compiled artifact embeds the check names. | None |

**Canonical question answered:** After the PR merges and the code says `["CI Summary"]`, GitHub's
live branch protection STILL requires the old 12 contexts until a maintainer runs the flip (or the
nightly fires). That gap is intentional (D-10/D-11) and is the human go/no-go step.

## Code Examples

### Verify expected set collapsed to one context (automatable)
```bash
# Source: setup_branch_protection.sh:64-96 (expected_json/--print-expected-json). [VERIFIED: codebase]
bash scripts/setup_branch_protection.sh --print-expected-json \
  | jq -e '.required_status_checks.contexts == ["CI Summary"]'
```

### Confirm the live cutover (post-merge, human — D-13)
```bash
# Source: scripts/ci/check_required_checks.sh (read-only). [VERIFIED: codebase]
bash scripts/ci/check_required_checks.sh main
# Expect: live "## Live required status checks" lists only "CI Summary",
#         and the diff vs expected is EMPTY.

# Confirm the reported check-run name BEFORE flipping (avoids the pending-forever trap):
gh api repos/szTheory/rindle/commits/"$(git rev-parse origin/main)"/check-runs \
  --jq '.check_runs[].name' | grep -Fx 'CI Summary'
```

### Apply the live flip (post-merge, human — D-11)
```bash
# Only AFTER the ci-summary job has run on main at least once.
GH_TOKEN=<admin-PAT> bash scripts/setup_branch_protection.sh main
# OR dispatch .github/workflows/branch-protection-apply.yml, OR wait for the 17 7 * * * nightly.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| N matrix-suffixed required contexts (12–13 here) | One stable aggregate context (`CI Summary`) | This phase (v1.20 GATE-01/02) | Branch protection becomes immune to matrix-name churn; Phase 106 lane renames never touch protection again. |
| `brandbook-tokens` non-gating (live drift) | Transitively gated via `CI Summary needs:` | This phase (D-09) | Deliberate tightening — flag in PR. |
| Sibling repos enumerate lanes by env var | rindle elects `toJSON(needs)` jq iteration (D-06) | This phase | Drift-proof; auto-covers `needs:` changes. |

**Idiom divergence to note (non-blocking):**
- The literal sibling implementations differ from D-06's elected form. lattice_stripe
  (`ci.yml:262-291`) and sigra (`ci.yml:1325-1376`) both **enumerate lanes via per-lane env
  vars**, NOT `toJSON(needs)`. lattice_stripe checks only `!= "success"` (does **not** treat
  `skipped` as pass); sigra DOES treat `skipped` as pass (`:1366`). [VERIFIED: codebase — sibling repos]
- This is not a CONTEXT.md error: D-06 explicitly *prefers* the `toJSON(needs)` jq form as the
  superior house default precisely because it is drift-proof, and skip-as-pass (D-05) is mandatory
  for rindle (fork gates). The planner should follow D-05/D-06 (jq iteration + skip-as-pass), using
  sigra as the closest prior art for skip-as-pass and lattice_stripe for the
  "collect-all-failures-before-exit" structure. The Pattern 1 example above already encodes this.

## Security Domain

> `security_enforcement` is not explicitly `false` in config → treated as enabled. However this is
> a **DX/infra, zero-`lib/`-change** phase: no auth, session, access-control, input-validation,
> or cryptography surface is added. The only relevant controls are CI least-privilege and
> supply-chain posture.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | yes (CI) | New gate declares **no `permissions:`** → inherits workflow default `contents: read` (least privilege; D-02). The mutating PUT stays admin-PAT-gated and human-run (D-11). |
| V5 Input Validation | no | — (no user input; `toJSON(needs)` is platform-controlled) |
| V6 Cryptography | no | — |
| V14 Configuration | yes | No third-party action added to the merge-gate critical path (D-06 rejects `re-actors/alls-green` unpinned). Workflow-level `permissions: contents: read` untouched. |

### Known Threat Patterns for GitHub Actions CI
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Required gate false-reds on infra flake | Denial of Service (merges blocked) | Pure network-free gate; no `gh api` in the required check (D-02). |
| Supply-chain via unpinned 3rd-party gate action | Tampering | Use inline bash; if any action is added, pin by SHA (D-06). Out of scope this phase. |
| Privilege creep in CI jobs | Elevation of Privilege | Gate adds no `permissions:`; inherits `contents: read` (D-02). |
| Untrusted fork code with secrets | Information disclosure | Out of scope — fork jobs remain fail-closed/skip; `pull_request_target` is explicitly Out of Scope (REQUIREMENTS.md:122). |

## Assumptions Log

> Every factual claim in this RESEARCH.md is either [VERIFIED: codebase] against the live tree or
> [CITED: docs.github.com] for platform semantics. No `[ASSUMED]` claims were introduced.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | (none) | — | All file/line refs verified against live code 2026-06-21; all decisions are user-locked D-01..D-13. |

**This table is empty:** all claims were verified or cited — no new user confirmation needed
beyond the already-locked D-01..D-13.

## Open Questions

1. **Exact bash/jq phrasing of the result loop + `runs-on` pin**
   - What we know: D-05/D-06 semantics are fixed; `runs-on: ubuntu-22.04` matches the repo.
   - What's unclear: precise loop wording — explicitly **Claude's Discretion** per CONTEXT.md.
   - Recommendation: use the Pattern 1 example (jq over `toJSON(needs)`, collect-all-then-exit,
     skip-as-pass). Mirrors sigra for skip-as-pass + lattice_stripe for failure collection.

2. **Sibling idiom divergence (env-enum vs `toJSON(needs)`)**
   - What we know: D-06 elects the jq form; siblings literally use env enumeration.
   - What's unclear: nothing blocking — D-06 is the authority and the jq form is strictly more
     drift-proof.
   - Recommendation: follow D-06 (jq). Surfaced here only so the plan-checker doesn't flag a false
     "doesn't match prior art" mismatch.

3. **Forcing a red/fork run for validation**
   - What we know: GATE-01's "fails red on real failure" and "fork PR reports success" are
     logic-provable but not in-repo automatable.
   - What's unclear: whether to invest in a throwaway-branch / real-fork-PR demonstration.
   - Recommendation: treat both as VERIFICATION/UAT (human) items, not CI assertions. The PR's own
     run already proves the green path; reasoning from D-05 covers the skip/fork path.

## Sources

### Primary (HIGH confidence)
- `.github/workflows/ci.yml` (`:1` name, `:740/750/765/1186` fork gates, `:925/998/1072` soak/live, `:1243-1315` ci-observability) — structure verified [VERIFIED: codebase]
- `scripts/setup_branch_protection.sh` (`:17-31` array, `:36-48` heredoc, `:64-85` expected_json) [VERIFIED: codebase]
- `scripts/ci/check_required_checks.sh` (read-only verifier) [VERIFIED: codebase]
- `.github/workflows/branch-protection-apply.yml` (`:46` runs script verbatim) [VERIFIED: codebase]
- `.github/workflows/release.yml` `gate-ci-green` (`:96,:180,:202`) [VERIFIED: codebase]
- `.github/workflows/release-please-automerge.yml` (`:4-6,:22`) [VERIFIED: codebase]
- `.planning/phases/103-observability-baseline/103-BASELINE.md` (§2 12 contexts, §3 drift) [VERIFIED: codebase]
- `.planning/phases/103-observability-baseline/103-PATTERNS.md` (summary-append, perms, Pitfall 4) [VERIFIED: codebase]
- `105-CONTEXT.md` D-01..D-13 (locked decisions) [VERIFIED: codebase]

### Secondary (MEDIUM confidence)
- `/Users/jon/projects/lattice_stripe/.github/workflows/ci.yml:262-291` (`ci-gate`, env-enum, no skip-pass) [VERIFIED: codebase — sibling]
- `/Users/jon/projects/sigra/.github/workflows/ci.yml:1325-1376` (`ci-gate`, env-enum, skip-as-pass `:1366`) [VERIFIED: codebase — sibling]
- GitHub Actions `needs` / `if: always()` / `toJSON(needs)` / required-status-check semantics [CITED: docs.github.com/actions]

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — pure platform + in-repo tooling, all verified.
- Architecture: HIGH — `ci-observability` is an exact in-repo structural analog; release coupling verified workflow-level.
- Pitfalls: HIGH — every pitfall traced to a verified line + a locked decision.
- Validation: HIGH — automatable vs human split is concrete and grounded in D-11/D-13.

**Research date:** 2026-06-21
**Valid until:** 2026-07-21 (stable; GitHub Actions + branch-protection API are slow-moving). Re-verify line numbers if `ci.yml` is edited before planning.
