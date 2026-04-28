# Architecture Research

**Domain:** Release-path integration for first Hex publication
**Researched:** 2026-04-28
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
maintainer/version bump
        |
        v
mix.exs package metadata + docs config
        |
        v
release workflow preflight
  - mix hex.build --unpack
  - tarball assertions
  - package-consumer smoke
  - docs parity / mix docs gate
  - dry-run publish
        |
        v
protected publish step
  - release environment
  - HEX_API_KEY
  - mix hex.publish --yes
        |
        v
post-publish verification
  - fetch/install from Hex.pm
  - docs availability
  - release notes / rollback instructions
```

## Integration Points

| Component | Responsibility | Current State | Likely Work |
|-----------|----------------|---------------|-------------|
| `mix.exs` | Package metadata, version, docs metadata | Present and mostly ready | Tighten metadata and any missing publish-facing fields |
| `.github/workflows/release.yml` | Release gating and publish automation | Already has build, smoke, docs parity, dry-run | Add real publish step and safer trigger policy |
| `README.md` / guides | Consumer-facing install and release guidance | Built-artifact path is documented | Add public package path and maintainer release steps |
| `scripts/install_smoke.sh` and helper tests | Outside-in adopter proof | Uses built package path today | Add or adapt to verify the published version from Hex.pm |
| GitHub `release` environment | Secret and approval boundary | Already declared in workflow | Bind real `HEX_API_KEY` and document required setup |

## Suggested Build Order

1. Finalize package metadata, ownership decision, and version/publish checklist.
2. Upgrade release workflow from dry-run-only to real-publish-capable with
   protected triggers.
3. Add post-publish verification that resolves Rindle from Hex.pm.
4. Update maintainer docs so future releases reuse the same path.

## Architecture Constraints

- The first publish should reuse the native Hex toolchain instead of introducing
  a second release abstraction.
- The real publish step must remain behind the existing `release` environment.
- The same release lane should validate both package contents and consumer
  installability before any live publish happens.
- Future routine releases should reuse the first-publish path instead of having
  a separate "special first release" process that will immediately rot.

## Sources

- https://hex.pm/docs/publish
- https://hex.pm/docs/faq
- https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html

---
*Architecture research for: Rindle first Hex publish*
