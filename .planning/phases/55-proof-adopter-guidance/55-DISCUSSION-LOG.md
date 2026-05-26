# Phase 55: Proof + Adopter Guidance - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or
> execution agents.
> Decisions captured in `55-CONTEXT.md` are authoritative; this log preserves
> the discuss-all research and narrowing path.

**Date:** 2026-05-26
**Phase:** 55-proof-adopter-guidance
**Mode:** discuss-all + advisor research
**Areas analyzed:** hermetic proof posture, adopter-facing proof lane, guidance
surface, support-truth guardrails

## Research Synthesis

### Hermetic proof posture
| Compared | Recommendation | Why |
|---|---|---|
| Focused ExUnit facade/worker proof vs bespoke proof harness vs broader integration-heavy merge gate | Keep merge-blocking hermetic proof focused on existing ExUnit seams around `Rindle`, `OwnerErasure`, and `PurgeStorage` | Lowest maintenance, best Elixir OSS fit, strongest contract-to-test mapping, no new harness drift |

### Adopter-facing proof lane
| Compared | Recommendation | Why |
|---|---|---|
| Canonical adopter lifecycle proof vs generated-app smoke extension vs docs-only demo | Use canonical adopter proof plus docs parity, not generated-app smoke | Matches existing proof taxonomy: package-consumer smoke proves install truth, canonical adopter proves public lifecycle semantics |

### Guidance surface
| Compared | Recommendation | Why |
|---|---|---|
| Temporary note only vs fuller `guides/user_flows.md` section vs dedicated guide / broad rewrite | Upgrade `guides/user_flows.md` into the canonical owner-erasure story and keep other docs thin | Best DX clarity with lowest duplication; matches the repo’s job-oriented docs structure |

### Support-truth guardrails
| Compared | Recommendation | Why |
|---|---|---|
| Docs parity only vs docs parity + API boundary + active planning updates vs broader audit-heavy process | Use the bounded three-part guardrail set | Strong enough to prevent drift, cheaper and more durable than process-heavy audits |

## Pros / Cons / Tradeoffs Highlights

### Focused hermetic proof
- **Pros:** direct proof of public report semantics, purge safety, idempotent
  reruns, and worker behavior; fastest feedback loop; least surprising to
  Elixir contributors.
- **Cons:** less “full-stack” than a bigger integration lane; requires
  discipline not to overfit to implementation details.
- **Tradeoff accepted:** semantic contract clarity matters more than heavier
  environment realism for this merge gate.

### Canonical adopter proof
- **Pros:** proves the actual public facade in an adopter-shaped environment;
  keeps install smoke scoped; strong support-truth value.
- **Cons:** does not prove packaged-artifact install behavior for this one verb
  specifically.
- **Tradeoff accepted:** install truth and lifecycle semantics are intentionally
  separate proof layers in this repo.

### Canonical docs surface
- **Pros:** one place for preview/execute flow, retained shared assets, and
  async purge truth; low duplication; better copy-paste UX.
- **Cons:** requires a slightly larger `user_flows` section than the current
  temporary note.
- **Tradeoff accepted:** one good canonical story is better than many shallow
  mentions.

### Bounded truth guardrails
- **Pros:** freezes adopter docs, public facade wording, and planning truth
  together; low recurring ceremony.
- **Cons:** requires touching tests and planning artifacts together when the
  story changes.
- **Tradeoff accepted:** bounded ceremony is preferable to broad audit process.

## Adjacent Ecosystem Lessons Applied

- **Rails Active Storage:** explicit attachment/blob split, async purge
  semantics, and strong separation between lifecycle verbs and maintenance
  cleanup were the most relevant lessons.
- **Shrine:** explicit attacher boundary, background deletion, and
  concurrency-safe lifecycle behavior reinforced the recommendation to prove the
  public verb rather than internal loops.
- **Spatie Media Library:** strong adopter DX and responsive-image ergonomics
  were useful reminders to keep user-facing guidance concrete and copyable, but
  not a reason to broaden Phase 55’s scope.

## Footguns Locked

1. Do not add a bespoke owner-erasure proof harness when existing ExUnit seams
   already express the contract clearly.
2. Do not expand generated-app smoke into a catch-all lifecycle matrix.
3. Do not teach `detach/3` loops plus `cleanup_orphans` as the supported
   account-deletion story.
4. Do not imply inline byte deletion; the contract remains detach now, purge
   later.
5. Do not imply Rindle deletes the adopter’s account row.
6. Do not duplicate the owner-erasure semantics across multiple guides with
   drift-prone wording.
7. Do not create a separate audit ledger or process-heavy truth ritual for this
   narrow wedge.

## Advisor Inputs Used

- Hermetic proof advisor: focused ExUnit proof over bespoke harness or heavy
  integration lane.
- Adopter-proof advisor: canonical adopter lane over generated-app smoke
  expansion.
- Guidance-surface advisor: `guides/user_flows.md` as canonical docs home.
- Support-truth advisor: docs parity + API boundary + planning artifact updates
  as the bounded truth guardrail set.

## External Prior Art Referenced

- https://guides.rubyonrails.org/active_storage_overview.html
- https://api.rubyonrails.org/classes/ActiveStorage/Attachment.html
- https://shrinerb.com/docs/attacher
- https://shrinerb.com/docs/plugins/backgrounding
- https://shrinerb.com/docs/plugins/derivatives
- https://spatie.be/docs/laravel-medialibrary/v11/introduction
- https://spatie.be/docs/laravel-medialibrary/v11/converting-images/defining-conversions
- https://spatie.be/docs/laravel-medialibrary/v11/responsive-images/getting-started-with-responsive-images
