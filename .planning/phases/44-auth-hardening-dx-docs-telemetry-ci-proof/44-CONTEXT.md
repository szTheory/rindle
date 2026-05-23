# Phase 44: Auth Hardening, DX, Docs, Telemetry, CI Proof - Context

**Gathered:** 2026-05-23 (assumptions mode + targeted research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make the shipped tus spine adopter-ready and trustworthy without widening the
core architecture: keep the auth posture honest, freeze the adopter-facing tus
error/DX contract, extend resumable telemetry coherently, publish copy-pasteable
setup guidance, prove browser drop-and-resume through a generated-app
package-consumer lane, and selectively close the Phase 35 review debt that
touches this trust boundary. This phase clarifies how tus is operated and
supported; it does not add a new upload topology, a new telemetry family, or a
new higher-level auth abstraction.
</domain>

<decisions>
## Implementation Decisions

### Resume authorization posture
- **D-01:** Keep HMAC-signed tus URLs as the default resume authority and keep
  same-user resume enforcement OPTIONAL via
  `config :rindle, :tus_resume_authorizer, MyApp.TusAuth`. Do NOT make same-user
  enforcement the library default. This preserves the adopter-owned auth
  boundary, keeps anonymous/login-churn/shared-device flows possible, and
  matches the bare-Plug/library posture.
- **D-02:** Be explicit in docs and operator language that the returned tus
  `Location` is a short-lived bearer credential. HMAC proves URL integrity and
  issuance, not same-user binding. The optional authorizer is the additive
  hardening layer for apps that need same-user resume semantics.
- **D-03:** Actor extraction remains adopter-defined through the Plug mount's
  `identity_fn` and auth pipeline. Rindle does NOT standardize cross-app actor
  semantics beyond passing `token_actor`, `session`, `profile`, and `method` to
  the configured authorizer.

### Public error contract and operator DX
- **D-04:** Keep the public tus-facing `Rindle.Error` vocabulary THIN and
  fix-oriented: `:tus_session_not_found`, `:tus_session_expired`,
  `:tus_offset_conflict`, `:tus_size_exceeded`,
  `:tus_url_signature_invalid`, and `{:upload_unsupported, :tus_upload}`. Do
  NOT grow a wider public atom taxonomy for environment/setup edge cases.
- **D-05:** `TusPlug` itself stays protocol-native at the HTTP edge: use tus
  status/header semantics (`404/410/409/413/401` plus tus headers) instead of
  mirroring those cases through a second public HTTP-error abstraction.
- **D-06:** `mix rindle.doctor` is the supported place for tus capability and
  config drift checks. Keep it config-driven through `:tus_profiles`; do NOT try
  to introspect Phoenix routes. Cross-component setup diagnosis belongs in
  doctor and guides, not in extra runtime error variants.

### Telemetry contract
- **D-07:** Reuse the existing public resumable telemetry namespace
  `[:rindle, :upload, :resumable, *]` for tus. Distinguish topology through a
  low-cardinality `protocol` metadata field (`:tus` vs `:gcs_native`) instead of
  creating a new `[:rindle, :upload, :tus, *]` family.
- **D-08:** Preserve the deny-by-default metadata posture. Never emit
  `session_uri`, `upload_key`, raw headers, request bodies, or decoded upload
  metadata in tus telemetry. Metadata remains allowlisted, redacted, and
  operator-useful rather than exhaustively descriptive.

### Docs and generated-app proof
- **D-09:** `guides/resumable_uploads.md` is the canonical adopter document for
  the tus edge. It must carry the parser/CORS/security/client-setup story,
  clearly separate `tus-js-client` from modern `@uppy/tus` behavior, and call
  out client-version footguns instead of trying to encode those nuances in the
  runtime error surface.
- **D-10:** Keep one merge-blocking generated-app package-consumer tus proof
  lane that mounts `TusPlug`, performs one real socket-level interrupted upload
  and resume through `tus-js-client` against MinIO, and asserts downstream
  `MediaAsset`/variant convergence. Do NOT downgrade this to fake-only proof.
  Broader soak or matrix expansion can be nightly/manual later.
- **D-11:** The S3/MinIO tus posture remains single-node or sticky-session in
  v1. Document it honestly in the guide and proof expectations; Phase 44 does
  NOT try to solve cross-node tail sharing.

### POLISH-02 posture
- **D-12:** Resolve the Phase 35 review findings that directly strengthen this
  phase's trust boundary and operator UX: WR-01, WR-02, WR-03, WR-04, WR-05,
  and WR-06. They harden body limits, idempotency drift, config honesty, and
  runtime-status usefulness.
- **D-13:** INFO-only or speculative Phase 35 items stay waived unless they
  materially change current adopter-facing behavior. This phase is not a blanket
  webhook cleanup pass; it is a targeted trust-boundary polish pass.

### the agent's Discretion
- Exact doctor copy and guide phrasing, as long as they remain calm,
  production-aware, and explicit about footguns.
- Whether POLISH-02 findings are closed by code changes versus narrow wording
  improvements when the operator-facing outcome is identical.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase contract
- `.planning/ROADMAP.md` — Phase 44 goal, success criteria, and locked phase
  boundary.
- `.planning/REQUIREMENTS.md` — TUS-10..14 and POLISH-02 contract.
- `.planning/PROJECT.md` — project constitution, scope, and decision-making
  contract.
- `.planning/STATE.md` — current milestone status, operator preferences, and
  active v1.8 notes.

### Prior locked tus decisions
- `.planning/phases/42-tus-protocol-edge-bare-plug/42-CONTEXT.md` — Phase 42
  decisions the auth/DX layer inherits.
- `.planning/research/v1.8/TUS-RESEARCH.md` — authoritative locked tus
  architecture and protocol posture.
- `.planning/research/v1.8/STRATEGY-SEQUENCING.md` — sequencing, budget cut
  order, and milestone fit.

### Code-review debt source
- `.planning/milestones/v1.6-phases/35-signed-webhook-plug-idempotent-ingest/35-REVIEW.md`
  — POLISH-02 source findings and severity split.

### Project worldview / prior-art
- `prompts/gsd-rindle-elixir-oss-dna.md` — stable OSS/library operating rules:
  explicit contracts, docs/CI as contract surface, metadata policy.
- `prompts/gsd-rindle-research-index.md` — research map and prior-art source
  index.
- `prompts/phoenix-media-uploads-lib-deep-research.md` — ecosystem lessons:
  Active Storage, Shrine, Spatie, Mux, tus, provider capability honesty.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/rindle/upload/tus_plug.ex` — already contains the HMAC token flow,
  optional `tus_resume_authorizer`, protocol-native status mapping, and emit
  points for resumable telemetry.
- `lib/rindle/error.ex` — already carries the narrow fix-oriented tus reason
  vocabulary and is the right stable adopter-facing error surface.
- `lib/rindle/upload/resumable_telemetry.ex` and
  `test/rindle/contracts/telemetry_contract_test.exs` — existing stable wrapper
  and contract tests for the resumable namespace.
- `lib/rindle/ops/runtime_checks.ex` and `lib/mix/tasks/rindle.doctor.ex` —
  existing doctor posture and config-driven capability checks.
- `guides/resumable_uploads.md` — already the natural canonical doc for parser,
  CORS, security, and client guidance.
- `test/install_smoke/support/generated_app_helper.ex` and
  `test/install_smoke/generated_app_smoke_test.exs` — generated-app tus proof
  harness is already present and should remain the package-consumer truth
  surface.

### Established Patterns
- Public contracts stay small and explicit; runtime/config drift is pushed into
  doctor, telemetry, guides, and generated-app proof rather than a ballooning
  public API.
- Storage/provider capability honesty beats faux parity. Unsupported tus mounts
  fail loudly at init time; no silent downgrade.
- Telemetry uses wrapper modules plus metadata allowlists, not ad hoc
  `:telemetry.execute` calls or rich unbounded metadata.
- Generated-app/package-consumer proof is treated as contract truth, not a
  nice-to-have CI extra.

### Integration Points
- `TusPlug` auth and edge semantics connect to `Config.tus_resume_authorizer/0`,
  `Rindle.Error`, and `ResumableTelemetry`.
- Doctor checks connect `:tus_profiles` config to adapter capability truth.
- Guide content must stay aligned with the actual `TusPlug` mount contract and
  generated-app proof lane.
- POLISH-02 work touches the signed-webhook/runtime-status/operator trust
  boundary adjacent to this phase's auth and DX concerns.
</code_context>

<specifics>
## Specific Ideas

- Treat the tus `Location` URL exactly as an opaque bearer credential and say so
  plainly in the guide.
- Call out current client-specific nuance explicitly: `tus-js-client` versus
  modern `@uppy/tus` behavior should be documented by client/version instead of
  assumed interchangeable.
- Keep one real interrupted-upload proof in CI because fake-only coverage misses
  the exact failure mode tus exists to solve.
</specifics>

<deferred>
## Deferred Ideas

- Making same-user resume enforcement the default policy — deferred
  indefinitely unless Rindle ever owns a canonical auth model (not current
  project shape).
- Splitting tus into a separate public telemetry family — deferred; current
  recommendation is one resumable family with `protocol` metadata.
- Broader tus soak/matrix coverage beyond one merge-blocking package-consumer
  proof lane — future nightly/manual expansion if CI budget warrants it.
- Cross-node/shared-tail S3 tus resume — out of scope for v1.8 Phase 44; keep
  sticky-session or single-node constraint documented honestly.

### Reviewed Todos (not folded)
None — `todo.match-phase` returned no Phase 44 matches.
</deferred>
