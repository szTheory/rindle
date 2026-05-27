# Phase 59: E2E Proof & Truth Closure - Research

**Researched:** 2026-05-27  
**Domain:** tus extension E2E proof hardening, docs truth closure, milestone closeout  
**Confidence:** HIGH

## User Constraints (Locked)

- Reuse the existing MinIO-backed `install_smoke` lane; do not create a new proof lane.
- Keep `tus-js-client@4.3.1` pinned as the proof driver.
- Prove three extension paths end-to-end in the existing Node proof harness:
  - Concatenation (`parallelUploads >= 2`)
  - Creation-Defer-Length (`uploadLengthDeferred: true`)
  - Checksum (valid `Upload-Checksum` transmission)
- Update `guides/resumable_uploads.md` to state full tus 1.0.0 extension support.
- Add parity assertions so guide claims cannot drift silently.
- No public API breakage; this phase is proof/doc/audit closure only.

## Repo Reality Check

1. `Rindle.Upload.TusPlug` already advertises the complete extension set in tests and code paths consumed by the current suite.
2. `test/rindle/upload/tus_plug_test.exs` already covers protocol-level checks (including checksum/defer-length/concatenation contract surfaces).
3. The current generated-app lane (`test/install_smoke/support/generated_app_helper.ex`) proves interrupt/resume but still runs with `parallelUploads: 1` and no explicit extension evidence object.
4. `guides/resumable_uploads.md` still documents conservative client posture and does not freeze all new extension claims in parity tests.
5. `test/install_smoke/generated_app_smoke_test.exs` and `test/install_smoke/phoenix_tus_truth_parity_test.exs` are the right lock points for "truth closure" and should be extended, not replaced.

## Key Technical Approach

### 1) Expand the existing Node proof harness by mode (no new lane)

Keep one generated Node script in `test/install_smoke/support/generated_app_helper.ex`, but add explicit extension runs:

- `resume_interrupt` (existing baseline)
- `concat_parallel` (`parallelUploads: 2`)
- `defer_length_stream` (`uploadLengthDeferred: true` with stream source and finite `chunkSize`)
- `checksum_patch` (checksum header verification on PATCH path)

This keeps operational cost low while making each extension auditable.

### 2) Extend report contract additively

Persist extension proof outcomes in `tmp/install_smoke_tus_report.json` under an `extensions` object, then surface the same fields through `GeneratedAppHelper.prove_package_install!/1` so `generated_app_smoke_test.exs` can assert them directly.

Recommended shape:

```json
{
  "extensions": {
    "concatenation": { "proved": true, "parallel_uploads": 2 },
    "creation_defer_length": { "proved": true, "used_upload_defer_length": true },
    "checksum": { "proved": true, "algorithm": "sha256", "status": 204 }
  }
}
```

### 3) Freeze guide truth across dedicated parity surfaces

Update `guides/resumable_uploads.md` to explicitly claim full tus extension coverage, then freeze those claims in:

- `test/install_smoke/generated_app_smoke_test.exs` (`assert_tus_guide_parity!/0`)
- `test/install_smoke/phoenix_tus_truth_parity_test.exs`

### 4) Keep checksum mismatch semantics primarily in unit/contract lane

The E2E proof should assert valid checksum transmission; negative-path (`460`) behavior remains most stable in `test/rindle/upload/tus_plug_test.exs` contract coverage.

## Dependencies and Constraints

- MinIO-backed smoke lane must stay healthy (`--include minio` and `scripts/ensure_minio.sh` path via `scripts/install_smoke.sh`).
- Node/npm are required in generated app for `npm install --no-save tus-js-client@4.3.1`.
- `ffmpeg` is required by existing large fixture generation in the generated app helper.
- Do not introduce new runtime dependencies in core library code.
- Do not modify public API semantics in `Rindle.Upload.TusPlug` for this phase.

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Mixing `parallelUploads` with `uploadLengthDeferred` in one proof | False failures and noisy debugging | Keep separate proof modes and assert mode metadata in report |
| Overfitting to config instead of transport behavior | Green tests without real extension proof | Record request/response evidence and assert completion semantics |
| Guide claims drift from executable truth | Docs become stale silently | Enforce claim strings in both smoke parity and truth parity tests |
| Checksum E2E path becomes brittle | Flaky CI lane | Keep E2E checksum proof focused on valid transmission; leave mismatch (`460`) in unit/contract suite |
| Milestone closure without artifact reconciliation | Premature closure and planning drift | Require updated planning artifacts and full tus smoke evidence before closure |

## Validation Architecture

Phase 59 validation follows a Nyquist-style dual-frequency model: fast checks run frequently during implementation, while full-lane checks run at merge gate to catch lower-frequency integration drift. Validation is complete only when all four surfaces pass: unit, integration, e2e, and docs parity.

### Validation Matrix (required for closure)

| Layer | Command | What it validates | Required evidence artifact |
|---|---|---|---|
| Unit / contract | `mix test test/rindle/upload/tus_plug_test.exs` | Tus protocol contract, extension headers, checksum semantics (`460` path) | ExUnit pass output for this file |
| Integration / truth parity | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs` | Guide + helper seam + planning truth alignment | ExUnit pass output for truth parity test |
| Integration / generated app assertions | `mix test test/install_smoke/generated_app_smoke_test.exs --include minio` | `GeneratedAppHelper.prove_package_install!/1` report mapping + guide parity assertions | ExUnit pass output and populated `report.tus_report_data` fields |
| E2E full lane | `bash scripts/install_smoke.sh tus` | End-to-end package-consumer flow with MinIO and generated app | `tmp/install_smoke_tus_last_run.json`, generated app `tmp/install_smoke_tus_report.json`, and `tmp/install_smoke_tus_debug_report.json` |
| Doc parity spot check | `rg -n 'checksum|creation-defer-length|concatenation|parallelUploads' guides/resumable_uploads.md` | Guide explicitly documents extension support and client posture | `rg` output captured in planner/checker notes |

### Artifact Contract for Checkers

Checkers/planners should be able to locate these artifacts after a tus run:

- Repo-level hint: `tmp/install_smoke_tus_last_run.json`
- Generated-app report path: value of `tus_report_path` in `tmp/install_smoke_tus_last_run.json`
- Generated-app debug path: value of `tus_debug_report_path` in `tmp/install_smoke_tus_last_run.json`
- Runtime summary keys to inspect:
  - `tus_failure_phase`, `tus_failure_mode`, `tus_failure_summary`
  - `tus_report.extensions.*` (new Phase 59 contract)
  - Existing truth keys (`completion_surface`, `phoenix_state_sequence`, etc.)

Helpful check command:

`rg -n '"tus_failure_phase"|"tus_failure_mode"|"extensions"|"completion_surface"|"phoenix_state_sequence"' tmp/install_smoke_tus_last_run.json`

### Failure-Mode Checks (must be explicit)

- If `tus_failure_phase` is not `none`/`nil`, treat as hard failure for closure.
- If extension proof object is missing or incomplete, treat as hard failure even when smoke test is otherwise green.
- If docs claim full extension support but parity tests do not assert those claims, treat as parity failure.
- If MinIO instability causes inconclusive E2E output, run unit + truth parity first to isolate infra vs logic regression.

### Rollback / Mitigation Notes

- Roll back harness changes by restoring baseline interrupt/resume mode only if the extension proof expansion is causing unrelated lane breakage; do not close Phase 59 in that state.
- Keep report evolution additive (new nested fields) to avoid breaking existing consumers of `tus_report_data`.
- If checksum E2E path is unstable, keep success-path proof in E2E and rely on existing contract test for mismatch (`460`) semantics.
- Do not unpin `tus-js-client@4.3.1` during this phase; version churn masks protocol regressions.

## Suggested Implementation Sequence for Planner Handoff

1. **Harness expansion**
   - Update `write_tus_node_script!/1` and surrounding helper functions in `test/install_smoke/support/generated_app_helper.ex` for explicit extension modes and evidence capture.
2. **Report mapping**
   - Extend helper report maps (`tus_report_data` and top-level projection) to include `extensions` fields.
3. **Smoke assertions**
   - Add assertions in `test/install_smoke/generated_app_smoke_test.exs` for extension proof fields and failure semantics.
4. **Guide update**
   - Update `guides/resumable_uploads.md` with full extension support and adopter usage guidance (`parallelUploads`, defer-length constraints, checksum behavior).
5. **Truth parity lock**
   - Extend `test/install_smoke/phoenix_tus_truth_parity_test.exs` and `assert_tus_guide_parity!/0` to freeze new claims.
6. **Validation and closure prep**
   - Run the validation matrix in order, capture artifacts, then update milestone closeout docs (`.planning/STATE.md`, `.planning/ROADMAP.md`, and milestone audit artifacts) only after all checks pass.

## Planner Slices

### Slice A - Extension Harness
- **Goal:** prove concatenation/defer-length/checksum in generated-app Node harness.
- **Files:** `test/install_smoke/support/generated_app_helper.ex`
- **Verify:** `mix test test/install_smoke/generated_app_smoke_test.exs --include minio`

### Slice B - Report + Assertions
- **Goal:** make extension evidence machine-checkable and test-enforced.
- **Files:** `test/install_smoke/support/generated_app_helper.ex`, `test/install_smoke/generated_app_smoke_test.exs`
- **Verify:** same as Slice A plus artifact spot-check command.

### Slice C - Guide + Truth Parity
- **Goal:** lock docs to implemented extension behavior.
- **Files:** `guides/resumable_uploads.md`, `test/install_smoke/phoenix_tus_truth_parity_test.exs`, `test/install_smoke/generated_app_smoke_test.exs`
- **Verify:** `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs`

### Slice D - Milestone Closure Readiness
- **Goal:** close v1.11 with executable proof and synchronized planning state.
- **Files:** `.planning/STATE.md`, `.planning/ROADMAP.md`, milestone audit artifact path selected in planning
- **Verify:** `bash scripts/install_smoke.sh tus`

