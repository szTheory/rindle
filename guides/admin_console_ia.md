# Admin Console Information Architecture

Rindle Admin is a task-first operations surface, not a decorative dashboard. It helps
maintainers see lifecycle health, inspect stuck work, and run existing repair/destructive
operations deliberately.

## Service Identity

The service name is `Rindle Admin`. Use it consistently in navigation, page titles, and
empty/error states so adopters know they are inside the Rindle-owned console, even when it
is mounted inside their Phoenix application.

The console translates GOV.UK/GDS service navigation into a maintainer/operator context:
clear service identity, obvious task grouping, ordered step-by-step flows only where order
matters, and no decorative dashboard sprawl.

## Top-Level Surfaces

The console has exactly these top-level surfaces:

| Surface | Operator job | Read/action boundary |
| --- | --- | --- |
| `Overview` | See whether Rindle is healthy and what needs attention next. | Read-only summary from `Rindle.Admin.Queries`, `Rindle.Ops.RuntimeStatus`, and Doctor output. |
| `Assets` | Find assets by lifecycle state and inspect detail/timeline. | Read-only query surface over media assets, variants, attachments, and state history. |
| `Upload sessions` | Diagnose stuck, failed, expired, or resumable uploads. | Read-only query surface over upload-session lifecycle state. |
| `Processing` | Inspect ready, stale, failed, cancelled, queued, or missing variants and related work. | Read-only query surface over variants, jobs, and recommendations. |
| `Doctor` | Validate setup, runtime drift, and environment prerequisites. | Read-only doctor/runtime status results first. |
| `Maintenance` | Run repair, erasure, regeneration, quarantine, and lifecycle operations deliberately. | Action surface using existing facade/ops capabilities after diagnostics. |

## Persona And JTBD Map

| Persona | Job to be done | Starts at | Goes deeper |
| --- | --- | --- | --- |
| Maintainer/operator | See if media lifecycle work is healthy before users notice issues. | `Overview` | `Doctor`, `Processing`, then `Maintenance` only if repair is needed. |
| Support engineer | Investigate a user report about missing, delayed, or unsafe media. | `Assets` | Asset detail, upload sessions, variants/jobs, then a scoped action with receipt. |
| Adopter developer | Verify integration wiring, seeds, and demo behavior while developing. | `Doctor` | `Upload sessions`, `Assets`, and deterministic test selectors documented in UI principles. |

## Find Your Job

| When you want to... | You reach for... | Why |
| --- | --- | --- |
| Know whether the installation is healthy | `Overview` | It summarizes blocked work and the next required action. |
| Check environment and runtime prerequisites | `Doctor` | It keeps setup validation separate from repair. |
| Find a specific media asset or lifecycle state | `Assets` | It maps to first-class `MediaAsset` state. |
| Understand upload residue or failed/resumable sessions | `Upload sessions` | It maps to `MediaUploadSession` state. |
| Inspect stale, missing, failed, or processing derivatives | `Processing` | It maps to `MediaVariant` state and Oban-backed runtime findings. |
| Repair lifecycle drift | `Maintenance` | Maintenance stays separated from diagnostics and requires confirmation. |
| Delete one or more owners' Rindle-managed media links | `Maintenance` | Owner erasure and batch erasure require collateral preview and typed confirmation. |

## Diagnostics Before Actions

The console keeps the existing operations split:

- doctor validates setup and drift
- runtime status reports degraded or stuck work
- repair verbs perform change after diagnostics point at the lane

Read surfaces map to `Rindle.Admin.Queries` or existing read models such as
`Rindle.Ops.RuntimeStatus`. Action surfaces map to existing facade/ops capabilities such
as owner erasure, batch erasure, variant regeneration, and lifecycle repair.

Quarantine review is a triage surface over existing quarantined asset state. It may link
to supported deletion or erasure paths where appropriate, but it must not add an
un-quarantine write path or direct row mutation. Current un-quarantine remains a manual
audited exception.

Do not put destructive buttons on status summaries. Status screens may link to the
relevant action flow, but the action itself starts on `Maintenance` with context and
confirmation.

## Surface Details

### Overview

Purpose: show readiness, blocked work, and the next required action.

Content:

- runtime status summary
- doctor pass/fail summary
- counts for assets, upload sessions, variants/jobs, and recommendations
- links to the surface where the operator can investigate

Avoid decorative analytics cards. Show operational state and actionability only.

### Assets

Purpose: help operators find assets by lifecycle state and inspect one asset.

Content:

- lifecycle-state filters
- profile/kind filters
- attachment context
- variant summary
- timeline or state history when available
- links to owner erasure or repair flows only where appropriate

### Upload sessions

Purpose: diagnose incomplete, expired, resumable, failed, or stuck upload work.

Content:

- upload session state
- asset link
- strategy/protocol summary
- expiration and failure reason
- cleanup guidance when residue is expired

### Processing

Purpose: inspect derivative work without making the operator spelunk through Oban.

Content:

- variant state
- recipe drift and storage drift buckets
- failed/cancelled/stale/missing summaries
- recommended repair lane
- job correlation where the implementation can provide it safely

### Doctor

Purpose: keep setup checks and runtime drift visible and read-only.

Content:

- `mix rindle.doctor`-style prerequisite checks
- `Rindle.Ops.RuntimeStatus` read model
- provider-stuck and upload residue findings
- recommended next surface

### Maintenance

Purpose: make existing operations executable with deliberate UX.

Content:

- owner erasure preview and execute
- batch erasure preview and execute
- variant regeneration
- quarantine review as read-only triage plus supported deletion/erasure escalation
- lifecycle repair
- receipts after completion

Destructive action flows must show collateral preview, require typed confirmation, and
name the owner/assets before enabling execution. Owner erasure and batch erasure are
collateral-preview and typed-confirmation flows.

## Query Boundary

`Rindle.Admin.Queries` owns read composition for the console. It may call existing read
models such as `Rindle.Ops.RuntimeStatus`, query first-class domain rows, and normalize
filters for UI consumption.

It must not add public facade convenience reads to `Rindle`. The public `Rindle` facade
continues to expose lifecycle operations; the admin console has its own query namespace.

## Ordered Flows

Use ordered steps only when sequence matters:

1. Diagnose with `Doctor`.
2. Inspect the affected asset/session/variant.
3. Preview collateral impact.
4. Confirm deliberately.
5. Show receipt and next state.

Do not turn independent navigation choices into numbered wizards.

## Implementation Constraints

- Read routes map to these six top-level surfaces.
- Action routes call existing capabilities and keep destructive flows deliberate.
- Browser proofs use stable selectors for these surfaces instead of text-only assertions.
