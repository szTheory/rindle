// WCAG 2.1 contrast gate for Rindle Admin console component token pairs.
// Exits non-zero if any pair is unknown or below its declared minimum.
// Run: node admin-contrast.mjs

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { CONSOLE_CONTRAST_PAIRS } from './admin-design-system-data.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const T = JSON.parse(readFileSync(join(here, '..', 'tokens', 'tokens.json'), 'utf8'));
const raw = T.color.raw;

const deref = (v) => v.replace(/\{([a-z0-9-]+)\}/g, (_, k) => {
  if (!(k in raw)) throw new Error(`unknown raw token reference: {${k}}`);
  return raw[k];
});

const resolve = (name, theme) => {
  if (name in raw) return raw[name];
  const semantic = T.color.semantic[theme] || {};
  if (name in semantic) return deref(semantic[name]);
  return null;
};

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

let failures = 0;
const rows = [];
const contexts = CONSOLE_CONTRAST_PAIRS.map((p) => p.context).join(' ');
for (const requiredContext of ['buttons', 'form controls', 'table', 'focus', 'status chips processing', 'toasts', 'confirm dialog', 'drawer', 'empty state', 'error state', 'loading state', 'skeleton', 'borders']) {
  if (!contexts.includes(requiredContext)) {
    rows.push(`FAIL      ?? >= coverage  ${requiredContext}  (missing console contrast context)`);
    failures++;
  }
}

for (const p of CONSOLE_CONTRAST_PAIRS) {
  const theme = p.theme || 'light';
  const fg = resolve(p.fg, theme);
  const bg = resolve(p.bg, theme);

  if (!fg || !bg) {
    rows.push(`FAIL      ?? >= ${p.min}  ${p.fg} on ${p.bg}  (${p.context}; ${theme}; unknown token)`);
    failures++;
    continue;
  }

  const r = ratio(fg, bg);
  const ok = r >= p.min;
  if (!ok) failures++;
  rows.push(`${ok ? 'PASS' : 'FAIL'}  ${r.toFixed(2).padStart(6)} >= ${p.min}  ${p.fg} on ${p.bg}  (${p.context}; ${theme})`);
}

console.log(rows.join('\n'));
console.log(`\nadmin contrast: ${CONSOLE_CONTRAST_PAIRS.length - failures}/${CONSOLE_CONTRAST_PAIRS.length} pairs pass`);
if (failures) process.exit(1);
