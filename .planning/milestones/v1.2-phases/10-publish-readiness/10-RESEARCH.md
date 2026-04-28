# Phase 10: Publish Readiness - Research

**Researched:** 2026-04-28 [VERIFIED: current date]
**Domain:** Hex.pm first-public-package readiness, package metadata, docs generation, and release preflight visibility [VERIFIED: .planning/ROADMAP.md]
**Confidence:** MEDIUM [VERIFIED: synthesis of sources below]

<user_constraints>
## User Constraints

No phase-local `CONTEXT.md` exists for Phase 10, so there are no additional locked decisions beyond the roadmap, requirements, and project files already loaded. [VERIFIED: init.phase-op output (has_context=false) (2026-04-28)]

### Locked Decisions

- Phase 10 must keep scope to publish readiness and preflight visibility, not live `Hex.pm` publication automation. [VERIFIED: .planning/ROADMAP.md]
- Phase 10 must satisfy `RELEASE-04` and `RELEASE-05`. [VERIFIED: .planning/REQUIREMENTS.md]
- Phase 10 already has two roadmap plans: one for metadata/versioning/runbook work and one for tarball/docs preflight hardening. [VERIFIED: .planning/ROADMAP.md]

### Claude's Discretion

- Exact file names and structure for maintainer-facing release guides. [ASSUMED]
- Exact shape of the tarball/docs verification helpers and tests, as long as they stay aligned with official `mix hex.*` and `mix docs` behavior. [VERIFIED: .planning/ROADMAP.md] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] [CITED: https://hexdocs.pm/ex_doc/ExDoc.html]

### Deferred Ideas (OUT OF SCOPE)

- Live `HEX_API_KEY` publication and protected publish execution belong to Phase 11, not Phase 10. [VERIFIED: .planning/ROADMAP.md]
- Post-publish verification from public `Hex.pm` belongs to Phase 12, not Phase 10. [VERIFIED: .planning/ROADMAP.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| RELEASE-04 | Maintainer can prepare Rindle for its first public `Hex.pm` publish with explicit package metadata, owner/auth setup, and a documented versioning/release checklist. [VERIFIED: .planning/REQUIREMENTS.md] | Phase 10 should add explicit `mix.exs` release metadata review, a maintainer runbook covering `mix hex.user` / `mix hex.owner` expectations, and a documented version bump checklist because current repo docs do not mention Hex publishing, owners, or release versioning steps. [VERIFIED: README.md] [VERIFIED: guides/getting_started.md] [VERIFIED: rg -n "Hex|publish|owner|version" README.md guides (2026-04-28)] [CITED: https://hex.pm/docs/publish] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Owner.html] |
| RELEASE-05 | Maintainer can inspect the exact package tarball and docs build output before any live publish occurs. [VERIFIED: .planning/REQUIREMENTS.md] | Use `mix hex.build --unpack` as the official package inspection path, inspect generated `hex_metadata.config`, and add an explicit docs build gate because current release workflow only runs `mix hex.publish package --dry-run`, which skips docs publication behavior. [VERIFIED: mix hex.build --unpack (2026-04-28)] [VERIFIED: rindle-0.1.0-dev/hex_metadata.config] [VERIFIED: .github/workflows/release.yml] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html] [CITED: https://hex.pm/docs/publish] |
</phase_requirements>

## Summary

Phase 10 is not a packaging-from-scratch phase. Rindle already has the basic Hex package surface in `mix.exs`, a buildable unpacked artifact from `mix hex.build --unpack`, an existing release workflow with tarball presence/absence assertions, and a package-consumer smoke lane inherited from Phase 9. [VERIFIED: mix.exs] [VERIFIED: mix hex.build --unpack (2026-04-28)] [VERIFIED: .github/workflows/release.yml] [VERIFIED: .github/workflows/ci.yml] [VERIFIED: .planning/milestones/v1.1-phases/09-RESEARCH.md]

The remaining trust gap is that first-publish knowledge still lives mostly in maintainer inference. Current public docs teach adopter installation, not maintainer release operations; current workflow comments mention future `HEX_API_KEY` wiring, but there is no release-facing guide for owner setup, first publisher expectations, version bump policy, or revert windows. [VERIFIED: README.md] [VERIFIED: guides/getting_started.md] [VERIFIED: .github/workflows/release.yml] [CITED: https://hex.pm/docs/publish] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Owner.html] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html]

The most important technical finding is that the current release lane does not actually exercise docs publication behavior. It runs `mix hex.publish package --dry-run --yes`, and official Hex documentation states that `mix hex.publish package` publishes a package without documentation while full `mix hex.publish` generates and publishes docs. That means Phase 10 needs an explicit docs build gate before any future live publish step can be considered safe. [VERIFIED: .github/workflows/release.yml] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html] [CITED: https://hex.pm/docs/publish]

**Primary recommendation:** Split Phase 10 exactly along the roadmap boundary: Plan 10-01 should make metadata, ownership, versioning, and first-publish runbook inputs explicit; Plan 10-02 should harden preflight verification around `mix hex.build --unpack`, `hex_metadata.config`, and `mix docs --warnings-as-errors` before Phase 11 ever receives a real publish key. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: mix help docs (2026-04-28)] [VERIFIED: mix help hex.build (2026-04-28)] [VERIFIED: mix help hex.publish (2026-04-28)]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Package metadata and semantic version declaration | API / Backend [ASSUMED] | CDN / Static [ASSUMED] | `mix.exs` and Hex package metadata are build-time backend concerns, but they directly shape the published static package surface. [VERIFIED: mix.exs] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] |
| Tarball assembly and inspection | API / Backend [ASSUMED] | CDN / Static [ASSUMED] | `mix hex.build --unpack` runs in the build pipeline, then produces the exact static contents consumers download. [VERIFIED: mix hex.build --unpack (2026-04-28)] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] |
| Docs generation and release-guide parity | CDN / Static [ASSUMED] | API / Backend [ASSUMED] | ExDoc emits static HTML/Markdown/EPUB output, but the release pipeline must invoke and gate it correctly. [VERIFIED: mix docs (2026-04-28)] [VERIFIED: doc/index.html exists after generation (2026-04-28)] [CITED: https://hexdocs.pm/ex_doc/ExDoc.html] [CITED: https://hexdocs.pm/ex_doc/0.38.1/Mix.Tasks.Docs.html] |
| Publish ownership and API-key expectations | API / Backend [ASSUMED] | — | Owner assignment, API keys, and release environment controls are workflow and access-control concerns rather than consumer-facing static assets. [VERIFIED: .github/workflows/release.yml] [VERIFIED: mix help hex.owner (2026-04-28)] [VERIFIED: mix help hex.user (2026-04-28)] [CITED: https://hex.pm/docs/publish] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Hex CLI | `2.4.1` [VERIFIED: mix help hex.publish (2026-04-28)] | Own package build, owner management, dry-run publish behavior, and auth UX. [VERIFIED: mix help hex.build (2026-04-28)] [VERIFIED: mix help hex.publish (2026-04-28)] [VERIFIED: mix help hex.owner (2026-04-28)] [VERIFIED: mix help hex.user (2026-04-28)] | Phase 10 should stay on official `mix hex.*` tasks instead of inventing wrapper semantics before first publish is even proven. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html] |
| ExDoc | `0.40.1` [VERIFIED: mix hex.info ex_doc (2026-04-28)] | Generate the docs output that Hex expects in `doc/` with `index.html`. [VERIFIED: mix docs (2026-04-28)] [CITED: https://hexdocs.pm/ex_doc/0.38.1/Mix.Tasks.Docs.html] | Hex publish relies on a real docs build; ExDoc is already installed and configured in this repo. [VERIFIED: mix.exs] [CITED: https://hex.pm/docs/publish] |
| Existing GitHub Actions release lane | `actions/checkout@v4`, `actions/cache@v4`, `erlef/setup-beam@v1` [VERIFIED: .github/workflows/release.yml] | Provide the current release-preflight execution context that Phase 10 should harden, not replace. [VERIFIED: .github/workflows/release.yml] | The repo already centralizes release checks here, so Phase 10 should tighten this lane rather than create a second release system. [VERIFIED: .github/workflows/release.yml] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `mix docs --warnings-as-errors` | ExDoc task option [VERIFIED: mix help docs (2026-04-28)] | Turn docs warnings into a blocking release signal. [VERIFIED: mix help docs (2026-04-28)] | Use in Phase 10 because current `mix docs` succeeds with warnings from `Rindle.LiveView.allow_upload/4`, which is too weak for release gating. [VERIFIED: mix docs (2026-04-28)] |
| `hex_metadata.config` from unpacked artifact | Generated by Hex build [VERIFIED: rindle-0.1.0-dev/hex_metadata.config] | Inspect exact package metadata as shipped, not just the source `mix.exs`. [VERIFIED: rindle-0.1.0-dev/hex_metadata.config] | Use whenever preflight needs to assert package name, version, licenses, files, and links from the built artifact. [VERIFIED: rindle-0.1.0-dev/hex_metadata.config] |
| Existing docs parity test | ExUnit file `test/install_smoke/docs_parity_test.exs` [VERIFIED: test/install_smoke/docs_parity_test.exs] | Guard canonical adopter docs against README drift. [VERIFIED: test/install_smoke/docs_parity_test.exs] | Keep using it, but expand Phase 10 checks to maintainer/release docs because current assertions only cover adopter install guidance. [VERIFIED: test/install_smoke/docs_parity_test.exs] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Official `mix hex.build --unpack` inspection [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] | Manual `tar` extraction of a built package [ASSUMED] | Manual extraction can work, but `--unpack` is the official inspection path and also emits `hex_metadata.config`, which is more useful for repeatable tests. [VERIFIED: mix hex.build --unpack (2026-04-28)] |
| Explicit docs build gate (`mix docs --warnings-as-errors`) [VERIFIED: mix help docs (2026-04-28)] | Rely only on `mix hex.publish package --dry-run` [VERIFIED: .github/workflows/release.yml] | `package --dry-run` skips docs publication behavior, so it cannot satisfy `RELEASE-05` on its own. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html] |
| Release guide as repo documentation [VERIFIED: requirement scope in .planning/ROADMAP.md] | Workflow comments only [VERIFIED: .github/workflows/release.yml] | Workflow comments are not discoverable enough for first-publish owner setup, versioning, or rollback expectations. [VERIFIED: .github/workflows/release.yml] [VERIFIED: rg -n "Hex|publish|owner|version" README.md guides (2026-04-28)] |

**Installation / verification commands:** [VERIFIED: mix help hex.build (2026-04-28)] [VERIFIED: mix help docs (2026-04-28)] [VERIFIED: mix help hex.publish (2026-04-28)]

```bash
mix hex.build --unpack
mix docs --warnings-as-errors
mix hex.publish package --dry-run --yes
mix test test/install_smoke/docs_parity_test.exs
```

**Version verification:** [VERIFIED: mix help hex.publish (2026-04-28)] [VERIFIED: mix hex.info ex_doc (2026-04-28)]

- Hex CLI observed locally: `2.4.1`. [VERIFIED: mix help hex.publish (2026-04-28)]
- ExDoc latest release observed from registry output: `0.40.1`. [VERIFIED: mix hex.info ex_doc (2026-04-28)]

## Architecture Patterns

### System Architecture Diagram

```text
mix.exs package/docs config
  -> mix hex.build --unpack
    -> unpacked artifact directory
      -> inspect shipped files
      -> inspect hex_metadata.config
        -> pass/fail package metadata preflight

maintainer release guide + README/guides
  -> docs parity tests
  -> mix docs --warnings-as-errors
    -> doc/index.html + doc artifacts
      -> pass/fail docs preflight

Hex owner/auth expectations
  -> maintainer runbook
    -> local auth path for first publish
    -> future GitHub release environment key path
      -> Phase 11 live automation

release.yml
  -> tarball checks
  -> package-consumer smoke
  -> docs build gate
  -> optional/local-only dry-run publish proof
    -> safe handoff to live publish phase
```

### Recommended Project Structure

```text
guides/
├── getting_started.md      # canonical adopter install path
├── release_publish.md      # new maintainer-facing first-publish and versioning runbook
└── operations.md           # keep runtime/day-2 ops separate from release steps

test/install_smoke/
├── docs_parity_test.exs    # existing adopter docs parity
└── package_metadata_test.exs  # new Phase 10 metadata/tarball assertions

scripts/
└── release_preflight.sh    # optional single entrypoint if CI and release need the same docs/package checks
```

### Pattern 1: Metadata-As-Built, Not Metadata-As-Source

**What:** Assert release metadata from the unpacked artifact and `hex_metadata.config`, not only from `mix.exs`. [VERIFIED: rindle-0.1.0-dev/hex_metadata.config] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html]

**When to use:** Use for any check that claims "this is what will ship to Hex.pm." [VERIFIED: .planning/ROADMAP.md]

**Example:**

```elixir
# Source: generated artifact inspection in this repo
metadata = File.read!("rindle-0.1.0-dev/hex_metadata.config")
assert metadata =~ ~s({<<"name">>,<<"rindle">>})
assert metadata =~ ~s({<<"licenses">>,[<<"MIT">>]})
```

### Pattern 2: Separate Docs Build Gate From Package-Only Dry Run

**What:** Run `mix docs --warnings-as-errors` independently of `mix hex.publish package --dry-run`. [VERIFIED: mix help docs (2026-04-28)] [VERIFIED: .github/workflows/release.yml] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html]

**When to use:** Use whenever the release lane still avoids full `mix hex.publish --dry-run` because auth or live publish controls are not ready yet. [VERIFIED: .github/workflows/release.yml]

**Example:**

```bash
# Source: official Mix/ExDoc help plus current repo gap
mix docs --warnings-as-errors
mix hex.build --unpack
mix test test/install_smoke/docs_parity_test.exs
```

### Pattern 3: Publish Runbook Separate From Live Publish Automation

**What:** Document first-publish owner/auth/versioning steps in repo docs now, then wire the real publish key later in Phase 11. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .github/workflows/release.yml]

**When to use:** Use when a phase must make release posture explicit without yet introducing a write-capable `HEX_API_KEY`. [VERIFIED: .planning/ROADMAP.md]

**Example:**

```text
1. Confirm target version in mix.exs.
2. Build and inspect unpacked artifact.
3. Build docs with warnings treated as failures.
4. Confirm publish owner path and key source.
5. Only then proceed to Phase 11 live publish automation.
```

### Anti-Patterns to Avoid

- **Assuming `mix hex.publish package --dry-run` covers docs:** official Hex behavior says it skips docs publication. [VERIFIED: .github/workflows/release.yml] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html]
- **Treating workflow comments as the release runbook:** comments are helpful context, but they do not satisfy explicit maintainer-facing documentation requirements. [VERIFIED: .github/workflows/release.yml] [VERIFIED: .planning/REQUIREMENTS.md]
- **Leaving owner model implicit until publish day:** first publisher becomes the package owner, and owner permissions are stronger than normal release permissions. [VERIFIED: mix help hex.publish (2026-04-28)] [VERIFIED: mix help hex.owner (2026-04-28)] [CITED: https://hex.pm/docs/publish]
- **Allowing doc warnings to pass silently:** current `mix docs` completed with warnings, which means a non-blocking docs build is not strict enough for release readiness. [VERIFIED: mix docs (2026-04-28)]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Package assembly and inspection | Custom tarball builder or ad hoc shell packaging [ASSUMED] | `mix hex.build --unpack` [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] | Hex already defines the exact package format and emits inspectable unpacked contents plus metadata. [VERIFIED: mix hex.build --unpack (2026-04-28)] |
| Owner and publish privilege model | Repo-local ownership registry [ASSUMED] | `mix hex.owner` and `mix hex.user` [VERIFIED: mix help hex.owner (2026-04-28)] [VERIFIED: mix help hex.user (2026-04-28)] | Hex owns the real package ACL model; duplicating it locally creates drift and false confidence. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Owner.html] |
| Docs publication semantics | Custom docs uploader [ASSUMED] | `mix docs` plus Hex publish flow [CITED: https://hex.pm/docs/publish] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html] | Hex already expects docs under `doc/` and auto-publishes them on full publish. [CITED: https://hex.pm/docs/publish] |

**Key insight:** Phase 10 should strengthen the official Hex and ExDoc path, not create an alternative release abstraction before the first real publish is proven. [VERIFIED: .planning/ROADMAP.md] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html]

## Common Pitfalls

### Pitfall 1: Package Dry Run Mistaken For Full Release Dry Run

**What goes wrong:** Maintainers believe the release workflow validated docs because it ran a Hex dry-run command. [VERIFIED: .github/workflows/release.yml]
**Why it happens:** The workflow uses `mix hex.publish package --dry-run --yes`, and official Hex docs distinguish that from full `mix hex.publish`, which generates and publishes docs. [VERIFIED: .github/workflows/release.yml] [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html]
**How to avoid:** Add a separate blocking docs build in Phase 10, then keep full live publish behavior for Phase 11. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: mix help docs (2026-04-28)]
**Warning signs:** Release lane passes even though `mix docs --warnings-as-errors` would fail or docs pages are broken. [VERIFIED: mix docs (2026-04-28)]

### Pitfall 2: Owner Setup Deferred Until Publish Day

**What goes wrong:** The initial publisher becomes the effective package owner without a documented post-publish owner-add step. [VERIFIED: mix help hex.publish (2026-04-28)] [VERIFIED: mix help hex.owner (2026-04-28)]
**Why it happens:** Current repo docs do not mention `mix hex.owner`, owner levels, or first-publish ownership transfer. [VERIFIED: rg -n "hex.owner|owner|publish" README.md guides (2026-04-28)]
**How to avoid:** Add a maintainer runbook that records the intended owner path before any live publish. [VERIFIED: .planning/REQUIREMENTS.md]
**Warning signs:** Release instructions mention `HEX_API_KEY` but do not say who should own the package or who adds maintainers afterward. [VERIFIED: .github/workflows/release.yml]

### Pitfall 3: Docs Warnings Allowed In Release Readiness

**What goes wrong:** Documentation builds succeed with warnings that could leave broken or misleading API references in HexDocs. [VERIFIED: mix docs (2026-04-28)]
**Why it happens:** ExDoc only fails warnings when `--warnings-as-errors` is passed. [VERIFIED: mix help docs (2026-04-28)]
**How to avoid:** Make warnings fatal in Phase 10 and fix the existing `Phoenix.LiveView.Upload.allow_upload/3` hidden-reference warnings. [VERIFIED: mix docs (2026-04-28)]
**Warning signs:** `mix docs` exits `0` while printing warnings. [VERIFIED: mix docs (2026-04-28)]

### Pitfall 4: Maintainer Release Guidance Mixed Into Adopter Onboarding

**What goes wrong:** The public onboarding docs become cluttered with maintainer-only release steps. [ASSUMED]
**Why it happens:** README and `guides/getting_started.md` currently serve adopter installation, not release operations. [VERIFIED: README.md] [VERIFIED: guides/getting_started.md]
**How to avoid:** Keep a distinct maintainer-facing release guide and preserve README/getting-started as consumer docs. [VERIFIED: README.md] [VERIFIED: guides/getting_started.md]
**Warning signs:** README starts mentioning API keys, owner transfer, or rollback steps that do not matter to package adopters. [ASSUMED]

## Code Examples

Verified patterns from official sources:

### Build And Inspect The Shipped Package

```bash
# Source: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html
mix hex.build --unpack
```

### Publish Without Docs Versus Full Publish

```bash
# Source: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html
mix hex.publish package
mix hex.publish docs
mix hex.publish --dry-run --yes
```

### Add A Maintainer After First Publish

```bash
# Source: https://hexdocs.pm/hex/Mix.Tasks.Hex.Owner.html
mix hex.owner add PACKAGE EMAIL_OR_USERNAME --level maintainer
```

### Build Docs With Warning Enforcement

```bash
# Source: local `mix help docs` on 2026-04-28
mix docs --warnings-as-errors
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Repo confidence centered on built-artifact install smoke and release tarball assertions. [VERIFIED: .planning/milestones/v1.1-phases/09-RESEARCH.md] [VERIFIED: .github/workflows/release.yml] | Phase 10 should extend that proof to maintainer-facing publish readiness with explicit metadata, owner/runbook documentation, and docs build gating. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .planning/REQUIREMENTS.md] | `v1.2` roadmap definition on `2026-04-28`. [VERIFIED: .planning/ROADMAP.md] | Planning should optimize for release clarity and preflight visibility, not new runtime features. [VERIFIED: .planning/ROADMAP.md] |
| Package-only dry-run warning tolerance in release workflow. [VERIFIED: .github/workflows/release.yml] | Separate docs build gate plus stricter package metadata assertions. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: mix help docs (2026-04-28)] | Not yet implemented; this is the target state for Phase 10. [VERIFIED: .planning/ROADMAP.md] | Prevents a future live publish path from bypassing docs validation. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html] |

**Deprecated/outdated:**

- Treating release workflow comments as the only publish runbook is outdated for this milestone because `RELEASE-04` requires explicit maintainer documentation. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: .github/workflows/release.yml]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A new maintainer-facing file such as `guides/release_publish.md` is the best place for Phase 10 release documentation. [ASSUMED] | Architecture Patterns | Low; file location can change without changing the phase intent. |
| A2 | README should stay adopter-focused and should not become the primary release runbook. [ASSUMED] | Common Pitfalls | Low; even if README gets a short maintainer section, the key need is still a dedicated explicit runbook somewhere in-repo. |
| A3 | Package metadata assertions are best expressed as a dedicated ExUnit or shell-based preflight helper rather than only inline workflow YAML. [ASSUMED] | Recommended Project Structure | Low; implementation vehicle can change while keeping the required gate behavior. |
| A4 | The intended first-public version is likely `0.1.0` rather than `0.1.0-dev`. [ASSUMED] | Open Questions | Medium; if wrong, release docs and checklist could encode the wrong versioning expectation. |
| A5 | The eventual owner model may be personal-first or organization-first, but it must be recorded explicitly during Phase 10. [ASSUMED] | Open Questions | Medium; Phase 11 key wiring depends on who should hold publish authority. |

## Open Questions

1. **What exact owner model should the first public package use?**
   - What we know: The current authenticated publisher becomes the package owner, and `mix hex.owner` supports adding maintainers or transferring ownership. [VERIFIED: mix help hex.publish (2026-04-28)] [VERIFIED: mix help hex.owner (2026-04-28)]
   - What's unclear: Whether Rindle should publish first under a personal Hex account and then add maintainers, or whether a Hex organization already exists and should own the package immediately. [ASSUMED]
   - Recommendation: Phase 10 should require this to be written down in the runbook even if the live key is deferred to Phase 11. [VERIFIED: .planning/REQUIREMENTS.md]

2. **What version should the first public release actually cut?**
   - What we know: `mix.exs` currently declares `0.1.0-dev`, while public install docs show `~> 0.1` dependency examples. [VERIFIED: mix.exs] [VERIFIED: README.md] [VERIFIED: guides/getting_started.md]
   - What's unclear: Whether the first public publish should normalize to `0.1.0` or another semver target. [ASSUMED]
   - Recommendation: Plan 10-01 should include a single authoritative version bump step and a rule for future prerelease versus release tags. [VERIFIED: .planning/ROADMAP.md] [CITED: https://hex.pm/docs/publish]

3. **Should docs warnings be fixed in code comments/docstrings during Phase 10 or only gated?**
   - What we know: `mix docs` currently warns about references to hidden `Phoenix.LiveView.Upload.allow_upload/3`. [VERIFIED: mix docs (2026-04-28)]
   - What's unclear: Whether the fix belongs to release readiness now or can be deferred until docs gating exists. [ASSUMED]
   - Recommendation: Treat warning cleanup as in-scope for Plan 10-02 because release readiness without warning-free docs is weak. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `mix` | All package/docs verification commands | ✓ [VERIFIED: command -v mix (2026-04-28)] | `1.19.5` [VERIFIED: mix --version (2026-04-28)] | — |
| Hex archive | `mix hex.build`, `mix hex.publish`, `mix hex.owner`, `mix hex.user` | ✓ [VERIFIED: mix help hex.publish (2026-04-28)] | `2.4.1` [VERIFIED: mix help hex.publish (2026-04-28)] | — |
| Docker | MinIO-backed install smoke and release workflow parity | ✓ [VERIFIED: docker --version (2026-04-28)] | `29.4.0` [VERIFIED: docker --version (2026-04-28)] | CI can still run even if a local maintainer machine lacks Docker, but local smoke parity is weaker. [ASSUMED] |
| `vips` / `libvips` CLI | Full local image-processing proof in adopter/install flows | ✗ [VERIFIED: command -v vips returned no path (2026-04-28)] | — | Use CI for the full proof or install `libvips` locally before running deep smoke. [VERIFIED: guides/getting_started.md] |
| MinIO client `mc` | Workflow bucket bootstrap | ✗ [VERIFIED: command -v mc returned no path (2026-04-28)] | — | Workflow already installs it on demand. [VERIFIED: .github/workflows/ci.yml] [VERIFIED: .github/workflows/release.yml] |
| `node` / `npm` | Context7 CLI fallback and optional scripting | ✓ [VERIFIED: node --version (2026-04-28)] [VERIFIED: npm --version (2026-04-28)] | `v22.14.0` / `11.1.0` [VERIFIED: node --version (2026-04-28)] [VERIFIED: npm --version (2026-04-28)] | — |

**Missing dependencies with no fallback:**

- None for writing Phase 10 plans. [VERIFIED: environment audit above (2026-04-28)]

**Missing dependencies with fallback:**

- Local `vips` is missing, but CI already provides full package-consumer and release-lane verification with installed native deps. [VERIFIED: command -v vips returned no path (2026-04-28)] [VERIFIED: .github/workflows/ci.yml] [VERIFIED: .github/workflows/release.yml]
- Local `mc` is missing, but workflows install it dynamically. [VERIFIED: command -v mc returned no path (2026-04-28)] [VERIFIED: .github/workflows/ci.yml] [VERIFIED: .github/workflows/release.yml]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit via Mix test tasks. [VERIFIED: test/install_smoke/docs_parity_test.exs] |
| Config file | `test/test_helper.exs` plus project `mix test` alias in `mix.exs`. [VERIFIED: mix.exs] [VERIFIED: test directory layout via repo files (2026-04-28)] |
| Quick run command | `mix test test/install_smoke/docs_parity_test.exs` [VERIFIED: .github/workflows/release.yml] |
| Full suite command | `mix test` plus package/docs preflight commands for release work. [VERIFIED: mix.exs] [VERIFIED: .github/workflows/ci.yml] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| RELEASE-04 | Maintainer-facing release metadata, owner/auth expectations, and versioning checklist are explicit. [VERIFIED: .planning/REQUIREMENTS.md] | docs / policy gate [ASSUMED] | `mix test test/install_smoke/docs_parity_test.exs` is partial only; a new release-doc parity check is needed. [VERIFIED: test/install_smoke/docs_parity_test.exs] | ❌ Wave 0 [VERIFIED: no release-doc parity file found by repo inspection (2026-04-28)] |
| RELEASE-05 | Maintainer can inspect exact package contents and docs build output before live publish. [VERIFIED: .planning/REQUIREMENTS.md] | build + smoke | `mix hex.build --unpack && mix docs --warnings-as-errors` [VERIFIED: mix help hex.build (2026-04-28)] [VERIFIED: mix help docs (2026-04-28)] | ❌ Wave 0 for unified gate [VERIFIED: .github/workflows/release.yml lacks `mix docs --warnings-as-errors` (2026-04-28)] |

### Sampling Rate

- **Per task commit:** `mix test test/install_smoke/docs_parity_test.exs` for docs edits, plus the smallest new metadata/doc gate added by the plan. [VERIFIED: test/install_smoke/docs_parity_test.exs] [ASSUMED]
- **Per wave merge:** `mix hex.build --unpack && mix docs --warnings-as-errors` once the new preflight exists. [VERIFIED: mix help hex.build (2026-04-28)] [VERIFIED: mix help docs (2026-04-28)]
- **Phase gate:** Updated release preflight green before `/gsd-verify-work`. [VERIFIED: .planning/config.json]

### Wave 0 Gaps

- [ ] `test/install_smoke/release_docs_parity_test.exs` or equivalent — verify release guide presence plus key owner/versioning instructions for `RELEASE-04`. [ASSUMED]
- [ ] `test/install_smoke/package_metadata_test.exs` or equivalent shell gate — assert unpacked `hex_metadata.config` and exact package file expectations for `RELEASE-05`. [ASSUMED]
- [ ] Workflow/build command for `mix docs --warnings-as-errors` — current release lane does not block on docs warnings. [VERIFIED: .github/workflows/release.yml] [VERIFIED: mix help docs (2026-04-28)]
- [ ] Warning cleanup in docs/code comments around `Rindle.LiveView.allow_upload/4`. [VERIFIED: mix docs (2026-04-28)]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes [ASSUMED] | Hex user auth / API key auth via `mix hex.user` or `HEX_API_KEY`; do not hand-roll. [VERIFIED: mix help hex.user (2026-04-28)] [CITED: https://hex.pm/docs/publish] |
| V3 Session Management | no [ASSUMED] | Not a runtime web-session phase. [ASSUMED] |
| V4 Access Control | yes [ASSUMED] | GitHub `release` environment restrictions plus Hex owner levels manage who can publish or manage owners. [VERIFIED: .github/workflows/release.yml] [VERIFIED: mix help hex.owner (2026-04-28)] |
| V5 Input Validation | yes [ASSUMED] | Validate package metadata and docs outputs by building from source and asserting generated artifacts, not by trusting handwritten docs alone. [VERIFIED: mix hex.build --unpack (2026-04-28)] [VERIFIED: mix docs (2026-04-28)] |
| V6 Cryptography | yes [ASSUMED] | Use Hex-generated API keys and GitHub secret storage; never invent custom credential formats. [CITED: https://hex.pm/docs/publish] [VERIFIED: .github/workflows/release.yml] |

### Known Threat Patterns for Hex publish readiness

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Leaked publish credential in CI or local shell history | Information Disclosure [ASSUMED] | Keep live `HEX_API_KEY` out of Phase 10, document secret location explicitly, and use the protected `release` environment in Phase 11. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: .github/workflows/release.yml] |
| Unauthorized package ownership or maintainer drift | Elevation of Privilege [ASSUMED] | Document owner-add / transfer steps and verify owner level expectations with `mix hex.owner`. [VERIFIED: mix help hex.owner (2026-04-28)] |
| Package contents drift from maintainer expectations | Tampering [ASSUMED] | Gate on `mix hex.build --unpack` and inspect `hex_metadata.config` plus required/prohibited paths. [VERIFIED: mix hex.build --unpack (2026-04-28)] [VERIFIED: .github/workflows/release.yml] |
| Docs ship with broken references or stale maintainer guidance | Repudiation / Tampering [ASSUMED] | Add release-doc parity tests and `mix docs --warnings-as-errors`. [VERIFIED: mix help docs (2026-04-28)] [VERIFIED: mix docs (2026-04-28)] |

## Sources

### Primary (HIGH confidence)

- Local `mix help hex.publish` on 2026-04-28 - current installed Hex CLI behavior for publish, docs, and owner semantics. [VERIFIED: mix help hex.publish (2026-04-28)]
- Local `mix help hex.build` on 2026-04-28 - current installed Hex CLI behavior for package build and `--unpack`. [VERIFIED: mix help hex.build (2026-04-28)]
- Local `mix help hex.owner` on 2026-04-28 - current installed owner management semantics and levels. [VERIFIED: mix help hex.owner (2026-04-28)]
- Local `mix help docs` on 2026-04-28 - current ExDoc task options including `--warnings-as-errors`. [VERIFIED: mix help docs (2026-04-28)]
- [mix.exs](/Users/jon/projects/rindle/mix.exs:7) - current package and docs configuration. [VERIFIED: mix.exs]
- [.github/workflows/release.yml](/Users/jon/projects/rindle/.github/workflows/release.yml:13) - current release behavior and dry-run posture. [VERIFIED: .github/workflows/release.yml]
- [.github/workflows/ci.yml](/Users/jon/projects/rindle/.github/workflows/ci.yml:242) - current package-consumer CI parity lane. [VERIFIED: .github/workflows/ci.yml]
- [README.md](/Users/jon/projects/rindle/README.md:1) and [guides/getting_started.md](/Users/jon/projects/rindle/guides/getting_started.md:1) - current public docs scope. [VERIFIED: README.md] [VERIFIED: guides/getting_started.md]
- [test/install_smoke/docs_parity_test.exs](/Users/jon/projects/rindle/test/install_smoke/docs_parity_test.exs:1) - current docs parity gate coverage. [VERIFIED: test/install_smoke/docs_parity_test.exs]
- Unpacked artifact `rindle-0.1.0-dev/hex_metadata.config` built on 2026-04-28 - exact shipped metadata snapshot. [VERIFIED: rindle-0.1.0-dev/hex_metadata.config]

### Secondary (MEDIUM confidence)

- https://hex.pm/docs/publish - official Hex publishing guide covering metadata, semver expectations, docs publication, and CI key generation. [CITED: https://hex.pm/docs/publish]
- https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html - official Hex build task docs. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html]
- https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html - official Hex publish task docs. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html]
- https://hexdocs.pm/hex/Mix.Tasks.Hex.Owner.html - official Hex owner task docs. [CITED: https://hexdocs.pm/hex/Mix.Tasks.Hex.Owner.html]
- https://hexdocs.pm/ex_doc/ExDoc.html - official ExDoc configuration docs. [CITED: https://hexdocs.pm/ex_doc/ExDoc.html]
- https://hexdocs.pm/ex_doc/0.38.1/Mix.Tasks.Docs.html - official `mix docs` task docs including warning enforcement. [CITED: https://hexdocs.pm/ex_doc/0.38.1/Mix.Tasks.Docs.html]

### Tertiary (LOW confidence)

- None. [VERIFIED: source audit for this document (2026-04-28)]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - the core toolchain is already installed and was verified directly from local `mix` help and registry output. [VERIFIED: mix help hex.publish (2026-04-28)] [VERIFIED: mix hex.info ex_doc (2026-04-28)]
- Architecture: MEDIUM - the split between docs/runbook work and preflight hardening is well-supported by the roadmap, but some exact file/test shapes remain discretionary. [VERIFIED: .planning/ROADMAP.md] [ASSUMED]
- Pitfalls: HIGH - each major pitfall was confirmed either from current workflow behavior or current command output. [VERIFIED: .github/workflows/release.yml] [VERIFIED: mix docs (2026-04-28)] [VERIFIED: mix hex.publish package --dry-run --yes (2026-04-28)]

**Research date:** 2026-04-28 [VERIFIED: current date]
**Valid until:** 2026-05-28 for repo-local findings; re-check Hex/ExDoc docs sooner if publish tooling is upgraded. [ASSUMED]
