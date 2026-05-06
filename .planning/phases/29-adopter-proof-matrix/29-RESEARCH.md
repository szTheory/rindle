# Phase 29: Adopter Proof Matrix - Research

**Researched:** 2026-05-05
**Domain:** Outside-in package-consumer proof for published Rindle artifacts across image-only and AV-enabled adopter flows, with CI matrix coverage and executable docs parity.
**Confidence:** HIGH for repo seams and required plan split; MEDIUM for the exact CI lane split until implementation validates the slowest AV/public-smoke path.

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROOF-01 | Fresh package-consumer Phoenix app proves image-only install, upload, processing, and signed delivery from the published artifact. | Existing generated-app smoke already proves the narrow image-only path from either an unpacked artifact or a published Hex version via `RINDLE_INSTALL_SMOKE_NETWORK_VERSION`; extend and harden that seam instead of inventing a new harness. |
| PROOF-02 | Fresh package-consumer Phoenix app proves AV-enabled install, probe, transcode, local playback, and signed delivery from the published artifact. | The canonical adopter AV lane already proves the repo-local AV lifecycle; Phase 29 should port that truth into the generated-app package-consumer harness and published-version path. |
| PROOF-03 | CI proves the canonical adopter matrix across local storage and at least one real S3-compatible path. | Current CI separates `package-consumer` and `adopter` jobs. The clean extension is a proof matrix that keeps generated-app proof primary and reuses MinIO-backed S3-compatible execution for the real storage path. |
| PROOF-04 | README, getting-started, AV onboarding, and ops guidance stay in executable parity with the proved package-consumer flows. | Existing docs parity tests already lock README/getting-started/troubleshooting/RUNNING, and the release preflight already treats docs parity as a first-class release gate. Extend that system to the new image-only + AV package-consumer truth. |
</phase_requirements>

## Summary

Phase 29 is not a brand-new install system. The repo already has the core outside-in seam: `test/install_smoke/support/generated_app_helper.ex` generates a fresh Phoenix app, installs Rindle either from a local unpacked package or from a published Hex version, runs host plus Rindle migrations, boots the app, and proves the canonical image-only presigned-PUT lifecycle. The generated-app smoke tests and scripts `scripts/install_smoke.sh`, `scripts/release_preflight.sh`, and `scripts/public_smoke.sh` are therefore the correct Phase 29 spine.

The main gap is that the current generated-app path is still image-only. AV proof today lives in `test/adopter/canonical_app/lifecycle_test.exs` and `Rindle.Adopter.CanonicalApp.VideoProfile`, which prove the public AV story against MinIO and Postgres from the repo checkout, not from a fresh package-consumer app. Phase 29 should bridge those two truths: keep the generated-app harness as the primary package-consumer signal, and extend it with a second AV-aware generated-app profile plus realistic post-upload assertions for probe, transcode, poster/local playback, and signed delivery.

The other important gap is scope drift in CI. The current `package-consumer` job already runs release preflight and the built-artifact smoke path; `scripts/public_smoke.sh` already supports published-version smoke. The right direction is not "one giant job". Keep proof lanes explicit and narrow:
- one image-only generated-app proof from the built or published artifact
- one AV-enabled generated-app proof from the built or published artifact
- one matrix wiring step that proves at least one real S3-compatible path (already MinIO-backed in this repo) while preserving fast-fail docs/package gates

Docs parity should remain repo-native ExUnit, not workflow grep. `test/install_smoke/docs_parity_test.exs` and `test/install_smoke/release_docs_parity_test.exs` are the established pattern. Phase 29 should add parity assertions that the public docs describe the exact proved package-consumer flows, including the generated-app posture, image-only vs AV-enabled path split, and the operator guidance that belongs in `guides/operations.md`.

## Recommended Plan Split

| Plan | Scope | Why This Boundary |
|------|-------|-------------------|
| `29-01-PLAN.md` | Harden the existing generated-app package-consumer smoke into an explicit image-only public-proof lane for built and published artifacts. | It is the narrowest trust signal and already exists. Keep image proof stable before adding AV complexity. |
| `29-02-PLAN.md` | Extend the generated-app harness with an AV-enabled profile and public-smoke flow proving probe, transcode, local playback-ready outputs, and signed delivery from package-consumer installs. | This is the largest product-surface gap relative to Phase 28 and must stay isolated from CI wiring churn. |
| `29-03-PLAN.md` | Wire the proof matrix into CI and release-facing scripts across built-artifact and published-version paths, preserving at least one real S3-compatible path. | Workflow wiring should follow once image and AV harnesses are truthful, otherwise CI changes become guesswork. |
| `29-04-PLAN.md` | Lock README, getting-started, AV onboarding, and operations docs to the proved package-consumer matrix with executable parity tests. | Docs must describe the proof that actually shipped, so they should land after the proof surfaces are defined. |

## Existing Seams To Reuse

| Seam | Current Role | Phase 29 Use |
|------|--------------|--------------|
| `test/install_smoke/support/generated_app_helper.ex` | Fresh `mix phx.new` app, package install, migration handoff, boot check, image-only smoke proof. | Primary implementation seam for both built-artifact and published-version package-consumer proof. |
| `test/install_smoke/generated_app_smoke_test.exs` | Asserts generated app does not fall back to repo-local deps and proves the canonical image lifecycle. | Expand into profile/mode-specific smoke tests instead of replacing it with shell-only proof. |
| `scripts/install_smoke.sh` | Local built-artifact smoke entrypoint. | Keep as the image-only/baseline proof command or split into mode-aware variants that still reuse the same helper. |
| `scripts/public_smoke.sh` | Published Hex version smoke entrypoint via `RINDLE_INSTALL_SMOKE_NETWORK_VERSION`. | Reuse for published-artifact proof and extend to cover AV mode rather than creating a parallel public-smoke harness. |
| `.github/workflows/ci.yml` `package-consumer` job | Shift-left release preflight plus built-artifact package-consumer smoke. | Add the proof matrix here or in sibling explicit jobs while preserving current readable workflow topology. |
| `test/adopter/canonical_app/lifecycle_test.exs` | Repo-local source-of-truth AV lifecycle proof. | Mine concrete AV assertions and fixture expectations for the generated-app AV lane. |
| `test/install_smoke/docs_parity_test.exs` | Public docs parity for README/getting-started/troubleshooting/RUNNING. | Extend with package-consumer matrix assertions. |
| `guides/operations.md` | Thin operator-facing task index. | Add only the package-consumer-proof-relevant ops guidance; do not turn it into a second canonical install guide. |

## Current Gaps

1. The generated-app helper writes only an image-only `RindleProfile`; there is no generated-app AV profile or AV smoke test.
2. The package-consumer smoke tests assert installability and the image lifecycle, but nothing yet proves published-package AV processing from a fresh app.
3. `scripts/public_smoke.sh` only runs the existing generated-app smoke; it has no AV-aware branch or verification surface.
4. CI currently proves built-artifact package-consumer installability and repo-local adopter AV behavior, but not the combined matrix promised by PROOF-01 through PROOF-03.
5. Docs parity currently locks the facade-first lifecycle and AV onboarding, but not the new package-consumer matrix or operator guidance for proving those flows outside the repo.

## Recommended Implementation Notes

- Keep generated-app proof primary. The repo already decided in Phase 9 that the fresh-app smoke path is the trust signal and the long-lived fixture is supporting evidence.
- Do not collapse image-only and AV-enabled proof into one overloaded test by default. The package-consumer matrix should stay explicit so failures remain attributable.
- Use the existing network-mode switch in `GeneratedAppHelper` for published-version smoke. That is already the truthful path for “published artifact” proof.
- Preserve adopter-owned Repo, default Oban, and explicit migration wiring in every generated-app proof. Those are still part of the public contract.
- Reuse MinIO-backed S3-compatible execution as the real storage path for PROOF-03 unless the implementation proves a second path is necessary. The roadmap requires at least one real S3-compatible path, and MinIO already exists in CI.
- Prefer ExUnit parity tests over shell grep for docs. The install-smoke and release-doc parity files are the established contract style in this repo.

## Verification Commands The Plans Should Encode

- `mix test test/install_smoke/generated_app_smoke_test.exs --include minio`
- `bash scripts/install_smoke.sh`
- `bash scripts/public_smoke.sh "$VERSION"` or `RINDLE_INSTALL_SMOKE_NETWORK_VERSION="$VERSION" bash scripts/public_smoke.sh`
- `mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs`
- `mix test test/install_smoke/docs_parity_test.exs test/install_smoke/release_docs_parity_test.exs`

## Primary Recommendation

Plan Phase 29 as a package-consumer harness expansion, not as a docs-only or CI-only patch. The repo already has the right separation of concerns:
- generated-app helper for outside-in install proof
- canonical adopter lane for deeper AV truth
- release/package-consumer scripts for built vs published artifact entrypoints
- ExUnit docs parity for public-surface drift

The best plan sequence is therefore: stabilize image-only proof, extend AV proof into the generated-app path, wire the matrix into CI/public smoke, then lock the docs to exactly that matrix.

---
*Phase: 29-adopter-proof-matrix*
*Research completed: 2026-05-05*
