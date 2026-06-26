# Phase 94: Foundation — Token Pipeline CI Gate & New Token Categories - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-14
**Phase:** 94-foundation-token-pipeline-ci-gate-new-token-categories
**Mode:** assumptions
**Calibration:** minimal_decisive (opinionated maintainer profile)
**Areas analyzed:** CI Gate Shape, Scope Boundary, Polish Generalization / Token Shape / Idempotency

## Assumptions Presented

### CI Gate — the `brandbook-tokens` job
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New standalone top-level job `brandbook-tokens`, `needs: [quality, optional-dependencies]`; setup-node@v4 (node 20) | Confident | `ci.yml:282/353/631/649` (one job per proof concern); node-20 pattern at `ci.yml:467,696`; brandbook shares no Elixir/Postgres/MinIO/ffmpeg setup |
| Job order: tokens-build → admin-css-build → admin-contrast → admin-gallery-check → sync 2nd CSS copy → `git diff --exit-code`; npm ci in examples/adoption_demo first | Confident | `admin-gallery-check.mjs:14-15` resolves playwright via adoption_demo `createRequire` |
| Gate must regen-and-diff BOTH committed CSS copies (brandbook + `priv/static/rindle_admin/`); make the hand-mirror a committed script | Confident | two byte-identical committed copies; no script copies to `priv/static/`; shipped artifact `mix.exs:279` (PITFALL #6) |

### Scope Boundary — admin-only in 94; Cohort categories → Phase 96
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 94 emits new categories to tokens.json + `.mjs` admin generators + widened CONSOLE_CONTRAST_PAIRS only; Cohort versions hand-authored later in Phase 96 (B1); 94 may seed `--ck-*` vocabulary but writes no cohort.css | Confident | ARCHITECTURE.md:111 "Do NOT generate cohort.css from tokens.json"; `cohort.css:5` "hand-authored, no build step"; no Cohort `.mjs`; SUMMARY Research Flags place dark contract in B1 |

### Polish Generalization, Token Shape & Idempotency
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Generalize admin-polish.js by threading `root`+`interactiveSelectors` params through `assertAdminPolish`, defaulting to admin set; no auto-detection | Confident | `admin-polish.js:16` single hardcoded ROOT const; spec passes `{viewport,surface}` options object (`admin-screenshots.spec.js:79`) |
| New categories as new top-level tokens.json objects, each with emit loop + entry in `exact()`/`requiredTokenUses` parity arrays (+ MOTION_TOKENS); clamp on display sizes only; dark status differentiated; elevation surface-tint not shadow | Likely | ARCHITECTURE.md:158-179; `tokens.json:99-104` dark status collapses today; `cohort.css:76` clamp ref |
| `git diff --exit-code` after single regen is sufficient idempotency anchor; no double-run needed | Likely | generators pure `Object.entries`; `exact()` parity = named anchor (STACK.md:33). Breaks if future generator adds Set/Date.now nondeterminism |

## Corrections Made

No corrections — maintainer selected "Yes, proceed"; all assumptions confirmed as presented.

## External Research

None performed. The repo + research SUMMARY/ARCHITECTURE already lock the *mechanism* for
every Phase-94 decision. Two items the analyzer flagged are **design judgment deferred to
`/gsd:ui-phase 94`** (not external research): the exact fluid `clamp()` bounds + named
breakpoints, and the differentiated dark-status hex values + 4-level elevation tint ramp.
The *shape* of both is locked in CONTEXT.md (D-94-09); only the values defer.

## Methodology Lenses Applied

- **Research-First Recommendation Lens:** Read local v1.19 research (SUMMARY/STACK/
  ARCHITECTURE/PITFALLS/FEATURES) + Phase 88 locked decisions before forming assumptions;
  returned decisive recommendations, not option menus (consistent with minimal_decisive tier).
- **Repo-Truth Evidence Ladder:** Every assumption cites shipped code/CI/test files first
  (`.mjs` generators, `ci.yml`, `admin-polish.js`, `tokens.json`, the two CSS copies), with
  research artifacts as supporting context — no decision made from an aspirational doc alone.
- **Adopter-First Done Lens:** The gate's reach was widened to the package-shipped
  `priv/static/rindle_admin/rindle-admin.css` precisely because that is the artifact adopters
  consume — drift there is an adopter-visible failure, not an internal one.
