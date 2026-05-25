# Phase 49: LiveView Tus Productization - Research

**Researched:** 2026-05-25
**Domain:** Phoenix LiveView external uploads over Rindle's shipped tus seam
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Phoenix / LiveView server contract
- **D-01:** Keep `Rindle.LiveView.allow_tus_upload/4` as a thin LiveView
  convenience seam over the shipped tus path rather than growing a broader
  Phoenix abstraction. The helper should stay a small wrapper around LiveView's
  `:external` upload contract, not a second framework.
- **D-02:** The supported server-side contract for this phase is explicit and
  narrow: required `:path` and `:secret_key_base`, optional `:actor`, adopter-
  owned router/auth/parser/CORS wiring, and completion through
  `consume_uploaded_entries/3`.
- **D-03:** Keep the canonical Phoenix / LiveView tus setup in
  `guides/resumable_uploads.md`. API docs in `Rindle.LiveView` should stay thin
  and point to that guide instead of duplicating the full setup narrative.

### Client uploader contract
- **D-04:** The canonical browser client remains a tiny documented
  `uploader: "RindleTus"` adapter over `tus-js-client`. Rindle should freeze the
  uploader shape and behavior through docs/tests, not by owning a JS package in
  this phase.
- **D-05:** The supported uploader contract must explicitly reuse the signed
  `upload_url`, perform resume discovery via `findPreviousUploads()`, resume via
  `resumeFromPreviousUpload(...)`, and preserve tus offset truth instead of
  inventing alternate client-side progress semantics.
- **D-06:** `@uppy/tus` may remain mentioned as a compatible alternative, but
  it is not the canonical Phase 49 LiveView path. Rindle should not bless a UI
  stack as the default story for this milestone.

### UI-state model
- **D-07:** Freeze a small honest public UI vocabulary: `uploading` while bytes
  are moving, `verifying` after transport reaches `100%`, and `ready` only after
  `consume_uploaded_entries/3` / `verify_completion/2` succeed. `error` remains
  the failure sink.
- **D-08:** Treat `100%` as "bytes transferred", not "asset ready". The guide
  and examples must explicitly separate transfer completion from server truth.
- **D-09:** Richer sublabels such as `resuming` or `retrying` are additive
  examples only, not part of the promised universal UI contract for this phase.

### Boundary discipline
- **D-10:** Phase 49 productizes only the already-shipped narrow helper path.
  Do not introduce a reusable drag/drop component kit, standalone npm package,
  provider-agnostic upload DSL, or broader Phoenix abstraction surface here.
- **D-11:** Preserve capability honesty across docs and examples. The Phase 49
  path is the Phoenix / LiveView helper seam over the existing tus edge and
  completion lane, not a batteries-included uploader framework.

### Downstream recommendation posture
- **D-12:** For this phase, downstream research/planning/execution should keep
  the project default posture explicit: produce one coherent recommendation set,
  decide by default on local/additive/ergonomic choices, and escalate only for
  genuinely high-blast-radius decisions such as semver-significant public API
  reshapes, security-boundary changes, destructive irreversibility, major cost
  surprises, or milestone/scope changes.

### Claude's Discretion
- Exact helper-doc wording and option-table formatting, as long as D-01 through
  D-03 stay intact.
- Exact `RindleTus` snippet shape and code style, as long as D-04 through D-06
  remain true.
- Exact sample UI labels/copy around `uploading`, `verifying`, and `ready`, as
  long as D-07 through D-09 remain true.

### Deferred Ideas (OUT OF SCOPE)
- Reusable uploader UI/component abstractions beyond the current helper seam.
- Rindle-owned standalone tus JS client package.
- Broader provider-agnostic Phoenix upload abstractions.
- Additional tus protocol extensions or new upload topology work.

### Reviewed Todos (not folded)
None — `todo.match-phase` returned no Phase 49 matches.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PHX-02 | Adopter can configure a LiveView upload with `Rindle.LiveView.allow_tus_upload/4` using documented required options (`path`, `secret_key_base`, optional `actor`) and keep completion through `consume_uploaded_entries/3`. | `allow_tus_upload/4` already fetches `:path` and `:secret_key_base`, accepts optional `:actor`, and strips those keys before delegating to LiveView `allow_upload`; `consume_uploaded_entries/3` still calls `Rindle.verify_completion/2`. `[VERIFIED: lib/rindle/live_view.ex]` |
| PHX-03 | Adopter can drop in a documented `uploader: "RindleTus"` client uploader or hook that reuses the signed `upload_url`, performs resume discovery, and reports byte progress without bypassing tus offset semantics. | The guide already shows `uploadUrl: entry.meta.upload_url`, `findPreviousUploads()`, and `resumeFromPreviousUpload(...)`; tus-js-client documents those resume APIs; Uppy wraps tus-js-client and exposes `uploadUrl`, `parallelUploads`, and fingerprint options. `[VERIFIED: guides/resumable_uploads.md] [CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/README.md] [CITED: https://raw.githubusercontent.com/transloadit/uppy/main/packages/@uppy/tus/src/index.ts]` |
| PHX-04 | Adopter can render honest UI states that distinguish byte transfer completion from server verification/readiness. | The guide already separates `Uploading…`, `Verifying…`, and `Ready`, and LiveView completion still converges through `consume_uploaded_entries/3` into `verify_completion/2`. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/live_view.ex]` |
</phase_requirements>

## Summary

Phase 49 should be planned as a **contract-freezing documentation and parity-test phase**, not a new capability phase. The core seam already exists in code: `Rindle.LiveView.allow_tus_upload/4` is a thin LiveView `:external` wrapper, returns `uploader`, `endpoint`, `upload_url`, `session_id`, and `asset_id`, and keeps completion through `consume_uploaded_entries/3` into `Rindle.verify_completion/2`. `[VERIFIED: lib/rindle/live_view.ex] [VERIFIED: test/rindle/live_view_test.exs]`

The canonical guide already contains most of the desired adopter flow, including the `RindleTus` snippet, signed `upload_url` reuse, resume discovery, and the `uploading`/`verifying`/`ready` state split. The main planning need is to turn that into an explicit supported contract with narrow option docs and parity assertions, while keeping `Rindle.LiveView` docs thin so the guide remains the only full narrative. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/live_view.ex] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs]`

Upstream LiveView documentation still treats external uploads as a server-generated metadata contract passed to a client uploader, which matches Rindle's helper shape. Current upstream client libraries also support the exact resume semantics Phase 49 wants to freeze: tus-js-client documents `findPreviousUploads()` and `resumeFromPreviousUpload(...)`, and current `@uppy/tus` is a wrapper over tus-js-client with `uploadUrl`, `parallelUploads`, and fingerprint behavior exposed. `[CITED: https://hexdocs.pm/phoenix_live_view/external-uploads.html] [CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/README.md] [CITED: https://raw.githubusercontent.com/transloadit/uppy/main/packages/@uppy/tus/src/index.ts]`

**Primary recommendation:** Plan Phase 49 around one canonical guide update, one thin API-doc tightening pass, and a focused parity-test expansion that freezes helper options, `RindleTus` resume behavior, and the honest UI-state vocabulary. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/live_view.ex] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs]`

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| LiveView upload setup (`allow_tus_upload/4`) | Frontend Server (SSR) | Browser / Client | The helper runs in LiveView mount/update code and emits metadata for the client uploader. `[VERIFIED: lib/rindle/live_view.ex] [CITED: https://hexdocs.pm/phoenix_live_view/external-uploads.html]` |
| tus byte transfer and resume discovery | Browser / Client | API / Backend | The browser uploader owns `findPreviousUploads`, `resumeFromPreviousUpload`, and progress callbacks while the server remains the offset authority. `[VERIFIED: guides/resumable_uploads.md] [CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/README.md]` |
| Signed tus URL minting and session binding | API / Backend | Frontend Server (SSR) | `Rindle.initiate_tus_upload/2` and `TusPlug.create_upload/2` mint the signed resource and persist it into the broker session. `[VERIFIED: lib/rindle.ex] [VERIFIED: lib/rindle/upload/tus_plug.ex] [VERIFIED: lib/rindle/upload/broker.ex]` |
| Verification and readiness transition | API / Backend | Database / Storage | `consume_uploaded_entries/3` calls `verify_completion/2`, which is the existing trust boundary for persisted object verification and promotion. `[VERIFIED: lib/rindle/live_view.ex] [VERIFIED: lib/rindle.ex] [VERIFIED: lib/rindle/upload/broker.ex]` |
| Upload-state rendering (`uploading` / `verifying` / `ready`) | Browser / Client | Frontend Server (SSR) | The UI state lives in the app's LiveView state/rendering layer, but the vocabulary must mirror the server completion boundary. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/live_view.ex]` |
| Router/auth/parser/CORS wiring | API / Backend | Frontend Server (SSR) | Rindle explicitly leaves mount, auth, parser, and CORS ownership to the host app rather than the helper. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/live_view.ex] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs]` |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `phoenix_live_view` | `1.1.30` (published 2026-05-05) | LiveView `allow_upload/3` external-upload contract that `allow_tus_upload/4` wraps. `[VERIFIED: npm registry]` | Official docs define the exact `:external` 2-arity metadata flow Rindle is using. `[CITED: https://hexdocs.pm/phoenix_live_view/external-uploads.html]` |
| `tus-js-client` | `4.3.1` (published 2025-01-16) | Canonical browser uploader for the supported `RindleTus` path. `[VERIFIED: npm registry]` | Its README shows the exact resume-discovery APIs the Phase 49 contract requires. `[CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/README.md]` |
| `plug` | `1.19.1` | Raw request-body and Plug boundary underlying `TusPlug` and Phoenix parser pass-through. `[VERIFIED: mix.lock]` | The guide requires raw `application/offset+octet-stream` bodies to reach the tus edge unchanged. `[VERIFIED: guides/resumable_uploads.md]` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `@uppy/tus` | `5.1.1` (published 2026-02-03) | Compatible alternative client for adopters who already standardize on Uppy. `[VERIFIED: npm registry]` | Mention as a non-canonical option only; keep `parallelUploads: 1` for the supported Rindle posture. `[VERIFIED: guides/resumable_uploads.md] [CITED: https://raw.githubusercontent.com/transloadit/uppy/main/packages/@uppy/tus/README.md] [CITED: https://raw.githubusercontent.com/transloadit/uppy/main/packages/@uppy/tus/src/index.ts]` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `tus-js-client` as the canonical example | `@uppy/tus` | Uppy is compatible, but Phase 49 explicitly does not bless a UI stack as the default path. `[VERIFIED: .planning/phases/49-liveview-tus-productization/49-CONTEXT.md] [VERIFIED: guides/resumable_uploads.md]` |
| Guide-owned setup narrative | Expanded `Rindle.LiveView` API docs | Duplicating router/parser/CORS/client setup in API docs would create drift; existing parity tests already guard the thin-doc pointer posture. `[VERIFIED: lib/rindle/live_view.ex] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs]` |

**Installation:**
```bash
npm install tus-js-client
```

**Version verification:** `[VERIFIED: npm registry]`
- `npm view tus-js-client version` → `4.3.1` (latest stable at registry query time; latest prerelease present is `5.0.0-pre2`). `[VERIFIED: npm registry]`
- `npm view @uppy/tus version` → `5.1.1`. `[VERIFIED: npm registry]`
- `npm view phoenix_live_view version` → `1.1.30` (latest stable at registry query time; `1.2.0-rc.2` exists as prerelease). `[VERIFIED: npm registry]`

## Architecture Patterns

### System Architecture Diagram

```text
Browser file select
  |
  v
LiveView mount/config
  -> allow_tus_upload/4
  -> LiveView :external metadata
  |
  v
Client uploader ("RindleTus")
  -> reuse signed upload_url
  -> findPreviousUploads()
  -> resumeFromPreviousUpload(...)
  -> PATCH bytes / HEAD offsets
  |
  v
Rindle.Upload.TusPlug
  -> signed URL verification
  -> offset truth
  -> session persistence
  |
  v
Broker / storage session
  -> session last_known_offset
  -> final upload object
  |
  v
LiveView consume_uploaded_entries/3
  -> Rindle.verify_completion/2
  -> asset validating / ready pipeline
  |
  v
UI state
  uploading -> verifying -> ready
           \-> error
```

### Recommended Project Structure
```text
guides/
├── resumable_uploads.md   # Canonical Phoenix / tus contract

lib/rindle/
├── live_view.ex           # Thin LiveView helper docs and metadata seam
├── upload/tus_plug.ex     # tus edge semantics and signed URL creation
└── ex                     # Public facade entrypoints

test/
├── rindle/live_view_test.exs                  # Helper metadata/unit semantics
└── install_smoke/phoenix_tus_truth_parity_test.exs  # Guide/helper truth freeze
```

### Pattern 1: Thin LiveView Helper Over `:external`
**What:** Keep `allow_tus_upload/4` as a narrow wrapper that fetches required opts, resolves optional actor data, and delegates to `Phoenix.LiveView.Upload.allow_upload/3` with an `:external` function. `[VERIFIED: lib/rindle/live_view.ex] [CITED: https://hexdocs.pm/phoenix_live_view/external-uploads.html]`

**When to use:** When the adopter already has a LiveView upload form and wants the supported Rindle tus path without inventing a second completion lifecycle. `[VERIFIED: guides/resumable_uploads.md]`

**Example:**
```elixir
# Source: lib/rindle/live_view.ex
socket =
  Rindle.LiveView.allow_tus_upload(socket, :video, MyApp.VideoProfile,
    path: "/uploads/tus",
    secret_key_base:
      Application.compile_env!(:my_app, MyAppWeb.Endpoint)[:secret_key_base],
    actor: fn socket -> socket.assigns.current_user.id end,
    accept: ~w(.mp4),
    max_entries: 1
  )
```

### Pattern 2: Reuse The Signed `upload_url`
**What:** The client contract should start from `entry.meta.upload_url`, not from a reconstructed resource URL derived from `endpoint`. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/live_view.ex]`

**When to use:** Always for the canonical `RindleTus` path, because the signed resource URL is already minted server-side and persisted into the broker session. `[VERIFIED: lib/rindle/upload/tus_plug.ex] [VERIFIED: test/rindle/live_view_test.exs]`

**Example:**
```javascript
// Source: guides/resumable_uploads.md
let upload = new tus.Upload(entry.file, {
  endpoint: entry.meta.endpoint,
  uploadUrl: entry.meta.upload_url,
  retryDelays: [0, 1000, 3000, 5000],
  removeFingerprintOnSuccess: true
})
```

### Pattern 3: Completion Still Flows Through `consume_uploaded_entries/3`
**What:** Treat LiveView's upload completion callback as the only supported handoff into `verify_completion/2`. `[VERIFIED: lib/rindle/live_view.ex]`

**When to use:** Every supported LiveView tus example in this phase. `[VERIFIED: guides/resumable_uploads.md]`

**Example:**
```elixir
# Source: lib/rindle/live_view.ex
Rindle.LiveView.consume_uploaded_entries(socket, :video, fn _entry, meta ->
  {:ok, meta.asset_id}
end)
```

### Anti-Patterns to Avoid
- **Expanding `Rindle.LiveView` into a full setup guide:** This duplicates router/parser/CORS/client material that parity tests already expect to live only in `guides/resumable_uploads.md`. `[VERIFIED: lib/rindle/live_view.ex] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs]`
- **Treating `100%` as ready:** The current guide already distinguishes byte transfer from verification; collapsing them would contradict both PHX-04 and the existing completion lane. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: .planning/REQUIREMENTS.md]`
- **Reconstructing the tus resource URL from `endpoint`:** That discards the signed resource URL Rindle already created and weakens the documented bearer-URL contract. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/upload/tus_plug.ex]`
- **Adding a second completion lifecycle in JS hooks:** The current helper and guide converge through `consume_uploaded_entries/3` and `verify_completion/2`; Phase 49 should not add a shadow “done” path. `[VERIFIED: lib/rindle/live_view.ex] [VERIFIED: guides/resumable_uploads.md]`

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Browser tus transport | A bespoke XHR/Fetch chunking client | `tus-js-client` | The supported contract depends on proven resume discovery and server-offset reconciliation APIs that tus-js-client already exposes. `[CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/README.md]` |
| LiveView direct-upload protocol | A second Phoenix-specific uploader lifecycle | LiveView `:external` uploads + `consume_uploaded_entries/3` | Phoenix LiveView already defines the server-to-client metadata contract and Rindle already wraps it. `[CITED: https://hexdocs.pm/phoenix_live_view/external-uploads.html] [VERIFIED: lib/rindle/live_view.ex]` |
| Completion truth in UI | Client-only "100% means complete" semantics | `verify_completion/2` via `consume_uploaded_entries/3` | Rindle's durable truth boundary remains server verification, not client byte transfer. `[VERIFIED: lib/rindle/live_view.ex] [VERIFIED: lib/rindle.ex] [VERIFIED: guides/resumable_uploads.md]` |

**Key insight:** The only new value Phase 49 should add is a sharper adopter contract and tighter drift protection; the transport, verification, and LiveView primitives already exist. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/live_view.ex] [VERIFIED: lib/rindle/upload/tus_plug.ex]`

## Common Pitfalls

### Pitfall 1: Doc Drift Between Guide And API Docs
**What goes wrong:** The full setup story gets copied into `Rindle.LiveView`, then drifts from the guide. `[VERIFIED: lib/rindle/live_view.ex] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs]`

**Why it happens:** The helper sits close to the feature, so it is tempting to document router/parser/CORS/client details there too. `[VERIFIED: lib/rindle/live_view.ex]`

**How to avoid:** Keep API docs thin, point to `guides/resumable_uploads.md`, and add parity assertions for the required options and canonical snippets in the guide. `[VERIFIED: lib/rindle/live_view.ex] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs]`

**Warning signs:** The moduledoc starts mentioning `Plug.Parsers`, `cors_plug`, or longer client-setup narratives. `[VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs]`

### Pitfall 2: Conflating Byte Progress With Asset Readiness
**What goes wrong:** The UI reports “done” at `100%` before `verify_completion/2` finishes. `[VERIFIED: guides/resumable_uploads.md]`

**Why it happens:** LiveView upload progress is easy to map directly to presentation state, but the server still has to verify and promote the upload. `[VERIFIED: lib/rindle/live_view.ex] [VERIFIED: lib/rindle.ex]`

**How to avoid:** Freeze `uploading` for transport, `verifying` after `entry.progress(100)`, and `ready` only after `consume_uploaded_entries/3` returns successfully. `[VERIFIED: guides/resumable_uploads.md]`

**Warning signs:** Guide/test prose says “100% complete” without also naming `verifying` or `consume_uploaded_entries/3`. `[VERIFIED: guides/resumable_uploads.md]`

### Pitfall 3: Bypassing Signed URL Reuse
**What goes wrong:** A client hook uses the collection endpoint only and does not feed the signed `upload_url` back into the uploader. `[VERIFIED: guides/resumable_uploads.md]`

**Why it happens:** Some generic tus examples demonstrate only `endpoint`, so it is easy to miss that Rindle already precreates the resource server-side. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/live_view.ex]`

**How to avoid:** Make `uploadUrl: entry.meta.upload_url` part of the canonical snippet and add parity coverage for it. `[VERIFIED: guides/resumable_uploads.md]`

**Warning signs:** The snippet has `endpoint` but no `uploadUrl`, or docs tell users to create a new resource client-side. `[VERIFIED: guides/resumable_uploads.md]`

### Pitfall 4: Scope Creep Into A UI Kit Or JS Product
**What goes wrong:** Planning grows toward reusable drag/drop components, a JS package, or broad Phoenix abstractions. `[VERIFIED: .planning/phases/49-liveview-tus-productization/49-CONTEXT.md]`

**Why it happens:** Once the docs improve, it is tempting to generalize the example into a framework product. `[VERIFIED: .planning/phases/49-liveview-tus-productization/49-CONTEXT.md]`

**How to avoid:** Treat `RindleTus` as a copy-paste contract frozen by docs/tests, not a distributable package. `[VERIFIED: .planning/phases/49-liveview-tus-productization/49-CONTEXT.md]`

**Warning signs:** New tasks propose npm publishing, reusable LiveView components, or provider-agnostic upload DSL work. `[VERIFIED: .planning/phases/49-liveview-tus-productization/49-CONTEXT.md]`

## Code Examples

Verified patterns from official sources:

### LiveView External Upload Contract
```elixir
# Source: https://hexdocs.pm/phoenix_live_view/external-uploads.html
{:ok,
 socket
 |> allow_upload(:avatar, accept: :any, max_entries: 3, external: &presign_upload/2)}
```

### tus-js-client Resume Discovery
```javascript
// Source: https://raw.githubusercontent.com/tus/tus-js-client/main/README.md
var upload = new tus.Upload(file, { endpoint: "http://localhost:1080/files/" })

upload.findPreviousUploads().then(function (previousUploads) {
  if (previousUploads.length) {
    upload.resumeFromPreviousUpload(previousUploads[0])
  }

  upload.start()
})
```

### Canonical RindleTus Upload Adapter
```javascript
// Source: guides/resumable_uploads.md
Uploaders.RindleTus = function (entries, onViewError) {
  entries.forEach((entry) => {
    let upload = new tus.Upload(entry.file, {
      endpoint: entry.meta.endpoint,
      uploadUrl: entry.meta.upload_url,
      retryDelays: [0, 1000, 3000, 5000],
      removeFingerprintOnSuccess: true
    })

    onViewError(() => upload.abort())

    upload.findPreviousUploads().then((previousUploads) => {
      if (previousUploads.length > 0) {
        upload.resumeFromPreviousUpload(previousUploads[0])
      }

      upload.start()
    })
  })
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| “LiveView tus uploader component” as deferred shorthand | Supported thin helper seam plus deferred richer UI/package abstractions | 2026-05-25 in active v1.9 planning artifacts | Planning and docs should now productize the shipped seam, not treat the whole Phoenix path as missing. `[VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/ROADMAP.md]` |
| Generic external-upload example keyed only by endpoint | Precreated signed `upload_url` reused by a canonical `RindleTus` uploader | Present in the current guide and helper/tests as of 2026-05-25 | The client contract is more specific and should be frozen explicitly in Phase 49. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: test/rindle/live_view_test.exs]` |
| “100% complete” UX shorthand | `uploading` -> `verifying` -> `ready` | Present in the current guide and phase requirements as of 2026-05-25 | UI examples and parity tests should preserve honest completion semantics. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: .planning/REQUIREMENTS.md]` |

**Deprecated/outdated:**
- Treating Phoenix / LiveView tus support as wholly deferred is outdated for active planning. `[VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md]`

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|

All claims in this research were verified or cited in this session — no user confirmation needed.

## Open Questions

1. **Should Phase 49 add a dedicated parity test for the exact UI vocabulary?**
   - What we know: The guide already says `Uploading…`, `Verifying…`, and `Ready`, but current parity coverage only checks for the broader seam and guide ownership. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs]`
   - What's unclear: Whether existing tests are sufficient for PHX-04 or whether planners should add a new docs-parity assertion now instead of waiting for Phase 50. `[VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs]`
   - Recommendation: Plan a small parity assertion in Phase 49 so PHX-04 is frozen before generated-app proof expands in Phase 50. `[VERIFIED: .planning/REQUIREMENTS.md]`

2. **Should `allow_tus_upload/4` docs include a compact option table in moduledoc examples or only in the guide?**
   - What we know: The helper docs already list required and optional options, and the guide owns the long-form setup. `[VERIFIED: lib/rindle/live_view.ex] [VERIFIED: guides/resumable_uploads.md]`
   - What's unclear: The exact split between a short option list in ExDoc and a more explicit table in the guide. `[VERIFIED: lib/rindle/live_view.ex]`
   - Recommendation: Keep the authoritative option table in the guide and leave only a short required/optional summary in `Rindle.LiveView`. `[VERIFIED: lib/rindle/live_view.ex] [VERIFIED: .planning/phases/49-liveview-tus-productization/49-CONTEXT.md]`

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix. `[VERIFIED: mix.exs] [VERIFIED: test/ directory]` |
| Config file | `test/test_helper.exs`. `[VERIFIED: test/test_helper.exs]` |
| Quick run command | `mix test test/rindle/live_view_test.exs test/install_smoke/phoenix_tus_truth_parity_test.exs` `[VERIFIED: test/rindle/live_view_test.exs] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs]` |
| Full suite command | `mix test` `[VERIFIED: mix.exs]` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PHX-02 | Helper exposes required `:path` / `:secret_key_base`, optional `:actor`, and returns broker-owned metadata while keeping LiveView config intact. `[VERIFIED: test/rindle/live_view_test.exs]` | unit | `mix test test/rindle/live_view_test.exs` | ✅ |
| PHX-03 | Canonical `RindleTus` flow reuses `upload_url`, discovers prior uploads, resumes from previous upload, and preserves offset-safe semantics in docs. `[VERIFIED: guides/resumable_uploads.md]` | docs parity | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs` | ✅ |
| PHX-04 | Guide and examples distinguish byte upload completion from verification/readiness. `[VERIFIED: guides/resumable_uploads.md]` | docs parity | `mix test test/install_smoke/phoenix_tus_truth_parity_test.exs` | ✅ |

### Sampling Rate
- **Per task commit:** `mix test test/rindle/live_view_test.exs test/install_smoke/phoenix_tus_truth_parity_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] Add explicit parity assertions for `findPreviousUploads()`, `resumeFromPreviousUpload(...)`, and `uploadUrl: entry.meta.upload_url` so PHX-03 is frozen by tests, not only by guide prose. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs]`
- [ ] Add explicit parity assertions for the `uploading` / `verifying` / `ready` vocabulary so PHX-04 has direct automated coverage. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs]`
- [ ] Consider one targeted unit test that a 1-arity `:actor` function is accepted and resolved from the socket, since current coverage only proves a literal actor value. `[VERIFIED: lib/rindle/live_view.ex] [VERIFIED: test/rindle/live_view_test.exs]`

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Mount `TusPlug` behind adopter auth; Rindle does not own app auth. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/upload/tus_plug.ex]` |
| V3 Session Management | no | No library-owned user session model is added in Phase 49; this remains adopter-owned. `[VERIFIED: guides/resumable_uploads.md]` |
| V4 Access Control | yes | Signed bearer `upload_url` plus optional `tus_resume_authorizer` for same-user resume hardening. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/upload/tus_plug.ex]` |
| V5 Input Validation | yes | LiveView file metadata, `Upload-Length`, `Upload-Offset`, and content-type checks still guard the edge. `[VERIFIED: lib/rindle/live_view.ex] [VERIFIED: lib/rindle/upload/tus_plug.ex]` |
| V6 Cryptography | yes | `Plug.Crypto.sign/verify` signs the tus resource URL; do not hand-roll URL signatures. `[VERIFIED: lib/rindle/upload/tus_plug.ex]` |

### Known Threat Patterns for Phoenix LiveView + tus

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Signed `upload_url` leakage to logs/UI | Information Disclosure | Treat `upload_url` as a bearer credential, reuse it byte-for-byte, and keep it out of logs/telemetry. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/upload/tus_plug.ex]` |
| Cross-user resume on shared devices | Spoofing / Elevation | Use optional `tus_resume_authorizer` when same-user resume semantics are required. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/upload/tus_plug.ex]` |
| Offset desynchronization | Tampering | Let the client `HEAD` for offset truth and resume from the server-reported offset instead of inventing local progress semantics. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/upload/tus_plug.ex]` |
| Client marks upload done before verification | Tampering | Keep readiness behind `consume_uploaded_entries/3` and `verify_completion/2`. `[VERIFIED: lib/rindle/live_view.ex] [VERIFIED: lib/rindle.ex]` |

## Sources

### Primary (HIGH confidence)
- `lib/rindle/live_view.ex` - helper contract, option handling, and `consume_uploaded_entries/3` verification boundary.
- `guides/resumable_uploads.md` - canonical Phoenix / LiveView tus guide and current `RindleTus` snippet.
- `lib/rindle.ex` - public `initiate_tus_upload/2` and `verify_completion/2` surfaces.
- `lib/rindle/upload/tus_plug.ex` - signed URL minting, edge semantics, and security posture.
- `lib/rindle/upload/broker.ex` - broker session persistence and completion convergence.
- `test/rindle/live_view_test.exs` - existing helper/unit semantics.
- `test/install_smoke/phoenix_tus_truth_parity_test.exs` - truth-alignment freeze for guide/helper ownership.
- `mix.exs` / `mix.lock` - dependency and test framework versions.
- `https://hexdocs.pm/phoenix_live_view/external-uploads.html` - official LiveView external upload contract.
- `https://raw.githubusercontent.com/tus/tus-js-client/main/README.md` - official tus-js-client resume API usage.
- `https://raw.githubusercontent.com/transloadit/uppy/main/packages/@uppy/tus/README.md` - official Uppy Tus plugin positioning.
- `https://raw.githubusercontent.com/transloadit/uppy/main/packages/@uppy/tus/src/index.ts` - current `@uppy/tus` defaults and option surface.
- npm registry queries for `phoenix_live_view`, `tus-js-client`, and `@uppy/tus` - current versions and publish dates.

### Secondary (MEDIUM confidence)
- None.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - versions were verified from the registry and the behavioral claims come from official docs/source. `[VERIFIED: npm registry] [CITED: https://hexdocs.pm/phoenix_live_view/external-uploads.html] [CITED: https://raw.githubusercontent.com/tus/tus-js-client/main/README.md]`
- Architecture: HIGH - the helper, broker, guide, and tests already implement the phase boundary in-repo. `[VERIFIED: lib/rindle/live_view.ex] [VERIFIED: lib/rindle/upload/tus_plug.ex] [VERIFIED: lib/rindle/upload/broker.ex]`
- Pitfalls: HIGH - each pitfall is grounded in current guide/helper/test boundaries or locked phase constraints. `[VERIFIED: guides/resumable_uploads.md] [VERIFIED: test/install_smoke/phoenix_tus_truth_parity_test.exs] [VERIFIED: .planning/phases/49-liveview-tus-productization/49-CONTEXT.md]`

**Research date:** 2026-05-25
**Valid until:** 2026-06-24
