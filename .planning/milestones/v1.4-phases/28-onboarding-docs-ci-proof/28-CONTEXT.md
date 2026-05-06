# Phase 28: Onboarding, Docs, CI Proof - Context

**Gathered:** 2026-05-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 28 is the v1.4 ship gate. It closes the gap between "the AV stack exists"
and "a fresh adopter can install it, follow the docs, and watch CI prove the
same path on every commit."

In scope:
- FFmpeg install and runtime guidance for the documented target platforms
- The smallest copy-pasteable AV onboarding path in `README.md` and
  `guides/getting_started.md`
- CI enforcement for `mix rindle.doctor`, stock preset/example profiles, and a
  real smartphone-video round-trip
- Exact parity gates for the locked AV error vocabulary, telemetry naming
  conventions, and anti-pattern grep checks
- End-to-end proof that `Rindle.Profile.Presets.Web` is the canonical demo
  story, not just a helper module with unit tests

Out of scope:
- New AV product surface beyond what Phases 23-27 already defined
- New storage providers, streaming providers, or additional presets
- UI work, LiveView components, or new docs unrelated to onboarding/CI proof
- Re-architecting the quality/integration/contract workflow layout
</domain>

<decisions>
## Implementation Decisions

### Docs Surface
- **D-01:** `README.md` remains the narrow quickstart and
  `guides/getting_started.md` remains the canonical deep adopter guide. Phase 28
  extends those files; it does not introduce a competing onboarding doc tree.
- **D-02:** Per-platform FFmpeg install instructions must live in a durable docs
  surface that is easy to link from both `README.md` and
  `guides/getting_started.md`. A new `RUNNING.md` is acceptable, but only if it
  is clearly part of the public onboarding path and referenced from the
  existing guides.
- **D-03:** The onboarding story must teach the smallest AV path:
  `mix deps.get`, install FFmpeg, declare one `:kind => :video` variant, run
  `mix rindle.doctor`, then exercise the stock `web_720p` + `poster` flow.
- **D-04:** The docs must stay copy-pasteable and aligned to executable code
  snippets already enforced elsewhere in the repo. Phase 28 should extend the
  existing docs-parity approach rather than relying on prose-only promises.

### Ship Gate Posture
- **D-05:** Phase 28 is the last phase of v1.4 and should behave like a release
  proof phase, not a feature-expansion phase. Any code changes should tighten
  proof, parity, and onboarding clarity around already-shipped behavior.
- **D-06:** The phase depends on Phases 23-27 as locked upstream contracts. The
  plan must assume the AV foundations, processor, delivery, helper, LiveView,
  and cancellation work already define the public runtime surface.
- **D-07:** The stock `Rindle.Profile.Presets.Web` preset is the canonical demo
  profile and must be used in the onboarding path and CI proof rather than
  inventing a second demo profile.

### CI and Proof Strategy
- **D-08:** CI must fail fast on environment drift. `mix rindle.doctor` becomes
  a first-class gate for AV-capable lanes, not an optional local convenience.
- **D-09:** The CI proof must cover a real smartphone-style source video through
  upload -> probe -> transcode -> ready variant -> poster -> signed delivery
  URL. A unit-only or pure-fixture assertion does not satisfy the roadmap.
- **D-10:** Phase 28 should reuse the existing adopter lifecycle and contract
  test seams whenever possible instead of introducing one-off shell scripts.
- **D-11:** Anti-pattern enforcement belongs in CI as a grep or equivalent
  deterministic check over `lib/rindle/`, specifically blocking
  `System.shell/2`, `:os.cmd/1`, raw `Port.open/2` for FFmpeg/FFprobe, and
  string-interpolated argv patterns.
- **D-12:** The telemetry naming parity gate should verify documented triplet
  conventions against the public event allowlist already locked by contract
  tests, not create a second competing telemetry source of truth.

### Error and Parity Contracts
- **D-13:** The eight AV-facing error reasons are a frozen public vocabulary.
  Phase 28 must lock both exact reason atoms and exact public message text
  against the docs/runtime contract.
- **D-14:** Error-text parity should stay centralized on `Rindle.Error` and its
  tests. Phase 28 should add ship-gate assertions around that surface rather
  than split message ownership across docs and CI scripts.
- **D-15:** Platform install snippets must respect the current FFmpeg minimum
  version requirement (>= 6.0). Docs that silently teach older packages would
  violate the security/runtime contract established in earlier phases.

### Decision-Making Preference
- **D-16:** Preserve the standing project preference from `.planning/STATE.md`:
  keep the public API coherent and additive, favor proof over new surface area,
  and escalate only if a true semver-significant ambiguity appears.

### the agent's Discretion
- Exact file placement for platform-install docs (`RUNNING.md` vs guide section)
  so long as the public docs path is obvious and linked from the onboarding
  surfaces.
- Exact CI job split for doctor, lifecycle, parity, and grep enforcement so
  long as failures are isolated and actionable.
- Exact smartphone fixture composition and where it lives in `test/support` or
  fixture directories, provided it proves codec/container/rotation variation
  without widening the product surface.
</decisions>

<specifics>
## Specific Ideas

- Keep the docs centered on one concrete AV profile example:
  ```elixir
  defmodule MyApp.VideoProfile do
    use Rindle.Profile,
      storage: Rindle.Storage.S3,
      variants: [hero: [kind: :video, preset: :web_720p], poster: [kind: :image, preset: :video_poster_scene]],
      allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
      max_bytes: 250_000_000
  end
  ```
- Tie the onboarding guide to `mix rindle.doctor` immediately after dependency
  install so FFmpeg drift is caught before adopters hit background-job failures.
- Prefer extending the canonical adopter lifecycle test with the stock preset
  over creating a standalone bash proof harness.
- Make the CI anti-pattern gate narrow and explainable. It should catch banned
  process-launch surfaces without flagging legitimate `System.cmd/3` usage in
  tests or validated subprocess helpers.
</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Source of truth
- `.planning/ROADMAP.md` — Phase 28 goal, requirements, and success criteria
- `.planning/REQUIREMENTS.md` — AV-06-01 through AV-06-08
- `.planning/PROJECT.md` — milestone goal, security invariants, and FFmpeg
  version/runtime posture
- `.planning/STATE.md` — current workflow preference and phase sequencing

### Upstream phase decisions this phase must honor
- `.planning/phases/23-av-foundations/23-RESEARCH.md` — FFmpeg install/version
  posture and doctor/capability context
- `.planning/phases/24-domain-model-dsl-extension/24-CONTEXT.md` — typed AV
  domain model and profile DSL constraints
- `.planning/phases/25-rindle-processor-av/25-CONTEXT.md` — stock preset,
  processor contract, progress, and telemetry decisions
- `.planning/phases/26-delivery-surface/26-CONTEXT.md` — signed delivery and
  streaming-url posture
- `.planning/phases/27-html-helpers-liveview-integration/27-CONTEXT.md` —
  public AV helper, LiveView, cancellation, and frozen error vocabulary posture

### Research references
- `.planning/research/v1.4/SYNTHESIS.md` — locked v1.4 recommendation,
  especially the Phase 28 shape
- `.planning/research/v1.4/DELIVERY-DX.md` — onboarding, error vocabulary, and
  docs/operator expectations
- `.planning/research/v1.4/FOOTGUNS.md` — install/runtime hazards and AV
  adoption pitfalls to explicitly guard against

### Existing repo seams
- `README.md` — narrow quickstart surface to extend for AV onboarding
- `guides/getting_started.md` — canonical deep adopter guide already tied to
  lifecycle parity tests
- `.github/workflows/ci.yml` — existing quality/integration/contract/adopter
  workflow structure and current guide drift gate
- `lib/mix/tasks/rindle.doctor.ex` — current environment-check surface
- `lib/rindle/error.ex` and `test/rindle/error_test.exs` — frozen AV error text
  seam to extend or parity-lock
- `lib/rindle/profile/presets/web.ex` and `test/rindle/profile/presets_web_test.exs`
  — stock AV preset surface
- `test/adopter/canonical_app/profile.ex` and
  `test/adopter/canonical_app/lifecycle_test.exs` — canonical executable docs
  seam and end-to-end adopter proof
- `test/rindle/contracts/telemetry_contract_test.exs` — telemetry allowlist
  contract
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- The repo already ships `README.md`, `guides/getting_started.md`, and install
  smoke/docs parity tests, so Phase 28 should extend proven docs surfaces
  instead of inventing a second onboarding system.
- `mix rindle.doctor` already exists and currently checks FFmpeg availability;
  Phase 28 can promote it into CI without designing a new diagnostics command.
- The canonical adopter lifecycle test already proves a full upload/promote/
  process/delivery loop and is explicitly documented as the source of truth for
  the getting-started guide.
- The stock AV preset surface already exists as `Rindle.Profile.Presets.Web`,
  which means Phase 28 should focus on docs + proof adoption rather than preset
  invention.

### Current Gaps
- The current docs are still image-first and do not yet present the smallest AV
  onboarding path promised by Phase 28.
- CI currently installs `libvips` but does not yet make FFmpeg install/version
  checks or `mix rindle.doctor` a dedicated AV ship gate.
- There is no explicit Phase-28-level CI lane yet for the anti-pattern grep,
  locked error-message/docs parity, or the smartphone-video canonical demo.

### Integration Points
- Docs changes will likely center on `README.md`, `guides/getting_started.md`,
  and possibly a new `RUNNING.md` or equivalent install guide.
- CI changes will likely center on `.github/workflows/ci.yml` plus one or more
  focused test/support scripts under `scripts/` or `test/`.
- Proof updates will likely touch the canonical adopter fixture/profile tests,
  `test/rindle/error_test.exs`, `test/rindle/contracts/telemetry_contract_test.exs`,
  and new CI-facing parity/grep tests.
</code_context>

---
*Phase: 28-onboarding-docs-ci-proof*
*Context gathered: 2026-05-05*
