# Phase 137 discussion research: package boundary, host, and developer experience

Researched 2026-10-21 against source `1741fd8022eb211450c77e0032843a962d0a2a2c`.
This is maintainer-operated synthetic research and proposed acceptance design. It proves neither independent adoption nor 1.0 readiness. No package was built, dependencies installed, tests run, or services mutated for this research.

## Recommendation

Choose **a dedicated minimal external Phoenix host, provisioned through the existing generated-consumer conventions**, with its own ordinary application supervision, Repo, host migrations, and production-mode Oban execution. Keep a thin package/orchestration boundary reusable with install-smoke; keep twin scenarios separate from smoke test source. Use existing shell/Elixir/Compose facilities; add no testing framework, orchestration dependency, registry, authorization protocol, or generic scenario DSL.

Do not make Cohort a prerequisite. Cohort remains valuable browser/onboarding proof and a source of realistic flows, but copying its complete product UI and test support adds unrelated coupling to the package/retry/restart proof. Do not expand the current generated smoke helper into a generalized fault/recovery platform. Its installation/migration conventions are useful; its sandbox/manual execution model is deliberately different.

This is an additive behavioral fixture under the existing built-package proof topology, not a competing release authority. Earlier D-120-03 asks reuse of generated-app helper/install-smoke/migration conventions rather than a second release test system (`.planning/milestones/v1.23-phases/120-adoption-proof-release-truth/120-CONTEXT.md:19`). Reuse or copy the small mechanisms that preserve that topology; avoid importing all existing test-support modules into the external host.

Routine decisions can be adopted now. No remaining host-choice question needs maintainer arbitration. Escalate only if execution discovers a necessary public API change, different support promise, destructive semantics outside run-owned resources, or material cost.

## Evidence and interpretation

Repository facts below cite paths and line numbers. Recommendations, expected costs, and threat conclusions are **inferences**, not measured implementation results. External documentation was read on the research date; versioned repo source and resolved locks take precedence over latest documentation when they disagree.

Read inputs: root/planning AGENTS, `.planning/METHODOLOGY.md`, active PROJECT/REQUIREMENTS/ROADMAP, Phase 133–135 CONTEXT and Phase 120 context, `guides/ui_principles.md`, and all six `prompts/` files. The prompt index/DNA favor explicit behavior seams, host ownership, optional dependency discipline, packaged consumer proof, operational visibility, and one recommended direction. Deep-research package-splitting and hypothetical DSL examples are historical proposals, not shipped contracts. Current product scope and current `brandbook/`/UI principles win; this phase needs no UI redesign.

The active contract requires fresh external artifact consumption, host-owned dependencies, documented fault boundaries, persisted retries, real runtime replacement, and receipts (`.planning/REQUIREMENTS.md:48`; `.planning/ROADMAP.md:754`). Phase 138 owns the complete lifecycle interruption matrix (`.planning/ROADMAP.md:769`). Phase 139 owns the complete exact-head readiness verdict (`.planning/ROADMAP.md:784`).

## What the existing code actually establishes

| Evidence | Existing strength | Limit relevant to 137 |
| --- | --- | --- |
| `examples/adoption_demo/mix.exs:4`, `:38` | Cohort can redirect its library dependency through `RINDLE_DEMO_RINDLE_PATH`. | Default is `../..`; an external export must replace the dependency entirely and reject missing configuration rather than keep a fallback. |
| `examples/adoption_demo/lib/adoption_demo/application.ex:12` | Repo, Oban, PubSub, Endpoint are ordinary supervised host children. | Test startup calls Mux cassette configuration at lines 8–9; a copied `MIX_ENV=test` app is not a neutral production substrate. |
| `examples/adoption_demo/config/config.exs:16` | Explicit adopter Repo and five queue declarations already demonstrate ownership. | Complete demo contains more consumers and integrations than the foundation needs. |
| `examples/adoption_demo/config/test.exs:16`, `:31` | Can switch SQL sandbox off for server mode. | Oban remains `testing: :inline`; changing only `PHX_SERVER` does not produce persisted queue retry evidence. |
| `examples/adoption_demo/config/runtime.exs:34` | Explicit MinIO and S3 runtime configuration, including browser/public endpoint distinction at lines 45–60. | Defaults shared bucket/credentials and runtime environment switches must be replaced with run-owned resources for twin cleanup safety. |
| `test/install_smoke/support/generated_app/workspace.ex:7`, `:27` | Fresh temp workspace and official Phoenix generator with no assets/dashboard/mailer/gettext/install. | `ensure_package!` accepts any existing directory at lines 22–24; freshness and artifact identity need stronger enforcement for this phase. |
| `test/install_smoke/support/generated_app_helper.ex:174` | External package root can be supplied and consumer is generated separately. | An environment-supplied directory is accepted; source SHA alone cannot prove its freshness or content. |
| `test/install_smoke/support/generated_app/patcher.ex:53` | Local artifact consumption uses an explicit path to unpacked package; published mode uses Hex version requirement. | The path itself is not bad; repository fallback is bad. A twin guard must distinguish an attested external unpack from arbitrary paths. |
| `test/install_smoke/support/generated_app/patcher.ex:121`, `test/install_smoke/support/generated_app/smoke_source.ex:175` | Smoke inserts jobs into host DB and directly exercises promotion/process outcomes. | `testing: :manual` plus `perform_job` at smoke lines 186–207 is not production scheduler retry/restart evidence. |
| `test/install_smoke/support/generated_app/contracts.ex:164`, `:176` | Host `Oban.Migration` and pinned `Rindle.Migration.up(version: 1)` are already separate migration wrappers. | Preserve ownership rather than installing Oban through Rindle or discovering migrations in package source. |
| `test/install_smoke/support/generated_app_helper.ex:333` | Existing versioned receipt binds subject SHA, unpacked tree, generated host tree, lock, commands/results. | `package_sha256` at line 366 hashes `hex_metadata.config`, not tarball bytes. Do not reuse that name/value as TWIN-06's package artifact checksum. Preserve historical receipt semantics; introduce honest new twin fields. |
| `test/adopter/canonical_app/profile.ex:12`, `test/adopter/canonical_app/lifecycle_test.exs:110` | Concrete MinIO image lifecycle closely tracks onboarding. | Lifecycle uses repository DataCase, global Repo swap, and `perform_job` (lines 12–25, 74–88, 138–157). Copy supported public interactions and documented read-only schema queries, not its support/runtime model. |
| `scripts/release_preflight.sh:30`, `scripts/install_smoke.sh:31` | Existing release path builds/unpacks then invokes generated package proof. | Install-smoke intentionally permits an externally prepared artifact; twin must freshly build within each run and bind actual tar bytes. |

## Serious host alternatives

Costs here are qualitative change/maintenance costs, not timing measurements.

| Candidate | Product/JTBD fit | Advantages | Costs and footguns | Decision |
| --- | --- | --- | --- | --- |
| **Export Cohort/adoption_demo** to temp directory; replace path dependency; compile fresh | Rich real Phoenix SaaS story; useful when browser flow itself is the subject | Existing endpoint/routes, profiles, owner examples, Oban/Repo wiring, tus and provider surfaces; familiar runnable demo | Must exclude `_build`, `deps`, UI artifacts, fixtures with parent paths; remove `../..`; replace test inline Oban/cassettes/sandbox; potentially compile LiveView, DNS cluster, vendor assets, Mux/JOSE for a storage retry; host lock differs from canonical lock. UI churn can break recovery proof. Without UI acceptance, most richness is unused. | Reject as default. Reconsider only for a named browser-specific assertion that minimal host cannot express through supported HTTP. |
| **Dedicated minimal generated Phoenix host** using narrow existing package/workspace/migration conventions | Directly models “install library, own Repo/Oban, upload, let real jobs recover, inspect, clean up” | External build isolation is easy to explain; minimal support footprint; explicit lifecycle boundaries; independently replaceable OS runtime; routes can forward shipped plugs; small owned application makes failures legible | A second small fixture must be maintained. Generation/patching can drift; pin generator and validate resulting host rather than silently replacing strings. Native dependency compilation still costs time. | **Choose.** Keep footprint bounded and share only stable mechanics with existing proof. |
| **Generalize current generated-app smoke harness** with recovery/scenario modes | Strong continuity with release install proof | Existing external package setup, migrations, image/video/tus/Mux/GCS profiles, command timeout and receipt scaffolding | Current helper also owns upgrades, compatibility, tags, sandbox tests, source string generation, receipt reruns. Adding long-running OS process/restart/fault state to this owner couples distinct proof semantics and encourages mode flags or giant fixture generators. Merely changing `testing: :manual` is insufficient. | Reject whole-harness generalization. Permit small reuse/extraction when both callers need exactly the same package primitive; copying a few explicit lines is preferable to a new dependency or unstable abstraction. |

A naked Plug-only host is a useful negative/control fixture but would weaken the declared Phoenix adopter story if made authoritative. Keep Phoenix Endpoint/Router and host Repo; omit HTML/LiveView/assets unless a selected scenario needs them. An existing shipped Plug can be forwarded normally; Plug documents composable routing/forwarding, so no twin-only Rindle endpoint is needed. [Plug.Router](https://hexdocs.pm/plug/Plug.Router.html#forward/2)

Phoenix supports API-shaped generation with `--no-html --no-assets`; `--no-install` suppresses automatic dependency fetching. Explicitly unset `PHX_NEW_CACHE_DIR`: the documented cache copies `_build`, `deps`, and `mix.lock`, which would defeat fresh compilation if inherited. Only use flags supported by the pinned generator; latest docs are guidance, not permission to upgrade it. [Phoenix generator](https://hexdocs.pm/phx_new/Mix.Tasks.Phx.New.html)

## Package contract: bytes first, host second

**Proposed default:** one fresh package build per twin run; one read-only external unpack of those exact bytes; all registered scenarios in that run share that artifact identity. A rerun is a new run and a new build. No local package registry and no publish are needed.

Hex officially builds an unpublished local tarball with `mix hex.build`; `--output` selects tar output, whereas `--unpack --output` selects an unpack directory. The latter is useful existing smoke behavior, but the twin needs retained tar bytes as its checksum authority. [Hex build](https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html)

1. Builder records clean immutable subject SHA, toolchain, generator version, and explicit packaging inputs. Build into an empty run-owned external directory. Fail if package output already exists; no `ensure-if-present` shortcut and no network/published-version substitution.
2. Compute SHA-256 of the entire produced `.tar`. Name the field `package_tar_sha256`; keep metadata digest and content manifest digest separate. A source SHA is provenance, not a checksum of the built package.
3. Unpack exactly that tar with the installed Hex tooling's verified unpack mechanism, recording metadata, manifest and resulting bytes. Do not build twice to manufacture a tar checksum for a different unpack. Hex-core exposes unpacking and outer checksum; the package has an outer tar containing version/checksum/metadata/content archive. Implementation should use the installed tool version's existing Hex unpack path or a narrow verified archive procedure, not add a runtime hex_core dependency or depend on an undocumented Hex private function. [Hex tarball implementation](https://raw.githubusercontent.com/hexpm/hex_core/main/src/hex_tarball.erl)
4. Validate extraction before compilation: relative normalized paths only; no escaping symlink/hardlink, duplicate/conflicting entry, parent traversal, `_build`, cached BEAM, repository test helper, or unapproved extra roots. Compare unpacked package bytes to the retained archive manifest, not a separate checkout copy. Record immutable package manifest before and after scenario execution.
5. Materialize host source, documented fixtures, host-owned fault adapter, and lock into another run-owned directory. Its sole Rindle dependency may be `{:rindle, path: absolute_attested_unpack}`. Explicitly label this **unpacked local Hex artifact consumption**, not registry resolution. Published-version resolution remains the existing separate proof path.
6. Resolve ordinary dependencies with the host lock; compile all code into fresh host `_build`. Run consumer and verifier without any checkout mount or read access. Parent orchestration may build/read packaging inputs; lifecycle behavior must not branch on checkout source, source text, docs reflection, beam disassembly, or test support.
7. Verify loaded Rindle code origin is the freshly compiled external package build, and no repository `_build`/`test/support`/`test/adopter` paths are present. This is runtime provenance checking, not parsing internal source to decide expected behavior. The library itself naturally executes its internal modules; forbidden coupling is **consumer/fault/helper calls into unsupported internals**, not the mere presence of internal modules in its package.

Mix supports path dependencies and ordinarily compiles dependencies in `:prod`; dependency projects' own lockfiles are ignored. Optional dependencies do not automatically propagate to consumers. Therefore the root `mix.lock` alone cannot establish the external host's dependency truth; bind the consumer lock and resolved graph. Do not force dependency `env: :test` to gain helpers. [Mix dependency contract](https://hexdocs.pm/mix/Mix.Tasks.Deps.html)

`mix hex.package fetch ... --unpack` fetches a registry artifact; it is not a local unpublished-tar installation command. Do not fetch “same version” and call it the freshly built subject. [Hex package task](https://hexdocs.pm/hex/Mix.Tasks.Hex.Package.html)

The actual shipped file projection is `lib`, migration/static priv paths, `mix.exs`, README/RUNNING/CHANGELOG/LICENSE and guides (`mix.exs:270–279`). Root `test`, `scripts`, examples and `mix.lock` are not package contents. Required host fixtures must be explicitly copied as host inputs and hashed; never read library test fixtures at runtime. Do not mistake packaged guides for a supported introspection API.

## Hermeticity and dependency truth

Do not conflate three different claims: fresh **Rindle artifact**, fresh **compiled code**, and pinned **third-party dependency inputs**. All three need explicit run facts. Empty `_build` and blocked parent paths are essential. A verified cache of dependency *source archives* can reduce network traffic without permitting cached BEAMs; compile locally in the external host. If a faster compiled-dependency cache is later desired, it is an explicit evidence-policy change, not an invisible optimization.

Sanitize inherited environment rather than appending a few variables to it. Current runner invokes `System.cmd(... env: env ...)` with a small supplied list (`test/install_smoke/support/generated_app/command_runner.ex:7–13`); a twin must explicitly control `ERL_LIBS`, `ERL_FLAGS`/`ERL_AFLAGS`/`ELIXIR_ERL_OPTIONS`, `MIX_BUILD_PATH`, `MIX_DEPS_PATH`, `MIX_HOME`, `MIX_ARCHIVES`, `PHX_NEW_CACHE_DIR`, and scenario-specific profile/source overrides. Use an allowlist and scoped temporary homes while preserving only declared toolchain/network/service configuration. Record redacted identities, never full secret environment dumps.

Choose one authoritative Docker/Compose path for the isolated external host, reusing existing service/readiness mechanics rather than maintaining native and container authorities. Existing `docker/compose.cohort-demo.yml:12–16` and `:32–36` provide PostgreSQL/MinIO readiness examples, but do not reuse its application image wholesale: `docker/Dockerfile.cohort-demo:4` selects Elixir 1.19.5 / OTP 28.5.0.2, lines 37–40 stage repository inputs, and line 56 copies the entire checkout. The twin build context must contain only the attested external package, minimal host, and declared tooling, with the canonical 1.17/27 toolchain. Its media prerequisites need actual probes: `RUNNING.md:26` requires FFmpeg >= 6.0 and `lib/rindle/av/probe.ex:8–23` enforces it. An unversioned distro `apt install ffmpeg` (demo Dockerfile line 11) is not proof that the installed runtime satisfies that minimum. Record libvips and FFmpeg/ffprobe capabilities for declared media rather than infer support from the base-image name.

Use a consumer container with no checkout mounted over an after-the-fact string assertion. Run a negative control that tries an undeclared checkout read and a repository BEAM injection; both must fail. Do not implement a bespoke security sandbox framework: ordinary isolated process/container setup and small executable guards suffice.

### Exact current locks and support boundaries

| Input | Repository root lock | Cohort lock | Evidence |
| --- | --- | --- | --- |
| Phoenix | 1.8.12 | 1.8.12 | `mix.lock:50`; `examples/adoption_demo/mix.lock:31` |
| Ecto / ecto_sql | 3.14.2 / 3.14.0 | 3.14.2 / 3.14.0 | root lines 15–16; demo lines 8–9 |
| Oban | 2.21.1 | 2.23.1 | root line 49; demo line 30 |
| Postgrex | 0.22.4 | 0.22.4 | root line 58; demo line 40 |
| Plug | 1.20.3 | 1.20.3 | root line 55; demo line 38 |
| ExAws | 2.7.0 | 2.6.1 | root line 19; demo line 11 |
| Req | 0.7.5 | 0.7.3 | root line 60; demo line 41 |
| Bandit | not locked at root | 1.13.1 | demo line 2 |

Generator is explicitly **phx_new 1.8.9**, not Phoenix runtime version (`scripts/ci/ensure_phx_new.sh:4`). Preserve this pin unless a focused compatibility failure justifies a change. Use canonical supported Elixir **1.17.3 / OTP 27.3.4.15** initially (`RUNNING.md:318–321`), record actual host resolution, and prefer versions already exercised by canonical install proof. Do not copy Cohort's newer Oban silently or substitute latest versions.

The root and demo declare Elixir `~> 1.15` (`mix.exs:11`; demo `mix.exs:10`). Phoenix **1.8.12's own versioned source** also declares `~> 1.15`, whereas latest Phoenix installation docs now say 1.17 or later. This illustrates why support claims must bind exact package/toolchain inputs rather than latest docs. It does not prove the entire current transitive graph supports Elixir 1.15. The twin's single 1.17/27 cell adds no new broad compatibility promise; existing CI owns broader supported cells (`RUNNING.md:63–70`). [Phoenix 1.8.12 source](https://raw.githubusercontent.com/phoenixframework/phoenix/v1.8.12/mix.exs), [current installation guide](https://hexdocs.pm/phoenix/installation.html)

## Consumer-first runtime and failure UX

Use one maintainer command, e.g. `scripts/twin.sh foundation`, with normal stages: `preflight → build → provision → migrate → compile → boot → stimulate → observe → stop/restart → verify → cleanup → receipt`. Exact filename is routine implementation discretion. `--help` lists required supported toolchain/services, the fixed foundational scenario, output destination and cleanup policy. No independent developer should need to edit an internal module or learn a bespoke scenario language.

Host source should read like a small Phoenix application:

```elixir
children = [
  TwinHost.Repo,
  {Oban, Application.fetch_env!(:twin_host, Oban)},
  TwinHostWeb.Endpoint
]
Supervisor.start_link(children, strategy: :one_for_one, name: TwinHost.Supervisor)
```

Use host migrations for its marker/owner records, host `Oban.Migration`, then a pinned Rindle wrapper. Standard `mix ecto.migrate` is sufficient; `Ecto.Migrator.with_repo`/`run` is the documented alternative if migration happens outside normal Mix startup. Do not rediscover and load packaged migration source. [Ecto migrator](https://hexdocs.pm/ecto_sql/Ecto.Migrator.html)

Run the scenario host outside SQL Sandbox with Oban testing disabled. Oban documents that inline work executes without touching the database, and both inline/manual modes suppress background query/queue execution. Those modes suit unit/install assertions, not TWIN-05. Host-owned `Oban.Job` reads can observe actual attempts; do not mutate attempts, `scheduled_at`, or job state to manufacture proof. [Oban testing](https://hexdocs.pm/oban/testing.html)

Use documented `Rindle` lifecycle calls and documented storage/HTTP surfaces. For example, initiate/upload/verify, allow actual Oban workers to advance state, query supported diagnostics and host-owned job records, then detach/clean up. Do not copy canonical smoke's direct worker calls. A host adapter implementing `Rindle.Storage` may fail the first selected delete and delegate all other operations to `Rindle.Storage.S3`; target an object/run identity so unrelated operations cannot consume its counter (`lib/rindle/storage.ex:1`, `:142`). Use a tiny fixed host-owned PostgreSQL fault table keyed by run, operation, object, and attempt to keep fail-N state across host restart. Update its counter atomically; never alter Rindle business rows or Oban attempt fields. This selects one durable mechanism and avoids file locking or a general fault-control service. Processor behavior existence alone is not configuration support: `ProcessVariant.processor_for` is hardcoded (`lib/rindle/workers/process_variant.ex:358`), so 137 should not add a fake processor option or new public seam.

Prefer public lifecycle calls plus `Rindle.runtime_status` counts in the fresh one-asset tracer when they establish the assertion. Where exact asset retention/absence or residue requires stronger evidence, permit a finite documented read-only Ecto query surface: `guides/core_concepts.md:14` names the domain schemas, lines 200–208 document queryable tables, and `guides/troubleshooting.md:358–377` demonstrates host Repo queries against assets, variants and upload sessions. Read-only documented schema aliases are supported consumer use; reject unsupported private workers/config/test helpers, reflection, or direct lifecycle mutations. Bounded/degraded `runtime_status` output alone cannot prove exact absence. Generic run-owned inventory remains necessary for total residue.

On failure, print a short stage, stable reason, last observed state, and receipt path. Example: `observe: retry_not_observed; job 42 stayed available; deadline 45s; receipt …`. Missing PostgreSQL/MinIO or media executables is `preflight_failed`, not passed/skipped. Timeout diagnostics must preserve actual state and stop child processes. Do not append a loop that reruns the whole lifecycle until green. Logs/receipts must redact URLs, credentials, webhook bodies and tokens before persistence.

## Bounded 137 tracer and 138 extension

137 should prove substrate with **one happy path plus one combined retry/restart tracer** using an image, MinIO and storage delete failure:

- real artifact compile/boot/migration and readiness checks;
- submit initial lifecycle stimulus once; let persisted Oban work create a real ready variant;
- detach once, observe selected delete failure and durable retryable job with actual attempt history;
- terminate the separate host runtime while durable retry is pending; restart against same run-owned DB/objects and same stimulus identity;
- allow ordinary Oban scheduling to complete and independently inspect effects and residue;
- clean up, validate receipt, and run a finite negative-control suite for package/source/receipt violations.

This is a proposed architectural tracer, not a promise that all purge details are already proven. Runtime research must check the worker's real scheduling/backoff and crash-rescue behavior before planning exact milestones. Avoid requiring restart of an executing job in the first tracer: pending durable work proves runtime replacement without conflating a separate stale-execution rescue protocol. 138 owns interrupted tus client recreation, real AV failures, provider duplicate/out-of-order events, interrupted cleanup, and broader matrix assertions. 137 owns the reusable ability to drive/observe those through the same artifact boundary; do not pre-register unimplemented scenarios as successes.

137 can therefore have a small ordinary GSD plan set: package guard/host; persisted tracer/fault boundary; receipts/cleanup/negative controls. This is a grouping recommendation, not execution authorization. Target no more than six plans and three tasks per plan; repeated failure at the same gate triggers rescope, not another qualification/journal layer (Phase 134 D-134-01). Keep existing PR lane names and release coupling unchanged; measure one tracer before choosing any added critical-path CI execution.

## Adversarial pass

| Attack or accidental green | Why shallow proof passes | Required executable rejection/evidence |
| --- | --- | --- |
| Build says SHA A; unpack actually from B | Version/name or source SHA matches while contents differ | Exact tar bytes hashed, exact tar unpacked, manifest bound; swap/tamper negative control fails before compile. |
| Hash only `hex_metadata.config` | Metadata can remain identical after source change | Whole tar hash plus extracted-content digest; modify packaged source without touching metadata and reject mismatch. |
| Host uses `../..`, a symlink, `ERL_LIBS`, `-pa`, copied BEAM, or generator cache | Directory exists and `repository_path_fallback?: false` is self-reported | No checkout mount/read; sanitized environment; fresh build; real origin check; injection controls fail. |
| Package excludes a needed file but host loads root helper | Monorepo support masks missing consumer dependency | External host inputs finite/hashed; no test/support or file read outside workspace; missing packaged file fails naturally. |
| “Retry” is direct worker call, HTTP retry, manual `retry_job`, or fresh duplicate request | Eventual success does not identify which retry owner acted | Same persisted Oban job identity, attempts/errors/timestamps, one stimulus identity; no test worker execution or manufactured timestamps. |
| Fault counter restarts at zero with host | Each resumed attempt fails forever, or first run's failure is erased | The fixed host-owned PostgreSQL fault table survives subject restart; persist its attempts separately from library business rows and use atomic counter updates. |
| Resubmission hides lost durable work | Same logical output appears but restart correctness is unproved | Driver remains outside subject; stimulus count fixed before kill; restart cannot call creation path. |
| Wrapper claims full S3 behavior but changes capabilities/errors | Tests exercise a private fake world | Preserve callbacks/return vocabulary/capabilities and delegate ordinary behavior; package contract guard checks supported seam. |
| Shared bucket cleanup removes unrelated data | “Zero residue” obtained by deleting other runs' objects | Unique owned DB and bucket or strictly owned prefix; inventory ownership before deletion; never reset shared default bucket. |
| Hidden transport retries consume fail-N inside one job | Failure count looks like durable retries | Observe HTTP/provider effects separately from Oban attempts; choose storage-return failure for foundational proof. |
| Internal schemas/functions are treated as public because compiled | Elixir exported functions are callable | Consumer call manifest/guard permits documented API, behaviors and fixed documented read-only schema/Repo queries; reject unsupported schema access, worker calls, `@doc false` facade helpers, lifecycle-row mutation, or source/BEAM inspection. |
| Receipt's schema passes while cleanup failed | Well-shaped narrative is mistaken for true state | Separate verifier queries run-owned DB/job/object/temp inventories; failed cleanup produces failed receipt and nonzero exit. |

## Cross-ecosystem lessons worth keeping

**Testcontainers:** explicit health, HTTP and command wait strategies are supported, each bounded by startup timeout. Transfer the principle of service-specific readiness rather than arbitrary sleeps: PostgreSQL connection/migration, MinIO operation, media command version/capability, host HTTP readiness. This does not require adding Testcontainers; existing Compose/shell probes can implement the same contract. [Official wait strategies](https://node.testcontainers.org/features/wait-strategies/)

**AWS SDKs:** request retries are bounded, classified and can be transparent to the caller; total request attempts are a different observable from job attempts. Transfer only that distinction and the need to record retry ownership. Do not import AWS's settings or claim they describe ExAws; determine ExAws/Req configuration from the actual host graph. [AWS retry behavior](https://docs.aws.amazon.com/sdkref/latest/guide/feature-retry-behavior.html)

**Phoenix/Ecto/Oban:** ordinary application supervision, host migration ownership and explicit asynchronous queue semantics already provide the substrate. The strongest DX here is a small recognizable Phoenix app plus precise failure output, not a new testing platform.

## Remaining implementation checks, not user questions

- Confirm the installed Hex version's exact supported way to unpack the retained local tar, without a private Hex API dependency. `hex.build --unpack` alone is not enough to retain the exact checksum subject.
- Confirm consumer lock policy permits the selected canonical toolchain and generated host dependencies together. Record exact resolved versions; do not assert root/demo lock equality.
- Verify subprocess termination kills the whole separately supervised host and its descendants. Current Task timeout is useful precedent, not proof of OS process-tree cleanup.
- Runtime owner must validate selected purge job attempts, retry timing and pending-stage restart trigger. If that exact tracer is awkward, choose the narrowest supported storage operation with persisted retry; do not widen API scope.
- Final package/public-call guard should distinguish documented supported Rindle calls and documented read-only schemas/Repo queries from merely exported/private implementation functions. Host-owned Oban query access is legitimate; Rindle internals present inside the compiled package are normal. Prefer the fresh one-asset public lifecycle/runtime-status path where sufficient, but never infer exact absence from bounded/degraded diagnostic output.

Further research is warranted only if one of these changes the selected architecture or acceptance. No general library/framework survey or new dependency is needed.
