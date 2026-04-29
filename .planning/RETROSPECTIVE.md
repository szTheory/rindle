# Retrospective: Rindle

---

## Milestone: v1.2 — First Hex Publish

**Shipped:** 2026-04-29
**Phases:** 5 (10–14) | **Plans:** 11

### What Was Built

- Maintainer-facing Hex publish guidance with explicit versioning, auth, and owner model plus executable parity gate
- Shared release preflight script proving artifact contents, release-doc parity, install smoke, and docs warnings
- Protected live Hex.pm publish via scoped credential in GitHub release environment with concurrency guard
- Version drift gate (`assert_version_match.sh`) blocking publication on tag/mix.exs mismatch
- Automated CI dry-run publish job exercising the release flow on every commit
- Fresh-runner post-publish verification job proving Hex.pm network resolution on every release
- Maintainer release runbook covering first-publish, routine releases, and rollback/revert locked to live workflow by parity tests
- Canonical `requirements-completed` frontmatter normalized across all release phase summaries
- Phase 10 and Phase 11 VALIDATION artifacts completed to Nyquist-compliant state

### What Worked

- **Tight phase scoping:** Keeping v1.2 narrowly focused on the publish/release path (no new API surface) meant every phase compounded directly on the previous one.
- **Executable parity gates:** Using ExUnit to assert guide language matches live workflow step names and commands (positive + refutation assertions) caught drift that would have been missed in a prose-only review.
- **Preflight script as single source of truth:** Centralizing the package, docs, and install-smoke gates behind `scripts/release_preflight.sh` prevented workflow drift between local and CI release checks.
- **Separate `public_verify` job:** Isolating post-publish verification in a fresh-runner job with cleared credentials cleanly separated publish concerns from verification concerns.
- **Phase 13 as cleanup phase:** Explicitly planning a traceability normalization phase rather than trying to fix metadata drift as a side effect of other work kept the closure clean and auditable.

### What Was Inefficient

- **Audit `tech_debt` status required two cleanup phases:** The v1.2 milestone audit landed at `tech_debt` rather than `passed` because requirement trace metadata was inconsistent across summaries. Phases 13 and 14 were planned specifically to close that debt. Better metadata discipline during earlier phases would have avoided these cleanup phases entirely.
- **Summary frontmatter inconsistency:** Three different frontmatter keys (`requirement:`, `requirements:`, `requirements-completed`) were used across phases. A shared frontmatter convention established before execution would have prevented the Phase 13-01 repair work.
- **Validation artifacts left draft:** Phases 10 and 11 VALIDATION files were left in partial/draft state after their respective phases completed. Building validation closure into the phase execution checklist rather than deferring to Phase 14 would be cleaner.

### Patterns Established

- **Release preflight pattern:** `mix hex.build --unpack → metadata gate → release-doc parity gate → install smoke → mix docs --warnings-as-errors` as the canonical pre-publish sequence, invoked both locally and from CI.
- **Parity test with refutation:** Assert both required presence (step names, commands) and prohibited absence (stale/deferred wording) to catch both omission and regression drift.
- **`requirements-completed: [REQ-ID]` frontmatter:** Canonical key for all phase summaries that close a milestone requirement, enabling strict three-source audit cross-checks.
- **Validation closure pattern:** After a phase is verified, flip VALIDATION.md markers from ready/draft to complete by confirming evidence in VERIFICATION.md, then updating frontmatter, Per-Task Map, Wave 0 checklist, and Approval line atomically.

### Key Lessons

- Establish a shared summary frontmatter schema (`requirements-completed:`) and validate it during phase planning, not after audit.
- Build VALIDATION artifact closure into the phase execution checklist — don't leave `wave_0_complete: false` after a phase passes VERIFICATION.
- Audit `tech_debt` status is acceptable at milestone close if the debt is non-blocking, but it reliably generates cleanup work. Tighter metadata hygiene during execution is cheaper than dedicated closure phases.
- Scoped publish automation (protected environment, version gate, CI dry-run) is the right pattern before any broader distribution or protocol work.

### Cost Observations

- Sessions: multiple parallel executor worktrees used in Phases 13 and 14
- Notable: Phase 13 and 14 combined took ~10 minutes of execution time despite representing 4 plans — metadata and documentation closure work is fast when evidence already exists

---

## Cross-Milestone Trends

| Trend | v1.1 | v1.2 |
|-------|------|------|
| Cleanup phases needed | 0 | 2 (Phases 13, 14) |
| Audit status at close | passed | tech_debt (closed) |
| Plans per phase (avg) | 3.0 | 2.2 |
| Phase count | 4 | 5 |
| Files changed | — | 60 |
| Timeline (days) | — | 5 |

**Recurring observation:** Each milestone has ended with some planning artifact debt (stale STATE.md references, incomplete VALIDATION files, metadata inconsistencies). The debt accumulates faster than it is addressed during execution. A milestone-close checklist that explicitly audits these before declaring done would reduce closure phase count.
