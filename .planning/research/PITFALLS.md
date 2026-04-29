# Pitfalls Research

**Domain:** First live Hex.pm publish execution and pre-1.0 API ergonomics review
**Researched:** 2026-04-29
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: The one-hour window closes before you notice a problem

**What goes wrong:**
After the first real publish of a new version, public packages can only be
overwritten or reverted within one hour. A new package (never published before)
has a 24-hour window, but any subsequent version cuts the window to one hour.
If the CI pipeline publishes `v0.1.0` automatically and you only discover a
metadata error, wrong package name casing, or bad tarball contents 90 minutes
later, you cannot fix it. The version is permanently visible and immutable. You
must publish `v0.1.1` — burning a patch version on a publish mistake.

**Why it happens:**
Automated pipelines with `--yes` skip the interactive diff output that would
catch problems. Docs generation failures can appear as full pipeline failures
even though the package tarball was already pushed. Post-publish verification
runs separately and may catch issues too late.

**How to avoid:**
Run `mix hex.build --unpack` and inspect the extracted directory as a required
CI gate before the real publish step. Add a manual approval step or delay
between tag creation and publish trigger for the very first cut. Treat the
post-publish window (first 60 minutes) as a hot observation period, not quiet
downtime. Keep the runbook rollback steps (revert command, retire command,
contact path) immediately accessible during the first release.

**Warning signs:**
- Automated `--yes` flag bypasses the interactive confirmation diff
- CI log shows docs task failure after package published line
- GitHub release workflow completes green but post-publish smoke fails

**Phase to address:** Live publish execution phase (PUBLISH-01, PUBLISH-02)

---

### Pitfall 2: Package metadata is wrong and locked after the window

**What goes wrong:**
The `:description`, `:licenses`, `:links`, and `:maintainers` fields in
`mix.exs` get published verbatim and become the permanent public identity of
the package. A wrong GitHub link, missing license identifier, or stale
description phrase is visible to every adopter and to the Hex.pm search index.
Metadata-only fixes after the one-hour window require a full new version
publish.

**Why it happens:**
Metadata fields are frequently copied from a template and never reviewed with
fresh eyes before publish. The `:licenses` field requires SPDX identifiers
(e.g., `"MIT"`, `"Apache-2.0"`) — an incorrect string is accepted locally but
may render oddly on Hex.pm. The `:links` map is freeform; dead or placeholder
URLs are not validated.

**How to avoid:**
Add a dedicated pre-publish metadata review step that checks: description is a
real sentence, license string is a valid SPDX identifier, all link URLs are
resolvable (at minimum manually verified), package name matches the intended
public identity, and module prefix matches the package name convention (e.g.,
`Rindle.*` modules for the `rindle` package).

**Warning signs:**
- `:description` contains "TODO" or the template placeholder text
- `:links` map has keys pointing to local or placeholder URLs
- `:licenses` is a list containing an unrecognized string

**Phase to address:** Publish preflight / pre-publish checklist phase

---

### Pitfall 3: Docs publish and package publish are treated as one atomic step

**What goes wrong:**
`mix hex.publish` publishes both the package tarball and the generated
documentation. If ExDoc is not in `:dev` dependencies or `mix docs` fails
silently, the package lands on Hex.pm without docs on HexDocs. The pipeline
may report overall success because the tarball push succeeded. HexDocs will
show a blank or error page for the package version. Documentation can be
republished at any time with `mix hex.publish docs` — but only if you notice
the failure.

**Why it happens:**
The historical issue (hexpm/hex#270) documents exactly this ambiguity: error
messaging does not distinguish "package published" from "docs also published."
Automated pipelines with `--yes` lose the interactive output that would make
the split obvious. ExDoc being dev-only is correct, but its absence from CI
env is a silent failure mode.

**How to avoid:**
Verify HexDocs URL resolves and has real content as a distinct post-publish
check (separate from the package install smoke). Add `{:ex_doc, ">= 0.0.0",
only: :dev, runtime: false}` to `mix.exs` and ensure it is available in the CI
environment that runs publish. Capture `mix docs` as a standalone gate before
`mix hex.publish` in the pipeline.

**Warning signs:**
- HexDocs URL for the version returns 404 or empty after publish
- Pipeline shows package published but no docs output line
- ExDoc not present in dev deps or missing from CI dep install

**Phase to address:** Live publish execution phase; post-publish verification phase

---

### Pitfall 4: Git or path dependencies block publication unexpectedly

**What goes wrong:**
Hex.pm does not allow publishing packages that have non-Hex dependencies.
Any git or path dependency in `mix.exs` causes `mix hex.publish` to fail with
an error at publication time. If those dependencies were temporarily added for
development or are leftovers from a spike, they will fail the real publish
attempt. They are not blocked by `--dry-run` in all Hex versions.

**Why it happens:**
Libraries under active development often accumulate path dependencies (e.g.,
`{:rindle_test_support, path: "../rindle_test_support"}`) or git pins for
upstream work. These are acceptable in `:dev`/`:test` only — but any non-only
dep that uses a git or path source blocks publish.

**How to avoid:**
In CI, run `mix hex.build` as a separate gate and verify it exits cleanly
before the publish step. Review `mix.exs` dependencies before cutting a
release tag and ensure all non-only deps are Hex-sourced. The optional dep
path (`:optional` flag) does not bypass this restriction.

**Warning signs:**
- `mix.exs` has any `git:` or `path:` option on a dep without `:only` scope
- `mix hex.build` exits non-zero with "dependencies excluded" message
- A dependency was recently pinned to a git branch for a bug workaround

**Phase to address:** Publish preflight / CI pipeline integrity phase

---

### Pitfall 5: The package name is registered permanently on first publish

**What goes wrong:**
The package name chosen for `v0.1.0` becomes the permanent public identity.
Hex.pm does not support renaming a package. If you realize after publish that
`rindle` should have been `rindle_phoenix`, or that the name conflicts with
community naming conventions (extension packages should be prefixed with the
parent package name), the only path is abandoning the old name and publishing
under a new name — with no redirect, no alias, no transfer. All early adopters
pointing at the old name must manually migrate.

**Why it happens:**
Package names are chosen during development without verifying them against
Hex.pm's namespace. The community convention (extension packages use the parent
name as prefix, e.g., `plug_auth` not `auth`) is not enforced at publish time —
it is just a policy.

**How to avoid:**
Search Hex.pm for the intended package name and any close variants before
publish. Verify the module prefix (`Rindle.*`) matches the package name
(`rindle`). Confirm the package name does not squat on or shadow an existing
namespace. Do this review as a named pre-publish checklist item, not an
assumption.

**Warning signs:**
- Package name search on Hex.pm shows a Levenshtein-adjacent existing package
- Module naming does not align with package name (e.g., `MyLib.Rindle` modules
  in an `other_name` package)

**Phase to address:** Pre-publish checklist; first publish execution phase

---

### Pitfall 6: Publishing v0.1.0 and immediately wanting to break its API

**What goes wrong:**
The publish milestone and the API ergonomics milestone are sequenced close
together. A common trap is: publish `v0.1.0`, run the API review, identify
renames and interface changes, then try to ship `v0.1.1` with breaking changes.
Under semver, `v0.1.1` is a patch version — adopters who locked `~> 0.1.0`
will receive it automatically. Any breaking rename in a patch version breaks
adopters silently. Publishing breaking changes as minor or patch versions in
pre-1.0 is technically permitted by semver (pre-1.0 has no stability
guarantee), but it burns adopter trust and is the root cause of "dependency
hell" in pre-1.0 Elixir library ecosystems.

**Why it happens:**
Pre-1.0 semver says nothing about stability, so maintainers feel free to break
at will. The problem is adopters do not uniformly understand this and often pin
`~> 0.1` or `~> 0.1.0` expecting minor and patch to be safe. The correct
community convention is to treat the minor version as the effective major during
0.x: `0.1.x` is a stable line, `0.2.0` is the breaking-change bump.

**How to avoid:**
Separate the publish phase and the API cleanup phase explicitly. Complete the
live publish first, lock the version, verify it. Then run the API review as a
distinct milestone. Any breaking API changes from the review go into `v0.2.0`,
not `v0.1.x`. Document the intended stability contract in the README or
CHANGELOG: state that `0.x` minor bumps may contain breaking changes following
the `0.MAJOR.MINOR` community convention.

**Warning signs:**
- API review findings include renames that affect function signatures already
  in `v0.1.0`
- The API review milestone is scheduled to complete in the same sprint as the
  live publish
- There is pressure to "clean up before anyone notices" in the first hour

**Phase to address:** API ergonomics phase; milestone sequencing discipline

---

### Pitfall 7: Over-scoping the API review and introducing unnecessary churn

**What goes wrong:**
An API ergonomics review scoped too broadly produces a long list of renames,
module splits, and new convenience functions all treated as equal priority.
This triggers a breaking-change flood in `v0.2.0` that is hard to document,
hard to test, and hard for early adopters to absorb. Breaking a stable API
when it only feels inconsistent (rather than genuinely wrong) destroys
adopter trust faster than it improves DX.

**Why it happens:**
API reviews done in isolation from real adopter usage tend to be opinionated
about naming aesthetics rather than ergonomic blockers. Without at least one
real adopter exercising the library, it is impossible to distinguish "this
name is inconsistent" from "this name makes real code unreadable."

**How to avoid:**
Scope the API review to three specific, concrete outputs:
1. Naming inconsistencies that would cause real confusion (not aesthetic preference)
2. Missing convenience functions that adopters will need and currently cannot do
3. Public/private boundary errors (things that are public but should be private,
   or private but should be public)

Explicitly defer any rename that is "nice to have" versus "clearly wrong."
Flag structural changes as `v0.3+` work. Require that every proposed breaking
change have a concrete adopter use-case that justifies it.

**Warning signs:**
- API review list has more than 10 breaking items for a library not yet in
  production use
- Items are described as "more idiomatic" rather than "removes a real obstacle"
- No real consuming application is available to validate the proposed changes

**Phase to address:** API ergonomics review phase (API-01 through API-04)

---

### Pitfall 8: Exposing too much of the public surface by accident

**What goes wrong:**
Every module in an Elixir library with a `@moduledoc` and documented public
functions becomes part of the permanent public contract. When the API review
adds `@doc` coverage and `@spec` annotations to internal helper modules, those
modules accidentally become part of the promised public API. Adopters start
using them. Later removal is a breaking change.

**Why it happens:**
Adding `@doc` and `@spec` to "all public functions" sounds correct but
conflates "functions that happen to be public" with "functions intentionally
part of the API contract." Elixir has no visibility annotation between `def`
(fully public) and `defp` (fully private). The convention is `@doc false` for
internal functions that must be public for implementation reasons (callbacks,
protocol implementations, test helpers).

**How to avoid:**
Before adding `@doc` and `@spec` coverage, first audit which modules are
intentional public API versus implementation modules. Apply `@doc false` and
`@moduledoc false` to any module or function that should not be adopted
against. Only then add documentation to the real public surface. Treat the
`@doc false` audit as a named phase task, not an afterthought.

**Warning signs:**
- Internal schema modules, changeset builders, or worker modules have
  `@doc` annotations
- The HexDocs sidebar shows more modules than you intend to support
- Worker or adapter modules are documented in the same style as public context
  modules

**Phase to address:** API ergonomics review phase (API-03, API-04)

---

### Pitfall 9: Using Application.get_env in the library for configuration

**What goes wrong:**
If any part of the library reads configuration from the application environment
at compile or boot time (e.g., `Application.get_env(:rindle, :some_option)`),
the library imposes a global singleton configuration on any adopter. A host app
with two different Rindle-backed contexts cannot configure them independently.
Compile-time configuration is worse: it locks configuration into the beam
artifact, making runtime reconfiguration impossible.

**Why it happens:**
The pattern is inherited from Phoenix app development where global
`Application.get_env` config is idiomatic for application-level settings. In a
library intended to be used by multiple host apps, the pattern is an
anti-pattern documented explicitly in the Elixir library guidelines.

**How to avoid:**
Configuration must be passed as parameters (keyword options to functions, or
options to `use Rindle`). If a top-level configuration is genuinely needed for
library-wide behavior (e.g., adapter selection), document it clearly and ensure
it is not needed per-instance. Never call `Application.get_env` inside library
code that is intended to run in the adopter's process.

**Warning signs:**
- Any call to `Application.get_env(:rindle, ...)` in library source outside
  of `Rindle.Config` or test harness modules
- Library documentation says "set this in config.exs" for a behavior the
  adopter might want per-instance
- The API review adds new `Application.get_env` calls as "convenience"

**Phase to address:** API ergonomics review phase (API-01, API-02)

---

### Pitfall 10: Removing or renaming @deprecated functions too quickly

**What goes wrong:**
The Elixir community deprecation convention requires the replacement to exist
for at least three minor versions before removal. If the API review introduces
`@deprecated` annotations and then a subsequent minor version removes those
functions, adopters who followed the deprecation warning and upgraded
immediately are broken by the removal. This is the "three-version minimum"
rule from Elixir's own compatibility policy.

**Why it happens:**
Pre-1.0 libraries feel entitled to skip the deprecation cycle because "semver
pre-1.0 allows breaking changes." This is technically true but destroys
adopter trust. The community expectation, even for 0.x libraries, is that you
use deprecation warnings before removal.

**How to avoid:**
Any function marked `@deprecated` in the API review must remain in the library
for at least the next two minor version cycles before removal. Do not remove a
deprecated function in the same release that introduces the replacement. If the
API review identifies something that must be renamed immediately and there are
no adopters yet, do the rename cleanly (no deprecation bridge needed for a
function that has never been publicly used) and document the change clearly in
the CHANGELOG.

**Warning signs:**
- API review plan shows "rename X to Y and remove X in the same PR"
- `@deprecated` annotation appears in a PR that also deletes the function
- A function is both introduced and removed within a single minor version

**Phase to address:** API ergonomics review phase (API-04); breaking-change audit

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Publish with `--yes` in CI from day one | Unattended release automation | Warnings and improvement suggestions silently swallowed | Only after first manual publish confirmed working |
| Use `mix hex.publish` without `mix hex.build --unpack` verification | Faster pipeline | Wrong tarball contents shipped; only caught post-publish | Never skip on first publish |
| Mark all `def` functions with `@doc` during review | Good doc coverage score | Internal helpers become permanent public API | Never — audit public vs. internal first |
| Defer `@doc false` audit until after documentation sprint | Faster doc writing | All modules become adopted surface area by default | Never once published |
| Break API in patch versions "while no one is using it yet" | Clean API faster | Destroys trust; causes semver confusion for early adopters who lock `~> 0.1.0` | Never — use minor bumps for breaking pre-1.0 |
| Rename modules without `@deprecated` bridge when "no one is using this" | Cleaner history | Cannot be undone after first public publish if even one user exists | Only before first real publish of that module |
| Use Application.get_env for library config "as a convenience" | Less boilerplate for adopters | Blocks multi-instance usage; violates library guidelines | Never in a library meant for general adoption |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Hex.pm publish + GitHub Actions | Using a personal user API key in CI instead of a scoped key | Generate a key with `--permission api:write` scoped to the `release` environment only |
| Hex.pm publish + docs | Treating docs failure as "package failed" | Check if package tarball published first, then republish docs separately with `mix hex.publish docs` |
| Hex.pm + git deps | Having a git-pinned dep that is not `:only :dev` | Move all non-Hex deps behind `:only :dev` or `:only :test`; verify with `mix hex.build` |
| Publish gate + dry-run | Assuming `--dry-run` catches all real-publish failures | Dry-run validates local structure; real auth, ownership, and namespace checks happen only on live publish |
| API review + published version | Running API review immediately after publish and shipping breaks in next patch | Gate API review on a separate minor version; complete publish, confirm stability, then review |
| `@doc` sprint + public surface | Writing `@doc` for every `def` without first auditing intent | Mark internal functions `@doc false` before the documentation sprint, not after |

## Performance Traps

Not applicable as primary concern for this milestone. Rindle's publish and API
review work is developer-time cost, not runtime performance.

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Storing full `HEX_API_KEY` with `api:write` and no env protection | Any workflow ref can trigger publish including forks | Scope the secret to the protected `release` environment in GitHub; never put in repository-level secrets |
| Publishing from a branch or PR workflow | Untrusted code could trigger publish | Restrict publish step to tag-triggered workflows from protected refs only |
| Hardcoding hex key in workflow YAML | Key exposed in repo history | Always use `${{ secrets.HEX_API_KEY }}` — never inline |

## "Looks Done But Isn't" Checklist

- [ ] **Live publish:** `mix hex.publish` exited 0 but HexDocs URL has not been verified to resolve with real content
- [ ] **Tarball contents:** `mix hex.build --unpack` was run but nobody inspected the unpacked directory for missing guides or extra generated files
- [ ] **Metadata:** description, links, and license fields were assumed correct because they existed in `mix.exs` without a pre-publish human review
- [ ] **API review scope:** breaking-change audit completed but `@doc false` audit not done — internal helpers are still documented as public API
- [ ] **Deprecation path:** functions marked `@deprecated` in review but same PR or next PR removes them (violates three-version minimum)
- [ ] **Docs coverage:** `@doc` and `@spec` were added to all `def` functions but no module was first evaluated for `@moduledoc false`
- [ ] **Version increment:** API review changes shipped as patch version instead of minor version bump
- [ ] **Rollback posture:** first live publish completed but revert command and runbook not confirmed executable before the one-hour window closed

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Wrong metadata published within 1 hour | LOW | `mix hex.publish --replace` within 60-minute window |
| Wrong metadata published after 1 hour | MEDIUM | Publish new patch version with corrected metadata; retire old version if severe |
| Bad tarball contents published within 1 hour | LOW | `mix hex.publish --revert VERSION` then re-publish with fixed tarball |
| Bad tarball contents after 1 hour | MEDIUM | Publish new patch version; use `mix hex.retire VERSION` with explanation message |
| Docs missing after publish | LOW | `mix hex.publish docs` — no time restriction on docs republish |
| Breaking API change shipped in patch version | HIGH | Cannot undo the published version; publish corrected API in next minor/patch; document the reversion clearly in CHANGELOG; use `mix hex.retire VERSION message: "contains accidental breaking change, use 0.x.y"` |
| Wrong package name registered | VERY HIGH | No rename path; must abandon old package name and publish under correct name; notify any early adopters manually |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| One-hour window closes before noticing problem | Live publish execution phase | Runbook includes explicit hot-observation checklist for first 60 minutes post-publish |
| Metadata wrong and locked | Pre-publish checklist phase | Metadata review checklist item passes before publish step runs |
| Docs and package publish conflated | Live publish execution; post-publish verification | Separate HexDocs URL check as explicit post-publish smoke test |
| Git/path deps block publish | Publish preflight / CI gate phase | `mix hex.build` exits 0 as required pre-publish gate |
| Package name locked permanently | Pre-publish checklist phase | Hex.pm namespace search completed and documented before first tag |
| Publish then immediately break API | Milestone sequencing discipline | API review is a separate milestone phase; no breaking changes to `v0.1.x` line |
| API review over-scoped | API ergonomics review phase | Review scoped to three concrete outputs; each item has a use-case justification |
| Over-exposing public surface | API ergonomics review phase | `@doc false` audit precedes any `@doc` coverage sprint |
| Application.get_env in library | API ergonomics review phase | Grep for `Application.get_env(:rindle` in library source; zero results required |
| Removing @deprecated too quickly | API ergonomics review phase; breaking-change audit | No function marked `@deprecated` is also deleted in same or next minor version |

## Sources

- [Hex.pm FAQ — immutability policy, revert and retire windows](https://hex.pm/docs/faq)
- [mix hex.publish documentation — flags, size limits, revert](https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html)
- [mix hex.build documentation — --unpack for pre-publish inspection](https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html)
- [Hex.pm publish guide — required metadata, git dep restriction, one-hour window](https://hex.pm/docs/publish)
- [Hex.pm dispute policy — package name squatting, no rename path](https://hex.pm/policies/dispute)
- [Elixir library guidelines — dependency version constraints, docs requirements](https://hexdocs.pm/elixir/library-guidelines.html)
- [Elixir design anti-patterns — Application.get_env in libraries, return type consistency](https://hexdocs.pm/elixir/main/design-anti-patterns.html)
- [Elixir compatibility and deprecations — three-version minimum rule](https://hexdocs.pm/elixir/compatibility-and-deprecations.html)
- [hexpm/hex issue #270 — docs publish failure silent in automation](https://github.com/hexpm/hex/issues/270)
- [Elixir Forum — pre-1.0 semver convention, 0.x.y as effective major](https://elixirforum.com/t/bumping-package-semver-based-on-api-change/3231)
- [Automating Elixir Package Deployment with GitHub Actions — pipeline gotchas](https://mikebian.co/automating-elixir-package-deployment-with-github-actions/)

---
*Pitfalls research for: Rindle v1.3 — Live Hex Publish and API Ergonomics*
*Researched: 2026-04-29*
