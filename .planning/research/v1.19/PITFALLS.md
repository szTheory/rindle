# Pitfalls Research

**Domain:** Fractal design-system audit + daisyUI→custom-DS migration on an existing Phoenix LiveView app (v1.19 Design-System Stress-Test)
**Researched:** 2026-06-14
**Confidence:** HIGH (repo-verified for the regression/idempotency/token surfaces; MEDIUM for animation + screenshot tuning, verified against current Playwright + LiveView docs)

> Scope note: this milestone restyles **working** LiveView flows and audits an **already-shipped** admin DS. The dominant risk is not "ugly UI" — it is **silently breaking working flows or thrashing prior work** while chasing an "award-winning" bar. Pitfalls below are ordered by that mandate: regression → idempotency → a11y → theme → animation → token-pipeline → visual-regression → scope.

---

## Critical Pitfalls

### Pitfall 1: Restyling breaks behavior because tests, hooks, and bindings are coupled to the markup you're changing

**What goes wrong:**
The inner Cohort pages do not separate "style classes" from "behavior anchors." On the same elements that carry daisyUI/Tailwind classes (`btn`, `tabs tabs-boxed`, `text-red-600`), there are also `data-testid`, `id`, `phx-hook`, `phx-change`, `phx-submit`, and `<.live_file_input>` attributes that the app's JS hooks and the Playwright suite depend on. Verified in `examples/adoption_demo/lib/adoption_demo_web/live/upload_live.ex`: e.g. `id="image-file-input" phx-hook="PresignedPut" data-testid="image-file-input"`, `phx-hook="MultipartUpload"`, `<.form phx-change="tus_changed" phx-submit="save_tus">`. Hooks `PresignedPut, PresignedVideoPut, PresignedMuxPut, MultipartUpload, Copy` are registered in `priv/static/assets/js/app.js` (`hooks: {…}`) and several push `push_event("presigned", …)` round-trips. A naive "replace the daisyUI classes" pass that also renames/moves the element, drops the `id`, or restructures the `<.form>` will silently kill upload, multipart, copy-to-clipboard, and tab navigation — and the visual restyle will look "done."

**Why it happens:**
Restyling feels like a pure-CSS task, so the migrator treats `class=` as the only thing to touch. But in this repo a single `<input>`/`<button>` is simultaneously a style target, a hook mount point (`phx-hook` requires a stable `id`), a LiveView event source (`phx-*`), and an E2E selector (`data-testid`/`id`). daisyUI classes (`btn`, `tabs`) look incidental but some are visually load-bearing for the current screenshots; the behavior attributes look incidental but are functionally load-bearing.

**How to avoid:**
- **Migrate class-by-class, never element-by-element.** Swap the value of `class=` (daisyUI/Tailwind → `cohort_components` / `cohort.css` BEM `.ck-*`) and leave `id`, `data-testid`, `phx-hook`, `phx-change`, `phx-submit`, `phx-click`, `name`, `for`, and `<.live_file_input>`/`<.form>` structure byte-for-byte intact. Treat behavior attributes as a frozen contract.
- **Establish a pre-migration selector inventory** as the regression contract: `grep -roh 'data-testid="[^"]*"' lib/adoption_demo_web/live/` and the `phx-hook`/`id` set, snapshot it, and assert the post-migration page still exposes every one. (Inventory already partially captured in research; ~40+ testids exist.)
- **Prefer routing behavior through `CohortComponents` function components** (as `cohort_components.ex` already does — e.g. the `cred/1` copy button carries `phx-hook="Copy"` + stable `id` internally). When you move markup into a component, the component must re-expose the same `id`/`data-testid`/`phx-*` via attrs/`:global`, not absorb them.
- **Run the existing Playwright behavior specs (not just screenshots) after every page**: `image-upload.spec.js`, `multipart-upload.spec.js`, `tus-resume.spec.js`, `liveview-upload.spec.js`, `mux-streaming.spec.js`, `ops-surfaces.spec.js`, `batch-erasure.spec.js`, `owner-erasure.spec.js`, `replace-detach.spec.js`. These select by `data-testid`/`getByTestId` and exercise the real flows — they are the regression net, distinct from the pixel matrix.

**Warning signs:**
- A diff that deletes or renames an `id`, `data-testid`, or `phx-hook` on an interactive element.
- A behavior spec that starts timing out (`waitForLiveSocket` succeeds but `getByTestId(...).click()` does nothing) — a sign a hook lost its mount `id`.
- Copy buttons that no longer copy, file inputs that no longer trigger presign — hook detached.

**Phase to address:**
Owned by **every Cohort inner-page restyle phase (Track 2)** as a hard gate; the roadmap should make "behavior specs green + selector-inventory preserved" a non-negotiable success criterion of each page phase, not a final QA phase.

---

### Pitfall 2: "Uplift" passes thrash — re-running undoes or double-applies prior work

**What goes wrong:**
The charter mandates **idempotent / no-regression**: "each run only moves quality forward; safe to re-run several times." The natural failure is a pass that is *not* a pure function of (tokens + current source). Examples specific to this repo: a pass that hand-edits generated `rindle-admin.css` (so the next `node admin-css-build.mjs` reverts it), a pass that appends a one-off `.ck-card` override that a later pass appends *again* (duplicate rules, last-wins thrash), or a pass that "improves" microcopy by rewriting strings a prior pass already finalized, producing oscillating wording between runs.

**Why it happens:**
Per-decision subagent research + one-shot synthesis means many independent passes touch overlapping surfaces (a component, then its meta-component group, then the page). Without a forward-only convention, pass N and pass N+2 fight over the same selector/string. Generated artifacts (`rindle-admin.css` from `tokens.json` via `.mjs`) make hand-edits actively destructive: they look applied but vanish on regenerate.

**How to avoid:**
- **Single source of truth per surface, enforced:** admin visuals derive *only* from `tokens.json` → `admin-css-build.mjs` → `rindle-admin.css` (+ `priv/static/rindle_admin/rindle-admin.css`). Never hand-edit a generated file. The generator already self-checks parity and exits non-zero on drift (`tokens-build.mjs` pattern) — extend that, don't bypass it.
- **Forward-only = convergent, not additive.** Each pass should *rewrite a declared region to its computed target*, not append. For `cohort.css`/`cohort_components.ex`, scope each component's styles to a single owned block so a re-run replaces (not stacks) it. Avoid "add an override at the bottom" patterns — they are the classic non-idempotent move.
- **Microcopy lives in the component/template, finalized once per surface**, tied to the persona/JTBD in `guides/user_flows.md`. A pass may only change copy if the *flow's* JTBD changed, not on aesthetic whim. Record the finalized string so later passes treat it as locked.
- **Make idempotency testable:** a CI/local check that runs the generator twice and asserts `git diff` is empty after the second run (generated artifacts), and that re-running a restyle pass on an already-migrated page is a no-op diff.

**Warning signs:**
- `git diff` on a generated CSS file after running the generator (means someone hand-edited it).
- Duplicate selectors / stacked overrides accumulating at the bottom of `cohort.css`.
- The same string flip-flopping between two phrasings across passes.
- A "re-run for safety" producing a non-empty diff.

**Phase to address:**
Owned by an early **Track-1 "DS pipeline & idempotency harness" phase** that locks the generated-artifact contract and the double-run check before any uplift pass runs; enforced thereafter by every phase.

---

### Pitfall 3: Focus-visible and keyboard a11y silently lost during restyle

**What goes wrong:**
daisyUI ships default `:focus-visible` rings, focus management on its `modal`/`dropdown`/`drawer`, and sensible focus order. Migrating off it onto bespoke `.ck-*`/`.rindle-admin-*` BEM means **you inherit none of that for free**. Common regressions: focus ring removed (or `outline: none` with no replacement), focus-visible not implemented on custom buttons/links/tabs, focus order broken when markup is reordered for visual layout, custom menus/dialogs/drawers/toasts/tables shipped without correct ARIA roles/`aria-expanded`/`aria-modal`/`aria-live`, dialogs/drawers without focus trap + restore + `Esc`, and tables losing header association.

**Why it happens:**
The quality bar (WCAG AA, keyboard, focus, ARIA) is explicit, but a11y is invisible in a screenshot and in a quick mouse click-through. A restyle that "looks award-winning" passes the eye test while keyboard and screen-reader paths rot. The framework safety net (daisyUI/Tailwind plugin defaults) is exactly what's being removed.

**How to avoid:**
- **Token-backed focus is mandatory and centralized.** The brand system already defines `--rindle-focus-ring/-width/-offset` and `brand.css`/admin patterns apply `:focus-visible { outline: var(--rindle-focus-width) solid var(--rindle-focus-ring); outline-offset: var(--rindle-focus-offset); }`. Every interactive `.ck-*`/`.rindle-admin-*` selector must carry an equivalent `:focus-visible` rule; never `outline:none` without a visible replacement.
- **ARIA-author custom widgets to the APG pattern**, not by vibes: menus (`role=menu`, roving tabindex, `aria-expanded`), dialogs/drawers (`role=dialog` / `aria-modal=true`, focus trap, `Esc` close, focus restore to invoker), toasts (`role=status`/`aria-live=polite`; errors `assertive`), tables (`<th scope>` + caption), tabs (`role=tablist`/`tab`/`tabpanel` + arrow keys — note `upload_live.ex` currently uses plain `<.link>` "tabs", which is acceptable as nav-tabs but must keep `aria-current`).
- **Keyboard pass is a required reviewer step**, not optional: Tab through every restyled surface, confirm visible focus at each stop, logical order, no keyboard trap in drawers/dialogs, and `Esc`/restore.
- Reuse the established Phase 88 rule: "every state indicator needs visible text plus an icon or non-color mark, token-gated contrast, and focus-visible coverage" — apply it to Cohort too.

**Warning signs:**
- `outline: none` / `outline: 0` anywhere in `cohort.css` or generated admin CSS without a paired focus style.
- Tabbing produces no visible ring, or jumps in an illogical order.
- A drawer/dialog where Tab cycles into the page behind it, or `Esc` doesn't close.
- Custom menu/table/toast with no `role`/`aria-*`.

**Phase to address:**
Owned by an **a11y-baseline phase early in Track 1** (define the focus/ARIA contract once), then enforced as a per-phase `/gsd:ui-review` pillar on every restyle phase. Should ship an automated axe-core / keyboard assertion in the Playwright suite as the durable gate.

---

### Pitfall 4: Dark-mode drift — hardcoded colors bypass tokens; contrast/elevation break only in dark

**What goes wrong:**
The admin system is correctly token-driven (`[data-theme="dark"]` + `[data-theme="auto"]` media query, generated from `tokens.json`). The **Cohort `cohort.css` system does not yet have an equivalent dark contract** (verified: needs the dark/system theme + reduced-motion added during migration). Restyling inner pages introduces dark-mode for the first time on those surfaces. Failure modes: hardcoded hex (`#…`) or Tailwind color literals (`text-red-600` already present in `upload_live.ex`) that don't flip in dark; text that passes contrast in light but fails AA in dark; shadows/elevation tuned for a light surface that become invisible or muddy on a dark surface (dark elevation needs lighter surface tints, not bigger shadows); status tints (`ready/processing/quarantine`) that lose their chip-vs-text contrast in one theme.

**Why it happens:**
Authors test in their default theme and eyeball the other once. Tailwind/daisyUI encourage literal color utilities (`text-red-600`) that have no token indirection, so they silently survive a "restyle" and never theme. Elevation-via-shadow is a light-mode idiom that designers carry into dark without rethinking.

**How to avoid:**
- **No raw color literals in restyled markup or CSS** — every color is `var(--rindle-*)` / `var(--ck-*)` resolving through the theme scope. Add a lint/grep gate: fail if `#[0-9a-fA-F]{3,6}` or Tailwind color utilities (`text-(red|green|…)-\d`) appear in restyled inner-page templates or in `cohort.css` component blocks. `upload_live.ex`'s `text-red-600` is a concrete instance to convert to a token-backed error class.
- **Extend the mechanical contrast gate to both themes.** The repo already has `contrast.mjs`/`admin-contrast.mjs` (WCAG ratio math + `contrast_pairs` exit-non-zero). Add dark-theme pairs for every chip/text/button/empty/disabled/focus combination, for **both** admin and Cohort. Contrast must be proven in dark, not assumed.
- **Elevation via surface tokens, not heavier shadow, in dark.** Define `--*-surface-raised` tokens per theme; in dark, raise by lightening the surface and softening shadow. Verify cards/drawers/menus read as "above" in both themes.
- **Bring Cohort onto the same `[data-theme]` contract** (`dark` + `auto` media query) the admin uses — do not invent a `.dark`/Tailwind-dark parallel convention (Phase 88 planner rule).

**Warning signs:**
- Any `#hex` or `text-{color}-{n}` in restyled templates/CSS.
- A contrast pair defined for light but missing its dark sibling.
- A card/drawer that looks flat or vanishes in dark; a status chip unreadable in one theme.
- Screenshots reveal a control that's fine in light, illegible in dark.

**Phase to address:**
Owned by the **Track-1 token/theme contract phase** (extend dark contrast pairs; add the no-literal lint), and the **first Cohort restyle phase** (introduce the `[data-theme]` dark contract to `cohort.css`). Verified by the light+dark screenshot matrix + contrast gate.

---

### Pitfall 5: LiveView DOM patching fights CSS transitions (and reduced-motion not honored)

**What goes wrong:**
On an "award-winning" animation pass you add CSS transitions to elements that LiveView re-patches (status chips updating via PubSub, upload-status `<p>` text, list rows). LiveView's morphdom patch can interrupt or re-trigger a `transition`/`@keyframes` mid-flight, producing flicker, double-play, or a stuck half-animated state — especially on `phx-update="stream"` rows and on text nodes that change every push. Separately, `cohort.css` currently has **no `prefers-reduced-motion` block** (verified), so any motion you add ignores reduced-motion users by default — a direct violation of the Emil-Kowalski / reduced-motion-aware mandate. Also: animating expensive properties (`width`, `height`, `top`, `box-shadow`, `background-position`) causes layout thrash/jank vs. compositor-friendly `transform`/`opacity`.

**Why it happens:**
CSS transitions are declared globally and authors don't think about which elements the server re-renders. The reduced-motion media query is easy to forget when starting from a stylesheet that never had one. Designers reach for the property that's intuitive (`height`) rather than the performant one (`transform: scaleY`).

**How to avoid:**
- **Coordinate motion with LiveView, don't fight it.** For enter/leave use `phx-mounted={JS.transition(...)}` and `phx-remove={JS.transition(...)}` (JS commands are DOM-patch-aware and stick across patches) rather than bare CSS transitions on server-patched nodes. Don't put `transition: all` on frequently-patched text/status nodes; transition only stable container properties.
- **Reduced-motion is a hard requirement, added to both stylesheets.** Wrap motion in `@media (prefers-reduced-motion: no-preference)` or add a `@media (prefers-reduced-motion: reduce){ *, ::before, ::after { animation: none !important; transition: none !important; scroll-behavior: auto !important; } }` safety net. Use only the established motion tokens (`--rindle-motion-press/popover/toast/transition`); keep failure/destructive feedback immediate.
- **Animate only `transform` and `opacity`** for movement/reveal; never animate layout-triggering properties on hot paths. The existing `.ck-reveal` pattern (with `--d` stagger) is the model — verify it's compositor-friendly and reduced-motion-gated.
- **Match the screenshot gate:** the admin matrix already captures with `animations: "disabled"`. Keep that, so motion never makes the visual proof flaky (see Pitfall 7).

**Warning signs:**
- `transition: all` or transitions on elements inside `phx-update="stream"`/frequently-pushed text.
- Flicker/double-animation when a PubSub update lands.
- No `prefers-reduced-motion` rule in `cohort.css`/`rindle-admin.css`.
- Jank/scroll-stutter; DevTools shows layout/paint on hover.

**Phase to address:**
Owned by a dedicated **motion phase (Track 1, applied to both surfaces)** that lands the reduced-motion contract + JS-coordinated enter/leave conventions; enforced per-phase by `/gsd:ui-review`'s motion pillar.

---

### Pitfall 6: Token-pipeline drift — generated CSS diverges from `tokens.json`; one-off styles creep outside the system; admin vs Cohort token divergence

**What goes wrong:**
Three related failures: (a) `rindle-admin.css` (the committed generated artifact, in two locations — `brandbook/tokens/` and `priv/static/rindle_admin/`) drifts from `tokens.json` because someone edited CSS directly or forgot to regenerate/copy both; (b) "just this once" inline styles or non-token magic numbers creep into templates outside the generated system, so the DS is no longer the single source of truth; (c) admin (`rindle-admin.*`) and Cohort (`cohort.*` / `--ck-*`) evolve their own divergent scales (spacing, radius, motion, status colors) so the two surfaces stop feeling like one brand.

**Why it happens:**
Generated artifacts are committed (for the shippable, host-independent library), so they're tempting to hand-edit and easy to leave stale. Two output locations double the drift surface. Cohort intentionally keeps a separate, lighter system, which invites silent divergence from the brand tokens. Inline `style=` is the path of least resistance under deadline.

**How to avoid:**
- **Generator is the only writer; CI proves it.** Keep/extend the `tokens-build.mjs`-style parity self-check (exit non-zero on missing tokens/selectors). Add a CI gate that regenerates and asserts both `brandbook/tokens/rindle-admin.css` and `priv/static/rindle_admin/rindle-admin.css` match the generator output byte-for-byte (no manual drift, both copies in sync).
- **Ban out-of-system styling in restyled surfaces:** grep-gate for `style="` inline declarations and non-token literals in restyled templates/CSS (ties to Pitfall 4's literal-color gate). Inline `style="--d:…"` stagger vars (as `task_card`/`access_panel` already use) are acceptable; raw values are not.
- **Shared brand spine.** Cohort's `--ck-*` should derive from / map onto the same `tokens.json` primitives (spacing/radius/motion/status semantics) even though its component layer differs. Document the mapping and add a check that Cohort's scale references brand primitives rather than ad-hoc values, so the two surfaces stay coherent ("internally coherent and consistent end-to-end").

**Warning signs:**
- Non-empty `git diff` after regenerating; the two `rindle-admin.css` copies differing.
- `style="…"` with literal values, or magic-number paddings/radii in templates.
- Cohort and admin showing visibly different radii/spacing/status hues for the "same" concept.

**Phase to address:**
Owned by the early **Track-1 DS pipeline phase** (regenerate-and-diff CI gate, two-location sync, no-inline-style lint, Cohort↔brand mapping). Re-verified at milestone close.

---

### Pitfall 7: Flaky visual-regression — screenshots churn on fonts/animation/async render, drowning signal

**What goes wrong:**
The visual matrix is the milestone's primary proof (light/dark, mobile, ~22+ PNGs). If it's flaky, false positives swamp the real signal and the team starts ignoring/rubber-stamping diffs — defeating the no-regression mandate. Flakiness sources specific to this app: animations mid-capture, web-font swap (FOUT) not settled, LiveView async content (status text that updates via push, `streaming_url`, doctor output) not yet rendered, dynamic/seed-dependent values (ids, timestamps, asset ids) differing run-to-run, and OS-level font hinting differences if baselines are generated on a Mac but compared in Linux CI.

**Why it happens:**
The current admin matrix (`admin-screenshots.spec.js`) is a **drift/existence gate** (captures with `animations:"disabled"`, then asserts the expected PNG set exists) — good, but if v1.19 upgrades to true `toHaveScreenshot` pixel-diff baselines, all the classic flakiness sources apply and baselines were not previously needed. Mixing "did it render" with "does it match pixels" without the right controls makes the suite noisy.

**How to avoid:**
- **Stabilize before diffing:** keep `animations: "disabled"`; `await page.evaluate(() => document.fonts.ready)` before capture; wait on `waitForLiveSocket` *and* on the specific `data-testid` content being present (the suite already gates on `expectAdminShell`/testids) so async LiveView content has landed.
- **Mask or normalize dynamic content:** `mask:` dynamic locators (asset ids, timestamps, streaming URLs, doctor stdout) or render them from fixed seeds. Note the charter explicitly permits adjusting seed/fixture data — use deterministic seeds so screenshots are reproducible (but see Pitfall 8: don't break flows doing it).
- **Generate baselines in the CI environment, not locally.** Font hinting/anti-aliasing differs Mac↔Linux; baselines must come from the same image that compares them (the repo already runs a Linux CI Playwright lane). Chromium-only for visual.
- **Per-surface thresholds, not one global number;** start tolerant on text-heavy tables, tight on brand/hero. Prefer keeping the **existence/drift gate** as the merge-blocker and treat pixel-diff as an assistive review artifact unless baselines are CI-generated and stable — don't make a flaky pixel diff merge-blocking.

**Warning signs:**
- Screenshot tests that pass/fail on re-run with no code change.
- Diffs concentrated in text anti-aliasing or in regions with timestamps/ids.
- Baselines committed from a developer Mac then failing in Linux CI.
- Reviewers approving screenshot diffs without reading them.

**Phase to address:**
Owned by the **visual-proof / screenshot-matrix phase** (likely the Track-2 proof phase reusing `admin-screenshots.spec.js` + `playwright.config.js`). Must define the stabilization recipe and where baselines are generated before expanding the matrix to Cohort pages.

---

### Pitfall 8: "Award-winning" scope creep — endless polish, seed-data changes that break flows, gold-plating over flow value

**What goes wrong:**
"Award-winning, fractal, at every level of abstraction" has no natural stopping point — a single button can absorb infinite passes. Two concrete failure modes: (a) gold-plating components/animations that no real user flow needs, while a genuinely broken flow stays unstyled; (b) "the flows must actually work, so I'll adjust seed/fixture data" turning into edits that break the very specs/screenshots that depend on those seeds (the suite asserts seeded names, asset states, member ids — changing them cascades into `data-testid` content mismatches and screenshot churn).

**Why it happens:**
The quality bar is aspirational and self-referential; without a "done" definition per surface, polish expands to fill available time. Seed edits feel safe but are load-bearing for both behavior specs (which assert seeded values) and the screenshot matrix (which captures seeded content).

**How to avoid:**
- **Anchor every uplift to a named JTBD/persona/flow** from `guides/user_flows.md` + `.planning/JTBD-MAP.md`. If a polish pass doesn't serve a documented flow for that surface, it's out of scope. "DS in service of the flows," per charter.
- **Define per-surface "done"** as a checklist (all interaction states, light+dark, mobile, a11y pass, motion+reduced-motion, on-brand microcopy, behavior specs green, contrast green) — not "until it feels award-winning." `/gsd:ui-review`'s 6 pillars already provide this rubric; treat passing it as done.
- **Seed/fixture changes are a deliberate, reviewed step, not a side effect.** When a flow needs richer data to exercise happy/error/boundary paths, update seeds *and* the dependent specs/screenshot expectations in the same pass, and re-run the behavior suite. Prefer adding states over mutating existing seeded identities the specs assert on.
- **Time-box per surface;** subagent research informs one-shot direction, then execute and move on. Re-open only on a failed pillar, not on taste.

**Warning signs:**
- A component on its Nth revision with no flow-value change.
- A still-broken/unstyled flow while a "nice-to-have" gets polished.
- Behavior specs failing after a seed edit; screenshots churning because seeded content changed.
- Reviews drifting into subjective "could be nicer" without a failing pillar.

**Phase to address:**
Owned by **roadmap scoping** (per-phase "done" = `/gsd:ui-review` pillars + behavior specs + contrast/theme gates) and enforced at **each phase boundary**. Seed changes owned by whichever flow phase needs them, with spec/screenshot co-update mandatory.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Hand-edit generated `rindle-admin.css` instead of `tokens.json` + regenerate | Instant visual tweak | Reverts on next generate; drift between the two committed copies; breaks SoT | Never |
| `outline: none` on custom controls without a focus replacement | "Cleaner" look | WCAG keyboard a11y regression invisible in screenshots | Never |
| Append override rules at the bottom of `cohort.css` per pass | Fast local fix | Non-idempotent; duplicate/last-wins thrash on re-run | Never |
| Hardcoded hex / `text-red-600`-style literals during restyle | Quick port from daisyUI | Doesn't theme; dark-mode + brand drift | Never (convert to tokens) |
| Bare CSS `transition: all` on LiveView-patched nodes | Easy animation | Flicker/double-play fighting morphdom; jank | Only on stable, non-patched containers |
| Make pixel-diff `toHaveScreenshot` merge-blocking before stabilizing | Strong-looking gate | Flaky false positives erode trust; reviewers rubber-stamp | Only after CI-generated, stabilized baselines |
| Edit seed data to make a flow "look full" without updating specs | Richer screenshots | Behavior specs + screenshot baselines break | Only with co-updated specs/baselines in same pass |
| Drop a `data-testid`/`id` to "clean up" markup during restyle | Tidier template | Silently breaks E2E + JS hook mount | Never |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Phoenix LiveView `phx-hook` (`PresignedPut`, `MultipartUpload`, `Copy`, …) | Restyle removes/renames the element `id` the hook mounts on | Keep stable `id` + `phx-hook`; only change `class`; re-expose via component attrs |
| LiveView `phx-update="stream"` / pushed text nodes | CSS `transition`/keyframes on patched nodes → flicker | Use `JS.transition` via `phx-mounted`/`phx-remove`; no `transition:all` on hot nodes |
| `<.form phx-change/phx-submit>` + `<.live_file_input>` | Restructuring form markup for layout breaks change/submit/upload wiring | Preserve `<.form>`/`<.live_file_input>` structure and event names verbatim |
| Generated CSS (two output paths) | Regenerate updates `brandbook/tokens/` but not `priv/static/rindle_admin/` (or vice-versa) | CI gate asserts both copies equal generator output |
| `[data-theme]` theme contract | Introducing a `.dark`/Tailwind-dark parallel on Cohort | Reuse `[data-theme="dark"]` + `[data-theme="auto"]` media-query convention everywhere |
| Playwright visual baselines | Baselines generated on dev Mac, compared in Linux CI | Generate baselines in the CI image; Chromium-only |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Animating `width`/`height`/`top`/`box-shadow` | Hover jank, scroll stutter, paint storms | Animate `transform`/`opacity` only | Immediately on low-end/mobile; mandate is mobile-first |
| `transition: all` on streamed/patched lists | Re-animates on every server push; CPU churn | Transition specific properties on stable containers | As soon as PubSub/stream updates flow |
| Large unmasked full-page screenshots × (light+dark+mobile) × surfaces | Slow, flaky CI matrix | Mask dynamic regions; per-surface scope; `animations:disabled` | As the matrix grows past current ~22 PNGs |
| Heavy box-shadow elevation reused in dark | Muddy/invisible elevation, extra paint | Surface-tint elevation tokens per theme | First dark-mode review |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Adding a runtime icon pack / CDN font / third-party UI registry for "polish" | Breaks the library's no-Tailwind, self-contained, host-independent asset contract; supply-chain + offline-install regression | Inline SVG marks (as `cohort_components.ex`/admin already do); self-host fonts; no shadcn/Radix/daisyUI/Tailwind UI in the shipped console (Phase 88 planner rule) |
| Rendering untrusted media/container metadata into restyled detail views unescaped | XSS via filename/title/artist/comment (security invariant 10: metadata is untrusted) | Keep HEEx escaping; never `raw/1` user-influenced strings in restyled templates |
| Surfacing provider-internal ids in a "nicer" detail panel | Violates security invariant 14 (provider id leakage in adopter-facing UI) | Show only public `playback_id`/redacted tags; never raw provider ids in restyled admin/Cohort UI |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Color-only status (chip with no label/icon) | Colorblind users can't distinguish ready/processing/failed | Text + icon + token-tint chip (existing brand rule) |
| Motion with no reduced-motion path | Vestibular/motion-sickness harm; mandate violation | `prefers-reduced-motion` gate on all motion |
| Polishing decorative dashboards over task-first IA | Operators can't find the next action | gov.uk-style least-surprise, task-first IA (admin IA inventory already defines surfaces) |
| Microcopy generic/off-persona | Doesn't serve the flow's JTBD; feels unbranded | Tie copy to the surface's persona/JTBD in `guides/user_flows.md`, finalize once |
| Drawer/dialog without `Esc`/focus restore | Keyboard users trapped or lost | APG dialog pattern: trap + `Esc` + restore focus to invoker |

## "Looks Done But Isn't" Checklist

- [ ] **Restyled page:** Often missing preserved `data-testid`/`id`/`phx-hook` — verify selector inventory unchanged and behavior specs green.
- [ ] **Custom button/link/tab:** Often missing `:focus-visible` ring — verify keyboard Tab shows visible token-backed focus.
- [ ] **Dark theme:** Often missing dark contrast proof — verify `admin-contrast`/`contrast` pairs exist and pass for dark, not just light.
- [ ] **Animation:** Often missing `prefers-reduced-motion` — verify reduce-motion disables it and only `transform`/`opacity` animate.
- [ ] **Generated CSS:** Often out of sync — verify regenerate-and-diff is empty across both `rindle-admin.css` copies.
- [ ] **Dialog/drawer:** Often missing focus trap + `Esc` + restore — verify keyboard-only operation.
- [ ] **Status indicator:** Often color-only — verify text + non-color mark present.
- [ ] **Screenshot matrix:** Often flaky — verify fonts settled, animations disabled, dynamic content masked, baselines CI-generated.
- [ ] **Seed-dependent flow:** Often breaks specs after seed edits — verify behavior specs + screenshot expectations co-updated.
- [ ] **Microcopy:** Often generic — verify tied to the surface's documented JTBD/persona.

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Broken hook/binding after restyle | LOW–MEDIUM | Re-run behavior spec to localize; restore `id`/`phx-hook`/`phx-*`; re-expose via component attrs |
| Hand-edited generated CSS lost on regenerate | LOW | Move the change into `tokens.json`/generator input; regenerate; sync both copies |
| Non-idempotent thrash (duplicate overrides) | MEDIUM | Refactor to one owned block per component; add double-run no-op check |
| Dark contrast failure found late | MEDIUM | Add dark `contrast_pairs`; adjust tokens (not literals); re-run gate across all surfaces |
| Lost focus-visible across many components | MEDIUM | Centralize focus mixin/token rule; apply to all `.ck-*`/`.rindle-admin-*` interactive selectors; add axe/keyboard assertion |
| Flaky screenshot matrix | MEDIUM–HIGH | Add `document.fonts.ready` + testid waits + masks + `animations:disabled`; regenerate baselines in CI; downgrade pixel-diff from merge-block to assistive until stable |
| Seed edit broke specs + baselines | MEDIUM | Revert to deterministic seeds; co-update specs + screenshot expectations; re-run full behavior + visual suite |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1. Behavior regression from class-coupled markup | Every Cohort restyle phase (Track 2) | Selector inventory preserved; behavior Playwright specs green |
| 2. Non-idempotent thrash | Early Track-1 DS-pipeline/idempotency phase | Double-run produces empty diff (generated + restyle passes) |
| 3. A11y (focus/ARIA/keyboard) loss | Track-1 a11y-baseline phase + per-phase `/gsd:ui-review` | axe-core + keyboard Playwright assertions; no `outline:none` |
| 4. Dark-mode/contrast drift | Track-1 token/theme phase + first Cohort restyle | Light+dark contrast gate passes; no color literals (grep gate) |
| 5. LiveView vs CSS animation + reduced-motion | Motion phase (Track 1, both surfaces) | `prefers-reduced-motion` present; no `transition:all` on patched nodes |
| 6. Token-pipeline drift / divergence | Early Track-1 DS-pipeline phase | Regenerate-and-diff CI gate; both copies in sync; no inline literals |
| 7. Flaky visual regression | Visual-proof / screenshot-matrix phase | Stable re-runs; CI-generated baselines; masked dynamics |
| 8. Scope creep / seed breakage | Roadmap scoping + each phase boundary | Per-surface "done" = pillars + specs + gates; seeds co-updated with specs |

## Sources

- Repo truth (HIGH): `examples/adoption_demo/lib/adoption_demo_web/live/upload_live.ex`, `dashboard_live.ex` (Tailwind/daisyUI + `phx-hook`/`data-testid`/`phx-*` coupling); `components/cohort_components.ex` + `priv/static/assets/cohort.css` (`.ck-*` system, `phx-hook="Copy"`, `.ck-reveal`); `priv/static/assets/js/app.js` (`hooks: {PresignedPut, …, Copy}`); `e2e/*.spec.js` (`getByTestId`/`data-testid` selectors); `e2e/admin-screenshots.spec.js` (`animations:"disabled"`, existence/drift gate), `admin-theme.spec.js` (`data-theme` assertion); `playwright.config.js`.
- Phase 88 prior-art (HIGH): `.planning/phases/88-admin-design-system-ui-kit/88-PATTERNS.md` — generated-artifact + parity contract (`tokens-build.mjs`), `[data-theme="dark"]/"auto"` theme contract, `contrast.mjs`/`admin-contrast.mjs` WCAG gate, focus-visible token pattern, motion tokens + `prefers-reduced-motion` rule, status text+icon+contrast rule, no-Tailwind/no-third-party-UI dependency boundary.
- Charter (HIGH): `.planning/PROJECT.md` v1.19 charter + D-v1.18-04 (BEM + tokens, no host Tailwind; Cohort keeps own system); `.planning/seeds/SEED-002-*.md` (fractal audit, idempotent/no-regression, Emil Kowalski motion, gov.uk IA, mobile-first, JTBD microcopy); security invariants 10 & 14.
- [Phoenix LiveView — DOM patching & JS commands (`phx-mounted`, `phx-remove`, JS DOM-patch-aware)](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.JS.html) (HIGH)
- [Playwright visual regression — fonts.ready, animations:disabled, masking, CI baselines, per-component thresholds](https://testdino.com/blog/playwright-visual-testing) and [Arbisoft guide](https://arbisoft.com/blogs/playwright-visual-testing-a-complete-guide-to-reliable-ui-regression-tests) (MEDIUM, multi-source agree)

---
*Pitfalls research for: fractal DS audit + daisyUI→custom-DS LiveView migration (v1.19)*
*Researched: 2026-06-14*
