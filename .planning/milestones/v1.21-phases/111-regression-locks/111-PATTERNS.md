# Phase 111: Regression locks - Pattern Map

**Mapped:** 2026-06-28
**Files analyzed:** 6 (3 NEW meta-tests, 2 MODIFY JS harnesses, 1 MODIFY ci.yml)
**Analogs found:** 6 / 6 (every file has a strong in-repo analog)

> All anchors below were re-read live 2026-06-28 and match RESEARCH.md's drift-corrected
> table. Plan against these line numbers, not CONTEXT.md's tilde anchors.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| LOCK-01 test (fold into `test/install_smoke/package_metadata_test.exs` OR new `test/install_smoke/install_smoke_preflight_test.exs`) | test (meta-test) | file-I/O + transform (read shipped script → `=~` + `:binary.match` order) | `test/install_smoke/package_metadata_test.exs` | exact (same role + same data flow; the host file already reads `install_smoke_script`) |
| `test/focus_visible_modality_guard_test.exs` (LOCK-04, `Rindle.FocusVisibleModalityGuardTest`) | test (meta-test) | file-I/O + transform (glob harnesses → presence-keyed offender list) | `test/async_safety_guard_test.exs` | role-match (glob + `assert files != []` + offender list; text-scan not AST-walk, so partial on mechanism) |
| `test/planning_path_hygiene_test.exs` (LOCK-05, `Rindle.PlanningPathHygieneTest`) | test (meta-test) | file-I/O + transform (glob `test/**/*.exs` → regex offender list) | `test/async_safety_guard_test.exs` | exact (same glob-the-tree + `assert offenders == []` + `assert files != []` skeleton) |
| `examples/adoption_demo/e2e/support/admin-polish.js` (add `focusVisibly` helper + replace 2 raw sites) | utility (JS harness helper) | transform (browser-modality side-effect) | existing exported helpers in same file (`assertConsistentRhythm`, `assertNoHorizontalScroll`) | exact (same file, same `module.exports` convention) |
| `brandbook/src/admin-gallery-check.mjs` (consume `focusVisibly` via `adoptionRequire`, replace raw site) | utility (JS harness consumer) | transform | the file's own `adoptionRequire(...admin-polish.js)` import at `:25-26` | exact (the import path is already load-bearing for 2 helpers) |
| `.github/workflows/ci.yml` (add purge `run:` step in `package-consumer` job before the smoke) | config (CI workflow) | event-driven (CI step) | existing `run:` steps in the `package-consumer` job (`:651-652`, `:654-660`) | exact |

## Pattern Assignments

### LOCK-01 test (`test/install_smoke/...`, meta-test, file-I/O + transform)

**Analog:** `test/install_smoke/package_metadata_test.exs`

**Host decision (Claude's Discretion, D-01):** fold into `package_metadata_test.exs` (reuse the
existing `install_smoke_script` ctx key — no new `setup_all`) OR create sibling
`install_smoke_preflight_test.exs`. If folding, honor the module-scoped
`@async_safety_allow [:file_mutation]` attribute already present (`:8`) — adding a read-only
test does not change its justification.

**Module header + ctx wiring** (`package_metadata_test.exs:1-2`, `:13-15`, `:36-59`):
```elixir
defmodule Rindle.InstallSmoke.PackageMetadataTest do
  use ExUnit.Case, async: true
  # ...
  @repo_root Path.expand("../..", __DIR__)
  @install_smoke_script Path.join(@repo_root, "scripts/install_smoke.sh")
  # ...
  setup_all do
    # ...
    {:ok, %{
      # ...
      install_smoke_script: File.read!(@install_smoke_script),
      # ...
    }}
  end
```
If folding: the `install_smoke_script` key is already returned (`:51`) — just add a `test`.
If a new sibling: copy the `@repo_root`/`@install_smoke_script` + minimal `setup_all` returning
only `install_smoke_script`.

**`=~` literal + `:binary.match` order-index pattern** (mirrors `:98-120` `command_position/2`
order-assert idiom, and `:134-150` literal-assert idiom). The exact assertion literals (from
RESEARCH.md drift-correction §LOCK-01 — install line is `MIX_ENV=dev mix archive.install hex
phx_new --force`, smoke at `:56`/`:59`):
```elixir
test "install_smoke.sh self-installs phx.new before the generated-app smoke (cold-runner guard)",
     %{install_smoke_script: script} do
  assert script =~ "mix phx.new --version",
         "install_smoke.sh must probe for the phx.new archive before using it"
  assert script =~ "mix archive.install hex phx_new --force",
         "install_smoke.sh must self-install the phx.new archive when absent"

  # ORDER-INDEX substring is the bare "mix archive.install hex phx_new" (NO MIX_ENV=dev prefix,
  # NO --force suffix) so cosmetic edits to the line don't break the order check.
  install_idx = :binary.match(script, "mix archive.install hex phx_new") |> elem(0)
  smoke_idx = :binary.match(script, "generated_app_smoke_test.exs") |> elem(0)
  assert install_idx < smoke_idx,
         "phx.new archive must be installed BEFORE the generated-app smoke runs"
end
```
Reuse the file's existing `command_position/2` (`:298-303`) helper if folding, instead of inline
`:binary.match`, to match the house idiom — it returns `{position, _}` or `nil`.

**Live target confirmation** (`scripts/install_smoke.sh`): probe `:31`
(`if ! mix phx.new --version >/dev/null 2>&1; then`), self-install `:33`
(`MIX_ENV=dev mix archive.install hex phx_new --force`), smoke `:56` (gcs) / `:59` (`--include minio`).

**Drift trap:** `:binary.match` RAISES (not returns nil) if a substring is absent — that is the
intended loud failure. Do NOT assert `"MIX_ENV=dev mix archive.install"` or
`"...--force"` for the order index (RESEARCH Anti-Pattern #1).

---

### LOCK-04 test (`test/focus_visible_modality_guard_test.exs`, meta-test, glob + offender list)

**Analog:** `test/async_safety_guard_test.exs`

**Module skeleton** (from `async_safety_guard_test.exs:1`, `:38-59`, `:107`):
```elixir
defmodule Rindle.FocusVisibleModalityGuardTest do
  use ExUnit.Case, async: true

  @repo_root Path.expand("..", __DIR__)
  @harnesses [
    "examples/adoption_demo/e2e/support/admin-polish.js",
    "brandbook/src/admin-gallery-check.mjs"
  ]
```

**`assert files != []` anti-vacuous guard** (copy verbatim style from `:57-59`):
```elixir
files = @harnesses |> Enum.map(&Path.join(@repo_root, &1)) |> Enum.filter(&File.exists?/1)
assert files != [], "expected harness glob to match files, got none"
```

**Offender-list + `assert offenders == []` shape** (from `:95-107`, with a file:line message like
`:491-510` `failure_message/1`). This is a TEXT scan (`String.split("\n") |> Enum.with_index(1)`),
NOT the AST walk the analog uses — the analog's `Macro.prewalk`/`Code.string_to_quoted!` is for
Elixir source; here the targets are JS, so scan lines.

**D-03 dual-assert (use the count-based mechanic, RESEARCH Pattern 2 + Open Q1):**
1. **Helper presses Tab before the programmatic focus** — read `admin-polish.js`, assert it defines
   `focusVisibly`, then `:binary.match` order: `tab_idx = :binary.match(helper, ~s|keyboard.press("Tab")|)`
   before `fv_idx = :binary.match(helper, "focusVisible: true")`.
2. **No raw call outside the helper** — post-dedupe there is exactly ONE `focusVisible: true` literal
   in the whole codebase (inside `focusVisibly` in `admin-polish.js`). Assert
   `admin-polish.js` has **exactly one** occurrence and `admin-gallery-check.mjs` has **zero**.
   Prefer count (`==1` / `==0`) over brittle region-scoping (RESEARCH Anti-Pattern #2). This
   catches a future 4th copy in EITHER file.

**Anti-vacuous guard:** key the scan off the *presence* of `focusVisible: true` so a file that
drops the feature can't silently exempt itself; `assert files != []` (RESEARCH Pitfall 5).

**SHIPPED-only discipline:** read only `examples/`, `brandbook/` paths — never `.planning/`
(carry the `ci_lane_split_test.exs:17-21` "SHIPPED artifacts ONLY" docstring).

---

### LOCK-05 test (`test/planning_path_hygiene_test.exs`, meta-test, glob `test/**/*.exs` + regex)

**Analog:** `test/async_safety_guard_test.exs` (near-exact skeleton reuse)

**Glob + `assert files != []`** (from `:40-41`, `:57-59` — note the BROADER glob `*.exs` not
`*_test.exs`, RESEARCH Anti-Pattern #4):
```elixir
defmodule Rindle.PlanningPathHygieneTest do
  use ExUnit.Case, async: true

  @test_root Path.expand("..", __DIR__)
  @glob Path.join(@test_root, "test/**/*.exs")   # *.exs (superset of *_test.exs) — catches support/helper files

  setup_all do
    files = Path.wildcard(@glob)
    assert files != [], "expected test/**/*.exs glob to match files, got none"  # ADD this — research's Lock C snippet omits it
    {:ok, files: files}
  end
```

**Regex offender list + `assert offenders == []`** (mirror `:95-107` flat_map → sort → assert; use
the Lock C regex). Build a `file:line` offender list (mirror `:491-510` message style):
```elixir
@planning_read_re ~r/(File\.(read!|exists\?)|Path\.expand)[^)]*\.planning/

# for each file: String.split("\n") |> Enum.with_index(1) |> filter(line =~ @planning_read_re)
#                |> map("#{relpath}:#{n}: #{trim}")
assert offenders == [], failure_message(offenders)
```

**Green-on-arrival:** live `grep -rnE '(File\.(read!|exists\?)|Path\.expand)[^)]*\.planning' test/`
returns EMPTY (verified 2026-06-28) — the lock passes on arrival. The new LOCK-01/04/05 tests must
themselves read only SHIPPED paths or LOCK-05 fails them in the same run (RESEARCH Pitfall 4).

---

### `examples/adoption_demo/e2e/support/admin-polish.js` (utility, MODIFY: add `focusVisibly` + replace 2 sites)

**Analog:** the file's own existing exported helpers + `module.exports` block.

**Export convention** (`:1099-1128`): add `focusVisibly,` to the `module.exports` object adjacent
to the focus exports (`assertFocusVisibleTokens` `:1107`, `assertFocusVisibleVsPointer` `:1115`).
The gallery already imports same-style helpers via `adoptionRequire` (`assertConsistentRhythm`,
`assertNoHorizontalScroll`).

**D-02 helper shape** (`focusVisibly(page, locator)`): press `Tab` (entering keyboard modality)
then `locator.evaluate(el => ...)`. Match the existing site's `.catch(() => {})` swallow on the Tab
press (Claude's Discretion D-03 note).

**Site 1 — `assertFocusVisibleTokens` (lines 428-434):**
```js
await page.keyboard.press("Tab").catch(() => {});
await item
  .evaluate((element) => {
    if (document.activeElement === element) element.blur();
    element.focus({ focusVisible: true });
  })
  .catch(() => {});
```
SEMANTIC TRAP (RESEARCH Pitfall 2): site 1 blurs-first-if-active. A blur-less helper changes
behavior. **The helper must always do `if (document.activeElement === el) el.blur(); el.focus({
focusVisible: true });`** (idempotent, safe for all 3 sites) so site 1's behavior is preserved.

**Site 2 — `assertFocusVisibleVsPointer` (lines 927-929):**
```js
await page.keyboard.press("Tab").catch(() => {});
const kb = await item.evaluate((el, contract) => {
  el.focus({ focusVisible: true });
  // ...reads computed styles, RETURNS state...
```
SEMANTIC TRAP (RESEARCH Pitfall 3): the focus is the FIRST statement inside a LARGER
`item.evaluate((el, contract) => {...})` that returns computed-style state. The helper CANNOT
wholesale-replace this evaluate. Extract only the `Tab + focus` prelude: call
`await focusVisibly(page, item)` THEN keep the existing `item.evaluate(... reads styles ...)`
separately (focus persists across evaluate calls).

---

### `brandbook/src/admin-gallery-check.mjs` (utility, MODIFY: consume `focusVisibly`, replace raw site)

**Analog:** the file's own `adoptionRequire(...admin-polish.js)` import (`:25-26`).

**Import path (already load-bearing)** (`:25-26`):
```js
const { assertConsistentRhythm, assertNoHorizontalScroll } = adoptionRequire(
  join(repoRoot, 'examples', 'adoption_demo', 'e2e', 'support', 'admin-polish.js'),
);
```
Add `focusVisibly` to this destructure — no new convention.

**Site 3 — the gallery focus site (lines 173, 178):**
```js
await page.keyboard.press('Tab');                                            // :173 — NO .catch
// ...
await locator.evaluate((element) => element.focus({ focusVisible: true }));  // :178
```
TRAP: the gallery's Tab press has NO `.catch(() => {})` (unlike admin-polish.js). The helper
centralizes this — decide ONCE (RESEARCH recommends keeping `.catch(() => {})` since the demo
sites rely on it). Replace both `:173` Tab and `:178` focus with a single
`await focusVisibly(page, locator)` per iteration. Post-edit the gallery must have ZERO
`focusVisible: true` literals (LOCK-04 asserts this).

---

### `.github/workflows/ci.yml` (config, MODIFY: add purge step in `package-consumer` job)

**Analog:** existing `run:` steps in the same `package-consumer` job.

**Insertion point** (RESEARCH §LOCK-02, verified): the purge goes IMMEDIATELY BEFORE the smoke
step `Run built-artifact image-only package-consumer proof against MinIO` (`:651-652`), after
`Set up MinIO` (`:645-646`). Must be in the lean PR-gating `package-consumer` job (`:541`), NOT
`package-consumer-full` (`:678`, off-PR).

**Existing adjacent steps for shape reference** (`:645-660`):
```yaml
      - name: Set up MinIO for S3-compatible package-consumer proofs
        uses: ./.github/actions/setup-minio

      # <<< LOCK-02 purge step inserts HERE (before the smoke) >>>

      - name: Run built-artifact image-only package-consumer proof against MinIO
        run: bash scripts/install_smoke.sh image

      - name: Verify version alignment (mocking tag)
        env:
          MIX_ENV: dev
        run: |
          ...
```

**Step to insert** (RESEARCH §LOCK-02, exact YAML; step name + position is Claude's Discretion but
MUST be before the smoke):
```yaml
      - name: Purge phx.new archive to exercise the cold-runner self-install path
        run: mix archive.uninstall phx_new --force || true
```

## Shared Patterns

### Meta-test scaffold (`use ExUnit.Case, async: true` + `setup_all` + `File.read!`/`Path.wildcard`)
**Source:** `test/install_smoke/package_metadata_test.exs:1-59`, `test/async_safety_guard_test.exs:38-74`
**Apply to:** LOCK-01, LOCK-04, LOCK-05.
- `@repo_root Path.expand("..", __DIR__)` (top-level tests, 1 level up) or `"../.."` (in
  `test/install_smoke/`, 2 levels up).
- Read shipped artifacts in `setup_all`, return as ctx; OR glob in `setup_all`.
- No exclude tag → default suite → merge-blocking `quality` lane (via `mix test`/`mix coveralls`).

### Anti-vacuous + offender-list assertion idiom
**Source:** `test/async_safety_guard_test.exs:57-59` (`assert files != []`), `:95-107`
(`flat_map → sort → assert offenders == []`), `:491-510` (`failure_message/1` file:line message)
**Apply to:** LOCK-04, LOCK-05.
- ALWAYS `assert files != []` before scanning (both LOCK-04 and LOCK-05 — research's Lock C snippet
  omits it for LOCK-05; ADD it).
- Offenders as `"#{relpath_or_basename}:#{line}: #{trimmed}"`, sorted, asserted `== []` with a
  descriptive message.

### Order-index via `:binary.match`
**Source:** `test/install_smoke/package_metadata_test.exs:298-303` (`command_position/2`), used at
`:108-111`, `:182-190`
**Apply to:** LOCK-01 (install before smoke), LOCK-04 (Tab before focus in the helper).
- `:binary.match(content, substring) |> elem(0)` for the start index; assert `a_idx < b_idx`.
- Use the SHORTEST stable substring (bare `"mix archive.install hex phx_new"`, no prefix/suffix).

### SHIPPED-artifacts-only docstring discipline
**Source:** `test/install_smoke/ci_lane_split_test.exs:9-21`
**Apply to:** all 3 new meta-tests (LOCK-01/04/05).
- Carry a `@moduledoc` stating the test asserts SHIPPED state and does NOT couple to `.planning/`
  paths (which move on `gsd-cleanup` archive). Avoid mutable `@vX` tag assertions (`:9-15`).
- Memory `install_smoke archive path coupling` + `OBS-02 meta-test content drift` are the governing
  footguns — LOCK-05 is the durable guard; re-grep `test/` for changed literals after the LOCK-02
  ci.yml edit lands (none at risk per RESEARCH Pitfall 1, but re-confirm in-phase).

### JS harness export + cross-file `adoptionRequire` import
**Source:** `admin-polish.js:1099-1128` (`module.exports`), `admin-gallery-check.mjs:25-26`
(`adoptionRequire(...admin-polish.js)`)
**Apply to:** LOCK-03 dedupe — export `focusVisibly` from `admin-polish.js`, consume in the gallery
via the existing destructure. No new module system / bundler (RESEARCH Don't Hand-Roll).

## No Analog Found

None. Every file in this phase maps to a strong in-repo analog. The only genuinely new code is one
JS function (`focusVisibly`), one CI step, and three small meta-tests assembled from the
`package_metadata_test.exs` + `async_safety_guard_test.exs` + `ci_lane_split_test.exs` skeletons.

## Metadata

**Analog search scope:** `test/`, `test/install_smoke/`, `examples/adoption_demo/e2e/support/`,
`brandbook/src/`, `.github/workflows/`, `scripts/`
**Files scanned (read this session):** `package_metadata_test.exs`, `async_safety_guard_test.exs`,
`ci_lane_split_test.exs`, `admin-polish.js` (3 ranges), `admin-gallery-check.mjs` (2 ranges),
`ci.yml` (package-consumer range), `install_smoke.sh` (guard range)
**Live verifications:** install_smoke.sh anchors (:31/:33/:56/:59), JS focus sites (admin-polish
:428/:432, :927/:929; gallery :173/:178), exports (:1099-1128), import (:25-26), ci.yml insertion
point (:645-652), LOCK-05 grep over `test/` → EMPTY (green-on-arrival)
**Pattern extraction date:** 2026-06-28
