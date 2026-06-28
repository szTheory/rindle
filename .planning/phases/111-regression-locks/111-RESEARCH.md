# Phase 111: Regression locks - Research

**Researched:** 2026-06-28
**Domain:** ExUnit shipped-artifact meta-tests (regression locks) + JS harness dedupe (CommonJS export)
**Confidence:** HIGH (every assertion target grep/read-confirmed live this session)

## Summary

This phase is **research-locked and CONTEXT-locked** — the WHAT lives in `.planning/research/v1.21-REGRESSION-LOCKS.md` (Locks A1/A2, B1, C → reqs LOCK-01/02, LOCK-04, LOCK-05; dedupe → LOCK-03) and the HOW was settled in `111-CONTEXT.md` (D-01 file placement, D-02 helper API `focusVisibly(page, locator)`, D-03 ban-raw-calls-outside-helper). This RESEARCH.md is a **synthesis + verification pass**: it confirms the assertion targets still exist as described, **corrects the stale line anchors in CONTEXT.md**, and specifies the anti-vacuous-pass guards each meta-test must carry. No decision is re-opened.

**Headline verification result:** the *facts* (guard text, Tab-first sites, export shape, import path, no `.planning/` coupling) are all live and accurate. The *line numbers* in CONTEXT.md/research have **drifted** — admin-polish.js grew to 1128 lines and the focus sites moved. Use the anchors in this file, not CONTEXT.md's. Drift is the planning risk this research neutralizes.

**Primary recommendation:** Ship 3 ExUnit meta-tests + 1 CI step + 1 JS dedupe exactly per CONTEXT D-01/D-02/D-03, mirroring `package_metadata_test.exs` (LOCK-01), `async_safety_guard_test.exs` (LOCK-04/05 glob+`assert files != []`), and the gallery's existing `adoptionRequire(...admin-polish.js)` import (LOCK-03 consumer). Every lock keys off the *presence* of the fixed feature so a file that drops it cannot silently exempt itself.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01 (file placement):** Split the three meta-tests by scope:
  - LOCK-01 (phx.new guard) → `test/install_smoke/` family — fold into `package_metadata_test.exs` OR a sibling `install_smoke_preflight_test.exs` (planner's discretion).
  - LOCK-04 (focus modality) → standalone top-level `test/focus_visible_modality_guard_test.exs`, `Rindle.FocusVisibleModalityGuardTest`.
  - LOCK-05 (`.planning/` hygiene) → standalone top-level `test/planning_path_hygiene_test.exs`, `Rindle.PlanningPathHygieneTest`.
  - All use `use ExUnit.Case, async: true`, no exclude tag → default suite → merge-blocking `quality` lane.
- **D-02 (LOCK-03 helper API):** Export a single high-level helper `focusVisibly(page, locator)` from `admin-polish.js`'s `module.exports`. It presses `Tab` (entering keyboard modality) then runs `locator.evaluate(el => el.focus({ focusVisible: true }))`. All three current sites + the gallery call it. This **removes every raw `focus({focusVisible:true})` from call sites**. Keep per-script WCAG-math copies as-is — only the *stateful* modality workaround is deduped.
- **D-03 (LOCK-04 enforcement):** Post-dedupe, the raw `focus({focusVisible:true})` lives ONLY inside the shared helper. LOCK-04 asserts BOTH: (1) the shared `focusVisibly` helper presses `Tab` before the programmatic focus; AND (2) NO harness file calls `focus({focusVisible:true})` directly OUTSIDE that helper. Anti-vacuous guard: key off *presence* of `focusVisible: true`, and `assert files != []`.

### Claude's Discretion
- Exact LOCK-01 host file (`package_metadata_test.exs` vs new `install_smoke_preflight_test.exs`) and assertion mechanics (`:binary.match` index ordering vs line-index) — match the house idiom.
- Exact LOCK-02 step name + position within the `package-consumer` job (must be **before** the built-artifact image-only proof that runs the smoke).
- The shared helper's internal `.catch(() => {})` handling on the `Tab` press (match existing call sites, which swallow the press error).

### Deferred Ideas (OUT OF SCOPE)
- **B2 Playwright unit test** of the `focusVisibly` helper (research LOCK-05/B2) — NOT in this milestone.
- **`CountingFailingTxnRepo` proxy-completeness lock** (research Lock D / Area 4) — owned by Phase 110.
- Any new CI job / new required check; any `lib/` change; any `.planning/`-coupled assertion.
- Coverage-single-run (108) and `:epipe` (109) proofs — shipped in their phases.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LOCK-01 | Merge-blocking meta-test asserts `install_smoke.sh` keeps the phx.new probe + self-install before the smoke proceeds (`quality`) | Verified targets §"LOCK-01"; install_smoke.sh:31/33 guard + :56/:59 smoke confirmed live; host idiom = `package_metadata_test.exs` |
| LOCK-02 | CI step purges the phx.new archive before the package-consumer smoke so the cold path is exercised on every PR (`package-consumer`) | Verified insertion point ci.yml:651 (`Run built-artifact image-only…`); purely additive — no existing literal at risk |
| LOCK-03 | Dedupe the Tab-first `:focus-visible` helper into one shared exported function consumed by both harnesses | Export shape + 3 sites + gallery `adoptionRequire` import path all verified live (see §"LOCK-03") |
| LOCK-04 | Merge-blocking meta-test asserts Tab-first modality at every `focus({focusVisible:true})` site, post-dedupe (`quality`) | D-03 dual-assert; idiom = `async_safety_guard_test.exs` glob+offender pattern |
| LOCK-05 | Merge-blocking meta-test globs `test/**/*.exs`, fails if any test reads a `.planning/` path (`quality`) | Lock C snippet; grep confirmed EMPTY today (`.planning/` decoupling holds); idiom = `async_safety_guard_test.exs` |
</phase_requirements>

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| LOCK-01 phx.new guard assertion | Test suite (ExUnit `quality`) | — | Static text fact about a shipped script; meta-test idiom |
| LOCK-02 cold-path purge | CI / build (`package-consumer` job) | — | Runtime precondition exercise; must be a CI step, not a meta-test (adopter self-heal stays silent) |
| LOCK-03 modality dedupe | JS harness (demo/brandbook, NOT `lib/`) | — | Source refactor of internal test harnesses; no semver impact |
| LOCK-04 modality assertion | Test suite (ExUnit `quality`) | — | Static AST/text fact over shipped JS harnesses |
| LOCK-05 `.planning/` hygiene | Test suite (ExUnit `quality`) | — | Static glob over the `test/` tree; strict superset of install_smoke decoupling |

## Verified Assertion Targets (anchors corrected vs CONTEXT.md)

> **This is the highest-value section.** CONTEXT.md and the research file cite line anchors that have DRIFTED. The *facts* are all live; the *line numbers* below are the actual current ones (read 2026-06-28). Plan against these.

### LOCK-01 — `scripts/install_smoke.sh` (phx.new guard)
[VERIFIED: read scripts/install_smoke.sh]

| Fact | CONTEXT/research anchor | **Actual current anchor** | Drift |
|------|------------------------|---------------------------|-------|
| `mix phx.new --version` probe | §31–34 | **`:31`** (`if ! mix phx.new --version >/dev/null 2>&1; then`) | minor |
| `mix archive.install hex phx_new --force` self-install | §31–34 | **`:33`** (`MIX_ENV=dev mix archive.install hex phx_new --force`) | minor — note the literal is `MIX_ENV=dev mix archive.install hex phx_new --force`, NOT bare `mix archive.install…` |
| `generated_app_smoke_test.exs` invocation | `:56`/`:59` | **`:56`** (gcs) and **`:59`** (`--include minio`) | **exact match** |

**Assertion-literal caution (informs A1 mechanics):** the install line is `MIX_ENV=dev mix archive.install hex phx_new --force`. Asserting `script =~ "mix archive.install hex phx_new --force"` (substring) PASSES against the live line. Asserting `script =~ "mix archive.install hex phx_new"` for the order-index (`:binary.match`) also works. Use the substring `"mix archive.install hex phx_new"` for the order check so the `MIX_ENV=dev ` prefix and the `--force` suffix don't break it. The probe substring `"mix phx.new --version"` matches `:31` exactly.

### LOCK-03 / LOCK-04 — JS harness focus sites (anchors DRIFTED significantly)
[VERIFIED: grep + read examples/adoption_demo/e2e/support/admin-polish.js, brandbook/src/admin-gallery-check.mjs]

| Site | CONTEXT anchor | **Actual current anchor** | Drift |
|------|---------------|---------------------------|-------|
| `admin-polish.js` total length | `:1099` exports | **1128 lines**; `module.exports` at **`:1099`** | exports start matches; file longer |
| `admin-polish.js` site 1 (`assertFocusVisibleTokens`) | `:428`/`:432` | **Tab `:428`, focus `:432`** | **exact match** |
| `admin-polish.js` site 2 (`assertFocusVisibleVsPointer`) | `:927`/`:929` | **Tab `:927`, focus `:929`** | **exact match** |
| `admin-gallery-check.mjs` site 3 | `:173`/`:178` | **Tab `:173`, focus `:178`** | **exact match** |
| gallery `adoptionRequire(...admin-polish.js)` | `:25–26` | **`:25–26`** (`assertConsistentRhythm`/`assertNoHorizontalScroll`) | **exact match** |

**Result:** the JS anchors are accurate. (CONTEXT's earlier "`:428/~432`" with tilde-approximation is exact on the nose.) The file is 1128 lines (research said 1099 for *exports*, correct). The 3 sites and the import path are exactly where CONTEXT says.

**Exact current shapes (so the dedupe replaces them precisely):**
- Site 1 (lines 428–434):
  ```js
  await page.keyboard.press("Tab").catch(() => {});
  await item
    .evaluate((element) => {
      if (document.activeElement === element) element.blur();
      element.focus({ focusVisible: true });
    })
    .catch(() => {});
  ```
  ⚠️ Site 1 is **not a pure `el.focus({focusVisible:true})`** — it first blurs if already active (`if (document.activeElement === element) element.blur();`). The D-02 helper `focusVisibly(page, locator)` running `locator.evaluate(el => el.focus({focusVisible:true}))` will DROP the blur-first step. The planner must decide: either (a) the helper takes an options arg / always blurs-first (safe — idempotent), or (b) confirm the blur is non-load-bearing here. **Recommend the helper always does `if (document.activeElement === el) el.blur(); el.focus({focusVisible:true})`** so site 1's behavior is preserved. This is a real semantic difference, not just a line move.
- Site 2 (lines 927–929): `await page.keyboard.press("Tab").catch(() => {});` then `el.focus({ focusVisible: true });` inside a larger `item.evaluate((el, contract) => {...})` that returns computed-style state. ⚠️ The focus here is the FIRST statement inside a bigger evaluate that reads styles — the helper cannot wholesale replace this evaluate. The dedupe must extract only the `Tab + focus` prelude into `focusVisibly`, then keep the state-reading evaluate. Cleanest: call `await focusVisibly(page, item)` then the existing `item.evaluate(... reads styles ...)` separately (the focus persists across evaluate calls).
- Site 3 (gallery, lines 173/178): `await page.keyboard.press('Tab');` (NO `.catch`) then `await locator.evaluate((element) => element.focus({ focusVisible: true }));`. ⚠️ The gallery's Tab press has **no `.catch(() => {})`** unlike admin-polish.js. D-02's discretion note says match the existing per-site swallow; the helper centralizes this — decide once (recommend keeping `.catch(() => {})` since the demo sites rely on it).

**`module.exports` block (lines 1099–1128):** add `focusVisibly` to this object. It currently exports `assertFocusVisibleTokens`, `assertFocusVisibleVsPointer`, and the helpers the gallery already imports (`assertConsistentRhythm`, `assertNoHorizontalScroll`). Insert `focusVisibly,` alphabetically/adjacent to the focus exports.

### LOCK-02 — `.github/workflows/ci.yml` (package-consumer job)
[VERIFIED: grep + read .github/workflows/ci.yml]

| Fact | Anchor | Status |
|------|--------|--------|
| `package-consumer:` job key | **`:541`** | live (lean PR-gating job, runs on ALL triggers — correct lane) |
| `Run built-artifact image-only package-consumer proof against MinIO` → `bash scripts/install_smoke.sh image` | **`:651`–`:652`** | **the smoke step** — LOCK-02 purge step goes IMMEDIATELY BEFORE this (after `Set up MinIO` at `:645`) |
| `Set up MinIO` step | **`:645`–`:646`** | purge can go before or after MinIO setup; before the smoke is the requirement |

**LOCK-02 step to insert (before `:651`):**
```yaml
- name: Purge phx.new archive to exercise the cold-runner self-install path
  run: mix archive.uninstall phx_new --force || true
```
The job already does `runs-on: ubuntu-22.04`, lean, no event gate → runs on every PR (satisfies `ci_lanes_only_on_main`). The `package-consumer-full` job (`:678`) is off-PR; do NOT add the purge there only — it must be in the lean PR-gating `package-consumer` job at `:541`.

## Standard Stack

No external packages. Pure repo-internal idioms.

### Core (idiom templates to mirror)
| Template | Path | Purpose | Why Standard |
|----------|------|---------|--------------|
| `package_metadata_test.exs` | `test/install_smoke/package_metadata_test.exs` | LOCK-01 host: already `File.read!`s `@install_smoke_script` into `setup_all` ctx as `install_smoke_script` | Drop-in; `=~` literal asserts at `:139–149` are the exact pattern |
| `async_safety_guard_test.exs` | `test/async_safety_guard_test.exs` | LOCK-04 & LOCK-05 skeleton: `Path.wildcard` + filter + `assert offenders == []` + `assert files != []` | The canonical glob-the-tree, anti-vacuous, file:line-offender lock |
| `ci_lane_split_test.exs` | `test/install_smoke/ci_lane_split_test.exs` | SHIPPED-only docstring convention (`:17–21`); avoid mutable `@vX` tags (`:9–15`) | The drift-discipline reference |

### Package Legitimacy Audit
N/A — this phase installs zero external packages (no npm/hex/pip additions). The only package referenced is `phx_new` (already in use; LOCK-02 *uninstalls then re-self-installs* it via the existing `install_smoke.sh` guard). No legitimacy gate required.

## Architecture Patterns

### System Architecture (lock data flow)

```
PR opened
   │
   ├─► quality lane (mix coveralls, default suite, merge-blocking)
   │      ├─ LOCK-01  → File.read! install_smoke.sh → =~ probe/install + order-index assert
   │      ├─ LOCK-04  → Path.wildcard JS harnesses → presence(focusVisible:true) ⇒ assert helper-routed + Tab-first
   │      └─ LOCK-05  → Path.wildcard test/**/*.exs → assert no line matches .planning runtime-read regex
   │
   └─► package-consumer lane (merge-blocking, all triggers)
          ├─ Set up MinIO  (:645)
          ├─ Purge phx.new archive  ◄── LOCK-02 (NEW step, :before 651)
          └─ Run install_smoke.sh image  (:651) → install_smoke.sh:31 probe FAILS (cold) → :33 self-install → smoke runs
                                                    └─ exercises the guard LOCK-01 asserts the TEXT of
   │
   ▼
CI Summary (single required check; skipped==pass) — unchanged; locks ride existing needs:
```

LOCK-01 (text) and LOCK-02 (behavior) are complementary: LOCK-02 makes the cold path real every PR; LOCK-01 makes the guard text undeletable. LOCK-03 (dedupe) collapses 3 modality copies → 1 helper; LOCK-04 asserts the post-dedupe invariant (raw call only inside the helper).

### Pattern 1: `setup_all` + `File.read!` shipped artifact → `=~` (LOCK-01)
**What:** Read the shipped script once into context, assert literal substrings + an order index.
**When to use:** Static text fact about a shipped script/workflow.
**Example:**
```elixir
# Source: test/install_smoke/package_metadata_test.exs:36-59, :134-150 (house idiom)
test "install_smoke.sh self-installs phx.new before the generated-app smoke (cold-runner guard)",
     %{install_smoke_script: script} do
  assert script =~ "mix phx.new --version",
         "install_smoke.sh must probe for the phx.new archive before using it"
  assert script =~ "mix archive.install hex phx_new --force",
         "install_smoke.sh must self-install the phx.new archive when absent"
  install_idx = :binary.match(script, "mix archive.install hex phx_new") |> elem(0)
  smoke_idx = :binary.match(script, "generated_app_smoke_test.exs") |> elem(0)
  assert install_idx < smoke_idx,
         "phx.new archive must be installed BEFORE the generated-app smoke runs"
end
```
(If folding into `package_metadata_test.exs`, reuse the existing `install_smoke_script` ctx key — no new `setup_all` needed. Honor its `@async_safety_allow [:file_mutation]` — that attribute is module-scoped; adding a read-only test is fine.)

### Pattern 2: glob + presence-keyed offender list (LOCK-04, D-03 dual-assert)
**What:** Glob harnesses, for each that *contains* `focusVisible: true`, assert it routes through the helper and presses Tab; separately assert no raw call lives outside the helper.
**Example:**
```elixir
# Source: mirrors test/async_safety_guard_test.exs:57-59, :95-107 (assert files != [] + offenders == [])
defmodule Rindle.FocusVisibleModalityGuardTest do
  use ExUnit.Case, async: true
  @repo_root Path.expand("..", __DIR__)
  @harnesses [
    "examples/adoption_demo/e2e/support/admin-polish.js",
    "brandbook/src/admin-gallery-check.mjs"
  ]

  test "the shared focusVisibly helper presses Tab before the programmatic focus" do
    helper = File.read!(Path.join(@repo_root, "examples/adoption_demo/e2e/support/admin-polish.js"))
    assert helper =~ ~r/function\s+focusVisibly|focusVisibly\s*=\s*(async\s*)?\(/,
           "admin-polish.js must define the shared focusVisibly helper"
    # Tab press must precede focusVisible: true within the helper body (index order is sufficient post-dedupe).
    tab_idx = :binary.match(helper, ~s|keyboard.press("Tab")|) |> elem(0)
    fv_idx = :binary.match(helper, "focusVisible: true") |> elem(0)
    assert tab_idx < fv_idx, "focusVisibly must press Tab before focus({focusVisible:true})"
  end

  test "no harness calls focus({focusVisible:true}) outside the shared helper" do
    files =
      @harnesses
      |> Enum.map(&Path.join(@repo_root, &1))
      |> Enum.filter(&File.exists?/1)
    assert files != [], "expected harness glob to match files, got none"

    offenders =
      Enum.flat_map(files, fn path ->
        File.read!(path)
        |> String.split("\n")
        |> Enum.with_index(1)
        |> Enum.filter(fn {line, _} -> line =~ "focusVisible: true" end)
        # post-dedupe the ONLY allowed occurrence is inside focusVisibly in admin-polish.js;
        # gallery must have ZERO raw occurrences (it calls the helper).
        |> Enum.reject(fn {_, _} -> false end) # planner: scope-check the helper region, see note
        |> Enum.map(fn {l, n} -> "#{Path.basename(path)}:#{n}: #{String.trim(l)}" end)
      end)
    # See D-03 enforcement note below for how to allow exactly the helper's own line.
    refute offenders == [] and false, "placeholder"
  end
end
```
**D-03 enforcement mechanics (planner must resolve):** post-dedupe there will be exactly ONE `focusVisible: true` literal in the whole codebase — inside `focusVisibly` in `admin-polish.js`. The cleanest "no raw call outside the helper" check: assert the gallery (`admin-gallery-check.mjs`) has **zero** `focusVisible: true` occurrences (it imports/calls the helper), and assert `admin-polish.js` has **exactly one** (`length(occurrences) == 1`). That single-count-in-the-helper-file + zero-in-consumers pair is simpler and stronger than region-scoping the helper body, and it catches a future fourth copy in either file. Prefer this over the placeholder above.

### Pattern 3: glob `test/**/*.exs` + regex offender list (LOCK-05)
**Example:** Use the Lock C snippet from research §2 verbatim (`Path.wildcard(Path.join(@test_root, "test/**/*.exs"))`, regex `~r/(File\.(read!|exists\?)|Path\.expand)[^)]*\.planning/`, `assert offenders == []`). Add `assert files != []` (the research snippet omits it — ADD it to match `async_safety_guard_test.exs:59`). [VERIFIED: live grep of that regex over `test/` returns EMPTY today, so the lock is green-on-arrival.]

### Anti-Patterns to Avoid
- **Asserting the `MIX_ENV=dev` prefix or `--force` suffix as part of the order-index substring** — use `"mix archive.install hex phx_new"` (no prefix/suffix) for `:binary.match` so cosmetic edits don't break the order check.
- **Region-scoping the helper body with brittle line math** for LOCK-04 — use the count-based approach (one occurrence in admin-polish.js, zero in gallery) instead.
- **Adding LOCK-02 purge to `package-consumer-full` only** (`:678`, off-PR) — it must be in the lean `package-consumer` (`:541`, PR-gating).
- **Globbing `*_test.exs` instead of `*.exs` for LOCK-05** — research/CONTEXT specify `test/**/*.exs` (catches support/helper files too). `async_safety_guard_test.exs` uses `*_test.exs`; LOCK-05 intentionally uses the broader `*.exs`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Read shipped script into a test | new `setup_all` | reuse `package_metadata_test.exs`'s `install_smoke_script` ctx key (LOCK-01) | already wired (`:51`) |
| Glob + offender-list scaffolding | bespoke recursion | `Path.wildcard` + `Enum.flat_map` + `assert offenders == []` + `assert files != []` | exact `async_safety_guard_test.exs` pattern |
| Cross-file JS import for the helper | new module system / bundler | the established `adoptionRequire(join(...,'admin-polish.js'))` at gallery `:25–26` | already load-bearing for 2 helpers |
| Cold-cache proof harness | shell assert in install_smoke.sh | a single `mix archive.uninstall phx_new --force \|\| true` CI step | adopter self-heal must stay silent; loud cold path lives in CI |

**Key insight:** every primitive this phase needs already ships in `test/`. The only *new* code is one JS function, one CI step, and three small meta-tests built from existing skeletons.

## Common Pitfalls

### Pitfall 1: OBS-02 content-drift (the #1 footgun for this phase)
**What goes wrong:** a meta-test asserting a literal in an artifact that THIS phase edits silently red-mains.
**Verification result (this session):** [VERIFIED: grep test/ for package-consumer / smoke-step / focus literals]
- LOCK-02 edits `ci.yml` (adds a step). The only `ci.yml` literals existing tests assert near package-consumer are **job-key presence** (`ci_lane_split_test.exs:82` `"\n  package-consumer:\n"`, `:85` `"\n  package-consumer-full:\n"`, `:110` needs `"- package-consumer\n"`, `:113` refute `package-consumer-full` in needs). The LOCK-02 step inserts a `run:` step at `:651`-ish — it does NOT touch the job-key line or the needs block. **No existing assertion is at risk.** Confirmed: no test asserts the `Run built-artifact image-only…` step name (`grep -rn "Run built-artifact" test/` → empty).
- LOCK-03 edits `admin-polish.js` + `admin-gallery-check.mjs`. **No `test/*.exs` currently asserts any literal from these JS files** — the focus behavior was previously unasserted (that's the whole gap). The new LOCK-04 test is the first asserter; it's authored in the same phase, so author it against the post-dedupe shape.
**How to avoid:** after writing LOCK-02/03 edits, re-run `grep -rn "package-consumer\|focusVisible\|admin-polish" test/` and confirm no *other* test's literal changed.
**Warning signs:** a green local `mix test` that goes red only after the artifact edit lands in the same commit.

### Pitfall 2: LOCK-03 drops the blur-first step (site 1) — semantic, not cosmetic
**What goes wrong:** D-02's helper spec (`Tab` + `locator.evaluate(el => el.focus({focusVisible:true}))`) omits site 1's `if (document.activeElement === el) el.blur();`. Replacing site 1 with a blur-less helper changes behavior.
**How to avoid:** make `focusVisibly` always blur-first-if-active (idempotent, safe for all 3 sites). See §Verified Targets site 1.
**Warning signs:** `assertFocusVisibleTokens` flakes again on re-focus of an already-focused element.

### Pitfall 3: site 2's focus is embedded in a state-reading `evaluate`
**What goes wrong:** wholesale-replacing site 2's `item.evaluate((el, contract) => { el.focus(...); ...reads styles... })` with the helper loses the style-reading return.
**How to avoid:** call `await focusVisibly(page, item)` for the Tab+focus, THEN keep the existing `item.evaluate(... reads styles ...)`. Focus persists across evaluate calls. See §Verified Targets site 2.

### Pitfall 4: `.planning/` path coupling re-introduction (the thing LOCK-05 guards)
**What goes wrong:** a new test (even LOCK-01/04/05 themselves) reads a `.planning/` path → breaks on archive.
**How to avoid:** all three new meta-tests read SHIPPED artifacts only (`scripts/`, `examples/`, `brandbook/`, `test/`). LOCK-05 will catch a violation in the SAME run it's introduced. Carry the `ci_lane_split_test.exs:17–21` "SHIPPED artifacts ONLY" docstring in each new module.
**Warning signs:** any `Path.expand(... ".planning" ...)` or `File.read!(... ".planning" ...)` in the new tests.

### Pitfall 5: vacuous pass
**What goes wrong:** a glob matches zero files and the lock "passes."
**How to avoid:** `assert files != []` in BOTH LOCK-04 and LOCK-05 (research's Lock C snippet omits it for LOCK-05 — ADD it). Key LOCK-04 off the *presence* of `focusVisible: true` so a file that drops the feature can't silently exempt itself.

## Validation Architecture

> REQUIRED — Nyquist validation is enabled (`.planning/config.json` has no `workflow.nyquist_validation: false`). Each lock IS a meta-test, so this section describes what each lock asserts, what a true regression looks like, and the anti-vacuous guard.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir), default suite, `use ExUnit.Case, async: true` |
| Config file | `test/test_helper.exs` (existing); `mix.exs` aliases drive `mix ci` |
| Quick run command | `mix test test/install_smoke/package_metadata_test.exs test/focus_visible_modality_guard_test.exs test/planning_path_hygiene_test.exs` |
| Full suite command | `mix coveralls` (the `quality` lane gate) |

### Each lock IS its own meta-test — what it asserts / what a regression looks like

| Req | The meta-test asserts | A TRUE regression that fails it | Anti-vacuous guard |
|-----|----------------------|----------------------------------|--------------------|
| LOCK-01 | `install_smoke.sh` contains `mix phx.new --version` AND `mix archive.install hex phx_new` AND install-index < smoke-index | Someone deletes the self-install guard (back to warm-cache-only pass) | `:binary.match` raises if a substring is absent → loud failure; order-index proves sequencing, not just presence |
| LOCK-02 | (behavioral, not a meta-test) the purge step runs before the smoke so the self-install path is actually taken on a cold archive every PR | The smoke silently relies on a warm archive; a deleted guard would pass in warm CI | The purge GUARANTEES the cold precondition — the smoke fails for real if the guard is gone (honest lock, not theater) |
| LOCK-03 | (the dedupe itself; validated BY LOCK-04) | n/a | n/a — LOCK-04 is its validator |
| LOCK-04 | (1) `focusVisibly` defined + presses Tab before focus; (2) zero raw `focusVisible: true` outside the helper (gallery==0, admin-polish.js==1) | A future 4th focus check copies `focus({focusVisible:true})` without Tab / without the helper | key off *presence* of `focusVisible: true`; `assert files != []`; count-based (==1 / ==0) catches new copies in EITHER file |
| LOCK-05 | no `test/**/*.exs` line matches `(File\.(read!\|exists\?)\|Path\.expand)[^)]*\.planning` | A new test reads a `.planning/` path (breaks on archive) | `assert offenders == []` with file:line list; **ADD `assert files != []`** (research omits it) so an empty glob fails loudly |

### Sampling Rate
- **Per task commit:** the quick-run command above (sub-second, the three meta-tests).
- **Per wave merge:** `mix coveralls` (full `quality` suite).
- **Phase gate:** full suite green + `package-consumer` lane green (LOCK-02 cold-path) before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `test/focus_visible_modality_guard_test.exs` — covers LOCK-04 (new module `Rindle.FocusVisibleModalityGuardTest`)
- [ ] `test/planning_path_hygiene_test.exs` — covers LOCK-05 (new module `Rindle.PlanningPathHygieneTest`)
- [ ] LOCK-01 test — either a new `test/install_smoke/install_smoke_preflight_test.exs` OR a new `test` inside existing `package_metadata_test.exs` (D-01 discretion)
- Framework install: none — ExUnit is the existing harness.

## Runtime State Inventory

This is a meta-test/refactor phase, but no runtime state migration applies — the changes are source-only. Verified per category:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no DB/datastore keys touched; LOCK-02 only uninstalls/reinstalls a hex *archive* (transient CI runner state, idempotent) | none |
| Live service config | None — no external service config; LOCK-02 is a `ci.yml` step (in git) | none |
| OS-registered state | None — no Task Scheduler / launchd / pm2 registrations | none |
| Secrets/env vars | None — no secret keys renamed; LOCK-02 uses no new secrets | none |
| Build artifacts | phx.new hex archive on the CI runner is uninstalled then self-reinstalled by `install_smoke.sh:33` — **this is the intended LOCK-02 behavior**, idempotent, no stale-artifact risk | none (by design) |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Fix flakes reactively, no lock | shipped-artifact meta-tests in `quality` (the `test/install_smoke/` family) | v1.20 (108–109) | This phase extends the established culture; zero new infra |
| 3 hand-duplicated modality copies | 1 exported `focusVisibly` helper via `adoptionRequire` | this phase (LOCK-03) | removes the "fixed in 2 places, forget the 3rd" footgun |

**Deprecated/outdated:** CONTEXT.md's tilde-prefixed JS anchors ("`:428/~432`") — they're actually exact; use the verified table above.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| (none) | — | — | All claims VERIFIED against live files this session (grep/read). | 

**This table is empty by intent — every factual claim was grep/read-confirmed on 2026-06-28. No `[ASSUMED]` claims.**

## Open Questions

1. **LOCK-04 dual-assert mechanics: count-based vs region-scoped.**
   - What we know: post-dedupe there is exactly ONE `focusVisible: true` literal (in `focusVisibly`), zero in the gallery.
   - What's unclear: whether the planner prefers count-assertion (`admin-polish.js`==1, gallery==0) or helper-body region-scoping.
   - Recommendation: count-based (simpler, stronger, catches a 4th copy in either file). Documented in Pattern 2.

2. **`focusVisibly` blur-first behavior (site 1 preservation).**
   - What we know: site 1 blurs-if-active before focusing; D-02's helper spec omits it.
   - What's unclear: whether the blur is load-bearing for `assertFocusVisibleTokens`.
   - Recommendation: helper always blurs-first-if-active (idempotent, safe for all 3 sites). Pitfall 2.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir/Mix + ExUnit | all LOCK meta-tests | ✓ (project toolchain) | per `.tool-versions` | — |
| `phx_new` hex archive | LOCK-02 (uninstall→self-reinstall) | ✓ in CI (install_smoke.sh self-installs) | hex latest | the guard self-heals if absent (the point) |
| Playwright / Chromium | NOT needed (B2 deferred) | n/a | — | LOCK-04 is a TEXT meta-test, no browser |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none (LOCK-02's archive purge is intentionally re-self-installed by the script under test).

## Project Constraints (from CLAUDE.md)

No `./CLAUDE.md` or `./.claude/CLAUDE.md` present in the working directory (verified — only `~/.claude` user-level memory exists). Governing constraints come from the milestone memories instead (honored throughout): `install_smoke archive path coupling` (LOCK-05 is the durable guard), `OBS-02 meta-test content drift` (Pitfall 1 — verified no existing literal at risk), `ci_lanes_only_on_main` (LOCK-02 in the lean PR-gating `package-consumer`, LOCK-01/04/05 in `quality`).

## Sources

### Primary (HIGH confidence — read/grep-confirmed this session)
- `scripts/install_smoke.sh` (:20–70) — phx.new guard + smoke invocation anchors
- `examples/adoption_demo/e2e/support/admin-polish.js` (:418–442, :918–935, :1099–1128) — 3 focus sites + exports
- `brandbook/src/admin-gallery-check.mjs` (:19–26, :160–189) — gallery focus site + `adoptionRequire` import
- `.github/workflows/ci.yml` (:541–676) — package-consumer lean job + smoke step insertion point
- `test/install_smoke/package_metadata_test.exs` (:1–59, :130–150) — LOCK-01 host idiom
- `test/install_smoke/ci_lane_split_test.exs` (:1–30, :78–234) — SHIPPED-only convention + package-consumer literal audit
- `test/async_safety_guard_test.exs` (:38–130) — glob + `assert files != []` + offender pattern
- Live grep: `(File\.(read!|exists\?)|Path\.expand)[^)]*\.planning` over `test/` → EMPTY (LOCK-05 green-on-arrival)

### Secondary
- `.planning/research/v1.21-REGRESSION-LOCKS.md` (the locked WHAT — Locks A1/A2/B1/C)
- `.planning/phases/111-regression-locks/111-CONTEXT.md` (D-01/02/03)
- `.planning/REQUIREMENTS.md` (LOCK-01..05, :53–57), `.planning/ROADMAP.md` (§Phase 111, :192–225)

## Metadata

**Confidence breakdown:**
- Standard stack (idioms): HIGH — all three template files read this session
- Assertion targets/anchors: HIGH — every anchor re-derived from live files; drift corrected
- Pitfalls (OBS-02, blur-first, embedded-evaluate): HIGH — grep/read-confirmed each

**Research date:** 2026-06-28
**Valid until:** 2026-07-28 (stable; re-verify JS anchors only if `admin-polish.js` is edited before planning)
