# Project Research Summary

**Project:** Rindle
**Domain:** First public Hex package publication and reusable release workflow
**Researched:** 2026-04-28
**Confidence:** HIGH

## Executive Summary

Rindle already has most of the technical release substrate in place: package
metadata in `mix.exs`, a release workflow with protected `release`
environment wiring, built-artifact consumer smoke, and docs parity checks. The
remaining gap is not "how to package an Elixir library" but "how to turn the
existing dry-run release proof into one real, guarded, repeatable public
publish path."

Official Hex guidance keeps the publish flow intentionally simple:
`mix hex.build` to inspect the package, `mix hex.publish` to publish the
package and docs, and `HEX_API_KEY` for CI automation. That simplicity is also
the main risk: if Rindle wires a real publish step without strong preflight,
protected secrets, and post-publish install verification, the first release
will be technically easy but operationally under-proved.

## Key Findings

### Stack Additions

- No new runtime dependencies are required for this milestone.
- The key stack additions are operational:
  - a real `HEX_API_KEY` bound to the GitHub `release` environment
  - explicit maintainer docs for owner/auth setup and rollback
  - post-publish verification that resolves from Hex.pm instead of a local path

### Feature Table Stakes

- package metadata completeness in `mix.exs`
- unpacked tarball inspection before publish
- protected auth path for a real publish
- docs build parity before publish
- consumer install verification after publish
- maintainer rollback/revert guidance

### Watch Out For

- `--dry-run` is necessary but not sufficient
- docs publishing is coupled to package publishing
- the publish secret must stay environment-scoped and review-protected
- the first publish should be deliberate before it becomes routine

## Implications for Requirements

The milestone should stay narrowly centered on release distribution proof. That
means requirements should cover:

1. first-publish readiness and metadata/ownership correctness
2. real publish automation behind protected controls
3. preflight guards that fail before any live publication
4. post-publish consumer verification from Hex.pm
5. maintainer-facing release and rollback documentation

## Sources

- https://hex.pm/docs/publish
- https://hex.pm/docs/faq
- https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html

---
*Research completed: 2026-04-28*
