# Phase 120: Adoption Proof & Release Truth - Discussion Log

> **Audit trail only.** Decisions are captured in `120-CONTEXT.md`.

**Date:** 2026-08-09
**Phase:** 120-adoption-proof-release-truth
**Areas discussed:** proof topology, compatibility contract, documentation/release truth, scope fences

---

## Autonomous selections

| Area | Selected decision | Rationale |
| --- | --- | --- |
| Proof topology | Packed generated-app proof is authoritative | It proves the shipped artifact rather than checkout-only behavior. |
| Compatibility | Keep a focused explicit `public` proof | It preserves the supported escape hatch without widening schema support. |
| Documentation | One operational contract across all public surfaces | Prevents divergent instructions around downtime, migration order, and Oban ownership. |
| Scope | Validate completed contracts; do not redesign them | Phase 120 is release proof and truth, not a new migration/routing feature. |

## the agent's Discretion

Plan the smallest dependency-safe vertical slices and reuse existing smoke/demo/doc-parity harnesses.

## Deferred Ideas

None.
