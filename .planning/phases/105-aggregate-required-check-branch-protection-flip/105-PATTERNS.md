# Phase 105: Aggregate Required Check + Branch-Protection Flip - Pattern Map

**Mapped:** 2026-06-21
**Files analyzed:** 3 (1 modify-by-add, 1 modify, 1 reused read-only)
**Analogs found:** 3 / 3 (all in-repo; plus 2 cross-repo idiom analogs)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.github/workflows/ci.yml` (ADD `ci-summary` job) | config (CI workflow job) | event-driven (aggregate over `needs.*.result`) | `ci-observability` job, same file `:1243-1315` | exact (same `needs:` set, same `if: always()`, same `$GITHUB_STEP_SUMMARY` idiom) — minus the `gh api` read and `permissions:` (D-02) |
| `scripts/setup_branch_protection.sh` (MODIFY array + heredoc) | config (maintainer script) | transform (declares required-context set) | the file itself — two in-lockstep spots (`:17-31`, `:36-48`) | exact (edit-in-place, no structural analog needed) |
| `scripts/ci/check_required_checks.sh` (REUSE, no edit) | utility (read-only verifier) | request-response (GET + diff) | n/a — reused verbatim from Phase 103 | exact (invocation pattern only) |

**Cross-repo idiom analogs (reference, not edited):**

| Sibling | Job | Lines | Contributes |
|---------|-----|-------|-------------|
| `sigra` | `ci-gate` | `ci.yml:1325-1376` | bash result-loop that treats `skipped` as pass (`:1366`) — closest prior art for D-05 |
| `lattice_stripe` | `ci-gate` | `ci.yml:262-291` | "collect-all-failures-before-exit" structure (`failed=1` loop) — D-06 structure; does NOT treat skip as pass |

---

## Pattern Assignments

### `.github/workflows/ci.yml` — new `ci-summary` job (config, event-driven aggregate)

**Analog:** `ci-observability` job, same file, `ci.yml:1243-1315`.
**Placement:** append at EOF (after `:1315`, which is the file's last line). Purely additive (D-01).
**LOCKED:** `name: CI` (`ci.yml:1`) and the filename `ci.yml` MUST NOT change — release coupling (D-08/GATE-02).

**Copy the job skeleton — name/runs-on/needs/if (`ci.yml:1243-1258`):**
```yaml
  ci-observability:
    name: CI Observability
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
```
For `ci-summary`: copy this verbatim but change `name:` to `CI Summary`, job id to `ci-summary`, keep `runs-on: ubuntu-22.04`, keep the **same 11-job `needs:` set** (D-03), keep `if: always()`. The 11 jobs are exactly the gating set; `mux-soak`, `gcs-soak`, `package-consumer-gcs-live` are deliberately ABSENT here and stay absent in `ci-summary` (D-04).

**OMIT the `permissions:` block (D-02).** The analog declares it (`ci.yml:1259-1260`) because it makes a `gh api` call — `ci-summary` makes NO network call, so it must declare NO `permissions:` (inherits workflow default `contents: read`):
```yaml
    permissions:          # ci-observability ONLY — DO NOT copy into ci-summary
      actions: read
```

**OMIT the `gh api` read (D-02).** The analog's whole reason to exist is the paginated API read (`ci.yml:1272-1275`) that can 401-flake (`103-BASELINE.md:73-77`). `ci-summary` must never contain a `gh api` call — it is pure `needs.*.result` evaluation.

**Copy the `$GITHUB_STEP_SUMMARY` brace-group append idiom (`ci.yml:1278-1291`):**
```yaml
          {
            echo "## CI per-job timing (native)"
            echo ""
            echo "| Job | Duration (s) | Conclusion |"
            echo "| --- | ---: | --- |"
            jq -r '...' /tmp/ci-jobs.json
          } >> "$GITHUB_STEP_SUMMARY"
```
For `ci-summary`, reuse this `{ echo …; } >> "$GITHUB_STEP_SUMMARY"` structure to emit a `| Job | Result |` table (D-06).

**Core result-evaluation pattern (D-05/D-06) — combine the two cross-repo analogs:**

Skip-as-pass test, from `sigra ci.yml:1366`:
```bash
if [[ "$result" != "success" && "$result" != "skipped" ]]; then
```
Collect-all-failures-then-exit structure, from `lattice_stripe ci.yml:277-290`:
```bash
          set -euo pipefail
          failed=0
          for lane in FORMAT COMPILE TEST INTEGRATION DOCS_TRUTH QUALITY; do
            result="${!lane}"
            if [[ "$result" != "success" ]]; then
              echo "Required lane $lane: $result"
              failed=1
            fi
          done
          if [[ "$failed" -ne 0 ]]; then
            echo "ci-gate failed: one or more required lanes did not succeed."
            exit 1
          fi
```
**Deviation from siblings (D-06, locked):** iterate `toJSON(needs)` via `jq` instead of per-lane env vars (drift-proof — auto-covers whatever is in `needs:`). Recommended phrasing already drafted in `105-RESEARCH.md` Pattern 1 (`:248-294`): `NEEDS_JSON: ${{ toJSON(needs) }}` env, then `jq -r 'to_entries[] | "\(.key)\t\(.value.result)"'`, `case "${result}" in success|skipped) ;; *) failed=1 ;; esac`. The exact bash/jq phrasing is Claude's Discretion as long as D-05 (success+skipped pass, failure+cancelled fail) and D-06 (explicit evaluation + collect-all + `exit 1`) hold.

**Anti-pattern to avoid (D-06 "green checkmark lie"):** an `if: always()` job whose steps do NOT check `needs.*.result` reports success even when a dependency failed. The step MUST `exit 1` on any non-pass.

---

### `scripts/setup_branch_protection.sh` — collapse to single `"CI Summary"` context (config, transform)

**Analog:** the file itself. Edit the **two in-lockstep spots** (D-08); `expected_json()` (`:64-85`) and the `gh api -X PUT` body (`:112-116`) read the array generically and need NO change.

**Edit spot 1 — `REQUIRED_CHECKS` array, verbatim current (`:17-31`):**
```bash
REQUIRED_CHECKS=(
  "Quality (1.15, 26)"
  "Quality (1.17, 27)"
  "ADMIN-06 Optional Dependencies (1.15, 26)"
  "ADMIN-06 Optional Dependencies (1.17, 27)"
  "Integration"
  "Contract"
  "Proof"
  "Package Consumer Proof Matrix + Release Preflight"
  "Adopter"
  "Adoption Demo Unit"
  "Adoption Demo E2E"
  "Cohort Demo Smoke"
  "brandbook-tokens"
)
```
Collapse to:
```bash
REQUIRED_CHECKS=(
  "CI Summary"
)
```
The string MUST be exactly `CI Summary` (matches the job `name:`, not the job id `ci-summary` — Pitfall 2).

**Edit spot 2 — `print_expected_text()` heredoc bullets, verbatim current (`:36-48`):**
```bash
  - Quality (1.15, 26)
  - Quality (1.17, 27)
  - ADMIN-06 Optional Dependencies (1.15, 26)
  - ADMIN-06 Optional Dependencies (1.17, 27)
  - Integration
  - Contract
  - Proof
  - Package Consumer Proof Matrix + Release Preflight
  - Adopter
  - Adoption Demo Unit
  - Adoption Demo E2E
  - Cohort Demo Smoke
  - brandbook-tokens
```
Collapse the 13 bullet lines to one:
```bash
  - CI Summary
```
Leave the surrounding heredoc lines (`Expected required status checks:` header `:35`, and the `Expected non-context branch protection fields:` block `:50-60`) UNCHANGED.

**Do NOT add a third encoding of the list** (D-08 anti-pattern). The list lives in this one file, two spots only.

---

### `scripts/ci/check_required_checks.sh` — reused verbatim (utility, read-only verify)

**No edit.** Reused as-is from Phase 103 for D-13 verification. It is READ-ONLY (GETs `/required_status_checks` `.contexts[]` at `:44-48`) and reuses `setup_branch_protection.sh --print-expected-json` as the single source of truth (`:51-52`), so it auto-picks up the collapsed array with no change.

**Invocation pattern for the post-merge verification step (D-13):**
```bash
bash scripts/ci/check_required_checks.sh main
# Expect: "## Live required status checks" lists only "CI Summary",
#         and the diff vs --print-expected-json is EMPTY.
```
Its diff is intentionally tolerant of nonzero exit (`|| true` at `:62`) — informational, not a gate.

---

## Shared Patterns

### `$GITHUB_STEP_SUMMARY` brace-group append
**Source:** `ci.yml:1278-1291` (also `:1297-1315`).
**Apply to:** the new `ci-summary` job's result table.
```bash
{
  echo "## <heading>"
  echo ""
  echo "| ... | ... |"
  echo "| --- | --- |"
  # ... rows ...
} >> "$GITHUB_STEP_SUMMARY"
```

### Job skeleton: `runs-on: ubuntu-22.04` + `needs:` 11-job set + `if: always()`
**Source:** `ci.yml:1243-1258`.
**Apply to:** `ci-summary` (copy the `needs:` block byte-for-byte; it is the verified gating set).

### Bash gate loop: collect-all-failures, skip-as-pass, `exit 1`
**Source:** structure from `lattice_stripe ci.yml:277-290`; skip-as-pass from `sigra ci.yml:1366`.
**Apply to:** `ci-summary` step (rephrased over `toJSON(needs)` + `jq` per D-06).

### Required-set source of truth: edit array + heredoc together
**Source:** `setup_branch_protection.sh:17-31` + `:36-48`.
**Apply to:** the GATE-02 collapse. `expected_json()` reads the array generically — never re-encode names elsewhere.

### Read-only verifier invocation
**Source:** `scripts/ci/check_required_checks.sh` (reused).
**Apply to:** the post-merge human verification (D-13) — `bash scripts/ci/check_required_checks.sh main`.

---

## No Analog Found

None. Every file has an exact in-repo analog. The only non-in-repo pattern (the explicit result-evaluation bash loop) is sourced from two verified sibling-repo analogs (`sigra`, `lattice_stripe`) and re-expressed over `toJSON(needs)` per the locked D-06.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| — | — | — | — |

---

## Metadata

**Analog search scope:** `/Users/jon/projects/rindle/.github/workflows/`, `/Users/jon/projects/rindle/scripts/`, and sibling repos `/Users/jon/projects/sigra`, `/Users/jon/projects/lattice_stripe` (cross-repo idiom only).
**Files read (full or targeted):** `ci.yml:1243-1315`, `setup_branch_protection.sh` (full, 120 lines), `check_required_checks.sh` (full, 63 lines), `sigra ci.yml:1325-1376`, `lattice_stripe ci.yml:262-291`.
**Pattern extraction date:** 2026-06-21
