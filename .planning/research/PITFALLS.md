# Pitfalls Research

**Domain:** First public Hex package publication
**Researched:** 2026-04-28
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: Treating dry-run as equivalent to a real publish

**What goes wrong:** the workflow passes `mix hex.publish --dry-run`, but the
first real upload still fails because ownership, auth, docs upload, or public
package resolution was never exercised.

**How to avoid:** keep dry-run as a preflight gate, but require one real
publish and one post-publish install proof in this milestone.

### Pitfall 2: Publishing with an overly broad or poorly protected API key

**What goes wrong:** a write credential lives in the wrong secret scope or can
run from unintended refs, increasing the blast radius of a publish secret.

**How to avoid:** use the existing protected GitHub `release` environment and a
publish-specific key with only the needed write permission.

### Pitfall 3: Forgetting that docs publish is part of package publish

**What goes wrong:** package publication succeeds but docs generation or hosted
docs expectations drift, leaving the first public release with broken docs.

**How to avoid:** gate on docs parity and explicit docs build success before the
real publish step, then verify the published docs path afterward.

### Pitfall 4: Shipping the wrong tarball contents

**What goes wrong:** generated files, missing guides, or stale package metadata
slip into the published tarball even though repo-local tests still pass.

**How to avoid:** keep `mix hex.build --unpack` and explicit required/prohibited
path assertions as must-pass gates before live publish.

### Pitfall 5: Making the first publish too automatic

**What goes wrong:** a tag or workflow path can push a public package before
maintainers have deliberately observed the release output and owner state.

**How to avoid:** make the first real publish a protected, deliberate flow with
clear rollback steps; only then normalize it into routine release automation.

## Sources

- https://hex.pm/docs/publish
- https://hex.pm/docs/faq
- https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html

---
*Pitfalls research for: Rindle first Hex publish*
