# Phase 48: Phoenix DX Contract + Truth Audit - Research

**Researched:** 2026-05-25
**Domain:** Phoenix/LiveView tus support-contract documentation and truth alignment [VERIFIED: codebase]
**Confidence:** HIGH [VERIFIED: codebase]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Canonical Phoenix story
- **D-01:** Keep the canonical Phoenix / LiveView tus integration story in
  `guides/resumable_uploads.md`. That guide is the single authoritative
  end-to-end source for router mount, `Plug.Parsers`, CORS, client uploader,
  `allow_tus_upload/4`, and `consume_uploaded_entries/3`.
- **D-02:** `Rindle.LiveView` moduledoc and API docs should stay deliberately
  thin and point to `guides/resumable_uploads.md` instead of becoming a second
  canonical setup guide.
- **D-03:** Do not create a second Phoenix-specific canonical guide in Phase 48.
  One canonical guide is lower-drift and more idiomatic for a Phoenix / ExDoc
  library whose real story crosses router, endpoint, JS, and verification
  boundaries.

### Support claim strength
- **D-04:** Describe the shipped Phoenix path as a supported narrow helper seam,
  not as experimental and not as a broad batteries-included Phoenix uploader
  abstraction.
- **D-05:** The core maintained contract remains the tus edge itself:
  `Rindle.Upload.TusPlug`, `Rindle.initiate_tus_upload/2`, and convergence
  through `verify_completion/2`. The LiveView layer is a real first-party
  helper path over that contract, but it is still convenience wiring rather
  than a full Rindle-owned UI abstraction.
- **D-06:** Support wording must be precise that `allow_tus_upload/4` plus the
  documented `uploader: "RindleTus"` client path are supported now, while the
  adopter still owns router/auth/parser/CORS wiring and current operational
  caveats such as sticky-session or single-node resume posture where relevant.

### Deferred terminology
- **D-07:** Stop using "LiveView tus uploader component" as shorthand for the
  entire deferred scope. That wording is now support-truth drift because the
  helper seam and documented client pattern already ship.
- **D-08:** Replace the old shorthand with an explicit split:
  the shipped contract is `initiate_tus_upload/2` +
  `allow_tus_upload/4` + documented `uploader: "RindleTus"` guidance;
  the deferred work is richer reusable uploader UI/component abstractions beyond
  the supported helper path, plus any future Rindle-owned standalone tus JS
  client package.
- **D-09:** Deferred lists should name UI-kit / component abstractions and
  standalone JS-package ownership separately when both matter, rather than
  collapsing them into one vague "LiveView uploader" bucket.

### Truth-alignment scope
- **D-10:** Phase 48 should truth-align active source-of-truth artifacts first:
  `PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`, relevant active
  guides, and API docs/moduledocs that speak about the Phoenix path.
- **D-11:** Archived v1.8 research and milestone artifacts should remain
  historical records rather than being rewritten wholesale. Preserve the
  historiography.
- **D-12:** Add short archival disclaimers or cross-links on the specific
  archived v1.8 research/context files whose older "deferred" wording can still
  mislead grep-driven readers, pointing them to active v1.9 truth surfaces
  rather than retroactively rewriting the body text.

### Downstream-agent posture
- **D-13:** Planning and execution for this milestone should default to one
  coherent recommendation set and decide by default on local, reversible, or
  ergonomic choices. Escalate only for high-blast-radius changes such as
  semver-significant support-boundary reshapes, security-boundary changes,
  destructive actions, material recurring-cost surprises, or milestone/scope
  changes.

### Claude's Discretion
- Exact support-copy phrasing, as long as it preserves the D-04 through D-09
  boundary precisely and does not imply a broader Phoenix abstraction than
  exists.
- Exact archive-banner format and placement, as long as archived docs remain
  visibly historical and point clearly at active truth surfaces.
- Exact cross-link targets between `Rindle.LiveView` docs and
  `guides/resumable_uploads.md`.

### Deferred Ideas (OUT OF SCOPE)
- Rindle-owned reusable uploader UI kit / component abstractions beyond the
  current helper seam.
- Rindle-owned standalone tus JS client package.
- Broader multi-provider Phoenix upload abstractions beyond the current narrow
  tus helper path.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PHX-01 | Adopter can identify the supported Phoenix tus path from one canonical guide without inferring that the entire LiveView story is still deferred. | Keep `guides/resumable_uploads.md` as the single canonical Phoenix story, keep `Rindle.LiveView` docs thin, and add parity coverage for guide/API/planning alignment. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] [VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/live_view.ex] |
| TRUTH-01 | Active planning artifacts stop claiming the entire LiveView tus path is deferred when the shipped helper already exists, and instead defer only richer future abstractions explicitly. | Update only active truth surfaces plus targeted archive disclaimers; do not rewrite archive bodies wholesale. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/STATE.md] [VERIFIED: .planning/milestones/v1.8-ROADMAP.md] [VERIFIED: .planning/research/v1.8/STRATEGY-SEQUENCING.md] |
</phase_requirements>

## Summary

Phase 48 is a contract-freeze and truth-alignment phase, not a feature phase. The shipped Phoenix-facing tus surface already exists in code: `Rindle.initiate_tus_upload/2` exposes the signed tus upload resource, `Rindle.LiveView.allow_tus_upload/4` wraps LiveView `:external` uploads, and the canonical adopter walkthrough already lives in `guides/resumable_uploads.md`. The remaining planning problem is to state that support boundary precisely, stop carrying stale shorthand that implies the whole LiveView story is deferred, and leave Phase 49 with a narrower productization target instead of a fuzzy “build Phoenix support” brief. [VERIFIED: lib/rindle.ex] [VERIFIED: lib/rindle/live_view.ex] [VERIFIED: guides/resumable_uploads.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md]

The key research conclusion is to treat this as a guide-first documentation contract with executable drift protection. `guides/resumable_uploads.md` should remain the only canonical Phoenix/LiveView tus guide; `Rindle.LiveView` should link to that guide instead of duplicating router/parser/CORS/client instructions; and archived v1.8 artifacts should receive short historical disclaimers where grep-driven readers still encounter the old “LiveView tus uploader component” shorthand. Existing tests already prove the helper seam and some guide content, but they do not yet freeze the active planning truth boundary, so the planner should budget parity work rather than assuming current coverage is enough. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] [VERIFIED: lib/rindle/live_view.ex] [VERIFIED: test/rindle/live_view_test.exs] [VERIFIED: test/install_smoke/generated_app_smoke_test.exs] [VERIFIED: test/install_smoke/docs_parity_test.exs]

**Primary recommendation:** Use a single-canonical-guide posture, add thin cross-links from API docs, update active truth surfaces first, and add targeted archive disclaimers plus parity tests that fail on renewed support-truth drift. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] [CITED: https://hexdocs.pm/phoenix_live_view/external-uploads.html]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Canonical Phoenix/LiveView tus setup contract | Frontend Server (SSR) | Browser / Client | The supported story is rooted in LiveView `allow_upload/3` external-upload configuration on the server, then handed to a client uploader via metadata. [CITED: https://hexdocs.pm/phoenix_live_view/external-uploads.html] [VERIFIED: lib/rindle/live_view.ex] |
| Browser uploader handoff (`uploader: "RindleTus"`) | Browser / Client | Frontend Server (SSR) | The client owns byte transfer and resume discovery, but the server owns the signed `upload_url` metadata and helper seam. [VERIFIED: lib/rindle/live_view.ex] [VERIFIED: guides/resumable_uploads.md] |
| tus create/resume/verify boundary | API / Backend | Database / Storage | `Rindle.Upload.TusPlug` and `Rindle.initiate_tus_upload/2` create the upload resource, while completion still converges into `verify_completion/2`. [VERIFIED: lib/rindle.ex] [VERIFIED: .planning/REQUIREMENTS.md] |
| Active support-truth surfaces | Frontend Server (SSR) | API / Backend | The user-facing support claim lives in docs/planning artifacts, but it must describe the backend seam and client handoff exactly. [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/ROADMAP.md] [VERIFIED: guides/resumable_uploads.md] |
| Historical archive disclaimers | Frontend Server (SSR) | — | Archive disclaimers are documentation-only surfaces whose job is to redirect readers to active truth without rewriting history. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] [VERIFIED: .planning/milestones/v1.8-ROADMAP.md] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `phoenix_live_view` | `1.1.28` locked in repo; `1.1.30` current on Hex as of 2026-05-25 | Owns the `allow_upload/3` + `:external` upload contract that `Rindle.LiveView.allow_tus_upload/4` wraps. [VERIFIED: mix.lock] [VERIFIED: `mix hex.info phoenix_live_view` 2026-05-25] [CITED: https://hexdocs.pm/phoenix_live_view/external-uploads.html] | This phase should describe the helper seam in LiveView’s native terms instead of inventing a parallel abstraction. [VERIFIED: lib/rindle/live_view.ex] |
| `ex_doc` | `0.40.1` locked in repo; `0.40.3` current on Hex as of 2026-05-25 | Publishes `guides/resumable_uploads.md` as an ExDoc extra and supports guide grouping. [VERIFIED: mix.lock] [VERIFIED: `mix hex.info ex_doc` 2026-05-25] [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] | The repo already uses ExDoc extras as the canonical long-form guide surface, so Phase 48 should reinforce that pattern rather than split docs. [VERIFIED: mix.exs] |
| `doctor` | `0.22.0` locked in repo; `0.23.0` current on Hex as of 2026-05-25 | Existing doc/API coverage and drift gates run through `mix doctor --full --raise`. [VERIFIED: mix.lock] [VERIFIED: `mix hex.info doctor` 2026-05-25] [VERIFIED: .github/workflows/ci.yml] | Phase 48 should extend parity/freeze checks inside the existing test/doctor culture instead of creating manual-only truth audits. [VERIFIED: test/install_smoke/docs_parity_test.exs] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ExUnit | bundled with Elixir `1.19.5` in the local environment | Existing `live_view_test`, docs parity, and generated-app smoke lanes already express the contract as executable assertions. [VERIFIED: test/rindle/live_view_test.exs] [VERIFIED: test/install_smoke/docs_parity_test.exs] [VERIFIED: test/install_smoke/generated_app_smoke_test.exs] [VERIFIED: `elixir --version` 2026-05-25] | Use for support-truth assertions so drift fails in CI instead of in prose review. [VERIFIED: codebase] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| One canonical Phoenix guide in `guides/resumable_uploads.md` | A second Phoenix-specific guide or a fat `Rindle.LiveView` moduledoc | Rejected because the repo already treats ExDoc extras as the canonical operational surface and duplicate guides increase drift risk. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] |
| Thin API docs that point to the guide | Duplicating router/parser/CORS/client setup in API docs | Rejected because LiveView’s official model already splits server `:external` setup from client uploader wiring, and Rindle’s helper docs should stay seam-level. [CITED: https://hexdocs.pm/phoenix_live_view/external-uploads.html] [VERIFIED: lib/rindle/live_view.ex] |
| Targeted archive disclaimers | Rewriting archived v1.8 bodies to match v1.9 truth | Rejected because the phase context explicitly preserves historical records and only authorizes disclaimers/cross-links on misleading artifacts. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] |

**Installation:** No new dependencies are needed for Phase 48. Use the repo-locked stack and existing test harnesses. [VERIFIED: mix.exs]

**Version verification:** `mix hex.info phoenix_live_view`, `mix hex.info ex_doc`, and `mix hex.info doctor` were run on 2026-05-25. Current observed releases were `phoenix_live_view 1.1.30` (published 2026-05-05), `ex_doc 0.40.3` (published 2026-05-21), and `doctor 0.23.0` (published 2026-05-16). The repo remains locked to `1.1.28`, `0.40.1`, and `0.22.0` respectively, so this phase should plan against current repo behavior, not assume upgrades. [VERIFIED: `mix hex.info phoenix_live_view` 2026-05-25] [VERIFIED: `mix hex.info ex_doc` 2026-05-25] [VERIFIED: `mix hex.info doctor` 2026-05-25] [VERIFIED: mix.lock]

## Architecture Patterns

### System Architecture Diagram

```text
Phoenix LiveView mount
  -> `Rindle.LiveView.allow_tus_upload/4`
  -> LiveView `:external` metadata
  -> Browser uploader `uploader: "RindleTus"`
  -> signed tus `upload_url`
  -> `Rindle.Upload.TusPlug`
  -> `Rindle.initiate_tus_upload/2` / session state
  -> `verify_completion/2`
  -> `consume_uploaded_entries/3`

Active docs/planning truth
  -> `guides/resumable_uploads.md` (canonical)
  -> thin `Rindle.LiveView` docs (pointer only)
  -> active `.planning/*` truth surfaces
  -> archive disclaimers on stale v1.8 wording
```

The runtime path above is already shipped, and the documentation path is what Phase 48 must freeze accurately. [VERIFIED: lib/rindle.ex] [VERIFIED: lib/rindle/live_view.ex] [VERIFIED: guides/resumable_uploads.md] [VERIFIED: .planning/ROADMAP.md]

### Recommended Project Structure
```text
.planning/
├── PROJECT.md                  # active support-truth constitution
├── REQUIREMENTS.md             # requirement-level truth
├── ROADMAP.md                  # milestone/phase truth
├── STATE.md                    # current milestone truth
└── milestones/                 # historical snapshots with targeted disclaimers only

guides/
└── resumable_uploads.md        # canonical Phoenix/LiveView tus guide

lib/
├── rindle.ex                   # public tus facade seam
└── rindle/live_view.ex         # thin helper seam + guide pointer target

test/
├── rindle/live_view_test.exs   # helper seam contract
└── install_smoke/              # docs parity + generated-app truth gates
```

### Pattern 1: Guide-First Canonical Contract
**What:** Keep the end-to-end Phoenix story in one ExDoc extra, and keep API docs focused on the seam plus a pointer. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] [VERIFIED: mix.exs]

**When to use:** Use this when the real story crosses router, endpoint, parser, CORS, client JS, and completion semantics, which is already true for the tus path. [VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/live_view.ex]

**Example:**
```elixir
# Source: lib/rindle/live_view.ex [VERIFIED: codebase]
def mount(_params, _session, socket) do
  {:ok,
   Rindle.LiveView.allow_tus_upload(socket, :video, MyApp.VideoProfile,
     path: "/uploads/tus",
     secret_key_base:
       Application.compile_env!(:my_app, MyAppWeb.Endpoint)[:secret_key_base],
     accept: ~w(.mp4),
     max_entries: 1
   )}
end
```

### Pattern 2: Thin API Docs, Rich Guide
**What:** `Rindle.LiveView` should document the existence of `allow_tus_upload/4`, the required opts, and then point readers to `guides/resumable_uploads.md` for operational setup. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] [VERIFIED: lib/rindle/live_view.ex]

**When to use:** Use this when duplicating the full setup guide would create a second canon. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md]

### Pattern 3: Historical Disclaimer, Not Historical Rewrite
**What:** Add short archive banners or cross-links only where stale v1.8 shorthand still misleads readers. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md]

**When to use:** Use this on archived artifacts that still say “LiveView tus uploader component” without the newer helper-seam split. The exact files already identified by grep are `.planning/milestones/v1.8-ROADMAP.md`, `.planning/research/v1.8/STRATEGY-SEQUENCING.md`, and `.planning/research/v1.8/TUS-RESEARCH.md`. [VERIFIED: .planning/milestones/v1.8-ROADMAP.md] [VERIFIED: .planning/research/v1.8/STRATEGY-SEQUENCING.md] [VERIFIED: .planning/research/v1.8/TUS-RESEARCH.md]

### Anti-Patterns to Avoid
- **Duplicate canon:** Do not create a second Phoenix setup guide or stuff full router/parser/CORS instructions into `Rindle.LiveView` docs. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md]
- **Archive rewrite:** Do not rewrite archived v1.8 prose bodies to sound like v1.9. Add disclaimers instead. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md]
- **Support-boundary inflation:** Do not describe the current seam as a broad Rindle-owned Phoenix uploader abstraction. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .planning/ROADMAP.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Canonical Phoenix story | A second guide or duplicated API setup narrative | `guides/resumable_uploads.md` as the single canonical guide | The repo already publishes it as an ExDoc extra and the phase context locks it as the only canon. [VERIFIED: mix.exs] [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] |
| Active-truth enforcement | Manual grep-only review | ExUnit docs/planning parity assertions | Existing tests already freeze other docs contracts; Phase 48 needs the same treatment for support truth. [VERIFIED: test/install_smoke/docs_parity_test.exs] [VERIFIED: test/install_smoke/generated_app_smoke_test.exs] |
| Archive modernization | Wholesale body rewrites | Short historical disclaimers or cross-links | The phase explicitly preserves historiography. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] |

**Key insight:** The expensive failure mode in this phase is not missing prose; it is support-truth drift between guide, API docs, planning artifacts, and archived search hits. Use one canon plus executable parity checks instead of more words in more places. [VERIFIED: codebase] [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Treating the Helper Seam as Either “Experimental” or “Full Phoenix Support”
**What goes wrong:** The docs either under-claim shipped support or over-claim a broader abstraction than exists. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md]

**Why it happens:** The runtime seam is real, but it spans backend, LiveView, and client code, so readers compress it into a vague label. [VERIFIED: lib/rindle/live_view.ex] [VERIFIED: guides/resumable_uploads.md]

**How to avoid:** Freeze the wording around “supported thin helper seam” and explicitly defer only richer reusable UI/package work. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md]

**Warning signs:** Phrases like “experimental Phoenix uploader,” “whole LiveView path deferred,” or “full uploader component support” reappear in active artifacts. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md]

### Pitfall 2: Canon Drift Between Guide and API Docs
**What goes wrong:** `Rindle.LiveView` starts accreting router/parser/CORS/client instructions independently of `guides/resumable_uploads.md`. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md]

**Why it happens:** ExDoc makes it easy to write rich moduledocs, but the operational story already lives in extras. [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] [VERIFIED: mix.exs]

**How to avoid:** Keep API docs thin and add an explicit guide pointer instead of duplicating operational setup. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md]

**Warning signs:** The same router/`Plug.Parsers`/CORS snippets appear in two places with slightly different wording. [VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle/live_view.ex]

### Pitfall 3: Believing Current Tests Already Freeze Support Truth
**What goes wrong:** The planner assumes existing smoke/parity tests already protect the Phase 48 claim, but they only partially do. [VERIFIED: test/install_smoke/generated_app_smoke_test.exs] [VERIFIED: test/install_smoke/docs_parity_test.exs]

**Why it happens:** `live_view_test.exs` proves helper metadata, and generated-app smoke asserts some guide text, but active planning artifacts and archive disclaimers are not covered. [VERIFIED: test/rindle/live_view_test.exs] [VERIFIED: test/install_smoke/generated_app_smoke_test.exs] [VERIFIED: .planning/PROJECT.md] [VERIFIED: .planning/ROADMAP.md]

**How to avoid:** Budget a truth-parity test that scans active planning surfaces and the canonical guide for the locked support-copy boundary. [VERIFIED: .planning/REQUIREMENTS.md]

**Warning signs:** Phase 48 edits land only in Markdown files, with no accompanying parity assertion changes. [VERIFIED: codebase]

## Code Examples

Verified patterns from official sources and the codebase:

### LiveView External Upload Metadata Pattern
```elixir
# Source: https://hexdocs.pm/phoenix_live_view/external-uploads.html
{:ok, %{uploader: "SomeClient", entrypoint: link}, socket}
```

Phoenix LiveView’s official external-upload guide expects a 2-arity server callback returning `{:ok, meta, socket}` and handing the client uploader a metadata map. That is the same shape Rindle already uses for `RindleTus`. [CITED: https://hexdocs.pm/phoenix_live_view/external-uploads.html] [VERIFIED: lib/rindle/live_view.ex]

### Current Shipped RindleTus Metadata
```elixir
# Source: lib/rindle/live_view.ex [VERIFIED: codebase]
meta = %{
  uploader: "RindleTus",
  endpoint: path,
  upload_url: upload_url,
  session_id: session.id,
  asset_id: session.asset_id
}
```

### Current Guide-Level Client Pattern
```javascript
// Source: guides/resumable_uploads.md [VERIFIED: codebase]
Uploaders.RindleTus = function (entries, onViewError) {
  entries.forEach((entry) => {
    let upload = new tus.Upload(entry.file, {
      endpoint: entry.meta.endpoint,
      uploadUrl: entry.meta.upload_url
    })
    onViewError(() => upload.abort())
    upload.start()
  })
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| “LiveView tus uploader component” as the deferred bucket | Supported seam now = `initiate_tus_upload/2` + `allow_tus_upload/4` + documented `RindleTus`; deferred work = richer reusable UI/package layers | v1.9 milestone kickoff on 2026-05-25 [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] | Phase 48 should audit wording, not invent new runtime code. [VERIFIED: .planning/ROADMAP.md] |
| Archived research used as live support truth by grep readers | Active planning/docs are the source of truth; archives stay historical with disclaimers | Locked in Phase 48 context on 2026-05-25 [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] | Planner should update active surfaces first and add targeted redirect banners to archives. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] |
| API docs potentially carrying full setup burden | ExDoc extra as canonical guide plus thin API docs | Current repo docs configuration already uses guide extras. [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] | Lower drift and clearer ownership of operational instructions. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] |

**Deprecated/outdated:**
- `LiveView tus uploader component` as shorthand for the whole Phoenix story is outdated for active truth surfaces and should remain only as historical text behind disclaimers in archived v1.8 artifacts. [VERIFIED: .planning/milestones/v1.8-ROADMAP.md] [VERIFIED: .planning/research/v1.8/STRATEGY-SEQUENCING.md] [VERIFIED: .planning/research/v1.8/TUS-RESEARCH.md] [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md]

## Assumptions Log

All claims in this research were verified or cited in this session. No user confirmation is required before planning. [VERIFIED: research session]

## Open Questions

1. **Which exact archive files deserve disclaimers in Phase 48?**
   - What we know: The stale shorthand is present in `.planning/milestones/v1.8-ROADMAP.md`, `.planning/research/v1.8/STRATEGY-SEQUENCING.md`, and `.planning/research/v1.8/TUS-RESEARCH.md`. [VERIFIED: codebase grep]
   - What's unclear: Whether the planner wants to scope the disclaimer pass to only those three files or also add a cross-link in adjacent historical contexts that already mention the canonical guide without using the stale shorthand. [VERIFIED: .planning/phases/42-tus-protocol-edge-bare-plug/42-CONTEXT.md] [VERIFIED: .planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-CONTEXT.md]
   - Recommendation: Default to those three files only, because they are the grep-visible drift source and the phase explicitly prefers targeted archive handling. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit on Elixir `1.19.5`. [VERIFIED: test/ directory] [VERIFIED: `elixir --version` 2026-05-25] |
| Config file | `test/test_helper.exs`; no standalone `pytest`/`jest`-style config in this stack. [VERIFIED: test/test_helper.exs] |
| Quick run command | `mix test test/rindle/live_view_test.exs test/install_smoke/docs_parity_test.exs -x` [VERIFIED: file paths exist] |
| Full suite command | `mix test` [VERIFIED: Mix project] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PHX-01 | Canonical guide and helper docs describe the shipped Phoenix path as supported now. [VERIFIED: .planning/REQUIREMENTS.md] | parity | `mix test test/install_smoke/docs_parity_test.exs -x` | ✅ existing file, but missing Phase 48-specific assertions. [VERIFIED: test/install_smoke/docs_parity_test.exs] |
| TRUTH-01 | Active planning artifacts stop implying the whole LiveView path is deferred. [VERIFIED: .planning/REQUIREMENTS.md] | parity | `mix test test/install_smoke/docs_parity_test.exs -x` or a new dedicated truth-parity file | ❌ dedicated active-truth assertions do not exist yet. [VERIFIED: test/install_smoke/docs_parity_test.exs] [VERIFIED: codebase grep] |

### Sampling Rate
- **Per task commit:** `mix test test/rindle/live_view_test.exs test/install_smoke/docs_parity_test.exs -x` [VERIFIED: file paths exist]
- **Per wave merge:** `mix test test/rindle/live_view_test.exs test/install_smoke/docs_parity_test.exs test/install_smoke/generated_app_smoke_test.exs -x` [VERIFIED: file paths exist]
- **Phase gate:** `mix test` before `/gsd-verify-work` if Phase 48 adds or extends parity assertions. [VERIFIED: Mix project]

### Wave 0 Gaps
- [ ] Add or extend a parity test to freeze the active support-copy boundary in `.planning/PROJECT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, and `.planning/STATE.md`. Existing docs parity does not cover those files. [VERIFIED: test/install_smoke/docs_parity_test.exs] [VERIFIED: codebase grep]
- [ ] Add or extend a parity assertion that `lib/rindle/live_view.ex` points readers at `guides/resumable_uploads.md` instead of becoming a second canon. The current helper tests validate metadata behavior, not doc-pointer ownership. [VERIFIED: test/rindle/live_view_test.exs] [VERIFIED: lib/rindle/live_view.ex]
- [ ] Add a narrow archive-disclaimer presence check for the specific v1.8 files Phase 48 touches, so future grep-driven drift is caught intentionally. [VERIFIED: .planning/milestones/v1.8-ROADMAP.md] [VERIFIED: .planning/research/v1.8/STRATEGY-SEQUENCING.md] [VERIFIED: .planning/research/v1.8/TUS-RESEARCH.md]

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Phase 48 does not add new auth mechanics; it documents the existing adopter-owned auth boundary. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] |
| V3 Session Management | yes | Document that the signed tus `Location`/`upload_url` remains a bearer credential and that same-user resume is optional hardening, not default identity binding. [VERIFIED: guides/resumable_uploads.md] [VERIFIED: .planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-CONTEXT.md] |
| V4 Access Control | yes | Keep support copy explicit that adopters still own router/auth/parser/CORS wiring. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] [VERIFIED: guides/resumable_uploads.md] |
| V5 Input Validation | yes | Preserve the guide/API truth that completion still converges through `consume_uploaded_entries/3` and `verify_completion/2`, not a silent alternate lifecycle. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: guides/resumable_uploads.md] |
| V6 Cryptography | yes | Preserve wording around HMAC-signed upload URLs and never soften bearer-credential handling in docs. [VERIFIED: lib/rindle.ex] [VERIFIED: guides/resumable_uploads.md] |

### Known Threat Patterns for this Phase
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Overclaiming same-user resume semantics | Spoofing | Keep docs explicit that HMAC proves issuance/integrity, while same-user resume is optional authorizer behavior. [VERIFIED: guides/resumable_uploads.md] [VERIFIED: .planning/phases/44-auth-hardening-dx-docs-telemetry-ci-proof/44-CONTEXT.md] |
| Bearer URL handling understated in support copy | Information Disclosure | Retain the “bearer credential” warning in the canonical guide and thin API docs. [VERIFIED: guides/resumable_uploads.md] [VERIFIED: lib/rindle.ex] |
| Archive grep returning stale deferred language | Tampering / Reliability | Add archive disclaimers that point to active v1.9 truth surfaces. [VERIFIED: .planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md] [VERIFIED: .planning/milestones/v1.8-ROADMAP.md] |

## Sources

### Primary (HIGH confidence)
- [https://hexdocs.pm/phoenix_live_view/external-uploads.html](https://hexdocs.pm/phoenix_live_view/external-uploads.html) - LiveView `:external` upload contract and metadata handoff.
- [https://hexdocs.pm/phoenix_live_view/uploads.html](https://hexdocs.pm/phoenix_live_view/uploads.html) - Upload lifecycle and `allow_upload/3` baseline.
- [https://hexdocs.pm/ex_doc/ExDoc.html](https://hexdocs.pm/ex_doc/ExDoc.html) - ExDoc extras and `groups_for_extras` behavior.
- [https://hex.pm/packages/phoenix_live_view](https://hex.pm/packages/phoenix_live_view) - current package release visibility.
- `mix hex.info phoenix_live_view`, `mix hex.info ex_doc`, `mix hex.info doctor` run on 2026-05-25 - repo-vs-current version verification. [VERIFIED: local commands]
- Codebase files: `.planning/phases/48-phoenix-dx-contract-truth-audit/48-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/PROJECT.md`, `.planning/STATE.md`, `lib/rindle/live_view.ex`, `lib/rindle.ex`, `guides/resumable_uploads.md`, `test/rindle/live_view_test.exs`, `test/install_smoke/docs_parity_test.exs`, `test/install_smoke/generated_app_smoke_test.exs`.

### Secondary (MEDIUM confidence)
- None.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - this phase uses existing repo dependencies and official Phoenix/ExDoc docs rather than contested ecosystem choices. [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/phoenix_live_view/external-uploads.html] [CITED: https://hexdocs.pm/ex_doc/ExDoc.html]
- Architecture: HIGH - the shipped helper seam, canonical guide, and active planning truth surfaces are directly visible in the current codebase. [VERIFIED: lib/rindle.ex] [VERIFIED: lib/rindle/live_view.ex] [VERIFIED: guides/resumable_uploads.md] [VERIFIED: .planning/PROJECT.md]
- Pitfalls: HIGH - the misleading archive shorthand and current parity gaps were confirmed by targeted grep and test inspection. [VERIFIED: codebase grep] [VERIFIED: test/install_smoke/docs_parity_test.exs]

**Research date:** 2026-05-25
**Valid until:** 2026-06-24 for internal planning surfaces; recheck package versions and upstream docs if Phase 48 planning slips beyond 30 days. [VERIFIED: fast-moving package releases on Hex]
