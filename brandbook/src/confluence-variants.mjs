// Confluence (candidate E) refinement round - generates focused variants of the
// user-selected direction plus a comparison sheet.
//
// Output: ../assets/logo/candidates/e-variants/  +  e-variants/sheet.html
// Run: node confluence-variants.mjs

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import opentype from 'opentype.js';
import { PALETTE, FONT_SIZE, PAD, svgDoc, r2 } from './geometry.mjs';
import { confluence } from './candidates.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, '..', 'assets', 'logo', 'candidates', 'e-variants');
mkdirSync(outDir, { recursive: true });

function loadFont(file) {
  const buf = readFileSync(join(here, 'fonts', file));
  return opentype.parse(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength));
}
const grotesk = loadFont('SpaceGrotesk-Medium.ttf');

function contours(commands) {
  const out = [];
  let cur = [];
  for (const c of commands) {
    if (c.type === 'M' && cur.length) { out.push(cur); cur = []; }
    cur.push(c);
  }
  if (cur.length) out.push(cur);
  return out;
}
function commandsToD(cmds) {
  let d = '';
  for (const c of cmds) {
    if (c.type === 'M') d += `M${r2(c.x)} ${r2(c.y)}`;
    else if (c.type === 'L') d += `L${r2(c.x)} ${r2(c.y)}`;
    else if (c.type === 'C') d += `C${r2(c.x1)} ${r2(c.y1)} ${r2(c.x2)} ${r2(c.y2)} ${r2(c.x)} ${r2(c.y)}`;
    else if (c.type === 'Q') d += `Q${r2(c.x1)} ${r2(c.y1)} ${r2(c.x)} ${r2(c.y)}`;
    else if (c.type === 'Z') d += 'Z';
  }
  return d;
}
const p = grotesk.getPath('rindle', 0, 0, FONT_SIZE, { kerning: true });
const word = { d: contours(p.commands).map(commandsToD).join(' '), width: grotesk.getAdvanceWidth('rindle', FONT_SIZE) };

const SCHEMES = {
  light: { base: PALETTE.deep, accent: PALETTE.green },
  dark: { base: PALETTE.porcelain, accent: PALETTE.green },
};

function renderParts(parts, { base, accent }) {
  return parts
    .map((q) => {
      const color = q.role === 'accent' ? accent : base;
      const dx = q.dx ? ` transform="translate(${r2(q.dx)} 0)"` : '';
      if (q.stroke) {
        return `  <path d="${q.d}" fill="none" stroke="${color}" stroke-width="${q.sw}" stroke-linecap="round" stroke-linejoin="round"${dx}/>`;
      }
      return `  <path d="${q.d}" fill="${color}"${dx}/>`;
    })
    .join('\n');
}

function wrap(c, parts, scheme, { box = null, title }) {
  const x1 = (box ? box.x1 : 0) - PAD;
  const y1 = (box ? box.y1 : c.top) - PAD;
  const x2 = (box ? box.x2 : c.width) + PAD;
  const y2 = (box ? box.y2 : c.bottom) + PAD;
  const body = `<g transform="translate(${r2(-x1)} ${r2(-y1)})">\n${renderParts(parts, scheme)}\n</g>`;
  return svgDoc({ width: x2 - x1, height: y2 - y1, body, title, desc: 'Rindle confluence variant' });
}

const VARIANTS = [
  {
    id: 'e1',
    name: 'Baseline (as picked)',
    note: 'Top tributary green, deep current, under-run ends below the i.',
    opts: {},
  },
  {
    id: 'e2',
    name: 'Green current',
    note: 'The merged current itself takes Rindle Green - the durable output is the brand-colored element.',
    opts: { exitAccent: true, topAccent: false },
  },
  {
    id: 'e3',
    name: 'Carried bead',
    note: 'All strokes deep; one green asset bead rides the current under the letters.',
    opts: { topAccent: false, bead: { x: 104, y: 9.5 } },
  },
  {
    id: 'e4',
    name: 'Long green current',
    note: 'Green current running on beneath "rin" - more underline presence.',
    opts: { exitAccent: true, topAccent: false, runEnd: 200 },
  },
  {
    id: 'e5',
    name: 'River junction',
    note: 'Tributaries enter like a watershed (steep, level, rising) + green bead riding the current.',
    opts: { river: true, topAccent: false, bead: { x: 104, y: 9.5 } },
  },
  {
    id: 'e6',
    name: 'River junction, green top',
    note: 'Watershed tributaries with the green on the entering stream (closest to the original).',
    opts: { river: true, topAccent: true },
  },
];

for (const v of VARIANTS) {
  const c = confluence(word, v.opts);
  c.id = v.id;
  writeFileSync(join(outDir, `${v.id}.svg`), wrap(c, c.parts, SCHEMES.light, { title: `Rindle confluence ${v.id} light` }));
  writeFileSync(join(outDir, `${v.id}-dark.svg`), wrap(c, c.parts, SCHEMES.dark, { title: `Rindle confluence ${v.id} dark` }));
  writeFileSync(
    join(outDir, `${v.id}-mark.svg`),
    wrap(c, c.markParts, SCHEMES.light, { box: c.markBox, title: `Rindle confluence ${v.id} mark` })
  );
}

const rows = VARIANTS.map(
  (v) => `
  <section class="v">
    <h2>${v.id.toUpperCase()} &mdash; ${v.name}</h2>
    <p>${v.note}</p>
    <div class="grid">
      <figure class="shell"><img class="hero" src="${v.id}.svg" alt=""></figure>
      <figure class="ink"><img class="hero" src="${v.id}-dark.svg" alt=""></figure>
      <figure class="shell sm"><img class="h56" src="${v.id}.svg" alt=""><img class="s40" src="${v.id}-mark.svg" alt=""><img class="s24" src="${v.id}-mark.svg" alt=""></figure>
    </div>
  </section>`
).join('\n');

writeFileSync(
  join(outDir, 'sheet.html'),
  `<!doctype html>
<!-- generated by brandbook/src/confluence-variants.mjs -->
<html lang="en"><head><meta charset="utf-8"><title>Rindle - Confluence refinement variants</title>
<style>
  :root { --ink:#101417; --deep:#123A35; --shell:#F7F4EA; --slate:#52605A; --border:#D9E0DA; }
  body { margin:0; padding:36px; background:#FBFEFC; color:var(--ink); font:15px/1.5 system-ui, sans-serif; }
  h1 { font-size:24px; margin:0 0 4px; } .note { color:var(--slate); }
  .v { margin-top:34px; border-top:1px solid var(--border); padding-top:18px; }
  h2 { font-size:18px; margin:0 0 2px; } .v p { margin:0 0 12px; color:var(--slate); font-size:13.5px; }
  .grid { display:flex; gap:14px; flex-wrap:wrap; }
  figure { margin:0; padding:20px 26px; border-radius:10px; display:flex; align-items:center; gap:20px; }
  .shell { background:var(--shell); } .ink { background:var(--ink); }
  .hero { height:88px; } .h56 { height:52px; } .s40 { height:40px; } .s24 { height:24px; }
</style></head><body>
<h1>Confluence &mdash; refinement variants</h1>
<p class="note">Direction E locked. Six executions; pick one (or mix: "e5 with e2's green current").</p>
${rows}
</body></html>
`
);
console.log(`wrote ${VARIANTS.length} variants + sheet to ${outDir}`);
