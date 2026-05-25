# Phase 49: LiveView Tus Productization - Context

**Gathered:** 2026-05-25 (assumptions mode + advisor subagents)
**Status:** Ready for planning

<domain>
## Phase Boundary

Turn the already-shipped Phoenix / LiveView tus helper seam into a copy-pasteable,
supportable adopter contract. Phase 49 productizes the narrow supported path:
`Rindle.LiveView.allow_tus_upload/4`, a documented `uploader: "RindleTus"`
client pattern, and an honest UI-state model that still completes through
`consume_uploaded_entries/3` and `verify_completion/2`.

This phase does not add a reusable uploader component library, a standalone JS
package, a broader provider-agnostic Phoenix upload abstraction, or new tus
protocol extensions. Those remain deferred.
</domain>

<decisions>
## Implementation Decisions

### Phoenix / LiveView server contract
- **D-01:** Keep `Rindle.LiveView.allow_tus_upload/4` as a thin LiveView
  convenience seam over the shipped tus path rather than growing a broader
  Phoenix abstraction. The helper should stay a small wrapper around LiveView's
  `:external` upload contract, not a second framework.
- **D-02:** The supported server-side contract for this phase is explicit and
  narrow: required `:path` and `:secret_key_base`, optional `:actor`, adopter-
  owned router/auth/parser/CORS wiring, and completion through
  `consume_uploaded_entries/3`.
- **D-03:** Keep the canonical Phoenix / LiveView tus setup in
  `guides/resumable_uploads.md`. API docs in `Rindle.LiveView` should stay thin
  and point to that guide instead of duplicating the full setup narrative.

### Client uploader contract
- **D-04:** The canonical browser client remains a tiny documented
  `uploader: "RindleTus"` adapter over `tus-js-client`. Rindle should freeze the
  uploader shape and behavior through docs/tests, not by owning a JS package in
  this phase.
- **D-05:** The supported uploader contract must explicitly reuse the signed
  `upload_url`, perform resume discovery via `findPreviousUploads()`, resume via
  `resumeFromPreviousUpload(...)`, and preserve tus offset truth instead of
  inventing alternate client-side progress semantics.
- **D-06:** `@uppy/tus` may remain mentioned as a compatible alternative, but
  it is not the canonical Phase 49 LiveView path. Rindle should not bless a UI
  stack as the default story for this milestone.

### UI-state model
- **D-07:** Freeze a small honest public UI vocabulary: `uploading` while bytes
  are moving, `verifying` after transport reaches `100%`, and `ready` only after
  `consume_uploaded_entries/3` / `verify_completion/2` succeed. `error` remains
  the failure sink.
- **D-08:** Treat `100%` as "bytes transferred", not "asset ready". The guide
  and examples must explicitly separate transfer completion from server truth.
- **D-09:** Richer sublabels such as `resuming` or `retrying` are additive
  examples only, not part of the promised universal UI contract for this phase.

### Boundary discipline
- **D-10:** Phase 49 productizes only the already-shipped narrow helper path.
  Do not introduce a reusable drag/drop component kit, standalone npm package,
  provider-agnostic upload DSL, or broader Phoenix abstraction surface here.
- **D-11:** Preserve capability honesty across docs and examples. The Phase 49
  path is the Phoenix / LiveView helper seam over the existing tus edge and
  completion lane, not a batteries-included uploader framework.

### Downstream recommendation posture
- **D-12:** For this phase, downstream research/planning/execution should keep
  the project default posture explicit: produce one coherent recommendation set,
  decide by default on local/additive/ergonomic choices, and escalate only for
  genuinely high-blast-radius decisions such as semver-significant public API
  reshapes, security-boundary changes, destructive irreversibility, major cost
  surprises, or milestone/scope changes.

### the agent's Discretion
- Exact helper-doc wording and option-table formatting, as long as D-01 through
  D-03 stay intact.
- Exact `RindleTus` snippet shape and code style, as long as D-04 through D-06
  remain true.
- Exact sample UI labels/copy around `uploading`, `verifying`, and `ready`, as
  long as D-07 through D-09 remain true.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Active phase contract
- `.planning/ROADMAP.md` — Phase 49 goal and success criteria.
- `.planning/REQUIREMENTS.md` — `PHX-02`, `PHX-03`, and `PHX-04`.
- `.planning/PROJECT.md` — project thesis, support truth, and decision-making
  contract.
- `.planning/STATE.md` — active milestone posture and current focus.

### Locked prior Phoenix/tus decisions
- `.planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md` — locked
  support-truth boundary for the shipped helper seam.
- `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-CONTEXT.md`
  — locked tus auth, DX, proof, and guide posture.
- `.planning/phases/42-tus-protocol-edge-bare-plug/42-CONTEXT.md` — locked tus
  edge, capability, and completion-lane architecture.
- `.planning/research/v1.8/TUS-RESEARCH.md` — locked tus architecture and
  ecosystem tradeoffs.
- `.planning/research/v1.8/STRATEGY-SEQUENCING.md` — milestone sequencing and
  boundary rationale for the Phoenix DX wedge.

### Source-of-truth code/docs for the shipped seam
- `lib/rindle/live_view.ex` — shipped `allow_tus_upload/4` helper contract.
- `guides/resumable_uploads.md` — canonical Phoenix / LiveView tus guide.
- `lib/rindle.ex` — public `initiate_tus_upload/2` and `verify_completion/2`
  surfaces.
- `lib/rindle/upload/tus_plug.ex` — signed upload URL and tus edge semantics.
- `lib/rindle/upload/broker.ex` — persisted completion boundary and verification
  lane.

### Proof and parity anchors
- `test/rindle/live_view_test.exs` — current helper semantics and metadata shape.
- `test/install_smoke/phoenix_tus_truth_parity_test.exs` — truth-alignment guard
  for the shipped Phoenix tus seam.
- `test/install_smoke/generated_app_smoke_test.exs` — package-consumer tus proof
  and guide parity baseline.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Rindle.LiveView.allow_tus_upload/4` already returns the right narrow metadata
  contract: `uploader`, `endpoint`, `upload_url`, `session_id`, and `asset_id`.
- `guides/resumable_uploads.md` already contains the core Phoenix / LiveView tus
  story, including the `RindleTus` uploader example and the transfer vs
  verification state split.
- `Rindle.initiate_tus_upload/2` and `Rindle.Upload.TusPlug.create_upload/2`
  already preserve the signed bearer-URL contract needed by browser tus clients.
- Existing parity/proof tests already guard the support truth boundary and can be
  extended instead of inventing a new proof posture.

### Established Patterns
- Phoenix-specific convenience layers in Rindle wrap core lifecycle contracts
  instead of owning separate lifecycles.
- Canonical adopter truth lives in guides plus targeted parity tests, not in
  duplicated API-doc narratives.
- Capability honesty and explicit contracts beat broad convenience claims.
- Rindle already prefers one coherent recommendation set and explicit deferred
  boundaries rather than menus of equal options.

### Integration Points
- `allow_tus_upload/4` sits on top of `initiate_tus_upload/2`, which in turn
  sits on top of the existing tus Plug and broker verification lane.
- The browser uploader contract must stay aligned with LiveView's `:external`
  upload model and the signed `upload_url` minted by the tus edge.
- UI examples must connect client byte progress to the existing server
  verification boundary without implying a second completion model.
</code_context>

<specifics>
## Specific Ideas

- Treat the supported `RindleTus` uploader as a tiny copy-pasteable contract,
  not as the seed of a JS product surface.
- Phrase the public UI contract as a small two-layer model: contractual public
  states (`uploading`, `verifying`, `ready`/`error`) with optional richer local
  labels left to adopters.
- Keep the canonical story calm and explicit: host app owns router/auth/parser/
  CORS wiring; Rindle owns the signed tus edge, helper seam, and completion
  truth.
</specifics>

<deferred>
## Deferred Ideas

- Reusable uploader UI/component abstractions beyond the current helper seam.
- Rindle-owned standalone tus JS client package.
- Broader provider-agnostic Phoenix upload abstractions.
- Additional tus protocol extensions or new upload topology work.

### Reviewed Todos (not folded)
None — `todo.match-phase` returned no Phase 49 matches.
</deferred>

---

*Phase: 49-liveview-tus-productization*
*Context gathered: 2026-05-25*
