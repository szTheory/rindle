# Phase 17: API Surface Boundary Audit - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as the primary planning artifact.
> Locked decisions live in `17-CONTEXT.md`.

**Date:** 2026-04-30
**Phase:** 17-api-surface-boundary-audit
**Mode:** assumptions
**Areas analyzed:** public boundary shape, naming/semver posture, observability helper exposure, docs IA and DX
**User interaction surface:** zero blocking questions; research-driven one-shot recommendation flow, honoring the repo's default “agent decides unless genuinely high-impact” preference

## Assumptions Presented

### Public surface architecture
| Assumption | Confidence | Evidence |
|---|---|---|
| Rindle should use a layered public surface rather than either facade-only minimalism or broad documented openness. | Confident | `README.md`, `guides/getting_started.md`, `guides/operations.md`, `guides/profiles.md`, `guides/secure_delivery.md`, `lib/rindle.ex`, `mix.exs` |
| `Rindle` and `Rindle.Profile` should be the first-tier onboarding concepts, with deeper modules documented by tier. | Likely | `lib/rindle.ex` already exposes common lifecycle calls; current docs still teach `Rindle.Upload.Broker` directly |
| Visible docs in ExDoc should be treated as support promise; implementation modules with real `@moduledoc` text are accidental API pressure. | Confident | Many internal modules currently have `@moduledoc` text; ExDoc behavior and Elixir docs guidance support hiding internals |

### Naming and semver
| Assumption | Confidence | Evidence |
|---|---|---|
| Breaking public renames should not land on the published `0.1.x` line unless compatibility is preserved additively. | Confident | `.planning/REQUIREMENTS.md`, `.planning/STATE.md`, `mix.exs` version `0.1.4`, current dependency guidance in `README.md` and `guides/getting_started.md` |
| `verify_completion/2` is the better canonical public name, with `verify_upload/2` retained as a compatibility shim. | Confident | `lib/rindle/upload/broker.ex` uses `verify_completion/2`; `lib/rindle.ex` uses `verify_upload/2`; direct-upload and multipart steps are semantically distinct |
| `complete_multipart_upload/3` should stay unchanged because it names a real transport-specific completion step. | Confident | `lib/rindle.ex`, `lib/rindle/upload/broker.ex`, multipart-specific tests, S3 multipart semantics |

### Observability helper exposure
| Assumption | Confidence | Evidence |
|---|---|---|
| `Rindle.log_variant_processing_failure/3` is accidental public surface, not intentional library capability. | Confident | Only visible internal use is from `store_variant/4` in `lib/rindle.ex`; no guide teaches adopters to call it |
| Telemetry is the right public observability contract; logging helpers belong behind internal modules. | Confident | `guides/background_processing.md`, current worker/ops docs, ecosystem telemetry norms |

### Optional integrations and docs IA
| Assumption | Confidence | Evidence |
|---|---|---|
| `Rindle.LiveView`, `Rindle.HTML`, behaviors, adapters, Mix tasks, and selected maintenance workers should stay public but move to second-tier docs. | Likely | Guides reference these explicitly; they are real extension/operator seams, not incidental helpers |
| `Rindle.Ops.*`, FSM modules, security helpers, config, validators, and internal pipeline workers should be hidden. | Confident | Current code usage patterns, lack of adopter-facing docs need, and low-level implementation nature |

## Research Subagents

### Pascal — boundary and documentation posture
- Recommendation: use a small root facade plus explicitly supported subsystem modules.
- Strongest lesson: facade-only would make the docs dishonest; broad openness would turn implementation namespaces into compatibility promises.
- Key ecosystem references: Elixir docs, ExDoc, Phoenix, Plug, Ecto SQL, Oban, Shrine, Active Storage.

### Kepler — naming and semver strategy
- Recommendation: add `Rindle.verify_completion/2`, keep `verify_upload/2` as compatibility shim, leave `complete_multipart_upload/3` unchanged.
- Strongest lesson: additive replacement first, deprecation second, removal much later is the idiomatic Elixir move.
- Key ecosystem references: Elixir compatibility/deprecation docs, Phoenix/Ecto soft-deprecation practice, AWS multipart semantics.

### Heisenberg — logging helper exposure
- Recommendation: move the implementation behind a hidden module, keep a hidden compatibility shim on `Rindle` in `0.1.x`, and preserve telemetry-first public observability.
- Strongest lesson: `@doc false` on a public module function is not a real boundary; public facades should expose lifecycle capabilities, not internal log helpers.
- Key ecosystem references: Elixir docs, Telemetry, Ecto Repo telemetry, Oban telemetry, OpenTelemetry, Python logging.

### Tesla — layered public surface and docs IA
- Recommendation: strongly layered developer journey with `Rindle` and `Rindle.Profile` first, advanced namespaces documented explicitly by tier.
- Strongest lesson: progressive disclosure beats both flat namespace sprawl and over-minimalism.
- Key ecosystem references: Ecto, Phoenix LiveView uploads, Req, Swoosh, Ash code interfaces, Shrine, Active Storage, ExDoc grouping.

## Corrections Made

None. The research outputs aligned with the repo's standing preference to favor agent-decided, cohesive recommendations unless a truly high-impact ambiguity appears.

## Decision-Making Preference Honored

Per `.planning/STATE.md`:

- **Default:** agent decides discussion/planning details
- **Escalate only for high-impact:** public semver breaks, destructive data/security changes, irreversible infra/cost, major scope shifts
- **Workflow preference:** skip discuss by default when ambiguity is low enough to resolve through research

This discussion followed the same precedent recorded in the Phase 16 discussion artifacts: research-driven, one-shot synthesis with subagents; zero blocking questions; explicit locking of only the decisions that materially affect downstream planning.

## Outcome

The resulting `17-CONTEXT.md` locks:

- a layered public boundary,
- a semver-safe naming posture,
- internalization of the stray logging helper,
- a facade-first documentation strategy,
- and a clear list of module families to keep public vs hide before Phase 18.

---

*Discussion gathered: 2026-04-30*
*Mode: assumptions; 0 user corrections; 4 research subagents*
