# Phase 48: Phoenix DX Contract + Truth Audit - Pattern Map

**Mapped:** 2026-05-25
**Files analyzed:** 12
**Analogs found:** 12 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `.planning/PROJECT.md` | config | transform | `.planning/PROJECT.md` | exact |
| `.planning/REQUIREMENTS.md` | config | transform | `.planning/REQUIREMENTS.md` | exact |
| `.planning/ROADMAP.md` | config | transform | `.planning/ROADMAP.md` | exact |
| `.planning/STATE.md` | config | transform | `.planning/STATE.md` | exact |
| `guides/resumable_uploads.md` | utility | transform | `guides/resumable_uploads.md` | exact |
| `lib/rindle/live_view.ex` | utility | request-response | `lib/rindle/live_view.ex` | exact |
| `lib/rindle.ex` | utility | request-response | `lib/rindle.ex` | exact |
| `test/install_smoke/docs_parity_test.exs` | test | transform | `test/install_smoke/docs_parity_test.exs` | exact |
| `.planning/milestones/v1.8-ROADMAP.md` | config | transform | `.planning/milestones/v1.8-ROADMAP.md` | exact |
| `.planning/research/v1.8/STRATEGY-SEQUENCING.md` | config | transform | `.planning/research/v1.8/STRATEGY-SEQUENCING.md` | exact |
| `.planning/research/v1.8/TUS-RESEARCH.md` | config | transform | `.planning/research/v1.8/TUS-RESEARCH.md` | exact |
| `.planning/phases/42-tus-protocol-edge-bare-plug/42-CONTEXT.md` | config | transform | `.planning/phases/42-tus-protocol-edge-bare-plug/42-CONTEXT.md` | exact |

## Pattern Assignments

### `.planning/PROJECT.md` (config, transform)

**Analog:** `.planning/PROJECT.md`

**Milestone framing pattern** (lines 5-17):
```markdown
Milestone `v1.8 Resumable Browser Ingest` shipped on `2026-05-25` ...
Milestone `v1.9 Phoenix Tus DX Completion` opened on `2026-05-25` ...
Rindle already ships the headless tus edge plus a thin
LiveView helper seam, so the remaining gap is turning that shipped capability
into an honest, first-class Phoenix adopter story with aligned docs, support
truth, and proof.
```

**Active-scope / deferred split pattern** (lines 203-218):
```markdown
### Active (v1.9 Phoenix Tus DX Completion)

In scope for `v1.9` ...
- `PHX-*`: Phoenix / LiveView tus DX completion ...
- `PROOF-*`: package-consumer and parity proof ...
- `TRUTH-*`: planning/docs truth-alignment work ...

Deferred to `v1.10+` or out of scope for this milestone: ... a
Rindle-owned standalone tus JS client package, generic uploader UI
kits beyond the supported helper path ...
```

**Locked decision-table wording pattern** (lines 358-359):
```markdown
| v1.9 is a Phoenix tus DX completion / truth-alignment milestone, not a new tus capability milestone | The repo already ships the headless tus edge, `Rindle.initiate_tus_upload/2`, and the thin `Rindle.LiveView.allow_tus_upload/4` seam; the remaining gap is coherent support truth, productized adopter guidance, and proof | Locked v1.9 |
| The supported Phoenix tus path remains helper + documented client uploader over the existing `verify_completion/2` lane; richer Rindle-owned uploader abstractions stay optional future scope unless the current seam proves insufficient | This preserves the shipped headless contract, avoids overclaiming a component that does not exist yet, and keeps the milestone on the highest-leverage wedge | Locked v1.9 |
```

### `.planning/REQUIREMENTS.md` (config, transform)

**Analog:** `.planning/REQUIREMENTS.md`

**Support-truth gate pattern** (lines 11-22):
```markdown
## Support Truth Gate

- **Supported now:** bare `Rindle.Upload.TusPlug`, `Rindle.initiate_tus_upload/2`,
  `Rindle.LiveView.allow_tus_upload/4`, `consume_uploaded_entries/3`, and a
  documented `uploader: "RindleTus"` client pattern over the existing
  `verify_completion/2` lane.
- **Not yet claimed:** a Rindle-owned standalone tus JS client package, a broad
  drag/drop uploader component library, multi-provider Phoenix abstractions, or
  new tus protocol extensions.
```

**Requirement bullet style** (lines 36-62):
```markdown
### Phoenix Tus Contract

- [ ] **PHX-01**: Adopter can identify the supported Phoenix tus path from one
      canonical guide without inferring that the entire LiveView story is still
      deferred.
...
- [ ] **TRUTH-01**: Active planning artifacts stop claiming the entire
      LiveView tus path is deferred when the shipped helper already exists, and
      instead defer only richer future abstractions explicitly.
```

**Out-of-scope table pattern** (lines 86-96):
```markdown
| Feature | Reason |
|---------|--------|
| Rindle-owned standalone tus JS client package | Too broad for the current wedge; the documented uploader pattern is sufficient if it is honest and proven. |
| Generic drag/drop uploader component library | This milestone closes the supported helper path, not a reusable UI kit. |
```

### `.planning/ROADMAP.md` (config, transform)

**Analog:** `.planning/ROADMAP.md`

**Current-status paragraph pattern** (lines 16-22):
```markdown
Milestone `v1.9 Phoenix Tus DX Completion` is now active. The wedge is narrow
on purpose: Rindle already ships the bare tus edge, `Rindle.initiate_tus_upload/2`,
the thin `Rindle.LiveView.allow_tus_upload/4` seam, and the headless tus proof.
This milestone finishes the Phoenix adopter story by aligning truth,
productizing the supported helper path, and proving it end to end.
```

**Phase-detail / success-criteria pattern** (lines 43-55):
```markdown
**Phase 48: Phoenix DX Contract + Truth Audit**
Goal: freeze the exact Phoenix tus support claim and remove stale planning
language that treats the current seam as wholly deferred.

Success criteria:
1. Active planning docs distinguish the shipped bare tus edge, the shipped thin
   LiveView helper seam, and the still-deferred richer future abstractions.
2. One canonical Phoenix-facing story is named explicitly ...
3. Deferred lists stop carrying "LiveView tus uploader component" as shorthand ...
```

**Deferred-list phrasing pattern** (lines 90-100):
```markdown
- Rindle-owned standalone tus JS client package
- Richer reusable uploader component abstractions beyond the supported helper path
```

### `.planning/STATE.md` (config, transform)

**Analog:** `.planning/STATE.md`

**Current-focus / next-step pattern** (lines 22-29, 54-58):
```markdown
**Current focus:** v1.9 Phoenix Tus DX Completion; Phase 48 not started.

Phase: 48 - Phoenix DX Contract + Truth Audit
Plan: —
Status: Milestone initialized
...
- Run `$gsd-discuss-phase 48`.
- Or run `$gsd-plan-phase 48` to plan directly from the new milestone artifacts.
- Keep using archived `v1.8` files as historical reference only.
```

**Risk wording pattern** (lines 80-85):
```markdown
## Blockers/Concerns

- No active blocker.
- Main execution risk is support-truth drift: the code already ships a thin
  LiveView tus seam, but planning artifacts and deferred lists still overstate
  what remains unshipped.
```

**Deferred-items table pattern** (lines 87-100):
```markdown
| Category | Item | Status |
|----------|------|--------|
| tus | Rindle-owned standalone tus JS client package | out of scope |
| tus | Richer reusable uploader component beyond the shipped helper seam | deferred |
```

### `guides/resumable_uploads.md` (utility, transform)

**Analog:** `guides/resumable_uploads.md`

**Canonical-guide opener pattern** (lines 1-17):
```markdown
# Resumable Uploads

Rindle ships a tus 1.0 upload edge via `Rindle.Upload.TusPlug`. This guide
covers the adopter-owned wiring: endpoint mount, client configuration,
capability checks, and the constraints you must keep in mind ...
```

**Adopter-owned wiring and helper seam pattern** (lines 123-198):
```markdown
### LiveView helper

If your upload form already lives in LiveView, Rindle can precreate the tus
resource server-side and hand the signed `upload_url` plus `session_id` /
`asset_id` back through LiveView's `:external` upload metadata:
...
Use a tiny client uploader keyed by `uploader: "RindleTus"`:
...
Keep LiveView progress and server lifecycle states separate in your UI:

- `Uploading…` while the client is sending bytes
- `Verifying…` after the upload reaches `100%`
- `Ready` only after `consume_uploaded_entries/3` succeeds
```

**Operational-caveat pattern** (lines 237-253):
```markdown
## 7. Security Checklist
...
- For S3-backed tus uploads, keep sticky-session or single-node routing in
  place. Mid-upload tail state is node-local and cross-node resume fails loudly.

## 8. No-Silent-Downgrade Contract

Rindle does not degrade from tus to presigned PUT or multipart automatically.
If the adapter lacks `:tus_upload`, `TusPlug.init/1` raises.
```

### `lib/rindle/live_view.ex` (utility, request-response)

**Analog:** `lib/rindle/live_view.ex`

**Thin moduledoc + example pattern** (lines 3-18, 47-61):
```elixir
@moduledoc """
LiveView integration helpers for direct-to-storage uploads via Rindle.
...
For resumable browser uploads against a mounted `Rindle.Upload.TusPlug`,
use `allow_tus_upload/4` and keep `consume_uploaded_entries/3` as the
completion gate:

    socket =
      Rindle.LiveView.allow_tus_upload(socket, :video, MyApp.VideoProfile,
        path: "/uploads/tus",
        secret_key_base: ...
      )
"""
```

**Narrow API-doc option-list pattern** (lines 130-143):
```elixir
@doc """
Configures a LiveView external upload backed by Rindle's tus edge.

Requires:

  * `:path` - the mounted tus route, such as `"/uploads/tus"`
  * `:secret_key_base` - the same secret used to mount `Rindle.Upload.TusPlug`

Optional:

  * `:actor` - either a binary or a 1-arity function receiving the socket.
"""
```

**Helper metadata contract pattern** (lines 224-244):
```elixir
case Rindle.initiate_tus_upload(profile, ...) do
  {:ok, %{session: session, upload_url: upload_url}} ->
    meta = %{
      uploader: "RindleTus",
      endpoint: path,
      upload_url: upload_url,
      session_id: session.id,
      asset_id: session.asset_id
    }

    {:ok, meta, socket}
```

### `lib/rindle.ex` (utility, request-response)

**Analog:** `lib/rindle.ex`

**Public facade / alias pattern** (lines 1-13, 26):
```elixir
defmodule Rindle do
  alias Rindle.Domain.MediaAsset
  alias Rindle.Domain.MediaAttachment
  alias Rindle.Domain.MediaUploadSession
  ...
  alias Rindle.Upload.TusPlug

  import Ecto.Query
```

**Public tus facade doc pattern** (lines 96-107):
```elixir
@doc """
Initiates a tus upload resource through the broker and returns the signed
upload URL needed by browser tus clients.

Requires an explicit mounted tus `:path`, the adopter `:secret_key_base`, and
the file `:length` in bytes. The returned `upload_url` is a bearer credential
and should only be handed to the client that will upload the file.
"""
@spec initiate_tus_upload(module(), keyword()) :: TusPlug.create_upload_result()
def initiate_tus_upload(profile, opts \\ []) do
  TusPlug.create_upload(profile, opts)
end
```

### `test/install_smoke/docs_parity_test.exs` (test, transform)

**Analog:** `test/install_smoke/docs_parity_test.exs`

**File-oriented parity-test setup pattern** (lines 3-24):
```elixir
defmodule Rindle.InstallSmoke.DocsParityTest do
  alias Rindle.InstallSmoke.GeneratedAppHelper
  use ExUnit.Case, async: true

  @readme_path Path.expand("../../README.md", __DIR__)
  ...

  setup_all do
    {:ok,
     %{
       readme: File.read!(@readme_path),
       guide: File.read!(@guide_path),
       ...
     }}
  end
end
```

**Direct string-assert / refute pattern** (lines 26-41, 165-176):
```elixir
test "README and getting-started guide teach the facade-first lifecycle and handoff", %{
  readme: readme,
  guide: guide
} do
  for doc <- [readme, guide] do
    assert doc =~ "Rindle.Profile"
    ...
  end

  assert readme =~ "guides/getting_started.md"
  assert guide =~ "[`README.md`](../README.md)"
end

test "docs distinguish public install guidance from maintainer-only release runbooks", %{
  readme: readme,
  guide: guide
} do
  ...
  for doc <- [readme, guide] do
    refute doc =~ "mix hex.user whoami"
    refute doc =~ "HEX_API_KEY"
  end
end
```

### `.planning/milestones/v1.8-ROADMAP.md` (config, transform)

**Analog:** `.planning/milestones/v1.8-ROADMAP.md`

**Historical snapshot structure** (lines 1-15, 33-43):
```markdown
# Milestone v1.8: Resumable Browser Ingest

**Status:** ✅ SHIPPED 2026-05-25
**Phases:** 42-47
...
## Phase Summary

| Phase | Name | Plans | Outcome |
|-------|------|-------|---------|
```

**Stale deferred shorthand to banner around, not rewrite wholesale** (lines 74-83):
```markdown
## Deferred to v1.9+

- Rindle-owned tus JS client
- LiveView tus uploader component
- Second streaming provider (Cloudflare/Bunny)
```

**Archive cross-link footer pattern** (line 92):
```markdown
_For current project status, see `.planning/ROADMAP.md`._
```

### `.planning/research/v1.8/STRATEGY-SEQUENCING.md` (config, transform)

**Analog:** `.planning/research/v1.8/STRATEGY-SEQUENCING.md`

**Locked historical-research header pattern** (lines 1-8):
```markdown
# v1.8 Strategy / Sequencing / Ecosystem-Fit — Locked Recommendation

**Project:** Rindle ...
**Date:** 2026-05-22
**Decision posture:** One-shot, opinionated, locked.
```

**Specific stale deferred wording to preserve but disclaim** (lines 15-19, 40-42):
```markdown
- **Defers to v1.9:** ... a Rindle-owned tus client, LiveView tus uploader component, second streaming provider.
...
2. **LiveView tus uploader component** — natural follow-on ... Defer to v1.9; do not let it inflate v1.8.
```

**Do-not-rewrite signal** (lines 22-23):
```markdown
This is not a menu. It is one coherent set with one story: **"browser to durable, even on a bad connection."**
```

### `.planning/research/v1.8/TUS-RESEARCH.md` (config, transform)

**Analog:** `.planning/research/v1.8/TUS-RESEARCH.md`

**Historical supersession pattern** (lines 3-9):
```markdown
**Status:** LOCKED RECOMMENDATION.
**Supersedes:** `.planning/research/v1.6-CANDIDATE-TUS.md` ...
**materially stale** because v1.7 shipped the resumable-session substrate ...
```

**Historical roadmap wording to disclaim, not normalize into active truth** (lines 183-192):
```markdown
1. tus is a **separate capability** (`:tus_upload`), never auto-selected.
2. tus has **no facade sugar**. Only the Plug + a broker `initiate` entrypoint.
...
5. The endpoint is **adopter-mounted under their own auth pipeline**.
```

**Context for why old shorthand existed** (lines 134-146):
```markdown
- **Completes the resumable story coherently.**
- **Killer case is real and already in-repo's wheelhouse.**
- **Most of the substrate is paid for.**
```

### `.planning/phases/42-tus-protocol-edge-bare-plug/42-CONTEXT.md` (config, transform)

**Analog:** `.planning/phases/42-tus-protocol-edge-bare-plug/42-CONTEXT.md`

**Historical phase-boundary pattern** (lines 7-17):
```markdown
## Phase Boundary

Ship the **tus 1.0 HTTP protocol edge** as a bare `Rindle.Upload.TusPlug`
...
An adopter can mount the Plug under their own auth pipeline; a
real tus client (tus-js-client) can create → resume across drops → complete →
delete an upload that promotes through the **unchanged** `verify_completion/2`
lane ...
```

**Original deferred-language source to annotate** (lines 18-24):
```markdown
**Explicitly NOT in this phase:**
- ... optional rebind authorizer enforcement ... `guides/resumable_uploads.md`,
  generated-app CI proof (TUS-10..14 → **Phase 44**).
```

**No-silent-downgrade wording pattern** (lines 102-109):
```markdown
- **D-09:** Add exactly ONE atom `:tus_upload` ...
  `init/1` calls `Capabilities.require_upload(adapter, :tus_upload)` and **raises
  `ArgumentError`** ...
  **No silent downgrade** to presigned/multipart/GCS.
```

## Shared Patterns

### Guide-First Canonical Phoenix Story
**Sources:** [mix.exs](../../mix.exs), `guides/resumable_uploads.md`, `lib/rindle/live_view.ex`
**Apply to:** `guides/resumable_uploads.md`, `lib/rindle/live_view.ex`, active planning docs

Use the guide as the single operational canon, then keep API docs thin and pointer-oriented.

From [mix.exs](/Users/jon/projects/rindle/mix.exs:121):
```elixir
defp docs do
  [
    main: "Rindle",
    source_url: @source_url,
    extras: [
      ...
      "guides/resumable_uploads.md",
      ...
    ]
```

From [lib/rindle/live_view.ex](/Users/jon/projects/rindle/lib/rindle/live_view.ex:49):
```elixir
For resumable browser uploads against a mounted `Rindle.Upload.TusPlug`,
use `allow_tus_upload/4` and keep `consume_uploaded_entries/3` as the
completion gate:
```

### Support-Boundary Wording
**Sources:** `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/PROJECT.md`
**Apply to:** all active truth surfaces

Keep the same three-part split everywhere: shipped bare tus edge, shipped thin LiveView helper seam, deferred richer UI / package ownership.

From [REQUIREMENTS.md](/Users/jon/projects/rindle/.planning/REQUIREMENTS.md:13):
```markdown
- **Supported now:** bare `Rindle.Upload.TusPlug`, `Rindle.initiate_tus_upload/2`,
  `Rindle.LiveView.allow_tus_upload/4`, `consume_uploaded_entries/3`, and a
  documented `uploader: "RindleTus"` client pattern over the existing
  `verify_completion/2` lane.
- **Not yet claimed:** a Rindle-owned standalone tus JS client package, a broad
  drag/drop uploader component library, multi-provider Phoenix abstractions, or
  new tus protocol extensions.
```

### Historical-Artifact Disclaimer Pattern
**Sources:** `.planning/milestones/v1.8-ROADMAP.md`, archived requirements files
**Apply to:** `.planning/milestones/v1.8-ROADMAP.md`, `.planning/research/v1.8/STRATEGY-SEQUENCING.md`, `.planning/research/v1.8/TUS-RESEARCH.md`, `.planning/phases/42-tus-protocol-edge-bare-plug/42-CONTEXT.md`

Keep the historical body, add a short top banner or adjacent note that redirects to active truth surfaces.

From [v1.8-ROADMAP.md](/Users/jon/projects/rindle/.planning/milestones/v1.8-ROADMAP.md:92):
```markdown
_For current project status, see `.planning/ROADMAP.md`._
```

From `.planning/milestones/v1.8-REQUIREMENTS.md` already matched by grep:
```markdown
For current requirements, start the next milestone with `.planning/REQUIREMENTS.md`.
```

### File-Oriented Truth Parity Tests
**Sources:** `test/install_smoke/docs_parity_test.exs`, `test/install_smoke/release_docs_parity_test.exs`
**Apply to:** any new Phase 48 parity test or edits to `test/install_smoke/docs_parity_test.exs`

Use `setup_all` with `File.read!`, then exact `assert` / `refute` string checks. Do not shell out.

From [test/install_smoke/release_docs_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/release_docs_parity_test.exs:12):
```elixir
setup_all do
  {:ok,
   %{
     mix_exs: File.read!(@mix_exs_path),
     release_guide: File.read!(@release_guide_path),
     ...
   }}
end
```

From [test/install_smoke/docs_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/docs_parity_test.exs:173):
```elixir
for doc <- [readme, guide] do
  refute doc =~ "mix hex.user whoami"
  refute doc =~ "HEX_API_KEY"
end
```

## No Analog Found

None. Every file implied by the phase has a direct in-repo analog or an exact existing target surface.

## Metadata

**Analog search scope:** `.planning/`, `guides/`, `lib/`, `test/`, `mix.exs`
**Files scanned:** 17
**Pattern extraction date:** 2026-05-25
