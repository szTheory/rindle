# Phase 113: Evaluation Baseline & Release Hygiene - Pattern Map

**Mapped:** 2026-06-29
**Files analyzed:** 5 code/YAML artifacts (analog-required) + 9 doc-edit surfaces (no analog needed)
**Analogs found:** 5 / 5 (all code/YAML artifacts have a concrete in-repo or sibling analog)

> This is a docs / release-hygiene phase. The artifacts that need a concrete code/YAML analog to copy
> from are items 1–5 below. The remaining work is Markdown content edits at known anchors (enumerated in
> "Doc-Edit Surfaces") and a release-cut that is operational, not authored (rotate token → observe the
> existing pipeline). NO `lib/` change. The planner must keep every new artifact OFF the `CI Summary`
> required path (D-09).

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `.planning/milestones/v1.22-OSS-QUALITY-EVAL.md` (NEW) | doc / scored-summary | transform (recon→work-list) | `.planning/milestones/v1.21-MILESTONE-AUDIT.md` `## Scorecard` + frontmatter | house-style exact (format), content from SEED-005 |
| `.github/workflows/release-train-drift.yml` (NEW) | config / CI workflow | event-driven (cron + dispatch) | `/Users/jon/projects/scrypath/.github/workflows/verify-published-release.yml` (+ rulestead variant) | role+flow match (sibling idiom) |
| `.github/ISSUE_TEMPLATE/release-train-drift.md` (NEW) | config / issue template | event-driven (JasonEtco render) | `/Users/jon/projects/scrypath/.github/ISSUE_TEMPLATE/release-parity-drift.md` | exact |
| Token-validity guard step INTO `.github/workflows/release.yml` `Release Please` job (MODIFY) | config / CI step | request-response (gh api preflight) | `release.yml` existing steps (lines 50-57) + `publish` job's `gh release`/`HEX_API_KEY` fail-loud idiom (lines 296-379) | in-file additive |
| `scripts/public_smoke.sh` junit hardening (MODIFY, D-08) | utility / test harness | file-I/O (junit write under crash) | `scripts/public_smoke.sh` self + `test/test_helper.exs` JUnitFormatter wiring (lines 31-47) | self / in-file |
| `test/install_smoke/ci_*_meta_test.exs` (NEW, OPTIONAL) | test / meta-guard | transform (read YAML, assert invariant) | `test/install_smoke/ci_observability_test.exs` (OBS-02 grep-meta pattern) | exact |

---

## Pattern Assignments

### 1. `.planning/milestones/v1.22-OSS-QUALITY-EVAL.md` (doc, scored-summary) — EVAL-01

**Analog:** `.planning/milestones/v1.21-MILESTONE-AUDIT.md` (frontmatter lines 1-31; `## Scorecard` lines 41-49)

**Frontmatter pattern to mirror** (`v1.21-MILESTONE-AUDIT.md:1-9`) — keys + delimiter style:
```yaml
---
milestone: v1.21
name: CI/DX Reliability Tail
audited: 2026-06-29
status: passed
scores:
  requirements: 24/24
```
Adapt for EVAL-01 to the RESEARCH-supplied frontmatter (research lines 313-319): `milestone: v1.22` /
`name: OSS Quality & Trust Hardening` / `evaluated:` / `source: SEED-005 …` / `headline: "Engineering
strong; project-surface weak …"`. Use the bare `OSS-QUALITY-EVAL` noun (D-01) — NOT `MILESTONE-AUDIT`
(reserved for the v1.22 closing audit).

**Scored-table pattern to mirror** (`v1.21-MILESTONE-AUDIT.md:43-49`):
```markdown
## Scorecard

| Dimension | Score | Notes |
|-----------|-------|-------|
| Requirements satisfied | **24/24** | 3-source cross-reference clean (...) |
| Phases verified | **5/5** | All `status: passed` in VERIFICATION.md frontmatter |
```
EVAL-01 adapts this to TWO tables (D-02): "Weak dimensions v1.22 fixes" with columns
`Dimension | Score | Evidence (present / named-absence / path) | Closing phase → reqs`, and "Strong
dimensions v1.22 does NOT touch". Full skeleton is in RESEARCH.md "Code Examples" lines 311-347 — reuse
it verbatim for structure.

**Mapping column (MUST be byte-faithful to REQUIREMENTS.md — D-03, research Pitfall 2 lines 275-281):**
- governance/trust **2/5** → **114** : TRUST-01, TRUST-02, TRUST-03, META-01, META-02
- versioning/path-to-1.0 **2/5** → **115** : VERSION-01, VERSION-02
- README positioning **2.5/5** → **115** : README-01, README-02
- host-app respectfulness **3.5/5** → **116** : MIGRATE-01, MIGRATE-02 (breaking schema flip → v1.23 ISO23-*)
- Strong/untouched: telemetry **5/5**, docs/ExDoc IA **4.5/5**, public API + `Rindle.Error` **4/5**, CI/testing.

**Length guard:** ~1 page (1.5 max, D-02). Scores lifted from SEED-005 — do NOT re-derive. (accrue
`176-SCORECARD.md` is the structural cousin but ~590 lines — borrow shape, not length.)

---

### 2. `.github/workflows/release-train-drift.yml` (config, event-driven) — D-06a

**Analog:** `/Users/jon/projects/scrypath/.github/workflows/verify-published-release.yml` (primary) and
`/Users/jon/projects/rulestead/.github/workflows/verify-published-release.yml` (richer rolling-issue
build + close-on-recovery). Mirror the cron + `JasonEtco/create-an-issue@v2` self-filing idiom.

**Trigger + permissions + concurrency pattern** (scrypath `verify-published-release.yml:3-14`):
```yaml
on:
  schedule:
    - cron: "17 6 * * *"
  workflow_dispatch:

permissions:
  contents: read
  issues: write

concurrency:
  group: verify-published-release-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```
For rindle, offset the cron (research uses `"23 7 * * *"`) so it does not collide with sibling crons.
Keep `permissions:` exactly `contents: read` + `issues: write` (least-privilege; the drift predicate is
read-only `git log` / `gh pr list`).

**Open-or-update issue pattern** (scrypath `verify-published-release.yml:94-103`):
```yaml
      - name: Open drift issue (scheduled runs only)
        if: ${{ failure() && github.event_name == 'schedule' && steps.resolve-version.outputs.published == 'true' }}
        uses: JasonEtco/create-an-issue@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          VERSION: ${{ steps.resolve-version.outputs.version }}
        with:
          update_existing: true
          search_existing: open
          filename: .github/ISSUE_TEMPLATE/release-parity-drift.md
```
Pin the action to a SHA for the rindle copy (rulestead pins `JasonEtco/create-an-issue@1b14a70…# v2.9.2`,
its `verify-published-release.yml:163`) to match rindle's SHA-pin house style (`release.yml` pins every
`uses:`).

**Close-on-recovery pattern** (rulestead `verify-published-release.yml:170-182`) — the auto-close half of
the rolling-issue lifecycle:
```yaml
      - name: Close rolling drift issue on success
        if: steps.resolve.outputs.status == 'ok' && steps.verify.outcome == 'success'
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          set -euo pipefail
          issue_number="$(gh issue list --state open --search 'in:title "Release drift: ..."' --json number --jq '.[0].number // empty')"
          if [[ -n "${issue_number}" ]]; then
            gh issue close "${issue_number}" --comment "..."
          fi
```

**Checkout pin to reuse from rindle's own `release.yml:46`** (SHA-pin convention to keep actionlint quiet):
```yaml
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1
        with:
          fetch-depth: 0   # + fetch-tags: true — drift predicate needs rindle-v* tags
```

**Drift predicate** (Claude's discretion per D-06; research Pattern 2 lines 188-219 has a worked
`git describe --match 'rindle-v*'` + `gh pr list --search 'head:release-please--branches--main--components--rindle'`
skeleton). The cron + JasonEtco + close-on-recovery wrapper is the locked idiom; the predicate body is free.

**HARD invariant:** this workflow MUST NOT appear in `ci-summary.needs` (see Shared Pattern: Required-Path
Invariant). It is a standalone non-required workflow.

---

### 3. `.github/ISSUE_TEMPLATE/release-train-drift.md` (config, issue template) — D-06a companion

**Analog:** `/Users/jon/projects/scrypath/.github/ISSUE_TEMPLATE/release-parity-drift.md` (whole file).
Note: rindle has NO `.github/ISSUE_TEMPLATE/` dir yet — this NEW file creates it.

**Full pattern** (scrypath `release-parity-drift.md:1-16`):
```markdown
---
title: "Release parity drift detected: scrypath {{ env.VERSION }}"
labels: ["area:release", "severity:drift"]
assignees: szTheory
---

`mix verify.release_parity {{ env.VERSION }}` detected a divergence ...

- Workflow run: {{ env.GITHUB_SERVER_URL }}/{{ env.GITHUB_REPOSITORY }}/actions/runs/{{ env.GITHUB_RUN_ID }}
- Version: {{ env.VERSION }}
```
Adapt for rindle: `title:` must contain a stable substring the drift workflow's close step `gh issue list
--search 'in:title "..."'` matches on (e.g. `"Release train drift: main ahead of last rindle-v* tag with
no open release PR"`); keep `labels:`/`assignees: szTheory`; use the `{{ env.* }}` mustache fields the
JasonEtco action interpolates from the workflow's `env:` block.

---

### 4. Token-validity guard step → `.github/workflows/release.yml` `Release Please` job (MODIFY) — D-06b

**Analog:** `release.yml` itself — the additive step lands BEFORE the `Run Release Please` step
(`release.yml:50-57`), inside the existing `release-please` job so it inherits that job's
`contents: write / issues: write / pull-requests: write` permissions (lines 37-40). Reuse the repo's own
fail-loud + `gh`/`HEX_API_KEY` env idiom already present in the `publish` job.

**The footgun being guarded** (`release.yml:54`):
```yaml
          token: ${{ secrets.RELEASE_PLEASE_TOKEN || github.token }}
```
A present-but-invalid secret WINS the `||`; `github.token` never engages. The guard validates the secret
via `gh api user` and fails loud with a rotation hint.

**Fail-loud idiom to mirror** (existing `release.yml:374-378`, the `HEX_API_KEY` preflight — same
`if [ -z … ]; then echo "::error::…"; exit 1; fi` shape):
```yaml
          if [ -z "$HEX_API_KEY" ] || [ "$HEX_API_KEY" = "dryrun-placeholder" ]; then
            echo "::error::HEX_API_KEY missing/invalid. Configure repo Settings → ..."
            exit 1
          fi
```

**Guard step to add** (research Pattern 1 lines 146-163; reads the secret via `env:`, never inlines it):
```yaml
      - name: Validate RELEASE_PLEASE_TOKEN if present (fail loud, don't silently fall through ||)
        if: ${{ secrets.RELEASE_PLEASE_TOKEN != '' }}
        env:
          GH_TOKEN: ${{ secrets.RELEASE_PLEASE_TOKEN }}
        shell: bash
        run: |
          set -euo pipefail
          if ! gh api user >/dev/null 2>&1; then
            echo "::error::RELEASE_PLEASE_TOKEN is present but INVALID (expired/revoked). ..."
            exit 1
          fi
          echo "RELEASE_PLEASE_TOKEN validated."
```
**actionlint caveat (research Pitfall 5 lines 300-302):** `secrets.*` in a step-level `if:` may not
evaluate on all runners. If actionlint/CI rejects it, move the emptiness check into the `run:` body
(`[ -n "${RELEASE_PLEASE_TOKEN:-}" ] || { echo "no token; relying on github.token"; exit 0; }`, secret via
`env:`). Bar: add ZERO new actionlint findings (7 pre-existing exist — see `v1.21-MILESTONE-AUDIT.md`
tech_debt line 22). Never echo the token value.

---

### 5. `scripts/public_smoke.sh` junit hardening (MODIFY, file-I/O) — D-08

**Analog:** `scripts/public_smoke.sh` self (whole file, 54 lines) + `test/test_helper.exs` JUnitFormatter
wiring (lines 31-47).

**The crash-path being hardened** (research Pitfall 3 lines 283-286): `public_smoke.sh:43` runs
`mix test test/install_smoke/generated_app_smoke_test.exs` with `CI=true` (set by the runner) → in
`test_helper.exs` that flips on `JUnitFormatter`; when the child `:epipe` crash propagates,
`JUnitFormatter.handle_suite_finished/1` (formatter.ex:164) fails to write
`_build/test/junit/rindle-junit.xml` → `File.Error ... bad argument`.

**The CI-gated JUnit wiring** (`test_helper.exs:31-47`) — the exact lines the fix touches/coordinates with:
```elixir
# Only emit JUnit XML in CI to keep local runs quiet (CI sets the CI env var).
formatters =
  if System.get_env("CI") do
    [ExUnit.CLIFormatter, JUnitFormatter]
  else
    [ExUnit.CLIFormatter]
  end

junit_report_dir = "_build/test/junit"
Application.put_env(:junit_formatter, :report_dir, junit_report_dir)
...
# junit_formatter does not create its report_dir; ensure it exists before writing (CI only).
if System.get_env("CI"), do: File.mkdir_p!(junit_report_dir)
```

**The smoke shell-out to patch** (`public_smoke.sh:39-44`):
```bash
run_install_smoke_profile() {
  local profile="$1"
  echo "Public smoke: profile=${profile}"
  export RINDLE_INSTALL_SMOKE_PROFILE="$profile"
  mix test test/install_smoke/generated_app_smoke_test.exs --include minio
}
```

**Fix shape (Claude's discretion among 3 research-vetted options, Pitfall 3 lines 286):**
(a) ensure `_build/test/junit` exists+writable in the clean-room run regardless of crash; (b) gate
JUnitFormatter off for the install-smoke shell-out child in `test_helper.exs`; (c) `unset CI` in
`public_smoke.sh` for the parent install-smoke `mix test` so JUnitFormatter does not engage during the
crash-prone run. Goal: an abnormal-exit suite yields a CLEAN failure, not `File.Error … bad argument`.
**NOT a precondition of the 0.3.2 cut** (D-08) — independent Track-A item.

---

### 6. `test/install_smoke/*_meta_test.exs` (NEW, OPTIONAL test) — guards D-06/D-09

**Analog:** `test/install_smoke/ci_observability_test.exs` (whole file, 255 lines) — the OBS-02
grep-meta-test pattern that already locks CI invariants inside `mix test` / `mix ci`.

**Setup + read-file pattern** (`ci_observability_test.exs:32-51`):
```elixir
  use ExUnit.Case, async: true

  @ci_path Path.expand("../../.github/workflows/ci.yml", __DIR__)
  ...
  setup_all do
    {:ok, %{ci: File.read!(@ci_path), ...}}
  end
```

**Presence + invariant assertion pattern** (`ci_observability_test.exs:56-71, 110-127`) — `=~` for
presence, `refute =~` for the must-NOT invariant:
```elixir
  test "...", %{ci: ci} do
    assert ci =~ "\n  ci-observability:\n", "ci.yml must declare ... (OBS-01)"
    ...
    refute workflow_perms =~ "actions: read",
           "the WORKFLOW-level default must NOT become `actions: read` ..."
  end
```
**For phase 113** the meta-test should: (a) `File.read!` the new `release-train-drift.yml` and assert it
exists / carries `JasonEtco/create-an-issue`; (b) `File.read!` `ci.yml`, isolate the `ci-summary:` `needs:`
block (lines 1437-1448), and `refute` that `release-train-drift` / the token-guard appear in it — i.e.
assert the guards stay OFF the required path (D-09). Reuse the block-isolator helper style
(`ci_observability_block/1`, lines 230-234) to scope the `needs:` scan. The file's own docstring
(lines 14-19) warns NOT to couple to `.planning/` paths (they move on archive) — keep the new meta-test
asserting SHIPPED artifacts only.

---

## Doc-Edit Surfaces (content edits — no code analog; exact regions)

These are Markdown content edits at known anchors. Line numbers verified in RESEARCH.md Pitfall 4
(lines 289-298) — re-grep before editing (release-state is time-sensitive).

| File | Region / Anchor | What | Track |
|------|-----------------|------|-------|
| `.planning/RELEASE-TRAIN.md` | `## Verification Log (maintainer)` table, header at line 24-25, append after last row (line 32) | D-07 root-cause row now + "released" row after publish. Cols: `Date \| Check \| Result \| Evidence`. Template in RESEARCH lines 351-355 | A (root-cause) + B (released) |
| `guides/release_publish.md` | `## Recovery Workflow Contract` (line 118), append a `### Stuck release: expired RELEASE_PLEASE_TOKEN` subsection before `## Post-Publish Follow-Up` (line 131) | D-07 runbook entry. Full prose in RESEARCH lines 358-381 | A |
| `.planning/PROJECT.md` | lines 19, 43-48 (re-date/tense block), 70, 109, 405, 599. **Leave line 814** (D-10/D-13). 70+109 = research recommendation beyond D-10's literal list (Open Q 3, lines 414-416) | D-10/D-11 truth edits — use canonical sentence (D-11) verbatim | B (AFTER publish) |
| `.planning/MILESTONES.md` | line 20 ("...→ Hex 0.3.2 via two adopter-invisible `fix:` patches") | D-10/D-11 truth edit | B (AFTER publish) |
| `.planning/RETROSPECTIVE.md` | line 9 ("...→ Hex 0.3.2 via two `fix:` patches") | D-10/D-11 truth edit | B (AFTER publish) |
| `.planning/seeds/SEED-003-*.md` | frontmatter line 3 `status: open` → `consumed`; add `consumed:`/`consumed_by:` after `planted_during:` (line 4) | D-14 (mirror SEED-002 field order) | A |
| `.planning/seeds/SEED-004-*.md` | frontmatter line 3 `status: open` → `consumed`; add `consumed:`/`consumed_by:` after `planted_during:` | D-14 | A |

**SEED frontmatter precedent (D-14, research Pitfall 6 lines 304-306)** — mirror `SEED-002` field order
(`SEED-002-*.md:1-9`), token is `consumed` (NOT `promoted`):
```yaml
---
id: SEED-002
status: consumed
planted: 2026-06-13
planted_during: v1.18 close-out / repo-hygiene pass
consumed: 2026-06-20
consumed_by: "v1.19 Design-System Stress-Test (chartered 2026-06-14, shipped 2026-06-19; 20/20 requirements complete)"
trigger_when: "..."
scope: Large
---
```
Use the D-14 verbatim `consumed`/`consumed_by` strings for SEED-003 (2026-06-22 / v1.20) and SEED-004
(2026-06-29 / v1.21). Both SEED-003/004 currently read `status: open` (confirmed).

**Out-of-scope — DO NOT edit (D-13):** any `.planning/milestones/v1.21-*` archive, v1.21 phase artifacts,
CHANGELOG `**104-03:**` false positives, `STATE.md`/`ROADMAP.md`/`SEED-005`/`REQUIREMENTS.md` hits
(already correct).

---

## Shared Patterns

### Required-Path Invariant (release-coupling — applies to items 2, 4, 6)
**Source:** `.github/workflows/ci.yml` `ci-summary:` job (lines 1424-1463), `needs:` block lines 1437-1448.
**Apply to:** every NEW/MODIFIED workflow artifact this phase.
The `CI Summary` check (line 1425, `name: CI Summary`) is the SOLE required check; its `needs:` list is the
PR critical path. New guard workflows MUST NOT be added to it (D-09). `ci.yml` line 1 (`name: CI`) and the
gate logic stay byte-unchanged. The drift workflow is standalone; the token-guard is an additive step
inside an existing job (no new check name).
```yaml
    needs:
      - quality
      - optional-dependencies
      - integration
      - ...
      - ci-script-tests        # ← release-train-drift / token-guard must NOT appear here
    if: always()
```

### SHA-Pin convention (applies to items 2, 3)
**Source:** `release.yml` — every `uses:` is SHA-pinned with a trailing `# vX.Y.Z` comment
(`actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1`, line 46;
`googleapis/release-please-action@5c625bf… # v4.4.1`, line 52).
**Apply to:** the new drift workflow's `uses:` lines (pin `JasonEtco/create-an-issue` and `actions/checkout`
to SHAs; rulestead pins `1b14a70… # v2.9.2`).

### Fail-loud `::error::` + secret-via-`env:` idiom (applies to item 4)
**Source:** `release.yml:374-378` (HEX_API_KEY preflight) and `release.yml:296-298` (`GH_TOKEN` via `env:`).
**Apply to:** the D-06b token-validity guard — read the secret through `env:`, check exit code only
(`gh api user`), emit `::error::` with a rotation hint, `exit 1`. NEVER inline-interpolate or echo the
secret value (V14 Configuration; research Security Domain lines 487-493).

### Hex-version resolution idiom (reference for the drift predicate, item 2)
**Source:** sibling `verify-published-release.yml` (scrypath lines 35-50; rulestead lines 62-89) and
rindle `release.yml:459-473` Hex-index wait.
**Apply to:** if the drift predicate consults Hex, use
`curl -sS -o pkg.json -w "%{http_code}" https://hex.pm/api/packages/rindle` + `jq -r '.latest_stable_version'`
(404-aware), NOT `mix hex.info` text parsing.

---

## No Analog Found

None. Every code/YAML artifact has a concrete in-repo or verified-sibling analog. The pure content edits
(EVAL prose, truth-sweep sentences, SEED frontmatter) follow in-repo house style, not a code analog.

---

## Metadata

**Analog search scope:** `.planning/milestones/`, `.github/workflows/`, `.github/ISSUE_TEMPLATE/`
(rindle + scrypath + rulestead), `scripts/`, `test/install_smoke/`, `test/test_helper.exs`, `guides/`,
`.planning/seeds/`.
**Files scanned:** 11 read in full/targeted (release.yml, scrypath + rulestead verify-published-release.yml,
v1.21-MILESTONE-AUDIT.md, public_smoke.sh, test_helper.exs, ci_observability_test.exs, scrypath
release-parity-drift.md, ci.yml ci-summary region, RELEASE-TRAIN.md + release_publish.md anchors, SEED
frontmatter).
**Pattern extraction date:** 2026-06-29
