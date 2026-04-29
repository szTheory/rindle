# Architecture Research

**Domain:** Elixir/Phoenix library — live Hex publish execution and public API surface audit
**Researched:** 2026-04-29
**Confidence:** HIGH (all findings derived from live codebase and workflow inspection)

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Release Pipeline                              │
│                                                                       │
│  CI (ci.yml)                     Release (release.yml)               │
│  ┌─────────────────────┐         ┌────────────────────────────────┐  │
│  │ release_check job   │         │ release job (env: release)     │  │
│  │ ├─ preflight        │         │ ├─ release_preflight.sh        │  │
│  │ ├─ version mock     │─ gate ──│ ├─ assert_version_match.sh     │  │
│  │ └─ dry-run publish  │         │ └─ mix hex.publish --yes       │  │
│  └─────────────────────┘         └───────────────┬────────────────┘  │
│                                                   │ needs:            │
│                                  ┌────────────────▼────────────────┐  │
│                                  │ public_verify job (fresh runner) │  │
│                                  │ └─ public_smoke.sh $VERSION      │  │
│                                  └─────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                          Public API Surface                           │
│                                                                       │
│  Rindle (facade)                                                      │
│  ├─ upload/proxied upload — upload/3, verify_upload/2                │
│  ├─ direct upload — initiate_upload/2, initiate_multipart_upload/2   │
│  │                   sign_multipart_part/3, complete_multipart_upload/3│
│  ├─ attachment — attach/4, detach/3                                   │
│  ├─ storage ops — store/4, download/4, delete/3, head/3              │
│  ├─ delivery — url/3, variant_url/4, presigned_put/4                 │
│  └─ instrumentation — store_variant/4, log_variant_processing_failure/3│
│                                                                       │
│  Behaviour Contracts (implementable by adopters)                      │
│  ├─ Rindle.Storage — 11-callback behaviour                           │
│  ├─ Rindle.Processor — 1-callback behaviour                          │
│  └─ Rindle.Authorizer — 1-callback behaviour                         │
│                                                                       │
│  Profile DSL                                                          │
│  └─ Rindle.Profile (use Rindle.Profile, storage: ...) — macro entry  │
│                                                                       │
│  Supporting Modules (internal, not adopter-facing)                   │
│  ├─ Rindle.Config — runtime config accessors                         │
│  ├─ Rindle.Delivery — URL policy enforcement                         │
│  ├─ Rindle.Upload.Broker — session state machine                     │
│  ├─ Rindle.Domain.{MediaAsset,MediaAttachment,MediaVariant,...}       │
│  └─ Rindle.Workers.{PromoteAsset,ProcessVariant,PurgeStorage,...}     │
└──────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Public or Internal |
|-----------|---------------|-------------------|
| `Rindle` | Facade — all adopter entry points live here | Public |
| `Rindle.Profile` | DSL macro — profile definition by adopters | Public |
| `Rindle.Storage` | Behaviour contract for storage adapters | Public |
| `Rindle.Processor` | Behaviour contract for variant processors | Public |
| `Rindle.Authorizer` | Behaviour contract for delivery auth hooks | Public |
| `Rindle.Html` | `use Rindle.Html` — `picture_tag/3` helper | Public |
| `Rindle.LiveView` | `use Rindle.LiveView` — `allow_upload/4`, `consume_uploaded_entries/3` | Public |
| `Rindle.Storage.Capabilities` | Capability vocabulary and negotiation helpers | Public |
| `Rindle.Config` | Runtime config accessors (`:repo`, `:queue`, TTLs) | Quasi-public (no `@doc`) |
| `Rindle.Delivery` | URL policy enforcement (signed vs public, TTL, authorizer) | Internal |
| `Rindle.Upload.Broker` | Upload session state machine and promotion | Internal |
| `Rindle.Domain.*` | Ecto schemas and changesets | Internal |
| `Rindle.Workers.*` | Oban worker `perform/1` implementations | Internal |
| `Rindle.Ops.*` | Day-2 ops helpers (cleanup, backfill, maintenance) | Internal |
| `Rindle.Security.*` | MIME sniffing, filename sanitization, upload validation | Internal |
| Mix tasks | Operator CLI surface (`rindle.*` tasks) | Public (Mix task) |
| `scripts/release_preflight.sh` | Build artifact, run install smoke, doc build | Release tooling |
| `scripts/assert_version_match.sh` | Git tag vs mix.exs version gate | Release tooling |
| `scripts/public_smoke.sh` | Post-publish Hex.pm resolution verification | Release tooling |
| `ci.yml` / `release.yml` | CI and release automation pipelines | DevOps |

## Recommended Project Structure

```
lib/
├── rindle.ex                    # Public facade — all adopter entry points
├── rindle/
│   ├── config.ex                # Runtime config accessors
│   ├── delivery.ex              # URL policy (internal, delegates from Rindle)
│   ├── profile.ex               # Profile DSL macro
│   ├── storage.ex               # Storage behaviour
│   ├── processor.ex             # Processor behaviour
│   ├── authorizer.ex            # Authorizer behaviour
│   ├── html.ex                  # use Rindle.Html — picture_tag
│   ├── live_view.ex             # use Rindle.LiveView — upload helpers
│   ├── storage/
│   │   ├── capabilities.ex      # Capability vocabulary
│   │   ├── local.ex             # Local filesystem adapter
│   │   └── s3.ex                # S3/MinIO adapter
│   ├── domain/                  # Ecto schemas and FSMs (internal)
│   ├── workers/                 # Oban workers (internal)
│   ├── ops/                     # Day-2 ops helpers (internal)
│   ├── security/                # MIME, filename, validation (internal)
│   └── upload/broker.ex         # Upload session state machine (internal)
├── mix/tasks/                   # Mix operator tasks (public CLI surface)
scripts/
├── release_preflight.sh         # Pre-publish gate
├── assert_version_match.sh      # Tag/version drift gate
├── public_smoke.sh              # Post-publish verification
└── install_smoke.sh             # Package consumer smoke
.github/workflows/
├── ci.yml                       # CI (includes dry-run publish lane)
└── release.yml                  # Release (live publish + public verify)
```

### Structure Rationale

- **`lib/rindle.ex` (facade):** All adopter-facing function calls go through one module. Adopters never reach into `Rindle.Delivery`, `Rindle.Upload.Broker`, or the domain layer directly. This is the primary API audit target for v1.3.
- **`lib/rindle/domain/`:** Schema and FSM modules are internal. Adopters receive structs from these but should not call their changesets directly.
- **`lib/rindle/workers/`:** Oban worker modules are internal. Adopters configure the queue; they never call `perform/1` themselves.
- **`lib/rindle/ops/`:** Ops helpers are primarily called by Mix tasks. Whether these should also be directly accessible public surface is an open API audit question for v1.3.
- **`scripts/`:** All release scripts are reused across both `ci.yml` and `release.yml`, so changes to scripts apply in both contexts automatically.

## Architectural Patterns

### Pattern 1: Release Pipeline Reuse — Scripts as Single Source of Truth

**What:** `ci.yml` and `release.yml` both invoke the same shell scripts (`release_preflight.sh`, `assert_version_match.sh`). CI runs a version mock (setting `GITHUB_REF_NAME` manually) and a `--dry-run` publish. The real release job runs the same scripts without mocking and executes `mix hex.publish --yes`.

**When to use:** This pattern means any change to release gate behavior only needs to happen in the scripts, not in both workflow files. CI failures surface pre-tag, not at release time.

**Trade-offs:** The dry-run in CI catches publish format/metadata issues but cannot catch network-level authentication problems (only a real publish can surface those). The two jobs share structure but diverge at exactly the right point: the secret boundary.

**Implication for v1.3:** The live publish execution requires no architectural change to the release pipeline. The pipeline is fully wired. The only action needed is: change `@version "0.1.0-dev"` to `0.1.0`, commit, tag `v0.1.0`, push the tag. PUBLISH-02 (diagnose CI failures) may require script or workflow fixes, but the architecture is correct.

### Pattern 2: Facade + Behaviour Contracts — Public API Boundary

**What:** `Rindle` is the sole public facade. Behaviours (`Rindle.Storage`, `Rindle.Processor`, `Rindle.Authorizer`) are the extension points adopters implement. Everything else is internal.

**When to use:** This pattern makes the API audit straightforward: audit `Rindle` module functions and the three behaviour contracts. Additions to the public surface happen in `Rindle` (delegating internally), not by exposing internal modules.

**Trade-offs:** `Rindle.Config` is a quasi-public module (adopters reference config key names, but the module itself has `@spec` and no `@doc`). It should either be formally documented as public or hidden behind `@moduledoc false`. `Rindle.Ops.*` modules are called by Mix tasks — whether they should also be directly callable by adopter app code is a decision the API audit must make explicitly.

**Implication for v1.3 (API-01 through API-04):** The audit scope is bounded:
1. `Rindle` facade — all 17 public functions already have `@doc` and `@spec`. Review for naming consistency and completeness.
2. `Rindle.Profile` macro — check that generated callbacks are documented.
3. `Rindle.Storage`, `Rindle.Processor`, `Rindle.Authorizer` — callbacks have `@callback` specs; confirm `@doc` coverage on each callback.
4. `Rindle.Html`, `Rindle.LiveView` — public via `use`; confirm `@doc`/`@spec` on injected functions.
5. `Rindle.Config` — no `@doc` on any function; decide: document as public API or suppress with `@moduledoc false`.
6. `Rindle.Ops.*` — partial `@doc` coverage; decide: promote to public surface or leave as internal Mix task helpers.
7. Mix tasks — `@moduledoc` present on all five tasks, which satisfies the Mix task docs contract.

### Pattern 3: Post-Publish Verification on a Fresh Runner

**What:** The `public_verify` job depends on (`needs: release`) and runs on a fresh runner with `HEX_API_KEY: ""` explicitly cleared. It runs `public_smoke.sh $VERSION` which calls `mix test test/install_smoke/generated_app_smoke_test.exs --include minio`. This test installs the published package from Hex.pm (network), not from the local workspace.

**When to use:** The isolation is the point — the post-publish check cannot accidentally pass by reading the local build artifact instead of what Hex.pm serves. This matters for the first publish because it confirms public resolution end-to-end.

**Trade-offs:** The `public_verify` job requires the same MinIO/PostgreSQL service containers as the release job. This is slightly heavyweight for a post-publish verification, but it mirrors what an adopter actually does after adding the dependency.

**Implication for v1.3:** No changes needed to the `public_verify` architecture. The existing `public_verify` job runs automatically after the real publish completes.

## Data Flow

### Live Publish Flow

```
Developer: bump @version in mix.exs (0.1.0-dev → 0.1.0) and commit
    ↓
git tag v0.1.0 + git push --tags
    ↓
release.yml triggered (push: tags: v*)
    ↓
release job (environment: release — gates on HEX_API_KEY secret)
    ├─ Checkout + Elixir setup + deps + MinIO + PostgreSQL
    ├─ release_preflight.sh
    │   ├─ mix hex.build --unpack             [build artifact]
    │   ├─ mix test package_metadata_test.exs [metadata gates]
    │   ├─ mix test release_docs_parity_test.exs
    │   ├─ bash scripts/install_smoke.sh
    │   └─ mix docs --warnings-as-errors
    ├─ assert_version_match.sh                [tag == mix.exs version]
    └─ mix hex.publish --yes                  [LIVE publish with HEX_API_KEY]
    ↓
public_verify job (fresh runner, HEX_API_KEY="")
    └─ public_smoke.sh 0.1.0
        └─ generated_app_smoke_test.exs       [installs from Hex.pm + runs]
```

### API Audit Flow

```
Audit target list (from lib/ scan):
    ↓
For each public module:
    ├─ Verify @moduledoc present and accurate
    ├─ Verify @doc present on each public def
    ├─ Verify @spec present and typed (not map()/term() where avoidable)
    └─ Check naming convention consistency (verb_noun pattern)
    ↓
For @callback modules (Storage, Processor, Authorizer):
    └─ Verify each @callback has an inline @doc or clear @typedoc context
    ↓
Decisions:
    ├─ Rindle.Config: @moduledoc false OR promote to documented public API
    ├─ Rindle.Ops.*: confirm as Mix task internal OR expose via Rindle facade
    └─ Rindle.Storage.Capabilities: already public; confirm @doc on all fns
    ↓
Breaking-change audit (API-04):
    ├─ List all public functions with their signatures
    ├─ Mark functions where adopter-facing contract could narrow/widen
    └─ Document stable-surface boundary before 1.0
```

## What Is NEW vs MODIFIED for v1.3

| Work Item | New or Modified | Target |
|-----------|----------------|--------|
| Bump `@version` to `0.1.0` | Modified | `mix.exs` |
| Diagnose + fix CI failures (PUBLISH-02) | Modified (conditional) | `ci.yml`, scripts, or library code |
| Execute real `mix hex.publish --yes` via tag push | Operational step, no code change | GitHub Actions trigger |
| Post-publish public verify | No change — existing `public_verify` job runs automatically | `release.yml` |
| Routine release runbook update (PUBLISH-03) | Modified | `guides/release_publish.md` |
| `@doc` coverage on `Rindle.Config` functions (API-03) | Modified | `lib/rindle/config.ex` |
| Naming audit + fixes (API-01) | Modified (functions may be renamed/aliased) | `lib/rindle.ex`, affected modules |
| Missing convenience functions (API-02) | New | `lib/rindle.ex` (delegating internally) |
| `@spec` tightening where `term()`/`map()` is too broad (API-03) | Modified | `lib/rindle.ex`, domain modules |
| Breaking-change surface lock document (API-04) | New | `.planning/` or `guides/` |

## Build Order Considerations

**Critical dependency:** Publish must happen before or alongside the API audit, not after a major API rewrite.

**Reasoning:**

1. Reserving the package name on Hex.pm is time-sensitive. Deferring the publish until after the API cleanup creates a window where someone else could register `rindle`.
2. Publishing pre-audit `0.1.0` is normal. The semver `0.x.y` contract signals instability; adopters expect iteration in early releases.
3. Naming fixes done before `0.1.0` lands are zero-cost. After any public release, every rename requires a deprecation cycle to avoid breaking adopters.

**Suggested build order:**

```
Phase A: Live Publish Execution
    ├─ PUBLISH-02 first: diagnose and fix any CI pipeline failures
    │    (CI dry-run must be green before the real tag push)
    ├─ PUBLISH-01: bump version, push tag, confirm full release workflow runs
    │    (preflight → version check → live publish → public verify)
    └─ PUBLISH-03: update runbook with actual first-publish experience

Phase B: API Surface Audit
    ├─ API-01: naming inconsistency review (safe to rename before any adopt)
    ├─ API-02: missing convenience functions (additive, no breakage)
    ├─ API-03: @doc/@spec/@moduledoc coverage gaps
    └─ API-04: breaking-change audit — lock stable surface before 1.0

Optional Phase C (if API audit reveals significant changes):
    └─ Patch publish 0.1.1 with the API cleanup applied
```

If the API audit is small (cosmetic doc gaps, minor additions), it can be folded into the same milestone as the first publish and shipped as `0.1.0` itself. If the audit reveals substantial renames or additions, publish `0.1.0` first, then ship `0.1.1` with the API cleanup.

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `Rindle` facade ↔ `Rindle.Upload.Broker` | Direct function call (delegating) | Broker is internal; facade is the only public entry |
| `Rindle` facade ↔ `Rindle.Delivery` | Direct function call (delegating) | `url/3` and `variant_url/4` both delegate to `Rindle.Delivery` |
| `Rindle.Config` ↔ all modules | `Application.get_env/3` at call time | No `@doc` on functions; adopters configure keys not the module |
| `Rindle.Storage` behaviour ↔ adapters | `@callback` contracts | `Local` and `S3` are the shipped implementations |
| `Rindle.Workers.*` ↔ Oban | `use Oban.Worker` + `Oban.insert/2` in transactions | Workers are internal; adopter configures the queue in their supervision tree |
| `Rindle.Ops.*` ↔ Mix tasks | Direct call from `run/1` in each Mix task | Ops modules are the implementation layer; tasks are the CLI wrapper |
| `scripts/` ↔ `ci.yml` / `release.yml` | Bash invocation — same scripts, different context | Single source of truth for gate logic |

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| Hex.pm (publish) | `mix hex.publish --yes` with `HEX_API_KEY` env var | Protected by `environment: release` in `release.yml` |
| Hex.pm (verify) | Network fetch from `generated_app_smoke_test.exs` | Fresh runner, no local artifacts, `HEX_API_KEY: ""` |
| GitHub Actions `release` environment | Secret gating — `HEX_API_KEY` is a scoped environment secret | Configured in repo settings; `HEX_API_KEY` is already set as of v1.2 |
| MinIO (test) | Docker service container in both release jobs | Required because the generated app smoke test exercises storage |

## Anti-Patterns

### Anti-Pattern 1: Exposing Internal Modules as Public API

**What people do:** Add `@doc` to `Rindle.Domain.MediaAsset.changeset/2` or `Rindle.Upload.Broker.verify_completion/2` and tell adopters to call them directly.

**Why it's wrong:** The facade pattern is the boundary. Exposing internals means the implementation cannot change without a public breaking change, changeset details leak to adopters, and the API surface explodes to dozens of functions adopters should never touch.

**Do this instead:** All adopter-facing operations go through `Rindle` facade functions. If a legitimate adopter need is discovered, add a new facade function that delegates internally. Never expose `Rindle.Upload.Broker` or domain modules directly.

### Anti-Pattern 2: Merging API Rewrite and Publish in a Single Commit

**What people do:** Rename public functions, bump the version, and push the tag all in the same commit or sequence.

**Why it's wrong:** If the rename introduces a compile error, a doc warning, or a test failure, the release pipeline fails after the tag is pushed. Reverting a pushed tag is painful and leaves the Hex.pm publish job in an ambiguous state.

**Do this instead:** Keep API changes in separate commits from the version bump commit. The version bump + tag push should happen on a clean, green-CI baseline. Treat the version-bump commit as a pure mechanical step with no substantive changes.

### Anti-Pattern 3: Narrowing `@spec` Types After First Publish

**What people do:** Leave `{:ok, map()}` return types on facade functions until after `0.1.0` ships, then try to tighten them to `{:ok, MediaAsset.t()}` in a patch release.

**Why it's wrong:** Changing a typespec from `map()` to a named struct type is a Dialyzer-level breaking change for adopters who run Dialyzer. After `0.1.0` is published, tightening specs requires a minor version bump at minimum.

**Do this instead:** Do the spec tightening as part of the API-03 work, before `0.1.0` ships. The facade already uses `{:ok, map()}` or `{:ok, struct()}` in several places where `{:ok, MediaAsset.t()}` or `{:ok, MediaAttachment.t()}` would be more accurate. Fix this in the API audit phase, pre-publish.

### Anti-Pattern 4: Skipping the Runbook Update After First Publish

**What people do:** Complete the first publish, confirm it worked, and move on without updating the runbook to reflect what actually happened vs what was planned.

**Why it's wrong:** The runbook's value is highest immediately after the first real exercise. Any deviations from the documented sequence — required manual steps, environment setup gotchas, timing issues — are forgotten within days. Future routine releases then encounter the same surprises.

**Do this instead:** PUBLISH-03 explicitly requires the runbook update. After the first publish completes, record: actual command sequence used, any deviations from the plan, timing, and the final published package URL.

## Sources

- Live codebase inspection: `lib/`, `scripts/`, `.github/workflows/` — HIGH confidence
- `mix.exs` package configuration and version state — HIGH confidence
- `guides/release_publish.md` — existing release runbook — HIGH confidence
- `.planning/PROJECT.md` — milestone context and active requirements — HIGH confidence

---
*Architecture research for: Rindle v1.3 Live Hex Publish and API Ergonomics*
*Researched: 2026-04-29*
