# Phase 79: CI Static-Analysis Policy Closure - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 79-ci-static-analysis-policy-closure
**Mode:** assumptions
**Areas analyzed:** Static-analysis severity, Rationale framing, Wiring approach, Doctor scope, Thread closure

## Assumptions Presented

### Static-analysis severity — Credo & Dialyzer stay advisory
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Keep Credo and Dialyzer advisory; do not remove `continue-on-error` | Confident | `.github/workflows/ci.yml` L97–99, L131–133; `RUNNING.md` L23–27; v1.16 out-of-scope; coveralls merge-blocking `0036760`; proof/package-consumer/adopter blocking |

### Rationale framing — signal value vs fork latency
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Document rationale under `### Static analysis policy (CI-04)` in RUNNING.md covering signal value, fork latency, green-main honesty | Likely | `REQUIREMENTS.md` CI-04 rationale requirement; Phase 71 proof-lane honesty pattern |

### Wiring — comments only, no workflow changes
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| No `ci.yml` wiring changes; update comments to reference CI-04 decision | Confident | ROADMAP success criteria #2; REQUIREMENTS out-of-scope guard; wiring already matches advisory |

### Doctor scope — out of CI-04 decision
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| CI-04 covers Credo and Dialyzer only; Doctor/AV doctor stay advisory without separate record | Confident | `REQUIREMENTS.md` CI-04 names only Credo/Dialyzer |

### Thread closure — remove "deferred" language
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Update assessment thread Open concerns L118; replace "Decision deferred" with recorded decision | Confident | ROADMAP success criteria #3; Phase 78 deferred to Phase 79 |

## Corrections Made

No corrections — all assumptions confirmed.

**User's choice:** "Yes, proceed" (option 1)

## Methodology Lenses Applied

- **Repo-Truth Evidence Ladder:** `ci.yml` + `RUNNING.md` canonical; threads follow
- **Diminishing-Returns Gate:** High-signal lanes already blocking; static analysis is narrow maintenance
- **Narrow-Then-Escalate:** Single policy record, not CI platform overhaul
- **Durable Planning Memory:** Phase 78 CONTEXT scoped CI-04 here explicitly
