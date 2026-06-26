# 105 — Branch-Protection Flip Runbook (post-merge, human go/no-go)

**Audience:** a repo maintainer with an admin `gh` session (or an admin-scoped PAT) on
`szTheory/rindle`.
**Status of the PR that ships this file:** purely additive and fully reversible — it makes
**NO** live branch-protection mutation. The live flip is a separate, deliberate **post-merge
human step** (D-11) documented below.

> ⚠️ **Do not reorder.** The cutover is strictly **D-10 → D-11 → D-13**. Flipping protection
> before `CI Summary` has run on `main` at least once leaves every PR pending forever
> (D-12). Read the whole runbook before touching branch protection.

---

## 1. Cutover summary — "Do not reorder" (D-10 → D-11 → D-13)

1. **This PR (D-10): additive only, no live mutation.** It adds the `ci-summary` job
   (`name: CI Summary`) to `.github/workflows/ci.yml` and collapses
   `scripts/setup_branch_protection.sh`'s required-check declaration to the single context
   `CI Summary`. During the PR, the **12 individual matrix-suffixed contexts remain the live
   gate**, and `CI Summary` runs as a **new, NON-required** check. Nothing about live branch
   protection changes — the PR is fully reversible (revert the commits and the new check
   simply stops being produced).

2. **The flip (D-11): post-merge, human, admin-only.** The live branch-protection mutation
   happens **only after** `ci-summary` has actually run on `main` at least once. It is an
   admin-PAT write to `/branches/main/protection` performed by a maintainer — it **cannot and
   must not** run inside PR CI.

3. **The verification (D-13): read-back after the flip.** Confirm the live `.contexts[]` is
   exactly `["CI Summary"]` with an empty diff vs the committed expected list.

---

## 2. The pending-forever trap (D-12)

GitHub **does not verify** that a required status-check context name was ever produced. If you
require `CI Summary` **before** any run on `main` has posted a check-run with that exact name —
or if the required string does not byte-match the produced name — **every** subsequent PR will
hang **pending forever**, waiting for a check that will never report.

**Mandatory order: merge-the-job-first, flip-protection-second.** Merge this PR, let CI run on
`main` so the `CI Summary` check-run is produced at least once, confirm that name exists
(Step 4.2 below), and **only then** flip protection.

> **Name precision:** the required context string is the job **`name:`** value — the literal
> **`CI Summary`** — **NOT** the job id `ci-summary`. The script already encodes `CI Summary`;
> do not "correct" it to the job id.

---

## 3. PR-description callout — copy verbatim into the PR body (D-09)

> **Gate tightening (deliberate):** Collapsing branch protection to the single `CI Summary`
> aggregate brings **`brandbook-tokens` into the merge gate for the first time, transitively**,
> via `CI Summary`'s `needs:`. `brandbook-tokens` was previously **non-gating** — it is present
> in the committed expected list but **absent from the live `.contexts[]`** today (live drift
> recorded in `103-BASELINE.md`). After the post-merge flip, a `brandbook-tokens` failure will
> turn `CI Summary` red and **block merge**. This is an intended tightening, not an accident —
> reviewers should expect the token→CSS pipeline to be enforced from this point on.

---

## 4. The flip + verification — human / post-merge steps

> Every command below is a **human, post-merge** step requiring an **admin `gh` session** (or
> `GH_TOKEN=<admin-PAT>`). Do **not** run any of these until this PR is merged **and**
> `ci-summary` has run on `main` at least once.

### 4.1 Pre-flip dump of the live set (start from a known state — D-09)

```bash
bash scripts/ci/check_required_checks.sh main
```

Records the **pre-flip** live `.contexts[]` (expected today: the 12 individual contexts, with
`brandbook-tokens` drift) so you have a before-state to compare against.

### 4.2 Confirm the `CI Summary` check-run name was actually produced on `main` — BEFORE flipping (D-13)

```bash
gh api repos/szTheory/rindle/commits/"$(git rev-parse origin/main)"/check-runs \
  --jq '.check_runs[].name' | grep -Fx 'CI Summary'
```

This **must print `CI Summary`**. If it prints nothing, the `ci-summary` job has not yet run on
the latest `main` commit (or the name does not match) — **STOP and do not flip** (D-12). Wait
for CI on `main` to finish and re-run this check.

### 4.3 Apply the flip (D-11)

```bash
GH_TOKEN=<admin-PAT> bash scripts/setup_branch_protection.sh main
```

Alternatives that run the **same script verbatim** (and self-heal to the collapsed array):
dispatch `.github/workflows/branch-protection-apply.yml`, or simply wait for the nightly
re-assert (`17 7 * * *`).

### 4.4 Verify the cutover (D-13)

```bash
bash scripts/ci/check_required_checks.sh main
```

**Expect:** live `.contexts[]` is **exactly `["CI Summary"]`**, and the diff vs
`--print-expected-json` is **EMPTY**. A non-empty diff means the flip did not fully land — do
not consider the cutover complete until the diff is empty.

### 4.5 (Optional) Fork-PR confirmation

Open a fork PR and confirm `CI Summary` **reports success** (rather than hanging on the
fork-skipped repo-gated jobs). This is the skip-as-pass (D-05) behavior that closes the
fork pending-forever trap; it is logic-provable from the job but observable only via a real
fork PR.

---

## 5. Release coupling is unaffected — no change required there

The release train consumes the **workflow run** conclusion and the workflow **name `CI`**,
never job- or check-names:

- `release.yml`'s `gate-ci-green` is keyed on `workflow_id: 'ci.yml'`.
- `release-please-automerge.yml` is keyed on `on: workflow_run: workflows: [CI]`.

Because the flip changes only the **required status-check context** (a branch-protection
field), and never the workflow filename or its `name: CI`, the flip is **invisible to the
release train** and requires **no change** to either release workflow.

---

## 6. Reversibility

If anything looks wrong after the flip, re-expand `REQUIRED_CHECKS` in
`scripts/setup_branch_protection.sh` to the prior 12-context set and re-run
`bash scripts/setup_branch_protection.sh main`. Because the script is the single source of
truth and the apply path is idempotent, reverting is a one-command operation.
