// The five Rindle logo direction candidates.
//
// Each candidate returns { id, name, parts, markParts, width, top, bottom, wordX }:
//   parts     - full lockup drawing instructions (mark + wordmark)
//   markParts - standalone mark/monogram for favicon tests (null = wordmark-only concept)
//   top/bottom- y extent of the artwork (baseline = 0, negative = up)
//
// A "part" is { d, fill } for filled paths, or { d, stroke, sw } for stroked paths,
// plus optional { role: 'accent' } - accent parts take the accent color; everything
// else takes the base color. Mono renders collapse both to one color.
//
// Hard constraints (locked, .planning/research/b1.0-brand-audit.md SS8):
//   - no background/container shapes of any kind
//   - logotype tight to the mark
//   - no subtitle in these lockups

import { MARK_GAP, STEM } from './geometry.mjs';

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

function dot(cx, cy, r) {
  // circle as path so every part is a <path>
  return `M ${cx - r} ${cy} a ${r} ${r} 0 1 0 ${2 * r} 0 a ${r} ${r} 0 1 0 ${-2 * r} 0 Z`;
}

// ---------------------------------------------------------------------------
// A. Headgate - mark + type. The brand idea drawn literally: a protected
//    current. An open arch (the headgate that admits water to a rindle)
//    shelters a current line that flows straight through it and out both
//    sides - the stream breaks the mark's own boundary; nothing contains it.
// ---------------------------------------------------------------------------

export function headgate(word) {
  const arch =
    'M 10 -20 ' +
    'C 10 -46 19 -60 37 -60 ' +
    'C 55 -60 64 -46 64 -20';
  const current =
    'M 0 -13.5 ' +
    'C 14 -19.5 26 -8.5 38 -13.5 ' +
    'C 49 -18 60 -10.5 74 -15';
  const asset = dot(38, -13.5, 5.2);

  const markW = 78;
  const parts = [
    { d: arch, stroke: true, sw: 8.5 },
    { d: current, stroke: true, sw: 7, role: 'accent' },
    { d: asset, fill: true },
    { d: word.d, fill: true, dx: markW + MARK_GAP },
  ];
  const markParts = [
    { d: arch, stroke: true, sw: 8.5 },
    { d: current, stroke: true, sw: 7, role: 'accent' },
    { d: asset, fill: true },
  ];
  return {
    id: 'a',
    name: 'Headgate',
    concept: 'A protected current, literally: the gate shelters the asset; the stream flows through unbroken.',
    weakness: 'Arch + current + dot is three elements; the favicon cut may drop the dot.',
    parts,
    markParts,
    markBox: { x1: -5, y1: -66, x2: 79, y2: 0 },
    width: markW + MARK_GAP + word.width,
    top: -70,
    bottom: 4,
  };
}

// ---------------------------------------------------------------------------
// B. Headwater r - integrated typemark + monogram. The wordmark's own "r" is
//    redrawn as one continuous stroke: stem, shoulder, then the terminal keeps
//    travelling - curling down past the baseline and back under itself,
//    sheltering a source dot in the pocket it creates. rindle has no
//    descenders, so the curl owns the space below the baseline (boundary-break).
// ---------------------------------------------------------------------------

export function headwaterR(word) {
  const sw = STEM; // letter portion matches the font's stem weight
  const swTail = 6; // the continuation thins as it flows
  // the letter: stem + shoulder, unmistakably an r - the arm stops high,
  // exactly where the font's own r terminal sits
  const rLetter =
    'M 12.8 -5.2 ' +
    'L 12.8 -28 ' +
    'C 12.8 -39.5 18 -44.2 26.5 -44.2 ' +
    'C 32.5 -44.2 36.5 -41.5 38.5 -38';
  // the continuation: a thin swash from the terminal, flowing down-right past
  // the baseline and onward toward the rest of the word
  const rTail =
    'M 38.5 -38 ' +
    'C 42.5 -28 41.5 -12 46.5 -3 ' +
    'C 49.5 2.5 54.5 4.5 60 3.5';
  // the carried asset rides the tail's bend
  const bead = dot(46.6, -4.5, 4.4);

  const rAdvance = 56; // custom r is wider than the font's 38.7
  const parts = [
    { d: rLetter, stroke: true, sw },
    { d: rTail, stroke: true, sw: swTail },
    { d: bead, fill: true, role: 'accent' },
    { d: word.d, fill: true, dx: rAdvance }, // word is "indle" here
  ];
  const markParts = [
    { d: rLetter, stroke: true, sw },
    { d: rTail, stroke: true, sw: swTail },
    { d: bead, fill: true, role: 'accent' },
  ];
  return {
    id: 'b',
    name: 'Headwater r',
    concept: 'The r itself is the channel: it shelters the asset and dips below the baseline.',
    weakness: 'The pocket dot may need to drop out at 16px (simplified favicon cut).',
    parts,
    markParts,
    markBox: { x1: 2, y1: -52, x2: 48, y2: 12 },
    width: rAdvance + word.width,
    top: -70,
    bottom: 10,
  };
}

// ---------------------------------------------------------------------------
// C. Branch dot - integrated typemark. The tittle of the i becomes the source
//    asset: a dot at tittle height branching up into two smaller variant dots
//    that rise above the ascender line (the type breaks its own bounding box
//    upward - no container anywhere).
// ---------------------------------------------------------------------------

export function branchDot(word) {
  // word here is the full wordmark *minus* the i tittle contour
  const src = { x: 51.5, y: -60 };
  const branchL = `M ${src.x - 2.2} ${src.y - 3.4} L 41.5 -78`;
  const branchR = `M ${src.x + 2.2} ${src.y - 3.4} L 61.5 -78`;
  const parts = [
    { d: word.d, fill: true },
    { d: dot(src.x, src.y, 5), fill: true, role: 'accent' },
    { d: branchL, stroke: true, sw: 3, role: 'accent' },
    { d: branchR, stroke: true, sw: 3, role: 'accent' },
    { d: dot(41.5, -81, 3.5), fill: true, role: 'accent' },
    { d: dot(61.5, -81, 3.5), fill: true, role: 'accent' },
  ];
  // standalone mark: the i glyph alone with its branch (for favicon test)
  const markParts = null; // built in build.mjs from the i glyph
  return {
    id: 'c',
    name: 'Branch dot',
    concept: 'The dot on the i is the original asset branching into variants.',
    weakness: 'Full wordmark dies at 16px (all wordmarks do); favicon is the i-glyph alone.',
    parts,
    markParts,
    width: word.width,
    top: -86,
    bottom: 2,
  };
}

// ---------------------------------------------------------------------------
// D. Outflow e - integrated typemark. The terminal of the final e keeps going:
//    a thin current line trails out of the word, dips below the baseline, and
//    carries one delivered asset with it. The gesture is exit/delivery -
//    media leaves rindle ready (boundary-break to the right and below).
// ---------------------------------------------------------------------------

export function outflowE(word) {
  const tail =
    'M 262 -8.5 ' +
    'C 273 -3.5 283 -0.5 295 1 ' +
    'C 309 2.8 322 2.4 336 0.5';
  const bead = dot(317, 1.8, 4.4);
  const parts = [
    { d: word.d, fill: true },
    { d: tail, stroke: true, sw: 4, role: 'accent' },
    { d: bead, fill: true, role: 'accent' },
  ];
  return {
    id: 'd',
    name: 'Outflow e',
    concept: 'Media flows out of rindle, ready - the tail carries a delivered asset.',
    weakness: 'Needs width; favicon pairs with a simple bead-on-line glyph.',
    parts,
    markParts: [
      { d: 'M 2 -22 C 14 -14 26 -10 38 -9 C 50 -8 60 -10 70 -14', stroke: true, sw: 7 },
      { d: dot(52, -9.2, 7), fill: true, role: 'accent' },
    ],
    markBox: { x1: -2, y1: -34, x2: 74, y2: 4 },
    width: 340,
    top: -72,
    bottom: 8,
  };
}

// ---------------------------------------------------------------------------
// E. Confluence - mark + type, interlocked. Three input streams (uploads,
//    formats, sources) converge into one durable current that runs on beneath
//    the first letters of the wordmark - the mark and the type physically
//    interlock instead of sitting apart (boundary-break, no container).
// ---------------------------------------------------------------------------

export function confluence(word) {
  const sw = 6.5;
  const inTop = 'M 0 -59 C 14 -59 28 -54 39 -46.5';
  const inMid = 'M 6 -43.5 C 17 -43.5 28 -43.5 39 -43.5';
  const inBot = 'M 0 -28 C 14 -28 28 -33 39 -40.5';
  // merged current: heavier, sweeps down past the baseline and runs clear
  // beneath the first letters of the wordmark, ending under the i
  const exit =
    'M 40 -43.5 ' +
    'C 53 -43 60 -36 63.5 -26 ' +
    'C 67.5 -14 74 -2 87 3.5 ' +
    'C 98 8 110 9.5 122 9.5 ' +
    'L 140 9.5';

  const markW = 64;
  const wordX = markW + 14; // tighter than MARK_GAP: the exit interlocks
  const parts = [
    { d: inTop, stroke: true, sw, role: 'accent' },
    { d: inMid, stroke: true, sw },
    { d: inBot, stroke: true, sw },
    { d: exit, stroke: true, sw: 10.5 },
    { d: word.d, fill: true, dx: wordX },
  ];
  const markParts = [
    { d: inTop, stroke: true, sw, role: 'accent' },
    { d: inMid, stroke: true, sw },
    { d: inBot, stroke: true, sw },
    { d: 'M 37 -43.5 C 51 -43 59 -36 63 -26 C 67 -15 71 -8 79 -4', stroke: true, sw: 10.5 },
  ];
  return {
    id: 'e',
    name: 'Confluence',
    concept: 'Many inputs, one durable current - it runs on under the name.',
    weakness: 'Three inputs become two at favicon size.',
    parts,
    markParts,
    markBox: { x1: -4, y1: -64, x2: 86, y2: 4 },
    width: wordX + word.width,
    top: -70,
    bottom: 13,
  };
}
