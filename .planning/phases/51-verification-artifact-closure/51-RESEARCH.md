# Phase 51: Verification Artifact Closure - Research

**Researched:** 2026-05-25 [VERIFIED: system date]
**Domain:** Retrospective phase-verification artifact closure for shipped Phoenix tus work. [VERIFIED: .planning/phases/51-verification-artifact-closure/51-CONTEXT.md] [VERIFIED: .planning/ROADMAP.md]
**Confidence:** HIGH [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] [VERIFIED: existing `*-VERIFICATION.md` patterns in `.planning/phases/44-*`, `.planning/phases/45-*`, `.planning/phases/46-*`, `.planning/phases/47-*`]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- "This phase was created by `$gsd-plan-milestone-gaps` to close the v1.9 audit gap caused by missing `48/49/50-VERIFICATION.md` artifacts." [VERIFIED: .planning/phases/51-verification-artifact-closure/51-CONTEXT.md]

### Claude's Discretion
- No explicit `## Claude's Discretion` section exists in `51-CONTEXT.md`. [VERIFIED: .planning/phases/51-verification-artifact-closure/51-CONTEXT.md]

### Deferred Ideas (OUT OF SCOPE)
- No explicit `## Deferred Ideas` section exists in `51-CONTEXT.md`. [VERIFIED: .planning/phases/51-verification-artifact-closure/51-CONTEXT.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PHX-01 | Adopter can identify the supported Phoenix tus path from one canonical guide without inferring that the entire LiveView story is still deferred. [VERIFIED: .planning/REQUIREMENTS.md] | Use `48-VERIFICATION.md` to cite `48-01/02-SUMMARY.md`, `48-UAT.md`, `48-VALIDATION.md`, and the current parity lane. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-01-SUMMARY.md] [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-02-SUMMARY.md] [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-UAT.md] [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] |
| TRUTH-01 | Active planning artifacts stop claiming the entire LiveView tus path is deferred when the shipped helper already exists, and instead defer only richer future abstractions explicitly. [VERIFIED: .planning/REQUIREMENTS.md] | Use `48-VERIFICATION.md` to tie active planning/doc parity and archive-disclaimer evidence back to Phase 48. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-02-SUMMARY.md] [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] |
| PHX-02 | Adopter can configure a LiveView upload with `Rindle.LiveView.allow_tus_upload/4` using documented required options and keep completion through `consume_uploaded_entries/3`. [VERIFIED: .planning/REQUIREMENTS.md] | Use `49-VERIFICATION.md` to cite `49-01-SUMMARY.md` plus `test/rindle/live_view_test.exs` evidence already named in Phase 49 validation. [VERIFIED: .planning/phases/49-liveview-tus-productization/49-01-SUMMARY.md] [VERIFIED: .planning/phases/49-liveview-tus-productization/49-VALIDATION.md] |
| PHX-03 | Adopter can drop in a documented `uploader: "RindleTus"` client uploader or hook that reuses the signed `upload_url`, performs resume discovery, and reports byte progress without bypassing tus offset semantics. [VERIFIED: .planning/REQUIREMENTS.md] | Use `49-VERIFICATION.md` to cite `49-02-SUMMARY.md`, current parity assertions, and the canonical guide strings. [VERIFIED: .planning/phases/49-liveview-tus-productization/49-02-SUMMARY.md] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs] [VERIFIED: guides/resumable_uploads.md] |
| PHX-04 | Adopter can render honest UI states that distinguish byte transfer completion from server verification/readiness. [VERIFIED: .planning/REQUIREMENTS.md] | Use `49-VERIFICATION.md` to tie the guide vocabulary and parity tests to Phase 49 ownership. [VERIFIED: .planning/phases/49-liveview-tus-productization/49-02-SUMMARY.md] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs] |
| PROOF-01 | Package-consumer or generated-app proof exercises the documented Phoenix/LiveView tus path end to end, not only a headless tus client against the mounted plug. [VERIFIED: .planning/REQUIREMENTS.md] | Use `50-VERIFICATION.md` to cite `50-01/02-SUMMARY.md`, `50-VALIDATION.md`, and `tmp/install_smoke_tus_last_run.json`. [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-01-SUMMARY.md] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-02-SUMMARY.md] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] [VERIFIED: tmp/install_smoke_tus_last_run.json] |
| PROOF-02 | Docs parity tests freeze the supported LiveView tus contract so drift between guide, helper metadata, and proof harness fails fast. [VERIFIED: .planning/REQUIREMENTS.md] | Use `50-VERIFICATION.md` to cite the fast parity test, local helper test, and persisted proof fields. [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-02-SUMMARY.md] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs] |
</phase_requirements>

## Summary

Phase 51 is a retrospective evidence-packaging phase, not a new Phoenix feature phase. The v1.9 milestone audit found the product path integrated and green in code and tests, but scored requirements `0/7` and phases `0/3` because Phases 48, 49, and 50 have no `48/49/50-VERIFICATION.md` artifacts. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] The planner should therefore treat the primary deliverable as three authoritative phase verification reports that restore the normal audit chain for already-shipped work. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md]

The evidence to populate those reports already exists in four places: plan summaries with `requirements-completed` frontmatter, phase UAT or VALIDATION artifacts, executable parity/unit/integration commands recorded in those artifacts, and the persisted generated-app proof JSON for Phase 50. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-01-SUMMARY.md] [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-02-SUMMARY.md] [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-UAT.md] [VERIFIED: .planning/phases/49-liveview-tus-productization/49-01-SUMMARY.md] [VERIFIED: .planning/phases/49-liveview-tus-productization/49-02-SUMMARY.md] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-01-SUMMARY.md] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-02-SUMMARY.md] [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] [VERIFIED: .planning/phases/49-liveview-tus-productization/49-VALIDATION.md] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] [VERIFIED: tmp/install_smoke_tus_last_run.json]

There is one planning risk that should drive task ordering: the working tree is currently dirty in the exact guide, helper, parity-test, and generated-app proof files that the retrospective reports would cite. The current quick parity lane still passes (`27 tests, 0 failures`), but Phase 51 should begin with a freshness gate before writing closure docs so the reports certify current evidence rather than stale prose. [VERIFIED: `git status --short`] [VERIFIED: `git diff --name-only -- guides/resumable_uploads.md lib/rindle/live_view.ex test/rindle/live_view_test.exs test/install_smoke/generated_app_smoke_test.exs test/install_smoke/support/generated_app_helper.ex test/install_smoke/phoenix_tus_truth_parity_test.exs .planning/STATE.md .planning/milestones/v1.8-ROADMAP.md .planning/research/v1.8/STRATEGY-SEQUENCING.md .planning/research/v1.8/TUS-RESEARCH.md`] [VERIFIED: `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs`]

**Primary recommendation:** Write `48/49/50-VERIFICATION.md` by reusing the established verification-report schema, citing existing shipped evidence by requirement, and gating authorship on a quick freshness rerun of the current parity/helper lane; reserve REQUIREMENTS and `49-VALIDATION.md` reconciliation for Phase 52. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] [VERIFIED: .planning/RETROSPECTIVE.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Per-phase verification authorship | Repository planning artifacts [VERIFIED: existing `*-VERIFICATION.md` files in `.planning/phases/44-*`, `.planning/phases/45-*`, `.planning/phases/46-*`, `.planning/phases/47-*`] | — | Milestone audits explicitly block on missing `48/49/50-VERIFICATION.md`, not on missing app code. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] |
| Requirement-to-evidence mapping | Repository planning artifacts [VERIFIED: .planning/REQUIREMENTS.md] | Test/runtime evidence [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] | The verification reports translate summary/UAT/validation/proof outputs into auditable requirement coverage. [VERIFIED: .planning/phases/47-audit-traceability-metadata-backfill/47-VERIFICATION.md] |
| Freshness confirmation before retrospective closure | Test/runtime evidence [VERIFIED: `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs`] | Repository planning artifacts [VERIFIED: `git status --short`] | Dirty source/proof files make a cheap rerun the safest guard before certifying the evidence chain. [VERIFIED: `git diff --name-only -- guides/resumable_uploads.md lib/rindle/live_view.ex test/rindle/live_view_test.exs test/install_smoke/generated_app_smoke_test.exs test/install_smoke/support/generated_app_helper.ex test/install_smoke/phoenix_tus_truth_parity_test.exs .planning/STATE.md .planning/milestones/v1.8-ROADMAP.md .planning/research/v1.8/STRATEGY-SEQUENCING.md .planning/research/v1.8/TUS-RESEARCH.md`] |
| Final milestone unblock | Milestone audit artifact [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] | Repository planning artifacts [VERIFIED: .planning/ROADMAP.md] | The audit says the blocker is evidence packaging and traceability, not broken Phoenix wiring. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `*-VERIFICATION.md` phase report convention | repo-local convention [VERIFIED: .planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md] [VERIFIED: .planning/phases/45-browser-mux-direct-creator-upload-sibling-droppable/45-VERIFICATION.md] [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md] [VERIFIED: .planning/phases/47-audit-traceability-metadata-backfill/47-VERIFICATION.md] | Authoritative goal-backward closure artifact for each shipped phase. [VERIFIED: cited files] | Existing audits and retrospectives already treat missing verification reports as a blocker. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] [VERIFIED: .planning/RETROSPECTIVE.md] |
| ExUnit via Mix | Elixir 1.19.5 / Mix 1.19.5 / OTP 28 [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] [VERIFIED: `mix --version`] [VERIFIED: `elixir -e 'IO.puts(System.version())'`] | Cheap freshness reruns for parity and helper behavior before retrospective certification. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] | Phases 48-50 already define their verification around these commands. [VERIFIED: cited validation files] |
| Persisted generated-app proof JSON | current artifact schema in `tmp/install_smoke_tus_last_run.json` [VERIFIED: tmp/install_smoke_tus_last_run.json] | Machine-readable evidence for `PROOF-01` and the honest Phoenix state sequence. [VERIFIED: tmp/install_smoke_tus_last_run.json] | It records `phoenix_helper_uploader`, `completion_surface`, and `phoenix_state_sequence` directly, which is stronger than prose-only summary evidence. [VERIFIED: tmp/install_smoke_tus_last_run.json] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phase summaries with `requirements-completed` | repo-local convention [VERIFIED: `rg -n "requirements-completed:" .planning/phases/48-phoenix-dx-contract-truth-audit .planning/phases/49-liveview-tus-productization .planning/phases/50-phoenix-proof-parity-closure`] | Requirement ownership and shipped-scope evidence by plan. [VERIFIED: cited summaries] | Use as the first citation layer inside each verification report. [VERIFIED: .planning/phases/47-audit-traceability-metadata-backfill/47-VERIFICATION.md] |
| `UAT.md` / `VALIDATION.md` | repo-local convention [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-UAT.md] [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] [VERIFIED: .planning/phases/49-liveview-tus-productization/49-VALIDATION.md] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] | Test commands, requirement-to-command mapping, and current execution status. [VERIFIED: cited files] | Use whenever a summary alone would be too prose-heavy or not falsifiable enough. [VERIFIED: cited files] |
| Milestone audit | current file `v1.9-MILESTONE-AUDIT.md` [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] | Defines the exact orphaned requirements and the unblock condition. [VERIFIED: cited audit file] | Use to scope Phase 51 narrowly and avoid Phase 52 metadata work. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Per-phase retrospective verification reports [VERIFIED: .planning/ROADMAP.md] | One Phase 51 mega-report covering all 7 requirements [ASSUMED] | Rejected because the audit explicitly calls for `48-VERIFICATION.md`, `49-VERIFICATION.md`, and `50-VERIFICATION.md`, and prior repo practice is phase-scoped verification. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] [VERIFIED: existing `*-VERIFICATION.md` files] |
| Citing shipped evidence plus targeted freshness reruns [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] [VERIFIED: `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs`] | Blindly rerunning the full milestone from scratch [ASSUMED] | Rejected because the audit says integration and flows already pass `4/4`; the gap is packaging and traceability. Full reruns are valuable only where the dirty working tree touches cited evidence. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] [VERIFIED: `git diff --name-only -- guides/resumable_uploads.md lib/rindle/live_view.ex test/rindle/live_view_test.exs test/install_smoke/generated_app_smoke_test.exs test/install_smoke/support/generated_app_helper.ex test/install_smoke/phoenix_tus_truth_parity_test.exs .planning/STATE.md .planning/milestones/v1.8-ROADMAP.md .planning/research/v1.8/STRATEGY-SEQUENCING.md .planning/research/v1.8/TUS-RESEARCH.md`] |
| Redacted field-level proof citations [VERIFIED: tmp/install_smoke_tus_last_run.json] [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md] | Pasting raw signed upload URLs and full debug blobs into markdown [ASSUMED] | Rejected because Phase 46 already treats the raw signed upload URL as bearer-credential material and proves the lane with safer fields. [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md] |

**Installation:**
```bash
# No new packages are needed for Phase 51.
# Use repo-local tooling and artifacts only.
```

**Version verification:** No new npm packages are recommended for this phase; the stack is the existing repo-local planning/test toolchain. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md]

## Architecture Patterns

### System Architecture Diagram

```text
REQUIREMENTS.md + ROADMAP.md
        |
        v
Phase 48/49/50 summaries -----> UAT / VALIDATION files -----> recorded commands
        |                               |                          |
        |                               v                          v
        |                      current quick reruns         persisted proof JSON
        |                               |                          |
        +-------------------------------+--------------------------+
                                        |
                                        v
                         48/49/50-VERIFICATION.md reports
                                        |
                                        v
                            milestone audit no longer orphaned
                                        |
                                        v
                      Phase 52 reconciles REQUIREMENTS / VALIDATION metadata
```

The critical data flow is evidence-first: requirement scope and success criteria constrain which summary/UAT/validation/proof artifacts are allowed to count, then the verification reports package that evidence for audit consumption. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] [VERIFIED: .planning/phases/47-audit-traceability-metadata-backfill/47-VERIFICATION.md]

### Recommended Project Structure

```text
.planning/
├── phases/
│   ├── 48-phoenix-dx-contract-truth-audit/
│   │   └── 48-VERIFICATION.md
│   ├── 49-liveview-tus-productization/
│   │   └── 49-VERIFICATION.md
│   └── 50-phoenix-proof-parity-closure/
│       └── 50-VERIFICATION.md
├── v1.9-MILESTONE-AUDIT.md
└── REQUIREMENTS.md
tmp/
└── install_smoke_tus_last_run.json
```

Only the three missing verification reports belong in Phase 51 scope; `REQUIREMENTS.md` and `49-VALIDATION.md` reconciliation are already assigned to Phase 52. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md]

### Pattern 1: Retrospective Verification Report
**What:** Write a normal phase-scoped verification report after implementation already shipped, using authoritative evidence from summaries, UAT/VALIDATION, and current command outputs. [VERIFIED: .planning/milestones/v1.5-phases/31-runtime-diagnostics-drift-visibility/31-VERIFICATION.md] [VERIFIED: .planning/milestones/v1.4-phases/28-onboarding-docs-ci-proof/28-VERIFICATION.md]
**When to use:** Use when the audit blocker is a missing `*-VERIFICATION.md` artifact rather than missing product behavior. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] [VERIFIED: cited milestone-phase verification examples]
**Example:**
```markdown
---
phase: 49-liveview-tus-productization
verified: 2026-05-25T00:00:00Z
status: passed
score: 3/3 success criteria verified
requirements_verified: [PHX-02, PHX-03, PHX-04]
verification_method: inline (summary evidence + validation commands + fresh parity rerun)
follow_ups: []
---

# Phase 49: LiveView Tus Productization — Verification Report

## Objective Evidence
- `49-01/02-SUMMARY.md` define the shipped contract and requirement ownership.
- `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs` is green on the current tree.
```
Source pattern: [VERIFIED: .planning/phases/45-browser-mux-direct-creator-upload-sibling-droppable/45-VERIFICATION.md] [VERIFIED: .planning/phases/47-audit-traceability-metadata-backfill/47-VERIFICATION.md]

### Pattern 2: Requirement-Coverage Table Tied to Source Plans
**What:** Include a dedicated table mapping each requirement to the source plan/summary and concrete evidence. [VERIFIED: .planning/milestones/v1.5-phases/31-runtime-diagnostics-drift-visibility/31-VERIFICATION.md] [VERIFIED: .planning/milestones/v1.4-phases/28-onboarding-docs-ci-proof/28-VERIFICATION.md]
**When to use:** Use in all three reports because Phase 51 exists to restore orphaned requirement traceability. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md]
**Example:**
```markdown
| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| PHX-03 | 49-02 | `RindleTus` client reuses signed `upload_url` and resume discovery | ✓ SATISFIED | `49-02-SUMMARY.md`; `phoenix_tus_truth_parity_test.exs`; `guides/resumable_uploads.md` |
```
Source pattern: [VERIFIED: .planning/milestones/v1.5-phases/31-runtime-diagnostics-drift-visibility/31-VERIFICATION.md]

### Pattern 3: Reconciled Verification When Later Evidence Is More Authoritative
**What:** If a later rerun or persisted artifact is stronger than the original phase narrative, say so explicitly in a reconciliation note. [VERIFIED: .planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md] [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md]
**When to use:** Use in `50-VERIFICATION.md` if the planner cites the persisted generated-app JSON or any fresh rerun as the authoritative closure artifact. [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md] [VERIFIED: tmp/install_smoke_tus_last_run.json]
**Example:**
```markdown
## Reconciliation Note

- `50-01/02-SUMMARY.md` remain the shipped scope record.
- `tmp/install_smoke_tus_last_run.json` is the authoritative machine-readable proof for the final package-consumer lane.
```
Source pattern: [VERIFIED: .planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md] [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md]

### Anti-Patterns to Avoid
- **Summary-only closure:** A verification report that only repeats summary prose without listing commands, files, or persisted artifacts will recreate the audit's "orphaned" problem in nicer wording. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] [VERIFIED: .planning/phases/47-audit-traceability-metadata-backfill/47-VERIFICATION.md]
- **Phase-scope leakage into Phase 52:** Updating `.planning/REQUIREMENTS.md` or normalizing `49-VALIDATION.md` inside Phase 51 would blur the separation already locked in the roadmap. [VERIFIED: .planning/ROADMAP.md]
- **Freshness-blind certification:** Certifying guide/helper/proof evidence without acknowledging the currently dirty working tree risks making the reports stale on arrival. [VERIFIED: `git status --short`] [VERIFIED: `git diff --name-only -- guides/resumable_uploads.md lib/rindle/live_view.ex test/rindle/live_view_test.exs test/install_smoke/generated_app_smoke_test.exs test/install_smoke/support/generated_app_helper.ex test/install_smoke/phoenix_tus_truth_parity_test.exs .planning/STATE.md .planning/milestones/v1.8-ROADMAP.md .planning/research/v1.8/STRATEGY-SEQUENCING.md .planning/research/v1.8/TUS-RESEARCH.md`] |
- **Secret-bearing proof dumps:** Do not paste raw signed upload URLs from `tmp/install_smoke_tus_last_run.json`; cite safe fields such as `phoenix_helper_uploader`, `completion_surface`, and `phoenix_state_sequence` instead. [VERIFIED: tmp/install_smoke_tus_last_run.json] [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Retrospective closure report | A new ad hoc Phase 51 artifact schema [ASSUMED] | The existing `*-VERIFICATION.md` report shape already used by Phases 44-47 and earlier milestone closures. [VERIFIED: .planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md] [VERIFIED: .planning/phases/45-browser-mux-direct-creator-upload-sibling-droppable/45-VERIFICATION.md] [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md] [VERIFIED: .planning/phases/47-audit-traceability-metadata-backfill/47-VERIFICATION.md] | The audit engine and repo workflow already understand this shape. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] |
| Phase 50 proof evidence | New bespoke proof harness or synthetic report format [ASSUMED] | `tmp/install_smoke_tus_last_run.json` plus the existing generated-app smoke/parity tests. [VERIFIED: tmp/install_smoke_tus_last_run.json] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] | The machine-readable proof fields already encode the Phoenix helper and state sequence more precisely than prose. [VERIFIED: tmp/install_smoke_tus_last_run.json] |
| Requirement mapping | Manual freeform prose paragraphs only [ASSUMED] | A requirement coverage table keyed by requirement ID, source plan, and evidence. [VERIFIED: .planning/milestones/v1.5-phases/31-runtime-diagnostics-drift-visibility/31-VERIFICATION.md] [VERIFIED: .planning/milestones/v1.4-phases/28-onboarding-docs-ci-proof/28-VERIFICATION.md] | The audit is explicitly requirement-oriented and is currently flagging orphaned IDs. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] |

**Key insight:** Phase 51 should compose authoritative evidence that already exists; it should not invent a new documentation or proof model. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] [VERIFIED: .planning/ROADMAP.md]

## Common Pitfalls

### Pitfall 1: Writing Non-Falsifiable Verification Docs
**What goes wrong:** The report says a phase is "done" but never names the command, test file, or persisted artifact that would let an auditor challenge the claim. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md]
**Why it happens:** The evidence exists in summaries and validation files, so it is tempting to compress everything into narrative. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-02-SUMMARY.md] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-02-SUMMARY.md]
**How to avoid:** Every success criterion and every requirement row should point to a specific summary, validation command, test file, or JSON field. [VERIFIED: .planning/milestones/v1.5-phases/31-runtime-diagnostics-drift-visibility/31-VERIFICATION.md] [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md]
**Warning signs:** Phrases like "evidence exists" appear without file paths or command outputs. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md]

### Pitfall 2: Certifying Drifted Evidence
**What goes wrong:** The report documents the shipped Phase 48-50 state, but the cited guide/helper/proof files have changed since the original green run. [VERIFIED: `git status --short`] [VERIFIED: `git diff --name-only -- guides/resumable_uploads.md lib/rindle/live_view.ex test/rindle/live_view_test.exs test/install_smoke/generated_app_smoke_test.exs test/install_smoke/support/generated_app_helper.ex test/install_smoke/phoenix_tus_truth_parity_test.exs .planning/STATE.md .planning/milestones/v1.8-ROADMAP.md .planning/research/v1.8/STRATEGY-SEQUENCING.md .planning/research/v1.8/TUS-RESEARCH.md`] |
**Why it happens:** Retrospective verification feels like a documentation-only task, so authors skip the quick rerun. [VERIFIED: .planning/RETROSPECTIVE.md]
**How to avoid:** Start Phase 51 with the narrow parity/helper loop, and escalate to the heavier generated-app lane only if Phase 50 proof files changed materially or the quick rerun fails. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] [VERIFIED: `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs`] |
**Warning signs:** `guides/resumable_uploads.md`, `lib/rindle/live_view.ex`, `test/rindle/live_view_test.exs`, or generated-app proof files appear in `git diff --name-only`. [VERIFIED: `git diff --name-only -- guides/resumable_uploads.md lib/rindle/live_view.ex test/rindle/live_view_test.exs test/install_smoke/generated_app_smoke_test.exs test/install_smoke/support/generated_app_helper.ex test/install_smoke/phoenix_tus_truth_parity_test.exs .planning/STATE.md .planning/milestones/v1.8-ROADMAP.md .planning/research/v1.8/STRATEGY-SEQUENCING.md .planning/research/v1.8/TUS-RESEARCH.md`] |

### Pitfall 3: Mixing Verification Closure with Traceability Reconciliation
**What goes wrong:** The phase starts editing requirement checkboxes, traceability tables, and validation frontmatter before the missing verification chain is restored. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md]
**Why it happens:** The audit lists all metadata debt together, but the roadmap split it intentionally into Phase 51 and Phase 52. [VERIFIED: .planning/ROADMAP.md]
**How to avoid:** Keep Phase 51 scoped to the three missing `*-VERIFICATION.md` files and treat REQUIREMENTS/VALIDATION edits as explicit handoff inputs to Phase 52. [VERIFIED: .planning/ROADMAP.md]
**Warning signs:** Tasks mention `REQUIREMENTS.md` checkbox flips or `49-VALIDATION.md` normalization. [VERIFIED: .planning/ROADMAP.md]

### Pitfall 4: Copying Raw Signed URLs into Markdown
**What goes wrong:** Proof artifacts include a signed upload URL; copying it verbatim into markdown leaks bearer-style credential material into long-lived docs. [VERIFIED: tmp/install_smoke_tus_last_run.json] [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md]
**Why it happens:** The JSON artifact contains both safe fields and sensitive fields in one blob. [VERIFIED: tmp/install_smoke_tus_last_run.json]
**How to avoid:** Quote only safe fields already used in Phase 46, such as `failure_mode`, `completion_surface`, `previous_uploads`, `ready_variants`, and `phoenix_state_sequence`. [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md] [VERIFIED: tmp/install_smoke_tus_last_run.json]
**Warning signs:** `phoenix_helper_upload_url` or `upload_url` appears in a draft verification report. [VERIFIED: tmp/install_smoke_tus_last_run.json]

## Code Examples

Verified patterns from repo sources:

### Verification Frontmatter Skeleton
```markdown
---
phase: 48-phoenix-dx-contract-truth-audit
verified: 2026-05-25T00:00:00Z
status: passed
score: 2/2 success criteria verified
requirements_verified: [PHX-01, TRUTH-01]
verification_method: inline (summary evidence + UAT/validation commands + fresh parity rerun)
follow_ups: []
---
```
Source: [VERIFIED: .planning/phases/45-browser-mux-direct-creator-upload-sibling-droppable/45-VERIFICATION.md] [VERIFIED: .planning/phases/47-audit-traceability-metadata-backfill/47-VERIFICATION.md]

### Phase 50 Safe Proof Citation Pattern
```markdown
## Objective Evidence

- `tmp/install_smoke_tus_last_run.json` records:
  - `phoenix_helper_uploader: "RindleTus"`
  - `completion_surface: "consume_uploaded_entries->verify_completion"`
  - `phoenix_state_sequence: ["uploading", "verifying", "ready"]`
```
Source: [VERIFIED: tmp/install_smoke_tus_last_run.json] [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Summary/UAT/validation evidence exists but no phase verification artifact. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] | Every shipped phase is expected to end with a `*-VERIFICATION.md` closure artifact. [VERIFIED: existing `*-VERIFICATION.md` files in `.planning/phases/44-*`, `.planning/phases/45-*`, `.planning/phases/46-*`, `.planning/phases/47-*`] | The gap is explicitly called out in the 2026-05-25 v1.9 audit. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] | Missing verification artifacts orphan requirements even when integration and E2E flows pass. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] |
| Prose-only proof claims. [VERIFIED: older summary-only patterns contrasted by current audit expectations] [ASSUMED] | Machine-readable Phoenix proof fields in `tmp/install_smoke_tus_last_run.json` plus parity tests. [VERIFIED: tmp/install_smoke_tus_last_run.json] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs] | Landed in Phase 50 on 2026-05-25. [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-01-SUMMARY.md] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-02-SUMMARY.md] | `PROOF-01` and `PROOF-02` can be verified from stable fields instead of summary wording alone. [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] [VERIFIED: tmp/install_smoke_tus_last_run.json] |
| Validation artifact drift can remain after a phase is effectively complete. [VERIFIED: .planning/phases/49-liveview-tus-productization/49-VALIDATION.md] [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] | Repo retrospective now states that VALIDATION closure should be updated atomically after verification. [VERIFIED: .planning/RETROSPECTIVE.md] | Documented in the retrospective for v1.2. [VERIFIED: .planning/RETROSPECTIVE.md] | Phase 51 should restore verification first and leave the validation cleanup itself to Phase 52. [VERIFIED: .planning/ROADMAP.md] |

**Deprecated/outdated:**
- Treating the entire Phoenix/LiveView tus story as deferred is outdated active-project truth after Phase 48. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-01-SUMMARY.md] [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-02-SUMMARY.md]
- Treating the v1.9 blocker as a broken Phoenix adopter flow is outdated; the audit says the blocker is evidence packaging and traceability. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A single Phase 51 mega-report would be worse than three phase-scoped reports. [ASSUMED] | Standard Stack / Alternatives Considered | Planner might over-constrain implementation shape, but the audit and roadmap already strongly prefer three reports. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] |
| A2 | Blindly rerunning the full milestone from scratch is unnecessary unless the dirty files affect cited proof surfaces or the quick rerun fails. [ASSUMED] | Standard Stack / Alternatives Considered | Planner might under-rerun and miss a drifted proof lane; mitigate by making the freshness gate explicit and escalating on failure. [VERIFIED: `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs`] [VERIFIED: `git diff --name-only -- guides/resumable_uploads.md lib/rindle/live_view.ex test/rindle/live_view_test.exs test/install_smoke/generated_app_smoke_test.exs test/install_smoke/support/generated_app_helper.ex test/install_smoke/phoenix_tus_truth_parity_test.exs .planning/STATE.md .planning/milestones/v1.8-ROADMAP.md .planning/research/v1.8/STRATEGY-SEQUENCING.md .planning/research/v1.8/TUS-RESEARCH.md`] |
| A3 | Ad hoc or mega-report verification schemas would be less compatible with the repo's audit expectations. [ASSUMED] | Don't Hand-Roll | Planner could miss a viable alternate format, but current repo history and the audit both point to phase-scoped `*-VERIFICATION.md` as the expected interface. [VERIFIED: existing `*-VERIFICATION.md` files] [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] |

## Open Questions (RESOLVED)

1. **How fresh must Phase 50 proof be before `50-VERIFICATION.md` is credible?**
   - What we know: The persisted proof JSON exists, the current quick parity/helper lane is green, and the generated-app proof files are in the dirty working tree. [VERIFIED: tmp/install_smoke_tus_last_run.json] [VERIFIED: `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs`] [VERIFIED: `git diff --name-only -- guides/resumable_uploads.md lib/rindle/live_view.ex test/rindle/live_view_test.exs test/install_smoke/generated_app_smoke_test.exs test/install_smoke/support/generated_app_helper.ex test/install_smoke/phoenix_tus_truth_parity_test.exs .planning/STATE.md .planning/milestones/v1.8-ROADMAP.md .planning/research/v1.8/STRATEGY-SEQUENCING.md .planning/research/v1.8/TUS-RESEARCH.md`] |
   - Resolved rule: Do not rerun `bash scripts/install_smoke.sh tus` by default. First run the quick parity/helper loop for Phase 51. Then rerun the heavy proof lane only when `git diff --name-only` is non-empty for `test/install_smoke/generated_app_smoke_test.exs`, `test/install_smoke/support/generated_app_helper.ex`, `test/install_smoke/phoenix_tus_truth_parity_test.exs`, `guides/resumable_uploads.md`, `lib/rindle/live_view.ex`, or `test/rindle/live_view_test.exs`. [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] [VERIFIED: `git diff --name-only -- test/install_smoke/generated_app_smoke_test.exs test/install_smoke/support/generated_app_helper.ex test/install_smoke/phoenix_tus_truth_parity_test.exs guides/resumable_uploads.md lib/rindle/live_view.ex test/rindle/live_view_test.exs`]
   - Why this is the chosen rule: The quick loop is sufficient for doc/helper drift, while the heavy lane remains the authoritative escalation path when proof-surface files changed materially. [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-02-SUMMARY.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix` | Quick freshness reruns and any optional Phase 50 proof rerun. [VERIFIED: validation files for Phases 48-50] | ✓ [VERIFIED: `mix --version`] | `Mix 1.19.5` [VERIFIED: `mix --version`] | If unavailable, Phase 51 can still draft from existing summaries/UAT/JSON, but freshness confidence drops and should be called out. [VERIFIED: existing summaries/UAT/JSON] |
| `elixir` | ExUnit execution. [VERIFIED: validation files for Phases 48-50] | ✓ [VERIFIED: `elixir -e 'IO.puts(System.version())'`] | `1.19.5` [VERIFIED: `elixir -e 'IO.puts(System.version())'`] | No repo-local fallback beyond citing existing evidence. [VERIFIED: existing summaries/UAT/JSON] |
| `node` | Generated-app/install-smoke proof tooling already used by Phase 50. [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-01-SUMMARY.md] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-02-SUMMARY.md] | ✓ [VERIFIED: `node --version`] | `v22.14.0` [VERIFIED: `node --version`] | Not needed for the quick parity/helper loop. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] |
| `npm` | Node toolchain support for install-smoke environment. [VERIFIED: Phase 50 generated-app proof context] [ASSUMED] | ✓ [VERIFIED: `npm --version`] | `11.1.0` [VERIFIED: `npm --version`] | Not needed unless the heavy generated-app proof is rerun. [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] |
| `rg` | Fast evidence grep for doc/archive truth checks. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-02-SUMMARY.md] [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] | ✓ [VERIFIED: `rg --version`] | `ripgrep 15.1.0` [VERIFIED: `rg --version`] | Use standard shell tools if needed. [ASSUMED] |
| `gsd-sdk` | Optional roadmap/audit queries already used in this repo's planning flow. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-01-SUMMARY.md] | ✓ [VERIFIED: `gsd-sdk --help >/dev/null 2>&1 && echo available`] | available [VERIFIED: `gsd-sdk --help >/dev/null 2>&1 && echo available`] | Direct file reads cover the same data. [VERIFIED: repo files cited throughout] |

**Missing dependencies with no fallback:**
- None identified for planning the phase. [VERIFIED: command checks above]

**Missing dependencies with fallback:**
- None identified for planning the phase. [VERIFIED: command checks above]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix on Elixir 1.19.5. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] [VERIFIED: `mix --version`] [VERIFIED: `elixir -e 'IO.puts(System.version())'`] |
| Config file | `test/test_helper.exs`. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] [VERIFIED: .planning/phases/49-liveview-tus-productization/49-VALIDATION.md] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] |
| Quick run command | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs`. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] [VERIFIED: `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs`] |
| Full suite command | `bash scripts/install_smoke.sh tus` for the heavy proof lane when Phase 50 freshness requires it. [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PHX-01 | Active truth surfaces and canonical guide stay aligned on the supported helper seam. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] | docs parity + unit | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs` [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] | ✅ [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs] [VERIFIED: test/rindle/live_view_test.exs] |
| TRUTH-01 | Active wording and archive disclaimers do not drift back to "fully deferred" shorthand. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] | grep + docs parity | `rg -n 'Historical v1.8 note' ... && mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs` [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] | ✅ [VERIFIED: .planning/milestones/v1.8-ROADMAP.md] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs] |
| PHX-02 | `allow_tus_upload/4` contract, required options, optional actor, and completion lane stay valid. [VERIFIED: .planning/phases/49-liveview-tus-productization/49-VALIDATION.md] | unit | `mix test test/rindle/live_view_test.exs` [VERIFIED: .planning/phases/49-liveview-tus-productization/49-VALIDATION.md] | ✅ [VERIFIED: test/rindle/live_view_test.exs] |
| PHX-03 | `RindleTus` client snippet reuses `upload_url`, resume discovery, and offset-safe semantics. [VERIFIED: .planning/phases/49-liveview-tus-productization/49-VALIDATION.md] | docs parity | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs` [VERIFIED: .planning/phases/49-liveview-tus-productization/49-VALIDATION.md] | ✅ [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs] |
| PHX-04 | Honest `uploading` / `verifying` / `ready` semantics remain explicit. [VERIFIED: .planning/phases/49-liveview-tus-productization/49-VALIDATION.md] | docs parity | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs` [VERIFIED: .planning/phases/49-liveview-tus-productization/49-VALIDATION.md] | ✅ [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs] |
| PROOF-01 | Generated-app proof exercises the documented Phoenix path end to end. [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] | integration | `RINDLE_INSTALL_SMOKE_PROFILE=tus mix test test/install_smoke/generated_app_smoke_test.exs --include minio` or `bash scripts/install_smoke.sh tus` [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] | ✅ [VERIFIED: test/install_smoke/generated_app_smoke_test.exs] |
| PROOF-02 | Guide/helper/proof-report parity and local helper alignment fail fast on drift. [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] | docs parity + unit | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs` and `mix test test/rindle/live_view_test.exs` [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] | ✅ [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs] [VERIFIED: test/rindle/live_view_test.exs] |

### Sampling Rate
- **Per task commit:** `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs`. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-VALIDATION.md] [VERIFIED: `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs`] |
- **Per wave merge:** Reuse the same quick loop unless Phase 50 proof files changed materially; then escalate to `bash scripts/install_smoke.sh tus`. [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] [ASSUMED] |
- **Phase gate:** All three verification reports drafted against green quick-loop evidence; `50-VERIFICATION.md` additionally cites persisted JSON or a fresh heavy rerun if escalation was triggered. [VERIFIED: tmp/install_smoke_tus_last_run.json] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] [ASSUMED] |

### Wave 0 Gaps
- None for test infrastructure; the missing phase artifact is documentation/traceability closure, not missing test files. [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] [VERIFIED: validation files for Phases 48-50]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes [VERIFIED: Phase 48/49/50 Phoenix path involves signed upload metadata and optional actor handling] [VERIFIED: .planning/phases/49-liveview-tus-productization/49-01-SUMMARY.md] | Cite the existing signed helper contract and avoid inventing alternate auth semantics in verification prose. [VERIFIED: .planning/phases/49-liveview-tus-productization/49-01-SUMMARY.md] |
| V3 Session Management | yes [VERIFIED: `session_id` and resumable upload session evidence are part of the Phoenix path] [VERIFIED: tmp/install_smoke_tus_last_run.json] | Use persisted `session_id`/state evidence rather than ad hoc narrative. [VERIFIED: tmp/install_smoke_tus_last_run.json] |
| V4 Access Control | yes [VERIFIED: archive truth and supported-now boundaries are scope-control concerns for adopters] [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-02-SUMMARY.md] | Keep verification language aligned with the supported seam only. [VERIFIED: .planning/ROADMAP.md] |
| V5 Input Validation | yes [VERIFIED: parity tests and helper tests are the locked validation controls for docs/helper drift] [VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-VALIDATION.md] | Reuse ExUnit parity and helper tests as the falsification layer. [VERIFIED: cited validation file] |
| V6 Cryptography | yes [VERIFIED: signed upload URLs and secret-backed proof fields are part of the documented flow] [VERIFIED: guides/resumable_uploads.md] [VERIFIED: tmp/install_smoke_tus_last_run.json] | Never paste raw signed URLs into long-lived docs; cite redacted/safe fields only. [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md] [VERIFIED: tmp/install_smoke_tus_last_run.json] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Verification report overclaims support beyond what tests and proof actually cover. [VERIFIED: truth-alignment requirements and audit language] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] | Tampering | Tie every claim to requirement-scoped evidence and the canonical guide/helper/proof artifacts only. [VERIFIED: validation files for Phases 48-50] |
| Signed upload URL leakage from proof JSON into markdown. [VERIFIED: tmp/install_smoke_tus_last_run.json] | Information Disclosure | Quote safe fields only; follow the Phase 46 redaction posture. [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md] |
| Stale or drifted docs certified as current because the verification report skipped reruns. [VERIFIED: dirty working tree + current green quick loop] [VERIFIED: `git status --short`] [VERIFIED: `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs`] | Repudiation | Run the quick parity/helper loop before authorship and note reconciliation if later evidence is authoritative. [VERIFIED: .planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md] [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md] |

## Sources

### Primary (HIGH confidence)
- `.planning/v1.9-MILESTONE-AUDIT.md` - exact Phase 51 problem statement, orphaned requirement list, and closeout conditions. [VERIFIED: repo file]
- `.planning/ROADMAP.md` - locked Phase 51 and Phase 52 scope split plus success criteria. [VERIFIED: repo file]
- `.planning/REQUIREMENTS.md` - authoritative requirement text for `PHX-01`, `TRUTH-01`, `PHX-02`, `PHX-03`, `PHX-04`, `PROOF-01`, `PROOF-02`. [VERIFIED: repo file]
- `.planning/phases/48-phoenix-dx-contract-truth-audit/48-01-SUMMARY.md`, `48-02-SUMMARY.md`, `48-UAT.md`, `48-VALIDATION.md` - shipped Phase 48 evidence. [VERIFIED: repo files]
- `.planning/phases/49-liveview-tus-productization/49-01-SUMMARY.md`, `49-02-SUMMARY.md`, `49-VALIDATION.md` - shipped Phase 49 evidence. [VERIFIED: repo files]
- `.planning/phases/50-phoenix-proof-parity-closure/50-01-SUMMARY.md`, `50-02-SUMMARY.md`, `50-VALIDATION.md` - shipped Phase 50 evidence and command map. [VERIFIED: repo files]
- `tmp/install_smoke_tus_last_run.json` - machine-readable Phase 50 proof fields. [VERIFIED: repo file]
- `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md`, `.planning/phases/45-browser-mux-direct-creator-upload-sibling-droppable/45-VERIFICATION.md`, `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md`, `.planning/phases/47-audit-traceability-metadata-backfill/47-VERIFICATION.md` - existing verification-report patterns and reconciliation precedent. [VERIFIED: repo files]
- `.planning/milestones/v1.5-phases/31-runtime-diagnostics-drift-visibility/31-VERIFICATION.md`, `.planning/milestones/v1.4-phases/28-onboarding-docs-ci-proof/28-VERIFICATION.md` - retrospective missing-artifact closure precedent. [VERIFIED: repo files]
- `.planning/RETROSPECTIVE.md` - repo lesson that VALIDATION closure should follow VERIFICATION atomically. [VERIFIED: repo file]

### Secondary (MEDIUM confidence)
- `mix --version`, `elixir -e 'IO.puts(System.version())'`, `node --version`, `npm --version`, `rg --version`, `git status --short`, `git diff --name-only ...`, and `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs` - current environment and freshness checks captured during this research session. [VERIFIED: command output]

### Tertiary (LOW confidence)
- None. [VERIFIED: this research relies on repo artifacts and direct command output only]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - The phase uses existing repo conventions, tests, and artifacts rather than uncertain external libraries. [VERIFIED: sources above]
- Architecture: HIGH - The roadmap, audit, and prior verification files agree that the blocker is missing verification artifacts, not product wiring. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md]
- Pitfalls: HIGH - The dirty working tree, audit findings, retrospective notes, and prior reconciled verification reports point to concrete failure modes rather than hypotheticals. [VERIFIED: `git status --short`] [VERIFIED: .planning/v1.9-MILESTONE-AUDIT.md] [VERIFIED: .planning/RETROSPECTIVE.md] [VERIFIED: .planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md] [VERIFIED: .planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md]

**Research date:** 2026-05-25 [VERIFIED: system date]
**Valid until:** 2026-06-24 for repo-local planning conventions unless the phase evidence files change again. [VERIFIED: repo-local scope] [ASSUMED]
