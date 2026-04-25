# Rindle OSS DNA Synthesis

## Why this exists

This document captures reusable engineering DNA from your recent Elixir OSS libraries so Rindle starts from proven patterns, not blank-slate opinions.

This is not a historical summary.
It is a practical operating system for decisions.

## Reader + post-read action

- Reader: maintainer running GSD initialization for Rindle.
- Post-read action: choose defaults and constraints for the initial Rindle roadmap that match proven patterns from prior successful libraries.

## DNA Pillars

### 1) Truth has an owner, shape, and timestamp

Across `sigra`, `accrue`, `mailglass`, `threadline`, `rulestead`, `kiln`, `scrypath`, `lockspire`, and `lattice_stripe`, planning succeeds when:

- a single core value is explicit and short
- key decisions are written as constraints, not suggestions
- non-goals are explicit
- state files are treated as operational truth, not notes
- milestone boundaries are archived with integrity

### 2) CI is a contract surface, not "a test runner"

The strongest pattern in your recent libs:

- each CI lane has a named purpose
- merge-blocking vs advisory lanes are explicit
- docs/contract checks are first-class (not optional cleanup)
- release pipelines re-run core quality bars before publish
- post-publish parity checks verify reality, not intent

### 3) Public API discipline beats framework cleverness

Your strongest libraries favor:

- behavior seams (`@behaviour`) before deep coupling
- strict option schemas (`NimbleOptions`) for runtime config and API inputs
- explicit transactional boundaries (`Ecto.Multi` / `Repo.transact`)
- telemetry wrappers with metadata policy
- generated/install surfaces tested by golden/idempotency contracts

### 4) Footguns are named early and encoded in checks

The highest-signal pattern is not "good code"; it is "known failure modes locked in tests, lints, and verify tasks."

## Effective Patterns (Portable to Rindle)

## Effective <Core Value + Decision Ledger>

Use this exact structure at project birth:

- one-sentence core value with operational posture
- key decisions table with rationale and outcome
- explicit non-goals for v0/v1
- "last updated" cadence at real boundaries

Why it works:

- prevents milestone sprawl
- avoids re-litigating decisions during execution
- makes phase planning faster because constraints are already locked

Apply now for Rindle:

- lock "media lifecycle after upload" as the core value
- lock "variants are records" and "processing is idempotent"
- lock "strict security defaults, explicit escape hatches"
- lock "day-2 operations are in scope for v1"

## Effective <Pitfall Ledger as Design Input>

Pattern observed strongly in `mailglass`, `accrue`, `scrypath`, `sigra`:

- maintain explicit pitfall IDs in planning docs
- map each pitfall to controls (code + CI + docs)
- treat pitfall closure as merge-criteria, not post-ship cleanup

Why it works:

- failure history becomes reusable leverage
- avoids repeating known mistakes across milestones

Apply now for Rindle:

- create a Rindle pitfall ledger before phase 1 execution
- include at minimum: lazy-variant abuse, storage cost leaks, orphan upload sessions, purge-in-transaction, MIME spoofing, oversized media bombs, stale recipe drift

## Effective <Atomic Domain Writes + Audit Coupling>

Pattern observed across `sigra`, `accrue`, `mailglass`, `rulestead`:

- state mutation and audit/event writes happen in the same transaction path
- `Ecto.Multi` or `Repo.transact` is the normative write path
- immutable event ledgers are favored where history matters

Why it works:

- prevents "state changed but audit missing" splits
- reduces race-condition surfaces
- keeps event timelines trustworthy for operators

Apply now for Rindle:

- require attach/promote/variant-state transitions to write audit rows in the same transaction
- keep processing-run records immutable except explicit status transitions
- never hide storage side effects inside DB transactions

## Effective <Behavior Seams + Adapter Capability Boundaries>

Pattern observed across `lockspire`, `lattice_stripe`, `scrypath`, `sigra`, `kiln`:

- define behavior contracts at boundaries (storage, processor, scanner, delivery, authz, queue, providers)
- keep defaults strong while leaving extension points explicit
- do not fake parity where providers differ materially

Why it works:

- allows growth without breaking core APIs
- keeps optional integrations from contaminating core dependencies

Apply now for Rindle:

- define storage capabilities explicitly (`presigned_put`, `multipart`, `resumable`, `head`, `copy`, `signed_url`)
- prefer "capability check + clear error" over pretending all backends behave the same

## Effective <NimbleOptions as Public Contract>

Pattern observed strongly in `accrue`, `mailglass`, `sigra`, `rulestead`, `lattice_stripe`:

- schema-driven config validation
- unknown keys fail loudly
- docs generated from schemas where possible
- option validation near the boundary, not deep in handlers

Why it works:

- avoids config ambiguity
- creates stable host integration surfaces
- reduces support burden

Apply now for Rindle:

- validate profile definitions and runtime config via schema
- reserve compile-time config only for true compile-time needs
- avoid scattered `compile_env` reads

## Effective <Telemetry with Explicit Metadata Policy>

Pattern observed across `mailglass`, `sigra`, `accrue`, `rulestead`, `lattice_stripe`, `kiln`:

- wrapper modules around telemetry emission
- spans for operation lifecycles; executes for one-shot counters/signals
- metadata allowlists to prevent PII leakage
- optional OTel bridges without forcing OTel dependency for everyone

Why it works:

- consistent event naming and payload shape
- safer observability for OSS adopters
- easier dashboards and support diagnostics

Apply now for Rindle:

- define event namespace before broad implementation
- ship default metadata allowlist and redaction rules
- include variant/cache miss events and cleanup outcomes

## Effective <CI as Layered Proof>

Pattern observed strongly in `sigra`, `accrue`, `scrypath`, `threadline`, `kiln`, `lattice_stripe`:

- split lanes by responsibility (quality, integration, adopter proof, release contract)
- maintain stable job names/IDs when docs or branch protection depend on them
- run focused verify tasks (phase/task-level) alongside broader suites
- include docs-contract checks and workflow linting

Why it works:

- improves failure triage
- keeps heavy checks scoped
- protects process contracts, not only runtime behavior

Apply now for Rindle:

- define merge-blocking lanes early:
  - quality (`format`, compile warnings-as-errors, tests, credo, dialyzer)
  - docs/contract checks
  - integration (storage + queue + processing)
  - adopter proof (example app flow)

## Effective <Release as Verified Chain>

Pattern observed across `sigra`, `accrue`, `scrypath`, `rulestead`, `lockspire`, `lattice_stripe`:

- release-please (or equivalent) drives version/changelog/tag flow
- publish step is gated from trusted branch/tag context
- dry-run publish before live publish
- post-publish verification checks package parity
- manual recovery workflow exists and is documented

Why it works:

- lowers release-risk and rollback panic
- keeps docs/version/tag/package aligned

Apply now for Rindle:

- set release chain from day one (even pre-1.0)
- include a verify-published-release lane for drift detection
- require explicit publish guardrails (environment reviewers or equivalent policy)

## Effective <Installer and Adopter Truth>

Pattern observed strongly in `sigra`, `accrue`, `scrypath`, `threadline`:

- example host apps are treated as contracts
- installer output is tested by golden-diff + idempotency
- "works in package tests" is not considered sufficient proof

Why it works:

- catches real integration regressions early
- reduces breakage in first-hour onboarding

Apply now for Rindle:

- maintain a canonical Phoenix example app from the start
- add installer/install-task contract tests if generating setup
- keep at least one CI lane that exercises host-like integration path

## Effective <Milestone Honesty and Retrospective Feedback Loop>

Pattern observed strongly in `threadline`, `accrue`, `sigra`, `kiln`, `scrypath`:

- state is updated at milestone/release boundaries, not only at phase close
- retrospective "top lessons" feed directly into next roadmap constraints
- unresolved tooling friction is acknowledged explicitly rather than hidden

Why it works:

- prevents planning drift
- preserves institutional memory
- creates compounding quality over milestones

Apply now for Rindle:

- add "top lessons" section from first milestone onward
- enforce milestone close checklist with evidence references

## Footguns to Avoid (Directly Inherited Lessons)

| Footgun | Why it hurts | Protective pattern |
| --- | --- | --- |
| Compile-time config sprawl (`compile_env` everywhere) | Recompile churn, hidden behavior coupling | Limit compile-time reads to config module boundaries |
| PII in telemetry/log metadata | Security and compliance risk | Metadata allowlists + redaction wrappers + lint checks |
| State writes outside transaction discipline | Partial writes and audit drift | Mandatory `Ecto.Multi` / `Repo.transact` write paths |
| Optional dependency leakage into core | Harder installation and portability regressions | Gateway modules and explicit optional seams |
| Monorepo package version drift | Release confusion and broken dependency pinning | Linked-version release controls + publish guards |
| Publish from untrusted context | Supply-chain and release integrity risk | Protected branch/tag + guarded environment + dry-run |
| Missing docs-contract verification | Runtime/doc divergence for adopters | CI-enforced docs contract checks |
| Installer drift | New adopters get broken setup | Golden-diff + idempotency tests |
| No post-publish parity check | "Published but wrong artifact" blind spot | Verify live package parity against source/tag |
| Unnamed non-goals | Scope creep and design thrash | Explicit non-goals in project manifest |

## Rindle Defaults to Carry Forward

These defaults are recommended for Rindle bootstrap:

- **Scope posture:** image-first implementation on media-agnostic core
- **Data posture:** normalized lifecycle tables, not JSON-only variants
- **Ops posture:** day-2 tasks in v1 (`cleanup_orphans`, `verify_storage`, `regenerate_variants`)
- **Security posture:** strict allowlists, generated keys, signed delivery, scanner hooks
- **Processing posture:** async-first with idempotent jobs, no heavy inline transforms in request path
- **Delivery posture:** named variants by default; dynamic transforms only signed and bounded
- **Release posture:** release-please + guarded publish + post-publish parity
- **Verification posture:** docs contracts + integration proof + host/adopter proof

## Practical "Do This First" Checklist

1. Lock core value, key decisions, and non-goals before phase planning.
2. Create pitfall ledger and map each row to a concrete control.
3. Define behavior contracts for storage/processing/delivery/scanning.
4. Define telemetry namespace + metadata policy before broad instrumentation.
5. Stand up CI lanes with explicit merge-blocking vs advisory policy.
6. Wire release/publish/parity workflows early.
7. Keep one canonical adopter integration path always green.
