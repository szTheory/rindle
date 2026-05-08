# Phase 41: Onboarding + Docs + Doctor + Package-Consumer Proof - Research

**Researched:** 2026-05-07
**Domain:** GCS resumable onboarding docs, profile-aware doctor warnings, generated-app package-consumer proof, and CI lane integration
**Confidence:** HIGH

## Summary

Phase 41 should stay a DX/integration phase, not a runtime-semantics phase. The repo already has the needed runtime primitives from Phases 37-40 plus strong analogs for each deliverable: provider-specific deep docs in `guides/`, profile-aware `mix rindle.doctor` checks in `lib/rindle/ops/runtime_checks.ex`, generated-app install-smoke lanes in `test/install_smoke/*`, and secret-gated real-provider soak jobs in `.github/workflows/ci.yml`. The plan should reuse those seams instead of introducing new command surfaces, new runtime abstractions, or a second onboarding path.

The biggest technical wrinkle is `mix rindle.doctor` warning support. The current report model is binary (`:ok | :error`), the Mix task prints only `[OK]` and `[ERROR]`, and failure is computed purely from `status == :error`. Phase 41's locked CORS-suspected check therefore needs an additive warning posture end-to-end: `RuntimeChecks` result type, Mix task rendering, and tests. That is the only real contract expansion in this phase; the rest is documentation and CI/harness composition.

The recommended planning split is one plan per requirement family:

1. `RESUMABLE-12`: deep GCS guide + capability-matrix honesty + short README/getting-started pointers
2. `RESUMABLE-13`: doctor warning support + resumable-aware GCS checks + operator-facing output/tests
3. `RESUMABLE-14`: generated-app GCS profile/lifecycle proof + CI lane wiring + doc parity updates

## File Touch Points

### Docs and capability messaging

- `guides/storage_gcs.md`
- `guides/storage_capabilities.md`
- `README.md`
- `guides/getting_started.md`
- `guides/troubleshooting.md`
- `test/install_smoke/docs_parity_test.exs`
- `test/install_smoke/release_docs_parity_test.exs`

### Doctor / runtime checks

- `lib/rindle/ops/runtime_checks.ex`
- `lib/mix/tasks/rindle.doctor.ex`
- `test/rindle/ops/runtime_checks_test.exs`
- `test/rindle/ops/runtime_checks_streaming_test.exs`
- `test/rindle/doctor_test.exs`
- `test/rindle/contracts/telemetry_contract_test.exs`

### Generated-app / install-smoke / CI

- `scripts/install_smoke.sh`
- `test/install_smoke/support/generated_app_helper.ex`
- `test/install_smoke/generated_app_smoke_test.exs`
- `.github/workflows/ci.yml`
- likely a new or extended generated-app lifecycle fixture under `test/install_smoke/`
- likely shell cleanup/support script(s) if the live GCS lane needs explicit always-run cleanup

## Repo Facts The Planner Should Preserve

- `guides/storage_gcs.md` is currently only an interim log-hygiene note. Phase 41 should expand that file in place, not replace it with a second GCS guide.
- `guides/storage_capabilities.md` still describes `:resumable_upload` and `:resumable_upload_session` as reserved, so the phase must update both the vocabulary section and provider matrix.
- `RuntimeChecks.run/2` already suppresses irrelevant GCS rows by appending GCS checks only when `gcs_profiles(profiles) != []`. The resumable CORS check should reuse this zero-noise posture and further gate on profiles that advertise `:resumable_upload_session`.
- Existing GCS checks are deterministic failures: `doctor.gcs_goth_running`, `doctor.gcs_bucket_reachable`, `doctor.gcs_signing_key`. The new CORS-suspected finding must be advisory and non-failing.
- `scripts/install_smoke.sh` currently accepts only `all|image|video|mux`. Phase 41 needs a fourth real profile mode rather than overloading an existing one.
- `GeneratedAppHelper.profile_enabled?/1` and `prove_package_install!/1` currently accept only `:image | :video | :mux`; the smoke assertions currently accept `[:image, :video, :upgrade, :mux]`.
- CI already demonstrates the intended split:
  - `package-consumer` is always-on and service-backed
  - `mux-soak` is a sibling secret/label-gated top-level soak lane
  - `gcs-soak` is already a secret-gated real-bucket lane for direct repo tests
- The new generated-app live GCS proof should mirror `mux-soak`/`gcs-soak` topology rather than nesting cloud work into the default package-consumer steps.

## Risks and Planning Implications

### 1. Doctor warning support is a contract change

Current types and rendering assume only `:ok` and `:error`. If the plan adds a warning-only check without widening that contract, the output will be ambiguous and tests will likely drift. The plan should treat warning support as part of the same slice as the new GCS resumable check, not as incidental cleanup.

Recommended invariant:

- warnings render distinctly, e.g. `[WARN]`
- warnings do not increment `failed`
- warnings do not make `report.success?` false
- unknown flags and existing error behavior remain unchanged

### 2. CORS cannot be proven server-side

The new check should be an advisory heuristic based on bucket CORS metadata/config shape, not a hard pass/fail promise that browser uploads will work. The plan must keep the finding text operator-first and copy-pasteable while preserving the locked exit-code policy.

### 3. Generated-app GCS proof will need live-secret hygiene

The live lane must avoid leaking `session_uri`, signed URLs, or raw service-account material in logs. The phase should prefer unique per-run object prefixes plus explicit cleanup over broad bucket sweeps.

### 4. Docs parity tests will tighten scope

The repo already has install-smoke docs parity tests that enforce canonical onboarding wording. Any README/getting-started additions must stay short and pointer-oriented or those tests will need intentional updates aligned to the locked "advanced optional path" posture.

## Validation Architecture

Plan verification should stay at three levels:

### Structural docs verification

- grep/file assertions for required headings and strings in `guides/storage_gcs.md`, `guides/storage_capabilities.md`, `README.md`, and `guides/getting_started.md`
- docs parity tests remain green
- `mix docs` or release-doc parity assertions confirm the guide is reachable from published docs

### Unit / command verification

- `mix test test/rindle/ops/runtime_checks_test.exs test/rindle/ops/runtime_checks_streaming_test.exs test/rindle/doctor_test.exs`
- direct assertions that warnings are non-failing and errors still fail
- direct assertions that non-GCS adopters still see zero new GCS rows

### Live proof verification

- always-on generated-app structural proof for the new `:gcs` profile
- secret-gated real-bucket generated-app lifecycle proof against GCS
- CI wiring proves the lane skips cleanly when secrets are absent

## Recommended Plan Boundaries

### Plan 01 - Docs and capability honesty (`RESUMABLE-12`)

Own the deep guide, capability-matrix update, and short README/getting-started pointers. Keep this plan doc-heavy and test with docs parity plus grep-verifiable acceptance criteria.

### Plan 02 - Doctor warning surface (`RESUMABLE-13`)

Own the warning-capable report model, new resumable-specific GCS check, Mix task output, and focused runtime-check tests. This plan should not touch install-smoke or CI.

### Plan 03 - Generated-app GCS proof (`RESUMABLE-14`)

Own the `:gcs` generated-app profile, lifecycle proof, `scripts/install_smoke.sh` dispatch, and CI lane changes. This plan can also absorb the final doc-parity updates that mention the new optional path if those changes are needed to keep package-consumer/release-doc proofs coherent.

## Open Questions Resolved By Existing Context

- Separate `mix rindle.gcs_doctor` task? No. Rejected by locked decision D-16.
- Always-on real-bucket package-consumer lane? No. Rejected by D-26..D-29.
- Make GCS resumable the default onboarding story? No. README/getting-started remain narrow per D-02..D-04 and D-14.
- Add new runtime resumable APIs? No. Phase boundary explicitly forbids it.

## Planning Advice

- Keep the doc plan separate from the doctor contract change. The warning model is small but semantically important and deserves its own verification story.
- Be explicit in plan tasks about the exact strings the docs must contain: `PATCH`, `PUT`, `Content-Range`, `x-goog-resumable`, `session URI is a bearer credential`, `one week`, `cloak_ecto`, and the logger translator recipe.
- Make the generated-app live lane mirror existing package-consumer conventions rather than inventing bespoke tooling. The executor should extend `GeneratedAppHelper` and `scripts/install_smoke.sh`, not replace them.
- Preserve zero-noise doctor behavior as a must-have. This is a locked UX constraint, not an implementation preference.
