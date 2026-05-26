# Rindle Methodology

These lenses apply across milestone assessment, discuss-phase, plan-phase, and
resume work. Use them to keep Rindle moving in repo-truth order with strong
adopter value and low planning drift.

## Adopter-First Done Lens

**Diagnoses:** Work being ranked by novelty, protocol completeness, or phase
count instead of whether a Phoenix SaaS developer can confidently adopt the
library for the core job it claims to solve.

**Recommends:** Judge scope from the adopter story outward:
- primary job to be done
- real shipped flows
- install/onboarding/docs truth
- operator/admin/diagnostic truth
- proof posture and CI honesty
- support truth and boundary clarity

Classify remaining work as `FOUNDATIONAL`, `IMPORTANT-BUT-NARROW`, or
`LONG-TAIL POLISH`. Stop broadening when the remaining delta is mostly adjacent
or demand-driven.

**Apply when:** Assessing milestone candidates, discussing phase scope,
deciding whether a wedge is core vs optional, or estimating how close the
library is to "done enough."

## Repo-Truth Evidence Ladder

**Diagnoses:** Planning/docs drift, stale milestone rankings, or decisions made
from a single aspirational artifact.

**Recommends:** Use this evidence order:
1. shipped code, tests, install-smoke, examples
2. active planning state
3. archived milestones and phase artifacts
4. prompts and framing docs

If sources disagree, say so explicitly, lower confidence, and preserve the
correction in durable planning surfaces instead of silently choosing the nicer
story.

**Apply when:** Milestone ranking, requirement validation, support-truth
questions, or any time docs and code appear to disagree.

## Research-First Recommendation Lens

**Diagnoses:** Re-asking the maintainer to arbitrate routine choices, or
producing broad option menus without a clear recommendation.

**Recommends:** Read local research, prompts, prior learnings, and open threads
before asking for direction. When multiple serious wedges or approaches exist,
research them in parallel, compare pros/cons/tradeoffs concretely, then return
one coherent recommendation set. Escalate only for high-blast-radius decisions
with no clear winner after narrowing.

**Apply when:** Milestone-boundary assessment, discuss-phase assumptions,
phase planning, or architecture choices with multiple viable local options.

## Narrow-Then-Escalate Lens

**Diagnoses:** Discuss sessions that surface too many choices too early, or
planning loops that ask the maintainer to resolve reversible local details that
research should have collapsed already.

**Recommends:** Treat discussion as a narrowing pass, not an option dump.

- read local truth and relevant prompts first
- research ecosystem norms and successful prior art where the repo alone is not
  enough
- compare the real candidate approaches with explicit pros/cons/tradeoffs
- return one recommendation set that fits Rindle's architecture, DX posture,
  and least-surprise goals
- escalate only when semver, destructive semantics, security/compliance
  boundary, recurring cost, or milestone/scope shape is materially at stake

Do not reopen wording, helper shape, local abstractions, or other reversible
ergonomic choices once research has produced a clear winner.

**Apply when:** Discuss-phase, plan-phase, support-truth decisions, public API
shape, and docs-contract work.

## Idiomatic Elixir And Least-Surprise Lens

**Diagnoses:** Clever abstractions, framework-shaped drift, or API/design
choices that fight Phoenix / Plug / Ecto conventions.

**Recommends:** Prefer:
- explicit contracts over magical indirection
- additive, composable surfaces over platform sprawl
- Phoenix / Plug / Ecto idioms over custom framework behavior
- honest capability/support truth over optimistic abstractions
- DX that is obvious from docs, types, naming, and failure modes

Steal proven patterns from successful libraries only when they fit Rindle's
scope and existing architecture cleanly.

**Apply when:** Designing public APIs, provider boundaries, lifecycle jobs,
upload surfaces, docs, or operator tooling.

## Durable Planning Memory Lens

**Diagnoses:** Re-deriving prior conclusions, losing investigations between
milestones, or burying high-value lessons in transient phase chatter.

**Recommends:** Before planning new work, read the most relevant:
- `prompts/` research/context files
- `.planning/threads/`
- recent phase `RESEARCH`, `SUMMARY`, `VERIFICATION`, and `LEARNINGS`

When new truth emerges, store it only in existing durable surfaces:
- `STATE.md` for current position, blockers, ordering notes
- `PROJECT.md` for durable scope/priority/boundary truth
- `threads/` for cross-session investigations
- an existing `LEARNINGS.md` only when there is a clearly relevant phase home

Prefer consolidation over duplication.

**Apply when:** Starting a milestone, discussing a phase, pausing/resuming
work, or closing investigations.

## Diminishing-Returns Gate

**Diagnoses:** Overbuilding after the core adopter story is already real.

**Recommends:** Prefer the single highest-leverage remaining wedge that:
- strengthens the core lifecycle mission
- serves many adopters, not edge specialists
- builds on shipped primitives instead of opening a new platform axis
- improves truth, proof, or operational confidence where it still matters

Deprioritize work that is mainly protocol completeness, second-provider
breadth, richer convenience abstractions, or polish unless adopter demand or
support burden makes it the obvious next move.

**Apply when:** Ranking the next 3-5 wedges, deciding whether to start another
milestone, or evaluating whether the project is near done.
