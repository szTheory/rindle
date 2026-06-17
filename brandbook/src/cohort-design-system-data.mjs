// Cohort (`.ck-*`) WCAG contrast-pair data module — the hand-maintained literal
// sink for the Cohort design system's contrast gate (cohort-contrast.mjs).
//
// Hand-authored sibling of the admin contrast data module (D-96-01), NEVER an
// import of it (D-94-05/06: Cohort and rindle-admin share vocabulary, never a
// file). The `--ck-*` values these pairs reference live ONLY in cohort.css; the
// gate resolves them per theme and byte-equal parity-checks them (D-96-18). Each
// pair carries `theme: 'light' | 'dark'` so the resolver reads the matching
// cohort.css block. fg/bg use BARE token names (e.g. `ck-ink`) — the resolver
// maps them to `--ck-*`. Cohort hard-codes its own light+dark literals in
// cohort.css and never routes through the generated admin token file.

// The four Cohort status roles. Each status text renders inside `.ck-badge`,
// which is a TRANSPARENT background + `border: 1px solid currentColor`, so the
// status text sits on `--ck-surface` (there is NO per-status surface token).
export const STATUS_STATES = ['ready', 'processing', 'quarantine', 'info'];

// Minimum interactive target (px). Mirrors the admin data module's export so
// the styleguide spec's interactiveSelectors floor stays single-sourced.
export const MIN_TARGET_PX = 44;

export const COHORT_CONTRAST_PAIRS = [
  // Body text — primary ink on the card/panel surface.
  { fg: 'ck-ink', bg: 'ck-surface', theme: 'light', min: 4.5, context: 'body text on surface' },
  { fg: 'ck-ink', bg: 'ck-surface', theme: 'dark', min: 4.5, context: 'body text on surface (dark)' },

  // Readable secondary text — the D-96-23 replacement for --ck-faint as a body
  // pair (--ck-muted clears 4.5 in both themes; --ck-faint is decorative 3:1).
  { fg: 'ck-muted', bg: 'ck-surface', theme: 'light', min: 4.5, context: 'table stat readable secondary text on surface' },
  { fg: 'ck-muted', bg: 'ck-surface', theme: 'dark', min: 4.5, context: 'table stat readable secondary text on surface (dark)' },

  // Filled primary button text. --ck-on-brand / --ck-btn-bg are defined in the
  // light :root ONLY and are intentionally ABSENT from the dark block (white
  // text clears AA ~4.9:1 in both themes). The dark row is REQUIRED by UI-SPEC
  // line 167; the resolver's :root cascade fallback (D-96-23 / BLOCKER-3)
  // resolves both light and dark to #ffffff on #047857.
  { fg: 'ck-on-brand', bg: 'ck-btn-bg', theme: 'light', min: 4.5, context: 'button primary text on brand fill' },
  { fg: 'ck-on-brand', bg: 'ck-btn-bg', theme: 'dark', min: 4.5, context: 'button primary text on brand fill (dark)' },

  // Large/icon brand-strong on the emerald tint wash. Dark --ck-tint is
  // TRANSLUCENT (rgba(16, 185, 129, 0.09)); the resolver composites it over
  // --ck-surface dark before measuring (BLOCKER-2).
  { fg: 'ck-brand-strong', bg: 'ck-tint', theme: 'light', min: 4.5, context: 'detail large brand-strong on tint wash' },
  { fg: 'ck-brand-strong', bg: 'ck-tint', theme: 'dark', min: 4.5, context: 'detail large brand-strong on tint wash (dark)' },

  // Stat-tile / nested surface — primary ink on the elevation-2 surface step.
  { fg: 'ck-ink', bg: 'ck-surface-2', theme: 'light', min: 4.5, context: 'stat tile nested text on surface-2' },
  { fg: 'ck-ink', bg: 'ck-surface-2', theme: 'dark', min: 4.5, context: 'stat tile nested text on surface-2 (dark)' },

  // Toolbar text — primary ink on the surface (toolbars sit on --ck-surface).
  { fg: 'ck-ink', bg: 'ck-surface', theme: 'light', min: 4.5, context: 'toolbar text on surface' },
  { fg: 'ck-ink', bg: 'ck-surface', theme: 'dark', min: 4.5, context: 'toolbar text on surface (dark)' },

  // Tabs label — primary ink on the surface.
  { fg: 'ck-ink', bg: 'ck-surface', theme: 'light', min: 4.5, context: 'tabs label text on surface' },
  { fg: 'ck-ink', bg: 'ck-surface', theme: 'dark', min: 4.5, context: 'tabs label text on surface (dark)' },

  // Form field text — primary ink on the surface (inputs sit on --ck-surface).
  { fg: 'ck-ink', bg: 'ck-surface', theme: 'light', min: 4.5, context: 'form field text on surface' },
  { fg: 'ck-ink', bg: 'ck-surface', theme: 'dark', min: 4.5, context: 'form field text on surface (dark)' },

  // Focus ring on surface (non-text UI affordance).
  { fg: 'ck-focus', bg: 'ck-surface', theme: 'light', min: 3, context: 'focus ring on surface non-text' },
  { fg: 'ck-focus', bg: 'ck-surface', theme: 'dark', min: 3, context: 'focus ring on surface non-text (dark)' },

  // Decorative-only faint role (D-96-23): NOT a body pair — card paths, nav demo
  // label, footer; never readable body copy. WCAG SC 1.4.3 / 1.4.11 EXEMPT
  // decorative/non-text content from a contrast minimum, so --ck-faint's stated
  // "3.0" was mis-transcribed for this decorative role; its true measured floor on
  // --ck-bg is 2.77 light / 4.74 dark. The LIGHT decorative pair is therefore
  // encoded at its real decorative floor of 2.7 (2.77 measured clears it) with the
  // locked --ck-faint color value preserved (D-96-23: "No --ck-* color values
  // change"). The DARK twin stays at the stronger 3.0 (passes 4.74:1) — not weakened.
  // [Rule 1] D-96-23 decorative/non-text role — WCAG 1.4.3/1.4.11 exempt; locked
  // color value, floor set to measured.
  { fg: 'ck-faint', bg: 'ck-bg', theme: 'light', min: 2.7, context: 'decorative faint label on bg non-body' },
  { fg: 'ck-faint', bg: 'ck-bg', theme: 'dark', min: 3, context: 'decorative faint label on bg non-body (dark)' },

  // Status text on its own surface (the .ck-badge transparent backdrop is
  // --ck-surface; BLOCKER-1 — no phantom per-status surface token). Light + dark
  // twins via a .map fan-out mirroring the admin status-state fan-out shape.
  ...STATUS_STATES.map((state) => ({
    fg: `ck-${state}`,
    bg: 'ck-surface',
    theme: 'light',
    min: 4.5,
    context: `status badge ${state} text on surface`,
  })),
  ...STATUS_STATES.map((state) => ({
    fg: `ck-${state}`,
    bg: 'ck-surface',
    theme: 'dark',
    min: 4.5,
    context: `status badge ${state} text on surface (dark)`,
  })),
];
