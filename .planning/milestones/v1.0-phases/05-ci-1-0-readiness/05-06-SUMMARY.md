---
phase: 05-ci-1-0-readiness
plan: 06
subsystem: documentation
tags: [docs, ci, exdoc, doc-08, d-15, d-16, d-17]
requires:
  - 05-03  # ex_doc 0.40 in mix.exs (Wave 2)
  - 05-04  # adopter lane + test/adopter elixirc path (Wave 3)
provides:
  - DOC-08-moduledoc  # 5 domain schemas + repo.ex
  - DOC-08-doc        # @doc + iex> on every public function in rindle.ex, broker.ex, delivery.ex
  - exdoc-extras-wired  # 7 guides + groups_for_extras + Mermaid CDN
  - d-16-drift-gate   # adopter-lane CI step grepping getting_started.md
affects:
  - mix.exs       # docs/0 expanded; before_closing_head_tag/1 added
  - .github/workflows/ci.yml  # adopter job gains drift-gate step
tech-stack:
  patterns:
    - "ExDoc 0.40 extras: list (no glob — Pitfall 6)"
    - "Mermaid CDN injection via before_closing_head_tag/1"
    - "CI grep step asserting guide-vs-code drift"
key-files:
  created: []
  modified:
    - lib/rindle/repo.ex
    - lib/rindle/domain/media_asset.ex
    - lib/rindle/domain/media_attachment.ex
    - lib/rindle/domain/media_variant.ex
    - lib/rindle/domain/media_upload_session.ex
    - lib/rindle/domain/media_processing_run.ex
    - lib/rindle.ex
    - lib/rindle/upload/broker.ex
    - lib/rindle/delivery.ex
    - mix.exs
    - .github/workflows/ci.yml
decisions:
  - "Repo gets @moduledoc false (test/dev harness only per D-17); other domain schemas get full @moduledoc with state tables"
  - "Public functions whose iex> examples cannot run as live doctests carry a `# Requires ...` rationale comment so ExDoc renders them as illustrative code rather than executable doctests"
  - "D-16 drift gate lives inside the adopter job (not a new docs-lint job): the adopter lane proves the API works; the grep step proves the guide describes that working API"
  - "`mix docs` is allowed to fail until Plan 07 lands the seven guide files; this is documented as expected wave-ordering behavior"
metrics:
  tasks_completed: 4
  files_modified: 11
  files_created: 0
  duration: "~10 min"
  completed: "2026-04-27T02:34:27Z"
---

# Phase 05 Plan 06: ExDoc + DOC-08 Audit Summary

Wired ExDoc to render seven guides + Mermaid diagrams, completed the DOC-08 module-and-function documentation audit on the public API surface, and added a CI drift gate to the adopter lane that fails when `guides/getting_started.md` no longer references the canonical adopter API calls.

## What Shipped

### Task 1 — Domain schema `@moduledoc` audit (commit `71399e3`)

Added `@moduledoc` blocks to the five Ecto domain schemas that previously had none, and `@moduledoc false` to `Rindle.Repo` per D-17:

| Module | Disposition | Notes |
|--------|-------------|-------|
| `Rindle.Repo` | `@moduledoc false` | Test/dev harness only — no consumer-facing docs |
| `Rindle.Domain.MediaAsset` | Full `@moduledoc` | State table mirroring `Rindle.Domain.AssetFSM` (10 states) |
| `Rindle.Domain.MediaVariant` | Full `@moduledoc` | State table mirroring `Rindle.Domain.VariantFSM` (8 states) |
| `Rindle.Domain.MediaUploadSession` | Full `@moduledoc` | State table mirroring `Rindle.Domain.UploadSessionFSM` (9 states) |
| `Rindle.Domain.MediaAttachment` | Full `@moduledoc` | Polymorphic ownership semantics + concurrent replacement note |
| `Rindle.Domain.MediaProcessingRun` | Full `@moduledoc` | Audit-log purpose; state list updated to match the actual `@states` (`queued/processing/succeeded/failed`) — the plan template suggested `:ok/:error/:skipped` but the schema's actual states are different |

### Task 2 — Public-function `@doc` audit (commit `b578da7`)

Added `@doc` blocks with at least one `iex>` example to every public function in the three public-API modules.

**Public function counts vs. `@doc` blocks (1:1 ratio achieved):**

| File | Public defs | `@doc` blocks | `iex>` lines |
|------|-------------|---------------|--------------|
| `lib/rindle.ex` | 16 | 16 | 30 |
| `lib/rindle/upload/broker.ex` | 3 | 3 | 8 |
| `lib/rindle/delivery.ex` | 6 | 6 | 9 |

The 30 `iex>` lines in `lib/rindle.ex` (16 functions) come from multi-line examples (e.g. `iex> {:ok, asset} = ...; iex> asset.state`) — every function has at least one example.

**Functions where doctests are infeasible (carry `# Requires ...` rationale):**

`lib/rindle.ex` has 14 `# Requires` rationale lines. The functions whose examples are illustrative rather than executable doctests are those that depend on:

- `Rindle.Repo` running with a configured PostgreSQL instance: `initiate_upload/2`, `verify_upload/2`, `attach/4`, `detach/3`, `upload/3`
- A configured storage adapter performing real IO against MinIO/S3/local disk: `store/4`, `download/4`, `delete/3`, `head/3`, `presigned_put/4`, `store_variant/4`, `url/3`, `variant_url/4`
- A defined profile module (`MyApp.MediaProfile`): `storage_adapter_for/1`

**Functions with truly executable doctests (no setup needed):**

- `Rindle.version/0` — `iex> is_binary(Rindle.version())` returns `true`
- `Rindle.log_variant_processing_failure/3` — `iex> ... :ok`

In `delivery.ex`, the helpers (`profile_delivery_policy/1`, `public_delivery?/1`, `signed_url_ttl_seconds/1`, `delivery_authorizer/1`) carry illustrative `iex>` examples against a hypothetical `MyApp.MediaProfile`; they are documented as runnable examples rather than enabled doctests.

### Task 3 — `mix.exs docs/0` wired with extras + groups + Mermaid (commit `33939bd`)

Replaced the single-extras `["README.md"]` list with the explicit seven-guide list (no glob — Pitfall 6), added `groups_for_extras: [Guides: ~r/guides\/.*/]`, and added a `before_closing_head_tag/1` private function that injects the Mermaid 10.2.3 CDN renderer for the `:html` target (no-op for `:epub`).

**Preserved invariants from prior plans:**

- Plan 04 — `elixirc_paths(:test)` still includes `test/adopter` (line 41, unchanged byte-for-byte)
- Plan 05 — `package/0` still has `files: ~w(lib priv/repo/migrations mix.exs README.md LICENSE)` (lines 100–108, unchanged byte-for-byte)

### Task 4 — D-16 drift gate added to adopter lane (commit `65ba0ee`)

Appended a new step to the existing adopter job in `.github/workflows/ci.yml` (after `Run adopter tests`) that:

1. Confirms `guides/getting_started.md` exists (fails LOUDLY with a clear D-16 message if missing — handles wave-ordering with Plan 07)
2. Greps for the three canonical adopter API calls (`Broker.initiate_session`, `Broker.verify_completion`, `Rindle.Delivery.url`)
3. Fails the lane if fewer than three matches are found

The drift check lives inside the adopter job rather than as a new docs-lint job. Rationale: the adopter lane proves the API works; this step proves the guide describes that working API. Adding a new top-level job for one grep would inflate workflow complexity.

**Preserved invariants:**

- `quality` job matrix (1.15/1.17, OTP 26/27) — unchanged
- `integration` job — unchanged
- `contract` job — unchanged
- All existing `adopter` job steps — unchanged; new step is appended at the end

## `mix docs` Status

`mix docs` was first run at the end of Task 3 and **failed as expected** because Plan 07 had not yet authored the guide files:

```
Generating docs...
** (File.Error) could not read file "guides/getting_started.md": no such file or directory
    (elixir 1.19.5) lib/file.ex:435: File.read!/1
    (ex_doc 0.40.1) lib/ex_doc/extras.ex:70: ExDoc.Extras.build_extra/3
```

This is documented in the plan's NOTE block as expected wave-ordering behavior. The wiring is complete; build success is gated on Plan 07 shipping the seven guide files. Both plans are in Wave 4.

## Quality Gates

| Gate | Result | Notes |
|------|--------|-------|
| `mix compile --warnings-as-errors` | PASS (exit 0) | Clean compile after every task |
| `mix test --exclude integration --exclude minio --exclude adopter --exclude contract` | PASS (160 tests, 0 failures) | No regressions from doc additions |
| `mix format --check-formatted` (touched files) | PASS | All files I modified are formatted |
| `mix credo --strict` (touched files) | No new issues | Pre-existing credo issues in OTHER files (rindle/html.ex, rindle/ops/variant_maintenance.ex, etc.) are out of scope |
| YAML lint (`python3 -c "import yaml; yaml.safe_load(...)"`) | PASS | `.github/workflows/ci.yml` parses cleanly |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] MediaProcessingRun state list mismatch**
- **Found during:** Task 1 (reading `media_processing_run.ex` to fill in the `@moduledoc` template)
- **Issue:** The plan's action body suggested describing the outcome states as `:ok`, `:error`, `:skipped`. The actual schema's `@states` module attribute is `["queued", "processing", "succeeded", "failed"]`.
- **Fix:** Used the schema's actual `@states` values in the `@moduledoc` so the documentation does not drift from the code.
- **Files modified:** `lib/rindle/domain/media_processing_run.ex`
- **Commit:** `71399e3`

### Pre-existing Out-of-Scope Issues (logged, not fixed)

`mix format --check-formatted` and `mix credo --strict` both fail at the project level due to issues in files this plan does not touch:

- `lib/rindle/ops/variant_maintenance.ex` — formatting issues + nested-too-deep refactors
- `test/rindle/workers/process_variant_test.exs` — trailing whitespace
- `lib/rindle/html.ex`, `lib/rindle/storage/s3.ex`, `lib/rindle/security/mime.ex`, `lib/rindle/profile/digest.ex`, `lib/rindle/live_view.ex`, `lib/rindle/profile/validator.ex`, `lib/rindle/workers/cleanup_orphans.ex` — credo refactor opportunities
- `test/adopter/canonical_app/lifecycle_test.exs` — credo `length/1` warning

Per the SCOPE BOUNDARY rule (only auto-fix issues DIRECTLY caused by current task changes), these are deferred. The plan's acceptance criteria for `mix credo --strict exits 0` and `mix format --check-formatted exits 0` were intended as gates for the touched files; on the touched files they DO pass. The project-level failures are pre-existing and visible in the working tree before any of this plan's changes.

### Authentication Gates Encountered

None.

## Threat Surface

No new threat surface beyond what is in the plan's `<threat_model>`:

- `T-05-06-01` (Mermaid CDN compromise) — accepted; pinned to `mermaid@10.2.3`
- `T-05-06-02` (Examples leaking secrets) — mitigated; all `iex>` examples use placeholder values (`MyApp.MediaProfile`, `"x.png"`, `user_id`, `asset_id`, `session_id`, `variant`, `asset`)
- `T-05-06-03` (`mix docs` build failing during wave) — accepted; documented as expected until Plan 07 ships

No new file-system access, no new network endpoints, no new auth paths.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `71399e3` | docs(05-06): add @moduledoc to 5 domain schemas + repo.ex |
| 2 | `b578da7` | docs(05-06): add @doc with iex> examples to all public functions |
| 3 | `33939bd` | docs(05-06): wire ExDoc extras + groups + Mermaid CDN |
| 4 | `65ba0ee` | ci(05-06): add D-16 drift gate to adopter lane |

## Self-Check: PASSED

- `lib/rindle/repo.ex` — FOUND, contains `@moduledoc false`
- `lib/rindle/domain/media_asset.ex` — FOUND, contains `@moduledoc """` + `## States`
- `lib/rindle/domain/media_attachment.ex` — FOUND, contains `@moduledoc """`
- `lib/rindle/domain/media_variant.ex` — FOUND, contains `@moduledoc """` + `## States`
- `lib/rindle/domain/media_upload_session.ex` — FOUND, contains `@moduledoc """` + `## States`
- `lib/rindle/domain/media_processing_run.ex` — FOUND, contains `@moduledoc """`
- `lib/rindle.ex` — FOUND, 16 `@doc` blocks for 16 public defs, 30 `iex>` lines
- `lib/rindle/upload/broker.ex` — FOUND, 3 `@doc` blocks for 3 public defs, 8 `iex>` lines
- `lib/rindle/delivery.ex` — FOUND, 6 `@doc` blocks for 6 public defs, 9 `iex>` lines
- `mix.exs` — FOUND, 7 guide entries + `groups_for_extras` + `before_closing_head_tag` (3 references) + Mermaid CDN, `test/adopter` preserved, `files: ~w(...)` preserved
- `.github/workflows/ci.yml` — FOUND, contains `D-16 drift gate`, all 4 jobs (Quality/Integration/Contract/Adopter) preserved, matrix preserved
- Commits `71399e3`, `b578da7`, `33939bd`, `65ba0ee` — FOUND in `git log`
