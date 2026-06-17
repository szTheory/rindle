---
phase: 97-admin-level-2-meta-components-track-a
reviewed: 2026-06-17T22:05:00Z
depth: standard
files_reviewed: 7
files_reviewed_list:
  - brandbook/src/admin-design-system-data.mjs
  - brandbook/src/admin-css-build.mjs
  - brandbook/src/admin-gallery.mjs
  - brandbook/src/admin-gallery-check.mjs
  - brandbook/admin-gallery/index.html
  - examples/adoption_demo/e2e/support/admin-polish.js
  - test/brandbook/admin_design_system_validation_test.exs
findings:
  critical: 0
  warning: 4
  info: 4
  total: 8
status: issues_found
---

# Phase 97: Code Review Report

**Reviewed:** 2026-06-17T22:05:00Z
**Depth:** standard
**Files Reviewed:** 7
**Status:** issues_found

## Summary

Phase 97 adds a Level-2 meta-component inventory, token-backed composition CSS for
8 composed units, gallery cohesion panels, two new offender-returning polish
sub-assertions (`assertConsistentRhythm`, `assertNoHorizontalScroll`), and the
phase-seal (overlap enforcement + priv CSS sync + pinned-literal bump). The
generated CSS, the parity/`exact()` guards, the fail-closed `requiredMetaSelectors`
self-check, and the `assertMetaCohesion` vacuous-pass count guard are all sound and
correctly fail-closed. No correctness bug produces a wrong rendered result and no
security issue exists (no network, auth, file-access, or injection surface; HTML is
generated from a fixed fixture set with `escapeHtml` on dynamic substrings).

The findings below concern **mechanical-coverage gaps where guards advertise more
than they actually prove** — exactly the "vacuous / dead-guard" class this review
was asked to scrutinize. None block the seal (the gallery-side checks do real work),
but several summary claims overstate the coverage the merge-blocking lane gets, and
one new surface introduces an ungated contrast pair.

## Warnings

### WR-01: Per-unit no-horizontal-scroll opt-out is dead code for the only unit it targets

**File:** `examples/adoption_demo/e2e/support/admin-polish.js:554-569` (with `brandbook/src/admin-gallery.mjs:187,195`)
**Issue:** `assertNoHorizontalScroll` skips a meta unit when
`unit.closest("[data-rindle-admin-scroll-region]")` is truthy — i.e. when the unit
root is itself **inside** a scroll region. But in the generated markup the
`data-rindle-admin-scroll-region` marker is a **descendant** of the
`data-rindle-admin-meta="data-table"` root (the inner `.rindle-admin-table--sticky`
div, gallery line 195), not an ancestor. `closest()` walks self-and-ancestors, so it
never matches for the data-table meta root. The opt-out branch is unreachable for the
exact unit it was written to exempt. The data-table unit passes only incidentally —
its `display:grid` root does not inflate `scrollWidth` because the inner
`overflow:auto` region clips its own overflow — not because the marker opted it out.
The 97-02/97-03 summaries assert "the sticky data-table correctly opted out via its
`data-rindle-admin-scroll-region` marker," which is not what the code does. If a
future change made the sticky region a wrapper *around* the meta root (or moved the
marker up), the opt-out still would not fire as documented, and a legitimately
internally-scrolling unit could be flagged.
**Fix:** Either move the skip to test the unit's own subtree
(`unit.querySelector("[data-rindle-admin-scroll-region]")` → skip, or measure
overflow on the non-scroll-region children), or move the marker onto the meta-unit
root so `closest()` matches as intended. Example (subtree-aware skip):
```js
for (const unit of document.querySelectorAll(`${ROOT} [data-rindle-admin-meta]`)) {
  // a unit that owns an internal scroll region manages its own horizontal extent
  if (unit.matches("[data-rindle-admin-scroll-region]") ||
      unit.querySelector("[data-rindle-admin-scroll-region]")) continue;
  ...
}
```

### WR-02: Both new "hard" cohesion checks are vacuous no-ops in the merge-blocking e2e lane

**File:** `examples/adoption_demo/e2e/support/admin-polish.js:599-600`
**Issue:** `assertConsistentRhythm` and `assertNoHorizontalScroll` both iterate
`document.querySelectorAll("${ROOT} [data-rindle-admin-meta]")`. The live
`adoption_demo` / LiveView surfaces emit **zero** `[data-rindle-admin-meta]`
elements (`lib/rindle/admin/components.ex` only has `data-rindle-admin-metadata-list`,
which is a different attribute that does not match the `[data-rindle-admin-meta]`
selector). So in the `adoption-demo-e2e` lane — the only lane where
`assertAdminPolish` runs — both checks always return `[]` and silently pass. Their
sole real exercise is `brandbook/src/admin-gallery-check.mjs` (which does add a count
guard). Wiring them into `assertAdminPolish` as "hard checks" (97-03 SUMMARY) gives a
false impression that the merge-blocking lane enforces intra-unit rhythm and per-unit
overflow; it does not. This is a sibling of the classic vacuous-pass: an empty
collection makes an offender-returning check pass with no coverage, and there is no
count guard on the `assertAdminPolish` side to detect it.
**Fix:** Either (a) document the wiring explicitly as a forward-seam no-op in the code
(a comment in `assertAdminPolish` next to the two `run(...)` calls, mirroring the
SUMMARY rationale), or (b) add a lightweight guard so a surface that *does* declare
meta units but exposes none at runtime fails loudly rather than passing vacuously —
e.g. only run the two checks when `surface` opts into a `expectsMetaUnits` flag and
assert `count > 0` in that case.

### WR-03: New meta surfaces introduce an ungated `text` on `surface-sunken` contrast pair

**File:** `brandbook/src/admin-css-build.mjs:755-770` and `:206-209`
**Issue:** `.rindle-admin-bulk-bar` and `[data-rindle-admin-selected]` paint
`color: var(--rindle-text)` (primary text) on `background: var(--rindle-surface-sunken)`.
`CONSOLE_CONTRAST_PAIRS` covers `text-secondary`/`surface-sunken` (disabled text) but
**not** `text`/`surface-sunken` in either light or dark. The static contrast gate
(`admin-contrast.mjs`, asserted at `58/58`) is the authority in the e2e lane; the
runtime `assertReadableContrast` is NOT invoked by `admin-gallery-check.mjs` (only the
rhythm + h-scroll checks are imported), so this new pair is unverified by any gate.
The values happen to pass AA today (light: `ink` on `mist`; dark: `dark-text` on
`ink`), so this is not a live failure — but it is a real hole in the "every
text/background pair is gated" guarantee the contrast system exists to provide, opened
by this phase without a corresponding pair.
**Fix:** Add the missing pairs to `CONSOLE_CONTRAST_PAIRS` and bump the asserted count
(this is the documented intent of the gate — a new on-surface text role must come with
its pair):
```js
{ fg: 'text', bg: 'surface-sunken', theme: 'light', min: 4.5, context: 'bulk bar / selected row text on sunken' },
{ fg: 'text', bg: 'surface-sunken', theme: 'dark',  min: 4.5, context: 'bulk bar / selected row text on sunken (dark)' },
```
(and update the `58/58` literal in `admin-contrast.mjs` and the ExUnit assertion at
`test/brandbook/admin_design_system_validation_test.exs:127`).

### WR-04: `assertMetaNoLeakage` proves "rindle-admin- prefix", not "Level-1-only composition"

**File:** `brandbook/src/admin-gallery-check.mjs:133-140` (with `brandbook/src/admin-gallery.mjs:177,310,315,317`)
**Issue:** The 97-02 SUMMARY calls this the "mechanical 'composed only of Level-1
selectors' proof (D-97-07)." But the predicate only asserts each class under
`[data-rindle-admin-meta]` `startsWith("rindle-admin-")`. The meta panels legitimately
contain **gallery-only** helper classes — `rindle-admin-gallery__input`,
`rindle-admin-gallery__receipt`, `rindle-admin-gallery__field` (e.g. gallery lines 177,
310, 315, 317) — which are presentational helpers defined in the gallery's inline
`<style>`, not Level-1 design-system primitives. They satisfy the `rindle-admin-`
prefix and pass the scan. So the check cannot detect a meta panel that smuggles in
non-primitive (but `rindle-admin-`-prefixed) styling, which is the exact leakage class
it claims to forbid. The guard is weaker than its stated contract.
**Fix:** Tighten the allowlist to the actual Level-1 surface (component roots + their
BEM parts) rather than a bare prefix, e.g. derive an allowed-class set from
`COMPONENTS`/`requiredSelectors` and assert every meta-subtree class is either a known
primitive class/modifier or an explicitly allowlisted gallery-chrome class — and fail
on anything else. At minimum, exclude `rindle-admin-gallery__*` from the "passing"
set and assert it is absent inside `[data-rindle-admin-meta]` subtrees if the contract
is truly "Level-1 primitives only."

## Info

### IN-01: `assertConsistentRhythm` allowed∪exempt set spans the entire spacing scale

**File:** `examples/adoption_demo/e2e/support/admin-polish.js:539`
**Issue:** `ALLOWED = [4,8,16,24,32,48,64]` ∪ `EXEMPT_PX = [12,44]` exactly equals the
declared spacing scale `{4,8,12,16,24,32,48,64}` plus the 44px target. So **every**
`--rindle-space-*` token value is accepted; the check can only ever catch a literal
non-token pixel value. That is the intended job, but the framing of `{12,44}` as
narrow "documented exceptions" understates that 12px (`--rindle-space-3`, used
pervasively in the meta CSS) is a first-class grid step, not an exception. Consider
folding 12 into the allowed set and reserving EXEMPT for genuinely off-scale values
(44) so the comment matches reality.
**Fix:** Move `12` into `ALLOWED`; keep only `44` (and any true off-scale value) in
`EXEMPT_PX`, updating the doc comment accordingly.

### IN-02: Static `th[aria-sort]` advertises `cursor: pointer` with no sort behavior

**File:** `brandbook/src/admin-css-build.mjs:705-707`
**Issue:** Sortable headers set `cursor: pointer`, but the data-table is explicitly
static (no client JS, D-97-03) — clicking a header does nothing. A pointer cursor on a
non-interactive element is a mild affordance/a11y mismatch (suggests interactivity that
is absent). Acceptable for a gallery fixture, but worth a note if these primitives are
later lifted into live LiveView where the cursor would imply a working sort.
**Fix:** Either gate `cursor: pointer` behind a `[data-rindle-admin-sortable]` opt-in
that the live (JS-backed) usage sets, or document the static intent in the CSS comment.

### IN-03: Stale "warn mode" comment above an enforced constant

**File:** `examples/adoption_demo/e2e/support/admin-polish.js:28-30`
**Issue:** The comment still reads "Ship it in warn mode for one green CI cycle, then
flip to a hard failure…" directly above `const OVERLAP_ENFORCED = true;`. The flip
already happened in 97-04; the comment now describes a past state and reads as if the
constant should be `false`.
**Fix:** Update the comment to record that the warn cycle completed and overlap is now
enforced (D-97-11), so the next reader does not "fix" it back to `false`.

### IN-04: Unanchored magic-number breakpoint in gallery inline CSS

**File:** `brandbook/src/admin-gallery.mjs:543`
**Issue:** `@media (max-width: 980px)` in the gallery's inline `<style>` is a bare
literal with no token basis or explanatory comment, unlike the generated CSS's
`@media (max-width: 760px)` which carries a "literal because CSS media conditions
cannot read custom properties" note anchored on `--rindle-bp-md`. 980px matches no
declared breakpoint (`sm 480 / md 760 / lg 1024 / xl 1280`).
**Fix:** Anchor on a declared breakpoint (e.g. `lg` 1024px) or add a comment
explaining why 980px is the gallery's two-column collapse point.

---

_Reviewed: 2026-06-17T22:05:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
