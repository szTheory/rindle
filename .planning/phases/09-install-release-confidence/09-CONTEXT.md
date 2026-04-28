# Phase 9: Install & Release Confidence - Context

**Gathered:** 2026-04-28
**Status:** Ready for planning

<domain>
## Phase Boundary

Prove that a fresh Phoenix adopter can install Rindle from the built package
artifact, wire the required runtime pieces without repo-local knowledge, and
complete the canonical upload-to-delivery path. This phase also aligns
top-level onboarding docs with the path the package-consumer proof actually
executes. It does not expand Rindle's media feature surface.

</domain>

<decisions>
## Implementation Decisions

### Install proof shape
- **D-01:** Phase 9 uses a **hybrid install-proof model**: keep the existing
  in-repo adopter fixture for deep lifecycle assertions, but add a
  truly-generated fresh Phoenix app smoke path that installs Rindle from the
  built package artifact.
- **D-02:** The generated-app smoke path is the trust signal for
  `RELEASE-01/02`; the long-lived fixture is supporting proof, not the primary
  installability guarantee.
- **D-03:** The generated-app path may reuse checked-in helper fragments or
  harness scripts for deterministic setup, but those helpers must support a
  real `mix phx.new` app shape rather than replacing it with a repo-local
  pseudo-app.

### CI and release gating
- **D-04:** Installability from the built artifact is validated in a **hybrid
  pipeline**: a slim PR CI smoke lane catches package-consumer regressions
  before merge, and the release workflow keeps the heavier tarball/release
  checks.
- **D-05:** The PR smoke lane should stay intentionally narrow: build the
  package, install it into a clean consumer app, prove the canonical flow, and
  fail loudly on packaging/setup drift. Do not turn it into a second copy of
  the full integration suite.
- **D-06:** The release workflow remains the place for deeper package-focused
  gates such as tarball inspection and `hex.publish --dry-run` posture. Shared
  helper logic is preferred so PR and release checks do not silently diverge.

### Canonical adopter path
- **D-07:** The package-consumer smoke path proves the **presigned PUT**
  canonical flow, not multipart. Multipart remains verified in the deeper
  MinIO-backed capability/integration proofs already established in earlier
  phases.
- **D-08:** Rindle's first-run story must optimize for least surprise: the
  first path taught in docs is the first path proven from the built artifact.
  Advanced capability-gated flows should remain clearly documented and
  explicitly verified elsewhere, not overloaded into smoke.
- **D-09:** Capability honesty still applies in docs: Phase 9 must make clear
  that multipart is supported and proven, but not the default install/onboarding
  path for a brand-new adopter.

### Documentation structure
- **D-10:** `README.md` becomes a **layered quickstart** document: package
  pitch, dependency snippet, short install path, and prominent callouts for the
  adopter-owned Repo contract, Oban expectations, and capability constraints.
- **D-11:** `guides/getting_started.md` remains the **canonical deep guide**
  with the fuller lifecycle walkthrough and operational detail. README should
  hand off to it explicitly rather than duplicating all nuance.
- **D-12:** Some duplication between README and the guide is acceptable for the
  install snippet and quickstart, but there must be one declared canonical path
  that planning can keep drift-tested.

### Decision authority and DX posture
- **D-13:** Phase 9 planning should bias toward **agent-decided defaults** for
  implementation details, tradeoffs, and document structure unless a choice
  materially affects public API/semver, security posture, irreversible
  infrastructure/cost, or product scope.
- **D-14:** When a decision does not cross that bar, prefer the option that
  strengthens least surprise, outside-in proof, and developer ergonomics rather
  than escalating it for user approval.

### the agent's Discretion
- Exact helper-script/template organization for the generated-app smoke lane.
- Exact CI job names, artifact handoff mechanics, and caching strategy.
- Exact README section ordering and wording, as long as the layered quickstart
  structure and required constraints remain explicit.
- Exact boundary between smoke assertions and deeper adopter/integration
  assertions, as long as the smoke path stays narrow and package-consumer-first.

</decisions>

<specifics>
## Specific Ideas

- The strongest trust signal is not just that `mix hex.build --unpack` looks
  correct, but that a freshly generated Phoenix app can consume the built
  artifact and succeed on the exact first-run path Rindle teaches.
- The docs should feel adopter-first, similar to how mature Elixir libraries
  treat installation as a product surface rather than an afterthought.
- Keep the beginner story short and executable. Push complexity rightward into
  the deeper guide and existing advanced proof lanes instead of front-loading
  it into README or smoke CI.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and locked requirements
- `.planning/ROADMAP.md` — Phase 9 goal, dependencies, and success criteria.
- `.planning/REQUIREMENTS.md` — `RELEASE-01`, `RELEASE-02`, and `RELEASE-03`.
- `.planning/PROJECT.md` — installability, adopter-owned Repo ownership,
  capability honesty, and current milestone intent.
- `.planning/STATE.md` — current default preference to let the agent decide
  unless ambiguity is truly high-impact.

### Prior decisions that constrain Phase 9
- `.planning/phases/05-ci-1-0-readiness/05-CONTEXT.md` — CI lane philosophy,
  adopter-lane drift gate, release-lane posture, and guide parity expectations.
- `.planning/phases/07-multipart-uploads/07-CONTEXT.md` — multipart is
  additive and advanced, with proof already living in deeper MinIO-backed
  suites.
- `.planning/phases/08-storage-capability-confidence/08-RESEARCH.md` and
  `.planning/phases/08-storage-capability-confidence/08-VERIFICATION.md` —
  capability honesty and current provider-proof posture that docs must not
  overstate.

### Existing code and docs surface
- `README.md` — current top-level entry point that Phase 9 must strengthen.
- `guides/getting_started.md` — current canonical lifecycle walkthrough.
- `guides/storage_capabilities.md` — capability constraints and provider-honest
  messaging that onboarding docs must link to rather than contradict.
- `mix.exs` — package file list and docs extras surface; packaging changes must
  respect what Hex actually ships.
- `.github/workflows/ci.yml` — existing quality/integration/contract/adopter
  lanes that Phase 9 extends with a package-consumer smoke gate.
- `.github/workflows/release.yml` — current tarball inspection and release gate
  posture.
- `test/adopter/canonical_app/lifecycle_test.exs` — existing deep adopter proof
  and current source of truth for the canonical lifecycle.
- `test/adopter/canonical_app/profile.ex` — current canonical profile shape
  mirrored by the getting-started guide.

### Ecosystem references informing the recommendation
- `https://hexdocs.pm/phoenix/Mix.Tasks.Phx.New.html` — canonical fresh Phoenix
  app shape via `mix phx.new`.
- `https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html` — built-package and unpack
  inspection workflow for Hex packages.
- `https://hexdocs.pm/ex_doc/readme.html` — `README.md` + extras layering model
  used by ExDoc/HexDocs.
- `https://hexdocs.pm/phoenix/file_uploads.html` — Phoenix’s default
  first-path-first teaching posture for uploads.
- `https://hexdocs.pm/phoenix_live_view/external-uploads.html` — advanced
  upload flows are layered after the basic path.
- `https://shrinerb.com/docs/getting-started` — a mature upload library’s
  progression from simple path to presigned direct upload.
- `https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpuoverview.html` —
  multipart complexity and cleanup footguns that should not be front-loaded
  into install smoke.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `test/adopter/canonical_app/lifecycle_test.exs`: already proves the canonical
  presigned and multipart flows against MinIO and can remain the deeper
  behavioral proof lane.
- `guides/getting_started.md`: already contains the detailed public lifecycle
  shape and Repo ownership guidance that Phase 9 can tighten rather than
  rewrite from scratch.
- `.github/workflows/release.yml`: already runs `mix hex.build --unpack` and
  tarball assertions, so Phase 9 can extend an existing packaging posture
  rather than invent one.
- `mix.exs`: package file list is intentionally narrow; install proof must
  validate only what ships in the package.

### Established Patterns
- The project already prefers executable docs parity checks over hand-wavy
  narrative promises.
- Existing advanced proofs live in dedicated suites instead of bloating one
  canonical lane.
- Capability honesty is a public contract: docs and install smoke must not
  imply that all advanced flows are equally first-run friendly.

### Integration Points
- New package-consumer smoke logic should connect CI packaging work to a fresh
  Phoenix consumer app, not only to the repository checkout.
- README quickstart and getting-started guide updates must align to the exact
  smoke-tested path.
- The release workflow and PR smoke workflow should share enough helper logic
  that the same package-consumer assumptions are exercised in both places.

</code_context>

<deferred>
## Deferred Ideas

- A full multipart package-consumer smoke lane remains out of scope for Phase 9
  unless the canonical first-run path itself changes to make multipart the
  primary onboarding flow.
- A separate external example repo remains unnecessary for this phase; the
  stronger outside-in signal is a generated fresh app consuming the built
  artifact inside CI.
- Broader changes to global GSD workflow defaults are outside this phase’s code
  scope, but the planning preference above should be treated as operative for
  Phase 9 work.

</deferred>

---

*Phase: 09-install-release-confidence*
*Context gathered: 2026-04-28*
