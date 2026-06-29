# Phase 111: Regression locks - Context

**Gathered:** 2026-06-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Give the already-fixed **2026-06-26 flake cluster** durable, **merge-blocking,
shipped-artifact-only** regression locks so it cannot silently regress. The fixes already
landed (phx.new self-install guard, `:focus-visible` Tab-first press in both harnesses,
`.planning/`-path decoupling); this phase asserts **closed state**, never in-flight work.

**Approach is research-locked** to the single decide-by-default package in
`.planning/research/v1.21-REGRESSION-LOCKS.md` (HIGH confidence, every claim grep-confirmed
live). All five LOCK requirements + the Phase 111 success criteria are locked upstream — this
discussion only settled the open *HOW* (file placement, dedupe helper shape, LOCK-04
enforcement strategy). It did NOT revisit *whether* to lock (locked), the lanes (locked to the
already-required `quality`/`package-consumer`), or whether dedupe happens (locked by success
criterion #3).

**In scope (LOCK-01..05):**
- **LOCK-01** — ExUnit meta-test asserting `scripts/install_smoke.sh` keeps the `mix phx.new --version`
  probe + `mix archive.install hex phx_new --force` self-install, AND that the install precedes the
  `generated_app_smoke_test.exs` invocation (`quality`, merge-blocking).
- **LOCK-02** — `package-consumer` CI step purging the phx.new archive
  (`mix archive.uninstall phx_new --force || true`) **before** the smoke, so the cold-runner
  self-install path is exercised on every PR (`package-consumer`, merge-blocking).
- **LOCK-03** — Dedupe the `:focus-visible` Tab-first keyboard-modality logic into one exported
  helper in `admin-polish.js`, consumed by all three call sites + `admin-gallery-check.mjs`
  (which already imports from it via `adoptionRequire`).
- **LOCK-04** — ExUnit meta-test asserting the Tab-first modality at every
  `focus({focusVisible:true})` site, post-dedupe (`quality`, merge-blocking).
- **LOCK-05** — ExUnit meta-test globbing `test/**/*.exs` that fails if any test reads a
  `.planning/` path at runtime (`quality`, merge-blocking).

**Out of scope:**
- **B2 Playwright unit test** of the shared modality helper (research LOCK-05/B2) — NOT in this
  milestone; the Tab-first text guard (LOCK-04) carries the PR-merge-blocking lock for both copies.
- **`CountingFailingTxnRepo` proxy-completeness lock** (research Lock D / Area 4) — owned by Phase
  110's async-isolation work and `async_safety_guard_test.exs`; not re-locked here.
- Any new CI job / new required check; any `lib/` change; any `.planning/`-coupled assertion.
- The coverage-single-run (108) and `:epipe` (109) proofs — those locks shipped in their phases.

</domain>

<decisions>
## Implementation Decisions

The research package settled the *what*. The discussion settled three open *HOW* questions; all
chose the stronger/research-default option. The unifying intent: every lock is a pure
string/AST scan over a **shipped artifact**, runs in the already-required `quality` /
`package-consumer` lane at ~0 wall-clock, and **honestly exercises** the failing condition rather
than asserting the fix text in the same warm environment that hid the bug.

### Meta-test file placement (LOCK-01 / LOCK-04 / LOCK-05)
- **D-01:** Split the three new meta-tests **by scope** (research default):
  - **LOCK-01** (phx.new guard) → the existing `test/install_smoke/` family — it is an
    install-smoke-script fact, sits next to `package_metadata_test.exs` (which already reads
    `install_smoke_script`). Fold into `package_metadata_test.exs` or a sibling
    `install_smoke_preflight_test.exs` at the planner's discretion.
  - **LOCK-04** (focus-modality) → a standalone top-level module (e.g.
    `test/focus_visible_modality_guard_test.exs`, `Rindle.FocusVisibleModalityGuardTest`) — it
    scans JS harnesses well beyond install_smoke.
  - **LOCK-05** (`.planning/` hygiene) → a standalone top-level module (e.g.
    `test/planning_path_hygiene_test.exs`, `Rindle.PlanningPathHygieneTest`) — it globs the whole
    `test/` tree, a strict superset of install_smoke.
  - All use `use ExUnit.Case, async: true`, no exclude tag → default suite → merge-blocking
    `quality` lane via `mix test` / `mix coveralls`.

### `:focus-visible` dedupe helper API (LOCK-03)
- **D-02:** Export a **single high-level helper** `focusVisibly(page, locator)` from
  `admin-polish.js`'s `module.exports`, that presses `Tab` (entering keyboard modality) then runs
  `locator.evaluate(el => el.focus({ focusVisible: true }))`. All three current sites
  (`admin-polish.js:~428/~432`, `:~927/~929`, `admin-gallery-check.mjs:~173/~178`) call it. This
  **removes every raw `focus({focusVisible:true})` from call sites** — the strongest guarantee,
  and rides the already-load-bearing `adoptionRequire(...admin-polish.js)` import in the gallery.
- Keep the existing per-script WCAG-math copies **as-is** (pure, side-effect-free, already locked
  by the contrast gates) — only the *stateful* modality workaround is deduped.

### LOCK-04 enforcement strategy
- **D-03:** Post-dedupe, the raw `focus({focusVisible:true})` lives **only** inside the shared
  helper. The LOCK-04 meta-test therefore asserts **both**:
  1. the shared `focusVisibly` helper in `admin-polish.js` presses `Tab` before the programmatic
     `focusVisible` focus; AND
  2. **no harness file** (`admin-polish.js`, `admin-gallery-check.mjs`) calls
     `focus({focusVisible:true})` directly **outside** that helper.
  This forces every site through the helper and catches a *future fourth copy* that bypasses it —
  the exact "duplicated in two places at once" footgun that produced the original flake.
- **Anti-vacuous-pass guard:** key the scan off the *presence* of `focusVisible: true` (a file
  that drops the feature can't silently exempt itself), and `assert files != []` so a glob that
  matches zero harnesses fails loudly (mirrors `async_safety_guard_test.exs`).

### Claude's Discretion (planner/executor decide)
- Exact LOCK-01 host file (fold into `package_metadata_test.exs` vs new
  `install_smoke_preflight_test.exs`) and assertion mechanics (`:binary.match` index ordering vs
  line-index) — match the house idiom.
- Exact LOCK-02 step name + position within the `package-consumer` job (must be **before** the
  built-artifact image-only proof that runs the smoke).
- The shared helper's internal `.catch(() => {})` handling on the `Tab` press (match the existing
  `admin-polish.js` call sites, which swallow the press error).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The locked plan (read first)
- `.planning/research/v1.21-REGRESSION-LOCKS.md` — THE decide-by-default package. §2 (per-lock
  mechanism + snippets A1/B1/C), §3 (dedupe rationale + established import path), §5 (medium
  selection: meta-test vs shell vs Playwright), §6 (footguns: warm-cache regression test,
  `.planning/` coupling, push:main-only, vacuous pass), §8 (LOCKED recommendation + atomic
  requirement bullets). **Requirement-number mapping:** research LOCK-01→req LOCK-01,
  research LOCK-02→LOCK-02, LOCK-03→LOCK-03, LOCK-04 (B1)→LOCK-04, research **LOCK-06 (Lock C)→req
  LOCK-05**; research LOCK-05 (B2 Playwright) is **out of scope** this milestone.
- `.planning/ROADMAP.md` § Phase 111 — the 5 locked success criteria + invariants (shipped
  artifacts only; ride already-required lanes; no new required checks).
- `.planning/REQUIREMENTS.md` LOCK-01..05 (lines 53–57) — the atomic acceptance bullets.

### Shipped artifacts under lock (assertion targets)
- `scripts/install_smoke.sh` §31–33 — the phx.new `--version` probe + `archive.install` self-install
  (LOCK-01 asserts this stays); `:56`/`:59` — the `generated_app_smoke_test.exs` invocation the
  install must precede.
- `examples/adoption_demo/e2e/support/admin-polish.js` — CommonJS `module.exports` (`:1099`); the
  three Tab-first sites (`:428`/`:432`, `:927`/`:929`); **host of the new `focusVisibly` helper**.
- `brandbook/src/admin-gallery-check.mjs` — the gallery copy (`:173`/`:178`); already imports from
  `admin-polish.js` via `adoptionRequire` (`:25–26`) — the dedupe consumer path.
- `.github/workflows/ci.yml` — the `package-consumer` job (LOCK-02 purge step host); the
  `quality` lane that runs the default suite (where LOCK-01/04/05 gate).

### House meta-test idioms (templates to mirror)
- `test/install_smoke/package_metadata_test.exs` — already reads `install_smoke_script`;
  LOCK-01 host candidate.
- `test/install_smoke/ci_lane_split_test.exs` §18–22 — the "SHIPPED artifacts ONLY — does NOT
  couple to `.planning/`" docstring convention; §9–15 — avoid mutable `@vX` tag assertions.
- `test/async_safety_guard_test.exs` — the glob-`test/`-tree + `assert files != []` + file:line
  offender-list pattern LOCK-04/05 reuse.

### Governing memories (footgun guards)
- `install_smoke archive path coupling` — assert SHIPPED paths only; `.planning/` dirs move on
  archive. LOCK-05 is the durable guard against re-coupling anywhere in `test/`.
- `OBS-02 meta-test content drift` — meta-tests asserting literal artifact content silently
  red-main when the SAME phase edits the artifact; if this phase edits `ci.yml`/scripts, re-grep
  `test/install_smoke/` for changed literals.
- `ci_lanes_only_on_main` — every lock must sit in a PR-gating lane (`quality`/`package-consumer`),
  never push:main-only/nightly (1-merge MTTD = the gap that let the cluster reach main).

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/install_smoke/` meta-test family — drop-in template: `use ExUnit.Case, async: true` +
  `setup_all` reading a shipped artifact + `=~`/`refute =~` literal assertions. Zero new infra.
- `admin-polish.js` `module.exports` (`:1099`) + the gallery's `adoptionRequire(...admin-polish.js)`
  (`:25–26`) — the cross-file import path the dedupe (LOCK-03) rides; **already load-bearing**
  (`assertConsistentRhythm`/`assertNoHorizontalScroll` are imported the same way), no new convention.
- `async_safety_guard_test.exs` — the `Path.wildcard("test/**/*.exs")` + filter + `assert offenders
  == []` + `assert files != []` skeleton LOCK-04 and LOCK-05 both reuse.

### Established Patterns
- Locks ride the already-required `quality` / `package-consumer` lanes via the `CI Summary`
  aggregate (skipped==pass) — no new required check, `setup_branch_protection.sh` untouched.
- Per-script copies of *pure* helpers (WCAG math) are intentionally kept; only the *stateful*
  browser-quirk modality workaround is deduped (research §3).

### Integration Points
- LOCK-02 is a CI-step edit in `ci.yml`'s `package-consumer` job (a `run:` step before the smoke).
- LOCK-03 touches `examples/adoption_demo/e2e/support/admin-polish.js` (helper export) +
  `brandbook/src/admin-gallery-check.mjs` (consume helper) — internal harness/demo files, NOT
  adopter-facing `lib/`; no semver impact.

</code_context>

<specifics>
## Specific Ideas

- "Honest" locks over theater: LOCK-02 **purges** the phx.new archive so the cold self-install
  path is genuinely taken every PR (a guard that runs in the same warm cache that hid the bug is
  theater — research §6 footgun #1).
- LOCK-04 must catch a *future fourth* `focusVisible` copy that forgets the helper — hence
  "ban raw calls outside the helper," not just "assert the helper presses Tab."
- Adopter self-heal in `install_smoke.sh` stays **silent** (correct UX); the loud cold-path
  exercise lives in CI only (LOCK-02).

</specifics>

<deferred>
## Deferred Ideas

- **B2 Playwright unit test** of the `focusVisibly` helper (press → programmatic focus →
  assert `el.matches(':focus-visible')`; pointer branch false) — research LOCK-05/B2. Now feasible
  *because* LOCK-03 dedupes the helper, but out of scope for v1.21; candidate for a future
  browser-test hardening pass.
- **`CountingFailingTxnRepo` `behaviour_info(:callbacks)` completeness lock** — research Lock D /
  Area 4; covered by Phase 110 + `async_safety_guard_test.exs`. Only revisit if 110's
  process-override approach leaves the proxy-completeness gap open.

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 111-regression-locks*
*Context gathered: 2026-06-28*
