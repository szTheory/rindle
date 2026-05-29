# Phoenix OSS Library Lens

Use this command as a product and adopter assessment for a Phoenix/Elixir
library, not as a framework-completion exercise.

## What "done enough" means

A library is close to done enough when a serious Phoenix SaaS team can:

- understand what the library is for quickly
- install it with low ambiguity
- complete the primary job-to-be-done without spelunking internals
- diagnose normal failures with truthful operator surfaces
- trust the support and proof posture
- avoid common footguns because docs and APIs steer them away early

It does not need to become a platform, a hosted service, or an everything-box.

## What to reward

- one strong, coherent wedge done thoroughly
- honest capability boundaries
- idiomatic use of Plug, Phoenix, Ecto, and OTP
- explicit runtime diagnostics and operator guidance
- install-smoke or generated-app proof
- docs that map to shipped behavior
- examples that reduce first-adopter friction

## What to penalize

- milestone inflation mistaken for product depth
- broad feature count without coherent adopter value
- docs that outrun code
- "support" claims that are not backed by proof
- scope creep into provider/platform behavior the library should not own
- internal cleverness that raises surprise for adopters

## Good milestone candidates

The best next milestone usually does one of these:

- closes an adopter-critical missing flow
- removes a major install/onboarding/support-truth gap
- turns a partial wedge into a truly usable one
- proves a public claim honestly in CI/docs/install-smoke

Avoid milestones that are mainly:

- niche breadth before the main wedge is truly usable
- prestige integrations without clear adopter pull
- architecture churn without user-facing gain
- polishing every edge before the core story is obviously strong

## Confidence handling

Lower confidence when:

- planning files disagree with shipped behavior
- tests exist but do not exercise the public story
- examples are stale or missing
- install path is implied rather than proved
- support posture is described but not mechanized

Say this directly rather than smoothing it over.
