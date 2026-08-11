# Phase 115: Versioning & README Positioning - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md - this log preserves the alternatives considered.

**Date:** 2026-07-01
**Phase:** 115-versioning-readme-positioning
**Areas discussed:** pre-answered documentation contract, scope boundaries

---

## Pre-Answered Documentation Contract

| Option | Description | Selected |
|--------|-------------|----------|
| Ask new user questions | Run the default interactive gray-area loop for README/versioning decisions. | |
| Use locked research and UI-SPEC | Treat the roadmap, requirements, research, and approved UI-SPEC as sufficient context. | yes |
| Skip context generation | Leave planning to infer decisions from research and UI-SPEC directly. | |

**User's choice:** User invoked `$gsd-discuss-phase 115`. No follow-up question was asked because the approved UI-SPEC says: "Do not add new user questions for this phase."

**Notes:** The phase is already narrowed to a docs-only implementation: shared stability sentence, versioned upgrade guide, image-first README path, and "when not to use" boundary. The context records those decisions for downstream agents rather than re-opening them.

---

## Scope Boundaries

| Option | Description | Selected |
|--------|-------------|----------|
| Docs and docs parity only | Edit README, CONTRIBUTING, upgrading guide, and docs parity tests within Phase 115 scope. | yes |
| Pull Phase 116 migration docs forward | Mention future `Rindle.Migration.up/1` / `down/1` APIs before the module exists. | |
| Change runtime behavior for libvips-free image processing | Expand beyond docs to alter image promotion/probing semantics. | |

**User's choice:** Pre-existing roadmap, requirements, research, and UI-SPEC constraints selected the docs-only boundary.

**Notes:** The key planning risk is overclaiming. README can lead with an original-only first attachment path, but it must not claim that complete background image processing is libvips-free under current implementation.

---

## Claude's Discretion

- Exact prose around the locked headings and transitions.
- Exact docs parity test structure.
- Exact local placement of the README boundary section, as long as it remains visible before the final guide links or near positioning.

## Deferred Ideas

- Phase 116 migration API and install/upgrade rewrite.
- v1.23 schema isolation flip.
- Any code change needed to make a complete image lifecycle truly libvips-free.
