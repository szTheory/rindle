# Phase 48: Phoenix DX Contract + Truth Audit - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `48-CONTEXT.md` and are authoritative.

**Date:** 2026-05-25
**Phase:** 48-phoenix-dx-contract-truth-audit
**Areas discussed:** Canonical Phoenix story location, Support-claim strength, Deferred terminology cleanup, Rewrite scope for truth alignment

---

## Canonical Phoenix story location

| Option | Description | Selected |
|--------|-------------|----------|
| Keep the canonical story in `guides/resumable_uploads.md`, with `Rindle.LiveView` as a thin pointer/reference layer | Single operational source of truth for router, parser, CORS, JS uploader, helper seam, and verification lane | ✓ |
| Create a separate Phoenix-specific guide and make it canonical | Phoenix landing page, but duplicates the already-working guide and increases drift risk | |
| Make `Rindle.LiveView` moduledoc / API docs the canonical source | Better API discoverability, but poor fit for the full cross-cutting setup story | |

**User's choice:** Discuss all with subagent-backed research; final recommendation accepted into context as the locked default.
**Notes:** The synthesized recommendation favored a guide-first posture consistent with Phoenix / ExDoc norms and least-surprise DX.

---

## Support-claim strength

| Option | Description | Selected |
|--------|-------------|----------|
| Supported Phoenix / LiveView tus integration | Strong headline, but overclaims the current seam as a broader maintained abstraction | |
| Experimental / beta LiveView tus integration | Safest semver posture, but undersells already-shipped value and creates awkward “when does beta end?” drift | |
| Supported tus edge; LiveView seam documented as convenience-only narrow helper contract | Support-honest middle ground that matches the shipped code and leaves room for richer future abstractions | ✓ |
| Bare `TusPlug` only supported; LiveView helper effectively outside support | Maximum protection, but contradicts shipped first-party docs/code | |

**User's choice:** Discuss all with subagent-backed research; final recommendation accepted into context as the locked default.
**Notes:** The selected posture explicitly supports the narrow helper path without claiming a full Phoenix-owned uploader abstraction.

---

## Deferred terminology cleanup

| Option | Description | Selected |
|--------|-------------|----------|
| Keep saying “LiveView tus uploader component” is deferred | Legacy shorthand, but now misleading | |
| Replace it with “reusable uploader UI/component abstractions beyond the supported helper path” | Better wording, but still only one half of the real split | |
| Defer only a “standalone tus JS client package” | Too narrow by itself | |
| Explicit split between shipped supported contract and deferred UI kit / JS package work | Precise support boundary and least-surprise wording | ✓ |

**User's choice:** Discuss all with subagent-backed research; final recommendation accepted into context as the locked default.
**Notes:** The selected recommendation cleanly separates the shipped helper contract from future reusable UI/package ownership.

---

## Rewrite scope for truth alignment

| Option | Description | Selected |
|--------|-------------|----------|
| Active artifacts only; leave archives verbatim | Preserves history, but stale archive wording still pollutes repo search | |
| Active artifacts rewrite + explicit archive disclaimers/cross-links | Best balance of support truth and historical integrity | ✓ |
| Retroactively rewrite historical research/context docs to match shipped truth | Highest textual consistency, but damages historiography and archive trust | |

**User's choice:** Discuss all with subagent-backed research; final recommendation accepted into context as the locked default.
**Notes:** The selected posture keeps active truth clean while preserving archived milestone artifacts as historical records with clarifying banners.

---

## the agent's Discretion

- Exact support-copy phrasing within the locked boundary.
- Exact archive-banner format and placement.
- Exact cross-link wording between `Rindle.LiveView` docs and `guides/resumable_uploads.md`.

## Deferred Ideas

- Rich reusable uploader UI / component abstractions beyond the supported helper seam.
- A Rindle-owned standalone tus JS client package.
- Broader Phoenix upload abstractions beyond the current narrow tus helper contract.
