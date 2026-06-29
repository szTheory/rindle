# Phase 108: Coverage single-run - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-06-27
**Phase:** 108-coverage-single-run
**Areas discussed:** Integration/adoption lane coverage strategy, COV-04 documentation target

---

## Lane coverage strategy (integration + adoption-demo)

Context: `v1.21-COVERAGE-SINGLE-RUN.md` locks option (a) `mix coveralls.multiple` as the
mechanism and the `quality`-lane changes. The one open flag it surfaced was whether the
`integration` + `adoption-demo` lanes' redundant coverage JSON should be folded into a
single run (2a) or dropped (2b) — gated on whether any consumer reads those artifacts.
Codebase scout confirmed **no `download-artifact`, no Codecov, no Coveralls.io, no
aggregate-merge consumer** exists in `.github/`.

| Option | Description | Selected |
|--------|-------------|----------|
| Drop redundant JSON (2b) | Integration gate stays plain `mix test`; adoption's standalone `coveralls.json` step deleted. Max `:epipe`-surface reduction. Quality lane still emits coverage JSON. | ✓ |
| Fold into single run (2a) | Convert integration + adoption to `coveralls.multiple` so all three lanes keep emitting `cover/excoveralls.json`. Only if a future Codecov/aggregate consumer is planned. | |
| Mixed | e.g. fold integration but drop adoption. | |

**User's choice:** Drop redundant JSON (2b)
**Notes:** No artifact consumer exists today, so dropping loses nothing. Deferred 2a as a
revisit-if-consumer-introduced path in CONTEXT.md.

---

## COV-04 documentation target

| Option | Description | Selected |
|--------|-------------|----------|
| RUNNING.md (near coverage table) | Document `mix coveralls.multiple --type local --type json --slowest 20` alongside the existing coverage / merge-blocking lane table (RUNNING.md:62). | ✓ |
| CONTRIBUTING / dev guide | Put it in CONTRIBUTING as a contributor workflow step. | |
| Both RUNNING.md + a mix alias | Document in RUNNING.md and add a `mix coveralls.multiple` shortcut alias. | |

**User's choice:** RUNNING.md (near coverage table)
**Notes:** Gate-alone reproduction (`mix coveralls`) stays unchanged and documented too.

---

## Claude's Discretion

- Exact wording of the updated ci.yml invariant comment.
- Exact RUNNING.md phrasing/placement within the coverage section.
- Whether to keep belt-and-suspenders `MIX_ENV=test` prefixes (preferred_envs already supplies it).

## Deferred Ideas

- Re-add coverage JSON to integration/adoption via `coveralls.multiple` (2a) if a Codecov/aggregate consumer is ever introduced.
- `minimum_coverage` threshold enforcement (currently defaults to 0 — no config) — separate decision/phase.
- The remaining single run's broken-pipe `:epipe` race → Phase 109 (EPIPE), not this phase.
