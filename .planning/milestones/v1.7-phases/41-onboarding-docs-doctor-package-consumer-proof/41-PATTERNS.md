# Phase 41: Onboarding + Docs + Doctor + Package-Consumer Proof - Pattern Map

**Mapped:** 2026-05-07
**Files analyzed:** 14
**Analogs found:** 14 / 14

## File Classification

| File | Role | Closest Analog | Match Quality |
| --- | --- | --- | --- |
| `guides/storage_gcs.md` | provider-specific deep guide | `guides/streaming_providers.md` | exact posture |
| `guides/storage_capabilities.md` | capability vocabulary + provider matrix | itself | exact in-place update |
| `README.md` | narrow optional pointer section | `README.md` "Streaming with Mux (optional)" | exact |
| `guides/getting_started.md` | canonical quickstart with short advanced pointer | `guides/getting_started.md` "Streaming with Mux (optional)" | exact |
| `guides/troubleshooting.md` | operator troubleshooting cross-link | existing install-smoke docs parity references | partial |
| `lib/rindle/ops/runtime_checks.ex` | profile-aware doctor checks | existing `doctor.streaming_*` and `doctor.gcs_*` checks | exact |
| `lib/mix/tasks/rindle.doctor.ex` | CLI rendering and exit semantics | current `[OK]/[ERROR]` output path | exact |
| `test/rindle/ops/runtime_checks_test.exs` | GCS doctor unit tests | existing `doctor.gcs_*` coverage | exact |
| `test/rindle/ops/runtime_checks_streaming_test.exs` | optional-feature doctor matrix tests | existing `doctor.streaming_*` coverage | exact |
| `test/rindle/doctor_test.exs` | Mix task flag/output plumbing tests | current `--streaming` assertions | exact |
| `scripts/install_smoke.sh` | profile dispatch | current `image|video|mux` case block | exact |
| `test/install_smoke/support/generated_app_helper.ex` | generated-app profile builder / proof harness | current `:image`, `:video`, `:mux` profiles | exact |
| `test/install_smoke/generated_app_smoke_test.exs` | generated-app assertions by profile | current image/video/mux cases | exact |
| `.github/workflows/ci.yml` | always-on package-consumer + secret-gated sibling soak jobs | `package-consumer`, `mux-soak`, `gcs-soak` | exact |

## Pattern Assignments

### README / getting-started optional pointer pattern

Use the existing "optional subsection with deep-guide pointer" posture rather than expanding the canonical quickstart.

Analog:

- `README.md` `## Streaming with Mux (optional)`
- `guides/getting_started.md` `## 10. Streaming with Mux (optional)`

Phase 41 should mirror this structure:

- short heading
- brief explanation that the path is optional/advanced
- pointer to the deep guide
- no branching first-run matrix

### Provider-specific deep guide pattern

`guides/storage_gcs.md` should become the deep source of truth just like the streaming guide is for Mux-specific setup:

- explicit steps
- copy-paste snippets
- operational caveats
- security callouts
- clear division between canonical quickstart and advanced provider setup

This is an in-place expansion, not a new guide family.

### Doctor optional-feature gating pattern

Analog in `lib/rindle/ops/runtime_checks.ex`:

- streaming checks are appended only when streaming profiles are relevant
- GCS checks are appended only when `gcs_profiles(profiles) != []`
- helper functions return structured `%{id, status, component, summary, fix}` maps

Phase 41 resumable GCS check should extend the same pattern:

- detect only GCS-backed profiles
- further gate to profiles that advertise `:resumable_upload_session`
- reuse `ok_result`/`error_result` style helpers, with an additive warning helper if needed
- never emit irrelevant rows for non-GCS adopters

### Mix task rendering pattern

`lib/mix/tasks/rindle.doctor.ex` currently:

- parses strict flags with `OptionParser`
- delegates to `RuntimeChecks.run/2`
- emits one line per check using `[#{String.upcase(to_string(status))}]`
- fails only when `report.success?` is false

Phase 41 should preserve this thin-shell pattern. If warning support is added, implement it at the report/result level and let the task remain a renderer plus exit-policy boundary.

### Generated-app profile expansion pattern

Analog in `test/install_smoke/support/generated_app_helper.ex`:

- `profile_enabled?/1`
- `prove_package_install!/1`
- profile-specific patching/wiring inside the helper
- report map returned to tests

Phase 41 should add a fourth profile mode instead of inventing a parallel helper.

Likely shape:

- extend accepted profile atoms to include `:gcs`
- extend generated-app patching to wire Goth/Finch/GCS profile config
- return additional proof fields needed for doctor/lifecycle assertions

### Generated-app smoke assertion pattern

Analog in `test/install_smoke/generated_app_smoke_test.exs`:

- one ExUnit module per profile when enabled
- shared `assert_install_source!/1`
- profile-specific lifecycle assertions

Phase 41 should mirror the `:mux` shape:

- one `:gcs` profile module
- install-source assertions stay identical
- lifecycle assertions check doctor pass plus resumable completion proof

### CI lane topology pattern

Use the existing split in `.github/workflows/ci.yml`:

- `package-consumer` for always-on structural proof
- `mux-soak` as a sibling top-level secret/label-gated live lane
- `gcs-soak` as an existing sibling real-provider lane

Phase 41 should follow that topology:

- keep structural generated-app GCS proof in `package-consumer`
- add a sibling secret-gated generated-app live GCS proof job, not a nested step that always runs
- reuse `if: ${{ secrets.* != '' }}` posture for fork safety

## Concrete Analog Notes

### `lib/rindle/ops/runtime_checks.ex`

Relevant existing anchors:

- `doctor.streaming_*` checks for optional-feature discovery and focused fix text
- `doctor.gcs_*` checks for GCS-only row gating
- `gcs_profiles/1` delegating to `Rindle.Capability.configured_gcs_profiles/1`

The new resumable CORS-suspected check should stay in this family rather than creating a second diagnostics module.

### `test/rindle/ops/runtime_checks_test.exs`

This file already proves:

- zero GCS noise when no GCS profiles are discovered
- the exact set of `doctor.gcs_*` rows when GCS profiles are present
- probe/failure taxonomy for bucket reachability

Phase 41 should extend these exact coverage patterns for the resumable-only warning row.

### `scripts/install_smoke.sh`

Current dispatch is a simple shell case over profile names. Extend the same case block for `gcs`; do not fork the script or add a second entrypoint.

### `.github/workflows/ci.yml`

The file already contains the right proof primitives:

- service-backed package-consumer structural lane
- real-provider soak jobs
- secret-gated `gcs-soak`

The new generated-app GCS live lane should look like a package-consumer-flavored sibling of `gcs-soak`, not a brand new workflow pattern.

## Planner Guidance

- Keep `RESUMABLE-12` file lists doc-only.
- Keep `RESUMABLE-13` file lists in doctor/runtime-check/task-test boundaries.
- Keep `RESUMABLE-14` file lists in install-smoke/helper/workflow/test boundaries.
- If the planner needs a threat model, the highest-signal boundaries are:
  - docs/CI/logs must not leak `session_uri` or credentials
  - warnings must not silently fail CI
  - secret-gated live lanes must skip safely on fork PRs
