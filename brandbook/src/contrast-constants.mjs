// Shared contrast thresholds for the brandbook WCAG gates.
// Single source of truth so the runtime polish gate (admin-gallery-check.mjs)
// and the token-pair gates (admin-contrast.mjs / cohort-contrast.mjs via their
// data modules) cannot drift apart (D-12).
//
// WCAG 2.x AA minimum contrast for NORMAL-size text (< 18pt / < 14pt bold).
// Large-text (3:1) and non-text/decorative floors keep their own per-pair
// values — only the AA-normal 4.5:1 threshold is single-sourced here.
export const WCAG_AA_NORMAL = 4.5;
