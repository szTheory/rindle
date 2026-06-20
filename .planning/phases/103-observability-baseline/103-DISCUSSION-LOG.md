# Phase 103: Observability / Baseline - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-20
**Phase:** 103-observability-baseline
**Mode:** assumptions
**Areas analyzed:** Timing/cache surfacing (OBS-01); Slowest-tests/compile/schedulers/seed
(OBS-02); JUnit + coverage artifacts (OBS-02); Baseline + live required-check capture (OBS-03)

## Assumptions Presented

### Per-job/per-step timing + cache hit/miss (OBS-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Surface timing/cache into `$GITHUB_STEP_SUMMARY`, purely additive (no run:/gate change); add `id:` to existing `actions/cache@v4` restore steps for `cache-hit` | Likely | `ci.yml:122` (only PLT has id), `ci.yml:65-77,228-240` (deps/build have none), `branch-protection-apply.yml:28-33` (summary idiom) |

### Slowest-tests / compile / schedulers / seed (OBS-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Surface `--slowest 20`, compile profile, `schedulers_online`, ExUnit seed; seed is implicit and must be read from output | Likely | `ci.yml:117-118` (quality runs full suite via coveralls), `test_helper.exs:1-35` (bare ExUnit.start, no seed/formatters) |

### JUnit + coverage artifacts (OBS-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add test-only `junit_formatter` dep + wire test_helper; coverage via ExCoveralls + upload-artifact; OK under "zero lib change" | Likely | `mix.lock:25` (only excoveralls 0.18.5, no junit), `mix.exs:43,50-53` (ExCoveralls + coveralls.json/html env-mapped), `mix.exs:278-280` (test-only excluded from package files:) |

### Baseline + live required-check capture (OBS-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Scripted baseline under `scripts/ci/` via `gh api`; diff live required checks vs `setup_branch_protection.sh`; commit to internal `.planning/` doc; no composite action | Confident | existing `scripts/ci/*.sh` pattern, `setup_branch_protection.sh:17-31` (+`--print-expected`), `mix.exs:154-172,278-280` (extras/files allowlists), ROADMAP line 169 (composite reserved for Phase 104) |

## Corrections Made

Two open forks were surfaced to the maintainer (both resolved toward the recommended option):

### OBS-02 measurement scope
- **Original assumption:** slowest-tests/timing in the `quality` job only (minimal churn).
- **Maintainer decision:** **Quality + long-pole jobs** (`integration`, `package-consumer`).
- **Reason:** ROADMAP line 228 names per-step `package-consumer` timing + slowest-test evidence
  as the explicit input to the Phase 106 lane split; quality-only would under-measure the actual
  bottleneck. Captured as D-04.

### OBS-02 JUnit approach
- **Original assumption:** Likely — either a test-only dep or a custom formatter.
- **Maintainer decision:** **Add test-only `junit_formatter` dep** (`~> 3.4`, `only: :test`).
- **Reason:** "Zero lib change" means zero `lib/` change; test-only deps don't ship (excluded
  from Hex `files:`). Standard ecosystem approach, less to own than a hand-rolled formatter.
  Captured as D-06.

## Auto-Resolved

Not applicable (interactive mode).

## External Research

Not performed in this discuss step. Three research topics were flagged by the analyzer and
carried forward into CONTEXT.md `<canonical_refs>` as research flags for the dedicated
gsd-phase-researcher (ROADMAP explicitly flags Phase 103 as data-producing):
- Exact branch-protection `required_status_checks` API JSON shape (`contexts` vs
  `checks[].context`).
- Whether rerun/flake rate is directly available via `gh` or must be derived from `run_attempt`.
- `junit_formatter` version compatible with the 1.15/OTP26 + 1.17/OTP27 matrix.
