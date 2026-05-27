# Phase 71: CI Proof Honesty - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-27
**Phase:** 71-ci-proof-honesty
**Mode:** assumptions
**Areas analyzed:** RUNNING.md matrix placement, CI-02 workflow changes, Advisory/soak lanes, Workflow comments, Merge-blocking ladder

---

## Assumptions Presented

### RUNNING.md matrix placement and shape
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Add `## CI lane severity` after intro, before `## Verify The Runtime`; table per job; keep FFmpeg matrix | Confident | `.planning/REQUIREMENTS.md` CI-01; `RUNNING.md` lines 10–12 |

### CI-02: package-consumer job-level; adopter step-level
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Remove job-level COE on `package-consumer`; remove step-level COE on adopter doctor + tests; no job-level COE on adopter | Likely | `.github/workflows/ci.yml` ~298, ~515–523 |

### Advisory and soak lanes stay non-blocking
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Leave quality/contract/gcs-soak/package-consumer-gcs-live COE; document release BYPASS only | Confident | `.planning/REQUIREMENTS.md` out-of-scope; `release.yml` ~204–214 |

### Workflow comment pattern
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| `# Phase 71 (CI proof honesty):` blocks at non-blocking lanes; pointer to RUNNING.md | Likely | ROADMAP success criterion 4; existing mux-soak/gcs-soak headers |

### Merge-blocking ladder
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Document per-job/step severity; contract tests advisory, hygiene blocking | Likely | `ci.yml` integration/contract/package-consumer/adopter structure |

---

## Corrections Made

No corrections — all assumptions confirmed by user (reply: "1").

---

## External Research

None performed — codebase and workflow files sufficient.
