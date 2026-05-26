# Phase 55: Proof + Adopter Guidance - Context

**Gathered:** 2026-05-26 (discuss-all research synthesis)
**Status:** Ready for planning

<domain>
## Phase Boundary

Freeze the supported owner/account erasure contract with merge-blocking proof
and adopter-facing guidance. This phase should prove the public facade
semantics already narrowed in Phases 53-54, teach the supported
preview/execute flow honestly, and lock support truth so the repo cannot drift
back to the old detach-loop story.

This phase does not add admin UI, bulk orchestration, force-delete policy for
still-shared assets, or a broader compliance workflow surface.
</domain>

<decisions>
## Implementation Decisions

### Hermetic proof posture
- **D-01:** `PROOF-03` should use focused hermetic ExUnit coverage centered on
  the public facade and purge worker, not a bespoke proof harness.
- **D-02:** The merge-blocking hermetic proof base is:
  `test/rindle/owner_erasure_test.exs`,
  `test/rindle/workers/purge_storage_test.exs`,
  `test/rindle/attach_detach_test.exs`, and
  `test/rindle/api_surface_boundary_test.exs`.
- **D-03:** Hermetic proof must cover the public report shape, execute detach
  behavior, orphan-only purge enqueueing, retained shared assets, purge-worker
  survivor re-checks, and idempotent reruns.
- **D-04:** Hermetic proof should assert semantic contract behavior and worker
  safety, not internal implementation trivia such as `Ecto.Multi` step names
  or helper layout.

### Adopter-facing proof lane
- **D-05:** `PROOF-04` should be satisfied by a canonical adopter lifecycle
  test that exercises `Rindle.preview_owner_erasure/2` and
  `Rindle.erase_owner/2` through the public facade in an adopter-shaped
  app/repo.
- **D-06:** Generated-app/package-consumer install-smoke should remain reserved
  for install/onboarding/package truth and should not be expanded for
  owner-erasure semantics unless the install story itself changes.
- **D-07:** The adopter-facing proof should validate the supported
  account-deletion flow directly, not indirectly through `detach/3` loops plus
  `cleanup_orphans`.
- **D-08:** The adopter-facing proof should stay thinner than the hermetic edge
  matrix; shared-vs-orphan edge cases remain primarily a `PROOF-03` concern.

### Guidance surface
- **D-09:** `guides/user_flows.md` should be the canonical home for supported
  owner/account erasure guidance.
- **D-10:** Replace the current temporary note with a short executable section
  or story that demonstrates `Rindle.preview_owner_erasure/2` and
  `Rindle.erase_owner/2`, explains retained shared assets, and states execute
  semantics honestly as detach now, purge enqueued later.
- **D-11:** Guidance must state that Rindle erases Rindle-managed media
  associations for an owner; it does not delete the adopter's account row.
- **D-12:** `guides/getting_started.md` and `guides/operations.md` should carry
  only brief pointer/boundary text back to `guides/user_flows.md`; do not
  spread the full semantics across multiple guides for this milestone.
- **D-13:** Do not add a standalone owner-erasure guide in Phase 55 unless a
  later milestone broadens scope into admin, bulk, or compliance workflows.

### Support-truth guardrails
- **D-14:** Phase 55 should close support truth with one bounded guardrail set:
  docs parity, public facade boundary checks, and active planning artifact
  updates.
- **D-15:** `test/install_smoke/docs_parity_test.exs` should freeze the
  adopter-facing account-deletion teaching copy so the repo cannot drift back
  to the detach-loop workaround.
- **D-16:** `test/rindle/api_surface_boundary_test.exs` should continue to
  freeze the supported facade names and semantic bucket vocabulary:
  `preview_owner_erasure/2`, `erase_owner/2`,
  `attachments_to_detach`, `assets_to_purge`, and
  `retained_shared_assets`.
- **D-17:** `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/STATE.md`,
  and the Phase 55 verification artifacts must all describe owner/account
  erasure as the supported account-deletion surface and keep `cleanup_orphans`
  maintenance-only.
- **D-18:** Do not introduce a separate audit ledger or broader process-heavy
  truth ritual for this milestone; the repo's existing test + planning surfaces
  are sufficient.

### Cross-ecosystem fit
- **D-19:** Follow the successful pattern from adjacent ecosystems: keep the
  public lifecycle verb explicit, keep destructive storage work async, and
  place the guidance near the attachment/lifecycle surface rather than in
  install or maintenance docs.
- **D-20:** Favor calm, explicit, least-surprise DX over exhaustive
  documentation fan-out or heavyweight proof machinery.

### the agent's Discretion
- Exact owner-erasure example wording and code snippet shape in
  `guides/user_flows.md`, as long as preview/execute, retained-shared-asset
  semantics, and async purge truth remain explicit.
- Exact breakdown of the adopter-facing proof assertions between canonical
  adopter tests and docs parity, as long as `PROOF-04` stays public-facade
  based and generated-app smoke remains install-scoped.
- Exact test names and organization for additional Phase 55 proof cases.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active phase contract
- `.planning/ROADMAP.md` — Phase 55 goal and success criteria.
- `.planning/REQUIREMENTS.md` — `PROOF-03`, `PROOF-04`, `TRUTH-02`, proof
  posture gate, and support-truth gate.
- `.planning/PROJECT.md` — discuss posture, support-truth boundary, and
  decision-making contract.
- `.planning/STATE.md` — active milestone framing and current owner-erasure
  truth.
- `.planning/METHODOLOGY.md` — adopter-first, repo-truth, research-first, and
  narrow-then-escalate lenses.

### Prior phase decisions
- `.planning/phases/53-owner-erasure-contract-truth-gate/53-CONTEXT.md` —
  frozen public contract and support-truth boundary.
- `.planning/phases/54-execute-orphan-safe-purge-wiring/54-CONTEXT.md` —
  execute semantics, shared-asset safety, and report ergonomics inherited by
  Phase 55.
- `.planning/research/SUMMARY.md` — v1.10 wedge summary and proof/doc
  expectations.
- `.planning/research/ARCHITECTURE.md` — owner-erasure integration shape.
- `.planning/research/PITFALLS.md` — destructive-work footguns and prevention
  strategy.
- `.planning/research/FEATURES.md` — proof/doc table stakes and anti-features.
- `.planning/threads/2026-05-25-next-milestone-ordering.md` — why owner
  erasure is the next wedge and why detach loops are not the target surface.

### Existing proof and docs seams
- `lib/rindle.ex` — public owner-erasure facade docs and report vocabulary.
- `lib/rindle/internal/owner_erasure.ex` — shared planner/execute seam and
  semantic report construction.
- `lib/rindle/workers/purge_storage.ex` — async destructive seam and
  surviving-attachment safety boundary.
- `test/rindle/owner_erasure_test.exs` — public preview/execute contract proof
  base.
- `test/rindle/workers/purge_storage_test.exs` — purge-worker shared-asset
  safety proof.
- `test/rindle/attach_detach_test.exs` — existing shared-asset purge behavior
  regression coverage.
- `test/rindle/api_surface_boundary_test.exs` — public docs boundary and
  supported surface freeze.
- `test/adopter/canonical_app/lifecycle_test.exs` — canonical adopter lifecycle
  proof lane for public API semantics.
- `test/install_smoke/generated_app_smoke_test.exs` — install/onboarding/package
  proof lane that should remain out of owner-erasure semantics scope.
- `test/install_smoke/support/generated_app_helper.ex` — generated-app smoke
  infrastructure and scope constraints.
- `test/install_smoke/docs_parity_test.exs` — docs/support-truth freeze harness.
- `guides/user_flows.md` — canonical adopter-facing lifecycle guide surface.
- `guides/getting_started.md` — first-run onboarding surface that should only
  point back to the canonical owner-erasure flow.
- `guides/operations.md` — maintenance-lane docs that must keep
  `cleanup_orphans` out of the owner-erasure contract.

### Prompt and product posture inputs
- `prompts/gsd-rindle-gsd-bootstrap-brief.md` — research-first, one coherent
  recommendation set, and support-truth posture.
- `prompts/gsd-rindle-elixir-oss-dna.md` — explicit-contract, async-side-effect,
  and operator-friendly lifecycle posture.
- `prompts/phoenix-media-uploads-lib-deep-research.md` — prior-art lessons on
  lifecycle APIs, proof posture, cleanup, and DX.
- `prompts/rindle-brand-book.md` — calm, explicit, anti-hype docs voice.

### External prior-art references
- `https://guides.rubyonrails.org/active_storage_overview.html` — explicit
  attach/remove/purge guidance, direct-upload cleanup separation, and variant
  tracker lessons.
- `https://api.rubyonrails.org/classes/ActiveStorage/Attachment.html` —
  attachment/blob split and async purge semantics.
- `https://shrinerb.com/docs/attacher` — explicit attachment lifecycle verbs
  and public-boundary lessons.
- `https://shrinerb.com/docs/plugins/backgrounding` — background deletion and
  concurrency-safety lessons.
- `https://shrinerb.com/docs/plugins/derivatives` — derivative/variant
  explicitness and lifecycle separation.
- `https://spatie.be/docs/laravel-medialibrary/v11/introduction` — media
  library DX positioning.
- `https://spatie.be/docs/laravel-medialibrary/v11/converting-images/defining-conversions`
  — queued conversions and user-facing conversion ergonomics.
- `https://spatie.be/docs/laravel-medialibrary/v11/responsive-images/getting-started-with-responsive-images`
  — responsive-image DX lessons.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/rindle/owner_erasure_test.exs` already proves preview/execute report
  semantics, orphan-only enqueueing, retained shared assets, and idempotent
  reruns; extend it rather than inventing a new proof harness.
- `test/rindle/workers/purge_storage_test.exs` and
  `test/rindle/attach_detach_test.exs` already prove the destructive seam and
  shared-asset survivor behavior that owner erasure relies on.
- `test/adopter/canonical_app/lifecycle_test.exs` is the established
  adopter-shaped lifecycle proof lane and is the correct place to prove the
  public owner-erasure flow.
- `test/install_smoke/docs_parity_test.exs` and
  `test/rindle/api_surface_boundary_test.exs` already freeze support truth and
  public docs boundaries.
- `guides/user_flows.md` is already the highest-visibility job-oriented guide
  and the natural place for the canonical owner-erasure story.

### Established Patterns
- Generated-app/package-consumer smoke is reserved for install/onboarding
  proof, not every lifecycle capability.
- Public lifecycle verbs live on `Rindle`, while destructive storage effects
  happen asynchronously and are described honestly.
- Docs/support truth is enforced with focused string/parity/boundary tests
  rather than heavyweight manual audit processes.
- Planning posture prefers one coherent recommendation set and avoids widening a
  narrow lifecycle wedge into adjacent operator/compliance work.

### Integration Points
- Phase 55 should connect the shipped `Rindle.preview_owner_erasure/2` /
  `Rindle.erase_owner/2` surface to the canonical adopter proof lane.
- Phase 55 should upgrade `guides/user_flows.md` from a temporary note to the
  canonical executable owner-erasure story and add only thin pointers elsewhere.
- Phase 55 verification must align docs parity, API boundary tests, and active
  planning artifacts so the owner-erasure story stays stable after ship.
</code_context>

<specifics>
## Specific Ideas

- Treat proof taxonomy explicitly:
  hermetic ExUnit for semantic edge coverage, canonical adopter proof for
  public-facade lifecycle reality, generated-app smoke for install truth only.
- Prefer one short executable owner-erasure story in `guides/user_flows.md`
  over a dedicated guide or a broad docs rewrite.
- Phrase the contract as:
  preview what will detach/purge/retain, execute the detach, report purge
  enqueueing, and retain shared assets when another attachment survives.
- Keep wording calm and exact:
  “erases Rindle-managed media associations for an owner,” not “deletes the
  account.”
</specifics>

<deferred>
## Deferred Ideas

- Expanding generated-app/package-consumer smoke to exercise owner-erasure
  semantics.
- A standalone owner-erasure guide or broad multi-guide semantic fan-out.
- A separate audit ledger or heavier truth-governance process for this wedge.
- Admin UI, bulk erasure orchestration, and force-delete policy for still-shared
  assets.
</deferred>

---

*Phase: 55-proof-adopter-guidance*
*Context gathered: 2026-05-26*
