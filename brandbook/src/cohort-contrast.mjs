// WCAG 2.1 contrast + parity + literal gate for the Cohort (`.ck-*`) design
// system. Net-new sibling of admin-contrast.mjs (D-96-01/02), but it resolves
// `--ck-*` directly from cohort.css per theme — it NEVER routes through the
// generated admin token file (D-94-05/06). Exits non-zero if any pair is below
// its declared minimum, any required {context × theme} pair is missing
// (coverage, D-96-19), any pair value drifts from cohort.css (parity, D-96-18),
// or any color literal lives outside a token-definition block (D-96-20).
//
// Run: node brandbook/src/cohort-contrast.mjs

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { COHORT_CONTRAST_PAIRS } from './cohort-design-system-data.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const COHORT_CSS_PATH = join(
  here,
  '..',
  '..',
  'examples',
  'adoption_demo',
  'priv',
  'static',
  'assets',
  'cohort.css',
);

// Allow an override path so the negative tests (planted literal / missing token)
// can point the same gate at a temp copy of cohort.css.
const cssPath = process.argv[2] || COHORT_CSS_PATH;
const css = readFileSync(cssPath, 'utf8');

const stripCssComments = (text) => text.replace(/\/\*[\s\S]*?\*\//g, '');

// --- WCAG sRGB-linearize + ratio (copied verbatim from admin-contrast.mjs) ---
const lum = (hex) => {
  const c = hex.replace('#', '');
  const [r, g, b] = [0, 2, 4].map((i) => {
    const v = parseInt(c.slice(i, i + 2), 16) / 255;
    return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};

const ratio = (a, b) => {
  const [l1, l2] = [lum(a), lum(b)].sort((x, y) => y - x);
  return (l1 + 0.05) / (l2 + 0.05);
};

// --- shared block extractor (reused by resolver + parity + literal scanner) ---
// Returns the raw body (between the outermost braces) of the FIRST top-level
// rule whose selector text contains `selectorNeedle`. Brace-depth aware so a
// nested block (e.g. the :root:not([data-theme]) inside the media query) does
// not confuse the top-level walk.
const extractBlock = (source, selectorNeedle) => {
  const text = stripCssComments(source);
  let i = 0;
  while (i < text.length) {
    const open = text.indexOf('{', i);
    if (open === -1) return null;
    const selector = text.slice(i, open).trim();
    // Walk to the matching close brace at depth 0.
    let depth = 1;
    let j = open + 1;
    while (j < text.length && depth > 0) {
      if (text[j] === '{') depth++;
      else if (text[j] === '}') depth--;
      j++;
    }
    const body = text.slice(open + 1, j - 1);
    if (selector.includes(selectorNeedle)) return body;
    i = j;
  }
  return null;
};

// The light token block is the combined `:root, [data-theme="light"]` selector;
// the dark block is the explicit `[data-theme="dark"]` attribute set; the
// `:root:not([data-theme])` block inside `@media (prefers-color-scheme: dark)` is
// the controlled byte-equal duplicate of the dark block (D-96-11). The parity
// check below asserts that duplicate stays byte-equal to the explicit dark block,
// so a hand-edit that drifts one block from the other hard-fails the build.
const lightBlock = extractBlock(css, '[data-theme="light"]');
const darkBlock = extractBlock(css, '[data-theme="dark"]');
// The auto-fallback dark set is the `:root:not([data-theme])` rule NESTED inside
// the `@media (prefers-color-scheme: dark)` block — extract the media body first,
// then the nested rule from within it (it is not a top-level selector).
const prefersDarkMedia = extractBlock(css, '@media (prefers-color-scheme: dark)');
const darkFallbackBlock = prefersDarkMedia
  ? extractBlock(prefersDarkMedia, ':root:not([data-theme])')
  : null;

// Read a single `--ck-x: <value>;` declaration's RAW value string from a block
// body. Returns undefined when the token is not declared in that block. The
// value is returned untouched (NOT normalized/parsed) so parity compares raw
// bytes uniformly for hex AND non-hex (rgba/color-mix) values.
const readDecl = (block, name) => {
  if (!block) return undefined;
  const re = new RegExp(`--${name}\\s*:\\s*([^;]+);`);
  const m = block.match(re);
  return m ? m[1].trim() : undefined;
};

// Resolve `ck-x` -> its RAW cohort.css value for the requested theme, mirroring
// real CSS custom-property cascade (BLOCKER-3 / D-96-23): for 'dark', look in
// the dark block FIRST, then FALL BACK to the light/:root block for
// theme-invariant brand tokens (--ck-btn-bg, --ck-on-brand, --ck-brand, ...)
// that live in :root only. Returns undefined ONLY when the token is absent from
// BOTH blocks — so a genuinely-missing dark token is NOT masked.
const resolveRaw = (name, theme) => {
  if (theme === 'dark') {
    const own = readDecl(darkBlock, name);
    if (own !== undefined) return own;
    return readDecl(lightBlock, name); // :root cascade fallback (narrow)
  }
  return readDecl(lightBlock, name);
};

// Composite a translucent value over a flat-hex backdrop B to a flat hex.
// rgba(r, g, b, a) over #RRGGBB -> per channel round(c*a + B*(1-a)).
const HEX6 = /^#[0-9a-fA-F]{6}$/;
const toByte = (n) => Math.max(0, Math.min(255, Math.round(n))).toString(16).padStart(2, '0');

const compositeOver = (channels, alpha, backdropHex) => {
  const b = backdropHex.replace('#', '');
  const [br, bg, bb] = [0, 2, 4].map((i) => parseInt(b.slice(i, i + 2), 16));
  const [r, g, bl] = channels;
  return `#${toByte(r * alpha + br * (1 - alpha))}${toByte(g * alpha + bg * (1 - alpha))}${toByte(bl * alpha + bb * (1 - alpha))}`;
};

// Convert a resolved RAW value to a flat hex for the WCAG measurement ONLY
// (never used for parity). Translucent values (rgba/color-mix) are composited
// over their REAL backdrop (--ck-surface for the same theme) before measuring,
// so we never feed an rgba()/color-mix() string into lum() (BLOCKER-2).
const toHex = (value, theme) => {
  if (value === undefined) return undefined;
  const v = value.trim();
  if (HEX6.test(v)) return v;

  const backdropRaw = resolveRaw('ck-surface', theme);
  const backdrop = backdropRaw && HEX6.test(backdropRaw.trim()) ? backdropRaw.trim() : '#ffffff';

  const rgba = v.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)/);
  if (rgba) {
    const channels = [Number(rgba[1]), Number(rgba[2]), Number(rgba[3])];
    const alpha = rgba[4] === undefined ? 1 : Number(rgba[4]);
    return compositeOver(channels, alpha, backdrop);
  }

  // color-mix(in srgb, <colorA> p%, <colorB>) — composite colorA over the
  // backdrop at p% (colorB defaults to the backdrop when not a flat hex).
  const mix = v.match(/color-mix\(\s*in\s+srgb\s*,\s*(#[0-9a-fA-F]{6})\s+([\d.]+)%\s*,\s*([^)]+)\)/);
  if (mix) {
    const a = mix[1];
    const p = Number(mix[2]) / 100;
    const bRaw = mix[3].trim();
    const over = HEX6.test(bRaw) ? bRaw : backdrop;
    const ah = a.replace('#', '');
    const [ar, ag, ab] = [0, 2, 4].map((i) => parseInt(ah.slice(i, i + 2), 16));
    return compositeOver([ar, ag, ab], p, over);
  }

  return undefined; // unknown/unmeasurable shape
};

let failures = 0;
const rows = [];

// --- coverage loop (D-96-19): fail on a MISSING required {context × theme} ---
// Each required context keyword MUST be present in BOTH a light AND a dark pair.
// The check is per-theme (filter the pair list by theme FIRST) so a missing
// light pair is not masked by its surviving dark twin — and vice versa — which
// is the D-94-08 "self-check green while artifact omits it" trap this guards.
const requiredContexts = ['body text', 'readable secondary text', 'button primary text', 'detail large', 'stat tile', 'toolbar text', 'tabs label', 'form field text', 'focus ring', 'decorative faint', 'status badge ready'];
for (const ctx of requiredContexts) {
  const lightHit = COHORT_CONTRAST_PAIRS.some((p) => p.theme === 'light' && p.context.includes(ctx));
  if (!lightHit) {
    rows.push(`FAIL      ?? >= coverage  ${ctx} (light)  (missing cohort contrast context)`);
    failures++;
  }
  const darkHit = COHORT_CONTRAST_PAIRS.some((p) => p.theme === 'dark' && p.context.includes(ctx));
  if (!darkHit) {
    rows.push(`FAIL      ?? >= coverage  ${ctx} (dark)  (missing cohort contrast context)`);
    failures++;
  }
}

// --- parity check (D-96-18): each pair value byte-equals cohort.css ----------
// Two independent assertions per token a pair references (raw STRING compares,
// so they work uniformly for hex AND non-hex rgba()/color-mix() values; never
// routed through toHex):
//   1. token-resolves: the resolver returns a defined RAW value (catches a
//      genuinely-missing token absent from BOTH blocks — unknown token fail).
//   2. dark-duplicate-parity: every token the resolver reads from the EXPLICIT
//      [data-theme="dark"] block must byte-equal the same token in the
//      :root:not([data-theme]) media-fallback duplicate (the controlled
//      duplication D-96-11; drift between the two blocks = hard fail). This is
//      the hand-authored-file equivalent of `git diff --exit-code` and is what
//      catches a value mutated in one block but not the other.
// A `Set` dedups the tokens (the pair list references each token many times).
const referencedTokens = new Set();
for (const p of COHORT_CONTRAST_PAIRS) {
  referencedTokens.add(`${p.theme || 'light'}::${p.fg}`);
  referencedTokens.add(`${p.theme || 'light'}::${p.bg}`);
}
for (const key of referencedTokens) {
  const [theme, name] = key.split('::');
  const resolved = resolveRaw(name, theme);
  if (resolved === undefined) {
    rows.push(`FAIL      ?? >= parity  --${name} (${theme})  (unknown token; absent from both blocks)`);
    failures++;
    continue;
  }
  // Only tokens that are actually DECLARED in the explicit dark block have a
  // media-fallback twin to parity-check; theme-invariant tokens resolved via the
  // :root cascade fallback live in :root only and have no dark duplicate (so they
  // are correctly skipped — parity does NOT demand they live in the dark block).
  if (theme === 'dark' && readDecl(darkBlock, name) !== undefined) {
    const explicit = readDecl(darkBlock, name);
    const fallback = readDecl(darkFallbackBlock, name);
    if (fallback === undefined) {
      rows.push(`FAIL      ?? >= parity  --${name} (dark)  (missing from prefers-color-scheme fallback block)`);
      failures++;
    } else if (explicit !== fallback) {
      rows.push(`FAIL      ?? >= parity  --${name} (dark)  (drift: explicit "${explicit}" !== fallback "${fallback}")`);
      failures++;
    }
  }
}

// --- per-pair WCAG assert (copied + adapted from admin-contrast.mjs:51-71) ----
for (const p of COHORT_CONTRAST_PAIRS) {
  const theme = p.theme || 'light';
  const fgRaw = resolveRaw(p.fg, theme);
  const bgRaw = resolveRaw(p.bg, theme);

  if (fgRaw === undefined || bgRaw === undefined) {
    rows.push(`FAIL      ?? >= ${p.min}  ${p.fg} on ${p.bg}  (${p.context}; ${theme}; unknown token)`);
    failures++;
    continue;
  }

  const fg = toHex(fgRaw, theme);
  const bg = toHex(bgRaw, theme);
  if (fg === undefined || bg === undefined) {
    rows.push(`FAIL      ?? >= ${p.min}  ${p.fg} on ${p.bg}  (${p.context}; ${theme}; unmeasurable value)`);
    failures++;
    continue;
  }

  const r = ratio(fg, bg);
  const ok = r >= p.min;
  if (!ok) failures++;
  rows.push(`${ok ? 'PASS' : 'FAIL'}  ${r.toFixed(2).padStart(6)} >= ${p.min}  ${p.fg} on ${p.bg}  (${p.context}; ${theme})`);
}

// --- literal scanner (D-96-20): hand-rolled brace-depth pass ------------------
// Hex/rgb/rgba/hsl literals are allowed ONLY inside the token-definition blocks
// (:root, [data-theme="light"], [data-theme="dark"], and the nested
// :root:not([data-theme]) under prefers-color-scheme). currentColor /
// transparent / color-mix are allowed anywhere. Any literal in another rule
// body fails. Reuses the comment-strip + brace-depth walk.
const scanLiterals = (source) => {
  const text = stripCssComments(source);
  const LITERAL = /#[0-9a-fA-F]{3,8}\b|\brgba?\(|\bhsla?\(/g;
  const TOKEN_SELECTORS = [':root', '[data-theme="light"]', '[data-theme="dark"]'];
  const offenders = [];

  // Walk top-level blocks by brace depth; recurse one level into @media so the
  // nested :root:not([data-theme]) token block is classified as a token sink.
  const walk = (s, atMediaPrefersColorScheme) => {
    let i = 0;
    while (i < s.length) {
      const open = s.indexOf('{', i);
      if (open === -1) break;
      const selector = s.slice(i, open).trim();
      let depth = 1;
      let j = open + 1;
      while (j < s.length && depth > 0) {
        if (s[j] === '{') depth++;
        else if (s[j] === '}') depth--;
        j++;
      }
      const body = s.slice(open + 1, j - 1);
      i = j;

      const isAtRule = selector.startsWith('@');
      if (isAtRule) {
        const isPrefersColorScheme = /prefers-color-scheme/.test(selector);
        // Recurse into at-rule bodies; nested :root inside a
        // prefers-color-scheme media query is a token sink.
        walk(body, isPrefersColorScheme);
        continue;
      }

      const isTokenSink =
        TOKEN_SELECTORS.some((sel) => selector.includes(sel)) &&
        // a bare nested :root inside prefers-color-scheme also counts
        true;
      const isNestedColorSchemeRoot = atMediaPrefersColorScheme && selector.includes(':root');

      if (isTokenSink || isNestedColorSchemeRoot) continue;

      // Rule body must not carry color literals (currentColor/transparent/
      // color-mix are fine — they don't match LITERAL).
      const hits = body.match(LITERAL);
      if (hits) offenders.push(`${selector.slice(0, 60)} -> ${[...new Set(hits)].join(', ')}`);
    }
  };

  walk(text, false);
  return offenders;
};

const literalOffenders = scanLiterals(css);
if (literalOffenders.length > 0) {
  for (const o of literalOffenders) {
    rows.push(`FAIL      ?? >= literal  ${o}  (color literal outside token block)`);
  }
  failures += literalOffenders.length;
}

console.log(rows.join('\n'));
console.log(`\ncohort contrast: ${COHORT_CONTRAST_PAIRS.length - failures}/${COHORT_CONTRAST_PAIRS.length} pairs pass`);
if (failures) process.exit(1);
