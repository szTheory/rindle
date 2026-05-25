# Phase 46: generated-app-tus-runtime-proof-recovery - Pattern Map

**Mapped:** 2026-05-24
**Files analyzed:** 6
**Analogs found:** 6 / 6

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/install_smoke.sh` | utility | batch | `scripts/install_smoke.sh` | exact |
| `scripts/ensure_minio.sh` | utility | request-response | `scripts/ensure_minio.sh` | exact |
| `test/install_smoke/generated_app_smoke_test.exs` | test | request-response | `test/install_smoke/generated_app_smoke_test.exs` | exact |
| `test/install_smoke/support/generated_app_helper.ex` | utility | batch | `test/install_smoke/support/generated_app_helper.ex` | exact |
| `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md` | test | request-response | `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md` | exact |
| `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VALIDATION.md` | test | request-response | `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VALIDATION.md` | exact |

## Pattern Assignments

### `scripts/install_smoke.sh` (utility, batch)

**Analog:** `scripts/install_smoke.sh`

**Shell bootstrap pattern** (`scripts/install_smoke.sh:1-17`):
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR="${RINDLE_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/rindle-install-smoke-script-XXXXXX")
...
trap cleanup EXIT
cd "$ROOT_DIR"
```

**Profile gate + package build pattern** (`scripts/install_smoke.sh:19-32`):
```bash
case "$PROFILE" in
  all|image|video|tus|mux|gcs) ;;
  *)
    echo "unsupported install smoke profile: $PROFILE" >&2
    exit 1
    ;;
esac

if [ -z "${RINDLE_INSTALL_SMOKE_PACKAGE_ROOT:-}" ]; then
  mix hex.build --unpack --output "$PACKAGE_ROOT"
fi

unset RINDLE_INSTALL_SMOKE_NETWORK_VERSION
export RINDLE_INSTALL_SMOKE_PROFILE="$PROFILE"
```

**MinIO gating + test dispatch pattern** (`scripts/install_smoke.sh:34-52`):
```bash
if [ "$PROFILE" != "gcs" ]; then
  export RINDLE_MINIO_RESET_BUCKET=1
  bash "$SCRIPT_DIR/ensure_minio.sh"
fi

if [ "$PROFILE" = "gcs" ]; then
  mix test test/install_smoke/generated_app_smoke_test.exs
  status=$?
else
  mix test test/install_smoke/generated_app_smoke_test.exs --include minio
  status=$?
fi
```

**Failure breadcrumb surfacing** (`scripts/install_smoke.sh:54-63`):
```bash
if [ "$status" -ne 0 ] && [ "$PROFILE" = "tus" ]; then
  hint_file="$ROOT_DIR/tmp/install_smoke_tus_last_run.json"

  if [ -f "$hint_file" ]; then
    echo "tus install-smoke artifacts:" >&2
    cat "$hint_file" >&2
  fi
fi
```

Use `scripts/public_smoke.sh:23-33` alongside this when preserving the shared pattern that MinIO bootstrap stays outside the test module and the script owns environment normalization.

---

### `scripts/ensure_minio.sh` (utility, request-response)

**Analog:** `scripts/ensure_minio.sh`

**Env + healthcheck pattern** (`scripts/ensure_minio.sh:4-25`):
```bash
MINIO_URL="${RINDLE_MINIO_URL:-http://localhost:9000}"
MINIO_BUCKET="${RINDLE_MINIO_BUCKET:-rindle-test}"
MINIO_ACCESS_KEY="${RINDLE_MINIO_ACCESS_KEY:-minioadmin}"
MINIO_SECRET_KEY="${RINDLE_MINIO_SECRET_KEY:-minioadmin}"
MINIO_RESET_BUCKET="${RINDLE_MINIO_RESET_BUCKET:-}"

healthcheck_url() {
  printf '%s/minio/health/ready' "${MINIO_URL%/}"
}

wait_for_minio() {
  local attempts="${1:-30}"
  ...
}
```

**Endpoint parsing + hard failure pattern** (`scripts/ensure_minio.sh:27-58`):
```bash
case "$MINIO_URL" in
  http://*)
    scheme="http"
    remainder="${MINIO_URL#http://}"
    ;;
  https://*)
    scheme="https"
    remainder="${MINIO_URL#https://}"
    ;;
  *)
    echo "Unsupported RINDLE_MINIO_URL: $MINIO_URL" >&2
    exit 1
    ;;
esac
```

**Bucket/bootstrap pattern** (`scripts/ensure_minio.sh:103-158`):
```bash
ensure_bucket() {
  "$MC_BIN" alias set local "$MINIO_URL" "$MINIO_ACCESS_KEY" "$MINIO_SECRET_KEY" >/dev/null
  "$MC_BIN" mb --ignore-existing "local/$MINIO_BUCKET" >/dev/null

  if [ -n "$MINIO_RESET_BUCKET" ]; then
    "$MC_BIN" rm --recursive --force "local/$MINIO_BUCKET" >/dev/null 2>&1 || true
  fi
}

if wait_for_minio 1; then
  ...
  ensure_bucket
  exit 0
fi
```

**Embedded local-only fallback** (`scripts/ensure_minio.sh:161-177`):
```bash
case "$MINIO_HOST" in
  localhost|127.0.0.1)
    ;;
  *)
    echo "MinIO is unreachable at $MINIO_URL and auto-bootstrap only supports local endpoints." >&2
    exit 1
    ;;
esac

ensure_binary "$MINIO_BIN" "https://dl.min.io/server/minio/release/${triplet}/minio"
ensure_binary "$MC_BIN" "https://dl.min.io/client/mc/release/${triplet}/mc"
start_embedded_minio
```

Keep this script as the sole place that decides whether to reuse, bootstrap, or reject MinIO endpoints.

---

### `test/install_smoke/generated_app_smoke_test.exs` (test, request-response)

**Analog:** `test/install_smoke/generated_app_smoke_test.exs`

**CaseTemplate assertion helpers** (`test/install_smoke/generated_app_smoke_test.exs:3-63`):
```elixir
defmodule Rindle.InstallSmoke.GeneratedAppSmokeAssertions do
  use ExUnit.CaseTemplate

  using do
    quote do
      defp assert_install_source!(report) do
        assert File.dir?(report.generated_app_root)
        assert report.profile_mode in [:image, :video, :tus, :upgrade, :mux, :gcs]
        ...
        refute report.deps_rindle_present?
        assert report.compile_exit_code == 0
        assert report.boot_exit_code == 0
      end
```

**Docs-parity lock pattern** (`test/install_smoke/generated_app_smoke_test.exs:29-47`):
```elixir
defp assert_tus_guide_parity! do
  guide = File.read!("guides/resumable_uploads.md")

  assert guide =~ "plug Plug.Parsers,"
  assert guide =~ ~s(pass: ["application/offset+octet-stream", "*/*"])
  assert guide =~ ~s("Upload-Offset")
  ...
  assert guide =~ "sticky-session or single-node"
  assert Regex.scan(~r/removeFingerprintOnSuccess: true/, guide) |> length() == 2
end
```

**Failure detail formatter** (`test/install_smoke/generated_app_smoke_test.exs:49-60`):
```elixir
defp tus_failure_details(report) do
  """
  tus smoke failed
  workspace: #{report.generated_app_root}
  report: #{report.tus_report_path}
  debug_report: #{report.tus_debug_report_path}
  phase: #{inspect(report.tus_failure_phase)}
  ...
  """
end
```

**Tus smoke contract pattern** (`test/install_smoke/generated_app_smoke_test.exs:177-209`):
```elixir
setup_all do
  report = GeneratedAppHelper.prove_package_install!(:tus)
  on_exit(fn -> GeneratedAppHelper.cleanup(report) end)
  {:ok, report: report}
end

test "generated Phoenix app proves a real-socket tus-js-client drop-and-resume flow against MinIO",
     %{report: report} do
  assert report.smoke_exit_code == 0, tus_failure_details(report)
  assert report.lifecycle_proved?, tus_failure_details(report)
  assert is_binary(report.tus_upload_url)
  assert String.contains?(report.tus_upload_url, "/uploads/tus/")
  assert report.tus_previous_uploads >= 1
  assert report.tus_byte_size >= 200 * 1024 * 1024
  assert report.tus_content_type == "video/mp4"
  assert report.tus_ready_variants == ["poster", "web_720p"]
  assert_tus_guide_parity!()
end
```

Preserve the pattern that failures show saved artifact paths, not just assertion text.

---

### `test/install_smoke/support/generated_app_helper.ex` (utility, batch)

**Analog:** `test/install_smoke/support/generated_app_helper.ex`

**Top-level prove/install report pattern** (`test/install_smoke/support/generated_app_helper.ex:19-140`):
```elixir
def prove_package_install!(profile_mode \\ :image)
    when profile_mode in [:image, :video, :tus, :mux, :gcs] do
  ...
  tus_report_path = Path.join(generated_app_root, "tmp/install_smoke_tus_report.json")
  tus_debug_report_path = Path.join(generated_app_root, "tmp/install_smoke_tus_debug_report.json")
  ...
  report = %{
    workspace_root: workspace_root,
    generated_app_root: generated_app_root,
    package_root: package_root,
    ...
    tus_upload_url: tus_report["upload_url"],
    tus_previous_uploads: tus_report["previous_uploads"],
    tus_byte_size: tus_report["byte_size"],
    tus_content_type: tus_report["content_type"],
    tus_ready_variants: tus_report["ready_variants"] || [],
    tus_report_path: tus_report_path,
    tus_debug_report_path: tus_debug_report_path,
    tus_report_data: tus_report,
    tus_debug_report_data: tus_debug_report,
    tus_failure_phase: tus_debug_report["failure_phase"] || tus_report["failure_phase"],
    tus_failure_endpoint: tus_debug_report["endpoint"] || tus_report["endpoint"],
    tus_failure_summary: tus_debug_report["failure_summary"] || tus_report["failure_summary"],
    tus_failure_mode: tus_debug_report["failure_mode"] || tus_report["failure_mode"],
    ...
  }

  maybe_write_tus_run_hint!(report)
  report
end
```

**Repo-level last-run hint pattern** (`test/install_smoke/support/generated_app_helper.ex:1177-1199`):
```elixir
defp maybe_write_tus_run_hint!(%{profile_mode: :tus} = report) do
  hint_path = Path.join([repo_root(), "tmp", "install_smoke_tus_last_run.json"])
  File.mkdir_p!(Path.dirname(hint_path))

  File.write!(
    hint_path,
    Jason.encode!(%{
      workspace_root: report.workspace_root,
      generated_app_root: report.generated_app_root,
      tus_report_path: report.tus_report_path,
      tus_debug_report_path: report.tus_debug_report_path,
      tus_report: report.tus_report_data,
      tus_debug_report: report.tus_debug_report_data,
      tus_failure_phase: report.tus_failure_phase,
      tus_failure_mode: report.tus_failure_mode,
      tus_failure_endpoint: report.tus_failure_endpoint,
      tus_failure_summary: report.tus_failure_summary,
      smoke_output: report.smoke_output
    })
  )
end
```

**Node client pin + resume storage pattern** (`test/install_smoke/support/generated_app_helper.ex:2180-2270`):
```elixir
defp install_tus_js_client! do
  if File.exists?("node_modules/tus-js-client/package.json") do
    :ok
  else
    {output, exit_code} =
      System.cmd("npm", ["install", "--no-save", "tus-js-client@4.3.1"], stderr_to_stdout: true)

    assert exit_code == 0, output
  end
end
...
function baseOptions() {
  return {
    endpoint,
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

**Two-phase proof + JSON merge helpers** (`test/install_smoke/support/generated_app_helper.ex:2462-2527`):
```elixir
defp run_tus_node_proof!(script_path, endpoint, fixture_path) do
  debug_report_path = Path.expand("../tmp/install_smoke_tus_debug_report.json", __DIR__)

  merge_tus_report!(%{
    endpoint: endpoint,
    report_path: Path.expand("../tmp/install_smoke_tus_report.json", __DIR__),
    debug_report_path: debug_report_path
  })

  {interrupt_output, interrupt_exit_code} =
    System.cmd("node", [script_path, endpoint, fixture_path, "interrupt", debug_report_path],
      stderr_to_stdout: true
    )
  ...
  {output, exit_code} =
    System.cmd("node", [script_path, endpoint, fixture_path, "resume", debug_report_path],
      stderr_to_stdout: true
    )
  ...
end

defp merge_tus_report!(attrs) do
  attrs = Map.merge(read_tus_report!(), attrs)
  write_tus_report!(attrs)
end

defp merge_tus_debug_report!(attrs) do
  attrs = Map.merge(read_tus_debug_report!(), attrs)
  write_tus_debug_report!(attrs)
end
```

If Phase 46 needs a fix, keep it inside this harness shape: package build, generated-app boot, interrupted run, resumed run, persisted report/debug report/last-run hint.

---

### `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VERIFICATION.md` (test, request-response)

**Analog:** `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md`

**Frontmatter pattern** (`.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md:1-12`):
```yaml
---
phase: 44-auth-hardening-dx-docs-telemetry-ci-proof
verified: 2026-05-24T15:30:00Z
status: gaps_found
score: 4/5 success criteria verified
requirements_verified: [TUS-10, TUS-11, TUS-12, TUS-13, POLISH-02]
requirements_blocked: [TUS-14]
verification_method: inline (local phase-surface tests + generated-app tus package-consumer proof attempt)
follow_ups:
  - "Fix generated-app tus package-consumer proof so `bash scripts/install_smoke.sh tus` completes end-to-end without `ECONNRESET`."
---
```

**Objective evidence pattern** (`.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md:20-27`):
```md
## Objective Evidence

- `mix test ...` → **141 tests, 0 failures (10 excluded)**.
- `bash scripts/install_smoke.sh tus` is now executable in this repo after closing two harness defects:
  - `scripts/install_smoke.sh` now accepts the `tus` profile.
  - Generated-app router wiring now uses `Application.compile_env!/2` instead of `Endpoint.config/1` at router compile time.
- The generated-app proof still fails end-to-end: ...
```

**Success-criteria table pattern** (`.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md:28-54`):
```md
## Goal Achievement — ROADMAP Success Criteria

| # | Success Criterion | Status | Evidence |
|---|-------------------|--------|----------|
| ... |
| 5 | Generated-app package-consumer CI proof uploads a large MP4 with one simulated drop against MinIO and asserts a ready asset. | ✗ GAP | `bash scripts/install_smoke.sh tus` now runs the real generated-app lane, but ... |
```

Use this structure in Phase 46, but switch the narrative from stale `ECONNRESET` gap to either fresh green proof evidence or a precisely named remaining blocker tied to the saved JSON artifacts.

---

### `.planning/phases/46-generated-app-tus-runtime-proof-recovery/46-VALIDATION.md` (test, request-response)

**Analog:** `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VALIDATION.md`

**Validation frontmatter pattern** (`.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VALIDATION.md:1-9`):
```yaml
---
phase: 44
slug: auth-hardening-dx-docs-telemetry-ci-proof
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-23
validated: 2026-05-24
---
```

**Test infrastructure + sampling pattern** (`.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VALIDATION.md:17-35`):
```md
## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit on Elixir/Mix |
| **Quick run command** | `...` |
| **Generated-app tus proof** | `RINDLE_INSTALL_SMOKE_PROFILE=tus mix test ...` or `bash scripts/install_smoke.sh tus` |

## Sampling Rate

- **After every task commit:** Run ...
- **Before `$gsd-verify-work`:** `bash scripts/install_smoke.sh tus` must pass locally when feasible, or in CI as the merge-blocking package-consumer lane
```

**Reconciliation note + verification map pattern** (`.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VALIDATION.md:39-50`):
```md
> Reconciled against the current tree on 2026-05-24. The earlier `44-VERIFICATION.md` gap on `TUS-14` is now superseded by the passing generated-app tus smoke artifact in `tmp/install_smoke_tus_last_run.json`.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 44-03-01 | 03 | 3 | TUS-14 | V2/V3/V4 | Guide, generated-app helper, and package-consumer tus proof stay aligned for drop-and-resume | integration | `bash scripts/install_smoke.sh tus` | ✅ | ✅ green |
```

**Validation audit closeout pattern** (`.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VALIDATION.md:87-104`):
```md
## Validation Audit 2026-05-24

Retroactive State A audit reconciling the original draft contract against the current Phase 44 tree.
...
For `TUS-14`, the authoritative current evidence is the persisted generated-app proof artifact at `tmp/install_smoke_tus_last_run.json`, which records `failure_phase: "none"`, `previous_uploads: 1`, `byte_size: 210777744`, `content_type: "video/mp4"`, and `ready_variants: ["poster", "web_720p"]`.
```

Phase 46 should reuse this format and explicitly compare live rerun output with `tmp/install_smoke_tus_last_run.json`.

## Shared Patterns

### Generated-App Smoke Wrapper
**Sources:** `scripts/install_smoke.sh:19-63`, `scripts/public_smoke.sh:23-33`, `test/install_smoke/package_metadata_test.exs:120-137`

Apply to any shell changes in Phase 46:
```bash
export RINDLE_MINIO_RESET_BUCKET=1
bash "$SCRIPT_DIR/ensure_minio.sh"
mix test test/install_smoke/generated_app_smoke_test.exs --include minio
```

The wrapper owns profile validation, MinIO setup, and failure breadcrumb printing. The test file should stay focused on assertions.

### Persisted Tus Breadcrumbs
**Sources:** `test/install_smoke/support/generated_app_helper.ex:1177-1199`, `test/install_smoke/support/generated_app_helper.ex:2462-2527`, `scripts/install_smoke.sh:54-60`

Apply to helper or verification updates:
```elixir
hint_path = Path.join([repo_root(), "tmp", "install_smoke_tus_last_run.json"])
...
merge_tus_report!(%{endpoint: endpoint, report_path: ..., debug_report_path: ...})
...
merge_tus_debug_report!(%{resume_output: output})
```

Keep all three artifacts aligned:
- generated app `tmp/install_smoke_tus_report.json`
- generated app `tmp/install_smoke_tus_debug_report.json`
- repo `tmp/install_smoke_tus_last_run.json`

### Proof Assertions Stay End-to-End
**Sources:** `test/install_smoke/generated_app_smoke_test.exs:194-208`, `test/install_smoke/support/generated_app_helper.ex:2180-2270`

Apply to any harness/runtime fix:
```elixir
assert report.tus_previous_uploads >= 1
assert report.tus_byte_size >= 200 * 1024 * 1024
assert report.tus_content_type == "video/mp4"
assert report.tus_ready_variants == ["poster", "web_720p"]
```

```javascript
parallelUploads: 1,
retryDelays: null,
removeFingerprintOnSuccess: true,
storeFingerprintForResuming: true,
urlStorage: new tus.FileUrlStorage(urlStoragePath),
```

Do not weaken this into fake-only coverage, remove resume discovery, or stop asserting asset convergence.

### Verification Artifact Story
**Sources:** `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VERIFICATION.md:20-54`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-VALIDATION.md:39-50`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-04-SUMMARY.md:38-49`

Apply to Phase 46 docs:
```md
- name the exact command that ran: `bash scripts/install_smoke.sh tus`
- state whether the old Phase 44 `ECONNRESET` evidence is stale or reproduced
- point to `tmp/install_smoke_tus_last_run.json` plus generated-app report/debug paths
- keep verification sections machine-greppable (`TUS-14`, `install_smoke_tus_last_run`, `bash scripts/install_smoke.sh tus`)
```

If the planner creates a Phase 46 plan summary, copy the frontmatter + `## Accomplishments` + `## Verification` shape from `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-03-SUMMARY.md:1-46` or `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-04-SUMMARY.md:1-53`.

## No Analog Found

None.

## Metadata

**Analog search scope:** `scripts/`, `test/install_smoke/`, `test/install_smoke/support/`, `.planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/`, `.planning/phases/46-generated-app-tus-runtime-proof-recovery/`
**Files scanned:** 13
**Pattern extraction date:** 2026-05-24
