// WCAG 2.1 contrast gate over the pairs declared in tokens.json.
// Exits non-zero if any pair falls below its declared minimum.
// Run: node contrast.mjs

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const T = JSON.parse(readFileSync(join(here, '..', 'tokens', 'tokens.json'), 'utf8'));
const raw = T.color.raw;

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
for (const p of T.contrast_pairs) {
  const fg = raw[p.fg], bg = raw[p.bg];
  if (!fg || !bg) {
    rows.push(`?? ${p.fg} on ${p.bg}: unknown token`);
    failures++;
    continue;
  }
  const r = ratio(fg, bg);
  const ok = r >= p.min;
  if (!ok) failures++;
  rows.push(`${ok ? 'PASS' : 'FAIL'}  ${r.toFixed(2).padStart(6)} >= ${p.min}  ${p.fg} on ${p.bg}  (${p.context})`);
}
console.log(rows.join('\n'));
console.log(`\n${T.contrast_pairs.length - failures}/${T.contrast_pairs.length} pairs pass`);
if (failures) process.exit(1);
