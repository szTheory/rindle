# Deferred Items — Phase 96

Out-of-scope discoveries logged during execution (not fixed; pre-existing or outside the current task scope).

## 96-01: default-env `mix compile --warnings-as-errors` fails on pre-existing Mox warnings
- **Found during:** Plan 96-01 verification (Task 1/2)
- **Issue:** `cd examples/adoption_demo && mix compile --warnings-as-errors` exits non-zero in default `:dev` env because `mox` is `only: :test` in `mix.exs`; `AdoptionDemo.MuxCassette` references `Mox.*` and warns. Unrelated to the static `cohort.css` change and pre-dates Phase 96.
- **Why deferred:** Pre-existing failure in an unrelated file (SCOPE BOUNDARY). The CSS edit is static; no-template-breakage was verified via `MIX_ENV=test mix compile --warnings-as-errors` (exit 0).
- **Suggested owner:** whichever phase touches `adoption_demo` Elixir compile hygiene (e.g. guard `MuxCassette` Mox refs behind `Code.ensure_loaded?/1` or move to a test-only module).

## 96-05: polish-gate focus-visible check hard-codes `--rindle-focus-*` token names
- **Found during:** Plan 96-05 (cohort-styleguide.spec.js running `assertAdminPolish` over `[data-ck-root]`).
- **Issue:** `assertFocusVisibleTokens` reads the expected focus ring from `--rindle-focus-width`/`--rindle-focus-ring`/`--rindle-focus-offset` on the document root. Cohort defines `--ck-focus` (a single token, `outline: 2px solid var(--ck-focus)`), so over the cohort root every focused `.ck-*` control reports an `outlineWidth/Offset/Color … != ""` offender. The cohort focus ring is real and correct — the gate just looks up admin-namespaced token names.
- **Also:** a daisyUI `@layer utilities { .menu { … } }` rule with `outline:none` appears in the page styleSheets scan (shared host chrome), producing one `outline-none-rule` offender unrelated to the `.ck` layer.
- **Why deferred:** This phase runs the polish gate in WARN/report mode (D-96-06); these are reported, not enforced. The warn→fail flip is **Phase 102**.
- **Suggested owner (Phase 102):** generalize the focus-token lookup (accept a per-surface focus-token name set, or read the resolved `:focus-visible` outline against the surface's own tokens) and scope the `outline:none` styleSheets scan to the gate root, before flipping cohort polish to merge-blocking.
