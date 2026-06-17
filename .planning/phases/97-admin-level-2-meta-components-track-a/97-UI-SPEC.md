---
phase: 97
slug: admin-level-2-meta-components-track-a
status: draft
shadcn_initialized: false
preset: none
created: 2026-06-17
---

# Phase 97 - UI Design Contract

> Visual and interaction contract for Track A Level-2 meta-components. Orchestrator-authored
> (full non-interview path) from Phase 95's UI-SPEC + codebase analysis. Composed units only;
> built exclusively from Level-1 primitives.

---

## Design System

| Property | Value |
|----------|-------|
| Tool | none — generated vanilla `rindle-admin` CSS |
| Preset | not applicable |
| Component library | none; generated BEM selectors composed into meta-components |
| Icon library | none required; status/sort affordances pair color with visible label/glyph |
| Font | `Space Grotesk` headings, `Atkinson Hyperlegible` UI/body, `JetBrains Mono` code/IDs |

Source: `guides/ui_principles.md`, `brandbook/tokens/tokens.json`, `brandbook/src/admin-css-build.mjs`. No `components.json`; shadcn/Radix/Tailwind/third-party UI registries remain forbidden for the console package boundary.

## Level-2 Meta-Component Inventory

Phase 97 composes and proves only these units, each built from Level-1 primitives. Every unit
carries a stable `data-rindle-admin-meta="{slug}"` marker on its root for mechanical unit
assertion, plus the existing `data-rindle-admin-component` markers on its Level-1 parts.

| Meta-component | `data-rindle-admin-meta` | Composed from (Level-1) | Required affordances / attributes |
|----------------|--------------------------|--------------------------|-----------------------------------|
| Toolbar | `toolbar` | button (primary/secondary/quiet/destructive), form-controls | Left-aligned title cluster + right-aligned action cluster; consistent control gap on the 4px grid; no wrap-induced overlap |
| Data table | `data-table` | table, status-chip, button, form-controls | Sortable header (`aria-sort="ascending\|descending\|none"` + token-backed sort affordance), sticky header (`.rindle-admin-table--sticky`, header stays pinned under internal scroll), bulk-select (header checkbox + per-row `[data-rindle-admin-selected]`) |
| Filter bar | `filter-bar` | form-controls (inputs/selects/checkbox), button, status-chip | Inline filter controls + apply/clear; active-filter chips; aligned baselines; no horizontal scroll |
| Action panel | `action-panel` | button, status-chip, table/empty-state | Grouped primary + secondary + destructive actions with consistent vertical rhythm |
| Detail drill-down | `detail-drilldown` | table, status-chip, `[data-rindle-admin-detail-link]`, drawer/panel | Master row → detail summary; key/value rows on consistent rhythm; back/close affordance |
| Confirm / destructive panel | `confirm-panel` | confirm-dialog, button (destructive/secondary), form-controls (`[data-rindle-admin-confirm-input]`) | Destructive preview + typed confirmation; confirm disabled until input matches |
| Drawer | `drawer` | drawer, button, table/form-controls | Overlay surface (dark elevation token in dark theme); header + body + action footer on grid |
| Toast stack | `toast-stack` | toast (`--success\|--warning\|--danger\|--info`), button (quiet dismiss) | Stacked real-state toasts with consistent inter-toast gap; non-color mark + label; no decorative motion |

Each unit must render in the gallery as one labeled cohesion panel under `data-theme="light"`,
`data-theme="dark"`, and `data-theme="auto"`. No new Level-1 primitive may be introduced; if a
unit appears to need one, flag it as out-of-scope rather than inventing it here.

## Spacing Scale (inherited — must hold within every unit)

Declared values (multiples of 4): `--rindle-space-1` 4px, `--rindle-space-2` 8px,
`--rindle-space-4` 16px, `--rindle-space-5` 24px, `--rindle-space-6` 32px, `--rindle-space-7`
48px, `--rindle-space-8` 64px. Exceptions: `--rindle-space-3` 12px for table cell padding;
`--rindle-admin-target-min` 44px minimum interactive target; `--rindle-space-fluid-gutter` /
`--rindle-space-fluid-section` are the only fluid tokens.

**Rhythm rule (new gate):** sibling gaps, margins, and paddings inside a meta-component must
resolve to one of the token values above. Off-grid spacing is a rhythm failure. Density (the
chosen rhythm step) must be consistent within a unit.

## Typography (inherited — no new roles)

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body | 17px | 400 | 1.6 |
| Label / small | 14px | 600 controls/chips, 400 secondary | 1.45 |
| Heading | 22px | 600 | 1.25 |
| Display | 30px | 600 | 1.15 |

Use only these four roles. Page-level hero/h1 sizes remain Phase 98 territory.

## Color (inherited — token-backed only)

60% dominant `--rindle-surface`; 30% secondary `--rindle-surface-raised` / dark
`--rindle-elevation-1..3`; 10% accent (light brand `#123A35`, dark `#32D08C`) reserved for
primary CTA / active affordance / focus ring / sort-active indicator; destructive light
`#C83232` / dark `#F09090`. No page-local color literals. `rindle-green` is accent/large-graphic
only on light surfaces — never body text.

## Interaction Contract (Level-2 additions over Phase 95)

| Concern | Contract |
|---------|----------|
| Composition | Meta-components use ONLY Level-1 selectors/tokens. No new class outside the generated `rindle-admin` vocabulary may appear inside a unit (gallery-check asserts no unknown-class leakage). |
| Rhythm / density | All intra-unit spacing is token-backed (4px grid). Consistent density per unit. Proven by the new `assertConsistentRhythm` check. |
| No horizontal scroll | Unit root `scrollWidth <= clientWidth + tolerance` at captured viewports. Proven by the new `assertNoHorizontalScroll` check. Internal sticky-header table scroll regions are the only exception and must be opted in by an explicit container marker (no auto-detection). |
| Overlap | No interactive-control bbox overlap within a unit. `OVERLAP_ENFORCED` flips to `true` for the meta-component matrix after one green CI cycle confirms zero spurious warnings. |
| Sortable header | `aria-sort` reflects state; sort affordance is token-backed and visible (not color-only); focus-visible + active remain distinct (inherited Level-1 contract). |
| Sticky header | Header row stays pinned during internal vertical scroll without covering the first data row or shifting layout. |
| Bulk-select | Header select-all + per-row `[data-rindle-admin-selected]`; selected rows use token-backed selected surface; a contextual bulk-action toolbar is shown only when ≥1 row is selected. |
| Inherited Level-1 states | default / hover / focus-visible / active / disabled / loading / empty / error / skeleton remain governed by Phase 95 and must not regress. |

Interactive selectors for the polish gate stay the Phase 95 set plus any new meta-component
control selectors the planner introduces (e.g. a bulk-action or sort-toggle selector), which
must be added to `DEFAULT_INTERACTIVE_SELECTORS`.

## Copywriting Contract (terse operator/SRE voice — reuse Phase 95 register)

| Element | Copy guidance |
|---------|---------------|
| Toolbar title | Name the surface being operated on (e.g. `Assets`, `Sessions`). |
| Filter bar empty result | `No assets match these filters` + next diagnostic action. |
| Bulk-action bar | State the count and the action, e.g. `3 selected — Erase` / `Requeue`. |
| Sort affordance label | `Sort by {column}` (accessible name); visible glyph for direction. |
| Destructive confirm | Reuse Phase 95 owner/batch erasure confirmation copy. |
| Toasts | Real state change only. Say what happened + next step. No "please/oops/sorry", no marketing, no color-only labels. |

## Gallery And Proof Contract

| Surface | Required additions |
|---------|--------------------|
| `brandbook/src/admin-design-system-data.mjs` | Add `META_COMPONENTS` inventory (slugs above). Keep `THEMES = ['light','dark','auto']`, `MIN_TARGET_PX = 44`. Extend `CONSOLE_CONTRAST_PAIRS` only from tokens if new pairs arise. |
| `brandbook/src/admin-css-build.mjs` | Generate all meta-component composition/state rules from tokens; self-check required meta selectors, sticky/sort/selected modifiers, theme scopes, and reduced-motion block. |
| `brandbook/src/admin-gallery.mjs` | Render each meta-component as one cohesion panel with `data-rindle-admin-meta="{slug}"`, across light/dark/auto. |
| `brandbook/src/admin-gallery-check.mjs` | Assert every `META_COMPONENTS` unit renders + is visible per theme, composes only of known Level-1 selectors, and capture unit screenshots. |
| `examples/adoption_demo/e2e/support/admin-polish.js` | Add `assertConsistentRhythm` + `assertNoHorizontalScroll` (offender-returning), wire into `assertAdminPolish`, flip `OVERLAP_ENFORCED` for the meta matrix. Keep single aggregated throw per state. |

Verification commands for planner/executor:

```bash
node brandbook/src/admin-css-build.mjs
node brandbook/src/admin-contrast.mjs
node brandbook/src/admin-gallery-check.mjs
mix test test/brandbook/admin_design_system_validation_test.exs
```

The existing merge-blocking `adoption-demo-e2e` lane runs `admin-polish.js` over real
screenshots — no new visual-regression dependency or Storybook.

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | none | not applicable — no shadcn, no `components.json`, not a React/Next/Vite project |
| third-party registries | none | forbidden by `guides/ui_principles.md` and `test/brandbook/admin_design_system_validation_test.exs` |

## Checker Sign-Off

- [ ] Dimension 1 Copywriting: PASS
- [ ] Dimension 2 Visuals (cohesion units): PASS
- [ ] Dimension 3 Color: PASS
- [ ] Dimension 4 Typography: PASS
- [ ] Dimension 5 Spacing (rhythm/density): PASS
- [ ] Dimension 6 Registry Safety: PASS

**Approval:** pending

## Pre-Populated Sources

| Source | Decisions Used |
|--------|----------------|
| `.planning/ROADMAP.md` | UPLIFT-02 success criteria, Level-2 inventory, rhythm/overlap/no-h-scroll gate requirement |
| `.planning/REQUIREMENTS.md` | Composed-units mandate, color+label (no color-only), no one-off styles |
| `.planning/phases/95-.../95-UI-SPEC.md` | Level-1 inventory, interaction/copy contract, gallery+polish proof surfaces (extend, don't re-open) |
| `guides/ui_principles.md` | Fonts, target size, theme behavior, dependency prohibitions, motion/copy rules |
| `brandbook/tokens/tokens.json` | Token values for spacing/grid, typography, colors, focus, motion |
| `brandbook/src/admin-design-system-data.mjs` | Existing inventories + where `META_COMPONENTS` is added |
| `brandbook/src/admin-gallery*.mjs` | Existing gallery proof surface and screenshot contract |
| `examples/adoption_demo/e2e/support/admin-polish.js` | Deterministic computed-style gate; rhythm/no-h-scroll checks to add, overlap to enforce |
