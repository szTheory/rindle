# Deferred Items — Phase 96

Out-of-scope discoveries logged during execution (not fixed; pre-existing or outside the current task scope).

## 96-01: default-env `mix compile --warnings-as-errors` fails on pre-existing Mox warnings
- **Found during:** Plan 96-01 verification (Task 1/2)
- **Issue:** `cd examples/adoption_demo && mix compile --warnings-as-errors` exits non-zero in default `:dev` env because `mox` is `only: :test` in `mix.exs`; `AdoptionDemo.MuxCassette` references `Mox.*` and warns. Unrelated to the static `cohort.css` change and pre-dates Phase 96.
- **Why deferred:** Pre-existing failure in an unrelated file (SCOPE BOUNDARY). The CSS edit is static; no-template-breakage was verified via `MIX_ENV=test mix compile --warnings-as-errors` (exit 0).
- **Suggested owner:** whichever phase touches `adoption_demo` Elixir compile hygiene (e.g. guard `MuxCassette` Mox refs behind `Code.ensure_loaded?/1` or move to a test-only module).
