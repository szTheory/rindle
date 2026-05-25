# Phase 50: Phoenix Proof + Parity Closure - Research

**Researched:** 2026-05-25
**Domain:** Phoenix LiveView external uploads proof closure for the shipped tus seam
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Package-consumer proof shape
- **D-01:** Extend the existing generated-app `:tus` install-smoke lane into
  the canonical Phoenix / LiveView proof instead of creating a second
  Phoenix-specific proof lane or relying only on in-repo helper tests.
- **D-02:** Keep the current lower-level bare `TusPlug` drop-and-resume proof as
  a sub-proof underneath the Phoenix-facing proof rather than replacing it.
  Phase 50 adds the missing LiveView/helper layer on top of the existing
  transport/runtime proof.
- **D-03:** The merge-blocking package-consumer proof for this phase must
  exercise the documented adopter path itself:
  `allow_tus_upload/4` -> `uploader: "RindleTus"` -> honest upload-state
  progression -> `consume_uploaded_entries/3` -> `verify_completion/2`.

### Parity gate scope
- **D-04:** Freeze parity at the narrow-contract layer of guide + helper +
  executable proof harness/report, not docs-only parity and not broad
  generated-source snapshot parity.
- **D-05:** Keep fast local parity/unit assertions for support truth and helper
  metadata, then extend the existing generated-app tus proof/report assertions
  so drift between the guide, helper contract, and proof harness fails fast.
- **D-06:** Do not introduce whole generated-app template snapshots or other
  high-churn parity gates. They are the wrong abstraction level for this repo
  and would raise maintenance noise without increasing trust in the Phoenix tus
  contract.

### Public contract and UX semantics under proof
- **D-07:** The proof and parity surface must freeze the exact narrow Phoenix
  contract already documented in Phase 49:
  required `:path` and `:secret_key_base`, optional `:actor`, adopter-owned
  router/auth/parser/CORS wiring, canonical `RindleTus` uploader behavior, and
  completion through `consume_uploaded_entries/3` / `verify_completion/2`.
- **D-08:** Proof artifacts must preserve the honest public state split:
  `uploading` while bytes move, `verifying` after transport reaches `100%`,
  `ready` only after server completion succeeds, and `error` for transport or
  verification failure. `100%` means bytes transferred, not asset readiness.
- **D-09:** Package-consumer proof artifacts should remain machine-readable and
  be extended with Phoenix-facing evidence rather than becoming prose-only test
  output. Auditability matters more than clever test structure.

### Ecosystem posture and architecture fit
- **D-10:** Keep the Phoenix-facing layer idiomatic and thin. The supported seam
  should remain a small wrapper over LiveView’s `:external` upload model rather
  than growing into a second framework-level uploader abstraction.
- **D-11:** Favor explicit, concurrency-safe, proof-friendly contracts over
  convenience breadth. In practice this means proving the existing seam,
  keeping lifecycle completion explicit, and extending artifact-backed proof
  rather than inventing new abstraction layers in Phase 50.
- **D-12:** Preserve the repo’s layered proof posture:
  local hermetic contract tests for helper semantics,
  local parity tests for documentation/support truth,
  and heavier generated-app package-consumer proof for end-to-end adopter
  reality.

### Shift-left recommendation posture
- **D-13:** Phase 50 should return one coherent proof recommendation set by
  default and proceed with it. Local proof-harness structure, naming,
  assertion granularity, and wording details are agent-decided and recorded,
  not escalated.
- **D-14:** Alternatives may be recorded for rationale only. Escalate only for
  high-blast-radius changes such as semver-significant public API reshapes,
  security-boundary changes, destructive behavior changes, major recurring-cost
  surprises, or milestone/scope expansion.

### Claude's Discretion
- Exact proof-report field names and assertion placement, as long as D-01
  through D-09 remain true.
- Exact split between low-cost parity tests and heavier generated-app proof,
  as long as the package-consumer Phoenix path remains merge-blocking and
  auditable.
- Exact wording of user-facing status labels and proof summaries, as long as
  the `uploading` / `verifying` / `ready` / `error` contract stays honest.

### Deferred Ideas (OUT OF SCOPE)
- Separate Phoenix-specific generated-app proof lane distinct from the existing
  `:tus` lane.
- Broad generated-app source snapshot parity.
- Reusable uploader UI/component abstractions beyond the current helper seam.
- Rindle-owned standalone tus JS client package.
- Broader provider-agnostic Phoenix upload abstractions and new tus protocol
  extensions.

### Reviewed Todos (not folded)
None — `todo.match-phase` returned no Phase 50 matches.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PROOF-01 | Package-consumer or generated-app proof exercises the documented Phoenix/LiveView tus path end to end, not only a headless tus client against the mounted plug. `[VERIFIED: .planning/REQUIREMENTS.md]` | Extend the existing generated-app `:tus` lane so it preflights a real LiveView upload through `allow_tus_upload/4`, runs the real Node `tus-js-client` transport using that metadata, then submits the LiveView form through `consume_uploaded_entries/3` and `verify_completion/2`. `[VERIFIED: codebase grep][CITED: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/client/external-uploads.md][CITED: https://github.com/tus/tus-js-client/blob/main/docs/api.md]` |
| PROOF-02 | Docs parity tests freeze the supported LiveView tus contract so drift between guide, helper metadata, and proof harness fails fast. `[VERIFIED: .planning/REQUIREMENTS.md]` | Keep fast parity in `test/install_smoke/phoenix_tus_truth_parity_test.exs`, extend generated-app report assertions, and freeze only guide text, helper metadata, and machine-readable proof fields instead of snapshotting the whole generated app. `[VERIFIED: codebase grep]` |
</phase_requirements>

## Summary

The current package-consumer `:tus` proof already boots a generated Phoenix app, mounts `Rindle.Upload.TusPlug`, drives a real `tus-js-client` interrupt/resume upload, and proves downstream asset promotion and variant convergence. It does **not** call `Rindle.LiveView.allow_tus_upload/4`, does **not** obtain metadata through LiveView’s `:external` upload preflight, and does **not** finish through a LiveView submit path that invokes `consume_uploaded_entries/3`. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex][VERIFIED: test/install_smoke/generated_app_smoke_test.exs]`

Phoenix LiveView’s external-upload contract is already the right seam for this closure: `allow_upload/3` accepts a 2-arity `:external` function that returns `{:ok, meta, socket}`, the client uploader is chosen by `meta.uploader`, and `consume_uploaded_entries/3` remains the submit-time completion boundary. LiveView’s own test helpers also expose `preflight_upload/1` specifically to retrieve external-upload metadata, which makes a package-consumer proof possible without adding browser automation. `[CITED: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/client/external-uploads.md][VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/test/live_view_test.ex][VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/upload_config.ex]`

The narrowest closure is therefore to keep one generated-app `:tus` lane, add a tiny generated LiveView proof page/module, reuse the existing Node `tus-js-client` harness for the real upload transport, and submit through the generated LiveView to hit `Rindle.LiveView.consume_uploaded_entries/3` and `Rindle.verify_completion/2`. This is an inference from the verified repo and framework APIs, not a separately documented Rindle pattern. `[VERIFIED: codebase grep][CITED: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/client/external-uploads.md][CITED: https://github.com/tus/tus-js-client/blob/main/docs/api.md]`

**Primary recommendation:** Extend the existing generated-app `:tus` install-smoke lane with a minimal LiveView preflight-and-submit wrapper around the current Node tus proof, then freeze guide/helper/report alignment with fast parity assertions and machine-readable report fields. `[VERIFIED: codebase grep]`

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Upload metadata minting via `allow_tus_upload/4` | Frontend Server | API / Backend | The helper runs inside LiveView on the server, but it delegates session creation and signed URL generation to Rindle’s backend surfaces. `[VERIFIED: lib/rindle/live_view.ex]` |
| Resumable byte transport over tus | Browser / Client | API / Backend | `tus-js-client` owns `findPreviousUploads`, `resumeFromPreviousUpload`, `HEAD`, and `PATCH`; `TusPlug` owns upload creation and offset truth. `[CITED: https://github.com/tus/tus-js-client/blob/main/docs/api.md][VERIFIED: test/install_smoke/support/generated_app_helper.ex]` |
| Completion through `consume_uploaded_entries/3` | Frontend Server | API / Backend | The LiveView submit event calls the helper, which in turn invokes `Rindle.verify_completion/2`. `[VERIFIED: lib/rindle/live_view.ex]` |
| Session and asset verification | API / Backend | Database / Storage | `verify_completion/2` checks persisted session state and storage object state before marking completion. `[VERIFIED: lib/rindle/live_view.ex][VERIFIED: lib/rindle.ex]` |
| Proof artifact emission | Test Harness | Filesystem | The generated-app helper already writes JSON reports under `tmp/`; Phase 50 should extend that surface rather than invent a second report mechanism. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex]` |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix LiveView | `1.1.28` in this repo; official docs currently show `v1.1.30`. `[VERIFIED: mix.lock][CITED: https://hexdocs.pm/phoenix_live_view/uploads.html]` | Provides the external-upload contract, `allow_upload/3`, `consume_uploaded_entries/3`, and LiveView test helpers. `[CITED: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/client/external-uploads.md][VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/test/live_view_test.ex]` | Use the framework’s built-in upload and test surfaces instead of layering a browser E2E harness on top. `[VERIFIED: codebase grep]` |
| Phoenix | `1.8.5` in this repo. `[VERIFIED: mix.lock]` | Owns the generated app, router, endpoint, and LiveView route mounting used by install smoke. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex]` | The generated-app proof already targets Phoenix consumers, so the proof should stay inside that adopter shape. `[VERIFIED: codebase grep]` |
| `tus-js-client` | `4.3.1`, published `2025-01-16`. `[VERIFIED: npm registry]` | Performs real tus upload creation/resume discovery/progress/resume in the proof harness. `[CITED: https://github.com/tus/tus-js-client/blob/main/docs/api.md]` | The repo already uses it in the Node proof harness; reusing it preserves transport realism and avoids widening product surface. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex]` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Phoenix.LiveViewTest` | Bundled with Phoenix LiveView `1.1.28`. `[VERIFIED: mix.lock][VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/test/live_view_test.ex]` | `live/2`, `file_input/4`, `preflight_upload/1`, `render_upload/3`, and `render_submit/2` make the generated LiveView proof executable without browser automation. `[VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/test/live_view_test.ex]` | Use for the server-side part of the Phoenix proof: metadata preflight, progress acks, and submit. `[VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/test/live_view_test.ex]` |
| Existing generated-app helper | Repo-local test support. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex]` | Generates the Phoenix app, patches runtime/router, runs the Node harness, and writes machine-readable JSON reports. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex]` | Extend for Phase 50 instead of creating a second proof runner. `[VERIFIED: codebase grep]` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| LiveViewTest + existing Node harness | Playwright/Wallaby/browser automation | Higher cost, new runtime dependency, and broader UI surface than the locked proof needs. This is a recommendation derived from verified existing capabilities. `[VERIFIED: codebase grep][ASSUMED]` |
| Extending the current `:tus` lane | A second Phoenix-specific install-smoke lane | Violates the locked single-lane decision and duplicates the existing runtime proof posture. `[VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-CONTEXT.md]` |
| Narrow guide/helper/report parity | Generated-app file snapshots | High churn and low signal for the actual Phoenix tus contract. `[VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-CONTEXT.md]` |

**Installation:**
```bash
# No new root dependency is required for the repo.
# Manual repro of the Node harness still uses the current npm package:
npm install tus-js-client@4.3.1
```

**Version verification:** `tus-js-client@4.3.1` is the current stable npm release in this session and was published on `2025-01-16`. `[VERIFIED: npm registry]` The repo itself is pinned to `phoenix_live_view 1.1.28` and `phoenix 1.8.5` in `mix.lock`. `[VERIFIED: mix.lock]`

## Architecture Patterns

### System Architecture Diagram

```text
Phoenix.LiveViewTest.live/2
  -> generated proof LiveView route
  -> file_input/4 + preflight_upload/1
  -> Rindle.LiveView.allow_tus_upload/4
  -> Rindle.initiate_tus_upload/2
  -> signed meta: %{uploader, endpoint, upload_url, session_id, asset_id}
  -> existing Node tus-js-client harness
  -> POST/HEAD/PATCH against TusPlug
  -> real bytes stored in MinIO/S3-compatible backend
  -> render_upload(..., progress) / render_submit(...)
  -> Rindle.LiveView.consume_uploaded_entries/3
  -> Rindle.verify_completion/2
  -> PromoteAsset / ProcessVariant
  -> machine-readable tus report + parity assertions
```

### Recommended Project Structure
```text
test/install_smoke/
├── generated_app_smoke_test.exs        # top-level assertions for the package-consumer lane
├── phoenix_tus_truth_parity_test.exs   # fast contract/parity assertions
└── support/generated_app_helper.ex     # generated app patching, LiveView proof view, Node harness, JSON report
guides/
└── resumable_uploads.md                # canonical adopter guide frozen by parity
lib/rindle/
└── live_view.ex                        # shipped helper contract already under proof
```

### Pattern 1: Generated LiveView Preflight + Real tus Transport
**What:** Mount a minimal generated LiveView page that uses `Rindle.LiveView.allow_tus_upload/4`, preflight it with `Phoenix.LiveViewTest.preflight_upload/1`, then feed the returned `endpoint` and `upload_url` into the existing Node `tus-js-client` harness before submitting the form through LiveView. `[VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/test/live_view_test.ex][VERIFIED: lib/rindle/live_view.ex][VERIFIED: test/install_smoke/support/generated_app_helper.ex]`

**When to use:** Use this for the merge-blocking package-consumer proof because it closes the missing Phoenix seam without adding a second proof lane or a browser automation stack. `[VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-CONTEXT.md][VERIFIED: codebase grep]`

**Example:**
```elixir
# Source: Phoenix.LiveViewTest + Rindle.LiveView APIs
{:ok, view, _html} = live(conn, "/rindle-smoke/tus")

upload =
  file_input(view, "#tus-form", :video, [
    %{name: "clip.mp4", content: File.read!(fixture_path), type: "video/mp4"}
  ])

{:ok, %{entries: entries}} = preflight_upload(upload)
entry = List.first(entries)

# Inference: hand entry metadata to the existing Node proof harness
proof = run_tus_node_proof!(script_path, entry["meta"]["endpoint"], fixture_path)

assert proof["failure_phase"] in [nil, "none"]
assert render_upload(upload, "clip.mp4", 100)
assert render_submit(form(view, "#tus-form"))
```

### Pattern 2: Report the Phoenix Contract, Not Just Raw tus Transport
**What:** Extend `install_smoke_tus_report.json` so it records LiveView-preflight metadata, proof-shape identity, submit/completion evidence, and honest state semantics alongside the existing transport facts. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex][ASSUMED]`

**When to use:** Use this for auditability and parity freezing. The phase context explicitly prefers machine-readable proof artifacts over prose-only evidence. `[VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-CONTEXT.md]`

**Example:**
```json
{
  "proof_shape": "phoenix_live_view_tus",
  "uploader": "RindleTus",
  "endpoint": "/uploads/tus",
  "upload_url": "/uploads/tus/...",
  "session_id": "...",
  "asset_id": "...",
  "status_sequence": ["uploading", "verifying", "ready"],
  "completion_surface": "Rindle.LiveView.consume_uploaded_entries/3",
  "verification_surface": "Rindle.verify_completion/2"
}
```

### Anti-Patterns to Avoid
- **Bypassing LiveView in the package-consumer proof:** The current direct `TusPlug` proof is necessary but insufficient for `PROOF-01`. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex][VERIFIED: .planning/REQUIREMENTS.md]`
- **Adding a browser automation stack just to click a form:** LiveViewTest already exposes `preflight_upload/1` for external upload metadata and `render_submit/2` for submit-time behavior. `[VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/test/live_view_test.ex]`
- **Calling `Rindle.verify_completion/2` directly in the Phoenix proof instead of submitting through `consume_uploaded_entries/3`:** That would re-prove the old lifecycle and skip the documented adopter seam. `[VERIFIED: guides/resumable_uploads.md][VERIFIED: lib/rindle/live_view.ex]`
- **Snapshotting the generated app source tree:** The locked parity scope is guide + helper + executable report, not broad template snapshots. `[VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-CONTEXT.md]`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| External-upload metadata extraction | Custom socket or channel probes | `Phoenix.LiveViewTest.preflight_upload/1` | The framework already exposes a helper specifically for testing external uploaders. `[VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/test/live_view_test.ex]` |
| Resumable transport proof | A new JS uploader or fake offset simulator | Existing `tus-js-client` Node harness | The repo already proves real POST/HEAD/PATCH behavior and writes debug artifacts. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex]` |
| End-to-end Phoenix proof | A second install-smoke matrix lane | Extend the existing `:tus` lane | This matches the locked phase decision and keeps one proof authority. `[VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-CONTEXT.md]` |
| Drift detection | Generated-app snapshots | Targeted parity assertions over guide/helper/report fields | Lower churn and higher signal for the actual support claim. `[VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-CONTEXT.md]` |

**Key insight:** The repo already has the expensive pieces: a generated Phoenix app, a real `tus-js-client` harness, and machine-readable reports. Phase 50 should add the missing LiveView seam on top of those pieces, not rebuild the transport proof from scratch. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex]`

## Common Pitfalls

### Pitfall 1: Re-proving `TusPlug` instead of the Phoenix seam
**What goes wrong:** The proof stays green while `allow_tus_upload/4` or the LiveView completion path drifts, because the harness still creates uploads by hitting `/uploads/tus` directly. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex]`
**Why it happens:** The current test starts the Node uploader at `"http://127.0.0.1:<port>/uploads/tus"` and then queries the DB directly. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex]`
**How to avoid:** Force metadata creation through LiveView preflight first, then feed that metadata into the Node harness. `[VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/test/live_view_test.ex][VERIFIED: lib/rindle/live_view.ex]`
**Warning signs:** The report contains `upload_url` and variants, but no `uploader`, `session_id`, `asset_id`, or completion-surface evidence. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex][ASSUMED]`

### Pitfall 2: Treating `100%` as `ready`
**What goes wrong:** The proof collapses `uploading` and `ready`, which contradicts the guide’s documented `uploading` -> `verifying` -> `ready` split. `[VERIFIED: guides/resumable_uploads.md]`
**Why it happens:** `tus-js-client` progress reaches `100%` when bytes finish transferring, but server verification still happens later. `[VERIFIED: guides/resumable_uploads.md][CITED: https://github.com/tus/tus-js-client/blob/main/docs/api.md]`
**How to avoid:** Record a status sequence in the proof artifact and assert `ready` only after the submit/verify step succeeds. This is a recommendation derived from the guide and current artifact posture. `[VERIFIED: guides/resumable_uploads.md][VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-CONTEXT.md][ASSUMED]`
**Warning signs:** A proof artifact or rendered status says `ready` immediately after the Node upload completes. `[ASSUMED]`

### Pitfall 3: Skipping `consume_uploaded_entries/3`
**What goes wrong:** The proof calls `Rindle.verify_completion/2` directly after the Node upload and never proves the documented LiveView submit seam. `[VERIFIED: lib/rindle/live_view.ex][VERIFIED: guides/resumable_uploads.md]`
**Why it happens:** Direct verification is simpler because the current tus lane already uses it implicitly through DB lookup and worker assertions. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex]`
**How to avoid:** Add a generated LiveView submit handler and require the proof report to record that the completion surface was `Rindle.LiveView.consume_uploaded_entries/3`. `[VERIFIED: lib/rindle/live_view.ex][ASSUMED]`
**Warning signs:** The test never calls `render_submit/2` or equivalent submit-time event. `[VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/test/live_view_test.ex][ASSUMED]`

### Pitfall 4: Local false negatives from missing MinIO
**What goes wrong:** The proof design is correct, but local reruns fail because the S3-compatible backend is not available. `[VERIFIED: scripts/install_smoke.sh][VERIFIED: local environment probe]`
**Why it happens:** The `:tus` smoke lane is tagged `:minio` and the local probe in this session shows Postgres ready but MinIO not currently listening on port `9000`. `[VERIFIED: test/install_smoke/generated_app_smoke_test.exs][VERIFIED: local environment probe]`
**How to avoid:** Keep using `scripts/install_smoke.sh tus` or `ensure_minio.sh` as the canonical local entrypoint. `[VERIFIED: scripts/install_smoke.sh]`
**Warning signs:** `curl http://localhost:9000/minio/health/ready` fails before the smoke run starts. `[VERIFIED: local environment probe]`

## Code Examples

Verified patterns from official sources:

### LiveView External Upload Metadata
```elixir
# Source: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/client/external-uploads.md
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:uploaded_files, [])
   |> allow_upload(:avatar, accept: :any, max_entries: 3, external: &presign_upload/2)}
end
```

### LiveView Test Preflight For External Uploaders
```elixir
# Source: deps/phoenix_live_view/lib/phoenix_live_view/test/live_view_test.ex
avatar = file_input(lv, "#my-form-id", :avatar, [%{name: "myfile.jpeg", content: "...", type: "image/jpeg"}])
assert {:ok, %{ref: _ref, config: %{chunk_size: _}}} = preflight_upload(avatar)
```

### `tus-js-client` Resume Contract
```javascript
// Source: https://github.com/tus/tus-js-client/blob/main/docs/api.md
const previousUploads = await upload.findPreviousUploads()
if (previousUploads.length > 0) {
  upload.resumeFromPreviousUpload(previousUploads[0])
}
upload.start()
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Generated-app `:tus` proof starts the client directly at `/uploads/tus` and proves raw transport/runtime. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex]` | Phase 50 should layer the documented LiveView metadata + submit seam on top of that existing transport proof. This is a recommendation derived from the current repo and locked phase scope. `[VERIFIED: .planning/phases/50-phoenix-proof-parity-closure/50-CONTEXT.md][ASSUMED]` | The gap was identified in v1.9 planning on `2026-05-25`. `[VERIFIED: .planning/ROADMAP.md][VERIFIED: .planning/REQUIREMENTS.md]` | Support truth becomes auditable from guide + tests + proof report without reading source history. `[VERIFIED: .planning/ROADMAP.md]` |
| Docs parity currently freezes guide wording and support-truth surfaces. `[VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs]` | Phase 50 should extend parity to include machine-readable proof-harness fields that describe the Phoenix proof shape. This is a recommendation, not an existing fact. `[VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs][ASSUMED]` | Phase 50. `[VERIFIED: .planning/ROADMAP.md]` | Drift will fail fast at the contract layer instead of after a support claim regresses. `[VERIFIED: .planning/REQUIREMENTS.md][ASSUMED]` |

**Deprecated/outdated:**
- Treating the direct `/uploads/tus` package-consumer proof as sufficient evidence for the Phoenix support claim is outdated for Phase 50 because `PROOF-01` now requires the documented LiveView path itself. `[VERIFIED: .planning/REQUIREMENTS.md][VERIFIED: test/install_smoke/support/generated_app_helper.ex]`

## Assumptions Log

> List all claims tagged `[ASSUMED]` in this research. The planner and discuss-phase use this
> section to identify decisions that need user confirmation before execution.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | LiveViewTest plus the existing Node harness is the narrowest executable proof shape and will be easier to keep green than browser automation. | Standard Stack / Architecture Patterns | Plan may underestimate implementation friction if LiveView submit semantics are trickier than expected. |
| A2 | The proof artifact should grow fields such as `proof_shape`, `status_sequence`, and `completion_surface`. | Architecture Patterns | Planner may choose field names or placement that conflict with existing report consumers. |
| A3 | A generated proof view should explicitly record or expose `uploading` -> `verifying` -> `ready` so the report can freeze honest progress semantics. | Common Pitfalls / Validation | Planner may need a different assertion strategy if a purely rendered-state approach is brittle. |
| A4 | The combined flow `preflight_upload` -> real Node upload -> `render_upload`/`render_submit` is the best way to bridge LiveView state with the existing real transport proof. | Architecture Patterns / Open Questions | Planner may need a small spike if `render_upload` and the real upload interact differently than expected. |

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Root tests and generated-app smoke | ✓ `[VERIFIED: local environment probe]` | `1.19.5` `[VERIFIED: local environment probe]` | — |
| Mix | Root tests and generated-app generation | ✓ `[VERIFIED: local environment probe]` | `1.19.5` `[VERIFIED: local environment probe]` | — |
| Node.js | Existing Node `tus-js-client` proof harness | ✓ `[VERIFIED: local environment probe]` | `22.14.0` `[VERIFIED: local environment probe]` | — |
| npm | `tus-js-client` install in the proof workspace | ✓ `[VERIFIED: local environment probe]` | `11.1.0` `[VERIFIED: local environment probe]` | — |
| PostgreSQL | Generated Phoenix app repo and smoke DB | ✓ `[VERIFIED: local environment probe]` | `14.17` client, local server ready. `[VERIFIED: local environment probe]` | — |
| Docker | Local MinIO startup path | ✓ `[VERIFIED: local environment probe]` | `29.4.1` `[VERIFIED: local environment probe]` | Use `scripts/ensure_minio.sh` through the existing smoke script. `[VERIFIED: scripts/install_smoke.sh]` |
| FFmpeg | Video/tus fixture generation and variant processing | ✓ `[VERIFIED: local environment probe]` | `8.0.1` `[VERIFIED: local environment probe]` | — |
| MinIO service on `localhost:9000` | Local `:tus` smoke reruns | ✗ in this session. `[VERIFIED: local environment probe]` | — | Start it through the existing smoke script; CI already does equivalent setup. `[VERIFIED: scripts/install_smoke.sh][VERIFIED: .github/workflows/ci.yml]` |

**Missing dependencies with no fallback:**
- None identified. `[VERIFIED: local environment probe]`

**Missing dependencies with fallback:**
- MinIO is not currently running locally, but the repo’s existing smoke script and CI already provision that dependency. `[VERIFIED: scripts/install_smoke.sh][VERIFIED: .github/workflows/ci.yml]`

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit with Phoenix LiveViewTest and install-smoke helpers. `[VERIFIED: test/install_smoke/generated_app_smoke_test.exs][VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/test/live_view_test.ex]` |
| Config file | `test/test_helper.exs` plus generated-app helper wiring. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex]` |
| Quick run command | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs` `[VERIFIED: codebase grep][ASSUMED]` |
| Full suite command | `bash scripts/install_smoke.sh tus` `[VERIFIED: scripts/install_smoke.sh]` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PROOF-01 | Generated-app proof preflights `allow_tus_upload/4`, uses `uploader: "RindleTus"` metadata, performs real resumable transport, and completes through LiveView submit/verification. `[VERIFIED: .planning/REQUIREMENTS.md]` | install-smoke | `bash scripts/install_smoke.sh tus` `[VERIFIED: scripts/install_smoke.sh]` | ✅ existing lane to extend in `test/install_smoke/generated_app_smoke_test.exs` and `support/generated_app_helper.ex`. `[VERIFIED: codebase grep]` |
| PROOF-02 | Guide, helper metadata, and proof report fields fail fast on drift. `[VERIFIED: .planning/REQUIREMENTS.md]` | parity + unit | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs` `[ASSUMED]` | ✅ existing parity/unit files to extend. `[VERIFIED: codebase grep]` |

### Sampling Rate
- **Per task commit:** `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs test/rindle/live_view_test.exs` `[ASSUMED]`
- **Per wave merge:** `bash scripts/install_smoke.sh tus` `[VERIFIED: scripts/install_smoke.sh]`
- **Phase gate:** Full `:tus` install-smoke green with new Phoenix fields present in the JSON report. `[VERIFIED: .planning/REQUIREMENTS.md][ASSUMED]`

### Wave 0 Gaps
- [ ] Add generated-app proof view/route wiring inside `test/install_smoke/support/generated_app_helper.ex` so the package-consumer lane can mount a real LiveView adopter path. `[VERIFIED: codebase grep][ASSUMED]`
- [ ] Extend `install_smoke_tus_report.json` emission with Phoenix-facing contract fields and honest state evidence. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex][ASSUMED]`
- [ ] Extend `test/install_smoke/phoenix_tus_truth_parity_test.exs` so it freezes helper metadata keys and expected proof-report keys, not only guide wording. `[VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs][ASSUMED]`

## Open Questions (RESOLVED)

### How should the generated proof synchronize LiveView upload state with the real Node tus upload?

**Resolution:** Use the generated Phoenix app's LiveView upload surface to
obtain real external-upload metadata first, then hand that metadata to the
existing Node `tus-js-client` proof harness, then submit back through LiveView
to exercise the completion lane.

**Chosen mechanism:**
- Mount a tiny generated LiveView proof page that calls
  `Rindle.LiveView.allow_tus_upload/4`.
- In the generated app test, use `Phoenix.LiveViewTest.file_input/4` plus
  `Phoenix.LiveViewTest.preflight_upload/1` to obtain the real
  `uploader: "RindleTus"` metadata (`endpoint`, `upload_url`, `session_id`,
  `asset_id`) emitted by `allow_tus_upload/4`.
- Pass `entry.meta.endpoint` and `entry.meta.upload_url` into the existing Node
  `tus-js-client` harness so the actual resumable upload still runs through the
  real browser-style client and the mounted `TusPlug`.
- After the Node proof completes, submit the LiveView form with
  `Phoenix.LiveViewTest.render_submit/2` so the generated app executes
  `consume_uploaded_entries/3` and reaches `verify_completion/2`.
- Persist both the preflight metadata and the post-submit completion evidence
  into the existing machine-readable tus report instead of creating a second
  proof artifact.

**Why this resolves the ambiguity:**
- It proves the documented Phoenix seam starts at `allow_tus_upload/4`, not at
  a fabricated raw tus URL.
- It preserves the existing real Node `tus-js-client` / drop-and-resume proof
  instead of replacing it with a repo-local fake uploader.
- It gives one clean handoff point between LiveView and the Node harness:
  `preflight_upload/1` supplies the canonical metadata, and
  `render_submit/2` supplies the canonical completion lane.

**Planning consequence:** Phase 50 does not need a prerequisite spike plan.
The implementation should directly use `preflight_upload/1` ->
Node `tus-js-client` upload -> `render_submit/2` as the canonical proof flow.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes. `[VERIFIED: guides/resumable_uploads.md]` | The guide requires mounting `TusPlug` behind adopter-owned auth; the proof should keep that contract explicit rather than bypassing it. `[VERIFIED: guides/resumable_uploads.md]` |
| V3 Session Management | no first-class browser session work in this phase. `[VERIFIED: .planning/REQUIREMENTS.md]` | Existing app/session handling remains adopter-owned. `[VERIFIED: guides/resumable_uploads.md]` |
| V4 Access Control | yes. `[VERIFIED: guides/resumable_uploads.md][VERIFIED: lib/rindle/live_view.ex]` | Signed bearer `upload_url` plus optional actor embedding / resume authorization remain the access-control boundary. `[VERIFIED: guides/resumable_uploads.md][VERIFIED: lib/rindle/live_view.ex]` |
| V5 Input Validation | yes. `[VERIFIED: lib/rindle/live_view.ex]` | LiveView upload constraints, profile MIME/size checks, and `verify_completion/2` stay in force. `[VERIFIED: lib/rindle/live_view.ex]` |
| V6 Cryptography | yes. `[VERIFIED: lib/rindle/live_view.ex]` | The helper requires `:secret_key_base` because the tus URL is signed; do not hand-roll alternate token logic in the proof harness. `[VERIFIED: lib/rindle/live_view.ex]` |

### Known Threat Patterns for Phoenix LiveView + tus

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Signed upload URL leakage | Information Disclosure | Treat the returned upload URL as a bearer credential and reuse it byte-for-byte. `[VERIFIED: guides/resumable_uploads.md]` |
| Client rebuilding resource URLs | Tampering | Freeze `uploadUrl: entry.meta.upload_url` and parity-test that exact guide/helper contract. `[VERIFIED: guides/resumable_uploads.md][VERIFIED: lib/rindle/live_view.ex]` |
| Skipping completion verification | Tampering | Keep `consume_uploaded_entries/3` -> `verify_completion/2` as the only supported completion lane in the Phoenix proof. `[VERIFIED: guides/resumable_uploads.md][VERIFIED: lib/rindle/live_view.ex]` |
| Cross-node resume surprise on S3-backed tus | Denial of Service | Preserve the guide’s sticky-session or single-node warning in parity-tested docs. `[VERIFIED: guides/resumable_uploads.md]` |

## Sources

### Primary (HIGH confidence)
- `guides/resumable_uploads.md` - canonical Phoenix / LiveView tus guide and honest status semantics. `[VERIFIED: codebase grep]`
- `lib/rindle/live_view.ex` - shipped `allow_tus_upload/4` and `consume_uploaded_entries/3` contract. `[VERIFIED: codebase grep]`
- `test/rindle/live_view_test.exs` - helper metadata shape and actor semantics. `[VERIFIED: codebase grep]`
- `test/install_smoke/support/generated_app_helper.ex` - current generated-app tus proof, Node harness, and JSON report surface. `[VERIFIED: codebase grep]`
- `test/install_smoke/generated_app_smoke_test.exs` - current install-smoke assertions and proof authority. `[VERIFIED: codebase grep]`
- `test/install_smoke/phoenix_tus_truth_parity_test.exs` - existing support-truth parity guard. `[VERIFIED: codebase grep]`
- `deps/phoenix_live_view/lib/phoenix_live_view/test/live_view_test.ex` - `preflight_upload/1`, `render_upload/3`, and `render_submit/2` capabilities. `[VERIFIED: codebase grep]`
- `https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/client/external-uploads.md` - official external-upload contract. `[CITED: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/client/external-uploads.md]`
- `https://github.com/tus/tus-js-client/blob/main/docs/api.md` - official `findPreviousUploads`, `resumeFromPreviousUpload`, and `start` behavior. `[CITED: https://github.com/tus/tus-js-client/blob/main/docs/api.md]`
- npm registry `tus-js-client` metadata - current release version and publish date. `[VERIFIED: npm registry]`

### Secondary (MEDIUM confidence)
- `https://hexdocs.pm/phoenix_live_view/uploads.html` - current published docs version used to confirm official LiveView docs currency. `[CITED: https://hexdocs.pm/phoenix_live_view/uploads.html]`

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - the repo already uses the relevant stack, and the LiveView/tus APIs were verified against official docs and local dependency source. `[VERIFIED: mix.lock][CITED: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/client/external-uploads.md][CITED: https://github.com/tus/tus-js-client/blob/main/docs/api.md]`
- Architecture: HIGH - the exact current proof gap is visible in repo code, and the recommended closure uses verified existing framework/test surfaces. `[VERIFIED: test/install_smoke/support/generated_app_helper.ex][VERIFIED: deps/phoenix_live_view/lib/phoenix_live_view/test/live_view_test.ex]`
- Pitfalls: HIGH - the major risks are directly visible from the mismatch between guide/helper contract and current proof scope, plus the current local environment probe. `[VERIFIED: guides/resumable_uploads.md][VERIFIED: test/install_smoke/support/generated_app_helper.ex][VERIFIED: local environment probe]`

**Research date:** 2026-05-25
**Valid until:** 2026-06-24
