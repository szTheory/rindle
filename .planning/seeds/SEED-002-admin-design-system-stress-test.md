---
id: SEED-002
status: consumed
planted: 2026-06-13
planted_during: v1.18 close-out / repo-hygiene pass
consumed: 2026-06-20
consumed_by: "v1.19 Design-System Stress-Test (chartered 2026-06-14, shipped 2026-06-19; 20/20 requirements complete)"
trigger_when: "Next `gsd new milestone` — the candidate feature milestone after v1.18. Surface when scope touches admin/operator UI quality, the Cohort example app styling, or design-system maturity."
scope: Large
---

# SEED-002: Design-system stress test — admin/operator UI + Cohort example app

## Why This Matters

The brand book is now strong (`brandbook/`, tokens, admin gallery) and the v1.18 admin
console + a new Cohort launchpad (`/`, `priv/static/assets/cohort.css`) exist. But quality is
uneven: the **inner Cohort example pages** (`/dashboard`, `/upload?tab=…`, `/ops`,
member/lesson/post/media) are still essentially **unstyled text**, and the **admin/operator
console UI** has not been systematically audited against the strengthened brand. We want to
elevate the whole design system to an award-winning bar — deliberately, fractally, and without
regressions — in service of real user flows.

## When to Surface

**Trigger:** the next `gsd new milestone` after v1.18. Strong candidate for the v1.19 feature
milestone. Present whenever milestone scope includes admin/operator UI polish, Cohort demo
styling, or "make the design system production-grade."

## Scope Estimate

**Large** — a full milestone. Two intertwined tracks:

1. **Admin/operator design-system audit & uplift (primary).** A Storybook-lens, *fractal*
   audit at every level of abstraction:
   - **Individual components** — color, typography, padding/spacing, shape/border-radius,
     shadow, animation, and all interaction states (hover/focus/active/disabled/loading/empty/
     error) — on-brand and excellent in **light, dark, and system**.
   - **Component groups / meta-components** — repeatable configurations (toolbars, tables +
     filters, action panels, detail drills) evaluated as units for cohesion and rhythm.
   - **Page composition** — how groups assemble per page; spacing, hierarchy, on-brand.
2. **Cohort example app restyle (deferred from the launchpad pass).** Bring `/dashboard`,
   `/upload` (all tabs), `/ops`, and member/lesson/post/media onto the Cohort design system
   (`cohort.css` + `CohortComponents`), replacing the daisyUI scaffold.

### Quality bar & method (the signal)

- **Animation**: best-practice, researched from Emil Kowalski (emilkowalski.ski) — purposeful,
  performant, reduced-motion-aware.
- **Per-decision research via subagents** (context-efficient): for each meaningful choice,
  research approaches / best practices / anti-patterns / footguns / real user feedback
  (loved + hated + why) / pros-cons-tradeoffs, then **adversarially judge at each level of
  abstraction** and synthesize the best one-shot direction.
- **gov.uk-style information architecture**: intuitive, least-surprise, good for onboarding +
  intermediate + advanced users across happy paths, main error cases, and boundary conditions.
- **Mobile-first responsive** at every width; looks good at all breakpoints.
- **UX microcopy** on-brand and serving the specific user flow / JTBD / persona of each
  component, section, and page (tie back to `guides/user_flows.md` personas).
- **Idempotent / no-regression**: each run only moves quality forward; safe to re-run several
  times. Internally coherent and consistent end-to-end.
- **Flows must actually work**: may adjust seed/fixture/example data to exercise happy /
  error / boundary / edge paths — but the design system is the goal, *in service of* the flows.

## Breadcrumbs

- `brandbook/` — brand book, `tokens/tokens.json`, `tokens/rindle-admin.css`, admin gallery
  (`brandbook/admin-gallery/index.html`) — the source of truth + component reference.
- `examples/adoption_demo/priv/static/assets/cohort.css` + `lib/adoption_demo_web/components/
  cohort_components.ex` — the launchpad's Cohort design system (extend this to inner pages).
- Inner pages to restyle: `lib/adoption_demo_web/live/{dashboard,upload,ops,member,lesson,post,
  media,account}_live.ex` (currently daisyUI/scaffold).
- Admin console UI: `lib/rindle/admin/**` (router macro, LiveViews, the generated
  `rindle-admin.css`) — the primary audit target.
- `guides/user_flows.md` + `.planning/JTBD-MAP.md` — personas/JTBD for the user-flow lens.
- Phase 88 (`.planning/phases/88-admin-design-system-ui-kit/`) — prior design-system work +
  6-pillar UI audit conventions (`/gsd:ui-review`, `gsd-ui-phase`).
- E2E + screenshots: `scripts/ci/adoption_demo_e2e.sh`, `e2e/admin-screenshots.spec.js`
  (light/dark matrix) — reuse for visual regression / proof.

## Notes

- Do NOT execute during the v1.18 close-out / repo-hygiene pass; this is planted for the next
  milestone. The launchpad button-legibility + cast-icon polish were done inline; the inner-page
  restyle and admin audit are explicitly this seed's scope.
- Consider whether a lightweight in-repo "gallery" (like `brandbook/admin-gallery`) for the
  Cohort components is worth it as a living audit surface.
- Leverage `/gsd:ui-phase` (UI-SPEC contract) and `/gsd:ui-review` (6-pillar audit) per phase.
