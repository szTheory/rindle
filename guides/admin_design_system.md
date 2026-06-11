# Rindle Admin Design System

This guide is the operating contract for the Phase 88 admin design-system kit.
Future console phases should use it before regenerating assets, reviewing the
gallery, or moving admin files toward packaged runtime serving.

## Source Of Truth

`brandbook/tokens/tokens.json` is the source of truth for Rindle Admin color,
typography, spacing, radius, focus, motion, and semantic theme tokens.
Generated artifacts must not be edited by hand.

The generated admin CSS lives at:

```sh
brandbook/tokens/rindle-admin.css
```

Regenerate and verify the kit from the repository root:

```sh
node brandbook/src/admin-css-build.mjs
node brandbook/src/admin-contrast.mjs
node brandbook/src/admin-gallery.mjs
node brandbook/src/admin-gallery-check.mjs
node brandbook/src/contrast.mjs
```

Use `node brandbook/src/admin-css-build.mjs` whenever token or component CSS
inputs change. Use `node brandbook/src/admin-contrast.mjs` for the
console-specific WCAG gate and `node brandbook/src/contrast.mjs` for the base
brand token gate. Use `node brandbook/src/admin-gallery.mjs` to regenerate the
static gallery HTML. Use `node brandbook/src/admin-gallery-check.mjs` to run the
browser checks and screenshot capture.

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

## Component Families

The Phase 88 component kit covers these required component families:

- nav shell
- tables
- lifecycle-state chips
- buttons
- theme picker
- confirm dialog
- drawer
- toasts
- empty states
- skeletons

Components use generated `rindle-admin` vanilla CSS, inspectable BEM selectors,
stable `data-rindle-admin-*` selectors, token-backed focus states, and
operator-oriented copy. Status chips must include visible labels plus non-color
marks and must not communicate state by color alone.

## Theme Contract

Theme behavior is `data-theme="light|dark|auto"` plus
`prefers-color-scheme`.

- `data-theme="light"` uses light semantic tokens.
- `data-theme="dark"` uses dark semantic tokens.
- `data-theme="auto"` follows `prefers-color-scheme`.

Do not add a parallel theme convention. The theme picker is a first-class
`rindle-admin` component, not a host Tailwind or daisyUI concern.

## Package Boundary

Phase 88 keeps generated admin design-system assets under `brandbook/`. While
assets stay under `brandbook/`, no `mix.exs` package file list change is
required.

Phase 89 owns serving assets from `priv/static/rindle_admin`. Any move into
`priv/static/rindle_admin` must add a package-file assertion in the same phase
so the Hex package includes the self-contained admin CSS and JavaScript files.

Phase 88 does not implement:

- `Rindle.Admin.Router.rindle_admin/2`
- auth semantics
- `Plug.Static`
- CSP/socket options
- `Rindle.Admin.Queries`
- production console routes

Those surfaces belong to later console phases. Phase 88 prepares generated CSS,
component markup patterns, gallery fixtures, browser checks, screenshots, and
contrast gates only. It must preserve the optional LiveView boundary and must
not make `phoenix_live_view` required for non-console adopters.

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

This guide records durable operating coverage for D-88-01, D-88-02, D-88-03,
D-88-04, D-88-05, D-88-06, D-88-07, D-88-08, D-88-09, D-88-10, D-88-11,
D-88-12, D-88-13, D-88-14, D-88-15, D-88-16, D-88-17, D-88-18, D-88-19, and
ADMIN-02 groundwork.

## Review Checklist

Before Phase 89 or Phase 90 relies on the kit, run the five commands above and
review the gallery plus screenshots. Confirm that light, dark, auto, mobile,
status-chip, theme-picker, and confirm-dialog states match the Phase 88
UI-SPEC: readable themes, no text overlap or clipping, visible focus states,
status chips with labels plus non-color marks, and confirm-dialog collateral
preview plus typed confirmation.
