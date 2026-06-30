# Phase 113: Evaluation Baseline & Release Hygiene - Research

**Researched:** 2026-06-29
**Domain:** Release engineering (release-please/Hex pipeline recovery), planning-truth reconciliation, OSS-quality evaluation artifact authoring
**Confidence:** HIGH (live-state verified via `gh`, git, and Hex API this session)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
The 14 decisions D-01..D-14 are LOCKED (researched one-shot via parallel subagents) and must be honored verbatim. Reproduced for the planner with the exact load-bearing constraints:

- **D-01 (EVAL home):** Write to `.planning/milestones/v1.22-OSS-QUALITY-EVAL.md` (bare `OSS-QUALITY-EVAL` noun; NOT `MILESTONE-AUDIT` — reserved for the v1.22 closing audit).
- **D-02 (EVAL shape):** ~1 page (1.5 max). Two scored tables (weak dims v1.22 fixes / strong dims it does NOT touch), each row with an inline-evidence cell + a weakness→closing-phase column mapped byte-faithfully to REQUIREMENTS.md. Plus a one-line headline verdict, a scope/method note, and an explicit "out of this milestone" block. Scores 1–5 (5=strong), lifted from SEED-005 — do NOT re-derive.
- **D-03 (mapping — must match REQUIREMENTS.md exactly):** governance/trust 2/5 → 114 (TRUST-01/02/03, META-01/02); versioning/path-to-1.0 2/5 → 115 (VERSION-01/02); README positioning 2.5/5 → 115 (README-01/02); host-app respectfulness 3.5/5 → 116 substrate (MIGRATE-01/02), breaking schema flip deferred to v1.23. Strong/untouched: telemetry 5/5, docs/ExDoc IA 4.5/5, public API + `Rindle.Error` 4/5, CI/testing.
- **D-04 (root cause):** `release.yml` `Release Please` job 401'd `Bad credentials` (run 28399407429, 2026-06-29). `RELEASE_PLEASE_TOKEN` PAT expired. Because `release.yml:54` is `token: ${{ secrets.RELEASE_PLEASE_TOKEN || github.token }}`, a non-empty-but-invalid secret wins the `||` and the fallback never engages. **[CORRECTION below — see Pitfall 1: D-04's claim that "last good run Found PR #40 = the 0.3.2 PR" is FACTUALLY WRONG; PR #40 was the 0.3.1 PR. The mechanism is still correct; the no-0.3.2-PR explanation needs a richer cause.]**
- **D-05 (mechanism — LOCKED = Option A):** Rotate the token, then let release-please cut 0.3.2 naturally. (1) [HUMAN] rotate `RELEASE_PLEASE_TOKEN`; (2) `gh pr edit 40 --remove-label "autorelease: pending" --add-label "autorelease: tagged"`; (3) phase-113 push re-triggers `release.yml`; (4) canonical chain runs. Reject Option B (hand-author PR) and Option C (out-of-band `mix hex.publish`).
- **D-06 (recurrence guards — IN SCOPE):** (a) release-train drift check (daily cron, PR-non-blocking, self-files issue); (b) token-validity guard (early step validates `RELEASE_PLEASE_TOKEN` via `gh api user`, fails loudly). Both OFF the `CI Summary` required path. Model on scrypath/rulestead `verify-published-release.yml`.
- **D-07 (record root cause):** Append a Verification-Log row to `.planning/RELEASE-TRAIN.md` AND a runbook entry to `guides/release_publish.md` (extend "Recovery Workflow Contract", ~line 118).
- **D-08 (public_smoke junit bug — SEPARATE follow-up):** Fix `scripts/public_smoke.sh`'s junit-write failure this phase; track as its own item, NOT a precondition of the cut.
- **D-09 (release-coupling invariants):** Option A touches NO versioned source by hand; does NOT touch `ci.yml` / `name: CI` / `CI Summary` / the full-verification gate. Only edits: docs + one new non-required guard workflow.
- **D-10 (truth-sweep scope — 3 live surfaces):** Edit ONLY `.planning/PROJECT.md`, `.planning/MILESTONES.md`, `.planning/RETROSPECTIVE.md`. (Line numbers verified below — they have drifted; see Pitfall 4.)
- **D-11 (canonical reconciliation sentence — reuse verbatim).**
- **D-12 (sequencing — load-bearing):** Investigate → cut/publish → THEN commit the "0.3.2 is now live" truth edits. Do NOT pre-write "now live". The `[0.3.2]` CHANGELOG + `mix.exs`/manifest bump are written by release-please itself.
- **D-13 (out-of-scope — leave):** Do NOT rewrite `.planning/milestones/v1.21-*` archive or v1.21 phase artifacts.
- **D-14 (SEED frontmatter):** Set `status: consumed` on SEED-003/004; add `consumed:`/`consumed_by:` after `planted_during:`.

### Claude's Discretion
- Exact line wording/formatting of the EVAL doc and the doc edits — within the locked structures.
- Exact workflow YAML shape of the drift + token-validity guards — match sibling `verify-published-release.yml` idiom; keep both off the required `CI Summary` path.

### Deferred Ideas (OUT OF SCOPE)
- Split `Public Verify` into "Hex/hexdocs reachability" vs "tarball↔tag source parity" (scrypath's pattern) — future DX polish.
- Adopt sibling evidence-tag legend (`[VERIFIED:]`/`[CITED:]`/`[ASSUMED:]`) in planning audits — optional house-style upgrade.
- All v1.22-but-later-phase work (114 governance, 115 versioning/README, 116 `Rindle.Migration`) and the v1.23 breaking schema flip.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EVAL-01 | Maintainer reads a concise, evidence-cited scored-weakness summary of Rindle's OSS quality | SEED-005 dimension scores verified (governance 2/5, versioning 2/5, README 2.5/5, host-respectfulness 3.5/5; strong: telemetry 5/5, docs 4.5/5, API 4/5, CI/testing). `v1.21-MILESTONE-AUDIT.md` `## Scorecard` format captured (see Code Examples). Dimension→phase mapping confirmed byte-faithful to REQUIREMENTS.md traceability (see Pitfall 2). |
| HYGIENE-01 | Cut the stuck 0.3.2 release; reconcile the "ships as 0.3.2" claim | Root cause re-confirmed against live state (run 28399407429 `Bad credentials`); release topology mapped end-to-end; the no-0.3.2-PR cause is richer than D-04 stated (see Pitfall 1). Truth-edit surfaces grepped with corrected line numbers. |
| HYGIENE-02 | Correct stale `status: open` → `consumed` on SEED-003/004 | SEED-002 precedent frontmatter shape verified (`consumed:` + `consumed_by:` after `planted_during:`); SEED-003/004 current `status: open` confirmed. |
</phase_requirements>

## Summary

Phase 113 opens v1.22 honestly with three non-feature deliverables: an evidence-cited scored-weakness EVAL artifact (the map), a truth-correction doc sweep, and the one time-sensitive action — cutting the stuck Hex 0.3.2 release so v1.21's merged-but-unreleased `lib/` fixes reach adopters. The locked decisions are coherent; this research hardens the *implementation knowledge* and surfaces three live-state findings that change how the planner must structure the phase.

**Three load-bearing findings from live-state verification (this session):**

1. **The release-please root cause (D-04 mechanism) is CORRECT, but D-04's evidence narrative contains a factual error.** The 401 `Bad credentials` failure is real (run `28399407429`, 2026-06-29, single failed step "Run Release Please"). But D-04 claims the last good run (`28265065628`, 2026-06-26) "Found pull request #40" as the 0.3.2 PR — **PR #40 was the 0.3.1 release PR** (title `chore(main): release rindle 0.3.1`, merged 2026-06-26 13:02). Hex live = 0.3.1; `mix.exs`/manifest/CHANGELOG all = 0.3.1. **The richer truth:** the `:epipe`/`$callers` fix commits landed 2026-06-28 (`ce18719`, `9948a22`, `830a9a4`, `80ab4e1`) — *after* the 0.3.1 tag (2026-06-26) and *after* the last good release-please run. The next push-to-main that should have opened a 0.3.2 PR was 2026-06-29 (run `28399407429`), which is exactly the run that 401'd. So no 0.3.2 PR exists because **the first release-please run after the fixes merged was the one killed by the expired token.** This is fully consistent with D-05's fix (rotate → re-trigger → release-please cuts 0.3.2) but the planner must record the *correct* causal chain, not D-04's "PR #40 was 0.3.2" framing.

2. **The D-08 `public_smoke.sh` junit "bad argument" is a SECONDARY symptom of the very `:epipe` bug 0.3.2 fixes** — not an independent junit bug. The failure chain (verified in run `28246413418` logs): `public_smoke.sh` runs the parent rindle suite (`test/install_smoke/generated_app_smoke_test.exs`, `CI=true` → JUnitFormatter active) against the *published 0.3.1 tarball*; that tarball still has the `:epipe` flake; a child `mix test` in the generated app dies `command failed (2) ** (EXIT) :epipe`; the parent test crashes mid-flight; JUnitFormatter's `handle_suite_finished/1` then fails to write `_build/test/junit/rindle-junit.xml` (`File.Error ... bad argument`) during abnormal GenServer teardown. **Implication:** 0.3.2's public-verify will likely pass *because 0.3.2 contains the `:epipe` fix* — but the brittle junit-during-crash write should still be hardened (D-08) so any future crash surfaces a clean failure, not a confusing `bad argument`.

3. **The truth-edit line numbers in D-10 have drifted** and one surface (PROJECT.md) has more live hits than D-10 enumerated. Exact current locations are catalogued below (Pitfall 4) so the planner can author precise edits.

**Primary recommendation:** Structure phase 113 as two independent tracks plus a gated tail. Track A (proceeds immediately, no human dependency): EVAL-01 artifact, HYGIENE-02 SEED frontmatter, the two D-06 guard workflows, the D-08 junit hardening, the D-07 runbook/ledger prose for the *investigation* (root-cause recorded), and the investigation write-up. Track B (BLOCKED on the human token rotation): the actual 0.3.2 cut + publish + the "0.3.2 is now live" truth edits (D-10/D-11) + the dated "released" RELEASE-TRAIN row. The phase's `checkpoint:human-verify` is the maintainer rotating `RELEASE_PLEASE_TOKEN`; everything past it is verifiable by observing release-please/Actions, not by Claude.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Scored-weakness EVAL artifact | Planning docs (`.planning/milestones/`) | — | Maintainer-facing milestone-tier doc; consumed by 114/115/116 as a work-list |
| Cut the stuck 0.3.2 release | CI/CD (GitHub Actions: release-please → automerge → gate-ci-green → publish → public_verify) | Human (repo-admin token rotation) | The pipeline is intact and credential-starved; the only human step is the secret rotation |
| Token-validity + drift guards | CI/CD (new non-required workflows) | — | Recurrence prevention; must stay OFF the `CI Summary` required path |
| `public_smoke.sh` junit hardening | Test harness (`test/test_helper.exs` / `scripts/public_smoke.sh`) | — | Robustness of the post-publish parity proof under an abnormal-exit suite |
| Truth reconciliation | Planning docs (PROJECT/MILESTONES/RETROSPECTIVE) | — | Single-source append-only planning truth; archived milestones are immutable history |
| SEED frontmatter correction | Planning docs (`.planning/seeds/`) | — | Lifecycle bookkeeping |

## Standard Stack

This phase installs **no external packages**. It edits docs, authors GitHub Actions YAML, and patches a test harness. The relevant existing toolchain (verified present):

| Tool / Action | Version | Purpose | Provenance |
|---------------|---------|---------|------------|
| `googleapis/release-please-action` | v4.4.1 (pinned `5c625bf...`) | Opens/updates the release PR on push-to-main | [VERIFIED: `.github/workflows/release.yml:52`] |
| `JasonEtco/create-an-issue` | v2 / v2.9.2 (`1b14a70...` in rulestead) | Self-filing/auto-updating drift issue for the new guard workflow | [VERIFIED: scrypath/rulestead `verify-published-release.yml`] |
| `junit_formatter` | `~> 3.4` (3.4.0 resolved) | ExUnit JUnit XML in CI; the source of the D-08 `bad argument` | [VERIFIED: `mix.exs:132`, run 28246413418 logs] |
| `erlef/setup-beam` | v1.24.0 (`fc68ffb...`) | Elixir/OTP in release + verify lanes | [VERIFIED: `.github/workflows/release.yml:140`] |
| `actions/checkout` | v4.3.1 (`34e1148...`) | Pinned-SHA checkout idiom to mirror in new workflow | [VERIFIED: `.github/workflows/release.yml:46`] |

**No installation step.** The drift-guard workflow reuses `JasonEtco/create-an-issue@v2` and `curl https://hex.pm/api/packages/rindle` (both already used by sibling repos and the existing `public_verify` job).

## Package Legitimacy Audit

> Not applicable — this phase installs zero new packages. All GitHub Actions and Hex deps referenced are already pinned and in use in the repo's existing release pipeline. No `npm`/`pip`/`cargo`/`mix.exs` dependency additions.

## Architecture Patterns

### System Architecture Diagram — the release-cut data flow (Option A)

```
[HUMAN: rotate RELEASE_PLEASE_TOKEN]   ← BLOCKING checkpoint (repo admin; Claude cannot do this)
        │  (fine-grained PAT or GitHub App token: contents:write + pull-requests:write [+ issues:write])
        ▼
[gh pr edit 40 --remove-label "autorelease: pending" --add-label "autorelease: tagged"]
        │  (truthful relabel — 0.3.1 IS tagged+published)
        ▼
[push to main (phase-113 commits)] ──► release.yml: "Release Please" job
        │                                   token now valid → 401 gone
        ▼
release-please opens PR "chore(main): release rindle 0.3.2"
        │  files: .release-please-manifest.json, CHANGELOG.md, mix.exs  (EXACT 3-file set)
        ▼
CI runs on that PR ──► on green, release-please-automerge.yml fires (workflow_run: CI completed)
        │  guards: headRef == release-please--branches--main--components--rindle
        │          title matches ^chore\(main\): release rindle \d+\.\d+\.\d+$
        │          files == exactly the 3-file set
        │          no "do-not-merge" label, MERGEABLE
        ▼
squash-merge PR → dispatch release.yml (workflow_dispatch, recovery_ref = merge SHA)
        ▼
recovery-validation → gate-ci-green (waits for ci.yml green on EXACT SHA) → publish (Hex.pm)
        ▼
public_verify (Hex index + HexDocs reachability + public_smoke.sh parity proof)
        │  ◄── D-08 junit hardening makes this robust
        ▼
update-release-train-baseline (auto-PR + admin squash-merge of RELEASE-TRAIN.md baseline)
        ▼
[THEN: commit truth edits "0.3.2 is now live" — D-12 sequencing]
```

### Recommended file-touch structure for phase 113

```
.planning/milestones/v1.22-OSS-QUALITY-EVAL.md   # NEW — EVAL-01 artifact (Track A)
.planning/seeds/SEED-003-*.md                    # frontmatter edit (Track A, HYGIENE-02)
.planning/seeds/SEED-004-*.md                    # frontmatter edit (Track A, HYGIENE-02)
.github/workflows/release-train-drift.yml        # NEW — D-06a drift guard (Track A; OFF required path)
.github/workflows/release.yml                    # D-06b token-validity guard step (Track A; in the Release Please job, additive)
.github/ISSUE_TEMPLATE/release-train-drift.md    # NEW — JasonEtco issue template for the drift guard
scripts/public_smoke.sh OR test/test_helper.exs  # D-08 junit hardening (Track A)
guides/release_publish.md                        # D-07 runbook entry (~line 118 "Recovery Workflow Contract")
.planning/RELEASE-TRAIN.md                        # D-07 Verification-Log row (root cause; Track A) + "released" row (Track B)
.planning/PROJECT.md                             # D-10/D-11 truth edits (Track B — AFTER publish)
.planning/MILESTONES.md                          # D-10/D-11 truth edits (Track B — AFTER publish)
.planning/RETROSPECTIVE.md                       # D-10/D-11 truth edits (Track B — AFTER publish)
```

### Pattern 1: D-06b token-validity guard (additive step in the existing `Release Please` job)
**What:** An early step in `release.yml`'s `release-please` job that, when `RELEASE_PLEASE_TOKEN` is non-empty, validates it and fails loudly with a rotation hint — so a future expired token surfaces a clear message instead of an opaque `Bad credentials` deep inside the action.
**When to use:** Before the `Run Release Please` step. Keep it inside the existing job so it shares the job's permissions; this does NOT add a new required check.
```yaml
# Source: derived from release.yml:50-57 + sibling gh-api validation idiom
- name: Validate RELEASE_PLEASE_TOKEN if present (fail loud, don't silently fall through ||)
  if: ${{ secrets.RELEASE_PLEASE_TOKEN != '' }}
  env:
    GH_TOKEN: ${{ secrets.RELEASE_PLEASE_TOKEN }}
  shell: bash
  run: |
    set -euo pipefail
    if ! gh api user >/dev/null 2>&1; then
      echo "::error::RELEASE_PLEASE_TOKEN is present but INVALID (expired/revoked). " \
           "release.yml uses 'secrets.RELEASE_PLEASE_TOKEN || github.token' — a present-but-bad " \
           "secret WINS the || and github.token never engages, so release-please dies on 'Bad " \
           "credentials'. Rotate the secret (fine-grained PAT or GitHub App token) then re-run."
      exit 1
    fi
    echo "RELEASE_PLEASE_TOKEN validated."
```
> Note: GitHub Actions does not allow `secrets.*` directly in a step-level `if:` on all runner versions; if the `if` expression errors, gate inside the `run:` block instead (`[ -n "${RELEASE_PLEASE_TOKEN:-}" ] || exit 0`) reading the secret via `env:`. The planner should pick whichever the repo's actionlint accepts (the repo already has 7 known pre-existing actionlint findings — do not add new ones).

### Pattern 2: D-06a release-train drift guard (new non-required workflow)
**What:** A daily-cron + `workflow_dispatch` job that fails / self-files a rolling issue when `main` has `feat:`/`fix:` commits ahead of the last `rindle-v*` tag with no open release-please PR. Models the scrypath/rulestead `verify-published-release.yml` cron + `JasonEtco/create-an-issue@v2` (`update_existing: true`, `search_existing: open`) idiom, including the close-on-success step.
**When to use:** Standalone `.github/workflows/release-train-drift.yml`. MUST NOT be added to `ci-summary.needs` or the required-check set.
```yaml
# Source: scrypath/.github/workflows/verify-published-release.yml (cron + JasonEtco idiom)
name: Release Train Drift Check
on:
  schedule:
    - cron: "23 7 * * *"   # daily; offset from sibling's "17 6"
  workflow_dispatch:
permissions:
  contents: read
  issues: write
concurrency:
  group: release-train-drift-${{ github.ref }}
  cancel-in-progress: true
jobs:
  drift:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@34e114876b0b11c390a56381ad16ebd13914f8d5 # v4.3.1
        with: { fetch-depth: 0, fetch-tags: true }
      - id: check
        shell: bash
        run: |
          set -euo pipefail
          last_tag="$(git describe --tags --match 'rindle-v*' --abbrev=0)"
          # releasable commits since last tag (feat:/fix:), excluding the release-please bump
          ahead="$(git log "${last_tag}..HEAD" --pretty=%s | grep -cE '^(feat|fix)(\(|:)' || true)"
          open_pr="$(gh pr list --state open --base main \
            --search 'head:release-please--branches--main--components--rindle' \
            --json number --jq 'length')"
          echo "ahead=$ahead open_pr=$open_pr"
          if [ "$ahead" -gt 0 ] && [ "$open_pr" -eq 0 ]; then
            echo "drift=true" >> "$GITHUB_OUTPUT"
          else
            echo "drift=false" >> "$GITHUB_OUTPUT"
          fi
        env:
          GH_TOKEN: ${{ github.token }}
      - name: Open or update drift issue
        if: ${{ steps.check.outputs.drift == 'true' && github.event_name == 'schedule' }}
        uses: JasonEtco/create-an-issue@v2
        env: { GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }} }
        with: { update_existing: true, search_existing: open, filename: .github/ISSUE_TEMPLATE/release-train-drift.md }
      - name: Close drift issue on recovery
        if: ${{ steps.check.outputs.drift == 'false' }}
        env: { GH_TOKEN: ${{ secrets.GITHUB_TOKEN }} }
        run: |
          n="$(gh issue list --state open --search 'in:title \"Release train drift\"' --json number --jq '.[0].number // empty')"
          [ -n "$n" ] && gh issue close "$n" --comment "Release train no longer drifting." || echo "no open drift issue"
      - name: Fail on drift
        if: ${{ steps.check.outputs.drift == 'true' }}
        run: { echo "main has releasable commits with no open release PR." >&2; exit 1; }
```
> The exact `git log`/`gh pr list` predicate is Claude's discretion (D-06); the cron + JasonEtco + close-on-recovery skeleton is the locked idiom to mirror.

### Anti-Patterns to Avoid
- **Hand-authoring the 0.3.2 release PR (Option B):** the automerge guard (`release-please-automerge.yml:42-83`) requires the head branch `release-please--branches--main--components--rindle`, a title matching `^chore\(main\): release rindle \d+\.\d+\.\d+$`, and an *exact* 3-file set (`.release-please-manifest.json,CHANGELOG.md,mix.exs`). A hand-authored PR that misses any of these is silently ineligible. Rejected by D-05.
- **Out-of-band `mix hex.publish` (Option C):** bypasses the `gate-ci-green` exact-SHA green gate the maintainer guards; irreversible on Hex. Rejected by D-05.
- **Pre-writing "0.3.2 is now live" before publish (violates D-12):** turns the truth-sweep into a new lie if the cut stalls again.
- **Adding a guard workflow to `CI Summary.needs` / required checks:** violates D-09 and the carried release-coupling invariant. The guards must stay non-required.
- **Renaming or restructuring `ci.yml` / `name: CI`:** breaks `release-please-automerge.yml` (`workflow_run: workflows: [CI]`) and `gate-ci-green` (`workflow_id: 'ci.yml'`). Hard invariant.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cutting the 0.3.2 release | Manual tag + `mix hex.publish` | Rotate token → let release-please + automerge + dispatch run | Preserves the exact-SHA green gate, version-alignment asserts, and idempotency probe the maintainer guards (D-05) |
| Self-filing drift issue | Custom `gh issue create` script | `JasonEtco/create-an-issue@v2` (`update_existing`/`search_existing`) | Sibling-proven; rolling single issue, auto-dedup, close-on-recovery |
| Resolving "latest published version" | Parse `mix hex.info` text | `curl https://hex.pm/api/packages/rindle` + `jq '.latest_stable_version'` | Existing `public_verify` + sibling pattern; structured, 404-aware |
| CHANGELOG/version bump for 0.3.2 | Hand-edit `mix.exs`/manifest/CHANGELOG | release-please writes them (D-12) | The mechanical cut is release-please's job; hand-editing risks automerge file-set mismatch |

**Key insight:** the pipeline is *intact and credential-starved* — there is nothing to build. The whole HYGIENE-01 action is "rotate a secret and observe the existing machine run." Every hand-rolled shortcut defeats a guard the maintainer deliberately put in place.

## Runtime State Inventory

> This is a release/planning-hygiene phase with a runtime-state dimension (GitHub repo secrets, labels, Hex registry). Inventory:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | Hex.pm registry: latest = `0.3.1` (verified via `hex.pm/api/packages/rindle`: releases `[0.3.1, 0.3.0, 0.1.10…]`, no 0.3.2). | After the cut, registry gains `0.3.2` — verified by `public_verify`, not by Claude. |
| Live service config | GitHub repo secret `RELEASE_PLEASE_TOKEN` (expired PAT — invalid). PR #40 label `autorelease: pending` (stale; 0.3.1 IS published). | **[HUMAN]** rotate the secret (Track B blocker). `gh pr edit 40` relabel to `autorelease: tagged` (Claude can do this once a valid token exists, or maintainer does it). |
| OS-registered state | None — no Task Scheduler / launchd / pm2 state references `0.3.2`. | None. |
| Secrets/env vars | `RELEASE_PLEASE_TOKEN` (expired), `HEX_API_KEY` (release env — assumed valid; 0.3.1 published with it), `BRANCH_PROTECTION_PAT`. Only `RELEASE_PLEASE_TOKEN` is the blocker. | Maintainer rotates `RELEASE_PLEASE_TOKEN`; prefer a GitHub App installation token (no expiry surprise) per D-05/specifics. |
| Build artifacts | `mix.exs @version "0.3.1"`, `.release-please-manifest.json {".": "0.3.1"}`, `CHANGELOG.md` top = `[0.3.1]`. The `:epipe`/`$callers` fix commits (`ce18719`, `9948a22`, `830a9a4`, `80ab4e1`, dated 2026-06-28) are on `main` but NOT in the 0.3.1 tag (verified via `git merge-base --is-ancestor` — all return NOT-in-0.3.1). | release-please bumps all three to `0.3.2` (D-12). |

**Verification commands used (re-runnable):**
```bash
mix.exs:        grep -n '@version' mix.exs                      # → 0.3.1
manifest:       cat .release-please-manifest.json               # → {".": "0.3.1"}
Hex live:       curl -fsSL https://hex.pm/api/packages/rindle | jq '.latest_stable_version'  # → 0.3.1
fix in 0.3.1?:  git merge-base --is-ancestor ce18719 rindle-v0.3.1 && echo IN || echo NOT-IN  # → NOT-IN
failed run:     gh run view 28399407429 --json jobs            # → "Run Release Please" FAILED, rest skipped
failure text:   gh run view 28399407429 --log | grep -i 'bad credentials'  # → "release-please failed: Bad credentials"
PR 40:          gh pr view 40 --json title,labels,mergedAt     # → "release rindle 0.3.1", autorelease: pending, merged 2026-06-26
```

## Common Pitfalls

### Pitfall 1: D-04's evidence narrative is factually wrong about PR #40 (the mechanism is still right)
**What goes wrong:** D-04 states the last good run "Found pull request #40" was the 0.3.2 PR and that the expired token blocked opening it. The planner could record this incorrect causal story in the investigation/runbook.
**Why it happens:** PR #40 is titled `chore(main): release rindle **0.3.1**` (merged 2026-06-26 13:02). The last good release-please run (`28265065628`, 2026-06-26 21:01) logged `❯ Found pull request #40: 'chore(main): release rindle 0.3.1'` — i.e. it was *re-finding the already-merged 0.3.1 PR's tagging*, not opening a 0.3.2 PR. The `:epipe`/`$callers` fixes merged 2026-06-28, AFTER that run. The FIRST release-please run after the fixes landed was `28399407429` (2026-06-29) — the one that 401'd.
**How to avoid:** Record the corrected chain in the investigation + `guides/release_publish.md` + `RELEASE-TRAIN.md`: *"The fix commits merged 2026-06-28, after the last successful release-please run (2026-06-26). The next push-to-main (2026-06-29, run 28399407429) — the first that would have opened a 0.3.2 PR — failed with `Bad credentials` because `RELEASE_PLEASE_TOKEN` had expired and `secrets.RELEASE_PLEASE_TOKEN || github.token` lets a present-but-invalid secret win the `||`. So no 0.3.2 PR was ever opened."* The fix (D-05) is unchanged.
**Warning signs:** Any draft prose claiming "PR #40 was the 0.3.2 PR" or "release-please tried to open 0.3.2 and failed on #40."

### Pitfall 2: EVAL dimension→phase mapping must match REQUIREMENTS.md byte-for-byte
**What goes wrong:** The EVAL's weakness→closing-phase column drifts from REQUIREMENTS.md traceability, breaking the contract 114/115/116 consume.
**Why it happens:** The mapping is split across D-03, SEED-005, and REQUIREMENTS.md — easy to transcribe a phase number wrong.
**How to avoid:** Use this verified-aligned mapping (REQUIREMENTS.md §Traceability + §Phase distribution confirm it exactly):
- governance/trust **2/5** → **Phase 114**: TRUST-01, TRUST-02, TRUST-03, META-01, META-02
- versioning/path-to-1.0 **2/5** → **Phase 115**: VERSION-01, VERSION-02
- README positioning **2.5/5** → **Phase 115**: README-01, README-02
- host-app respectfulness **3.5/5** → **Phase 116**: MIGRATE-01, MIGRATE-02 (breaking schema flip explicitly deferred → v1.23 ISO23-*)
- Strong/untouched: telemetry **5/5**, docs/ExDoc IA **4.5/5**, public API + `Rindle.Error` **4/5**, CI/testing.
**Warning signs:** A phase number or REQ-ID in the EVAL that doesn't appear in REQUIREMENTS.md §Traceability.

### Pitfall 3: The D-08 junit fix could be mistaken for a precondition of the cut
**What goes wrong:** Treating "make public_smoke green" as a gate before cutting 0.3.2 — when in fact 0.3.1's smoke fails *because of the bug 0.3.2 fixes*.
**Why it happens:** The `bad argument` error looks like infra breakage but is a teardown symptom of the `:epipe` crash. The published 0.3.1 tarball lacks the fix; smoke run against it crashes; 0.3.2's smoke runs against a tarball that HAS the fix.
**How to avoid:** Per D-08, fix `public_smoke.sh`/junit-write robustness as a *separate, parallel* Track-A item. Do NOT block the cut on it. The minimal hardening: guard the JUnitFormatter report write so an abnormal suite exit yields a clean failure, not `File.Error ... bad argument`. Options (Claude's discretion): (a) wrap/ensure `_build/test/junit` exists and is writable in the install-smoke run context regardless of crash; (b) only enable JUnitFormatter in `test_helper.exs` when `CI` AND not running the install-smoke shell-out child; (c) make `public_smoke.sh` unset `CI` for the parent install-smoke `mix test` so JUnitFormatter doesn't engage during the crash-prone clean-room run. Pin to the precise failure: `JUnitFormatter.handle_suite_finished/1` at `formatter.ex:164` writing `_build/test/junit/rindle-junit.xml` during an `:epipe`-induced `GenServer.stop`.
**Warning signs:** A plan task that lists "public_smoke green" as a dependency/precondition of "cut 0.3.2."

### Pitfall 4: Truth-edit line numbers have drifted from D-10
**What goes wrong:** Editing the wrong line, or missing a live hit / touching an out-of-scope one.
**Why it happens:** Files shifted since D-10 was written.
**How to avoid:** Use these VERIFIED current locations (grepped this session). **Live, in-scope (Track B, edit AFTER publish):**
- `.planning/PROJECT.md`: line **19** ("...**0.3.2** via release-please `fix:` commits..."), block **43–48** ("Release-state correction (2026-06-29): Hex 0.3.2 was never published..." — re-date/re-tense once live), line **70** ("cut the stuck Hex 0.3.2 release..."), line **109** ("...→ ships Hex **0.3.2**"), line **405** ("`lib/` `fix:` patches → Hex 0.3.2"), line **599** (D-v1.21-01 decision row mentions 0.3.2). Line **814** ("confirmed Hex 0.3.2 was never published") — **leave per D-10** (accurate-as-of-its-context; the v1.21 retro statement). Note D-10 named ~18-19/~43-48/~405/~599/~814 but missed **70** and **109** — the planner should decide per D-11 whether those aspirational-prose hits also need the reconciliation tense-flip (recommend: yes, they say "cut the stuck"/"ships as" which become past-tense once live).
- `.planning/MILESTONES.md`: line **20** ("...→ Hex 0.3.2 via two adopter-invisible `fix:` patches").
- `.planning/RETROSPECTIVE.md`: line **9** ("...→ Hex 0.3.2 via two `fix:` patches").

**Out-of-scope (D-13 — DO NOT edit):** all of `.planning/milestones/v1.21-*` (REQUIREMENTS/ROADMAP/MILESTONE-AUDIT + `v1.21-phases/109,110/*`), and CHANGELOG `**104-03:**`-style false positives. Also: `.planning/STATE.md` (lines 49,51,52,82,85,101,102,108,146), `.planning/ROADMAP.md` (lines 6,40,50,62,65,66,161,166,338), and `SEED-005`/`REQUIREMENTS.md` hits already say "never published / merged-but-unreleased / cuts the stuck release" — **correct as-is; optional future→past tense polish only**, not required (D-13).
**Warning signs:** A diff touching any `milestones/v1.21-*` path, or pre-publish edits to the "now live" prose.

### Pitfall 5: `secrets.*` in a step-level `if:` may not evaluate
**What goes wrong:** The D-06b token-validity guard's `if: ${{ secrets.RELEASE_PLEASE_TOKEN != '' }}` can error or always-skip depending on runner/context support for secrets in `if`.
**How to avoid:** If actionlint/CI rejects it, move the emptiness check into the `run:` body (read via `env:`, `[ -n "${RELEASE_PLEASE_TOKEN:-}" ] || { echo "no token set; relying on github.token"; exit 0; }`). Do not introduce new actionlint findings (7 pre-existing exist; the bar is "add zero").

### Pitfall 6: SEED frontmatter field shape
**What goes wrong:** Wrong token (`promoted` vs `consumed`) or wrong field placement.
**How to avoid:** Mirror the VERIFIED SEED-002 precedent exactly — `status: consumed` (not `promoted`), with `consumed:` and `consumed_by:` placed **after `planted_during:`** (SEED-002 order: `status`/`planted`/`planted_during`/`consumed`/`consumed_by`/`trigger_when`/`scope`). Use the D-14 verbatim strings for SEED-003/004.

## Code Examples

### EVAL-01 house-style scorecard (mirror `v1.21-MILESTONE-AUDIT.md` `## Scorecard`)
```markdown
<!-- Source: .planning/milestones/v1.21-MILESTONE-AUDIT.md lines 1-50 (frontmatter + ## Scorecard) -->
---
milestone: v1.22
name: OSS Quality & Trust Hardening
evaluated: 2026-06-29
source: SEED-005 (software-quality consolidation recon, 2026-06-29)
headline: "Engineering strong; project-surface weak — v1.22 fixes the surface, not the engine."
---

# Milestone v1.22 — OSS Quality Evaluation (Scored-Weakness Summary)

**Method:** scores 1–5 (5=strong), lifted from the SEED-005 recon (not re-derived).
Evidence is a present file, a *named* absence, or a code path.

## Weak dimensions v1.22 fixes

| Dimension | Score | Evidence (present / named-absence / path) | Closing phase → reqs |
|-----------|-------|-------------------------------------------|----------------------|
| OSS governance / trust | 2/5 | absent: SECURITY.md, CODE_OF_CONDUCT.md, .github/ISSUE_TEMPLATE/; thin Hex `package.links`; no `maintainers` (mix.exs) | 114 → TRUST-01/02/03, META-01/02 |
| Versioning / path-to-1.0 | 2/5 | absent: stated SemVer / pre-1.0 policy in README+CONTRIBUTING | 115 → VERSION-01/02 |
| README positioning | 2.5/5 | README leads AV-heavy (FFmpeg/libvips) first-run; no "when not to use" block | 115 → README-01/02 |
| Host-app respectfulness | 3.5/5 | raw 15-file `Ecto.Migrator` install; Rindle creates shared `oban_jobs` (latent host-Oban collision) | 116 → MIGRATE-01/02 (breaking schema flip → v1.23) |

## Strong dimensions v1.22 does NOT touch

| Dimension | Score | Evidence |
|-----------|-------|----------|
| Telemetry | 5/5 | … |
| Docs / ExDoc IA | 4.5/5 | … |
| Public API + `Rindle.Error` | 4/5 | … |
| CI / testing | strong | merge-blocking gate, exact-SHA release proof |

## Out of this milestone
- The four strong dimensions above (no work planned).
- The breaking Postgres schema-default flip to `rindle` → **v1.23 (0.4.0)**, ISO23-01..04.
```
> Stay ~1 page / 1.5 max (D-02). The accrue `176-SCORECARD.md` cousin is ~590 lines — borrow shape, not length.

### D-07 RELEASE-TRAIN.md Verification-Log row (existing table at line 24)
```markdown
<!-- Source: .planning/RELEASE-TRAIN.md "## Verification Log (maintainer)" table, cols: Date | Check | Result | Evidence -->
| 2026-06-29 | Release-please stuck: 0.3.2 PR never opened | Root-caused + guarded | `Bad credentials` 401 in [run 28399407429](…/actions/runs/28399407429); `RELEASE_PLEASE_TOKEN` expired; `secrets.X \|\| github.token` masks a bad token. Rotated token + added release-train-drift guard + token-validity guard. |
| 2026-06-29 | 0.3.2 publish + public verify | Pass | [release run …] — Publish + Public Verify success (Track B, after rotation) |
```

### D-07 guides/release_publish.md runbook entry (extend "## Recovery Workflow Contract", ~line 118)
```markdown
<!-- Append a subsection under Recovery Workflow Contract -->
### Stuck release: expired RELEASE_PLEASE_TOKEN (the `|| github.token` footgun)

Symptom: `release-please failed: Bad credentials` in the `Release Please` job; no
`chore(main): release rindle X.Y.Z` PR appears despite releasable commits on `main`.

Root cause: `release.yml` uses `token: ${{ secrets.RELEASE_PLEASE_TOKEN || github.token }}`.
A present-but-expired/revoked `RELEASE_PLEASE_TOKEN` WINS the `||`; `github.token` never
engages, so every push run 401s before opening the release PR.

Recovery:
1. Rotate `RELEASE_PLEASE_TOKEN` (prefer a GitHub App installation token — no expiry
   surprise — or a fine-grained PAT: contents:write + pull-requests:write [+ issues:write]).
   Update repo Settings → Secrets → Actions → `RELEASE_PLEASE_TOKEN`.
2. If a prior release PR is stuck on `autorelease: pending` but its version IS published,
   relabel truthfully: `gh pr edit <N> --remove-label "autorelease: pending" --add-label "autorelease: tagged"`.
3. Push (or re-run the latest `main` push) to re-trigger `release.yml`; release-please opens
   the release PR; the canonical automerge → dispatch → gate-ci-green → publish chain runs.

Prevention: the `release-train-drift.yml` guard self-files an issue when `main` has
releasable commits with no open release PR; the token-validity step in the `Release Please`
job fails loudly when the token is present-but-invalid.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `secrets.X \|\| github.token` assumed safe | Recognized as a footgun (bad token masks fallback) | This phase (D-06b) | Add a token-validity preflight; fail loud, not opaque |
| No drift detection between `main` and last tag | scheduled drift guard self-files an issue | This phase (D-06a) | Rindle becomes the reference impl (no sibling has it yet) |

**Deprecated/outdated:**
- The "PR #40 = the 0.3.2 PR" framing in D-04 — superseded by the verified chain (PR #40 = 0.3.1; fixes merged 2026-06-28; first post-fix release-please run 2026-06-29 401'd).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `HEX_API_KEY` (release environment) is still valid (0.3.1 published with it). | Runtime State Inventory | LOW — if invalid, publish step fails with the existing explicit `::error::HEX_API_KEY missing/invalid` message; surfaces clearly, not silently. |
| A2 | The expired `RELEASE_PLEASE_TOKEN` is the sole blocker (config/path-filter/commit-type ruled out per D-04). | HYGIENE-01 | LOW — re-confirmed: the only failed step is "Run Release Please" with `Bad credentials`; all downstream jobs `skipped`. |
| A3 | 0.3.2's `public_smoke` will pass once the tarball contains the `:epipe` fix. | Pitfall 3 | MEDIUM — the junit teardown write is brittle independent of `:epipe`; D-08 hardening de-risks this. If a *different* crash occurs, the same `bad argument` could recur — hence harden, don't assume. |
| A4 | release-please will compute `0.3.2` (patch bump) from the `fix:` commits given `bump-patch-for-minor-pre-major: true`. | Architecture | LOW — config verified (`release-please-config.json`: `bump-minor-pre-major` + `bump-patch-for-minor-pre-major` both true; pre-1.0 `fix:` → patch). |
| A5 | The maintainer is willing/able to rotate the secret (the human checkpoint). | Sequencing | HIGH for Track B timing — Track B is fully blocked until this happens; Track A is independent. Plan must not stall Track A on it. |

## Open Questions

1. **GitHub App token vs fine-grained PAT for `RELEASE_PLEASE_TOKEN`?**
   - What we know: D-05/specifics *prefer* a GitHub App installation token (no expiry surprise).
   - What's unclear: whether the maintainer wants to set up a GitHub App now or rotate another PAT.
   - Recommendation: surface as a maintainer choice in the human-checkpoint task; either unblocks Track B. Record the choice in the RELEASE-TRAIN row.

2. **Does the D-06b token-validity `if: secrets.* != ''` evaluate on this repo's runners?**
   - What we know: secrets-in-`if` support is version/context dependent; the repo has 7 pre-existing actionlint findings and a "add zero new findings" bar.
   - Recommendation: author the guard with the `run:`-body emptiness check fallback (Pitfall 5) so it's robust regardless; let `mix ci`/actionlint pick the accepted form.

3. **Should PROJECT.md lines 70 and 109 (aspirational "cut the stuck"/"ships as 0.3.2") also get the D-11 tense-flip?**
   - What we know: D-10 enumerated 18-19/43-48/405/599/814 but not 70/109; D-11 says reuse the reconciliation sentence "across touched docs."
   - Recommendation: yes — include 70 and 109 in the Track-B sweep (they become past-tense once live); they are live-truth prose, not archive. Flag to maintainer as a minor scope nudge beyond D-10's literal list.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI | live-state verification, drift guard, relabel | ✓ | (authenticated; ran successfully this session) | — |
| `git` (with `rindle-v*` tags) | drift predicate, ancestry checks | ✓ | tags present (`rindle-v0.3.1` etc.) | — |
| Hex.pm API (`hex.pm/api/packages/rindle`) | version resolution | ✓ | reachable (returned releases JSON) | — |
| `RELEASE_PLEASE_TOKEN` (valid) | release-please opening the 0.3.2 PR | ✗ | expired/invalid | **[HUMAN] rotation — no automated fallback (the `|| github.token` fallback does NOT engage for a bad token)** |
| `HEX_API_KEY` (release env) | publish step | assumed ✓ (A1) | — | explicit error if missing |

**Missing dependencies with no fallback:**
- Valid `RELEASE_PLEASE_TOKEN` — the single hard human blocker for Track B (the 0.3.2 cut). Track A proceeds without it.

**Missing dependencies with fallback:**
- None.

## Validation Architecture

> `workflow.nyquist_validation` key is absent in `.planning/config.json` → treated as ENABLED.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.17 / OTP 27) + `junit_formatter ~> 3.4` (CI-gated) |
| Config file | `test/test_helper.exs` (JUnitFormatter wiring lines 31-47) |
| Quick run command | `mix test test/install_smoke/package_metadata_test.exs` (asserts smoke-script shape; fast, no MinIO) |
| Full suite command | `mix ci` (mirrors the PR merge-blocking set; `mix.exs` alias) |

### Phase Requirements → Test/Verification Map
| Req ID | Behavior | Test Type | Automated Command / Check | File Exists? |
|--------|----------|-----------|---------------------------|-------------|
| EVAL-01 | EVAL doc exists at the locked path, ~1 page, two scored tables, mapping matches REQUIREMENTS | file-existence + content-grep | `test -f .planning/milestones/v1.22-OSS-QUALITY-EVAL.md && grep -q 'TRUST-01' …` | ❌ Wave 0 (new doc) |
| HYGIENE-01 (investigation) | Root cause recorded in RELEASE-TRAIN + release_publish guide | content-grep | `grep -q 'Bad credentials' .planning/RELEASE-TRAIN.md guides/release_publish.md` | ❌ Wave 0 |
| HYGIENE-01 (guards) | Drift workflow present + OFF required path; token-validity step present | YAML-presence + required-path absence | `test -f .github/workflows/release-train-drift.yml`; assert NOT in `ci-summary.needs` (mirror `ci_observability_test.exs` grep style) | ❌ Wave 0 (consider an install_smoke meta-test) |
| HYGIENE-01 (junit, D-08) | public_smoke survives an abnormal-exit suite without `bad argument` | harness fix + (optionally) a regression assertion | manual/observed in `public_verify`; optional `test_helper` guard meta-test | ❌ Wave 0 |
| HYGIENE-01 (cut) | Hex live = 0.3.2; mix.exs/manifest/CHANGELOG = 0.3.2 | **HUMAN-GATED** (post-publish) | `curl hex.pm/api/packages/rindle \| jq .latest_stable_version` == `0.3.2` | — (Track B, after rotation) |
| HYGIENE-01 (truth) | PROJECT/MILESTONES/RETROSPECTIVE say "0.3.2 is now live" (D-11) | content-grep | `grep -q 'released in v1.22 Phase 113' .planning/PROJECT.md` | — (Track B, after publish) |
| HYGIENE-02 | SEED-003/004 `status: consumed` + `consumed_by` | frontmatter-grep | `grep -A6 '^status:' .planning/seeds/SEED-003*.md \| grep -q 'consumed'` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** the file-existence/content-grep checks above (sub-second).
- **Per wave merge:** `mix test test/install_smoke/package_metadata_test.exs` (+ any new meta-test); `actionlint` over the new workflow (`mix ci` lint slice) — must add ZERO new findings.
- **Phase gate:** Track A verifiable fully by Claude (files, frontmatter, grep, YAML presence-off-required-path). Track B's "0.3.2 live" is the single HUMAN-gated criterion — verified by observing release-please/Actions + the Hex API, NOT by Claude. Mark it `checkpoint:human-verify` (token rotation) → then machine-observable (`curl … == 0.3.2`).

### What is automatically verifiable vs human-gated
- **Automatically verifiable (Track A + post-publish observation):** EVAL doc existence/shape/mapping; SEED frontmatter values; RELEASE-TRAIN/guide root-cause prose (grep); drift workflow YAML presence AND its absence from `ci-summary.needs`/required checks; token-validity step presence; truth-edit grep for the D-11 sentence; final `curl hex.pm/api/packages/rindle | jq .latest_stable_version == 0.3.2`.
- **Human-gated (irreducible):** the maintainer rotating `RELEASE_PLEASE_TOKEN` (repo-admin secret action). Everything downstream of it is automated by the existing pipeline.

### Wave 0 Gaps
- [ ] `.planning/milestones/v1.22-OSS-QUALITY-EVAL.md` — new (EVAL-01).
- [ ] `.github/workflows/release-train-drift.yml` + `.github/ISSUE_TEMPLATE/release-train-drift.md` — new (D-06a).
- [ ] Token-validity step in `release.yml` `Release Please` job — additive (D-06b).
- [ ] D-08 junit hardening in `scripts/public_smoke.sh` and/or `test/test_helper.exs`.
- [ ] (Optional, recommended) an `install_smoke` meta-test asserting the new guard workflow stays OFF `ci-summary.needs` — mirrors the existing `ci_observability_test.exs` OBS-02 grep-meta-test pattern that already guards CI invariants.

## Security Domain

> `security_enforcement` is not set in `.planning/config.json`; treated as enabled. This phase is doc/release-hygiene + workflow YAML — minimal attack surface. Relevant controls:

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no | — (no user input; YAML/markdown authoring) |
| V6 Cryptography | no | — |
| V14 Configuration (CI/CD secrets) | **yes** | Least-privilege token scope; prefer GitHub App token over long-lived PAT (D-05); fail-loud on invalid token (D-06b); never echo secret values in logs |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Over-scoped/long-lived release PAT | Elevation of Privilege | Fine-grained PAT (contents:write + pull-requests:write [+ issues:write]) or GitHub App installation token (D-05) |
| Secret leakage in workflow logs | Information Disclosure | The token-validity guard checks `gh api user` exit code only; never prints the token; uses `env:` not inline interpolation in `run:` |
| Silent auth failure masking (`secrets.X || github.token`) | Spoofing/DoS-of-release | D-06b fail-loud guard + D-06a drift detection |
| New required check sneaking onto the gate | Tampering (release-coupling) | D-09: guards stay OFF `CI Summary`/required path; optional meta-test asserts it |

## Sources

### Primary (HIGH confidence — verified this session)
- `gh run view 28399407429` — confirmed `release-please failed: Bad credentials`; only "Run Release Please" failed, rest skipped.
- `gh run view 28265065628 --log` — last good run: `Found pull request #40: 'chore(main): release rindle 0.3.1'` (PR #40 = 0.3.1, not 0.3.2).
- `gh pr view 40` — title `chore(main): release rindle 0.3.1`, label `autorelease: pending`, merged 2026-06-26.
- `gh run view 28246413418 --log` — exact junit failure chain (`:epipe` → `File.Error ... bad argument` at `JUnitFormatter.handle_suite_finished/1` formatter.ex:164).
- `curl hex.pm/api/packages/rindle` — latest_stable = 0.3.1; no 0.3.2.
- `git merge-base --is-ancestor` — `:epipe`/`$callers` fixes (2026-06-28) NOT in `rindle-v0.3.1` (2026-06-26).
- `.github/workflows/release.yml`, `release-please-automerge.yml`, `release-please-config.json` — full topology + automerge guard + version-bump config.
- `scripts/public_smoke.sh`, `test/test_helper.exs`, `test/install_smoke/support/generated_app_helper.ex` — junit wiring + clean-room shell-out.
- `.planning/milestones/v1.21-MILESTONE-AUDIT.md` `## Scorecard` — house-style format.
- `.planning/seeds/SEED-002/003/004/005-*.md` — frontmatter precedent + dimension scores + release-hygiene finding.
- `/Users/jon/projects/scrypath/.github/workflows/verify-published-release.yml`, `/Users/jon/projects/rulestead/.github/workflows/verify-published-release.yml` — cron + `JasonEtco/create-an-issue@v2` idiom (update_existing/search_existing/close-on-success).
- `.planning/PROJECT.md`, `MILESTONES.md`, `RETROSPECTIVE.md`, `STATE.md`, `ROADMAP.md`, `REQUIREMENTS.md` — truth-edit surfaces + traceability + line-number verification.
- `guides/release_publish.md` (Recovery Workflow Contract), `.planning/RELEASE-TRAIN.md` (Verification Log) — extension points.

### Secondary (MEDIUM confidence)
- D-04's narrative (CONTEXT.md) — partially superseded by primary live-state findings (see Pitfall 1).

### Tertiary (LOW confidence)
- None — all load-bearing claims were tool-verified this session.

## Metadata

**Confidence breakdown:**
- HYGIENE-01 root cause / mechanism: **HIGH** — re-confirmed against live Actions/git/Hex; D-04 mechanism correct, evidence narrative corrected.
- EVAL-01 format + mapping: **HIGH** — scores from SEED-005, mapping byte-checked against REQUIREMENTS.md, house-style from v1.21 audit.
- D-08 junit fix: **MEDIUM-HIGH** — exact failure chain captured; precise minimal fix is Claude's discretion among 3 verified-viable options.
- Truth-edit surfaces: **HIGH** — grepped + line-verified; drift from D-10 documented.
- Guard workflows: **HIGH** (idiom) / **MEDIUM** (exact predicate is discretion).

**Research date:** 2026-06-29
**Valid until:** 2026-07-06 (release-state is time-sensitive — Hex live version and token state can change; re-verify `curl hex.pm/api/packages/rindle` and the latest `release.yml` run before executing Track B).
