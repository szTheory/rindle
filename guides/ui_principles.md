# UI Principles

These rules satisfy PRIN-01 for Rindle UI/admin-console work. Future agents must read this
guide before changing console, Cohort, E2E, or visual-polish surfaces.

## Design-system values

- `brandbook/tokens/tokens.json` is the source of truth.
- `brandbook/src/contrast.mjs` is the contrast-gate pattern.
- The shipped console uses `rindle-admin` vanilla CSS, BEM selectors, and generated
  `--rindle-` custom properties.
- The console must not depend on host Tailwind, daisyUI, esbuild, shadcn, Radix,
  Tailwind UI, daisyUI registry components, or any third-party UI registry.
- Theme behavior is `data-theme="light|dark|auto"` plus `prefers-color-scheme`.
- Interactive targets are at least `44px`.
- Typography uses `Space Grotesk` for compact headings, `Atkinson Hyperlegible` for
  UI/body text, and `JetBrains Mono` for code, IDs, env vars, and file paths.
- Status indicators use labels/icons plus token color pairs; never rely on color alone.

## Visual and accessibility audit checklist

- Text and controls meet the token contrast contract.
- Focus states use token focus width, offset, and color.
- Status chips include visible labels/icons plus color.
- Navigation names actual operator tasks, not decorative dashboard categories.
- Destructive actions show the affected owner/assets before confirmation.
- Empty states explain the next useful action.
- Error states name the missing source artifact or failed operation.
- Light and dark themes are both checked.
- No control is smaller than `44px`.
- No UI text depends on hover-only disclosure.

## Deterministic E2E rules

- Use stable selectors or element IDs for LiveView tests and Playwright specs.
- Prefer stateful selectors over text-only assertions where stable selectors are available.
- seeded lifecycle state is required for asset, variant, upload-session, degraded,
  quarantined, failed, stale, and expired cases.
- Tests should verify outcomes, not implementation details.
- Avoid sleeps. Wait for explicit state, events, or selectors.
- Keep destructive flows deterministic by asserting the collateral preview, typed
  confirmation, disabled-submit state, execution result, and receipt.

## Screenshot polish loop

- Capture every console screen in light/dark screenshot mode before claiming visual polish.
- Seed data so screenshots include ready, processing, warning, danger, quarantine, and empty
  states.
- Compare layout density, table rhythm, focus visibility, chip readability, and dark-theme
  contrast.
- Fix overlap, clipped text, horizontal scroll, unstable dimensions, and illegible chips
  before completion.
- Do not use screenshots to justify decorative motion or dashboard sprawl.

## Motion constraints

- Use `--rindle-motion-press`, `--rindle-motion-popover`,
  `--rindle-motion-toast`, `--rindle-motion-transition`, and
  `--rindle-motion-easing`.
- Respect `prefers-reduced-motion`.
- Motion is allowed for press feedback, origin-aware popovers/drawers, toast
  materialization, real PubSub/LiveView continuity, and orientation-preserving transitions.
- Motion is forbidden for decorative animation, parallax, bouncing, infinite loops,
  marketing-style hero motion, and loading animation not backed by real pending work.
- Destructive and failure states update immediately without animated delay.

## Security and destructive-action rules

- Host apps own auth and `:on_mount`; the console must not weaken that boundary.
- Admin reads stay in `Rindle.Admin.Queries`; do not add convenience reads to the public
  `Rindle` facade.
- Owner erasure and batch erasure require collateral preview and typed confirmation.
- Variant regeneration, quarantine review, and lifecycle repair must reuse existing
  facade/ops capabilities.
- Do not hide dangerous state behind color, animation, or collapsed-only UI.
- Receipts must show what changed and what did not change.

## When to escalate

Escalate exactly these triggers before proceeding:

- public API shape
- auth semantics
- dependency footprint
- destructive operations
- security/compliance boundary
- material recurring cost
- milestone scope

Local wording, selector, layout, and styling choices that preserve this guide can be
resolved by the agent and recorded in the relevant plan or summary.
