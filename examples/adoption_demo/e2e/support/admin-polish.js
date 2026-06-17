// Deterministic, in-browser "visual polish" gate for the Rindle admin console.
//
// This module replaces a former human screenshot-review checkpoint (Phase 92) with
// computed-style assertions that run on the exact rendered state of every screenshot
// capture. It runs inside the already merge-blocking `adoption-demo-e2e` CI lane, so
// adding it adds no CI jobs — only assertions to an existing spec.
//
// Each sub-assertion RETURNS its offenders (never throws); `assertAdminPolish`
// aggregates across all checks and throws a single error per state listing every
// violation, so one CI run reports all issues at once.
//
// WCAG math (`luminance`, `contrastRatio`, `parseColor`) is ported from
// brandbook/src/admin-gallery-check.mjs, matching the repo convention of per-script
// copies (see contrast.mjs / admin-contrast.mjs) rather than cross-package imports.

// Default surface targeting for the admin console. Callers (e.g. a future Cohort
// spec in Phase 102) may override `root` / `interactiveSelectors` via assertAdminPolish
// options to run this SAME gate over another surface (e.g. `[data-ck-root]` / `.ck-*`).
// The root is ALWAYS explicit (passed or defaulted) — there is no auto-detection
// (D-94-07: a page mounting both surfaces would match both roots and weaken the gate).
const DEFAULT_ROOT = "[data-rindle-admin-root]";
const MIN_TARGET_PX = 44; // mirrors brandbook/src/admin-design-system-data.mjs MIN_TARGET_PX
const SUBPIXEL_TOLERANCE = 0.5; // rect-rounding slack for target sizes
const CLIP_TOLERANCE = 1; // px slack for scrollWidth > clientWidth
const OVERLAP_TOLERANCE = 2; // px of allowed bbox intersection
const CONTRAST_SLACK = 0.05; // float slack on the WCAG ratio comparison

// Overlap is the noisiest check. Ship it in warn mode for one green CI cycle, then
// flip to a hard failure once the matrix confirms zero spurious warnings.
const OVERLAP_ENFORCED = false;

// Union of interactive-control selectors (all confirmed present in the admin shell).
const DEFAULT_INTERACTIVE_SELECTORS = [
  "[data-rindle-admin-submit]",
  "[data-rindle-admin-input]",
  '[data-rindle-admin-theme="light"]',
  '[data-rindle-admin-theme="dark"]',
  '[data-rindle-admin-theme="auto"]',
  "[data-rindle-admin-nav-item]",
  ".rindle-admin-actions-tab",
  "[data-rindle-admin-detail-link]",
  "[data-rindle-admin-action]",
];

// Per-surface, per-check opt-out. SHIP EMPTY — an allowlist that starts populated
// hides exactly the defects this gate exists to catch. Each entry must carry a
// justification comment and is a reviewable code change.
const POLISH_EXEMPTIONS = Object.freeze({
  // "surface-slug": new Set(["readableContrast"]), // why...
});

function isExempt(surface, check) {
  const set = POLISH_EXEMPTIONS[surface];
  return set ? set.has(check) : false;
}

// Freeze CSS transitions/animations so computed-style reads observe the SETTLED
// final state, not a mid-transition tween. Without this, reading colors right after
// a theme switch returns interpolated midpoints (e.g. a muddy gray between the dark
// and light surface), producing false contrast failures. This mirrors the
// determinism `page.screenshot({ animations: "disabled" })` already applies to the
// captured image. Re-applied per call because navigation discards the injected style.
async function freezeMotion(page) {
  await page.evaluate(() => {
    if (document.getElementById("__admin_polish_freeze__")) return;
    const style = document.createElement("style");
    style.id = "__admin_polish_freeze__";
    style.textContent =
      "*,*::before,*::after{transition:none !important;animation:none !important;}";
    document.head.appendChild(style);
  });
}

// --- ported WCAG utilities (Node-side; pages return serialized colors) ---

function luminance([r, g, b]) {
  const [rr, gg, bb] = [r, g, b].map((value) => {
    const channel = value / 255;
    return channel <= 0.04045 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4);
  });
  return 0.2126 * rr + 0.7152 * gg + 0.0722 * bb;
}

function contrastRatio(a, b) {
  const [l1, l2] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (l1 + 0.05) / (l2 + 0.05);
}

// Ported verbatim from brandbook/src/admin-gallery-check.mjs:208-217 (the comment above
// already lists `parseColor` among the ported WCAG utilities — it was referenced by
// assertFocusVisibleTokens but never actually defined here, so that check threw a
// ReferenceError the moment a focused control reached the outline-color comparison).
function parseColor(value) {
  const color = value.trim();
  const hex = color.match(/^#([0-9a-f]{6})$/i);
  if (hex) {
    return [0, 2, 4].map((offset) => parseInt(hex[1].slice(offset, offset + 2), 16));
  }
  const rgb = color.match(/^rgba?\((\d+),\s*(\d+),\s*(\d+)/);
  if (rgb) return rgb.slice(1, 4).map(Number);
  throw new Error(`could not parse computed color: ${value}`);
}

// ---------------------------------------------------------------------------
// Check 1 — clipped text
// ---------------------------------------------------------------------------
// Flags admin text elements whose content is genuinely clipped (overflow hidden/clip
// or text-overflow:ellipsis), excluding elements that intentionally wrap or scroll
// (white-space:pre-wrap, overflow-wrap:anywhere, overflow:auto/scroll) and the
// table-layout:fixed table element (which clips its border-radius, not text).
async function assertNoClippedText(page, root = DEFAULT_ROOT) {
  return page.evaluate(
    ({ ROOT, CLIP_TOLERANCE }) => {
      const root = document.querySelector(ROOT);
      if (!root) return [];
      const SCROLLABLE = new Set(["auto", "scroll"]);
      const CLIPS = new Set(["hidden", "clip"]);
      const WRAPS = new Set(["normal", "pre-wrap", "pre-line"]);
      const describe = (el) => {
        const id = el.id ? `#${el.id}` : "";
        const cls =
          typeof el.className === "string" && el.className.trim()
            ? "." + el.className.trim().split(/\s+/)[0]
            : "";
        return `${el.tagName.toLowerCase()}${id}${cls}`;
      };
      const hasOwnText = (el) =>
        Array.from(el.childNodes).some(
          (n) => n.nodeType === Node.TEXT_NODE && n.textContent.trim().length > 0
        );

      const out = [];
      for (const el of root.querySelectorAll("*")) {
        const rect = el.getBoundingClientRect();
        if (rect.width === 0 || rect.height === 0) continue;
        if (el.tagName === "TABLE") continue;
        if (!hasOwnText(el)) continue;

        const s = getComputedStyle(el);
        if (s.tableLayout && s.tableLayout !== "auto") continue;
        const wraps =
          WRAPS.has(s.whiteSpace) ||
          s.overflowWrap === "anywhere" ||
          s.overflowWrap === "break-word" ||
          s.wordBreak === "break-word" ||
          s.wordBreak === "break-all";

        const ox = s.overflowX;
        const oy = s.overflowY;
        const clippedX =
          el.scrollWidth > el.clientWidth + CLIP_TOLERANCE &&
          (CLIPS.has(ox) || s.textOverflow === "ellipsis") &&
          !SCROLLABLE.has(ox);
        const clippedY =
          !wraps &&
          el.scrollHeight > el.clientHeight + CLIP_TOLERANCE &&
          CLIPS.has(oy) &&
          !SCROLLABLE.has(oy);

        if ((clippedX && !wraps) || clippedY) {
          out.push(
            `${describe(el)}` +
              `${clippedX && !wraps ? ` x(${el.scrollWidth}>${el.clientWidth})` : ""}` +
              `${clippedY ? ` y(${el.scrollHeight}>${el.clientHeight})` : ""}` +
              ` text="${el.textContent.trim().slice(0, 40)}"`
          );
        }
      }
      return out;
    },
    { ROOT: root, CLIP_TOLERANCE }
  );
}

// ---------------------------------------------------------------------------
// Check 2 — readable contrast (highest defect-surfacing power)
// ---------------------------------------------------------------------------
// For every visible text-bearing element under the admin root, compute WCAG contrast
// of computed color vs the *effective* background, resolved by climbing ancestors and
// alpha-compositing layered/transparent backgrounds until an opaque fill is found.
// Gradient-backed text (no reachable opaque solid) is skipped-with-note, not failed.
async function assertReadableContrast(page, root = DEFAULT_ROOT) {
  const samples = await page.evaluate(
    ({ ROOT }) => {
      const root = document.querySelector(ROOT);
      if (!root) return [];
      const parse = (c) => {
        const m = c.match(/rgba?\(([^)]+)\)/);
        if (!m) return null;
        const p = m[1].split(",").map((x) => parseFloat(x.trim()));
        return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
      };
      const over = (fg, bg) => {
        const a = fg.a + bg.a * (1 - fg.a);
        if (a === 0) return { r: 0, g: 0, b: 0, a: 0 };
        const mix = (f, b) => (f * fg.a + b * bg.a * (1 - fg.a)) / a;
        return { r: mix(fg.r, bg.r), g: mix(fg.g, bg.g), b: mix(fg.b, bg.b), a };
      };
      const visible = (el) => {
        const r = el.getBoundingClientRect();
        const s = getComputedStyle(el);
        return (
          r.width > 0 &&
          r.height > 0 &&
          s.visibility !== "hidden" &&
          s.display !== "none" &&
          parseFloat(s.opacity) > 0
        );
      };
      const hasOwnText = (el) =>
        Array.from(el.childNodes).some(
          (n) => n.nodeType === Node.TEXT_NODE && n.textContent.trim().length > 0
        );
      const describe = (el) => {
        const cls =
          typeof el.className === "string" && el.className.trim()
            ? "." + el.className.trim().split(/\s+/)[0]
            : "";
        return `${el.tagName.toLowerCase()}${el.id ? "#" + el.id : ""}${cls}`;
      };

      const out = [];
      for (const el of root.querySelectorAll("*")) {
        if (!hasOwnText(el) || !visible(el)) continue;
        const cs = getComputedStyle(el);
        const fg = parse(cs.color);
        if (!fg) continue;

        let bg = { r: 255, g: 255, b: 255, a: 1 }; // page-white fallback
        let gradientSeen = false;
        const layers = [];
        for (
          let node = el;
          node && node !== document.documentElement.parentNode;
          node = node.parentElement
        ) {
          const ns = getComputedStyle(node);
          if (ns.backgroundImage && ns.backgroundImage !== "none") gradientSeen = true;
          const layer = parse(ns.backgroundColor);
          if (layer && layer.a > 0) {
            layers.push(layer);
            if (layer.a === 1) {
              bg = layer;
              break;
            }
          }
          if (node === document.documentElement) break;
        }
        let eff = bg;
        for (let i = layers.length - 1; i >= 0; i--) {
          if (layers[i].a < 1) eff = over(layers[i], eff);
        }
        const composedFg = fg.a < 1 ? over(fg, eff) : fg;

        const size = parseFloat(cs.fontSize);
        const weight = parseInt(cs.fontWeight, 10) || 400;
        const large = size >= 24 || (size >= 18.66 && weight >= 700);

        out.push({
          selector: describe(el),
          color: [composedFg.r, composedFg.g, composedFg.b],
          bg: [eff.r, eff.g, eff.b],
          threshold: large ? 3.0 : 4.5,
          gradient: gradientSeen && eff.a < 1,
          text: el.textContent.trim().slice(0, 40),
        });
      }
      return out;
    },
    { ROOT: root }
  );

  const failures = [];
  for (const s of samples) {
    if (s.gradient) continue; // can't deterministically resolve over a gradient
    const ratio = contrastRatio(s.color, s.bg);
    if (ratio + CONTRAST_SLACK < s.threshold) {
      const rgb = (c) => `rgb(${c.map((n) => Math.round(n)).join(",")})`;
      failures.push(
        `${s.selector} ratio ${ratio.toFixed(2)}:1 < ${s.threshold}:1 ` +
          `color=${rgb(s.color)} bg=${rgb(s.bg)} text="${s.text}"`
      );
    }
  }
  return failures;
}

// ---------------------------------------------------------------------------
// Check 3 — target sizes (44px interactive controls)
// ---------------------------------------------------------------------------
async function assertTargetSizes(page, interactiveSelectors = DEFAULT_INTERACTIVE_SELECTORS) {
  return page.locator(interactiveSelectors.join(",")).evaluateAll(
    (els, { MIN, TOL }) => {
      const out = [];
      for (const el of els) {
        const s = getComputedStyle(el);
        if (s.display === "none" || s.visibility === "hidden") continue;
        if (el.offsetParent === null && s.position !== "fixed") continue; // hidden / unselected tab panel
        if (el.closest("[hidden],[aria-hidden='true']")) continue;
        const r = el.getBoundingClientRect();
        if (r.width === 0 && r.height === 0) continue;
        if (r.width < MIN - TOL || r.height < MIN - TOL) {
          const cls =
            typeof el.className === "string" && el.className.trim()
              ? "." + el.className.trim().split(/\s+/)[0]
              : "";
          out.push(`${el.tagName.toLowerCase()}${cls} ${r.width.toFixed(1)}x${r.height.toFixed(1)} < ${MIN}`);
        }
      }
      return out;
    },
    { MIN: MIN_TARGET_PX, TOL: SUBPIXEL_TOLERANCE }
  );
}

// ---------------------------------------------------------------------------
// Check 4 — token-backed focus-visible and no bare outline removal
// ---------------------------------------------------------------------------
async function assertFocusVisibleTokens(page, interactiveSelectors = DEFAULT_INTERACTIVE_SELECTORS) {
  const offenders = await page.evaluate(() => {
    const out = [];
    for (const sheet of Array.from(document.styleSheets)) {
      let rules = [];
      try {
        rules = Array.from(sheet.cssRules || []);
      } catch (_error) {
        continue;
      }
      for (const rule of rules) {
        const cssText = rule.cssText || "";
        if (/outline\s*:\s*none\b/i.test(cssText.replace(/\/\*[\s\S]*?\*\//g, ""))) {
          out.push(`outline-none-rule: ${cssText.slice(0, 120)}`);
        }
      }
    }
    return out;
  });

  for (const selector of interactiveSelectors) {
    const locator = page.locator(selector);
    const count = await locator.count();
    for (let index = 0; index < count; index++) {
      const item = locator.nth(index);
      if (!(await item.isVisible().catch(() => false))) continue;
      if (await item.isDisabled().catch(() => false)) continue;
      await item.evaluate((element) => element.focus({ focusVisible: true })).catch(() => {});
      const state = await item.evaluate((element) => {
        if (document.activeElement !== element && !element.matches(":focus-within")) return null;
        const styles = getComputedStyle(element);
        const root = getComputedStyle(document.documentElement);
        return {
          tag: element.tagName.toLowerCase(),
          selector:
            element.getAttribute("data-rindle-admin-theme") ||
            element.getAttribute("data-rindle-admin-action") ||
            element.getAttribute("data-rindle-admin-detail-link") ||
            element.getAttribute("data-rindle-admin-input") ||
            element.className ||
            element.id ||
            element.tagName.toLowerCase(),
          outlineWidth: styles.outlineWidth,
          outlineColor: styles.outlineColor,
          outlineOffset: styles.outlineOffset,
          expectedWidth: root.getPropertyValue("--rindle-focus-width").trim(),
          expectedColor: root.getPropertyValue("--rindle-focus-ring").trim(),
          expectedOffset: root.getPropertyValue("--rindle-focus-offset").trim(),
        };
      });
      if (!state) continue;
      if (state.outlineWidth !== state.expectedWidth) {
        offenders.push(`${selector} ${state.selector} outlineWidth ${state.outlineWidth} != ${state.expectedWidth}`);
      }
      if (state.outlineOffset !== state.expectedOffset) {
        offenders.push(`${selector} ${state.selector} outlineOffset ${state.outlineOffset} != ${state.expectedOffset}`);
      }
      // Report an unparseable/missing outline color (e.g. a root that does not define the
      // expected focus-ring token) as an offender rather than throwing — matching the
      // offender-collecting contract of the width/offset checks above, so a single bad value
      // surfaces as a reviewable mismatch instead of aborting the whole gate run.
      let colorMismatch = false;
      try {
        const actual = parseColor(state.outlineColor);
        const expected = parseColor(state.expectedColor);
        colorMismatch = actual.some((value, channel) => Math.abs(value - expected[channel]) > 1);
      } catch (_error) {
        colorMismatch = true;
      }
      if (colorMismatch) {
        offenders.push(`${selector} ${state.selector} outlineColor ${state.outlineColor} != ${state.expectedColor}`);
      }
    }
  }

  return offenders;
}

// ---------------------------------------------------------------------------
// Check 5 — no interactive overlap (noisiest; warn-then-tighten)
// ---------------------------------------------------------------------------
async function assertNoInteractiveOverlap(page, interactiveSelectors = DEFAULT_INTERACTIVE_SELECTORS) {
  return page.locator(interactiveSelectors.join(",")).evaluateAll(
    (els, { TOL }) => {
      const visible = (el) => {
        const s = getComputedStyle(el);
        if (s.display === "none" || s.visibility === "hidden") return false;
        if (el.offsetParent === null && s.position !== "fixed") return false;
        const r = el.getBoundingClientRect();
        return r.width > 0 && r.height > 0;
      };
      const items = els.filter(visible).map((el) => ({
        el,
        group: el.parentElement,
        r: el.getBoundingClientRect(),
        tag: el.tagName.toLowerCase(),
      }));
      const intersect = (a, b) =>
        a.left + TOL < b.right - TOL &&
        b.left + TOL < a.right - TOL &&
        a.top + TOL < b.bottom - TOL &&
        b.top + TOL < a.bottom - TOL;
      const contains = (a, b) =>
        a.left <= b.left && a.top <= b.top && a.right >= b.right && a.bottom >= b.bottom;

      const out = [];
      for (let i = 0; i < items.length; i++) {
        for (let j = i + 1; j < items.length; j++) {
          const A = items[i];
          const B = items[j];
          if (A.group !== B.group) continue; // only direct siblings
          if (A.el.contains(B.el) || B.el.contains(A.el)) continue;
          if (contains(A.r, B.r) || contains(B.r, A.r)) continue;
          if (intersect(A.r, B.r)) {
            out.push(
              `${A.tag} overlaps ${B.tag} ` +
                `[${A.r.left.toFixed(0)},${A.r.top.toFixed(0)} vs ${B.r.left.toFixed(0)},${B.r.top.toFixed(0)}]`
            );
          }
        }
      }
      return out;
    },
    { TOL: OVERLAP_TOLERANCE }
  );
}

// ---------------------------------------------------------------------------
// Check 6 — stable / correctly-sized rasterization
// ---------------------------------------------------------------------------
// Decode PNG IHDR (pure Node, no dependency): after the 8-byte signature there is a
// 4-byte length, the "IHDR" tag, then width and height as big-endian uint32.
function pngSize(buf) {
  if (buf.length < 24 || buf.toString("ascii", 12, 16) !== "IHDR") {
    throw new Error("not a PNG / missing IHDR");
  }
  return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
}

async function assertStableDimensions(page) {
  const dpr = await page.evaluate(() => window.devicePixelRatio);
  const viewport = page.viewportSize();
  const expectedWidth = Math.round(viewport.width * dpr);

  const a = await page.screenshot({ animations: "disabled", fullPage: true });
  const b = await page.screenshot({ animations: "disabled", fullPage: true });
  const sa = pngSize(a);
  const sb = pngSize(b);

  const failures = [];
  if (sa.width !== sb.width || sa.height !== sb.height) {
    failures.push(`non-deterministic capture: ${sa.width}x${sa.height} then ${sb.width}x${sb.height}`);
  }
  if (sa.width !== expectedWidth) {
    failures.push(
      `unexpected device width: got ${sa.width}, expected ${expectedWidth} ` +
        `(viewport ${viewport.width} * dpr ${dpr})`
    );
  }
  return failures;
}

// ---------------------------------------------------------------------------
// Check 7 — consistent intra-unit rhythm (4px grid ∪ {12,44})
// ---------------------------------------------------------------------------
// Walks ONLY descendants of `[data-rindle-admin-meta]` units (the intra-unit
// requirement — scoping to meta subtrees dramatically cuts noise) and asserts the
// rhythm-bearing box properties resolve to the design system's spacing grid. Only
// `rowGap`/`columnGap`/top-bottom `margin`/the four `padding` sides are checked;
// sizing (`height`/`width`/`min-height`) and `line-height` are intentionally
// excluded because they legitimately carry off-grid values (the 28px chip min-height,
// the 44px target minimum, fluid widths, line-box metrics). Horizontal margins are
// excluded too (`margin: 0 auto` centering resolves to arbitrary px). `0px` is always
// valid. Allowed set is `{4,8,16,24,32,48,64}` (the declared spacing multiples) plus
// the two documented exceptions `{12,44}` (the table-cell padding step and the target
// minimum). RETURNS offenders `"{slug} {tag} {prop}={px}px off-grid"`; never throws.
//
// Only elements the design system actually styles are measured: an element is inspected
// when it carries a `rindle-admin-*` class. Native form-control internals (an `<option>`
// padded by the user-agent stylesheet, a checkbox `<input>`'s UA margin) and bare
// typographic elements (`<p>`/`<h2>` relying on the user-agent's em-based margins) carry
// box metrics the generated CSS never sets — including them would surface the browser's
// defaults, not off-grid token spacing (Pitfall 1: offenders all at UA-default values mean
// the walk is too wide, not that the CSS is off-grid).
async function assertConsistentRhythm(page, root = DEFAULT_ROOT) {
  return page.evaluate(
    ({ ROOT, ALLOWED, EXEMPT_PX, TOL }) => {
      const onGrid = (px) =>
        EXEMPT_PX.some((v) => Math.abs(px - v) <= TOL) ||
        ALLOWED.some((v) => Math.abs(px - v) <= TOL);
      const styled = (el) =>
        typeof el.className === "string" &&
        el.className.split(/\s+/).some((c) => c.startsWith("rindle-admin-"));
      const PROPS = [
        "rowGap",
        "columnGap",
        "marginTop",
        "marginBottom",
        "paddingTop",
        "paddingBottom",
        "paddingLeft",
        "paddingRight",
      ];
      const out = [];
      for (const unit of document.querySelectorAll(`${ROOT} [data-rindle-admin-meta]`)) {
        const slug = unit.getAttribute("data-rindle-admin-meta") || "?";
        for (const el of [unit, ...unit.querySelectorAll("*")]) {
          if (!styled(el)) continue; // measure only design-system-owned box metrics
          const s = getComputedStyle(el);
          for (const prop of PROPS) {
            const px = parseFloat(s[prop]);
            if (!Number.isFinite(px) || px === 0) continue; // 0px / unset always valid
            if (!onGrid(px)) {
              out.push(`${slug} ${el.tagName.toLowerCase()} ${prop}=${px}px off-grid`);
            }
          }
        }
      }
      return out;
    },
    { ROOT: root, ALLOWED: [4, 8, 16, 24, 32, 48, 64], EXEMPT_PX: [12, 44], TOL: SUBPIXEL_TOLERANCE }
  );
}

// ---------------------------------------------------------------------------
// Check 8 — no horizontal overflow per meta-unit root
// ---------------------------------------------------------------------------
// The PER-UNIT counterpart to the page-level no-horizontal-scroll helper in
// support/admin.js (which asserts the document + admin root only — do NOT duplicate
// it here). This iterates each `[data-rindle-admin-meta]` unit root and flags one
// whose `scrollWidth` exceeds its `clientWidth` (a unit that overflows its own box).
// A unit that legitimately owns an internal scroll region (the sticky data table)
// opts out via the explicit `[data-rindle-admin-scroll-region]` marker — D-94-07:
// explicit opt-in, never auto-detected. RETURNS offenders `"{slug} x(sw>cw)"`;
// never throws.
async function assertNoHorizontalScroll(page, root = DEFAULT_ROOT) {
  return page.evaluate(
    ({ ROOT, CLIP_TOLERANCE }) => {
      const out = [];
      for (const unit of document.querySelectorAll(`${ROOT} [data-rindle-admin-meta]`)) {
        if (unit.closest("[data-rindle-admin-scroll-region]")) continue; // explicit opt-in
        const slug = unit.getAttribute("data-rindle-admin-meta") || "?";
        if (unit.scrollWidth > unit.clientWidth + CLIP_TOLERANCE) {
          out.push(`${slug} x(${unit.scrollWidth}>${unit.clientWidth})`);
        }
      }
      return out;
    },
    { ROOT: root, CLIP_TOLERANCE }
  );
}

// ---------------------------------------------------------------------------
// Orchestrator
// ---------------------------------------------------------------------------
async function assertAdminPolish(
  page,
  {
    viewport,
    surface,
    root = DEFAULT_ROOT,
    interactiveSelectors = DEFAULT_INTERACTIVE_SELECTORS,
  } = {}
) {
  await freezeMotion(page); // settle transitions before any computed-style read

  const violations = [];
  const warnings = [];

  const run = async (name, prefix, fn, { warnOnly = false } = {}) => {
    if (isExempt(surface, name)) return;
    const offenders = await fn();
    for (const offender of offenders) {
      const line = `${prefix}: ${offender}`;
      if (warnOnly) warnings.push(line);
      else violations.push(line);
    }
  };

  await run("noClippedText", "clipped-text", () => assertNoClippedText(page, root));
  await run("consistentRhythm", "rhythm", () => assertConsistentRhythm(page, root));
  await run("noHorizontalScroll", "h-scroll", () => assertNoHorizontalScroll(page, root));
  await run("readableContrast", "contrast", () => assertReadableContrast(page, root));
  await run("targetSizes", "target-size", () => assertTargetSizes(page, interactiveSelectors));
  await run("focusVisibleTokens", "focus-visible", () => assertFocusVisibleTokens(page, interactiveSelectors));
  await run("noInteractiveOverlap", "overlap", () => assertNoInteractiveOverlap(page, interactiveSelectors), {
    warnOnly: !OVERLAP_ENFORCED,
  });
  await run("stableDimensions", "stable-dimensions", () => assertStableDimensions(page));

  if (warnings.length) {
    // eslint-disable-next-line no-console
    console.warn(
      `[admin-polish] surface="${surface}" viewport="${viewport}" ` +
        `${warnings.length} warning(s):\n  ${warnings.join("\n  ")}`
    );
  }
  if (violations.length) {
    throw new Error(
      `Admin polish gate failed for surface="${surface}" viewport="${viewport}" ` +
        `(${violations.length} violation${violations.length === 1 ? "" : "s"}):\n  ` +
        violations.join("\n  ")
    );
  }
}

module.exports = {
  assertAdminPolish,
  freezeMotion,
  assertNoClippedText,
  assertConsistentRhythm,
  assertNoHorizontalScroll,
  assertReadableContrast,
  assertTargetSizes,
  assertFocusVisibleTokens,
  assertNoInteractiveOverlap,
  assertStableDimensions,
  luminance,
  contrastRatio,
  pngSize,
  MIN_TARGET_PX,
  OVERLAP_ENFORCED,
};
