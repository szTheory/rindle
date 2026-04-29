# Stack Research

**Domain:** Rindle v1.3 — Live Hex.pm Publish Execution and API Ergonomics
**Researched:** 2026-04-29
**Confidence:** HIGH

## Context

This document covers only what is NEW or CHANGED for v1.3. The existing stack
(Elixir/Phoenix/Ecto, Oban, ExDoc, Credo, Dialyxir, ExCoveralls, GitHub Actions
with a protected `release` environment) is validated and carries forward unchanged.

The two new capability areas are:

1. **Live Hex.pm publish** — executing the real publish from the existing
   workflow, verifying it lands, confirming post-publish public resolution.
2. **API ergonomics** — auditing and tightening the public API surface:
   naming, `@doc`/`@spec`/`@moduledoc` coverage, convenience access,
   and breaking-change audit before 1.0.

---

## Recommended Stack for New Capabilities

### Live Hex Publish Execution

The workflow in `.github/workflows/release.yml` already contains `mix hex.publish --yes`
guarded by a real `HEX_API_KEY` check. No new tooling is needed. The stack changes
are operational, not dependency-level:

| Tool / Command | Version | Purpose | Why |
|----------------|---------|---------|-----|
| `mix hex.publish --yes` | Hex 2.4.1 (current) | Live package + docs publish in one step | Default `mix hex.publish` publishes both package tarball and HexDocs in a single call — no separate `mix hex.publish docs` step required |
| `mix hex.publish --revert VERSION` | Hex 2.4.1 | Rollback a just-published version | New packages: 24-hour revert window. Existing versions: 1-hour window. Docs: no time limit. If the last version is reverted, the entire package is removed. |
| `mix hex.publish --replace` | Hex 2.4.1 | Re-publish same version (if within 1-hour window) | Public packages can only be replaced within 1 hour of initial publish — use only to fix a broken first publish, not as a routine pattern |
| `mix hex.user key generate --key-name publish-ci --permission api:write` | Hex 2.4.1 | Generate a scoped write key for the `release` environment secret | Personal keys with `api:write` scope are the correct credential type for `HEX_API_KEY`; not a repository secret, lives in the `release` environment |
| `scripts/public_smoke.sh VERSION` | repo script | Post-publish verification from a fresh runner | Already exists; the release workflow calls it in the `public_verify` job, which runs only after a successful publish |

**Operational note on first publish:** The current authenticated Hex user (the
person who runs the initial `mix hex.publish` or who holds the `HEX_API_KEY` used
by CI) becomes the package owner automatically on first publish. Ownership can be
extended with `mix hex.owner add rindle EMAIL` afterward.

**No new mix.exs deps needed for publish execution.** All tooling is already
present or is part of the Hex CLI that ships with Elixir.

---

### API Ergonomics — Doc/Spec Coverage

#### doctor — `~> 0.22.0`

**Add to `mix.exs` deps as `only: :dev`.**

Doctor is the right tool for the `@doc`/`@spec`/`@moduledoc` coverage gap.
It generates a coverage report per module, measures doc and spec percentages
against configurable thresholds, and exits non-zero with `--raise` when
thresholds are not met.

```elixir
{:doctor, "~> 0.22.0", only: :dev, runtime: false}
```

Why doctor over alternatives:
- Credo's `Readability.ModuleDoc` only checks for present-or-absent `@moduledoc`.
  It does not measure `@doc` or `@spec` coverage on individual public functions.
- Dialyxir reports type contract violations on functions that have `@spec` but
  it does not flag functions that are missing `@spec` entirely.
- There is no built-in mix compiler warning for missing `@doc` on public functions.
- Doctor is the only Elixir-native tool specifically designed for `@doc`/`@spec`/
  `@moduledoc` coverage thresholds with per-module reporting.

Run locally: `mix doctor` (report) or `mix doctor --raise` (fail on threshold miss).

Default `.doctor.exs` to generate with `mix doctor.gen.config`:

```elixir
%Doctor.Config{
  ignore_modules: [],
  ignore_paths: [],
  min_module_doc_coverage: 40,
  min_module_spec_coverage: 0,
  min_overall_doc_coverage: 50,
  min_overall_moduledoc_coverage: 100,
  min_overall_spec_coverage: 0,
  exception_moduledoc_required: true,
  raise: false,
  reporter: Doctor.Reporters.Full,
  struct_type_spec_required: true,
  umbrella: false
}
```

**Recommended thresholds for Rindle v1.3** (tighten from defaults):

```elixir
%Doctor.Config{
  ignore_modules: [Rindle.Application, Rindle.Repo],
  ignore_paths: ["test/", "lib/mix/tasks/"],
  min_module_doc_coverage: 80,
  min_module_spec_coverage: 60,
  min_overall_doc_coverage: 80,
  min_overall_moduledoc_coverage: 100,
  min_overall_spec_coverage: 60,
  exception_moduledoc_required: true,
  raise: false,
  reporter: Doctor.Reporters.Full,
  struct_type_spec_required: true,
  umbrella: false
}
```

Rationale for ignoring `Rindle.Application` and `Rindle.Repo`:
- `Rindle.Application` carries `@moduledoc false` deliberately (internal OTP callback).
- `Rindle.Repo` carries `@moduledoc false` deliberately (dev/test harness, not public).
- Mix tasks have their own documentation convention via `@shortdoc` — doctor's
  coverage model does not apply cleanly to them.

**CI integration:** Add `mix doctor --raise` as a step in the `quality` job in
`ci.yml`, after `mix credo --strict`. Doctor exits non-zero if any module is below
threshold; `--raise` turns threshold misses into CI failures.

---

### API Ergonomics — Breaking-Change Audit

No new tooling is needed for breaking-change detection. The appropriate audit
approach for a pre-1.0 library is:

| Approach | Tool | Notes |
|----------|------|-------|
| Public API surface list | `mix xref graph` (built-in Mix) | Traces export dependencies to identify what modules/functions are called by adopters; use to enumerate the surface |
| Cross-version diff | `mix hex.package diff rindle VERSION1 VERSION2` (Hex 2.4.1 built-in) | Generates a git diff between published tarballs — useful after each release to verify surface changes match intent |
| Web diff viewer | https://diff.hex.pm | Browser-based shareable diff; same underlying data as the CLI command |

These are **audit workflows**, not CI gates. At v0.x, breaking changes are
permitted; the audit is to inform the changelog and post-1.0 stability posture.
No new library dependency is required.

---

### Existing Tools — Role in API Ergonomics

These already exist in `mix.exs` and `ci.yml`. Their role in v1.3 is clarified:

| Tool | Current Version | Role in API Ergonomics |
|------|-----------------|----------------------|
| Credo `~> 1.7` | 1.7.18 | `Readability.ModuleDoc` check enforces `@moduledoc` presence on every module; `Readability.FunctionNames`, `Readability.ModuleNames` enforce naming conventions. Already running in CI as `mix credo --strict`. |
| Dialyxir `~> 1.4` | 1.4.7 | Validates correctness of existing `@spec` annotations; reports contract violations. Does NOT flag missing specs. Already running in CI. |
| ExDoc `~> 0.40` | 0.40.1 | `mix docs --warnings-as-errors` (already in `release_preflight.sh`) fails if doc references are broken. Does NOT flag missing `@doc`. |
| `mix compile --warnings-as-errors` | stdlib | Catches undefined functions, deprecated calls. Already in CI `quality` job. |

**Gap summary:**
- Credo catches: missing `@moduledoc`, bad names
- Dialyxir catches: wrong specs (not missing specs)
- ExDoc catches: broken doc references
- Doctor fills: missing `@doc`, missing `@spec`, per-module thresholds

---

## Installation (New Addition Only)

```elixir
# In mix.exs deps/0 — add alongside existing :dev tools
{:doctor, "~> 0.22.0", only: :dev, runtime: false}
```

```bash
mix deps.get
mix doctor.gen.config   # generates .doctor.exs — edit thresholds before committing
mix doctor              # run report; will show coverage gaps to fix
```

---

## Alternatives Considered

| Recommended | Alternative | Why Not |
|-------------|-------------|---------|
| `doctor` for spec/doc coverage | Custom shell script + grep | Doctor produces structured per-module output, has a stable threshold config, and exits correctly for CI. A grep-based approach would need re-invention of the same feature set with more maintenance surface. |
| `doctor` for spec/doc coverage | ExDoc `--warnings-as-errors` alone | ExDoc warns on broken references but does not audit missing `@doc`/`@spec`. These are complementary, not alternatives. |
| Existing Credo `Readability.ModuleDoc` for `@moduledoc` | Any new `@moduledoc` checker | Credo already handles this and is already in CI. Doctor's `min_overall_moduledoc_coverage: 100` duplicates the enforcement but is less disruptive. Rely on Credo's check for `@moduledoc` — add doctor for `@doc`/`@spec`. |
| `mix hex.publish --yes` for live publish | `expublish` or other release orchestrators | Rindle's release workflow is already complete (preflight, version gate, protected environment, post-publish smoke). Adding another layer of tooling creates an unnecessary dependency on a third-party release tool. |
| Manual `mix hex.owner add` post-publish | Organization key | Rindle is a personal open-source project; personal `api:write` key with scoped CI secret is appropriate. Organization keys are for multi-maintainer or enterprise scenarios. |

---

## What NOT to Add

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `mix_audit` or `sobelow` as new CI gates | These are security dep-audit and Phoenix security tools — they address a different concern than API ergonomics | `mix hex.audit` (already available) for retired dep warnings; neither is needed for v1.3 goals |
| Any new job backend or release orchestrator | Rindle's CI and release workflow is already complete for the publish path | `mix hex.publish --yes` directly |
| Bumping OTP/Elixir versions in CI matrix | The current matrix (Elixir 1.15/OTP 26 + Elixir 1.17/OTP 27) covers the supported range | Only bump when a new Elixir LTS drops and the old one exits support |
| `ex_doc` `--no-deps` or other non-standard flags for the publish step | The release preflight already runs `mix docs --warnings-as-errors` — adding flags risks silencing real doc failures | Keep current `release_preflight.sh` doc step unchanged |
| Automated breaking-change enforcement at pre-1.0 | Pre-1.0 semver allows breaking changes; enforcement would block legitimate API cleanup | Use `mix hex.package diff` as an audit workflow post-release |

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| `doctor ~> 0.22.0` | Elixir ~> 1.13, OTP 24+ | Current 0.22.0 is compatible with the project's minimum Elixir 1.15 / OTP 26 |
| Hex 2.4.1 | Elixir 1.19.5 locally | `mix hex.publish`, `mix hex.build`, `mix hex.package diff` — all available in Hex 2.x; `--revert` and `--replace` are stable flags |
| ExDoc 0.40.1 | Elixir ~> 1.15 | `--warnings-as-errors` flag is stable since ExDoc 0.29 |

---

## Sources

- https://hex.pm/packages/doctor — doctor 0.22.0 release date, install snippet (HIGH confidence)
- https://github.com/akoutmos/doctor — configuration defaults, `--raise` flag, CI usage (HIGH confidence; Context7 verified)
- https://hexdocs.pm/hex/Mix.Tasks.Hex.Publish.html — `--yes`, `--dry-run`, `--replace`, `--revert` flags; revert timing windows (HIGH confidence; official Hex docs)
- https://hex.pm/docs/publish — `HEX_API_KEY` setup, `api:write` permission, owner assignment on first publish (HIGH confidence; official Hex docs)
- https://hexdocs.pm/credo/Credo.Check.Readability.ModuleDoc.html — scope of the ModuleDoc check (HIGH confidence; official Credo docs)
- https://hexdocs.pm/dialyxir/readme.html — `underspecs` warning flag, `--format github` (HIGH confidence; Context7 verified)
- https://hexdocs.pm/elixir/library-guidelines.html — official naming conventions, doc completeness expectations (HIGH confidence)
- https://hex.pm/blog/announcing-hex-diff — `mix hex.package diff` availability since Hex 0.20.0 (MEDIUM confidence)

---
*Stack research for: Rindle v1.3 Live Hex Publish and API Ergonomics*
*Researched: 2026-04-29*
