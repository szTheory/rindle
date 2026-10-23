# Phase 137: Built-Package Twin Foundation — Pattern Map

**Mapped:** 2026-10-21  
**Files analyzed:** 18 proposed new/modified files or file groups  
**Analogs found:** 15 / 18 (several are partial; filenames below are planner suggestions, not locked decisions)

The authoritative worktree is `.claude/worktrees/phase136-execution`. All analogs named below were checked with `git ls-files` in that worktree. No ignored capability mirror is an analog. There is no `137-RESEARCH.md` yet; this map uses `137-CONTEXT.md` and the five discussion research/synthesis files. Do not make existing generated-app smoke's `testing: :manual`, `perform_job`, or permissive package-root semantics the twin's runtime pattern.

## File Classification

| Proposed new/modified file | Role | Data flow | Closest tracked analog | Match |
|---|---|---|---|---|
| `scripts/maintainer/twin.sh` | CLI/utility | batch, process I/O | `scripts/release_preflight.sh` | role match |
| `scripts/maintainer/twin_runner.py` | service/utility | batch, file I/O, event driven | `scripts/maintainer/phase136_evidence.py` | role match |
| `docker/compose.twin.yml` | config | service orchestration | `docker/compose.cohort-demo.yml` | role match |
| `docker/Dockerfile.twin` | config | build/file I/O | `docker/Dockerfile.cohort-demo` | role match with isolation caveat |
| `test/twin/host/mix.exs` and `mix.lock` | config | package resolution | `test/install_smoke/support/generated_app/patcher.ex` | partial |
| `test/twin/host/config/config.exs` and `runtime.exs` | config | request response/runtime | `examples/adoption_demo/config/config.exs`, `runtime.exs` | role match |
| `test/twin/host/lib/twin/application.ex` and Repo/Endpoint/Router | component/config | supervision, HTTP | `examples/adoption_demo/lib/adoption_demo/application.ex` | role match |
| `test/twin/host/priv/repo/migrations/*_install_oban.exs` | migration | CRUD | `test/install_smoke/support/generated_app/contracts.ex` | exact |
| `test/twin/host/priv/repo/migrations/*_install_rindle.exs` | migration | CRUD | `test/install_smoke/support/generated_app/contracts.ex` | exact |
| `test/twin/host/priv/repo/migrations/*_create_fault_counter.exs` | migration | CRUD | `test/install_smoke/support/generated_app/migrations.ex` | partial |
| `test/twin/host/lib/twin/profile.ex` | config | transform | `examples/adoption_demo/lib/adoption_demo/rindle_profile.ex` | exact |
| `test/twin/host/lib/twin/storage_fault.ex` | service | request response, storage I/O | `lib/rindle/storage/s3.ex`, `lib/rindle/storage.ex` | role match |
| `test/twin/host/lib/twin/tracer.ex` | service | event driven, durable job | `test/adopter/canonical_app/lifecycle_test.exs`, `lib/rindle.ex` | partial |
| `scripts/maintainer/twin_receipt.py` (or a small section of runner) | utility | transform/file I/O | `scripts/maintainer/phase136_evidence.py` | role match |
| `scripts/maintainer/twin_cleanup.py` (or a small section of runner) | utility | batch, file I/O | `scripts/mux_soak_cleanup.sh` | partial |
| `test/install_smoke/twin_contract_test.exs` | test | request response/transform | `test/install_smoke/phase136_qualification_test.exs` | role match |
| `test/install_smoke/twin_fault_test.exs` | test | event driven/CRUD | none | none |
| `guides/built_package_twin.md` or `RUNNING.md` addition | documentation | maintainer workflow | `RUNNING.md` | role match |

Exact names and whether small utilities are one file or two are at planner discretion. Keep runtime code at stable `scripts/` and `test/` paths; do not load `.planning/phases` as runtime configuration. The host is an external staged input and must be copied into the small Docker build context; it is not an in-repository app at runtime.

## Pattern Assignments

### Entrypoint, archive staging, container (`twin.sh`, `twin_runner.py`, Compose, Dockerfile)

**Sources:** `scripts/release_preflight.sh:26-41`, `test/install_smoke/support/generated_app/workspace.ex:7-10,27-41`, `scripts/ci/ensure_phx_new.sh:4-24`, `docker/compose.cohort-demo.yml:3-16,18-36,63-73`, `scripts/maintainer/phase136_evidence.py:89-112`.

```sh
# scripts/release_preflight.sh:30-35 — caller builds, then passes an external artifact
(
  cd "$SOURCE_ROOT"
  MIX_ENV=dev mix hex.build --unpack --output "$PACKAGE_ROOT"
)
export RINDLE_INSTALL_SMOKE_PACKAGE_ROOT="$PACKAGE_ROOT"
```

```elixir
# workspace.ex:27-40 — narrow no-UI host generation switches
["mix", "phx.new", generated_app_root,
 "--no-assets", "--no-dashboard", "--no-mailer", "--no-gettext", "--no-install"]
```

```yaml
# docker/compose.cohort-demo.yml:12-16,32-36,68-73
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres -d adoption_demo_dev"]
  interval: 2s
  timeout: 5s
  retries: 15
# consumer depends_on uses condition: service_healthy; init uses service_completed_successfully
```

Reuse the stage ordering, Compose readiness conditions and bounded subprocess pattern (`phase136_evidence.py:89-112` starts a process group, enforces time/output limits, and kills on breach). Change the build contract: `workspace.ex:22-24` accepts any existing package directory, and `release_preflight.sh` produces only an unpack; neither proves exact tar bytes. Build **one** `mix hex.build` archive in a fresh parent root; hash retained tar bytes as `package_tar_sha256`; extract that same tar through safe-path/material checks; hash metadata and extracted tree separately; compile the external unpack; verify loaded code origin and no repository BEAM/deps path. The explicit host dependency path to this attested unpack is valid (`patcher.ex:53-61`), while arbitrary env-supplied package paths are not. Bind the host's actual lock, host/input hashes, Elixir 1.17.3/OTP 27.3.4.15, and resolved Oban 2.21.1. `scripts/ci/ensure_phx_new.sh:4` pins the generator at 1.8.9, distinct from Phoenix runtime 1.8.12.

The Compose file may copy service health mechanics, but must allocate a unique DB and bucket and retain the temp root across host restart. The Dockerfile must reverse the Cohort source boundary: `docker/Dockerfile.cohort-demo:37-40,56` copies repository manifests and then `COPY . /app`, and its base is Elixir 1.19.5/OTP 28.5.0.2 at line 4. Stage only declared host, exact extracted archive, and declared tooling in the twin build context; probe actual FFmpeg/ffprobe/libvips/DB/S3 capabilities. Image-only evidence cannot claim AV support.

### Minimal host and dependency resolution (`mix.exs`, config, Application, Repo, Endpoint)

**Sources:** `test/install_smoke/support/generated_app/patcher.ex:53-61,445-455`; `examples/adoption_demo/lib/adoption_demo/application.ex:12-22`; `examples/adoption_demo/config/config.exs:10-26,30-47`; `examples/adoption_demo/config/runtime.exs:34-68,71-87`.

```elixir
# adoption_demo/application.ex:12-22 — Repo starts before ordinary default Oban
children = [
  AdoptionDemoWeb.Telemetry,
  AdoptionDemo.Repo,
  {Oban, Application.fetch_env!(:adoption_demo, Oban)},
  {DNSCluster, query: Application.get_env(:adoption_demo, :dns_cluster_query) || :ignore},
  {Phoenix.PubSub, name: AdoptionDemo.PubSub},
  AdoptionDemoWeb.Endpoint
]
opts = [strategy: :one_for_one, name: AdoptionDemo.Supervisor]
Supervisor.start_link(children, opts)
```

```elixir
# adoption_demo/config/config.exs:12-26 — host owns Repo and queue config
config :adoption_demo, ecto_repos: [AdoptionDemo.Repo]
config :rindle, :repo, AdoptionDemo.Repo
config :adoption_demo, Oban,
  repo: AdoptionDemo.Repo,
  queues: [rindle_media: 2, rindle_promote: 2,
           rindle_process: 2, rindle_purge: 1, rindle_maintenance: 1]
```

Copy the ownership and startup order into a small host, with default Oban, ordinary Repo pool, no SQL Sandbox, and **no `testing:` option**. Exclude demo-only DNSCluster, Mux cassettes (`application.ex:8-10`), HTML/LiveView/assets, broad provider configuration, and Cohort's newer lock. `patcher.ex:121-124,378-410` deliberately uses `testing: :manual`; `examples/adoption_demo/config/test.exs` uses inline execution. Neither yields persisted queue retries. Runtime S3 endpoint/bucket config (`runtime.exs:34-68`) is a useful shape, but substitute run-owned names and private credentials; never export URLs or secret values into a receipt. The `Repo` module and minimal Endpoint/Router follow Phoenix generator output; there is no need for a custom host framework.

### Host migrations and persistent fault state

**Sources:** `test/install_smoke/support/generated_app/contracts.ex:164-186`; `test/install_smoke/support/generated_app/migrations.ex:27-49,52-82`.

```elixir
# contracts.ex:164-186 — separate host-owned migration wrappers
defmodule RindleSmokeApp.Repo.Migrations.InstallHostOwnedOban do
  use Ecto.Migration
  def up, do: Oban.Migration.up()
  def down, do: Oban.Migration.down(version: 1)
end

defmodule RindleSmokeApp.Repo.Migrations.InstallRindle do
  use Ecto.Migration
  def up, do: Rindle.Migration.up(version: 1)
  def down, do: Rindle.Migration.down(version: 1)
end
```

Keep `Oban` in `public` and supported Rindle data in `rindle`, all inside a unique disposable database; do not invent a run-specific schema prefix. The `migrations.ex:37-46` host marker migration shows `use Ecto.Migration`, `create table`, `null: false`, and `timestamps()` for a small owned table. The new fault-counter table needs an exact run/key primary or unique constraint and atomic `UPDATE ... RETURNING`/conflict-safe increment so only one selected source-delete receives the synthetic error. It persists across a stopped host; no existing tracked module provides this exact fault protocol. Never mutate Oban attempts or Rindle lifecycle rows to make a retry.

### Profile and storage fault adapter

**Sources:** `examples/adoption_demo/lib/adoption_demo/rindle_profile.ex:1-9`; `lib/rindle/profile.ex:15-21,34-63`; `lib/rindle/storage.ex:120-153`; `lib/rindle/storage/s3.ex:47-49,61-103`.

```elixir
# adoption_demo/rindle_profile.ex:1-9 — adapter is chosen by public profile DSL
use Rindle.Profile,
  storage: Rindle.Storage.S3,
  variants: [thumb: [mode: :fit, width: 64, height: 64]],
  allow_mime: ["image/png", "image/jpeg"],
  max_bytes: 10_485_760
```

```elixir
# storage.ex:152-153; s3.ex:95-103 — callback and error shape to preserve
@callback delete(key :: String.t(), opts :: keyword()) ::
            {:ok, delete_result()} | {:error, term()}

@impl true
def delete(key, opts) do
  with {:ok, bucket} <- bucket(opts),
       {:ok, result} <- request(S3.delete_object(bucket, key), opts) do
    {:ok, result}
  else
    {:error, reason} -> {:error, reason}
  end
end
```

Use `storage: Twin.StorageFault` in the host profile. Implement **every** `Rindle.Storage` callback by delegating to `Rindle.Storage.S3`, including `capabilities/0`; intercept only `delete/2` for the exact run-owned source key. The first matching call atomically claims the fault and returns a retryable error; later calls delegate unchanged. Preserve the callback's `{:ok, map} | {:error, term}` shape and all S3 options. `lib/rindle/storage.ex:5-7` requires external storage I/O outside DB transactions: claim the tiny counter transaction first, then perform delegate I/O. Do not infer configurable worker injection from the public processor behaviour.

### Lifecycle tracer and restart observations

**Sources:** `test/adopter/canonical_app/lifecycle_test.exs:110-135`; `lib/rindle.ex:377-379,451-480,554-569,593-603,725`; `lib/rindle/workers/purge_storage.ex:25-55` (source-review only).

```elixir
# canonical_app/lifecycle_test.exs:115-134 — public broker + actual signed HTTP PUT
{:ok, session} = Rindle.Upload.Broker.initiate_session(Profile, filename: "adopter.png")
{:ok, %{session: signed, presigned: presigned}} =
  Rindle.Upload.Broker.sign_url(session.id)
:ok = put_to_presigned_url(presigned.url, png_bytes)
{:ok, %{session: completed, asset: asset}} =
  Rindle.Upload.Broker.verify_completion(session.id)
```

```elixir
# lib/rindle.ex:377-379,451-452,554,594 — exact public facade signatures
Rindle.attach(asset_or_id, owner, slot)
Rindle.detach(owner, slot) # returns :ok, not a job ID
Rindle.attachment_for(owner, slot)
Rindle.ready_variants_for(asset_or_id)
```

Copy only the public stimulus and read patterns. `canonical_app/lifecycle_test.exs:138-157` directly calls `perform_job` under a test Repo; the twin must wait for ordinary default Oban workers and committed state. After final detach, discover the unique purge through host-owned `Oban.Job` query (queue `rindle_purge`, matching ordinary args/asset ID). Wait for committed attempt one, retryable state, error, retained asset handle, and exact storage effect. Pause the local purge queue, confirm paused/no running jobs, re-read the **same job** at attempt one, then terminate the entire old host runtime. Start a new runtime against the same DB/bucket/temp/counter and let ordinary scheduling finish attempt two without restimulus. Record old/new runtime identity and pause boundary. A race is incomplete. `purge_storage.ex:27-40` shows variant keys are deleted before the source key; earlier variant deletions are legitimate, and the worker source is evidence for expectations only—never call it from the host.

### Typed receipt, semantic verifier, and safe diagnostics

**Sources:** `scripts/maintainer/phase136_evidence.py:37-61,89-112,124-163,409-448`; `test/install_smoke/support/generated_app_helper.ex:358-373`; `lib/rindle/upload/resumable_telemetry.ex:11-12,117-126`.

```python
# phase136_evidence.py:45-55 — reject duplicate keys and non-finite JSON
def decode_json(data):
    def unique(items):
        value = {}
        for key, item in items:
            require(key not in value, "duplicate_json_key")
            value[key] = item
        return value
    value = json.loads(data, object_pairs_hook=unique,
                       parse_constant=lambda _: (_ for _ in ()).throw(Rejected("nonfinite_json")))
    require(isinstance(value, dict), "json_object_required")
    return value
```

```python
# phase136_evidence.py:429-434 — exclusive creation preserves earlier receipts
descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
result = {"schema_version": 1, "kind": args.operation,
          **subject, "outcome": "blocked"}
```

Use existing Jason in the Elixir host and a small typed, versioned receipt/verifier at the parent; no JSON Schema dependency. Define exact allowed keys/types and source-owned expected scenario IDs, not a list copied from the submitted receipt. Recompute the verdict from bound subject/archive/host/lock/toolchain identities, same persisted Oban job attempt and error, runtime replacement, object/asset effects, cleanup, and complete inventories. Unknown, duplicate, missing, contradictory, skipped, or failed required work exits nonzero even when JSON parses. The Phase 136 qualification verifier permits a structurally authentic `blocked` receipt to exit zero (`phase136_qualification_test.exs:55-66`); that is **not** this acceptance contract. `generated_app_helper.ex:366` calls a metadata-file digest `package_sha256`; the twin must name tar-byte, metadata, and extracted-tree digests separately.

Project observations into allowlisted fields before Jason encoding or console printing. `resumable_telemetry.ex:117-126` uses `Map.drop` plus `Map.take`; twin output should construct bounded safe fields from scratch and omit raw signed URLs, child output, arbitrary job errors, bodies, credentials, and environment dumps. `phase136_evidence.py:115-121` only substitutes inherited secret-like env values; it cannot cover generated signed URLs or remote error bodies. Capture raw subprocess output privately with hard limits (`:89-112`), then publish only stage/reason/dependency codes. Run canary tests over receipts, stdout/stderr, access logs, and captured telemetry. State synthetic identity and zero independent-pilot credit in every artifact/summary. A checksum verifier does not authenticate an invented trusted-runner observation set.

### Domain cleanup, infrastructure disposal, janitor

**Sources:** `guides/operations.md:18-28,50-71`; `lib/mix/tasks/rindle.cleanup_orphans.ex:65-95`; `scripts/mux_soak_cleanup.sh:33-50,77-100`; `test/install_smoke/support/generated_app/workspace.ex:14-17`.

```elixir
# cleanup_orphans.ex:72-78 — dry run is the default
dry_run? =
  case Keyword.fetch(opts, :dry_run) do
    {:ok, value} -> value
    :error -> not Keyword.get(opts, :live, false)
  end
```

Copy the `mux_soak_cleanup.sh:77-100` idea of listing and filtering by ownership before deletion, but make the twin's ownership a validated pre-allocation descriptor for its unique DB, bucket and workspace. The existing Mux script treats missing credentials and some list failures as exit-zero no-ops; the twin janitor must report unknown/denied/truncated inventory as incomplete, preserve decoys, be idempotent, and avoid overwriting the original failed receipt. Observe terminal asset/job/object/multipart/temp/process facts **before** infrastructure disposal. Domain cleanup uses supported `Rindle.detach`, owner-erasure or upload maintenance as applicable, with explicit live flags; a zero exit from a dry run proves nothing. Stop writers; inventory all owned resources with bounded infrastructure/history allowances; then dispose of the private DB/bucket/workspace. `workspace.ex:14-17` ignores `File.rm_rf` outcome and is not a cleanup proof. No existing tracked janitor has the complete ownership and inventory semantics, so design and behaviorally test them.

### Fast contract tests and maintainer instructions

**Sources:** `test/install_smoke/phase136_qualification_test.exs:7-67`; `RUNNING.md:151-159,185-194,318-330`.

```elixir
# phase136_qualification_test.exs:20-51 — mutation that must fail verification
assert {_, 0} = qualify(fixture, "generate")
original = File.read!(fixture.manifest)
# Replace receipt with a plausible incomplete/foreign representation.
File.write!(fixture.manifest, tampered)
assert {_, 1} = qualify(fixture, "verify")
File.write!(fixture.manifest, original)
```

Use ExUnit temporary fixtures and behavioral negative mutations: wrong tar/lock/origin; duplicate/unknown receipt keys; swapped job ID or attempt; missing restart; fake success; cleanup denied/truncated; decoy resource; signed URL and secret canaries. The runner's help/check/run/verify/cleanup commands must expose bounded stages, safe failure codes, evidence location, and reproduction/cleanup invocation. Start with local disposable execution plus fast tests in existing lanes; measure real runtime before proposing CI expansion. `RUNNING.md` names current lane and toolchain gates. No new UI, dependency, required CI context, registry, or release coupling in Phase 137.

## Shared Patterns and Boundaries

- **Public API:** `lib/rindle.ex:377-379,451-480,554-603,725` supplies attach/detach/read/status. Public returned structs and documented read-only `Rindle.Domain.MediaAsset`/`MediaVariant` queries are allowed when needed for exact absence. Do not call private workers/FSM/config owners or mutate domain rows.
- **Host-owned durable authority:** `examples/adoption_demo/application.ex:12-22` starts Repo before default Oban. `contracts.ex:164-186` keeps Oban and Rindle migrations separate. `Oban.Job` reads, queue pause/status, and PostgreSQL catalog inventory belong to the host; job attempts must be committed observations, not fabricated rows.
- **Storage callback/error shape:** `lib/rindle/storage.ex:128-153` and `storage/s3.ex:61-103`; intercept only one exact key, delegate all other callbacks and capabilities, preserve options and return tuples.
- **Safety:** `phase136_evidence.py:45-61,89-112,429-448` provides bounded decoding/process/exclusive-write pieces; `resumable_telemetry.ex:117-126` provides projection discipline. Never copy raw-output publication from `generated_app/command_runner.ex:41-47`.
- **No direct worker execution:** `canonical_app/lifecycle_test.exs:138-157` and generated smoke code are test patterns only. The Phase 137 retry claim depends on default Oban scheduling across two real host processes.

## No Close Analog Found

| File/group | Role | Data flow | Reason |
|---|---|---|---|
| Host fault-counter migration/claim implementation | migration/service | atomic CRUD | Existing host marker table is structural only; no exact once-per-key persistent fault claim exists. |
| Restart tracer's queue-boundary handshake | service | event driven | Existing tests run manual/inline Oban; no tracked same-job attempt-one pause/host-restart/attempt-two flow. |
| Strict owned-resource janitor | utility | batch/file I/O | Existing cleanup scripts have useful filtering but not complete deny/truncation-safe inventory and descriptor validation. |

## Metadata

**Search scope:** tracked `scripts/`, `docker/`, `examples/adoption_demo/`, `test/install_smoke/`, `test/adopter/`, `lib/rindle/`, guides and RUNNING.  
**Analogs read:** 22 tracked source/document files; large files were searched and only relevant ranges inspected.  
**Tracked-source gate:** `git ls-files -- <analog>` returned every source analog named in this map.  
**Pattern extraction date:** 2026-10-21.
