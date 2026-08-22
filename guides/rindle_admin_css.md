# Rindle Admin CSS Architecture

The shipped console CSS is a vanilla `rindle-admin` layer generated from
`brandbook/tokens/tokens.json`. It uses generated `--rindle-` custom properties, BEM
selectors, and self-contained static assets. It does not require host Tailwind, daisyUI,
esbuild, or host asset-pipeline integration.

The repository ships the generator, CSS, components, and contrast extensions described
here.

## Source Of Truth

`brandbook/tokens/tokens.json` is the token source of truth. Generated CSS is an artifact,
like `brandbook/tokens/tokens.css`, and must not be edited by hand.

Regenerate and verify the admin layer with the repository's existing build commands:

```sh
node brandbook/src/tokens-build.mjs
node brandbook/src/contrast.mjs
```

`brandbook/src/contrast.mjs` remains the mechanical WCAG gate pattern. Console-specific
contrast pairs should extend that pattern rather than rely on visual judgment.

## Layer Shape

The console layer is named `rindle-admin`. It should ship as one namespaced CSS surface
served by Rindle static assets.

Shipped selector examples include:

- `.rindle-admin-shell`
- `.rindle-admin-nav__item`
- `.rindle-admin-table__row`
- `.rindle-admin-status-chip`
- `.rindle-admin-status-chip--ready`
- `.rindle-admin-status-chip--processing`
- `.rindle-admin-status-chip--danger`

Selectors use BEM so adopters can inspect markup without learning a generated class
system. Do not use global element selectors for console styling.

## Custom Properties

Generated custom properties are prefixed `--rindle-`.

Examples consumed by the shipped implementation include:

- `--rindle-surface`
- `--rindle-surface-raised`
- `--rindle-text`
- `--rindle-brand`
- `--rindle-status-ready`
- `--rindle-status-processing`
- `--rindle-status-danger`
- `--rindle-focus-ring`
- `--rindle-motion-press`

Raw hex values may appear in this lock document as requirements copied from the token
source, but console implementation should consume custom properties.

## Theme Contract

Theme behavior is `data-theme="light|dark|auto"` plus `prefers-color-scheme`.

- `data-theme="light"` uses light semantic tokens.
- `data-theme="dark"` uses dark semantic tokens.
- `data-theme="auto"` follows `prefers-color-scheme`.

The theme control is a console component, not a host Tailwind/daisyUI concern.

## Status Chips

Every status chip must include:

- visible text label
- icon or equivalent non-color mark
- token-gated foreground/background color pair

Never communicate state by color alone. A ready state should still read "Ready"; a danger
state should still read "Danger" or the specific failure label.

Locked status examples:

```html
<span class="rindle-admin-status-chip rindle-admin-status-chip--ready">Ready</span>
<span class="rindle-admin-status-chip rindle-admin-status-chip--processing">Processing</span>
<span class="rindle-admin-status-chip rindle-admin-status-chip--danger">Danger</span>
```

## UI-SPEC Values

These values are constraints from the admin UI design contract:

| Concern | Locked value |
| --- | --- |
| Minimum interactive target | `44px` |
| Compact headings | `Space Grotesk` |
| UI/body font | `Atkinson Hyperlegible` |
| Code/IDs font | `JetBrains Mono` |
| Dominant surface | `#F7F4EA` |
| Secondary surface | `#FBFEFC` |
| Brand accent | `#123A35` |
| Destructive | `#C83232` |
| Processing | `#6D5DD3` |

`#6D5DD3` is frozen because the contrast margin is narrow. Do not lighten the processing
token for visual convenience.

## Cohort Separation

Cohort keeps Tailwind/daisyUI for the demo app. The shipped library console must not
inherit Cohort's frontend stack and must not depend on Tailwind, daisyUI, esbuild, or
host asset-pipeline integration.

This separation lets the demo move quickly while keeping the library console portable for
Phoenix adopters.

## Registry And Dependency Boundary

Do not add shadcn, Radix, Tailwind UI, daisyUI, or third-party UI registries to the shipped
console. The design system is vanilla CSS plus Phoenix/LiveView markup.

If a future change proposes a new runtime UI dependency, stop and review because dependency
footprint is a recorded high-blast-radius boundary.

## Implementation Constraints

- The build scripts generate and ship the `rindle-admin` CSS layer.
- Contrast gating covers console token pairs.
- The `:rindle` OTP app serves the generated assets.
- Screenshot polish uses this CSS contract rather than one-off styles.
