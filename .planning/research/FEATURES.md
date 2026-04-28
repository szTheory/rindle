# Feature Research

**Domain:** First public package publication and reusable release workflow
**Researched:** 2026-04-28
**Confidence:** HIGH

## Feature Landscape

### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Complete package metadata | Hex packages need accurate description, license, links, versioning, and file inclusion | LOW | First publish should not rely on implicit defaults staying correct |
| Protected publish credential path | Real publication needs authenticated `api:write` access | MEDIUM | Prefer environment-scoped CI secret over ad hoc local auth |
| Pre-publish artifact inspection | Maintainers need to see exactly what ships | LOW | `mix hex.build --unpack` is the official low-risk gate |
| Docs build parity | Publishing a package also publishes docs | MEDIUM | Broken `mix docs` means broken publish |
| Consumer install verification | Publish success is not enough; package must resolve and install for adopters | MEDIUM | Existing smoke should be reused against the public package |
| Revert/runbook guidance | First publish is high-leverage and partly irreversible | LOW | Hex supports reverting a version shortly after publish |

### Differentiators

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| Publish flow proven from the same repo that already proves built-artifact install | Connects release readiness to the real distribution channel | MEDIUM | Builds directly on Phase 9 instead of replacing it |
| Guarded automation that can publish for real without bypassing review | Makes future releases routine without making the first publish reckless | MEDIUM | Existing `release` environment is the right control point |
| Post-publish smoke that resolves Rindle from Hex.pm instead of local path packaging | Proves the registry/CDN/docs path, not only tarball correctness | MEDIUM | Closes the last outside-in trust gap |

### Anti-Features

| Feature | Why It Sounds Useful | Why It Hurts | Alternative |
|---------|----------------------|-------------|-------------|
| Auto-publish on every tag immediately | Feels fast and hands-off | First publish should be deliberate and observable; failures are harder to contain | Manual dispatch or tightly controlled tagged release path first |
| Publishing and broad API redesign in one milestone | "Do all release-facing cleanup at once" | Mixes distribution proof with product-surface decisions | Keep API cleanup separate unless it blocks publish |
| Relying only on dry-run publish | Dry-run is safer | Does not prove real registry upload, docs hosting, owner state, or public install | Use dry-run as a gate, then do one real publish |

## Milestone-Appropriate Scope

### In Scope for v1.2

- first real `Hex.pm` publish path
- protected credential and ownership setup for publish
- release workflow automation that can perform a real publish
- docs/package/build gates that fail before publish
- post-publish install verification from Hex.pm
- maintainer-facing release checklist and rollback guidance

### Deferred

- public API ergonomics cleanup unrelated to publish blockers
- GCS, tus, or other new upload protocol work
- broader release tooling abstraction beyond the native `mix hex.*` path

## Sources

- https://hex.pm/docs/publish
- https://hex.pm/docs/faq
- https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html

---
*Feature research for: Rindle first Hex publish*
