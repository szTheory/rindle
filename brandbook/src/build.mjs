// Rindle logo candidate builder.
//
// Outlines the "rindle" wordmark from Space Grotesk Medium (text -> paths, so no
// viewer font dependency), composes each candidate from candidates.mjs, and writes
// light / dark / mono / mark / subtitle SVG variants to ../assets/logo/candidates/.
//
// Run: node build.mjs

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import opentype from 'opentype.js';
import { PALETTE, FONT_SIZE, PAD, svgDoc, r2 } from './geometry.mjs';
import { headgate, headwaterR, branchDot, outflowE, confluence } from './candidates.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const outDir = join(here, '..', 'assets', 'logo', 'candidates');
mkdirSync(outDir, { recursive: true });

function loadFont(file) {
  const buf = readFileSync(join(here, 'fonts', file));
  return opentype.parse(buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength));
}

const grotesk = loadFont('SpaceGrotesk-Medium.ttf');
const atkinson = loadFont('AtkinsonHyperlegible-Regular.ttf');

// --- wordmark path builders -------------------------------------------------

function textPath(font, text, size = FONT_SIZE) {
  // serialize commands ourselves: toPathData(2) emits data Chromium chokes on
  // partway through the full "rindle" string (path silently truncates)
  const p = font.getPath(text, 0, 0, size, { kerning: true });
  return { d: contours(p.commands).map(commandsToD).join(' '), width: font.getAdvanceWidth(text, size) };
}

// split a path's command list into contours (M ... Z groups)
function contours(commands) {
  const out = [];
  let cur = [];
  for (const c of commands) {
    if (c.type === 'M' && cur.length) {
      out.push(cur);
      cur = [];
    }
    cur.push(c);
  }
  if (cur.length) out.push(cur);
  return out;
}

function contourBox(cont) {
  const xs = [], ys = [];
  for (const c of cont) {
    for (const k of ['x', 'x1', 'x2']) if (c[k] !== undefined) xs.push(c[k]);
    for (const k of ['y', 'y1', 'y2']) if (c[k] !== undefined) ys.push(c[k]);
  }
  return { x1: Math.min(...xs), y1: Math.min(...ys), x2: Math.max(...xs), y2: Math.max(...ys) };
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

// full wordmark with the i tittle contour removed (candidate C replaces it)
function wordmarkWithoutTittle() {
  const p = grotesk.getPath('rindle', 0, 0, FONT_SIZE, { kerning: true });
  const keep = contours(p.commands).filter((cont) => {
    const b = contourBox(cont);
    const isTittle = b.y2 <= -55 && b.x1 >= 43 && b.x2 <= 60; // i dot, word coords
    return !isTittle;
  });
  return { d: keep.map(commandsToD).join(' '), width: grotesk.getAdvanceWidth('rindle', FONT_SIZE) };
}

// standalone i glyph (with tittle removed) for candidate C's mark
function iGlyphSansTittle() {
  const p = grotesk.charToGlyph('i').getPath(0, 0, FONT_SIZE);
  const keep = contours(p.commands).filter((cont) => contourBox(cont).y2 > -55);
  return keep.map(commandsToD).join(' ');
}

// --- rendering ----------------------------------------------------------------

function renderParts(parts, { base, accent }) {
  return parts
    .map((p) => {
      const color = p.role === 'accent' ? accent : base;
      const dx = p.dx ? ` transform="translate(${r2(p.dx)} 0)"` : '';
      if (p.stroke) {
        return `  <path d="${p.d}" fill="none" stroke="${color}" stroke-width="${p.sw}" stroke-linecap="round" stroke-linejoin="round"${dx}/>`;
      }
      return `  <path d="${p.d}" fill="${color}"${dx}/>`;
    })
    .join('\n');
}

function wrap(c, parts, scheme, { box = null, title, desc }) {
  const x1 = (box ? box.x1 : 0) - PAD;
  const y1 = (box ? box.y1 : c.top) - PAD;
  const x2 = (box ? box.x2 : c.width) + PAD;
  const y2 = (box ? box.y2 : c.bottom) + PAD;
  const body = `<g transform="translate(${r2(-x1)} ${r2(-y1)})">\n${renderParts(parts, scheme)}\n</g>`;
  return svgDoc({ width: x2 - x1, height: y2 - y1, body, title, desc });
}

const SCHEMES = {
  light: { base: PALETTE.deep, accent: PALETTE.green },
  dark: { base: PALETTE.porcelain, accent: PALETTE.green },
  mono: { base: 'currentColor', accent: 'currentColor' },
};

// --- compose candidates ---------------------------------------------------------

const fullWord = textPath(grotesk, 'rindle');
const indleWord = textPath(grotesk, 'indle');
const sansTittle = wordmarkWithoutTittle();

const candidates = [
  headgate(fullWord),
  headwaterR(indleWord),
  (() => {
    const c = branchDot(sansTittle);
    // mark: the bare i glyph + branch motif, scaled into its own viewbox
    const iD = iGlyphSansTittle();
    c.markParts = [
      { d: iD, fill: true },
      { d: 'M 10.6 -57.8 a 5 5 0 1 0 4.4 0 a 5 5 0 1 0 -4.4 0 Z', fill: true, role: 'accent' },
    ];
    // simpler: rebuild mark parts in build-time coords (i glyph spans x 5.7..19.9)
    const cx = 12.8;
    c.markParts = [
      { d: iD, fill: true },
      { d: `M ${cx - 5} -60 a 5 5 0 1 0 10 0 a 5 5 0 1 0 -10 0 Z`, fill: true, role: 'accent' },
      { d: `M ${cx - 2.2} -63.4 L 2.5 -78`, stroke: true, sw: 3, role: 'accent' },
      { d: `M ${cx + 2.2} -63.4 L 23 -78`, stroke: true, sw: 3, role: 'accent' },
      { d: `M -1 -81 a 3.5 3.5 0 1 0 7 0 a 3.5 3.5 0 1 0 -7 0 Z`, fill: true, role: 'accent' },
      { d: `M 19.5 -81 a 3.5 3.5 0 1 0 7 0 a 3.5 3.5 0 1 0 -7 0 Z`, fill: true, role: 'accent' },
    ];
    c.markBox = { x1: -6, y1: -87, x2: 28, y2: 2 };
    return c;
  })(),
  outflowE(fullWord),
  confluence(fullWord),
];

const TAGLINE = 'Media, made durable.';

for (const c of candidates) {
  const baseName = `candidate-${c.id}`;
  const meta = (variant) => ({
    title: `Rindle logo candidate ${c.id.toUpperCase()} - ${c.name} (${variant})`,
    desc: c.concept,
  });

  writeFileSync(join(outDir, `${baseName}.svg`), wrap(c, c.parts, SCHEMES.light, meta('light')));
  writeFileSync(join(outDir, `${baseName}-dark.svg`), wrap(c, c.parts, SCHEMES.dark, meta('dark')));
  writeFileSync(join(outDir, `${baseName}-mono.svg`), wrap(c, c.parts, SCHEMES.mono, meta('monochrome')));

  if (c.markParts) {
    writeFileSync(
      join(outDir, `${baseName}-mark.svg`),
      wrap(c, c.markParts, SCHEMES.light, { ...meta('mark'), box: c.markBox })
    );
    writeFileSync(
      join(outDir, `${baseName}-mark-dark.svg`),
      wrap(c, c.markParts, SCHEMES.dark, { ...meta('mark dark'), box: c.markBox })
    );
  }

  // with-subtitle variant: tagline set in Atkinson under the wordmark
  const tagSize = 24;
  const tag = textPath(atkinson, TAGLINE, tagSize);
  const tagW = tag.width;
  const wordX = c.parts.find((p) => p.dx)?.dx ?? 0;
  const tagY = c.bottom + 34;
  const subtitleParts = [
    ...c.parts,
    { d: tag.d, fill: true, dx: wordX, dy: tagY, isTag: true },
  ];
  const bodyParts = subtitleParts
    .map((p) => {
      const color = p.isTag ? PALETTE.slateTag ?? '#52605A' : p.role === 'accent' ? SCHEMES.light.accent : SCHEMES.light.base;
      const tx = p.dx ? r2(p.dx) : 0;
      const ty = p.dy ? r2(p.dy) : 0;
      const tr = tx || ty ? ` transform="translate(${tx} ${ty})"` : '';
      if (p.stroke) {
        return `  <path d="${p.d}" fill="none" stroke="${color}" stroke-width="${p.sw}" stroke-linecap="round" stroke-linejoin="round"${tr}/>`;
      }
      return `  <path d="${p.d}" fill="${color}"${tr}/>`;
    })
    .join('\n');
  const sx1 = -PAD;
  const sy1 = c.top - PAD;
  const sx2 = Math.max(c.width, wordX + tagW) + PAD;
  const sy2 = tagY + 8 + PAD;
  const subtitleSvg = svgDoc({
    width: sx2 - sx1,
    height: sy2 - sy1,
    body: `<g transform="translate(${r2(-sx1)} ${r2(-sy1)})">\n${bodyParts}\n</g>`,
    title: `Rindle logo candidate ${c.id.toUpperCase()} - ${c.name} (with subtitle)`,
    desc: `${c.concept} Subtitle variant carries the tagline; the main lockup never does.`,
  });
  writeFileSync(join(outDir, `${baseName}-subtitle.svg`), subtitleSvg);
}

console.log(`wrote ${candidates.length} candidates x (light, dark, mono, subtitle${candidates.every((c) => c.markParts) ? ', mark' : ''}) to ${outDir}`);
