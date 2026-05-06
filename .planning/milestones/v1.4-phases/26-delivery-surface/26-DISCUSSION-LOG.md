# Phase 26: Delivery Surface - Discussion Log (Delegated Research Mode)

> **Audit trail only.** Do not use as input to planning, research, or
> execution agents.
> Decisions are captured in `26-CONTEXT.md`.

**Date:** 2026-05-05
**Phase:** 26-delivery-surface
**Mode:** delegated research synthesis
**Areas analyzed:** streaming URL surface, local dev playback path, download
filename posture, TTL + telemetry

## Assumptions Presented

### Streaming URL Surface
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| `streaming_url/3` should be a separate additive wrapper, not a shape-shift on `url/3` | Confident | `.planning/research/v1.4/DELIVERY-DX.md`, `.planning/research/v1.4/SYNTHESIS.md`, `lib/rindle/delivery.ex`, `lib/rindle/html.ex` |

### Local Development Delivery
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Local AV playback parity should be solved by a narrow `Rindle.Delivery.LocalPlug`, not by mutating storage adapter URL semantics | Confident | `.planning/research/v1.4/DELIVERY-DX.md`, `lib/rindle/storage/local.ex`, `lib/rindle/delivery.ex` |

### Download Filenames
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Download filenames should be explicit at delivery time and sanitized by the library; container metadata is never a trusted source | Confident | `.planning/research/v1.4/FOOTGUNS.md`, `.planning/PROJECT.md`, Phase 24 context metadata trust model |

### TTL and Telemetry
| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Keep one profile-level TTL in code for v1.4 and add only additive delivery telemetry around the new seam | Likely | `.planning/research/v1.4/DELIVERY-DX.md`, `lib/rindle/delivery.ex`, `lib/rindle/profile.ex`, telemetry contract tests |

## Delegated Research Results

### Streaming URL Surface
- Subagent recommendation: add `streaming_url/3` wrapper delegating to `url/3`
  in v1.4 and returning `%{url, kind, mime}`.
- Key lesson: additive named API is less surprising in Elixir/Phoenix than
  mutating `url/3` into a polymorphic return contract.

### Local Development Delivery
- Subagent recommendation: ship `Rindle.Delivery.LocalPlug` in core.
- Key lesson: keep storage adapters filesystem/object-store-focused; keep HTTP
  range-serving in a delivery-layer Plug.

### Download Filenames
- Subagent recommendation: explicit filename/disposition API with RFC 5987
  sanitization; never infer from untrusted container metadata.
- Key lesson: least surprise and security both favor explicit caller intent with
  library-owned sanitization.

### TTL and Telemetry
- Subagent recommendation: keep profile-level TTL and add
  `[:rindle, :delivery, :streaming, :resolved]`; one subagent argued against
  making `:range_request` a public contract because it is local/dev-heavy.
- Resolution in synthesis: keep `:range_request` anyway because AV-04-06 locks
  it, but scope/document it narrowly as a `LocalPlug` event.

## Corrections Made

None. The user asked for deep subagent research and coherent one-shot
recommendations rather than an interactive option-by-option review.

## Preference Update Captured

- Reinforced project preference: research first, delegate when helpful, choose
  coherent defaults, and escalate only for very impactful decisions.
