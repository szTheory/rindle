# Phase 59: E2E Proof & Truth Closure - Pattern Map

**Mapped:** 2026-05-27  
**Files analyzed:** 11  
**Analogs found:** 11 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/install_smoke/support/generated_app_helper.ex` | generated-app proof harness | batch + artifact emission | `test/install_smoke/support/generated_app_helper.ex` | exact |
| `test/install_smoke/generated_app_smoke_test.exs` | install-smoke assertions | report-consumer + docs parity | `test/install_smoke/generated_app_smoke_test.exs` | exact |
| `test/install_smoke/phoenix_tus_truth_parity_test.exs` | truth/parity drift gate | string parity across truth surfaces | `test/install_smoke/phoenix_tus_truth_parity_test.exs` | exact |
| `guides/resumable_uploads.md` | adopter protocol guide | docs -> runtime expectations | `guides/resumable_uploads.md` | exact |
| `.planning/ROADMAP.md` | milestone/phase status ledger | planning truth | `.planning/ROADMAP.md` | exact-structure |
| `.planning/STATE.md` | active milestone state | planning truth + continuity | `.planning/STATE.md` | exact-structure |
| `.planning/milestones/v1.11-MILESTONE-AUDIT.md` (new) | milestone closure artifact | evidence synthesis | `.planning/milestones/v1.10-MILESTONE-AUDIT.md` | strong |
| `.planning/phases/59-e2e-proof-truth-closure/59-VALIDATION.md` | phase verification matrix | command/evidence mapping | `.planning/phases/50-phoenix-proof-parity-closure/50-02-SUMMARY.md` verification style + existing `59-VALIDATION.md` | strong |
| `.planning/phases/59-e2e-proof-truth-closure/59-01-SUMMARY.md` (likely new) | plan execution summary | closure/frontmatter ownership | `.planning/phases/50-phoenix-proof-parity-closure/50-01-SUMMARY.md` | strong |
| `.planning/phases/59-e2e-proof-truth-closure/59-02-SUMMARY.md` (likely new) | plan execution summary | closure/frontmatter ownership | `.planning/phases/50-phoenix-proof-parity-closure/50-02-SUMMARY.md` | strong |
| `scripts/install_smoke.sh` (read-only reference) | closure command wrapper | script -> smoke lane | `scripts/install_smoke.sh` | exact |

## Pattern Assignments

### `test/install_smoke/support/generated_app_helper.ex`

- **Analog:** same file, current `:tus` lane implementation.
- **Why this is the anchor:** Phase 59 is constrained to expand the existing MinIO-backed lane, not create a new lane.

**Concrete seams to reuse**

```elixir
defp install_tus_js_client! do
  if File.exists?("node_modules/tus-js-client/package.json") do
    :ok
  else
    {output, exit_code} =
      System.cmd(
        "npm",
        ["install", "--no-save", "tus-js-client@4.3.1"],
        stderr_to_stdout: true
      )

    assert exit_code == 0, output
  end
end
```

```elixir
defp baseOptions() {
  return {
    endpoint,
    uploadUrl,
    metadata,
    chunkSize,
    parallelUploads: 1,
    retryDelays: null,
    httpStack: new tus.DefaultHttpStack({ agent: false }),
    removeFingerprintOnSuccess: true,
    storeFingerprintForResuming: true,
    fingerprint: () => Promise.resolve(fingerprintValue),
    urlStorage: new tus.FileUrlStorage(urlStoragePath),
  }
}
```

```elixir
defp merge_tus_report!(attrs) do
  attrs = Map.merge(read_tus_report!(), attrs)
  write_tus_report!(attrs)
end
```

**Actionable guidance**

- Keep one script (`write_tus_node_script!/1`) and branch by explicit mode, like current `interrupt`/`resume`; add additive modes for `concat_parallel`, `defer_length_stream`, `checksum_patch`.
- Keep `tus-js-client@4.3.1` pinned exactly.
- Extend report shape additively under `extensions`:
  - `extensions.concatenation`
  - `extensions.creation_defer_length`
  - `extensions.checksum`
- Preserve current breadcrumbs (`failure_phase`, `failure_mode`, `failure_summary`, `completion_surface`, `phoenix_state_sequence`) and add extension evidence instead of replacing existing keys.
- Continue writing `tmp/install_smoke_tus_report.json`, `tmp/install_smoke_tus_debug_report.json`, and repo hint `tmp/install_smoke_tus_last_run.json`.

---

### `test/install_smoke/generated_app_smoke_test.exs`

- **Analog:** same file (`GeneratedAppSmokeTusTest` + `assert_tus_guide_parity!/0`).

**Concrete seams to reuse**

```elixir
assert report.smoke_exit_code == 0, tus_failure_details(report)
assert report.lifecycle_proved?, tus_failure_details(report)
assert report.tus_previous_uploads >= 1
assert report.tus_ready_variants == ["poster", "web_720p"]
assert_tus_guide_parity!()
```

```elixir
defp assert_tus_guide_parity! do
  guide = File.read!("guides/resumable_uploads.md")
  assert guide =~ "@uppy/tus"
  assert guide =~ "tus-js-client"
  assert guide =~ "sticky-session or single-node"
end
```

**Actionable guidance**

- Add assertions on `report.tus_report_data["extensions"]` (or projected top-level mirrors) for all three Phase 59 proofs.
- Keep failure diagnostics routed through `tus_failure_details/1` so extension regressions surface with phase/mode context.
- Extend `assert_tus_guide_parity!/0` with literal strings that freeze new claims (`checksum`, `creation-defer-length`, `concatenation`, `parallelUploads`).

---

### `test/install_smoke/phoenix_tus_truth_parity_test.exs`

- **Analog:** same file, literal contract freeze style.

**Concrete seams to reuse**

```elixir
assert guide =~ "findPreviousUploads()"
assert guide =~ "resumeFromPreviousUpload(previousUploads[0])"
```

```elixir
assert generated_helper =~
         ~s(completion_surface: "consume_uploaded_entries->verify_completion")
assert generated_helper =~ ~s(phoenix_state_sequence: ["uploading", "verifying", "ready"])
```

```elixir
for doc <- active_truth_surfaces do
  refute doc =~ "LiveView tus uploader component"
end
```

**Actionable guidance**

- Keep parity tests literal and narrow; add extension-proof vocabulary checks as `assert guide =~ ...` and helper/report seam checks as `assert generated_helper =~ ...`.
- Add negative drift guards for stale wording (for example, wording that says only `parallelUploads: 1` is supported).
- Keep active-vs-historical split intact; Phase 59 should extend current truth surfaces, not re-open archived milestone wording.

---

### `guides/resumable_uploads.md`

- **Analog:** same file, numbered sections + explicit adopter ownership.

**Concrete seams to reuse**

```markdown
Rindle ships a tus 1.0 upload edge via `Rindle.Upload.TusPlug`.
```

```javascript
const upload = new tus.Upload(file, {
  endpoint: "/uploads/tus",
  metadata: { ... },
  retryDelays: [0, 1000, 3000, 5000],
  parallelUploads: 1,
  removeFingerprintOnSuccess: true
})
```

```javascript
uppy.use(Tus, {
  endpoint: "/uploads/tus",
  parallelUploads: 1
})
```

**Actionable guidance**

- Keep guide posture honest: default-safe config plus explicit opt-in examples for extension paths.
- Add an explicit "supported extensions" statement listing: `creation`, `expiration`, `termination`, `checksum`, `creation-defer-length`, `concatenation`.
- Show adopter knobs concretely:
  - `parallelUploads >= 2` for concatenation
  - `uploadLengthDeferred: true` for defer-length
  - checksum negotiation notes for `tus-js-client`
- Preserve existing security/no-silent-downgrade language and sticky-session caveat.

---

### Planning Closure Docs (`.planning/ROADMAP.md`, `.planning/STATE.md`, milestone audit + phase summaries)

- **Analogs:**
  - `.planning/milestones/v1.10-MILESTONE-AUDIT.md`
  - `.planning/milestones/v1.9-MILESTONE-AUDIT.md`
  - `.planning/phases/50-phoenix-proof-parity-closure/50-01-SUMMARY.md`
  - `.planning/phases/50-phoenix-proof-parity-closure/50-02-SUMMARY.md`

**Concrete seams to reuse**

```yaml
---
milestone: v1.10
audited: 2026-05-26T14:47:00Z
status: passed
scores:
  requirements: 7/7
  phases: 3/3
  integration: 4/4
  flows: 4/4
---
```

```markdown
## Evidence Consumed
- `.planning/phases/.../XX-VERIFICATION.md` certifies ...
- `.planning/phases/.../XX-VALIDATION.md` now record validated Nyquist metadata ...
```

```yaml
requirements-completed: [PROOF-01, PROOF-02]
```

**Actionable guidance**

- `ROADMAP.md`: mark Phase 59 complete only after full matrix evidence exists; then archive milestone links with consistent heading format.
- `STATE.md`: update frontmatter and narrative to reflect milestone closeout status and next milestone focus.
- `v1.11-MILESTONE-AUDIT.md` (new): follow v1.9/v1.10 scorecard/evidence/verdict format with explicit pass/fail fields.
- `59-0x-SUMMARY.md` (if produced): keep frontmatter ownership (`requirements-completed`) and concrete verification commands.
- `59-VALIDATION.md`: once checks are green, set Nyquist flags and status consistently; avoid leaving draft compliance flags at closure.

---

### `scripts/install_smoke.sh` (closure command contract)

- **Analog:** same file.

**Concrete seam to reuse**

```bash
if [ "$PROFILE" = "gcs" ]; then
  mix test test/install_smoke/generated_app_smoke_test.exs
else
  mix test test/install_smoke/generated_app_smoke_test.exs --include minio
fi
```

```bash
if [ "$status" -ne 0 ] && [ "$PROFILE" = "tus" ]; then
  hint_file="$ROOT_DIR/tmp/install_smoke_tus_last_run.json"
  ...
fi
```

**Actionable guidance**

- Do not create a parallel script lane for Phase 59; run/verify through existing `tus` profile path.
- Treat `tmp/install_smoke_tus_last_run.json` as required closure evidence pointer.

## Anti-Pattern Warnings

- Do not introduce a second proof lane (new script/profile/test module) for extensions; extend existing `:tus` generated-app proof.
- Do not unpin or loosely pin `tus-js-client`; keep `tus-js-client@4.3.1`.
- Do not overwrite tus report payload wholesale; use additive merge and preserve existing keys.
- Do not claim full extension support in docs without freezing those exact claims in both smoke parity surfaces.
- Do not replace literal truth-parity assertions with broad regex-only checks that allow wording drift.
- Do not close milestone/planning docs before collecting green evidence from unit, integration parity, generated-app smoke, and full `scripts/install_smoke.sh tus`.

## Execution Checklist for Planner/Executor

- Extend helper Node proof modes and emit `extensions.*` report object.
- Project extension evidence through `GeneratedAppHelper.prove_package_install!/1`.
- Add smoke assertions for extension evidence and failure semantics.
- Update guide extension claims and client-configuration examples.
- Extend truth parity tests to freeze new guide/helper claims.
- Run closure matrix and then update `.planning/ROADMAP.md`, `.planning/STATE.md`, and milestone audit artifacts.

## PATTERN MAPPING COMPLETE

Path: `.planning/phases/59-e2e-proof-truth-closure/59-PATTERNS.md`

- Mapped concrete analogs for helper/test/guide/closure docs.
- Included repository-specific excerpts and additive report-contract guidance.
- Added anti-pattern guards aligned with Phase 59 constraints.
