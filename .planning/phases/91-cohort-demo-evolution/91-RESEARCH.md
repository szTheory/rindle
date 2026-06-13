# Phase 91: Cohort Demo Evolution - Research

**Researched:** 2024-05-30
**Domain:** Elixir/Phoenix, Rindle Admin, Demo Environment Data Seeding
**Confidence:** HIGH

## Summary

This phase transforms the Cohort adoption demo into a comprehensive Rindle playground. To achieve this, we need to apply a new distinct brand (replacing the Phoenix logo), add new Media profiles for Audio and Documents, seed records representing the entire Rindle lifecycle (assets, variants, upload sessions) directly in the database, and mount the Rindle Admin console within the demo router for observation. No new external libraries are required, as this leverages Rindle's built-in models and Ecto's `Repo.insert_all`.

**Primary recommendation:** Mount the Rindle Admin router with `allow_unauthenticated?: true`, implement two new custom profiles (`AdoptionDemo.AudioProfile` and `AdoptionDemo.DocumentProfile`), and use direct Ecto seeding to simulate lifecycle edge cases without having to orchestrate failed uploads via actual HTTP requests.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Cohort Brand Assets | Browser / Client | CDN / Static | Static SVG replacement and layout.ex updates |
| Media Profiles | API / Backend | Database | Profiles define the validation and variants; Ecto handles persistence |
| Data Seeding | Database / Storage | API / Backend | Explicit db seed bypassing changesets to achieve unreachable states |
| Admin Console | Frontend Server | API / Backend | Rindle Admin relies on LiveView router macros and backend state APIs |

## Standard Stack

No new external packages are introduced in this phase.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified beyond the existing Rindle + Phoenix stack)

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEMO-01 | Cohort gets its own lightweight brand | Replaces `logo.svg` in `priv/static/images/` and layout header. |
| DEMO-02 | Cohort exercises audio + document types, seeds express every state | We will define `AdoptionDemo.AudioProfile` and `AdoptionDemo.DocumentProfile`. Ecto `insert!` allows us to mock all `Rindle.Domain.*` lifecycle states (like `quarantined`, `degraded`, `stale`) in `seeds.exs`. |
| DEMO-03 | Cohort mounts the admin console; walkthrough | `Rindle.Admin.Router.rindle_admin/2` can be mounted in `router.ex` with `allow_unauthenticated?: true` for non-prod. |
</phase_requirements>

## Architecture Patterns

### Seeding Unreachable States
To test the console UI against edge cases, we must mock Rindle records in states that are normally hard or impossible to force reliably via standard APIs (e.g., `degraded` assets or `stale` variants).
**Pattern:** Bypass Rindle APIs and directly insert rows using Ecto.
**Example:**
```elixir
alias Rindle.Domain.{MediaAsset, MediaVariant, MediaUploadSession}

AdoptionDemo.Repo.insert!(%MediaAsset{
  id: Ecto.UUID.generate(),
  state: "quarantined",
  profile: "AdoptionDemo.DocumentProfile",
  kind: "document",
  storage_key: "mock/quarantined.pdf"
})
```

### Routing the Admin Console in Demo Apps
**What:** Exposing the Rindle Admin securely.
**When to use:** When you need a built-in Rindle console for monitoring and debugging.
**Example:**
```elixir
import Rindle.Admin.Router
scope "/" do
  pipe_through :browser
  rindle_admin "/admin", allow_unauthenticated?: true
end
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Simulating failures | HTTP request mocking/abort scripts | `Repo.insert!` with explicit states | We only need the DB records to exist to test the Admin UI presentation of these states. |
| Audio/Doc Profiles | Hardcoded schema logic | `use Rindle.Profile` | Profiles are the canonical way Rindle scopes storage and validation. |

## Common Pitfalls

### Pitfall 1: Missing Required Fields in Mocked Records
**What goes wrong:** Admin Console crashes when trying to render a mocked `MediaAsset` or `MediaVariant`.
**Why it happens:** Rindle Admin LiveViews often assume `profile`, `kind`, `storage_key`, or `byte_size` are populated.
**How to avoid:** Carefully inspect `Rindle.Domain.MediaAsset` and `Rindle.Domain.MediaVariant` schemas to include realistic dummy data for required fields when mocking state records.

### Pitfall 2: `rindle_admin` in Production
**What goes wrong:** Router compilation fails with "allow_unauthenticated?: true is not permitted".
**Why it happens:** `Rindle.Admin.Router` enforces secure mounts in `:prod`.
**How to avoid:** `allow_unauthenticated?: true` is fine for the Cohort demo app because it is fundamentally a dev/test environment. Just do not let it leak into a real Rindle production mount.

## Code Examples

### Defining New Profiles
```elixir
defmodule AdoptionDemo.AudioProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    allow_mime: ["audio/mpeg", "audio/ogg", "audio/wav"],
    max_bytes: 52_428_800
end

defmodule AdoptionDemo.DocumentProfile do
  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    allow_mime: ["application/pdf", "text/plain"],
    max_bytes: 20_971_520
end
```

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Phoenix) |
| Config file | none — see Wave 0 |
| Quick run command | `mix test` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEMO-03 | Admin router mounts | smoke | `mix run priv/repo/seeds.exs && mix phx.server` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix compile`
- **Per wave merge:** `mix test`
- **Phase gate:** Manual UI verification for Admin console and branding.

### Wave 0 Gaps
- None — existing test infrastructure covers basic compilation. The primary validation here is visual and manual UI testing.

## Sources
### Primary (HIGH confidence)
- Codebase investigation of `examples/adoption_demo/`
- `Rindle.Admin.Router` documentation and code
- `Rindle.Domain.MediaAsset` source for state vocabularies
