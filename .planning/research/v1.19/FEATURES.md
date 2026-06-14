# Feature Research — Award-Winning Admin/Operator Design System

**Domain:** Mountable admin/operator console (media-asset lifecycle triage) + polished example app (Cohort course/community demo)
**Researched:** 2026-06-14
**Confidence:** HIGH (cross-verified GDS official docs, NN/g, Material 3, enterprise-table practitioner analysis, distilled Emil Kowalski motion rules, dark-mode token guides)

> "Features" in this UI-quality milestone = the **qualities and patterns** that make an
> admin/operator design system and demo app *excellent*, not new domain capabilities. This
> file categorizes each into **TABLE STAKES** (penalized if missing), **DIFFERENTIATOR**
> (separates award-winning from merely competent), and **ANTI-FEATURE** (looks impressive,
> hurts operators). Everything is tied to the two surfaces and the four Rindle personas
> (App developer, Platform/senior engineer, **Operator/SRE — the primary console user**,
> Security/compliance).

---

## The bar, in one paragraph

An award-winning operator console is **calm, fast, legible, and trustworthy under stress.**
The operator arrives mid-incident ("Friday 5pm, lesson videos never went ready") and needs to
go from *"something is wrong"* → *"this exact asset, this state, this repair"* with zero
surprises. That means: every component is correct in every interaction state (so nothing flickers
or lies), meta-components (tables/filters/drawers/confirm panels) compose into a coherent triage
rhythm, the IA is task-first (not a tour of the data model), dark mode is a first-class context
(operators work at night), microcopy names the operator's job in the operator's words, and motion
is sub-300ms and purposeful (never decorative). The demo app (Cohort) has a gentler bar — it must
look *finished and on-brand* across light/dark and every breakpoint, exercising happy/empty/error
states so the design system is proven against real flows.

---

## Feature Landscape

### Table Stakes (Users Expect These — penalized if missing)

#### A. Component-state coverage (the canonical state matrix)

The non-negotiable matrix, per interactive component. "Great" defined per state; common gaps flagged.

| State | What "great" looks like | Common gap (the penalty) | Complexity |
|---|---|---|---|
| **default / rest** | On-brand, correct contrast (WCAG AA), clear affordance | — | LOW |
| **hover** | Subtle bg/elevation shift; ~150–200ms transition so accidental passes don't flash; pointer-only (never the sole signal) | Hover used to *hide* primary affordances on touch; instant snap that flickers | LOW |
| **focus-visible** | Visible 2–3px focus ring with offset, keyboard-only (`:focus-visible`, not `:focus`); meets non-text contrast | Ring suppressed globally (`outline:none`); mouse clicks leave rings everywhere | LOW |
| **active / pressed** | Immediate (<100ms) tactile depress/tint; confirms the click registered | No pressed feedback → operator double-clicks destructive actions | LOW |
| **disabled** | Visibly inert + **explains why** (tooltip/helper); `aria-disabled` so it stays focusable for SR | Greyed with no reason → operator stuck guessing; `disabled` attr removes it from a11y tree | LOW |
| **loading** | In-place spinner/skeleton, control stays put (no layout shift), button keeps its width, action locked against double-submit | Whole-page spinner; button collapses; double-submit fires twice | MEDIUM |
| **empty** | Heading + motivation + primary next action (not just "No data") — see microcopy | Bare "No results" with no path forward | MEDIUM |
| **error** | Plain-language cause + fix, tied to the field/region, recoverable, never clears entered data | Toast-only "An error occurred"; form wipes on error | MEDIUM |
| **skeleton** | Shape mirrors the real content, reserves exact space, ≤ ~1s before content or shows progress | Skeleton that doesn't match → content "jumps"; skeleton shown for >2s with no fallback | MEDIUM |
| **selected / current** | Clear non-color cue (border/weight/check) for selected rows + `aria-current` for nav | Color-only selection (fails for color-blind operators) | LOW |

> The current admin gallery already covers default/hover-ish/focus/disabled/loading/empty/error/skeleton
> across buttons, table rows, chips, toasts, drawer, confirm-dialog. **The gap is systematic
> per-state QA in BOTH themes and the `active`/`focus-visible` distinction**, plus proving the
> matrix on real LiveViews (not just the static fixture).

#### B. Meta-components for operator tooling

| Pattern | "Great" looks like | Complexity |
|---|---|---|
| **Data table** | Header-click sort with chevron that doesn't break alignment; left-align text / right-align numbers + monospace IDs; 1px subtle row rules (no zebra under interactive states); sticky header on scroll; row hover reveals actions; default sort = "most urgent / most recent" | MEDIUM |
| **Filter bar** | Quick filters above the table that map to real lifecycle states (ready/processing/warning/quarantine/danger/info — already the chip vocabulary); instant apply; visible active-filter chips with one-click clear; filter state reflected in URL (shareable triage link) | MEDIUM |
| **Toolbar** | Stable region for page-level actions + search + density; doesn't reflow when bulk-select bar appears | LOW |
| **Bulk-select + bulk-action bar** | Checkboxes appear on hover/select; bulk actions surface **only after** selection (sticky footer/header), show count, are reversible or confirmed | MEDIUM |
| **Row actions** | ≤2 inline; >2 collapse into an actions menu; never a wall of buttons per row | LOW |
| **Detail drill-down (drawer/page)** | Stays close to the invoking row (drawer for quick triage, full page for deep work); shows **state timeline** of the asset's FSM history; deep-linkable | MEDIUM |
| **Action / confirmation panel** | Summarizes *what will happen* before asking to confirm; primary/destructive separated spatially | MEDIUM |
| **Destructive-action UX** | **Typed confirmation** for irreversible ops (type `owner:cohort-demo-42`) + **collateral preview** (N detached, M retained shared, K purge jobs) before enabling Confirm; confirm/cancel far apart; redundant non-color signal | HIGH |
| **Toasts** | Transient success/info; **never** the only channel for errors that need action; dismissible; stack without covering primary content; `role=status`/`alert` correctly | LOW |
| **Empty states** | Heading + motivation + action; differentiate "no data yet" (onboarding) from "no results for this filter" (offer clear-filter) from "doctor not configured" (offer setup) | MEDIUM |

> Already present in the gallery: table, status chips, buttons, confirm-dialog with typed
> confirmation + collateral receipt, drawer, toasts, empty-state, skeletons. **Missing meta-components
> to reach the bar:** real filter bar, sortable headers, bulk-select bar, density control, sticky
> header, and an **asset state-timeline** in the detail drill (the operator's #1 triage artifact).

#### C. Information architecture (gov.uk / GDS principles applied to an OPERATOR console)

GDS principles, translated from public-service IA to operator-console IA:

| GDS principle | Concrete application to the Rindle console (not generic) |
|---|---|
| **Start with user needs; task-oriented, not org-chart** | Nav is keyed to operator *jobs* ("Home/Status, Assets, Upload Sessions, Variants/Jobs, Runtime/Doctor, Actions" — current nav is already job-shaped, keep it), NOT to Ecto table names. The home is a **triage landing**: "what's stuck right now," not a data dump. |
| **Do less / do the hard work to make it simple** | Surface only what an operator acts on. The complex lifecycle (FSM states, Oban jobs) is *underneath*; the console presents the few decisions: inspect, repair, requeue, erase. |
| **Inverted-pyramid drill-down** (observability convention) | Home = high-level health ("3 danger, 2 warning") → list filtered to that state → asset detail with timeline → action. One screen answers one on-call question; if it can't, split it. |
| **Progressive disclosure** | Default view is clean; power surfaces (raw job payloads, provider sync detail, redacted IDs) live behind drawers/expanders. Don't show provider-internal noise by default (also a security-invariant-14 fit: redacted last-4 only). |
| **Least surprise / be consistent not uniform** | Same chip vocabulary, same action verbs, same confirm pattern everywhere. An "Inspect" button always opens the same drawer shape. |
| **Serve onboarding + intermediate + advanced** | First-run/empty consoles teach ("No assets match — adjust filter or check Runtime/Doctor"); intermediate users get filters + bulk; advanced users get deep-links, keyboard nav, dense mode. |
| **Cover happy / error / boundary paths** | Every list has: populated (happy), filtered-empty (boundary), error/unreachable-storage (error), and not-yet-configured (onboarding) states designed, not just the happy path. |

#### D. Dark mode done right + light/dark parity

| Requirement | "Great" | Common gap |
|---|---|---|
| **Semantic tokens, not raw values** | `--rindle-surface`, `--surface-raised`, `--text`, `--text-secondary`, `--focus-ring` (already the token shape) — both themes resolve the *same* semantic names | Hard-coded hex; "invert and ship" |
| **Elevation via surface lightness, not shadow** | Dark mode needs ≥4 surface levels (base → raised panel → nested/hover → overlay/modal), each progressively *lighter* (shadows barely read on dark) | Reusing light-mode drop-shadows in dark; flat single-surface dark |
| **Per-mode color scales, tuned contrast** | Status chips (ready/warning/danger…) carry their semantic meaning in BOTH themes at AA; saturated brand colors desaturated slightly for dark to avoid vibration | Same chip palette in both → neon/illegible danger-red on dark |
| **Parity = same job, different visual logic** | Every state in the matrix verified in light AND dark; theme picker (already present: Light/Dark/Auto with `aria-pressed`) respects system | Dark mode shipped as second-class; states only QA'd in light |

#### E. Microcopy that serves a specific JTBD/persona

GDS error rules (authoritative) + empty-state structure, tied to Rindle/Cohort personas:

| Surface | Pattern (great) | Anti-pattern (penalty) |
|---|---|---|
| **Button labels** | Verb + object in the operator's words: "Requeue failed variants," "Erase owner," "Review Runtime/Doctor." Match the facade vocabulary the operator already knows from `mix rindle.*` | "Submit," "OK," "Process" |
| **Empty state** | Heading ("No assets match this state") + motivation ("Adjust the lifecycle filter or check Runtime/Doctor") + action button — already the gallery pattern, generalize it | "No data" / blank panel |
| **Error message** | GDS rules: plain English, say *what happened + how to fix*, **no** "forbidden/illegal/you forgot," **no** "please," **no** "oops"; tie to the region; never clear entered input | "An error occurred"; jargon; toast-only; wipes the form |
| **Confirmation copy** | State the collateral concretely: "12 detached, 3 retained shared assets, 2 purge jobs queued" (already the receipt pattern) before asking to confirm | "Are you sure?" with no consequences shown |
| **Persona fit** | Operator/SRE copy is terse + diagnostic ("Processor failed after retry budget"); Cohort App-dev demo copy is warmer ("Your lesson is processing — we'll email you when it's ready") | One generic voice across both surfaces |

> Tie-back: console copy speaks **Operator/SRE** (the JTBD-MAP primary console persona — "see what's
> stuck, repair it, keep cost bounded"). Cohort inner-page copy speaks **App developer / end-user**
> (member uploads avatar, creator uploads a lesson) — warmer, outcome-focused.

#### F. Animation as a quality signal (Emil Kowalski principles)

| Principle | "Great" (purposeful) | "Cheap/janky" (anti-signal) |
|---|---|---|
| **Restraint — know when NOT to animate** | Animate state *changes* that need explaining (drawer open, toast in, row removed); leave data-dense tables still | Decorative-by-default; everything fades/slides |
| **Speed** | UI motion < 300ms; ~180ms feels responsive; perceived performance comes from speed | 400ms+ transitions that make the console feel sluggish under load |
| **Easing** | `ease-out` for enters, custom cubic-bezier / spring for natural feel; never bare `ease`/`linear` for UI | `linear`, default `ease`, or no easing |
| **GPU-friendly properties** | Animate `transform` + `opacity` only | Animating `width/height/top/left` (layout thrash, jank) |
| **Origin-aware** | Drawer/menu animates *from its trigger*; `scale` starts near 0.95–0.98, never `scale(0)` | `scale(0)` "grow from nothing"; motion with no spatial logic |
| **Interruptible** | Animations can be reversed mid-flight (open→close without waiting) | Queued animations that block the operator |
| **Reduced-motion** | `@media (prefers-reduced-motion: reduce)` swaps to instant/opacity-only — **table stakes for an a11y-grade console** | Missing the query entirely (WCAG 2.2.2 fail) |

---

### Differentiators (award-winning, not merely competent)

| Feature | Value proposition | Complexity | Notes |
|---|---|---|---|
| **Asset state-timeline in detail drill** | Operator sees the FSM history (validating → ready → variant failed) as a vertical timeline — the single most useful triage artifact; turns "archaeology" into a glance | MEDIUM | Maps directly to Story 6; Rindle's "every state is a queryable row" is the data backing |
| **Shareable triage deep-links** | Filter/sort/selected-asset encoded in URL → operator pastes a link in the incident channel and a teammate lands on the exact view | MEDIUM | "One page answers one on-call question" made collaborative |
| **Collateral-preview destructive UX** (already seeded) | Typed confirm + concrete collateral receipt is the gold standard (GitHub/Cloudflare-tier); for owner-erasure it's *also* a compliance artifact | HIGH | Already in gallery — elevate to all destructive ops, show retained-shared-asset safety explicitly |
| **Density toggle + persisted prefs** | Power operators compress to 40px rows on big monitors; preference remembered across sessions | MEDIUM | Loved by power users; pure win |
| **Empty states that route to the fix** | "No assets match → Review Runtime/Doctor" turns a dead-end into onboarding/repair | LOW | Already seeded; make it systematic |
| **True dark-mode elevation system** | 4-level surface ladder that feels designed, not inverted — rare even in funded products; strong "award" signal | MEDIUM | Operators work at night; this is felt daily |
| **Origin-aware, interruptible motion** | Drawers/toasts that animate from their trigger and reverse cleanly read as "expensive" software | MEDIUM | The Emil Kowalski "feel" differentiator |
| **Living component gallery for Cohort** | A `brandbook/admin-gallery`-style fixture for `CohortComponents` as a durable audit + visual-regression surface | MEDIUM | Seed explicitly flags considering this; pairs with the e2e light/dark screenshot matrix |
| **Keyboard-first operability** | Full keyboard nav, focus management on drawer/modal open-close, type-to-confirm reachable — a console that never needs a mouse | MEDIUM | Differentiator for SRE persona; also an a11y win |

---

### Anti-Features (look impressive, hurt operators)

| Anti-feature | Why it gets requested | Why it's problematic | Do instead |
|---|---|---|---|
| **Animate everything / scroll-triggered reveals** | "Feels premium" | Slows triage, distracts under stress, fails reduced-motion, janks on big tables | Restraint: animate only state changes; <300ms; reduced-motion fallback |
| **Color-only status** (red/green chips, no label/icon) | Compact, pretty | Fails color-blind operators + dark-mode contrast; ambiguous in a hurry | Label + non-color mark (already the gallery rule — keep it) |
| **Inline editing of high-stakes lifecycle fields** | "Power-user efficiency" | One mis-click mutates production media state; no confirmation surface | Inline only for low-stakes; route destructive/state changes through confirm panels |
| **Zebra-striped dense tables** | "Easier to scan" | Collides with hover/selected/disabled states → visual chaos | 1px subtle row rules + clear hover/selected treatment |
| **Toast-only error handling** | Simple to wire | Errors that need action disappear in 4s; operator misses the fix | Inline/region errors for actionable problems; toasts for transient confirmations only |
| **Persistent row action buttons (wall of buttons)** | "Discoverable" | Cognitive overload, drowns the data, breaks density | Reveal on hover/select; collapse >2 into a menu |
| **Modal-stacking confirmation gauntlets** | "Safety" | Confirmation fatigue → operators click through blindly | One well-designed typed-confirm with collateral preview; reserve for truly irreversible ops; use undo for reversible ones |
| **Dark mode by color inversion** | Cheap to "support" | Breaks hierarchy, harsh contrast, inconsistent states | Semantic tokens + per-mode scales + surface-elevation ladder |
| **Building a metrics/charting dashboard** | "Operators love graphs" | Scope creep toward an observability platform; Rindle is a *lifecycle library*, not Grafana | Surface lifecycle *state*, not time-series telemetry; adopters build dashboards on the telemetry contract |
| **Custom scrollbars / bespoke select widgets** | "Polish" | Reinvent native a11y/keyboard behavior badly; break on platforms | Native controls, styled within reason; keep keyboard + SR semantics |
| **`please`/`oops`/`sorry`/jargon microcopy** | "Friendly" | GDS: implies choice, doesn't help fix, reads unserious in an ops tool | Plain, direct, fix-oriented copy |

---

## Feature Dependencies

```
Semantic token system (light + dark scales, 4-level elevation)
    └──required by──> Every component state in both themes
                          └──required by──> Meta-components (table/filter/drawer/confirm)
                                                └──required by──> Page composition + IA

State matrix coverage ──required by──> Visual-regression screenshot matrix (light/dark/mobile)

Filter bar ──requires──> Status-chip vocabulary (exists) + URL-encoded filter state
Bulk-action bar ──requires──> Row selection model + sticky toolbar region
Asset state-timeline ──requires──> FSM history query (Rindle data model already exposes states)
Destructive collateral preview ──requires──> Owner-erasure preview facade (exists: preview_owner_erasure/2)
Reduced-motion fallback ──enhances/gates──> All animation work (WCAG 2.2.2)

Cohort component gallery ──enhances──> Cohort inner-page restyle (durable audit surface)
```

### Dependency notes

- **Tokens are the foundation phase.** Every state, in both themes, resolves from semantic
  tokens with a real dark-elevation ladder. Get this wrong and every later phase inherits the debt.
- **State matrix before meta-components.** A table is only as good as its row's hover/focus/selected/
  loading/empty states; lock component states first, then compose.
- **Destructive UX reuses existing facade.** Collateral preview is backed by
  `preview_owner_erasure/2` — no new domain semantics, pure UI surfacing (consistent with v1.18's
  "actions reuse existing facade capabilities only" charter rule).
- **Reduced-motion gates all motion.** Treat it as a definition-of-done checkbox, not a phase.

---

## MVP Definition (for this UI-quality milestone)

### Launch With (the audit baseline — what makes it "not embarrassing")

- [ ] **Semantic token system** with light + dark scales and a 4-level dark elevation ladder — foundation for everything
- [ ] **Full state matrix** (default/hover/focus-visible/active/disabled/loading/empty/error/skeleton/selected) verified per component in **both themes**
- [ ] **Core meta-components** correct: data table (sort + sticky header + row hover actions), filter bar (chip-state filters), detail drawer, confirm/destructive panel, toasts, empty states
- [ ] **Task-first IA** on the console: triage home, inverted-pyramid drill-down, happy/empty/error/onboarding states per list
- [ ] **GDS-grade microcopy** pass on console (errors, empties, buttons, confirmations) in Operator voice
- [ ] **Reduced-motion-aware** motion under 300ms, GPU properties only, on the few moments that need it (drawer/toast/row-remove)
- [ ] **Cohort inner-page restyle** onto `cohort.css` + `CohortComponents`, retiring daisyUI, across `/dashboard`, `/upload` tabs, `/ops`, member/lesson/post/media/account
- [ ] **Light/dark/mobile screenshot matrix** extended as the no-regression proof (reuse `e2e/admin-screenshots.spec.js`)

### Add After Validation (the differentiator layer)

- [ ] **Asset state-timeline** in the detail drill (highest-leverage triage differentiator)
- [ ] **Bulk-select + bulk-action bar** with sticky footer + count
- [ ] **Density toggle + persisted prefs**
- [ ] **Shareable triage deep-links** (URL-encoded filter/selection)
- [ ] **Cohort component gallery** as a living audit + visual-regression surface

### Future Consideration (explicit pull only)

- [ ] Column reorder/hide/resize (power-user table management) — only if operators ask
- [ ] Saved views / per-operator dashboards — verges on platform scope; defer
- [ ] Any time-series charting — anti-feature; keep on the telemetry-contract side

## Feature Prioritization Matrix

| Feature | Operator Value | Implementation Cost | Priority |
|---|---|---|---|
| Semantic tokens + dark elevation ladder | HIGH | MEDIUM | P1 |
| Full state matrix (both themes) | HIGH | MEDIUM | P1 |
| Data table (sort/sticky/hover-actions) | HIGH | MEDIUM | P1 |
| Filter bar (chip-state) | HIGH | MEDIUM | P1 |
| Destructive UX (typed confirm + collateral) | HIGH | MEDIUM | P1 (mostly seeded) |
| Task-first IA + happy/error/empty coverage | HIGH | MEDIUM | P1 |
| GDS microcopy pass | HIGH | LOW | P1 |
| Reduced-motion-aware sub-300ms motion | MEDIUM | LOW | P1 |
| Cohort inner-page restyle | HIGH | HIGH | P1 (track 2) |
| Asset state-timeline | HIGH | MEDIUM | P2 |
| Bulk-select + bulk-action bar | MEDIUM | MEDIUM | P2 |
| Density toggle + persisted prefs | MEDIUM | MEDIUM | P2 |
| Shareable triage deep-links | MEDIUM | MEDIUM | P2 |
| Cohort component gallery | MEDIUM | MEDIUM | P2 |
| Column reorder/hide/resize | LOW | HIGH | P3 |

**Priority key:** P1 must-have for the award bar · P2 differentiator, add after baseline lands · P3 defer to explicit pull.

## Competitor / prior-art feature analysis

| Pattern | GitHub / Cloudflare (admin tooling) | Material 3 / GDS (systems) | Rindle console approach |
|---|---|---|---|
| Destructive confirm | Typed "type the repo name" + consequences | GDS: separate confirm/cancel, plain copy | Typed owner-id + collateral receipt (already seeded) — best-of-both |
| Status semantics | Label + icon + color | Non-color-reliant by mandate | Chip = label + non-color mark (already enforced) |
| Dark mode | First-class, elevation-aware | Token-driven | Semantic tokens + 4-level dark elevation ladder |
| IA | Task/inbox-oriented | User-need / task-first | Triage home + inverted-pyramid drill, job-shaped nav |
| Motion | Restrained, fast | Reduced-motion respected | Emil-Kowalski: <300ms, GPU props, origin-aware, reduced-motion |

## Sources

- [GOV.UK Design System — Error message component (tone, specificity, surfacing)](https://design-system.service.gov.uk/components/error-message/) — HIGH (official)
- [GOV.UK / GDS Design Principles](https://www.gov.uk/guidance/government-design-principles) — HIGH (official)
- [GOV.UK Design System home](https://design-system.service.gov.uk/) — HIGH (official)
- [NN/g — Button States: Communicate Interaction](https://www.nngroup.com/articles/button-states-communicate-interaction/) — HIGH
- [NN/g — Dangerous UX: Consequential Options Close to Benign Options](https://www.nngroup.com/articles/proximity-consequential-options/) — HIGH
- [Material Design 3 — Interaction States](https://m3.material.io/foundations/interaction/states/applying-states) — HIGH
- [Pencil & Paper — Enterprise Data Tables UX Pattern Analysis](https://www.pencilandpaper.io/articles/ux-pattern-analysis-enterprise-data-tables) — HIGH (practitioner, concrete do/don't)
- [Pencil & Paper — Error Message UX, Handling & Feedback](https://www.pencilandpaper.io/articles/ux-pattern-analysis-error-feedback) — MEDIUM
- [Denovers — Enterprise Table UX Design best practices](https://www.denovers.com/blog/enterprise-table-ux-design) — MEDIUM
- [Stéphanie Walter — Essential resources to design complex data tables](https://stephaniewalter.design/blog/essential-resources-design-complex-data-tables/) — MEDIUM
- [Muzli — Dark Mode Design Systems: Patterns, Tokens, Hierarchy](https://muz.li/blog/dark-mode-design-systems-a-complete-guide-to-patterns-tokens-and-hierarchy/) — MEDIUM (verified vs Material elevation guidance)
- [Medium/Bootcamp — Dark Mode Design Systems: A Practical Guide](https://medium.com/design-bootcamp/dark-mode-design-systems-a-practical-guide-13bc67e43774) — MEDIUM
- [Emil Kowalski — distilled motion rules (open-agents / design-motion-principles skill references)](https://github.com/kylezantos/design-motion-principles) — MEDIUM (distillation of emilkowalski.ski; primary site unreachable at research time)
- [UXPin — Designing the Overlooked Empty States](https://www.uxpin.com/studio/blog/ux-best-practices-designing-the-overlooked-empty-states/) — MEDIUM
- [Honeycomb — What is Observability (inverted-pyramid dashboard principle)](https://www.honeycomb.io/blog/what-is-observability-key-components-best-practices) — MEDIUM
- Internal: `.planning/seeds/SEED-002-*`, `.planning/PROJECT.md` (v1.19 charter), `.planning/JTBD-MAP.md`, `guides/user_flows.md`, `brandbook/admin-gallery/index.html` — HIGH (repo truth)

---
*Feature research for: award-winning admin/operator design system + Cohort demo app (v1.19)*
*Researched: 2026-06-14*
