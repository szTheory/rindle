# Phase 28: Onboarding, Docs, CI Proof - Research

**Researched:** 2026-05-05  
**Domain:** Rindle v1.4 ship-gate proof across onboarding docs, Mix diagnostics, canonical adopter lifecycle, and GitHub Actions enforcement. [VERIFIED: repo reads listed in user request]  
**Confidence:** MEDIUM-HIGH. Repo seams and current gaps are clear, but a few exact platform-install snippets still need implementation-time verification against current provider docs. [VERIFIED: repo reads] [CITED: https://github.com/federicocarboni/setup-ffmpeg] [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs?apiVersion=2022-11-28]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### Deferred Ideas (OUT OF SCOPE)
None stated in `28-CONTEXT.md`. [VERIFIED: .planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AV-06-01 | Per-platform FFmpeg install docs. [VERIFIED: .planning/REQUIREMENTS.md] | Reuse `README.md` + `guides/getting_started.md` as entrypoints and add one linked install page/surface. [VERIFIED: README.md] [VERIFIED: guides/getting_started.md] |
| AV-06-02 | Smallest AV onboarding path. [VERIFIED: .planning/REQUIREMENTS.md] | Center docs on `Rindle.Profile.Presets.Web`, `mix deps.get`, FFmpeg install, and `mix rindle.doctor`. [VERIFIED: lib/rindle/profile/presets/web.ex] [VERIFIED: lib/mix/tasks/rindle.doctor.ex] |
| AV-06-03 | CI runs `mix rindle.doctor` against every example/fixture profile. [VERIFIED: .planning/REQUIREMENTS.md] | Extend current doctor task/tests and call it from an AV-capable CI lane. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] [VERIFIED: test/rindle/doctor_test.exs] [VERIFIED: .github/workflows/ci.yml] |
| AV-06-04 | Smartphone-source lifecycle round-trip in CI. [VERIFIED: .planning/REQUIREMENTS.md] | Extend the canonical adopter lane with a committed smartphone-style fixture and stronger ready/poster/signed-url assertions. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] |
| AV-06-05 | Locked AV error vocabulary parity gate. [VERIFIED: .planning/REQUIREMENTS.md] | Keep exact-message ownership in `Rindle.Error` and `test/rindle/error_test.exs`; add docs references against that source. [VERIFIED: lib/rindle/error.ex] [VERIFIED: test/rindle/error_test.exs] |
| AV-06-06 | `Rindle.Profile.Presets.Web` exercised end-to-end in CI. [VERIFIED: .planning/REQUIREMENTS.md] | Reuse `AdopterVideoProfile` and the existing stock-preset adopter test rather than inventing another demo profile. [VERIFIED: test/adopter/canonical_app/profile.ex] [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] |
| AV-06-07 | Telemetry names verified against documented conventions. [VERIFIED: .planning/REQUIREMENTS.md] | Extend the existing telemetry contract lane instead of adding a new telemetry checker. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] |
| AV-06-08 | Anti-pattern grep gate in CI. [VERIFIED: .planning/REQUIREMENTS.md] | Put the deterministic scan in the contract/quality layer, but scope it narrowly enough to avoid sanctioned validator code. [VERIFIED: lib/rindle/processor/av/video.ex] [VERIFIED: lib/rindle/processor/av/audio.ex] [VERIFIED: lib/rindle/processor/waveform.ex] |
</phase_requirements>

## Summary

Phase 28 should be planned as a **ship-gate tightening pass**, not a feature pass. The repo already contains most of the right seams: `README.md` and `guides/getting_started.md` are the established onboarding surfaces; `test/adopter/canonical_app/lifecycle_test.exs` is already declared as executable source-of-truth for the guide; `test/install_smoke/release_docs_parity_test.exs` proves the project prefers repo-native docs parity over ad-hoc shell checks; `test/rindle/error_test.exs` already freezes exact AV error text; and `test/rindle/contracts/telemetry_contract_test.exs` already freezes the telemetry allowlist. [VERIFIED: README.md] [VERIFIED: guides/getting_started.md] [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: test/rindle/error_test.exs] [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs]

The main Phase 28 work is therefore to **promote and align** those seams. Several repo-specific drifts would make a naive plan fail: `mix rindle.doctor` ignores profile arguments and only performs one global FFmpeg check; the AV-facing `ffmpeg_not_found` message still says `FFmpeg ≥ 4.0` while the v1.4 requirement and runtime probe require `>= 6.0`; the current adopter docs drift gate in `ci.yml` is still grepping for image-era API names; and the existing AV adopter proof uses a generated synthetic mp4, not a committed smartphone-style fixture with container/rotation variance and signed-URL assertions. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] [VERIFIED: lib/rindle/error.ex] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .github/workflows/ci.yml] [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs]

The cleanest split is four plans: docs surface, doctor/profile proof, canonical smartphone adopter proof, and CI/parity gates. That sequencing matches the repo’s established workflow: tighten docs first, make the diagnostic task truthful, extend the canonical adopter lane, then wire the final enforcement into GitHub Actions jobs whose dependencies remain readable and actionable. [VERIFIED: .planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md] [VERIFIED: .github/workflows/ci.yml] [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs?apiVersion=2022-11-28]

**Primary recommendation:** Use the existing adopter, contract, and install-smoke seams as the entire Phase 28 spine; do not add standalone bash proof harnesses or a second demo profile. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] [VERIFIED: test/install_smoke/release_docs_parity_test.exs] [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs]

## Project Constraints (from CLAUDE.md)

No project-root `CLAUDE.md` exists in `/Users/jon/projects/rindle`, so there are no additional repo-local directives beyond the planning artifacts already cited. [VERIFIED: repo root file check]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Public onboarding narrative (`README.md`, `guides/getting_started.md`, install page) | Frontend Server (SSR) | API / Backend | This phase teaches adopters the public API shape; it does not create runtime behavior by itself. [VERIFIED: README.md] [VERIFIED: guides/getting_started.md] |
| `mix rindle.doctor` environment gate | API / Backend | — | The Mix task verifies FFmpeg/runtime/profile compatibility before background workers run. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] |
| Canonical smartphone fixture lifecycle proof | API / Backend | Database / Storage | The proof exercises upload, probe, worker processing, variant persistence, and signed delivery against MinIO/Postgres. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] |
| Telemetry parity gate | API / Backend | Frontend Server (SSR) | Event naming is emitted by backend code but documented/consumed externally, so the contract test is the correct ownership tier. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] |
| Error-message parity gate | API / Backend | Frontend Server (SSR) | `Rindle.Error` is the single text seam for public bang/helper failures. [VERIFIED: lib/rindle/error.ex] [VERIFIED: test/rindle/error_test.exs] |
| Anti-pattern grep/scan gate | API / Backend | — | The dangerous subprocess surfaces live under `lib/rindle/`; enforcement belongs beside other backend contract gates. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: lib/rindle/processor/ffmpeg.ex] |

## Standard Stack

### Core

| Library / Module | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `Mix.Tasks.Rindle.Doctor` | repo-local | Ship-gate diagnostic entrypoint. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] | The task already exists, so Phase 28 should extend it instead of inventing a new probe command. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] |
| `Rindle.Profile.Presets.Web` | repo-local | Canonical AV onboarding profile. [VERIFIED: lib/rindle/profile/presets/web.ex] | The preset already encodes the intended `web_720p` + `poster` story and is covered by unit tests. [VERIFIED: test/rindle/profile/presets_web_test.exs] |
| Canonical adopter lane | repo-local | End-to-end executable docs proof. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] | The file is already declared as source-of-truth for `guides/getting_started.md`, so it is the correct place for Phase 28 proof expansion. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] |
| `Rindle.Error` + `test/rindle/error_test.exs` | repo-local | Frozen AV public vocabulary. [VERIFIED: lib/rindle/error.ex] [VERIFIED: test/rindle/error_test.exs] | Exact-string parity is already centralized here. [VERIFIED: test/rindle/error_test.exs] |
| `test/rindle/contracts/telemetry_contract_test.exs` | repo-local | Public telemetry allowlist and event-shape contract. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] | Phase 28 can extend the existing contract file instead of adding a second telemetry truth source. [VERIFIED: .planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md] |
| GitHub Actions `ci.yml` | `actions/checkout@v4`, `actions/cache@v4`, `erlef/setup-beam@v1`. [VERIFIED: .github/workflows/ci.yml] | Existing quality/integration/contract/adopter topology. [VERIFIED: .github/workflows/ci.yml] | The workflow already separates lanes by responsibility; Phase 28 should add one AV-proof/parity layer, not rewrite the topology. [VERIFIED: .github/workflows/ci.yml] [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs?apiVersion=2022-11-28] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `FedericoCarboni/setup-ffmpeg` | `@v3` action line in upstream README. [CITED: https://github.com/federicocarboni/setup-ffmpeg] | Install `ffmpeg` and `ffprobe` on GitHub Actions with a selectable version. [CITED: https://github.com/federicocarboni/setup-ffmpeg] | Prefer this for the GitHub Actions install snippet and, if adopted in CI, for pinning FFmpeg across runners. [CITED: https://github.com/federicocarboni/setup-ffmpeg] |
| Homebrew `ffmpeg` formula | stable `8.1.1`, with `ffmpeg@6` available. [CITED: https://formulae.brew.sh/formula/ffmpeg] | macOS install guidance. [CITED: https://formulae.brew.sh/formula/ffmpeg] | Use `brew install ffmpeg` in docs; note that `>= 6.0` is the runtime floor, not the docs target. [CITED: https://formulae.brew.sh/formula/ffmpeg] |
| Docker + MinIO + `mc` bootstrap already in CI | repo-local workflow shell steps. [VERIFIED: .github/workflows/ci.yml] | Reproduce S3-compatible adopter proof. [VERIFIED: .github/workflows/ci.yml] | Keep reusing this for adopter/AV proof jobs rather than moving to a mock-only lane. [VERIFIED: .github/workflows/ci.yml] |
| `test/install_smoke/release_docs_parity_test.exs` style | repo-local. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] | Repo-native text parity assertions. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] | Use this pattern for docs/install/error references before falling back to workflow `grep`. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Extending the canonical adopter lane | A new bash AV demo script | Reject; the repo already treats `test/adopter/canonical_app/lifecycle_test.exs` as executable docs source-of-truth. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] |
| Repo-native parity tests | More inline YAML `grep` blocks | Reject; existing package/release docs parity is already expressed as ExUnit, which is easier to diff, review, and run locally. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] |
| Dedicated telemetry parity in the current contract file | A second telemetry docs checker | Reject; `test/rindle/contracts/telemetry_contract_test.exs` already freezes the allowlist and event-shape contract. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] |
| Scope-limited anti-pattern scan | Naive grep for any joined `ffmpeg` string | Reject; repo code intentionally joins argv strings for `Argv.validate/1`, so a blunt string scan would false-positive valid guard code. [VERIFIED: lib/rindle/processor/ffmpeg.ex] [VERIFIED: lib/rindle/processor/av/video.ex] [VERIFIED: lib/rindle/processor/av/audio.ex] [VERIFIED: lib/rindle/processor/waveform.ex] |

**Dependencies:** No new Hex dependency is required for Phase 28. The likely changes are docs files, ExUnit files, the doctor task, and `ci.yml`. [VERIFIED: repo reads]

## Recommended Plan Split

| Plan | Scope | Where It Lives | Verification Commands |
|------|-------|----------------|-----------------------|
| `28-01-PLAN.md` | AV onboarding docs surface: `README.md`, `guides/getting_started.md`, and one linked install surface (`RUNNING.md` or equivalent). Replace image-first first-run story with the stock web preset path. [VERIFIED: README.md] [VERIFIED: guides/getting_started.md] | Docs + install-smoke parity tests. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] | `mix test test/install_smoke/release_docs_parity_test.exs` [VERIFIED: test/install_smoke/release_docs_parity_test.exs] |
| `28-02-PLAN.md` | Make `mix rindle.doctor` truthful for v1.4: accept profile args, check all fixture/example profiles, and align user-facing error text with `>= 6.0`. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] [VERIFIED: lib/rindle/error.ex] | `lib/mix/tasks/rindle.doctor.ex`, `test/rindle/doctor_test.exs`, `test/rindle/error_test.exs`. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] [VERIFIED: test/rindle/doctor_test.exs] [VERIFIED: test/rindle/error_test.exs] | `mix test test/rindle/doctor_test.exs test/rindle/error_test.exs` and `mix rindle.doctor Rindle.Adopter.CanonicalApp.VideoProfile`. [VERIFIED: test/rindle/doctor_test.exs] [VERIFIED: test/rindle/error_test.exs] |
| `28-03-PLAN.md` | Canonical smartphone-proof lane: committed fixture(s), stock preset end-to-end assertions, poster + signed URL + ready-state checks, and executable doc parity with `AdopterVideoProfile`. [VERIFIED: test/adopter/canonical_app/profile.ex] [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] | `test/adopter/canonical_app/*` plus new fixture directory under `test/support` or `test/fixtures`. [VERIFIED: test/support] [ASSUMED] | `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs`. [VERIFIED: .github/workflows/ci.yml] |
| `28-04-PLAN.md` | CI wiring and final ship gates: doctor lane, telemetry parity, error parity, anti-pattern scan, and replacement of stale shell-only drift checks with repo-native assertions. [VERIFIED: .github/workflows/ci.yml] | `.github/workflows/ci.yml`, contract/parity tests. [VERIFIED: .github/workflows/ci.yml] [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] | `mix test --only contract test/rindle/contracts/telemetry_contract_test.exs`; `mix test test/rindle/error_test.exs`; repo anti-pattern scan command from this research. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] [VERIFIED: test/rindle/error_test.exs] |

**Why this split:** Each plan closes a different truth boundary in dependency order: docs, diagnostics, adopter proof, then CI enforcement. That keeps failures isolated and keeps the final workflow diff small. [VERIFIED: .planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md] [VERIFIED: .github/workflows/ci.yml]

## Existing Docs / CI Seams To Reuse

| Seam | Current Role | Phase 28 Use |
|------|--------------|--------------|
| `README.md` | Narrow quickstart. [VERIFIED: README.md] | Keep it narrow; add one AV quickstart path and link to the deeper guide/install page. [VERIFIED: .planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md] |
| `guides/getting_started.md` | Canonical deep adopter guide. [VERIFIED: guides/getting_started.md] | Make this the copy-pasteable AV source-of-truth; keep it executable against the canonical adopter lane. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] |
| `test/adopter/canonical_app/profile.ex` | Canonical adopter profile fixtures, including `AdopterVideoProfile`. [VERIFIED: test/adopter/canonical_app/profile.ex] | Reuse `AdopterVideoProfile`; do not create a second docs-only AV profile. [VERIFIED: test/adopter/canonical_app/profile.ex] |
| `test/adopter/canonical_app/lifecycle_test.exs` | End-to-end adopter proof and source-of-truth note for docs. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] | Extend the existing stock web preset test into the smartphone-proof lane. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] |
| `test/install_smoke/release_docs_parity_test.exs` | Repo-native docs parity pattern. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] | Mirror its style for install/onboarding parity, rather than encoding assertions in YAML only. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] |
| `test/rindle/error_test.exs` | Exact-string AV message lock. [VERIFIED: test/rindle/error_test.exs] | Keep all message-parity assertions here. [VERIFIED: .planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md] |
| `test/rindle/contracts/telemetry_contract_test.exs` | Public telemetry allowlist and AV transcode triplet coverage. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] | Keep telemetry parity here and only add docs-traceability assertions if needed. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] |
| `.github/workflows/ci.yml` `quality` / `integration` / `contract` / `adopter` | Existing job topology. [VERIFIED: .github/workflows/ci.yml] | Add one AV-proof-focused downstream gate or upgrade the adopter/contract lanes; do not flatten the topology. [VERIFIED: .github/workflows/ci.yml] [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs?apiVersion=2022-11-28] |

## Where Each Phase-28 Proof Should Live

| Proof Item | Recommended Home | Reason |
|------------|------------------|--------|
| `mix rindle.doctor` behavior | `lib/mix/tasks/rindle.doctor.ex` plus `test/rindle/doctor_test.exs`. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] [VERIFIED: test/rindle/doctor_test.exs] | The task already exists there; Phase 28 should expand its surface rather than wrapping it in CI-only shell logic. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] |
| Smartphone fixture proof | `test/adopter/canonical_app/lifecycle_test.exs` with fixture files under `test/support/fixtures/av/` or `test/fixtures/av/`. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] [ASSUMED] | This is already the executable docs seam, and tests are excluded from the Hex package artifact. [VERIFIED: test/install_smoke/package_metadata_test.exs] |
| Telemetry parity | `test/rindle/contracts/telemetry_contract_test.exs`. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] | The file already freezes the allowlist and the `:start / :stop / :exception` AV triplet. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] |
| Error-message parity | `test/rindle/error_test.exs`. [VERIFIED: test/rindle/error_test.exs] | `Rindle.Error` owns the public wording; keeping parity here prevents text ownership from splitting across docs and workflow shell. [VERIFIED: lib/rindle/error.ex] [VERIFIED: test/rindle/error_test.exs] |
| Anti-pattern grep gate | New repo-native contract/parity test file under `test/rindle/contracts/` or a small checked-in script called from `contract`/`quality`; prefer the ExUnit file. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] [ASSUMED] | Repo-native tests are easier to review and can scope false positives better than long YAML `grep` blocks. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] |

## Architecture Patterns

### System Architecture Diagram

```text
README.md / getting_started.md / install page
                  |
                  v
      Copy-paste adopter quickstart snippet
                  |
                  v
          Rindle.Profile.Presets.Web
                  |
                  v
           mix rindle.doctor <Profile>
                  |
       +----------+----------+
       |                     |
       v                     v
  PASS / actionable      FAIL / fix guidance
  capability report      blocks CI + onboarding
       |
       v
Canonical adopter AV lane (MinIO + Postgres + Oban)
       |
       v
upload -> verify -> promote -> probe -> process variants
       |                                |
       |                                +--> poster ready
       |                                +--> web_720p ready
       v
 signed delivery url asserted
       |
       +--> telemetry contract lane
       +--> error parity lane
       +--> anti-pattern scan lane
       |
       v
 GitHub Actions ship gate for v1.4
```

### Recommended Project Structure

```text
guides/
├── getting_started.md      # canonical deep adopter path
└── RUNNING.md              # or equivalent linked install matrix page [ASSUMED]

lib/mix/tasks/
└── rindle.doctor.ex        # profile-aware AV diagnostics

test/
├── adopter/canonical_app/
│   ├── profile.ex          # source-of-truth adopter profiles
│   └── lifecycle_test.exs  # smartphone-source AV proof
├── rindle/
│   ├── error_test.exs      # exact AV error-message parity
│   ├── doctor_test.exs     # task behavior
│   └── contracts/
│       ├── telemetry_contract_test.exs
│       └── subprocess_contract_test.exs   # recommended new anti-pattern gate [ASSUMED]
└── support/fixtures/av/    # recommended committed smartphone fixtures [ASSUMED]
```

### Pattern 1: Executable Docs, Not Narrative Docs
**What:** Keep docs anchored to code that already runs in CI. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs]  
**When to use:** For onboarding snippets, profile examples, and first-run sequences. [VERIFIED: .planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md]  
**Example:**

```elixir
# Source: test/adopter/canonical_app/profile.ex
defmodule Rindle.Adopter.CanonicalApp.VideoProfile do
  use Rindle.Profile.Presets.Web,
    storage: Rindle.Storage.S3,
    allow_mime: ["video/mp4"],
    max_bytes: 524_288_000
end
```

### Pattern 2: One Truth Source Per Public Contract
**What:** Keep each public contract in the file that already owns it. [VERIFIED: lib/rindle/error.ex] [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs]  
**When to use:** For error wording, telemetry names, and doctor output. [VERIFIED: .planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md]  
**Example:**

```elixir
# Source: test/rindle/contracts/telemetry_contract_test.exs
@public_events [
  [:rindle, :media, :transcode, :start],
  [:rindle, :media, :transcode, :stop],
  [:rindle, :media, :transcode, :exception]
]
```

### Pattern 3: Downstream CI Gates With Readable `needs`
**What:** Put the final AV proof after the cheaper quality/contract prerequisites. [VERIFIED: .github/workflows/ci.yml]  
**When to use:** When adding the new doctor/AV-proof/parity job. [VERIFIED: .github/workflows/ci.yml]  
**Example:**

```yaml
# Source: GitHub Docs + current ci.yml shape
needs: [quality, integration, contract]
```

[VERIFIED: .github/workflows/ci.yml] [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs?apiVersion=2022-11-28]

### Anti-Patterns to Avoid

- **New standalone AV demo harness:** The repo already has the canonical adopter lane. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs]
- **Shell-only docs drift gates:** They have already drifted from the current public API names. [VERIFIED: .github/workflows/ci.yml] [VERIFIED: guides/getting_started.md]
- **Synthetic-only AV proof:** The current generated mp4 path proves the worker but not smartphone-source container/rotation hazards. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] [VERIFIED: .planning/REQUIREMENTS.md]
- **Blunt string grep for any `ffmpeg` join:** Current validator paths intentionally join argv strings for `Argv.validate/1`. [VERIFIED: lib/rindle/processor/ffmpeg.ex] [VERIFIED: lib/rindle/processor/av/video.ex]

## Don’t Hand-Roll

| Problem | Don’t Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Docs drift enforcement | Inline YAML grep for snippet fragments only | ExUnit parity tests like `test/install_smoke/release_docs_parity_test.exs`. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] | Easier to keep in sync, easier to run locally, and already standard in this repo. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] |
| AV end-to-end demo | New shell script that drives uploads manually | Extend `test/adopter/canonical_app/lifecycle_test.exs`. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] | Existing test already stands in for the guide and runs in CI. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] |
| Telemetry contract copy | Another allowlist in docs or workflow shell | `test/rindle/contracts/telemetry_contract_test.exs`. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] | Two allowlists will drift. [VERIFIED: .planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md] |
| AV install logic in GitHub Actions | Hand-maintained curl/unzip FFmpeg bootstrap | `FedericoCarboni/setup-ffmpeg@v3` when version pinning matters. [CITED: https://github.com/federicocarboni/setup-ffmpeg] | The action already installs both `ffmpeg` and `ffprobe`, supports selecting a version, and warns that default versions may differ by OS if unspecified. [CITED: https://github.com/federicocarboni/setup-ffmpeg] |

**Key insight:** Phase 28 succeeds by consolidating existing proof seams, not by widening the surface area again. [VERIFIED: .planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Assuming the Current Docs Drift Check Is Still Valid
**What goes wrong:** The workflow grep still looks for `Broker.initiate_session`, `Broker.verify_completion`, and `Rindle.Delivery.url`, while the public guide now teaches `Rindle.initiate_upload`, `Rindle.verify_completion`, and `Rindle.url`. [VERIFIED: .github/workflows/ci.yml] [VERIFIED: guides/getting_started.md]  
**Why it happens:** The repo migrated its public facade but left the shell drift check behind. [VERIFIED: README.md] [VERIFIED: guides/getting_started.md]  
**How to avoid:** Replace or supplement the grep with repo-native parity assertions that reference the actual public API snippets. [VERIFIED: test/install_smoke/release_docs_parity_test.exs]  
**Warning signs:** The guide passes review visually but CI fails on missing `Broker.*` or `Rindle.Delivery.url`. [VERIFIED: .github/workflows/ci.yml]

### Pitfall 2: Treating the Synthetic AV Fixture as “Good Enough”
**What goes wrong:** CI stays green on a generated testsrc mp4, but a real smartphone clip later fails on container/rotation assumptions. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] [VERIFIED: .planning/REQUIREMENTS.md]  
**Why it happens:** The current adopter AV test builds bytes with `ffmpeg` at runtime and never proves real-world source oddities. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs]  
**How to avoid:** Commit one or more small smartphone-style source files and assert poster, ready variants, and delivery URL on that path. [ASSUMED]  
**Warning signs:** The test only asserts ready states and never inspects rotation, original container, or signed delivery. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs]

### Pitfall 3: Leaving `mix rindle.doctor` as a Global FFmpeg Ping
**What goes wrong:** CI proves FFmpeg exists, but it does not prove that every shipped profile/example compiles and validates against the AV runtime contract. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] [VERIFIED: .planning/REQUIREMENTS.md]  
**Why it happens:** The current task ignores args and only calls `Rindle.AV.Probe.check_ffmpeg!/0`. [VERIFIED: lib/mix/tasks/rindle.doctor.ex]  
**How to avoid:** Make the task accept profile modules and call it over every fixture/example profile in CI. [VERIFIED: .planning/ROADMAP.md]  
**Warning signs:** `mix rindle.doctor Foo.Profile` behaves the same as `mix rindle.doctor` or the task output never mentions profiles/variants. [VERIFIED: lib/mix/tasks/rindle.doctor.ex]

### Pitfall 4: Shipping Docs and Errors With Conflicting FFmpeg Minimums
**What goes wrong:** Runtime requirements say `>= 6.0`, but user-facing error text still says `>= 4.0`, which makes onboarding guidance contradictory. [VERIFIED: lib/rindle/av/probe.ex] [VERIFIED: lib/rindle/error.ex] [VERIFIED: .planning/PROJECT.md]  
**Why it happens:** The minimum changed in AV foundations, but the message copy was not fully ratcheted. [VERIFIED: .planning/PROJECT.md] [VERIFIED: test/rindle/error_test.exs]  
**How to avoid:** Update `Rindle.Error` and its exact-string tests in the same plan as the doctor/docs changes. [VERIFIED: lib/rindle/error.ex] [VERIFIED: test/rindle/error_test.exs]  
**Warning signs:** Any docs or task output still contain `FFmpeg ≥ 4.0`. [VERIFIED: lib/rindle/error.ex] [VERIFIED: test/rindle/error_test.exs]

### Pitfall 5: Writing a Naive Anti-Pattern Grep
**What goes wrong:** CI blocks sanctioned argv validation code instead of only blocking dangerous exec surfaces. [VERIFIED: lib/rindle/processor/ffmpeg.ex] [VERIFIED: lib/rindle/processor/av/video.ex]  
**Why it happens:** The repo legitimately joins command strings before `Argv.validate/1`, so a simple `rg 'ffmpeg.*join'` is too broad. [VERIFIED: lib/rindle/processor/ffmpeg.ex]  
**How to avoid:** Ban only `System.shell/2`, `:os.cmd/1`, and unsafe `Port.open/2` / interpolated-shell execution patterns under `lib/rindle/`; allow validator-only string assembly. [VERIFIED: .planning/REQUIREMENTS.md] [ASSUMED]  
**Warning signs:** The first implementation of the grep flags `command_str = Enum.join(...)` in modules that do not execute the string. [VERIFIED: lib/rindle/processor/av/audio.ex] [VERIFIED: lib/rindle/processor/waveform.ex]

## Repo-Specific Risks That Would Break a Naive Plan

| Risk | Why It Matters | Recommended Handling |
|------|----------------|----------------------|
| Phase progress metadata lags reality | `ROADMAP.md` and `STATE.md` still show earlier phase sequencing/status that does not cleanly match the code already present for AV helper/tests. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/STATE.md] | Plan against the current code tree, not only the progress table. [VERIFIED: repo reads] |
| Current AV adopter test stops at ready-state parity | It does not assert signed URL output or smartphone-specific source behavior. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] | Extend the existing test rather than assuming AV-06-04 is already satisfied. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] |
| No existing binary fixture directory | Adding committed video assets needs a deliberate location and naming convention. [VERIFIED: `find test ... fixture` result] | Create a dedicated test fixture directory under `test/`; package metadata tests show the whole `test/` tree is excluded from Hex artifacts. [VERIFIED: test/install_smoke/package_metadata_test.exs] |
| GitHub Actions currently installs `libvips` but not FFmpeg | AV proof would rely on runner ambient state or fail unpredictably. [VERIFIED: .github/workflows/ci.yml] | Add explicit FFmpeg setup in AV-capable jobs or a shared AV bootstrap step. [VERIFIED: .planning/REQUIREMENTS.md] [CITED: https://github.com/federicocarboni/setup-ffmpeg] |
| Local MinIO client `mc` is absent | Local reproduction of the CI adopter lane differs slightly from CI bootstrap. [VERIFIED: local command checks] | Keep CI installing `mc`; document Docker-only local fallback if needed. [VERIFIED: .github/workflows/ci.yml] |

## Code Examples

Verified repo-native patterns:

### Canonical Preset Profile
```elixir
# Source: test/adopter/canonical_app/profile.ex
defmodule Rindle.Adopter.CanonicalApp.VideoProfile do
  use Rindle.Profile.Presets.Web,
    storage: Rindle.Storage.S3,
    allow_mime: ["video/mp4"],
    max_bytes: 524_288_000
end
```

### Current AV Adopter Proof Seam
```elixir
# Source: test/adopter/canonical_app/lifecycle_test.exs
test "stock web preset round-trips a canonical video upload end to end" do
  {:ok, session} = Broker.initiate_session(AdopterVideoProfile, filename: "adopter.mp4")
  {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
  :ok = put_to_presigned_url(presigned.url, video_bytes)
  {:ok, %{session: completed, asset: asset}} = Broker.verify_completion(session.id)
  assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})
end
```

### Existing Telemetry Triplet Lock
```elixir
# Source: test/rindle/contracts/telemetry_contract_test.exs
@public_events [
  [:rindle, :media, :transcode, :start],
  [:rindle, :media, :transcode, :stop],
  [:rindle, :media, :transcode, :exception]
]
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Image-first quickstart only in `README.md` / `getting_started.md`. [VERIFIED: current docs content] | AV onboarding centered on `Rindle.Profile.Presets.Web` and `mix rindle.doctor`. [VERIFIED: .planning/REQUIREMENTS.md] | v1.4 requirement set on 2026-05-02. [VERIFIED: .planning/REQUIREMENTS.md] | Docs must now prove FFmpeg/runtime posture, not only image upload posture. [VERIFIED: .planning/PROJECT.md] |
| Shell `grep` as the main docs drift mechanism in CI. [VERIFIED: .github/workflows/ci.yml] | Repo-native ExUnit parity tests already exist for release docs and should be extended to onboarding docs. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] | Shipped by earlier release-proof work. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] | Phase 28 should follow the repo pattern instead of expanding shell checks. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] |
| Generated synthetic AV fixture bytes. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] | Committed smartphone-style fixture(s) for CI proof. [ASSUMED] | Needed for AV-06-04. [VERIFIED: .planning/REQUIREMENTS.md] | Improves proof realism without changing runtime surface. [VERIFIED: .planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md] |

**Deprecated/outdated:**
- `FFmpeg ≥ 4.0` user-facing copy is outdated for v1.4. [VERIFIED: lib/rindle/error.ex] [VERIFIED: .planning/PROJECT.md]
- The current `Broker.*`/`Rindle.Delivery.url` docs drift grep is outdated relative to the public guide. [VERIFIED: .github/workflows/ci.yml] [VERIFIED: guides/getting_started.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The best home for committed smartphone assets is `test/support/fixtures/av/` or a nearby `test/fixtures/av/` directory. [ASSUMED] | Recommended Project Structure / smartphone proof | Low; only affects file organization, not the proof concept. |
| A2 | A repo-native ExUnit subprocess contract test is preferable to a pure-YAML grep block for AV-06-08. [ASSUMED] | Where Each Proof Should Live / Don’t Hand-Roll | Medium; if maintainers insist on shell-only enforcement, plan 28-04 shape changes. |
| A3 | Exact Heroku/Fly.io/Render install snippets still need implementation-time validation against current platform docs. [ASSUMED] | Summary / Open Questions | Medium; wrong snippets would degrade onboarding trust. |
| A4 | A committed smartphone-style fixture can be kept small enough for repo hygiene while still proving container/rotation variation. [ASSUMED] | Common Pitfalls / Recommended Plan Split | Medium; if not, the plan must switch to a generated-but-realistic fixture workflow. |

## Resolved Decisions

1. **Platform install matrix location**
   - Decision: create a dedicated public `RUNNING.md` and link it from the AV
     onboarding sections in both `README.md` and `guides/getting_started.md`.
   - Why: the platform matrix is substantial enough to crowd the canonical
     guide, while `28-CONTEXT.md` explicitly allows `RUNNING.md` if it remains
     part of the public onboarding path. [VERIFIED: .planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md]

2. **GitHub Actions FFmpeg install method**
   - Decision: use `FedericoCarboni/setup-ffmpeg@v3` in the GitHub Actions docs
     snippet and in the AV-capable CI lanes where version pinning matters.
   - Why: AV-06-01 names that action explicitly for GitHub Actions docs, and it
     provides a repo-visible way to pin both `ffmpeg` and `ffprobe`. [VERIFIED: .planning/REQUIREMENTS.md] [CITED: https://github.com/federicocarboni/setup-ffmpeg]

3. **Smartphone fixture count and shape**
   - Decision: require a two-fixture matrix in the canonical adopter lane: one
     portrait `mov` source with rotation metadata and one second source from a
     different container/codec family so AV-06-04 explicitly proves container,
     codec, and rotation variance.
   - Why: a single synthetic clip could miss the exact variability the roadmap
     calls out; two small committed fixtures keep the proof narrow but
     specific. [VERIFIED: .planning/REQUIREMENTS.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir / Mix | All plan verification commands. [VERIFIED: local command] | ✓ [VERIFIED: local command] | `Mix 1.19.5` / OTP 28 locally. [VERIFIED: local command] | — |
| FFmpeg | Doctor task, adopter AV proof, worker tests. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] | ✓ [VERIFIED: local command] | `ffmpeg 8.0.1`. [VERIFIED: local command] | In CI, install explicitly; do not rely on ambient runner state. [VERIFIED: .planning/REQUIREMENTS.md] |
| FFprobe | Probe and AV proof. [VERIFIED: lib/rindle/probe/av_probe.ex] | ✓ [VERIFIED: local command] | `ffprobe 8.0.1`. [VERIFIED: local command] | Same as FFmpeg. [VERIFIED: .planning/REQUIREMENTS.md] |
| Docker | MinIO-backed adopter proof and local reproduction. [VERIFIED: .github/workflows/ci.yml] | ✓ [VERIFIED: local command] | `29.4.1`. [VERIFIED: local command] | CI already bootstraps MinIO with Docker; local proof without Docker is incomplete. [VERIFIED: .github/workflows/ci.yml] |
| `curl` | CI service readiness and package/release smoke patterns. [VERIFIED: .github/workflows/ci.yml] | ✓ [VERIFIED: local command] | `8.7.1`. [VERIFIED: local command] | — |
| MinIO client `mc` | CI bucket bootstrap in adopter/integration lanes. [VERIFIED: .github/workflows/ci.yml] | ✗ locally. [VERIFIED: local command] | — | CI already installs it; local users can rely on CI or install manually. [VERIFIED: .github/workflows/ci.yml] |
| GitHub Actions | Final ship gate execution. [VERIFIED: .github/workflows/ci.yml] | CI-only [VERIFIED: .github/workflows/ci.yml] | `checkout@v4`, `cache@v4`, `setup-beam@v1` in repo. [VERIFIED: .github/workflows/ci.yml] | Local approximation via Mix + Docker, but not authoritative. [VERIFIED: test/install_smoke/package_metadata_test.exs] |

**Missing dependencies with no fallback:** None for research; `mc` is missing locally but CI already installs it. [VERIFIED: local command] [VERIFIED: .github/workflows/ci.yml]  
**Missing dependencies with fallback:** Local `mc` is absent; rely on CI bootstrap or install manually when reproducing adopter jobs outside CI. [VERIFIED: local command] [VERIFIED: .github/workflows/ci.yml]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + repo-native workflow shell checks. [VERIFIED: test suite layout] |
| Config file | `test/test_helper.exs`. [VERIFIED: repo tree] |
| Quick run command | `mix test test/rindle/error_test.exs test/rindle/doctor_test.exs test/rindle/contracts/telemetry_contract_test.exs`. [VERIFIED: file presence] |
| Full suite command | `mix test`. [VERIFIED: repo conventions] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AV-06-01 | Platform install docs exist and stay linked from onboarding surfaces. [VERIFIED: .planning/REQUIREMENTS.md] | docs parity | `mix test test/install_smoke/release_docs_parity_test.exs` plus a new onboarding parity file. [VERIFIED: test/install_smoke/release_docs_parity_test.exs] | Partial |
| AV-06-02 | Smallest AV onboarding path is copy-pasteable. [VERIFIED: .planning/REQUIREMENTS.md] | docs parity + compile smoke | `mix test test/install_smoke/release_docs_parity_test.exs` and `mix rindle.doctor Rindle.Adopter.CanonicalApp.VideoProfile`. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] | Partial |
| AV-06-03 | Doctor runs against every example/fixture profile. [VERIFIED: .planning/REQUIREMENTS.md] | task / CI gate | `mix rindle.doctor Rindle.Adopter.CanonicalApp.Profile Rindle.Adopter.CanonicalApp.VideoProfile` or equivalent task surface. [ASSUMED] | Gap |
| AV-06-04 | Smartphone-source full lifecycle round-trip. [VERIFIED: .planning/REQUIREMENTS.md] | adopter integration | `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs`. [VERIFIED: .github/workflows/ci.yml] | Partial |
| AV-06-05 | Exact AV error reason/message parity. [VERIFIED: .planning/REQUIREMENTS.md] | unit parity | `mix test test/rindle/error_test.exs`. [VERIFIED: test/rindle/error_test.exs] | Exists |
| AV-06-06 | Stock web preset exercised end-to-end. [VERIFIED: .planning/REQUIREMENTS.md] | adopter integration | `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs`. [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs] | Partial |
| AV-06-07 | Telemetry names keep public contract and triplet conventions. [VERIFIED: .planning/REQUIREMENTS.md] | contract | `mix test --only contract test/rindle/contracts/telemetry_contract_test.exs`. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] | Exists |
| AV-06-08 | Dangerous subprocess surfaces are blocked. [VERIFIED: .planning/REQUIREMENTS.md] | contract / scan | `rg -n 'System\\.shell|:os\\.cmd|Port\\.open' lib/rindle lib/mix/tasks` plus a repo-native contract test. [VERIFIED: .planning/REQUIREMENTS.md] [ASSUMED] | Gap |

### Sampling Rate

- **Per task commit:** `mix test test/rindle/error_test.exs test/rindle/doctor_test.exs`
- **Per wave merge:** `mix test --only contract test/rindle/contracts/telemetry_contract_test.exs` and `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs`
- **Phase gate:** Full `ci.yml` green with the new AV-proof/parity lane. [VERIFIED: .github/workflows/ci.yml]

### Wave 0 Gaps

- [ ] New docs parity file for AV onboarding/install snippets. [VERIFIED: test/install_smoke/release_docs_parity_test.exs]
- [ ] Doctor task/profile-argument coverage beyond the current FFmpeg-only smoke. [VERIFIED: lib/mix/tasks/rindle.doctor.ex]
- [ ] Smartphone fixture asset(s) committed under `test/`. [ASSUMED]
- [ ] Repo-native anti-pattern contract test or checked-in script. [ASSUMED]
- [ ] CI replacement for the stale `Broker.*`/`Rindle.Delivery.url` shell grep. [VERIFIED: .github/workflows/ci.yml]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | This phase does not add auth features. [VERIFIED: phase scope in 28-CONTEXT.md] |
| V3 Session Management | no | This phase does not change user/session state. [VERIFIED: phase scope in 28-CONTEXT.md] |
| V4 Access Control | yes | Signed delivery and actor-tagged range telemetry remain public contracts that docs/tests must not misstate. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs] [VERIFIED: lib/rindle/delivery.ex] |
| V5 Input Validation | yes | Doctor/profile validation, exact error messages, and anti-pattern enforcement all protect the subprocess/input boundary. [VERIFIED: lib/mix/tasks/rindle.doctor.ex] [VERIFIED: lib/rindle/processor/ffmpeg.ex] |
| V6 Cryptography | yes | Signed URL behavior already exists and should remain the documented delivery contract. [VERIFIED: README.md] [VERIFIED: guides/secure_delivery.md] |

### Known Threat Patterns for This Phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Reintroducing shell-based subprocess execution | Tampering / Elevation | Anti-pattern contract gate over `lib/rindle/` plus existing `Argv.validate/1`/wrapper seams. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: lib/rindle/processor/ffmpeg.ex] |
| Teaching stale FFmpeg minimums in docs/errors | Tampering | Exact-string parity in `test/rindle/error_test.exs` and linked install docs. [VERIFIED: lib/rindle/error.ex] [VERIFIED: test/rindle/error_test.exs] |
| Shipping a docs path that bypasses runtime verification | Repudiation / Misconfiguration | `mix rindle.doctor` immediately after install in docs and CI. [VERIFIED: .planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md] |
| False-confidence CI proof from synthetic-only clips | Repudiation | Commit smartphone-style fixtures and run them in the adopter lane. [VERIFIED: .planning/REQUIREMENTS.md] [ASSUMED] |

## Sources

### Primary (HIGH confidence)
- `README.md` - current quickstart posture and image-first onboarding gap. [VERIFIED: README.md]
- `guides/getting_started.md` - canonical deep adopter guide and current public API snippet. [VERIFIED: guides/getting_started.md]
- `.github/workflows/ci.yml` - current job topology, adopter drift grep, and missing FFmpeg bootstrap. [VERIFIED: .github/workflows/ci.yml]
- `lib/mix/tasks/rindle.doctor.ex` - current doctor behavior. [VERIFIED: lib/mix/tasks/rindle.doctor.ex]
- `lib/rindle/error.ex` and `test/rindle/error_test.exs` - frozen AV error wording and current `>= 4.0` drift. [VERIFIED: lib/rindle/error.ex] [VERIFIED: test/rindle/error_test.exs]
- `lib/rindle/profile/presets/web.ex` and `test/rindle/profile/presets_web_test.exs` - stock AV preset onboarding seam. [VERIFIED: lib/rindle/profile/presets/web.ex] [VERIFIED: test/rindle/profile/presets_web_test.exs]
- `test/adopter/canonical_app/profile.ex` and `test/adopter/canonical_app/lifecycle_test.exs` - canonical executable docs seam and current AV proof shape. [VERIFIED: test/adopter/canonical_app/profile.ex] [VERIFIED: test/adopter/canonical_app/lifecycle_test.exs]
- `test/rindle/contracts/telemetry_contract_test.exs` - telemetry parity seam. [VERIFIED: test/rindle/contracts/telemetry_contract_test.exs]
- `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `.planning/STATE.md`, `.planning/phases/28-onboarding-docs-ci-proof/28-CONTEXT.md` - locked phase contract and milestone posture. [VERIFIED: planning files]

### Secondary (MEDIUM confidence)
- GitHub Docs: `jobs.<job_id>.needs` behavior and downstream job dependency semantics. [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs?apiVersion=2022-11-28]
- `federicocarboni/setup-ffmpeg` README for version pinning and `ffprobe` availability in GitHub Actions. [CITED: https://github.com/federicocarboni/setup-ffmpeg]
- Homebrew Formula page for current macOS install command and available ffmpeg versions. [CITED: https://formulae.brew.sh/formula/ffmpeg]

### Tertiary (LOW confidence)
- Exact current Heroku/Fly.io/Render install snippet details remain unverified in this session and should be checked during implementation. [ASSUMED]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - almost entirely repo-native and already present in tree. [VERIFIED: repo reads]
- Architecture: HIGH - current docs/tests/workflow seams make the ownership boundaries clear. [VERIFIED: repo reads]
- Pitfalls: MEDIUM-HIGH - most are directly observed in repo; platform-install exactness still needs implementation-time verification. [VERIFIED: repo reads] [ASSUMED]

**Research date:** 2026-05-05  
**Valid until:** 2026-06-04 for repo structure; re-verify platform install snippets and third-party action details before implementation if Phase 28 slips. [ASSUMED]
