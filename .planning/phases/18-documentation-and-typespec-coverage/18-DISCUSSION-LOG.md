# Phase 18: Documentation and Typespec Coverage - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `18-CONTEXT.md` — this log preserves the analysis path.

**Date:** 2026-04-30
**Phase:** 18-documentation-and-typespec-coverage
**Mode:** assumptions (with deep parallel research)
**Areas analyzed:** Coverage scope and gaps; named struct types vs opaque returns; `mix doctor` setup; CI integration; documentation patterns by module type; compatibility shim documentation; callback enforcement strategy; plan slicing

## Assumptions Presented (round 1 — codebase analyzer output)

### Coverage scope and gaps
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Asymmetric work — facade + Delivery + 5 schemas already complete; biggest gaps in Broker (no specs), 5 behaviours (no callback docs), Mix tasks (no specs), workers (no `perform/1` doc/spec), HTML, Profile macro | Confident | Direct grep counts on lib/rindle/upload/broker.ex, lib/rindle/storage.ex, lib/mix/tasks/rindle.*.ex, etc. |

### Named struct types
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| All 5 Domain schemas already declare `@type t`; work is tightening *callers'* specs in Rindle facade and Broker; adapter return shapes stay heterogeneous as named local result maps | Confident | media_asset.ex:47, media_attachment.ex:29, etc.; current opaque specs in lib/rindle.ex; storage adapters in s3.ex:14-24 and local.ex:9-17 |

### `mix doctor` setup
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add `{:doctor, "~> 0.22.0", only: [:dev, :test]}`, generate `.doctor.exs` via `mix doctor.gen.config`, strict thresholds, doctor auto-skips `@moduledoc false` modules | Likely | STATE.md line 68 records the version intent; mix.exs:89-90 shows the dep convention pattern |

### CI integration
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Insert `mix doctor --raise` step into `quality` job between credo and tests; matrix-covered for free | Confident | ci.yml lines 78-107 show the quality job order |

### Plan structure
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 5 plans mirroring Phase 17 rhythm: failing harness → named types → behaviours+broker → ops+integrations → closure | Likely | Phase 17 used 5 plans (ROADMAP.md lines 98-102); STATE.md line 69 records RED-only TDD precedent |

### Edge cases
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `mix doctor` may not enforce `@callback` docs; conditional-compile modules need MIX_ENV=test | Likely | live_view.ex:1, html.ex:1 wrapped in `Code.ensure_loaded?`; mix.exs:64 marks `phoenix_live_view` `optional: true` |

## External Research (round 1 — `mix doctor` behavior verification)

Resolved 8 authoritative questions about `:doctor` behavior by reading hex.pm, hexdocs.pm, and the akoutmos/doctor source on GitHub:

- **Q1 — Latest stable:** `0.22.0`. `~> 0.22.0` is correct.
- **Q2 — `@moduledoc false` handling:** **NOT auto-skipped.** Open issue [#67](https://github.com/akoutmos/doctor/issues/67) confirms. Must explicitly populate `ignore_modules:`. **Materially changed assumption.**
- **Q3 — `@doc false` handling:** Exempts from `@doc` coverage but counts toward `@spec` coverage. Verified in `lib/module_report.ex`.
- **Q4 — `@callback` docs:** Doctor does **NOT** analyze callback declarations at all. Only `def`/`defp` AST. `mix docs --warnings-as-errors` also does not catch them. **Confirmed assumption.**
- **Q5 — Threshold defaults:** Doctor's defaults are loose (`min_module_doc_coverage: 40`, `min_overall_*_spec_coverage: 0`). Strict enforcement requires explicit threshold configuration.
- **Q6 — `--raise` semantics:** In 0.22.0 the `System.at_exit` hook already exits non-zero on failure; `--raise` adds a louder Mix.raise message but is otherwise belt-and-suspenders.
- **Q7 — Optional modules:** Conditionally-compiled `Rindle.LiveView`/`Rindle.HTML` only exist when their optional deps are loaded at compile time. `MIX_ENV=test` ensures they're in scope. **Confirmed assumption.**
- **Q8 — Complementary tooling:** No canonical Elixir tool enforces `@callback` docs. Custom Credo check is the closest option; honor-system + ExUnit backstop is the pragmatic alternative.

## Assumptions Presented (round 2 — to user)

After round 1 research, I presented the user with 6 areas of locked assumptions and asked three clarifying questions: (1) callback-doc enforcement strategy, (2) plan slicing count, (3) any other corrections.

The user's response: "for each of these... research using subagents, what is pros/cons/tradeoffs of each considering the example for each approach, what is idiomatic for elixir/plug/ecto/phoenix... lessons learned from other libs/apps in same space even from other languages/frameworks... great developer ergonomics/dx emphasized... think deeply one-shot a perfect set of recommendations... (shift this preference left within GSD as well if possible... except for VERY impactful ones I might actually care about)"

Interpretation: defer decisions to deep research rather than interview-style Q&A. Saved a refinement to `feedback_research_driven_one_shot.md` to make the ecosystem-comparison aspect of the research preference explicit going forward.

## External Research (round 2 — three parallel deep-research subagents)

### Subagent A — Callback doc enforcement strategy

**Reviewed:** Ecto.Adapter, Ecto.Adapter.Queryable, Ecto.Type, Plug, Plug.Session.Store, Plug.Conn.Adapter, Oban.Worker, Oban.Plugin, Broadway.Producer, Broadway.Acknowledger, Tesla.Adapter, Tesla.Middleware, Phoenix.Channel, Phoenix.Endpoint, Phoenix.LiveView, Membrane.Source, Waffle.StorageBehavior; cross-language: Shrine, ActiveStorage::Service, CarrierWave, Django storage, Paperclip; tooling: rrrene/credo, mirego/credo_naming, theblitzapp/blitz_credo_checks, jump_credo_checks, ash_credo, plus 8 others.

**Finding:** Every reference Elixir lib uses honor-system. **Zero** custom Credo checks for `@doc` on `@callback` exist in the ecosystem. `BlitzCredoChecks.DocsBeforeSpecs` is the closest analog and only checks `def`/`defp`, not `@callback`. Ruby/Python/Node peers in the file-upload space are silent on this — no documented "callback docs got out of sync" incidents anywhere.

**Locked recommendation:** Honor-system (D-18) + ExUnit `Code.fetch_docs/1` backstop test (D-19) + single-line CONTRIBUTING note (D-20). Optional Membrane-style callback summaries (D-21).

### Subagent B — Plan slicing strategy

**Reviewed:** Phoenix typespec PRs (#5280, #5312, #5441, #5444), Phoenix "Update typespecs and TODOs" 2022 sweep, Ecto typespec PRs (#4374, #4495), Plug's "Improve callback documentation" #1013, Membrane's moduledoc-handling commits, Doctor's own README. Cross-language: Shopify Sorbet rollout, Notion ESLint ratchet, Mainmatter Lint-to-the-Future, Rust `#[deny(missing_docs)]` adoption (Diesel #563, rust-unofficial patterns), Python PEP 561, Pydantic v1→v2 migration. PR-size literature: dev.to 10-15-files-per-PR consensus.

**Finding:** 5 plans is the right shape, but the failing-CI-as-harness pattern can backfire on subjective coverage thresholds (Sorbet's exact warning). Notion/Sorbet/Lint-to-the-Future all favor "baseline-then-ratchet" — ship the gate at current-state thresholds, ratchet to target later. Phase 17 P01's RED-only worked because the window was 7 minutes; Phase 18 plan 1 → plan 5 will span days, so the same approach would create CI noise.

**Locked recommendation:** 5 plans (D-22), but Plan 18-01 ships baseline thresholds (not target) and a failing **unit test** asserting target thresholds (D-23) — TDD discipline preserved without making CI itself the failing harness. Plan 18-05 ratchets to target. Defensive split clause: 18-04 → 18-04a/18-04b at planning time if file count > 10 (D-25).

### Subagent C — Cross-validation of remaining assumptions

**Reviewed:** 17 real `.doctor.exs` files from Hex libs (akoutmos/doctor, christhekeele/matcha, agentjido/jido, ash_authentication, ash_rate_limiter, prom_ex, naramore/foundation, novuhq/novu-elixir, agoodway/pgflow, jimsynz/cinder); CI workflow precedents (team-alembic/staple-actions, buildkite/test_collector_elixir, ash-project/ash); Mix task patterns (Mix.Tasks.Ecto.Migrate, Mix.Tasks.Phx.New, Mix.Tasks.Hex.Publish, Mix.Tasks.Run); Oban worker patterns (Plausible analytics, getmydia/mydia); behaviour callback patterns (Ecto.Repo, Ecto.Adapter.*, Oban.Worker, Phoenix.Endpoint, Tesla.Adapter); deprecation patterns (Phoenix.Controller's 6+ shims); `__using__/1` patterns (Phoenix.Controller, Phoenix.LiveView, Phoenix.LiveComponent, Ecto.Schema, Oban.Worker, thousand_island, ash_reactor).

**Findings — keep as-is:** Decisions 3 (`ignore_modules:` strategy), 6 (`@doc` immediately before `@callback`).

**Findings — refine:**
- Decision 1 (thresholds): lower spec thresholds to 95/95 (matches `prom_ex` style; avoids per-module exemptions for Mix tasks and `@impl` modules)
- Decision 2 (CI invocation): use `--full --raise` not `--summary --raise` (matches Ash-family canonical action and buildkite usage)
- Decision 4 (named types): three-layer pattern — facade returns schema `t()`, behaviour-level result types on `Rindle.Storage` (Tesla pattern), named multi-key result aliases
- Decision 5 (compatibility shim): add `@deprecated "..."` between `@doc false` and `@spec` (Phoenix.Controller pattern)
- Decision 9 (`__using__/1`): keep `@doc` + `@spec __using__(keyword) :: Macro.t()` (thousand_island pattern); use `keyword` not `any`

**Findings — reconsider:**
- Decision 7 (Mix tasks): **drop `@doc` and `@spec` from `run/1`.** Phoenix, Ecto, Hex, and Elixir core unanimously use `@shortdoc` + `@moduledoc` + `@impl true` only. The `@impl` is the documentation pointer. **Strongest reconsider in the audit.**
- Decision 8 (Oban workers): drop `@doc` from `perform/1` (Plausible pattern). Keep `@spec` only if narrowing return type beyond `Oban.Worker.result()`. Rich `@moduledoc` does the heavy lifting.

## Corrections Made

The user did not select specific corrections from a multiSelect — they delegated to deep research. Subagent C's cross-validation produced 7 specific refinements that were all locked into the final CONTEXT.md without further user interaction:

| Original assumption | Refined to | Source |
|---|---|---|
| 100% across all five doctor thresholds | 100% docs / 95% specs (D-07) | prom_ex precedent + avoiding `@impl` exemption noise |
| `mix doctor --summary --raise` | `mix doctor --full --raise` (D-09) | Ash-family staple-actions canonical |
| Named struct types (single layer) | Three-layer: schema `t()` / behaviour result types / multi-key aliases (D-03/D-04/D-05) | Tesla.Adapter, Ecto.Adapter.Schema, Phoenix typing |
| `@doc false` on shim | `@doc false` + `@deprecated "..."` + `@spec` (D-16) | Phoenix.Controller's 6+ deprecation shims |
| `@spec __using__(any) :: Macro.t()` | `@spec __using__(keyword()) :: Macro.t()` (D-14) | thousand_island, ash_reactor precedents |
| Mix task `@doc` + `@spec` on `run/1` | **Drop both** — `@shortdoc` + `@moduledoc` + `@impl true` only (D-12) | Phoenix, Ecto, Hex, Elixir core unanimous |
| Oban worker `@doc` + `@spec` on `perform/1` | **Drop `@doc`**; `@spec` only if narrowing return (D-13) | Plausible production pattern |
| Plan 18-01 ships target 100% thresholds | Plan 18-01 ships baseline; failing unit test asserts target; Plan 18-05 ratchets (D-22 / D-23) | Sorbet baseline-then-ratchet, Notion ESLint pattern |

## Ecosystem-comparison reference table (locked)

| Decision | Locked pattern | Precedent |
|---|---|---|
| Behaviour callback docs | `@doc` immediately before `@callback`; `@doc since:` for new ones | Phoenix.Endpoint, Ecto.Adapter, Oban.Worker, Tesla.Adapter, Plug.Session.Store |
| Mix task | `@shortdoc` + `@moduledoc` + `@impl true`; no `@doc`/`@spec` on `run/1` | Mix.Tasks.Ecto.Migrate, Phx.New, Hex.Publish, Elixir core's Run |
| Oban worker | rich `@moduledoc` + `@impl Oban.Worker`; drop `@doc` from `perform/1` | Plausible analytics |
| Macro `__using__/1` | `@doc` immediately above; `@spec __using__(keyword()) :: Macro.t()` | Phoenix.Controller, Phoenix.LiveView, thousand_island |
| Compatibility shim | `@doc false` + `@deprecated` + `@spec` | Phoenix.Controller (6+ instances) |
| `ignore_modules:` | regex (`~r/^Inspect\./`, namespace prefixes) + explicit list with comments | ash_authentication, cinder, pgflow, jido |
| `.doctor.exs` thresholds | 100/95/100/95/100 | prom_ex (90/90/90/90/100), one notch stricter |
| CI invocation | `MIX_ENV=test mix doctor --full --raise` | team-alembic/staple-actions, buildkite/test_collector_elixir |
| Callback enforcement | Honor-system + ExUnit `Code.fetch_docs/1` backstop | Universal across Ecto/Phoenix/Oban/Broadway/Tesla/Plug |
| Plan slicing | 5 plans, baseline-then-ratchet, RED-only failing test in plan 1 | Sorbet/Notion/Lint-to-the-Future + Phase 17 P01 rhythm |

## Sources cited across the three deep-research passes

See `<canonical_refs>` in `18-CONTEXT.md` for the full curated reference list. Total external sources reviewed across the three subagents: ~80 unique URLs spanning hex.pm, hexdocs.pm, GitHub source files, ecosystem blog posts, and adoption playbooks.

---

*Mode: assumptions + 3 parallel research subagents (callback enforcement, plan slicing, cross-validation)*
*Total user interactions: 1 (single AskUserQuestion at round 2 boundary)*
*Decisions locked: 26 (D-01 through D-26) plus Claude's Discretion items*
