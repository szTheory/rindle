# Phase 28: Onboarding, Docs, CI Proof - Pattern Map

**Mapped:** 2026-05-05
**Files analyzed:** 10
**Analogs found:** 9 / 10

## File Classification

| New/Modified File | Role | Closest Analog | Match quality |
|---|---|---|---|
| `README.md` | public quickstart doc | self + `guides/getting_started.md` | exact |
| `guides/getting_started.md` | canonical adopter guide | self + `test/adopter/canonical_app/lifecycle_test.exs` | exact |
| `RUNNING.md` (if added) | runtime/install doc | `guides/getting_started.md` + `guides/release_publish.md`-style cross-link posture | partial |
| `.github/workflows/ci.yml` | CI workflow / ship gate | self | exact |
| `test/install_smoke/docs_parity_test.exs` | exact-text docs parity test | self | exact |
| `test/rindle/contracts/telemetry_contract_test.exs` | public contract test | self | exact |
| `test/rindle/error_test.exs` | exact-text public error contract | self | exact |
| `test/rindle/doctor_test.exs` | runtime gate smoke test | self | exact |
| `test/adopter/canonical_app/lifecycle_test.exs` | canonical adopter lifecycle proof | self + `test/adopter/canonical_app/profile.ex` | exact |
| anti-pattern grep gate (workflow step or script) | deterministic CI enforcement | `scripts/assert_release_docs_html.sh` + inline grep gate in `.github/workflows/ci.yml` | role-match |

## Pattern Assignments

### `README.md` + `guides/getting_started.md`

**Analogs:** [README.md](/Users/jon/projects/rindle/README.md:13), [guides/getting_started.md](/Users/jon/projects/rindle/guides/getting_started.md:11)

Mirror these patterns:

- keep `README.md` narrow and make `guides/getting_started.md` the canonical deep path
- state the same lifecycle story in both places, then assert parity in tests instead of trusting prose
- keep first-tier concepts on `Rindle` and `Rindle.Profile`, not lower-level transport internals

Concrete anchors:

- quickstart/deep-guide split: [README.md](/Users/jon/projects/rindle/README.md:13), [guides/getting_started.md](/Users/jon/projects/rindle/guides/getting_started.md:11)
- facade-first lifecycle snippet: [README.md](/Users/jon/projects/rindle/README.md:86), [guides/getting_started.md](/Users/jon/projects/rindle/guides/getting_started.md:135)
- parity language that points back to tests: [guides/getting_started.md](/Users/jon/projects/rindle/guides/getting_started.md:159)

Planning implication: if Phase 28 adds FFmpeg install guidance, link it from these two docs and keep the copy-paste path centered on `mix deps.get`, install FFmpeg, one canonical video profile, `mix rindle.doctor`, then the stock preset flow.

### `RUNNING.md` (only if Phase 28 adds it)

**Analog:** no exact standalone install-guide analog; copy the existing public-doc posture from [guides/getting_started.md](/Users/jon/projects/rindle/guides/getting_started.md:42) and maintainer-doc cross-link discipline from [test/install_smoke/release_docs_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/release_docs_parity_test.exs:67)

Mirror these patterns:

- durable public docs live behind explicit cross-links, not as an orphan page
- docs ownership is enforced by parity tests that assert exact phrases/snippets
- maintainer-only material stays out of adopter docs

Planning implication: if `RUNNING.md` exists, it should behave like a linked extension of onboarding, not a competing doc tree.

### `test/install_smoke/docs_parity_test.exs`

**Analog:** [test/install_smoke/docs_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/docs_parity_test.exs:1)

Mirror these patterns:

- `setup_all` reads doc files once, then every test works off in-memory strings
- parity tests assert literal snippets for required guidance and `refute` stale wording
- intro sections get their own focused guard instead of one giant regex

Concrete anchors:

- shared file-load setup: [test/install_smoke/docs_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/docs_parity_test.exs:4)
- exact positive copy checks across both docs: [test/install_smoke/docs_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/docs_parity_test.exs:15)
- negative drift guards for onboarding posture: [test/install_smoke/docs_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/docs_parity_test.exs:83)

Planning implication: docs parity and drift gates for FFmpeg install guidance, doctor usage, and stock preset onboarding should extend this file instead of inventing a separate shell-only doc checker.

### `.github/workflows/ci.yml`

**Analog:** [.github/workflows/ci.yml](/Users/jon/projects/rindle/.github/workflows/ci.yml:15)

Mirror these patterns:

- keep lanes explicit by concern: `quality`, `integration`, `contract`, `package-consumer`, `adopter`
- prefer `needs:` dependencies to document ship-gate order instead of collapsing everything into one job
- infrastructure setup is repeated per lane when that keeps each job self-contained and reproducible

Concrete anchors:

- fast-fail quality gate structure, including `doctor`: [.github/workflows/ci.yml](/Users/jon/projects/rindle/.github/workflows/ci.yml:16), [.github/workflows/ci.yml](/Users/jon/projects/rindle/.github/workflows/ci.yml:87)
- contract lane stays isolated and runs only contract tests: [.github/workflows/ci.yml](/Users/jon/projects/rindle/.github/workflows/ci.yml:200)
- package/adopter proof lanes reuse MinIO bootstrap instead of bespoke tooling: [.github/workflows/ci.yml](/Users/jon/projects/rindle/.github/workflows/ci.yml:265), [.github/workflows/ci.yml](/Users/jon/projects/rindle/.github/workflows/ci.yml:371)
- existing inline drift gate style: [.github/workflows/ci.yml](/Users/jon/projects/rindle/.github/workflows/ci.yml:464)

Planning implication: Phase 28 CI additions should land as named steps or lanes in `ci.yml`, not as undocumented local-only scripts.

### `test/rindle/contracts/telemetry_contract_test.exs`

**Analog:** [test/rindle/contracts/telemetry_contract_test.exs](/Users/jon/projects/rindle/test/rindle/contracts/telemetry_contract_test.exs:12)

Mirror these patterns:

- one locked `@public_events` allowlist is the source of truth for public telemetry names
- contract tests assert event-name shape, required metadata keys, and numeric measurements
- concrete runtime exercises prove events rather than snapshotting a static list alone

Concrete anchors:

- allowlist structure: [test/rindle/contracts/telemetry_contract_test.exs](/Users/jon/projects/rindle/test/rindle/contracts/telemetry_contract_test.exs:67)
- exact allowlist assertion: [test/rindle/contracts/telemetry_contract_test.exs](/Users/jon/projects/rindle/test/rindle/contracts/telemetry_contract_test.exs:87)
- exercised metadata/measurement assertions: [test/rindle/contracts/telemetry_contract_test.exs](/Users/jon/projects/rindle/test/rindle/contracts/telemetry_contract_test.exs:100)

Planning implication: telemetry naming parity for Phase 28 should extend this contract lane and compare docs against the allowlist, not create a second telemetry registry.

### `test/rindle/error_test.exs`

**Analog:** [test/rindle/error_test.exs](/Users/jon/projects/rindle/test/rindle/error_test.exs:1)

Mirror these patterns:

- exact public text parity uses byte-for-byte assertions via `exact("""...""")`
- each public reason gets its own focused test case
- remediation text belongs in `Rindle.Error.message/1` and tests lock it there

Concrete anchors:

- exact message helper and assertion style: [test/rindle/error_test.exs](/Users/jon/projects/rindle/test/rindle/error_test.exs:19), [test/rindle/error_test.exs](/Users/jon/projects/rindle/test/rindle/error_test.exs:187)
- FFmpeg-facing copy contract: [test/rindle/error_test.exs](/Users/jon/projects/rindle/test/rindle/error_test.exs:32)
- range/streaming exact public wording pattern: [test/rindle/error_test.exs](/Users/jon/projects/rindle/test/rindle/error_test.exs:127), [test/rindle/error_test.exs](/Users/jon/projects/rindle/test/rindle/error_test.exs:171)

Planning implication: the frozen AV vocabulary ship gate should extend this file with exact-text assertions, not move copy ownership into docs or workflow scripts.

### `test/rindle/doctor_test.exs` + `lib/mix/tasks/rindle.doctor.ex`

**Analogs:** [test/rindle/doctor_test.exs](/Users/jon/projects/rindle/test/rindle/doctor_test.exs:6), [lib/mix/tasks/rindle.doctor.ex](/Users/jon/projects/rindle/lib/mix/tasks/rindle.doctor.ex:4)

Mirror these patterns:

- the doctor surface is intentionally small: validate environment, print stable operator-facing output, halt non-zero on failure
- CI should run the public Mix task, not reach into lower-level probe internals

Concrete anchors:

- public requirement and minimum version statement: [lib/mix/tasks/rindle.doctor.ex](/Users/jon/projects/rindle/lib/mix/tasks/rindle.doctor.ex:7)
- stable success copy check: [test/rindle/doctor_test.exs](/Users/jon/projects/rindle/test/rindle/doctor_test.exs:7)
- CI already treats doctor as a first-class quality step: [.github/workflows/ci.yml](/Users/jon/projects/rindle/.github/workflows/ci.yml:87)

Planning implication: Phase 28 should reuse `mix rindle.doctor` as the environment drift gate and keep any new docs/tests aligned to the `>= 6.0` contract declared here.

### `test/adopter/canonical_app/lifecycle_test.exs` + `test/adopter/canonical_app/profile.ex`

**Analogs:** [test/adopter/canonical_app/lifecycle_test.exs](/Users/jon/projects/rindle/test/adopter/canonical_app/lifecycle_test.exs:1), [test/adopter/canonical_app/profile.ex](/Users/jon/projects/rindle/test/adopter/canonical_app/profile.ex:19)

Mirror these patterns:

- the canonical adopter lane is the source of truth for the public onboarding path
- real infra proof uses MinIO + PostgreSQL + actual presigned PUT, not mocked shortcuts
- canonical video onboarding should use the stock preset module, not a bespoke recipe

Concrete anchors:

- source-of-truth doc contract: [test/adopter/canonical_app/lifecycle_test.exs](/Users/jon/projects/rindle/test/adopter/canonical_app/lifecycle_test.exs:7)
- real presigned PUT proof posture: [test/adopter/canonical_app/lifecycle_test.exs](/Users/jon/projects/rindle/test/adopter/canonical_app/lifecycle_test.exs:120)
- stock preset round-trip, including `poster` + `web_720p`: [test/adopter/canonical_app/lifecycle_test.exs](/Users/jon/projects/rindle/test/adopter/canonical_app/lifecycle_test.exs:292)
- `Rindle.Profile.Presets.Web` as canonical fixture: [test/adopter/canonical_app/profile.ex](/Users/jon/projects/rindle/test/adopter/canonical_app/profile.ex:23)

Planning implication: the smartphone-video CI proof for Phase 28 should extend this adopter lane and its fixture profile, not add a second demo profile or a shell-script-only smoke.

### Anti-pattern grep enforcement

**Analogs:** [scripts/assert_release_docs_html.sh](/Users/jon/projects/rindle/scripts/assert_release_docs_html.sh:1), existing inline grep gate in [.github/workflows/ci.yml](/Users/jon/projects/rindle/.github/workflows/ci.yml:464), security posture in [test/rindle/security/argv_test.exs](/Users/jon/projects/rindle/test/rindle/security/argv_test.exs:11)

Mirror these patterns:

- deterministic bash checks use `set -euo pipefail`
- prefer a tiny helper with `rg` fallback to `grep` when scanning repo text
- fail with a concrete operator-facing message instead of silent non-zero exits

Concrete anchors:

- reusable `search()` helper pattern: [scripts/assert_release_docs_html.sh](/Users/jon/projects/rindle/scripts/assert_release_docs_html.sh:7)
- explicit failure messaging style: [scripts/assert_release_docs_html.sh](/Users/jon/projects/rindle/scripts/assert_release_docs_html.sh:18)
- existing CI inline grep drift gate: [.github/workflows/ci.yml](/Users/jon/projects/rindle/.github/workflows/ci.yml:464)
- exact anti-shell posture already tested at the library layer: [test/rindle/security/argv_test.exs](/Users/jon/projects/rindle/test/rindle/security/argv_test.exs:11)

Planning implication: block `System.shell/2`, `:os.cmd/1`, raw `Port.open/2` FFmpeg/FFprobe calls, and interpolated argv with the same small-shell-gate style already used elsewhere.

## Recommended Ownership By Plan

### Plan 01

- Primary files: `README.md`, `guides/getting_started.md`, optional `RUNNING.md`, `test/install_smoke/docs_parity_test.exs`
- Reason: keep onboarding copy and its parity gate together

### Plan 02

- Primary files: `.github/workflows/ci.yml`, `test/rindle/doctor_test.exs`, optional grep-enforcement script
- Reason: environment drift gates and anti-pattern checks belong in the ship-gate lane design

### Plan 03

- Primary files: `test/adopter/canonical_app/lifecycle_test.exs`, `test/adopter/canonical_app/profile.ex`
- Reason: canonical `Presets.Web` onboarding proof should stay in the adopter lane, not split between docs and lower-level tests

### Plan 04

- Primary files: `test/rindle/contracts/telemetry_contract_test.exs`, `test/rindle/error_test.exs`
- Reason: freeze exact telemetry naming and exact AV-facing copy in the existing public contract lanes

## Anti-Patterns To Avoid

- Do not create a second onboarding doc tree that competes with `README.md` and `guides/getting_started.md`.
- Do not make CI proof depend on ad hoc local scripts when the repo already expresses ship gates in `ci.yml`.
- Do not create a second telemetry source of truth outside `@public_events` in `test/rindle/contracts/telemetry_contract_test.exs`.
- Do not move public error copy ownership out of `Rindle.Error.message/1` and its exact-text tests.
- Do not prove AV onboarding with a bespoke demo profile; use `Rindle.Profile.Presets.Web`.
- Do not use mocked or shortcut upload/storage flows for the adopter proof when the lane is supposed to validate the real presigned PUT and variant round-trip.
