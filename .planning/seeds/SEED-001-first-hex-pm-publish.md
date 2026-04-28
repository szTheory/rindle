---
id: SEED-001
status: dormant
planted: 2026-04-28
planted_during: v1.1 / Phase 08
trigger_when: "When package-consumer install proof is complete or the next milestone scope includes first public package publication / release automation."
scope: Medium
---

# SEED-001: Plan the first Hex.pm publish for Rindle

## Why This Matters

Rindle now looks like a real library project, but it is not yet published on
Hex.pm. That means the public adoption story is still inferred from the repo
instead of proven from the package artifact users will actually install.

The right time to surface this is once installability and release confidence
have been proven from the built artifact, because first publish, package
metadata, release automation, and install docs should all land against the same
validated release path.

## When to Surface

**Trigger:** When package-consumer install proof is complete or the next
milestone scope includes first public package publication / release automation.

This seed should be presented during `$gsd-new-milestone` when the milestone
scope matches any of these conditions:
- Phase 9 or its successor proves installability from the built artifact
- Release-readiness / package publication becomes active milestone scope
- Hex.pm metadata, publish workflow, or first public versioning strategy needs
  to be planned explicitly

## Scope Estimate

**Medium** — likely one focused phase or a small cluster of release-readiness
tasks: package metadata review, publish checklist, CI/release automation,
versioning policy, and first-release docs alignment.

## Breadcrumbs

Related code and decisions found in the current codebase:

- `.planning/ROADMAP.md` — Phase 9 already targets package-consumer install and
  release confidence before broad publication.
- `.planning/PROJECT.md` — install proof is explicitly package-consumer-first,
  not repo-local.
- `.planning/REQUIREMENTS.md` — `RELEASE-01..03` cover fresh install, built
  artifact validation, and docs alignment.
- `.planning/STATE.md` — existing pending todo already says to cut the first
  package-consumer smoke path once Phase 9 is reached.
- `.planning/milestones/v1.0-REQUIREMENTS.md` — prior release lane work
  included Hex dry-run thinking, which is a useful precedent.
- `.github/workflows/ci.yml` — existing CI/release wiring is the likely place
  to extend once first publish becomes in-scope.
- `README.md` — top-level install guidance still references a dependency entry,
  but public publish/distribution posture is not yet proven.

## Notes

- This should not preempt Phase 8.
- The natural milestone hook is after Phase 9 proves installability from the
  built artifact, or at the start of the next milestone if public publication
  becomes the goal.
- If the first publish happens during `0.x`, the plan should explicitly decide
  how much public API/semver stability is being promised.
