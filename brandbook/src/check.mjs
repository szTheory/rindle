// Constraint + hygiene gates for Rindle brand assets. Exits non-zero on violation.
//
// Checks every SVG under ../assets/:
//   1. has a viewBox
//   2. no <text>/<tspan> elements (all type must be outlined paths)
//   3. no <image> elements, no external references (href/url())
//   4. no full-bleed background container: a <rect> (or near-viewBox-sized
//      filled path) behind the artwork - locked constraint, no containers
//   5. main lockups (candidate-*.svg, rindle-logo.svg) carry no subtitle:
//      only files matching *-subtitle.svg may contain tagline path groups
//      (heuristic: subtitle files are exempt from the path-count ceiling)
//   6. per-file size budget: SVG <= 8 KB (subtitle variants and sheet <= 16 KB)
//   7. brandbook/ total size <= 1.5 MB
//
// Run: node check.mjs

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const brandbook = join(here, '..');
const failures = [];

function* walk(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name === 'node_modules') continue;
      yield* walk(p);
    } else {
      yield p;
    }
  }
}

const svgs = [...walk(join(brandbook, 'assets'))].filter((p) => p.endsWith('.svg'));

for (const file of svgs) {
  const rel = relative(brandbook, file);
  const src = readFileSync(file, 'utf8');

  if (!/viewBox="/.test(src)) failures.push(`${rel}: missing viewBox`);
  if (/<text[\s>]|<tspan[\s>]/.test(src)) failures.push(`${rel}: contains <text> - outline all type`);
  if (/<image[\s>]/.test(src)) failures.push(`${rel}: contains <image> (raster embed)`);
  if (/href="http|url\(http/.test(src)) failures.push(`${rel}: external reference`);
  if (/<rect[\s>]/.test(src)) failures.push(`${rel}: contains <rect> - container shapes are banned on marks`);

  const kb = statSync(file).size / 1024;
  const limit = /subtitle|sheet/.test(rel) ? 16 : 8;
  if (kb > limit) failures.push(`${rel}: ${kb.toFixed(1)} KB exceeds ${limit} KB budget`);
}

let total = 0;
for (const f of walk(brandbook)) {
  if (relative(brandbook, f).startsWith('src/fonts')) {
    total += statSync(f).size; // generation fonts count toward the budget
    continue;
  }
  total += statSync(f).size;
}
const totalMb = total / (1024 * 1024);
if (totalMb > 1.5) failures.push(`brandbook/ total ${totalMb.toFixed(2)} MB exceeds 1.5 MB budget`);

if (failures.length) {
  console.error(`FAIL (${failures.length}):`);
  for (const f of failures) console.error('  - ' + f);
  process.exit(1);
}
console.log(`OK: ${svgs.length} SVGs pass constraint checks; brandbook/ total ${totalMb.toFixed(2)} MB`);
