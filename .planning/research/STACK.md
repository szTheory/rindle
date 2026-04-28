# Stack Research

**Domain:** First public Hex.pm publish and repeatable release automation for
Rindle
**Researched:** 2026-04-28
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Hex CLI | 2.2.1 | Package build and publish toolchain | Official publish path for Elixir packages; `mix hex.build` validates package metadata and contents before publish |
| ExDoc | current project dependency (`~> 0.40`) | HexDocs generation during publish | Hex publishes docs automatically by running `mix docs`, so local docs generation is part of the release contract |
| GitHub Actions | current repo workflows | Protected automation entrypoint | Existing `release` workflow and environment gating already provide the narrow place to add a real `HEX_API_KEY` |
| `erlef/setup-beam` | current repo workflow action | Deterministic Elixir/OTP setup in CI | Reuses the same toolchain already proving package-consumer smoke and release checks |

### Supporting Tools

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `mix hex.build --unpack` | Inspect exact tarball contents locally or in CI | Must-pass gate before any real publish |
| `mix hex.publish package --dry-run --yes` | Validate package publish path without a real upload | Metadata and auth gate before wiring live publish |
| `mix hex.publish --yes` | Real package + docs publication | Only from the protected first-publish workflow or a deliberate manual maintainer run |
| `mix hex.publish --revert VERSION` | Revert a broken just-published version | Immediate rollback path if the first publish is wrong |
| Existing `scripts/install_smoke.sh` | Fresh-consumer install proof | Reuse post-publish against the version resolved from Hex.pm, not only the unpacked tarball |

## Recommended Additions

| Addition | Purpose | Why |
|----------|---------|-----|
| Real `HEX_API_KEY` release secret in the GitHub `release` environment | Enables real publish from CI | Current workflow uses a dry-run placeholder; first public publish needs a scoped write key |
| Explicit publish/owner documentation | Removes ambiguity around personal vs organization ownership | Hex asks for ownership management on first publish; this should not be decided ad hoc during the cut |
| Changelog or release notes artifact | Human-readable release record | Keeps first publish and future releases tied to a documented version narrative |

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| Third-party release orchestration before first publish is exercised | Adds moving parts before the base path is proven | Use `mix hex.*` directly first |
| Repo-level unprotected `HEX_API_KEY` secret | Broadens blast radius for a write credential | Use the existing protected `release` environment |
| Broader API cleanup in this milestone | Expands scope away from the publish goal | Keep API review as a later milestone unless a publish blocker appears |

## Integration Notes

- Rindle already has the key building blocks: `package/0` metadata in
  `mix.exs`, package-consumer smoke in CI, and a release workflow with a
  `release` environment.
- The current release lane proves `mix hex.build --unpack`, tarball contents,
  package-consumer smoke, docs parity, and an auth-tolerant dry-run publish.
- The missing stack piece is a real publish credential and the workflow changes
  around when and how an irreversible publish is allowed to happen.

## Sources

- https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html
- https://hex.pm/docs/publish
- https://hex.pm/docs/faq

---
*Stack research for: Rindle first Hex publish*
