# Phase 41: Onboarding + Docs + Doctor + Package-Consumer Proof - Context

**Gathered:** 2026-05-07
**Status:** Ready for planning
**Mode:** Research-driven one-shot with advisor subagents. Per user instruction, discuss all remaining gray areas, synthesize one coherent recommendation set, and escalate only for genuinely high-blast-radius decisions.

<domain>
## Phase Boundary

Lock the adopter-facing close-out for GCS resumable uploads so the shipped
runtime from Phases 37-40 becomes a maintainable, least-surprise onboarding
story:

- expand `guides/storage_gcs.md` from its interim secret-hygiene note into the
  canonical deep GCS resumable guide
- update `guides/storage_capabilities.md` so resumable capability messaging is
  honest and adapter-specific
- add Phase 41 GCS-aware `mix rindle.doctor` onboarding checks without adding
  noise for non-GCS adopters
- extend the generated-app install-smoke/package-consumer harness with a GCS
  profile and a real-bucket proof posture that matches the repo's OSS-safe CI
  discipline
- add short README/getting-started pointers while keeping image/AV onboarding
  as the canonical first-run story

Out of scope:

- new resumable runtime semantics or public API beyond what shipped in
  Phases 37-40
- a generic resumable guarantee across all adapters
- tus protocol work
- browser UI work beyond documentation snippets and operator guidance
- turning GCS resumable into the default onboarding lane for all adopters

</domain>

<decisions>
## Implementation Decisions

### Documentation posture

- **D-01:** `guides/storage_gcs.md` is the deep source of truth for GCS
  resumable onboarding. Expand the existing interim note in place rather than
  creating a second GCS guide or bloating `README.md`.
- **D-02:** `README.md` stays narrow. Add only a short optional
  `Storage with GCS (optional)` pointer section, mirroring the existing
  `Streaming with Mux (optional)` posture.
- **D-03:** `guides/getting_started.md` stays canonical for the shortest
  image/AV first success path. Add only a short advanced-path pointer for GCS
  resumable, not a full branching onboarding matrix.
- **D-04:** Duplicate the minimum necessary summary in README/getting-started:
  GCS resumable is an advanced optional path, requires adopter-owned
  Goth/Finch/bucket/signing-key wiring, and should be validated with
  `mix rindle.doctor` before use.
- **D-05:** Keep copy-pasteable runtime wiring, security callouts, bucket/CORS
  setup, session-expiry guidance, operator notes, and resumable lifecycle
  guidance centralized in `guides/storage_gcs.md`.
- **D-06:** `guides/storage_gcs.md` should follow the repo's strongest existing
  guide posture: explicit steps, copy-paste snippets, operational caveats, and
  clear separation between canonical first-run and advanced/provider-specific
  setup.

### Deep GCS guide content

- **D-07:** The locked section set for `guides/storage_gcs.md` is:
  1. Why/when to use GCS resumable uploads in Rindle
  2. Required deps and adopter-owned runtime wiring
  3. Bucket setup and service-account JSON wiring with supervised `MyApp.Goth`
     and `MyApp.Finch`
  4. Signing-key config shape and validation expectations
  5. Profile example enabling `Rindle.Storage.GCS` with resumable support
  6. `gsutil cors set` recipe with `PUT` and `PATCH`, plus
     `Content-Range` and `x-goog-resumable`
  7. `mix rindle.doctor` expectations and common failures
  8. Security callouts: `session_uri` is a bearer credential, logger metadata
     filtering, `cloak_ecto` recipe for at-rest encryption
  9. Operational callouts: one-week session expiry, region pinning/cost
     posture, cleanup/maintenance notes
- **D-08:** The guide should explicitly say Rindle is not a browser upload UI
  framework or file server; adopters own their client/browser integration while
  Rindle owns the durable lifecycle layer.
- **D-09:** The guide should be maintainer-to-maintainer and adopter-friendly:
  decisive, copy-pasteable, and explicit about the few load-bearing footguns
  instead of offering broad option catalogs.

### Capability and public messaging

- **D-10:** `guides/storage_capabilities.md` becomes the canonical semantic
  source of truth for capability vocabulary and adapter honesty; it must no
  longer describe `:resumable_upload` and `:resumable_upload_session` as
  merely reserved.
- **D-11:** Capability messaging uses a two-tier structure:
  - shared semantics live in `guides/storage_capabilities.md`
  - provider-specific onboarding and footguns live in `guides/storage_gcs.md`
- **D-12:** The provider matrix should be adapter-first, not brand-first:
  `Rindle.Storage.Local`, `Rindle.Storage.S3`, `Rindle.Storage.GCS`, with
  provider examples only in notes/proof-posture columns.
- **D-13:** Public messaging must say clearly:
  - `Rindle.Storage.GCS` advertises `:resumable_upload` and
    `:resumable_upload_session`
  - `Rindle.Storage.S3` and `Rindle.Storage.Local` do not
  - adopter-supplied custom adapters may advertise either, both, or neither
    honestly
- **D-14:** README and getting-started should continue describing presigned PUT
  as the canonical first-run path. Resumable upload is a shipped advanced path,
  not the new default story.
- **D-15:** The docs must explicitly call out what remains out of scope:
  no hidden fallback from resumable to presigned PUT, no provider-wide claim
  beyond shipped GCS support, no tus support, and no universal resumable
  abstraction across adapters.

### `mix rindle.doctor` posture

- **D-16:** Keep a single `mix rindle.doctor` entrypoint. Do not add
  `mix rindle.gcs_doctor`, `--gcs`, or `--resumable` modes for Phase 41.
- **D-17:** Preserve zero-noise, profile-aware gating. Non-GCS adopters should
  not see new rows. GCS-but-non-resumable adopters should only see the checks
  relevant to their configured capabilities.
- **D-18:** Existing GCS foundation checks remain hard failures:
  `doctor.gcs_goth_running`, `doctor.gcs_bucket_reachable`,
  `doctor.gcs_signing_key`.
- **D-19:** Add a resumable-specific CORS-suspected check only when at least
  one discovered profile is GCS-backed and advertises
  `:resumable_upload_session`.
- **D-20:** The CORS check is advisory, not blocking. It should surface as a
  warning, not an error, because server-side doctor cannot fully prove browser
  origin success.
- **D-21:** Phase 41 therefore widens doctor reporting beyond binary
  `:ok | :error` semantics to support a first-class warning posture, with clear
  output and explicit exit-code policy.
- **D-22:** Exit-code posture: warnings do not fail the task. Errors still do.
  This keeps `mix rindle.doctor` useful as both an onboarding checklist and a
  CI/operator gate.
- **D-23:** The CORS warning fix text should be operator-first and
  copy-pasteable: allow app origins, `PUT` and `PATCH`, `Content-Range`, and
  `x-goog-resumable`; remind that `session_uri` is a bearer credential,
  sessions expire within one week, and region pinning is normal.
- **D-24:** The CORS check should inspect bucket metadata/API shape that can
  actually reflect bucket CORS configuration. Do not rely on misleading default
  response headers from generic JSON API requests.

### Generated-app package-consumer proof posture

- **D-25:** Add a new generated-app `:gcs` / `gcs-enabled` profile to the
  install-smoke harness by extending the existing `image` / `video` / `mux`
  shape in `test/install_smoke/support/generated_app_helper.ex` and
  `scripts/install_smoke.sh`.
- **D-26:** Do not make a real-bucket generated-app GCS proof an always-on PR
  step inside the existing `package-consumer` job.
- **D-27:** Use a hybrid proof posture:
  - always-on structural generated-app proof for harness/config/doc drift
  - secret-gated real-bucket generated-app soak proof for true end-to-end GCS
    trust
- **D-28:** The real-bucket generated-app GCS proof should be a sibling
  top-level CI job, not a nested step in the default package-consumer lane.
- **D-29:** Secret-gating should mirror the existing OSS-safe posture:
  fail closed when secrets are absent, skip cleanly on fork PRs, and never
  require cloud credentials for routine contributor PR validation.
- **D-30:** The generated-app GCS proof must exercise the real adopter path:
  fresh `mix phx.new` app, installed Rindle artifact, GCS profile wiring,
  `mix rindle.doctor`, initiate resumable session, chunked upload through the
  returned session URI, status/verification convergence, and asset promotion.
- **D-31:** The live GCS generated-app lane must use a unique per-run object
  prefix and `if: always()` cleanup. Never print or persist raw `session_uri`
  values in logs or CI output.
- **D-32:** The live proof should stay thin and trustworthy rather than turning
  into a full cloud conformance suite. Use existing unit/Bypass coverage for
  branch-heavy error cases; use the real lane for end-to-end trust only.

### Architecture and DX cohesion

- **D-33:** All recommendations in this phase should stay aligned with
  Rindle's existing architecture:
  one canonical doctor task, one canonical quickstart, dedicated advanced
  guides, adapter-honest capability messaging, and generated-app proof for
  adopter-facing claims.
- **D-34:** Prefer least surprise over maximal discoverability. Advanced GCS
  material should be easy to find, but it must not visually or structurally
  replace the image/AV onboarding story.
- **D-35:** Prefer decisive, research-backed defaults over open-ended option
  lists. Planning/execution should only reopen choices when they materially
  affect semver, security boundaries, destructive behavior, or cost posture.

### Decision-making preference (carried forward, tightened)

- **D-36:** For this phase and adjacent GSD work, downstream agents should
  front-load research, use subagents when helpful, synthesize one coherent
  recommendation set, and decide by default.
- **D-37:** Escalate only for very impactful decisions the user is likely to
  actually care about: public semver reshapes, irreversible/destructive
  operations, security/compliance boundary changes, or real cost surprises.

### the agent's Discretion

- Exact heading names and ordering inside `guides/storage_gcs.md`, so long as
  the locked content set above is preserved.
- Exact warning label/output formatting for `mix rindle.doctor`, so long as
  warnings stay non-failing and clearly distinct from errors.
- Exact naming of the generated-app GCS profile/lane (`:gcs`, `gcs-enabled`,
  etc.), so long as the adopter-facing semantics stay obvious and consistent.

</decisions>

<specifics>
## Specific Ideas

- The winning documentation model is the same one that already works for Mux:
  short optional pointers in canonical entrypoints, deep provider-specific
  guidance in a dedicated guide.
- Capability semantics should read like adapter truth, not marketing copy.
  The right sentence is effectively: resumable is shipped today where the
  adapter honestly advertises it, which is `Rindle.Storage.GCS`.
- The doctor task should behave like a strong maintainer/operator checklist:
  one command, quiet by default when irrelevant, hard failures for deterministic
  runtime blockers, warnings for likely browser footguns.
- The GCS generated-app proof should be credible but not contributor-hostile:
  real bucket when secrets exist, otherwise keep the structural harness green
  without pretending that live GCS behavior was proven.
- `session_uri` secrecy should be treated as seriously in docs/CI/logging as
  existing provider-secret and webhook-secret boundaries.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase and milestone source of truth
- `.planning/ROADMAP.md` — Phase 41 goal, success criteria, and plan-count
  guidance.
- `.planning/REQUIREMENTS.md` — `RESUMABLE-12`, `RESUMABLE-13`,
  `RESUMABLE-14`.
- `.planning/PROJECT.md` — current milestone posture, architecture boundaries,
  and v1.7 scope.
- `.planning/STATE.md` — project-level decision-making preference and current
  phase posture.

### Locked prior context
- `.planning/phases/37-gcs-adapter-foundation/37-CONTEXT.md` — GCS adapter
  shape, doctor foundation checks, and secret-gated GCS proof posture.
- `.planning/phases/39-resumable-adapter-behaviour-broker-wiring/39-CONTEXT.md`
  — shipped resumable capability semantics and broker truth model.
- `.planning/phases/40-maintenance-cancel-contract/40-CONTEXT.md` —
  maintenance/cancel operator posture and resumable visibility constraints.
- `.planning/milestones/v1.6-phases/36-public-dx-onboarding-ci-proof/36-CONTEXT.md`
  — the onboarding/doc/doctor/package-consumer structural template this phase
  should mirror where appropriate.

### Existing code and doc seams
- `guides/storage_gcs.md` — current interim Phase 38 note; Phase 41 expands it
  into the canonical deep guide rather than replacing it.
- `guides/storage_capabilities.md` — capability vocabulary and provider matrix
  that must be updated from reserved to shipped GCS resumable semantics.
- `guides/getting_started.md` — canonical deep onboarding path whose first-run
  posture must remain narrow.
- `README.md` — narrow quickstart that should gain only a short optional GCS
  pointer.
- `lib/mix/tasks/rindle.doctor.ex` — current single-entrypoint doctor task and
  exit-code/output semantics.
- `lib/rindle/ops/runtime_checks.ex` — existing GCS and streaming check
  patterns; Phase 41 layers resumable onboarding checks here without
  restructuring the command surface.
- `scripts/install_smoke.sh` — current install-smoke profile dispatch that
  Phase 41 extends with a GCS lane.
- `test/install_smoke/support/generated_app_helper.ex` — generated-app harness
  for `image`, `video`, and `mux`; the direct template for the GCS profile.
- `test/install_smoke/generated_app_smoke_test.exs` — generated-app assertions
  and lane structure.
- `.github/workflows/ci.yml` — current package-consumer, `mux-soak`, and
  `gcs-soak` topology that Phase 41 should extend coherently.
- `test/rindle/upload/broker_test.exs` — existing live resumable lifecycle
  proof shape that the generated-app GCS lane should mirror rather than invent
  from scratch.

### Research and design sources already locked into the repo
- `.planning/research/v1.6-CANDIDATE-GCS.md` — original GCS/resumable design
  posture, peer-library lessons, and security considerations.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Mix.Tasks.Rindle.Doctor` and `Rindle.Ops.RuntimeChecks` already provide the
  single-command, profile-aware health-check surface Phase 41 should extend.
- `test/install_smoke/support/generated_app_helper.ex` already proves generated
  app install paths across multiple profiles and should be extended rather than
  replaced.
- `.github/workflows/ci.yml` already contains the repo's preferred split
  between always-on proof and secret-gated real-provider soak jobs.

### Established Patterns
- Canonical entry docs stay narrow while provider-specific advanced topics get
  dedicated guides.
- Profile-aware doctor checks suppress irrelevant noise rather than emitting
  universal rows for optional features.
- Real-provider proofs are secret-gated and fail closed; routine contributor
  CI remains deterministic and fork-safe.
- Public-facing capability claims are explicit and adapter-honest.

### Integration Points
- `guides/storage_gcs.md`, `guides/storage_capabilities.md`, `README.md`, and
  `guides/getting_started.md` must be updated together so wording stays
  coherent.
- `lib/mix/tasks/rindle.doctor.ex` and `lib/rindle/ops/runtime_checks.ex` must
  evolve together if warning support is introduced.
- `scripts/install_smoke.sh`, generated-app helper/test files, and GitHub
  workflow lanes must change in lockstep for the GCS generated-app proof.

</code_context>

<deferred>
## Deferred Ideas

- Separate `mix rindle.gcs_doctor` task or `--gcs` mode — rejected for Phase 41
  because it increases surprise and splits operator muscle memory.
- Always-on real-bucket generated-app GCS proof in the default package-consumer
  job — rejected for OSS contributor safety, cost, and flake reasons.
- Turning GCS resumable into the canonical first-run onboarding path —
  explicitly deferred; image/AV remain the default story.

</deferred>

---

*Phase: 41-onboarding-docs-doctor-package-consumer-proof*
*Context gathered: 2026-05-07*
