---
phase: 94-foundation-token-pipeline-ci-gate-new-token-categories
verified: 2026-06-15T20:39:56Z
status: passed
verification_mode: automated
manual_uat: not_required
score: 4/4 automated truths verified; BP-94-01 branch-protection gap resolved
overrides_applied: 0
re_verification:
  previous_status: verification_gap_recorded
  previous_score: 4/4 automated truths verified; 1 merge-blocking protection gap
gaps: []
resolved_gaps:
  - id: BP-94-01
    truth: "brandbook-tokens is merge-blocking on protected PRs"
    status: resolved
    severity: major
    evidence: "main branch protection requires brandbook-tokens; PR #23 shows brandbook-tokens passing"
---

# Phase 94: Foundation — Token Pipeline CI Gate & New Token Categories Verification Report

**Phase Goal:** The token→CSS pipeline is gated in CI and carries the new token categories the uplift needs, so all later visual work is idempotent and drift-proof. Blocks everything.
**Verified:** 2026-06-15T20:39:56Z
**Status:** passed (all 4 automated truths VERIFIED; `brandbook-tokens` is now required by branch protection and passing on PR #23)
**Re-verification:** Yes — prior status recorded a verification gap

## Re-verification Update — 2026-06-15T20:39:56Z

The original automation-first gate was re-run locally in CI order:

`npm ci` in `examples/adoption_demo` → `npx playwright install chromium` → `node brandbook/src/tokens-build.mjs` → `node brandbook/src/admin-css-build.mjs` → `node brandbook/src/admin-contrast.mjs` → `node brandbook/src/admin-gallery-check.mjs` → `node brandbook/src/sync-admin-css.mjs` → `git diff --exit-code`

Result: PASS. `admin-contrast.mjs` reported 44/44 pairs passing, `admin-gallery-check.mjs` wrote 7 screenshots and passed, `sync-admin-css.mjs` wrote a 23846-byte priv copy, and `git diff --exit-code` was clean.

Gap closure Plan 05 then resolved the remaining release-train protection layer:

- `scripts/setup_branch_protection.sh --print-expected-json | jq -e '.required_status_checks.contexts | index("brandbook-tokens")'` returned `12`.
- `gh api repos/szTheory/rindle/branches/main/protection/required_status_checks --jq '.contexts | index("brandbook-tokens")'` returned `12`.
- `gh pr checks 23 --watch=false | rg '^brandbook-tokens'` returned `brandbook-tokens pass 43s` for run `27574464166`, job `81519519377`.
- `.github/workflows/ci.yml` now uses `name: brandbook-tokens`, so the literal required context is satisfiable by the Actions check.

Conclusion: no manual UAT file is required for phase 94. Code-level evidence, branch-protection state, and PR check-rollup evidence are all automated and complete.

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth (ROADMAP SC) | Status | Evidence |
|---|--------------------|--------|----------|
| 1 | A `brandbook-tokens` CI job regenerates `rindle-admin.css` from `tokens.json` via the `.mjs` scripts, runs the WCAG contrast gate, and **fails the build on any uncommitted diff** | ✓ VERIFIED | `.github/workflows/ci.yml:1144` — standalone `brandbook-tokens` job, `needs:[quality, optional-dependencies]` (both jobs exist, satisfiable), node-20, D-94-02 step order: tokens-build → admin-css-build → admin-contrast → admin-gallery-check → sync-admin-css → `git diff --exit-code` with verbatim locked drift message. YAML parses clean. |
| 2 | `tokens.json` + generators emit the new categories — motion presets, semantic dark elevation/shadow ladder (not inversion), fluid type+space with named breakpoints, semantic dark status surfaces — flowing to `rindle-admin` (BEM) | ✓ VERIFIED | tokens.json has `elevation`/`space_fluid`/`breakpoint` objects, 3 new easing presets, `shadow.raised/overlay`, and **6 distinct** dark status-surface values (not collapsed). Emitted to `rindle-admin.css`: 12 elevation refs, 8 fluid-type, 4 fluid-space, 6 breakpoint, 3 easing presets, raised+overlay shadows, 7 `clamp()` uses. Parity registration (`requiredTokenUses`, `requiredMotionUses`, `exact()`) enforces emitted-AND-used. |
| 3 | Re-running the generators with unchanged source produces a **byte-identical, empty-diff** artifact (idempotency anchor) | ✓ VERIFIED | Live run: `tokens-build` + `admin-css-build` + `sync-admin-css` then `git diff --exit-code` over the four artifacts → **EMPTY DIFF**. priv copy `diff -q` IDENTICAL. Negative test: appending a byte to `rindle-admin.css` makes `git diff --exit-code` exit non-zero (gate detects drift), then restored. |
| 4 | The `admin-polish.js` computed-style gate is generalized to target any root selector, ready to run over both surfaces (VIS-01 groundwork) | ✓ VERIFIED | `assertAdminPolish(page, { ..., root = DEFAULT_ROOT, interactiveSelectors = DEFAULT_INTERACTIVE_SELECTORS })`; all 4 sub-assertions thread the param; **no auto-detection** (grep=0, D-94-07 honored); `admin-screenshots.spec.js` byte-unchanged vs HEAD; `node --check` passes. |

**Score:** 4/4 truths verified; BP-94-01 resolved

### ROADMAP `cohort.css` note

ROADMAP SC #1/#2 mention "(+ Cohort assets)" / "flowing to both `rindle-admin` and `cohort`". The plans explicitly scope-fence `cohort.css` to **Phase 96** (D-94-05/06) as a hand-authored analog, NOT generated or gated in Phase 94. This is a documented, deliberate decision recorded in 94-03/94-04 SUMMARYs and the plan threat models. It is correctly deferred — not a Phase 94 gap.

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | `cohort.css` generated + gated; Cohort assets in the drift gate | Phase 96 | 94-04 SUMMARY scope fence "gates `rindle-admin.css` only, `cohort.css` (Phase 96) explicitly excluded"; D-94-05/06 |
| 2 | VIS-01 fully delivered (single merge-blocking gate extended over admin + Cohort) | Phase 102 | REQUIREMENTS.md maps VIS-01 → Phase 102; Phase 94 delivers only the parameterized harness seam (groundwork) |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.github/workflows/ci.yml` (brandbook-tokens job) | Standalone gate job | ✓ VERIFIED | Exists L1144, `name: brandbook-tokens`, needs satisfiable, correct step order, locked message verbatim, tree-wide diff |
| `brandbook/src/sync-admin-css.mjs` | Single CSS-mirror | ✓ VERIFIED | readFileSync(source) → writeFileSync(priv copy); produces byte-identical priv copy |
| `brandbook/tokens/tokens.json` | Four new categories | ✓ VERIFIED | elevation/space_fluid/breakpoint objects + easings + 6 distinct dark status surfaces |
| `brandbook/src/admin-css-build.mjs` | Emit loops + parity | ✓ VERIFIED | New vars emitted; requiredTokenUses/requiredMotionUses/exact() enforce emitted-AND-used |
| `brandbook/tokens/rindle-admin.css` | Regenerated w/ new vars | ✓ VERIFIED | All new categories present; idempotent (empty diff) |
| `priv/static/rindle_admin/rindle-admin.css` | Synced shipped copy | ✓ VERIFIED | Byte-identical to source (`diff -q` clean) |
| `examples/adoption_demo/e2e/support/admin-polish.js` | Parameterized harness | ✓ VERIFIED | root/interactiveSelectors threaded; no auto-detect; spec unchanged |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| sync-admin-css.mjs | priv/.../rindle-admin.css | readFileSync + writeFileSync | ✓ WIRED | L32-33; live sync produced identical priv copy |
| brandbook-tokens job | `git diff --exit-code` | generators+sync run before diff | ✓ WIRED | Step order confirmed; negative test fails on drift |
| brandbook-tokens job | quality + optional-dependencies | needs: [...] | ✓ WIRED | Both dependency jobs exist in ci.yml |
| branch protection | brandbook-tokens job | required context exactly matches Actions check name | ✓ WIRED | required contexts index `12`; PR #23 `brandbook-tokens` check passes |
| tokens.json new objects | rindle-admin.css vars | emit loops + parity | ✓ WIRED | All categories emitted AND used (parity arrays) |
| dark status-surface hexes | admin-contrast.mjs WCAG gate | CONSOLE_CONTRAST_PAIRS | ✓ WIRED | Contrast gate 44/44, exit 0 |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Generators run + parity OK | `node tokens-build.mjs && node admin-css-build.mjs` | "parity OK" both | ✓ PASS |
| Contrast gate is a real merge-blocker | `node admin-contrast.mjs; echo $?` | 44/44 pairs, exit 0 (`if (failures) process.exit(1)`) | ✓ PASS |
| Sync produces identical priv copy | `node sync-admin-css.mjs; diff -q ...` | IDENTICAL | ✓ PASS |
| Idempotency (empty diff after regen) | `git diff --exit-code` over 4 artifacts | EMPTY DIFF | ✓ PASS |
| Drift detection (negative test) | append byte → `git diff --exit-code` | exit non-zero (caught), restored | ✓ PASS |
| Harness syntax valid | `node --check admin-polish.js` | SYNTAX OK | ✓ PASS |
| YAML parses | `yaml.safe_load(ci.yml)` | parses, needs satisfiable | ✓ PASS |
| Phase commits exist | `git cat-file` x7 | all 7 present | ✓ PASS |
| Branch protection requires brandbook-tokens | `gh api repos/szTheory/rindle/branches/main/protection/required_status_checks --jq '.contexts | index("brandbook-tokens")'` | `12` | ✓ PASS |
| PR rollup has passing brandbook-tokens check | `gh pr checks 23 --watch=false | rg '^brandbook-tokens'` | `brandbook-tokens pass 43s` | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| PIPE-01 | 94-01, 94-04, 94-05 | Token→CSS pipeline gated in CI; regen + WCAG + fails on diff; no hand-edits | ✓ SATISFIED | brandbook-tokens job + admin-contrast.mjs gate + tree-wide git diff; live empty-diff + drift-detection verified; branch protection now requires `brandbook-tokens`; PR #23 shows the check passing. |
| PIPE-02 | 94-03 | tokens.json + generators extended with 4 new categories flowing to rindle-admin | ✓ SATISFIED | 4 categories in source + emitted to CSS + parity-enforced; cohort.css deferred to Phase 96 (documented) |
| VIS-01 (groundwork) | 94-02, 94-03 | Parameterized admin-polish harness seam for the merge-blocking visual gate | ✓ SATISFIED | Harness parameterized over root/interactiveSelectors, no auto-detect, admin spec unchanged. Full VIS-01 → Phase 102. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| (none) | — | No TBD/FIXME/XXX in modified files; no stubs (every emitted var is parity-enforced as used) | — | — |

### Integration-Tag Caveat (investigated per phase brief)

**Finding:** `test/brandbook/admin_design_system_validation_test.exs` is `@moduletag :integration` and is **NOT executed by any CI job** — it is not referenced by name in `ci.yml`, and the only `--include integration` step runs unrelated upload/storage tests. So this ExUnit byte-equality test is effectively dormant in the merge pipeline.

**Assessment — does NOT weaken the PIPE-01 gate:** The `brandbook-tokens` job does not depend on `mix test` at all (verified: no `mix test` in the job). The intended drift + contrast checks are exercised independently by the `.mjs` scripts:
- **Contrast:** `admin-contrast.mjs` → `process.exit(1)` on any sub-AA pair (real merge-blocker, verified 44/44 / exit 0).
- **Byte-equality of the shipped priv copy:** the `sync-admin-css.mjs` step writes the priv copy and the subsequent tree-wide `git diff --exit-code` catches any divergence (verified the negative drift test fails).
- **Drift/idempotency:** tree-wide `git diff --exit-code` (verified empty after regen).

The CI `git diff` provides equivalent (in fact broader) coverage than the dormant ExUnit assertion. **Note (informational, not a gap):** the 94-01/94-03 SUMMARYs cite "ExUnit two-copy byte-equality stays green" as evidence — accurate only under `--include integration` locally, misleading as a CI-gate claim. The actual CI guarantee comes from the `.mjs` + `git diff` path, which is correctly wired.

### Resolved Verification Gaps

#### BP-94-01: `brandbook-tokens` is required by branch protection

**Truth:** `brandbook-tokens` is merge-blocking on protected PRs.
**Status:** resolved.
**Severity:** major.
**Evidence:** `gh api repos/szTheory/rindle/branches/main/protection/required_status_checks --jq '.contexts | index("brandbook-tokens")'` returns `12`, and `gh pr checks 23 --watch=false | rg '^brandbook-tokens'` returns `brandbook-tokens pass 43s`.
**Fix delivered:** `94-05-PLAN.md` added `brandbook-tokens` to `scripts/setup_branch_protection.sh` and `RUNNING.md`, aligned the Actions job display name to the required context, pushed the phase branch, and applied branch protection through the existing owner-controlled script.

### Gaps Summary

No open verification gaps remain. All four code-level ROADMAP truths are verified directly against the codebase with live command evidence: the gate exists and is correctly wired (step order, needs, locked message, tree-wide diff), the four new token categories are present in source AND emitted AND parity-enforced as used, the pipeline is idempotent (empty diff) and drift-detecting, and the admin-polish harness is parameterized without auto-detection while the admin spec is byte-unchanged.

The release-train protection layer is now verified too: branch protection requires `brandbook-tokens`, and PR #23 shows the matching Actions check passing on the pushed phase branch.

The `cohort.css` portion of the ROADMAP wording and full VIS-01 delivery are deliberately and explicitly deferred to Phases 96/102 respectively — documented scope fences, not omissions.

The integration-tag caveat is a real documentation-accuracy nuance but does NOT weaken any Phase 94 gate, because the merge-blocking `brandbook-tokens` job is pure-Node and enforces drift + contrast independently of the dormant ExUnit test.

Status is `passed`: no manual UAT is required for Phase 94.

---

_Verified: 2026-06-15T20:39:56Z_
_Verifier: Codex (gsd-verify-work)_
