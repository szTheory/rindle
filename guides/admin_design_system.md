# Rindle Admin Design System

This guide is the operating contract for the generated Rindle Admin design
system. Future console phases should use it before regenerating assets,
reviewing the gallery, or changing packaged admin runtime assets.

## Source Of Truth

`brandbook/tokens/tokens.json` is the source of truth for Rindle Admin color,
typography, spacing, radius, focus, motion, and semantic theme tokens.
Generated artifacts must not be edited by hand.

The generated admin CSS lives at:

```sh
brandbook/tokens/rindle-admin.css
```

The Hex-shipped package copy lives at:

```sh
priv/static/rindle_admin/rindle-admin.css
```

`priv/static/rindle_admin/rindle-admin.css` is synced by
`brandbook/src/sync-admin-css.mjs` and must not be hand-edited. The brandbook
copy is the canonical generator output; the shipped copy must be byte-identical
after sync.

Regenerate and verify the kit from the repository root:

```sh
node brandbook/src/admin-css-build.mjs
node brandbook/src/admin-contrast.mjs
node brandbook/src/admin-gallery-check.mjs
node brandbook/src/sync-admin-css.mjs
cmp -s brandbook/tokens/rindle-admin.css priv/static/rindle_admin/rindle-admin.css
node brandbook/src/contrast.mjs
mix test --include integration test/brandbook/admin_design_system_validation_test.exs
```

Use `node brandbook/src/admin-css-build.mjs` whenever token or component CSS
inputs change. Use `node brandbook/src/admin-contrast.mjs` for the
console-specific WCAG gate and `node brandbook/src/contrast.mjs` for the base
brand token gate. Use `node brandbook/src/admin-gallery-check.mjs` to regenerate
the static gallery HTML, run browser checks, and capture screenshots. Use
`node brandbook/src/sync-admin-css.mjs` after generator changes so the shipped
package CSS stays byte-identical to the brandbook CSS.

## Gallery Review Artifacts

The static gallery HTML lives at:

```sh
brandbook/admin-gallery/index.html
```

Review screenshots are generated under:

```sh
brandbook/admin-gallery/screenshots/
```

The expected maintainer review set is:

- `brandbook/admin-gallery/screenshots/gallery-light-desktop.png`
- `brandbook/admin-gallery/screenshots/gallery-dark-desktop.png`
- `brandbook/admin-gallery/screenshots/gallery-auto-desktop.png`
- `brandbook/admin-gallery/screenshots/gallery-light-mobile.png`
- `brandbook/admin-gallery/screenshots/status-chips-dark.png`
- `brandbook/admin-gallery/screenshots/theme-picker-light.png`
- `brandbook/admin-gallery/screenshots/confirm-dialog-light.png`
- `brandbook/admin-gallery/screenshots/form-controls-light.png`
- `brandbook/admin-gallery/screenshots/error-state-dark.png`
- `brandbook/admin-gallery/screenshots/loading-state-auto.png`

The screenshots are generated local review artifacts. They are hardcoded gallery
fixtures, not production data, and should contain no real owner media, secrets,
environment variables, or adopter data.

## Operator Surfaces

Rindle Admin uses exactly six top-level surfaces:

- Home/Status
- Assets
- Upload Sessions
- Variants/Jobs
- Runtime/Doctor
- Actions

These names are the navigation contract for later console phases. Do not replace
them with decorative dashboard categories.

## Level-1 Component Inventory

The Phase 95 Level-1 primitive inventory is exact and singular:

- shell
- nav
- table
- status-chip
- button
- theme-picker
- form-controls
- confirm-dialog
- drawer
- toast
- empty-state
- error-state
- loading-state
- skeleton

The Level-1 state vocabulary is exact:

- default
- hover
- focus-visible
- active
- disabled
- loading
- empty
- error
- skeleton

Components use generated `rindle-admin` vanilla CSS, inspectable BEM selectors,
stable `data-rindle-admin-*` selectors, token-backed focus states, and
operator-oriented copy. Status chips must include visible labels plus non-color
marks and must not communicate state by color alone.

Every applicable gallery fixture must carry same-element
`data-rindle-admin-component` and `data-rindle-admin-state` markers so the
browser checker can assert combined selectors such as
`[data-rindle-admin-component="button"][data-rindle-admin-state="disabled"]`.
Focus-visible states use `outline: var(--rindle-focus-width) solid
var(--rindle-focus-ring)` plus `outline-offset: var(--rindle-focus-offset)`.
Bare `outline:none` and `outline: none` removal is forbidden.

## Theme Contract

Theme behavior is `data-theme="light|dark|auto"` plus
`prefers-color-scheme`.

- `data-theme="light"` uses light semantic tokens.
- `data-theme="dark"` uses dark semantic tokens.
- `data-theme="auto"` follows `prefers-color-scheme`.
- Status-chip foreground and surface tokens are semantic in both light and dark;
  contrast gates must check the same `status-*-surface` backgrounds the CSS uses.
- Border color tokens (`border-subtle`, `border-strong`) stay color-only; border
  shorthand tokens use the `border-rule-*` namespace.

Do not add a parallel theme convention. The theme picker is a first-class
`rindle-admin` component, not a host Tailwind or daisyUI concern.

## Package Boundary

Generated source assets stay under `brandbook/`; the shipped CSS copy is under
`priv/static/rindle_admin`. The sync script is the only committed mirror path.
The package must include the self-contained admin CSS while preserving the
optional LiveView boundary and without making `phoenix_live_view` required for
non-console adopters.

The generated design system does not own auth semantics, CSP/socket policy, or
new public read/write APIs. Runtime console routes remain mounted through
`Rindle.Admin.Router.rindle_admin/2`, and admin reads stay in
`Rindle.Admin.Queries`.

## Dependency Boundary

The shipped library console must not depend on host asset tooling, runtime UI
frameworks, or registry components. The forbidden dependency list is:

- Tailwind
- daisyUI
- esbuild
- shadcn
- Radix
- Tailwind UI
- daisyUI registry
- third-party UI registries

If a later phase proposes any runtime UI dependency or third-party registry,
stop and escalate because dependency footprint is a recorded high-blast-radius
boundary.

## Decision Coverage

This guide records durable operating coverage for the Phase 88 generated kit,
Phase 94 token pipeline, and Phase 95 Level-1 primitive audit: D-95-01 through
D-95-09 plus ADMIN-02 package/dependency boundary groundwork.

## Review Checklist

Before later admin phases rely on the kit, run the command chain above and
review the gallery plus screenshots. Confirm that light, dark, auto, mobile,
status-chip, theme-picker, confirm-dialog, form-controls, error-state, and
loading-state fixtures match the Phase 95 UI-SPEC: readable themes, no text
overlap or clipping, visible focus-visible states, active/current states that do
not rely on focus outlines, disabled/loading affordances, status chips with
labels plus non-color marks, and confirm-dialog collateral preview plus typed
confirmation.
