# Phase 50: Phoenix Proof + Parity Closure - Context

**Gathered:** 2026-05-25 (assumptions mode + subagent research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Prove the documented Phoenix / LiveView tus adopter path end to end and freeze
it against future drift. Phase 50 closes the remaining proof gap for the
already-shipped Phoenix-facing seam by making the package-consumer proof cover
`Rindle.LiveView.allow_tus_upload/4`, the documented `uploader: "RindleTus"`
client contract, and completion through `consume_uploaded_entries/3` and
`verify_completion/2`.

This phase does not broaden the product surface. It does not add a reusable
uploader component kit, a standalone JS package, broader provider-agnostic
Phoenix abstractions, or new tus protocol extensions.
</domain>

<decisions>
## Implementation Decisions

### Package-consumer proof shape
- **D-01:** Extend the existing generated-app `:tus` install-smoke lane into
  the canonical Phoenix / LiveView proof instead of creating a second
  Phoenix-specific proof lane or relying only on in-repo helper tests.
- **D-02:** Keep the current lower-level bare `TusPlug` drop-and-resume proof as
  a sub-proof underneath the Phoenix-facing proof rather than replacing it.
  Phase 50 adds the missing LiveView/helper layer on top of the existing
  transport/runtime proof.
- **D-03:** The merge-blocking package-consumer proof for this phase must
  exercise the documented adopter path itself:
  `allow_tus_upload/4` -> `uploader: "RindleTus"` -> honest upload-state
  progression -> `consume_uploaded_entries/3` -> `verify_completion/2`.

### Parity gate scope
- **D-04:** Freeze parity at the narrow-contract layer of guide + helper +
  executable proof harness/report, not docs-only parity and not broad
  generated-source snapshot parity.
- **D-05:** Keep fast local parity/unit assertions for support truth and helper
  metadata, then extend the existing generated-app tus proof/report assertions
  so drift between the guide, helper contract, and proof harness fails fast.
- **D-06:** Do not introduce whole generated-app template snapshots or other
  high-churn parity gates. They are the wrong abstraction level for this repo
  and would raise maintenance noise without increasing trust in the Phoenix tus
  contract.

### Public contract and UX semantics under proof
- **D-07:** The proof and parity surface must freeze the exact narrow Phoenix
  contract already documented in Phase 49:
  required `:path` and `:secret_key_base`, optional `:actor`, adopter-owned
  router/auth/parser/CORS wiring, canonical `RindleTus` uploader behavior, and
  completion through `consume_uploaded_entries/3` / `verify_completion/2`.
- **D-08:** Proof artifacts must preserve the honest public state split:
  `uploading` while bytes move, `verifying` after transport reaches `100%`,
  `ready` only after server completion succeeds, and `error` for transport or
  verification failure. `100%` means bytes transferred, not asset readiness.
- **D-09:** Package-consumer proof artifacts should remain machine-readable and
  be extended with Phoenix-facing evidence rather than becoming prose-only test
  output. Auditability matters more than clever test structure.

### Ecosystem posture and architecture fit
- **D-10:** Keep the Phoenix-facing layer idiomatic and thin. The supported seam
  should remain a small wrapper over LiveView’s `:external` upload model rather
  than growing into a second framework-level uploader abstraction.
- **D-11:** Favor explicit, concurrency-safe, proof-friendly contracts over
  convenience breadth. In practice this means proving the existing seam,
  keeping lifecycle completion explicit, and extending artifact-backed proof
  rather than inventing new abstraction layers in Phase 50.
- **D-12:** Preserve the repo’s layered proof posture:
  local hermetic contract tests for helper semantics,
  local parity tests for documentation/support truth,
  and heavier generated-app package-consumer proof for end-to-end adopter
  reality.

### Shift-left recommendation posture
- **D-13:** Phase 50 should return one coherent proof recommendation set by
  default and proceed with it. Local proof-harness structure, naming,
  assertion granularity, and wording details are agent-decided and recorded,
  not escalated.
- **D-14:** Alternatives may be recorded for rationale only. Escalate only for
  high-blast-radius changes such as semver-significant public API reshapes,
  security-boundary changes, destructive behavior changes, major recurring-cost
  surprises, or milestone/scope expansion.

### the agent's Discretion
- Exact proof-report field names and assertion placement, as long as D-01
  through D-09 remain true.
- Exact split between low-cost parity tests and heavier generated-app proof,
  as long as the package-consumer Phoenix path remains merge-blocking and
  auditable.
- Exact wording of user-facing status labels and proof summaries, as long as
  the `uploading` / `verifying` / `ready` / `error` contract stays honest.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active phase contract
- `.planning/ROADMAP.md` — Phase 50 goal and success criteria.
- `.planning/REQUIREMENTS.md` — `PROOF-01` and `PROOF-02`, plus the package-
  consumer and docs-parity proof posture.
- `.planning/PROJECT.md` — project thesis and decision-by-default contract.
- `.planning/STATE.md` — current milestone status and proof gap framing.

### Locked prior Phoenix/tus decisions
- `.planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md` — locked
  support-truth boundary for the shipped Phoenix seam.
- `.planning/phases/49-liveview-tus-productization/49-CONTEXT.md` — locked
  helper contract, `RindleTus` uploader posture, and honest UI vocabulary.
- `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-CONTEXT.md`
  — current generated-app tus proof authority and artifact posture.
- `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-CONTEXT.md`
  — inherited tus docs/DX/proof posture.
- `.planning/phases/42-tus-protocol-edge-bare-plug/42-CONTEXT.md` — locked tus
  edge and completion-lane architecture.

### Source-of-truth code/docs for the Phoenix seam
- `guides/resumable_uploads.md` — canonical Phoenix / LiveView tus guide.
- `lib/rindle/live_view.ex` — shipped `allow_tus_upload/4` helper contract.
- `lib/rindle.ex` — public `initiate_tus_upload/2` and `verify_completion/2`
  surfaces.
- `test/rindle/live_view_test.exs` — helper metadata and actor behavior
  assertions.

### Proof and parity anchors
- `test/install_smoke/generated_app_smoke_test.exs` — package-consumer proof
  matrix and current `:tus` lane authority.
- `test/install_smoke/support/generated_app_helper.ex` — generated-app setup,
  Node proof harness, and machine-readable tus report/debug-report plumbing.
- `test/install_smoke/phoenix_tus_truth_parity_test.exs` — existing support-
  truth parity guard for the shipped Phoenix seam.
- `test/install_smoke/docs_parity_test.exs` — established docs-contract test
  posture.
- `.github/workflows/ci.yml` — current CI split between lighter contract tests
  and heavier install-smoke/package-consumer proof.
- `scripts/install_smoke.sh` — current install-smoke invocation surface.

### Product and prior-art inputs
- `prompts/phoenix-media-uploads-lib-deep-research.md` — prior-art lessons on
  explicit lifecycle boundaries, lazy-vs-eager proof posture, and media-library
  DX.
- `prompts/gsd-rindle-elixir-oss-dna.md` — repo-level defaults around truth
  ownership, docs contracts, package-consumer proof, and decide-by-default.
- `prompts/gsd-rindle-gsd-bootstrap-brief.md` — locked project defaults for
  one coherent recommendation set, explicit proof surfaces, and low-blast-
  radius autonomy.
- `prompts/rindle-brand-book.md` — calm explicit voice, anti-hype constraints,
  and status-language expectations.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/install_smoke/generated_app_smoke_test.exs` already treats profile-based
  generated-app smoke lanes as package-consumer proof authority.
- `test/install_smoke/support/generated_app_helper.ex` already knows how to
  generate the Phoenix app, patch router/runtime setup, boot a real endpoint,
  drive `tus-js-client`, and persist machine-readable tus proof artifacts.
- `test/install_smoke/phoenix_tus_truth_parity_test.exs` already freezes the
  support-truth boundary and can be extended rather than replaced.
- `test/rindle/live_view_test.exs` already freezes the helper metadata shape
  (`uploader`, `endpoint`, `upload_url`, `session_id`, `asset_id`) and actor
  semantics.

### Established Patterns
- Rindle uses layered proof: local contract tests for semantics, install-smoke
  tests for consumer reality, and parity tests for docs/support truth.
- Canonical adopter truth lives in guides plus executable proof, not in broad
  duplicated API-doc narratives or template snapshots.
- The codebase favors extending existing proof anchors over creating parallel
  competing proof systems.
- Machine-readable proof artifacts are preferred over prose-only reporting.

### Integration Points
- Phase 50 should connect `allow_tus_upload/4` and the canonical guide to the
  existing generated-app `:tus` lane so that the package-consumer proof
  exercises the documented Phoenix path.
- The generated-app proof harness should emit Phoenix-facing evidence that can
  be checked by parity tests without snapshotting the entire generated app.
- CI should continue using a split posture: fast local contract/parity checks
  plus heavier install-smoke proof for the generated Phoenix app.
</code_context>

<specifics>
## Specific Ideas

- Treat the existing generated-app `:tus` lane as the proof foundation and
  productize it upward into a LiveView/helper proof rather than sideways into a
  second proof lane.
- Freeze only the contract that matters:
  guide wording and examples,
  helper metadata/required options,
  executable proof/report evidence,
  and honest state-boundary semantics.
- Keep the Phoenix-facing contract “small but real”: a thin helper seam over
  LiveView `:external`, not a batteries-included uploader framework.
- Shift-left the decision posture in this phase explicitly:
  choose one proof shape, record rejected alternatives for rationale, and avoid
  maintainer arbitration on local proof/doc ergonomics unless the blast radius
  is genuinely high.
</specifics>

<deferred>
## Deferred Ideas

- Separate Phoenix-specific generated-app proof lane distinct from the existing
  `:tus` lane.
- Broad generated-app source snapshot parity.
- Reusable uploader UI/component abstractions beyond the current helper seam.
- Rindle-owned standalone tus JS client package.
- Broader provider-agnostic Phoenix upload abstractions and new tus protocol
  extensions.

### Reviewed Todos (not folded)
None — `todo.match-phase` returned no Phase 50 matches.
</deferred>

---

*Phase: 50-phoenix-proof-parity-closure*
*Context gathered: 2026-05-25*
