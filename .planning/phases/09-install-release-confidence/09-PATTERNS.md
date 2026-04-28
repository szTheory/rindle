# Phase 09: Install & Release Confidence - Pattern Map

**Mapped:** 2026-04-28
**Files analyzed:** 8
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `test/install_smoke/generated_app_smoke_test.exs` | test | request-response | `test/adopter/canonical_app/lifecycle_test.exs` | exact |
| `test/install_smoke/support/generated_app_helper.ex` | utility | file-I/O | `test/rindle/upload/lifecycle_integration_test.exs` | partial |
| `test/install_smoke/docs_parity_test.exs` | test | transform | `.github/workflows/ci.yml` | partial |
| `scripts/install_smoke.sh` | utility | batch | `.github/workflows/release.yml` | role-match |
| `.github/workflows/ci.yml` | config | batch | `.github/workflows/ci.yml` | exact |
| `.github/workflows/release.yml` | config | batch | `.github/workflows/release.yml` | exact |
| `README.md` | utility | transform | `guides/getting_started.md` | role-match |
| `guides/getting_started.md` | utility | transform | `test/adopter/canonical_app/lifecycle_test.exs` | role-match |

## Pattern Assignments

### `test/install_smoke/generated_app_smoke_test.exs` (test, request-response)

**Analog:** `test/adopter/canonical_app/lifecycle_test.exs`

**Imports and test-module setup** (lines 12-25):
```elixir
use Rindle.DataCase, async: false
use Oban.Testing, repo: Rindle.Adopter.CanonicalApp.Repo

alias Rindle.Adopter.CanonicalApp.Profile, as: AdopterProfile
alias Rindle.Adopter.CanonicalApp.Repo
alias Rindle.Domain.{MediaAsset, MediaAttachment, MediaUploadSession, MediaVariant}
alias Rindle.Ops.UploadMaintenance
alias Rindle.Upload.Broker
alias Rindle.Workers.{ProcessVariant, PromoteAsset, PurgeStorage}

@moduletag :adopter
@moduletag sandbox_repo: Rindle.Adopter.CanonicalApp.Repo
```

**Runtime bootstrap and env override pattern** (lines 40-101):
```elixir
setup do
  case :inets.start() do
    :ok -> :ok
    {:error, {:already_started, :inets}} -> :ok
  end

  case start_supervised(Rindle.Adopter.CanonicalApp.Repo) do
    {:ok, _pid} -> :ok
    {:error, {:already_started, _}} -> :ok
  end

  minio_url = System.get_env("RINDLE_MINIO_URL", "http://localhost:9000")
  bucket = System.get_env("RINDLE_MINIO_BUCKET", "rindle-test")
  access_key = System.get_env("RINDLE_MINIO_ACCESS_KEY", "minioadmin")
  secret_key = System.get_env("RINDLE_MINIO_SECRET_KEY", "minioadmin")
  region = System.get_env("RINDLE_MINIO_REGION", "us-east-1")

  %URI{host: host, port: port, scheme: scheme} = URI.parse(minio_url)

  previous_repo = Application.get_env(:rindle, :repo)
  previous_s3 = Application.get_env(:rindle, Rindle.Storage.S3)
  previous_ex_aws = Application.get_env(:ex_aws, :s3)

  Application.put_env(:rindle, :repo, Rindle.Adopter.CanonicalApp.Repo)
  Application.put_env(:rindle, Rindle.Storage.S3, bucket: bucket)

  Application.put_env(:ex_aws, :s3,
    scheme: "#{scheme}://",
    host: host,
    port: port,
    region: region,
    access_key_id: access_key,
    secret_access_key: secret_key
  )
```

**Canonical presigned-PUT lifecycle to keep smoke narrow** (lines 104-190):
```elixir
test "direct upload through MinIO promotes asset, generates ready variant, and serves signed URL" do
  assert_upload_capabilities!(AdopterProfile.storage_adapter().capabilities())

  {:ok, session} = Broker.initiate_session(AdopterProfile, filename: "adopter.png")
  assert session.state == "initialized"

  {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
  assert signed.state == "signed"
  assert is_binary(presigned.url)

  :ok = put_to_presigned_url(presigned.url, @png_1x1)

  {:ok, %{session: completed, asset: asset}} = Broker.verify_completion(session.id)
  assert completed.state == "completed"
  assert asset.state == "validating"
  assert_enqueued(worker: PromoteAsset, args: %{"asset_id" => asset.id})

  assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})
  {:ok, signed_url} = Rindle.Delivery.url(AdopterProfile, asset.storage_key)

  owner = %Owner{id: Ecto.UUID.generate()}
  {:ok, attachment} = Rindle.attach(asset.id, owner, "primary")
  assert :ok = Rindle.detach(owner, "primary")
  assert_enqueued(worker: PurgeStorage, args: %{"asset_id" => asset.id})
end
```

**Real HTTP PUT helper pattern** (lines 295-322):
```elixir
defp put_to_presigned_url(presigned_url, body)
     when is_binary(presigned_url) and is_binary(body) do
  url_charlist = String.to_charlist(presigned_url)
  headers = []
  content_type = ~c"application/octet-stream"
  request = {url_charlist, headers, content_type, body}

  case :httpc.request(:put, request, [], []) do
    {:ok, {{_http_version, status, _reason}, _resp_headers, _resp_body}}
    when status in 200..299 ->
      :ok

    {:ok, {{_http_version, status, reason}, _resp_headers, resp_body}} ->
      raise "Presigned PUT failed with status #{status} #{reason}: #{inspect(resp_body)}"

    {:error, reason} ->
      raise "Presigned PUT to MinIO failed: #{inspect(reason)}"
  end
end
```

### `test/install_smoke/support/generated_app_helper.ex` (utility, file-I/O)

**Analog:** `test/rindle/upload/lifecycle_integration_test.exs`

**Temporary workspace and cleanup pattern** (lines 47-99):
```elixir
setup do
  case :inets.start() do
    :ok -> :ok
    {:error, {:already_started, :inets}} -> :ok
  end

  root =
    Path.join(System.tmp_dir!(), "rindle-integration-#{System.unique_integer([:positive])}")

  File.mkdir_p!(root)

  previous_local = Application.get_env(:rindle, Rindle.Storage.Local)
  previous_s3 = Application.get_env(:rindle, Rindle.Storage.S3)
  previous_ex_aws = Application.get_env(:ex_aws, :s3)
  minio_url = System.get_env("RINDLE_MINIO_URL", "http://localhost:9000")
  bucket = System.get_env("RINDLE_MINIO_BUCKET", "rindle-test")

  on_exit(fn ->
    case previous_local do
      nil -> Application.delete_env(:rindle, Rindle.Storage.Local)
      value -> Application.put_env(:rindle, Rindle.Storage.Local, value)
    end

    File.rm_rf(root)
  end)

  {:ok, root: root}
end
```

**File-writing and path utility pattern** (lines 102-110):
```elixir
defp write_fixture(root, name) do
  path = Path.join(root, name)
  File.write!(path, @png_1x1)
  path
end

defp storage_path_from_url(url) do
  URI.parse(url).path
end
```

**Presigned PUT helper with explicit failure text** (lines 112-125):
```elixir
defp put_to_presigned_url(presigned_url, body) do
  request = {String.to_charlist(presigned_url), [], ~c"application/octet-stream", body}

  case :httpc.request(:put, request, [], []) do
    {:ok, {{_http_version, status, _reason}, _response_headers, _resp_body}}
    when status in 200..299 ->
      :ok

    {:ok, {{_http_version, status, reason}, _response_headers, resp_body}} ->
      flunk("presigned PUT failed with status #{status} #{reason}: #{inspect(resp_body)}")

    {:error, reason} ->
      flunk("presigned PUT failed: #{inspect(reason)}")
  end
end
```

**Use for Phase 09 helper design:** keep helper logic deterministic and side-effect-oriented: create temp app root, patch files, shell out, restore env, and raise or `flunk/1` immediately on setup drift.

### `test/install_smoke/docs_parity_test.exs` (test, transform)

**Analog:** `.github/workflows/ci.yml`

**Current drift-gate logic to turn into an ExUnit assertion** (lines 335-354):
```bash
GUIDE=guides/getting_started.md
if [ ! -f "$GUIDE" ]; then
  echo "FAIL (D-16): $GUIDE missing"
  exit 1
fi

MATCHES=$(grep -E "Broker\.initiate_session|Broker\.verify_completion|Rindle\.Delivery\.url" "$GUIDE" | wc -l)
if [ "$MATCHES" -lt 3 ]; then
  echo "FAIL (D-16): $GUIDE missing one or more canonical adopter API calls"
  exit 1
fi
```

**Source-of-truth language to preserve in assertions** from `test/adopter/canonical_app/lifecycle_test.exs` lines 7-9:
```elixir
This file is the source of truth for `guides/getting_started.md` (D-16).
The snippet shown in that guide must match the public API calls below;
drift between this file and the guide breaks DOC-01 acceptance.
```

**Use for Phase 09 helper design:** move grep-based drift checks into a narrow test file under `test/install_smoke/` so docs parity can run locally and in CI with the rest of the smoke lane.

### `scripts/install_smoke.sh` (utility, batch)

**Analog:** `.github/workflows/release.yml`

**Current package-build posture to reuse** from `.github/workflows/release.yml` lines 58-76:
```yaml
- name: Build package artifact
  run: mix hex.build --unpack

- name: Assert required paths present in tarball
  run: |
    ls rindle-*/lib/rindle.ex
    ls rindle-*/priv/repo/migrations
    ls rindle-*/README.md
```

**Current CI bootstrap posture to keep consistent** from `.github/workflows/ci.yml` lines 253-333:
```yaml
env:
  MIX_ENV: test
  RINDLE_MINIO_URL: http://localhost:9000
  RINDLE_MINIO_BUCKET: rindle-test
```

**Use for Phase 09 runner design:** keep the script as the single smoke entrypoint for local, CI, and release execution. It should build and unpack the package, fail loudly on artifact/setup drift, and never fall back to repo-source installation when the packaged artifact is broken.

### `.github/workflows/ci.yml` (config, batch)

**Analog:** `.github/workflows/ci.yml`

**Service/env bootstrap pattern** (lines 253-279):
```yaml
env:
  MIX_ENV: test
  PGUSER: postgres
  PGPASSWORD: postgres
  PGHOST: localhost
  PGPORT: "5432"
  RINDLE_MINIO_URL: http://localhost:9000
  RINDLE_MINIO_ACCESS_KEY: minioadmin
  RINDLE_MINIO_SECRET_KEY: minioadmin
  RINDLE_MINIO_BUCKET: rindle-test
  RINDLE_MINIO_REGION: us-east-1

services:
  postgres:
    image: postgres:16-alpine
```

**Narrow MinIO/bootstrap step pattern** (lines 310-333):
```yaml
- name: Start MinIO
  run: |
    docker run -d --name rindle-minio -p 9000:9000 -e MINIO_ROOT_USER=minioadmin -e MINIO_ROOT_PASSWORD=minioadmin minio/minio server /data --console-address ":9001"
    for _ in $(seq 1 30); do
      if curl -fsS http://localhost:9000/minio/health/ready >/dev/null; then
        exit 0
      fi
      sleep 2
    done
    exit 1

- name: Install MinIO client
  run: |
    curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc -o mc
    chmod +x mc
    sudo mv mc /usr/local/bin/mc

- name: Create MinIO bucket
  run: |
    mc alias set local http://localhost:9000 minioadmin minioadmin
    mc mb --ignore-existing local/rindle-test
```

**Existing proof-lane job shape** (lines 242-354):
```yaml
adopter:
  name: Adopter
  runs-on: ubuntu-latest
  needs: [quality, integration, contract]
  ...
  - name: Run adopter tests
    run: mix test --only adopter test/adopter/canonical_app/lifecycle_test.exs
```

**Use for Phase 09 CI change:** add a new slim package-consumer smoke job as a sibling proof lane, reusing this service/bootstrap posture but running the generated-app smoke only.

### `.github/workflows/release.yml` (config, batch)

**Analog:** `.github/workflows/release.yml`

**Current package-build gate** (lines 60-80):
```yaml
- name: Build package artifact
  run: mix hex.build --unpack

- name: Assert required paths present in tarball
  run: |
    set -e
    ls rindle-*/lib/rindle.ex
    ls rindle-*/mix.exs
    ls rindle-*/README.md
    ls rindle-*/LICENSE

- name: Assert prohibited paths absent from tarball
  run: |
    set -e
    if [ -e rindle-*/_build ]; then echo "FAIL: _build leaked into tarball"; exit 1; fi
    if [ -e rindle-*/test ]; then echo "FAIL: test/ leaked into tarball"; exit 1; fi
    if [ -e rindle-*/.github ]; then echo "FAIL: .github leaked into tarball"; exit 1; fi
```

**Dry-run publish posture** (lines 82-98):
```yaml
- name: Dry-run publish (optional — A1 risk tolerance)
  run: |
    set +e
    mix hex.publish package --dry-run --yes 2>&1 | tee /tmp/dryrun.log
    status=${PIPESTATUS[0]}
    if [ $status -ne 0 ]; then
      if grep -q "No authenticated user found" /tmp/dryrun.log; then
        echo "::warning::mix hex.publish --dry-run requires auth ..."
        exit 0
      fi
      echo "::error::mix hex.publish --dry-run failed for non-auth reason"
      exit $status
    fi
```

**Use for Phase 09 release change:** keep these artifact assertions intact, then insert shared consumer-smoke helper reuse after `mix hex.build --unpack` so release and PR smoke exercise the same built package assumptions.

### `README.md` (utility, transform)

**Analog:** `guides/getting_started.md`

**Current install snippet to compress into a layered quickstart** from `guides/getting_started.md` lines 14-37:
```text
## Installation
Add Rindle to your `mix.exs` deps:
def deps do
  [
    {:rindle, "~> 0.1"}
  ]
end
Pick an HTTP client for ExAws if you plan to use the S3 storage adapter ...
Run `mix deps.get` and `mix ecto.migrate` to install Rindle's schemas.
```

**Repo ownership callout to preserve in top-level docs** from `guides/getting_started.md` lines 43-57:
```text
Rindle persists runtime state through **your** Ecto repo.
config :rindle, :repo, MyApp.Repo
```

**Oban ownership callout to surface prominently** from `guides/background_processing.md` lines 20-29:
```text
Rindle ships Oban workers but does not start or supervise Oban itself.
Adopters own the Oban supervision tree, queue topology, reliability
settings, and the default Oban Repo that backs those jobs.
```

**Capability honesty callout to link, not duplicate** from `guides/storage_capabilities.md` lines 57-62:
```text
| MinIO | `Rindle.Storage.S3` | `[:presigned_put, :head, :signed_url, :multipart_upload]` | Automated in default CI and local integration lanes |
| Cloudflare R2 | `Rindle.Storage.S3` | `[:presigned_put, :head, :signed_url, :multipart_upload]` when the provider honors the shipped S3-compatible operations | Documented compatibility target; adopters validate vendor behavior in their own environments |
```

**Use for Phase 09 README change:** keep README short: dependency snippet, explicit Repo/Oban/capability caveats, and a handoff link to `guides/getting_started.md` for the full lifecycle.

### `guides/getting_started.md` (utility, transform)

**Analog:** `test/adopter/canonical_app/lifecycle_test.exs`

**Source-of-truth statement already present** (lines 7-12):
```text
This guide walks you from `mix new` to a working upload → process → deliver
loop. The four-step lifecycle shown below is the **same code path** the
adopter integration test exercises end-to-end against MinIO and PostgreSQL —
drift between this snippet and `test/adopter/canonical_app/lifecycle_test.exs`
is a CI failure
```

**Canonical lifecycle snippet to keep aligned to smoke** (lines 84-101):
```elixir
{:ok, session} =
  Rindle.Upload.Broker.initiate_session(MyApp.MediaProfile, filename: "photo.png")

{:ok, %{session: signed, presigned: %{url: upload_url}}} =
  Rindle.Upload.Broker.sign_url(session.id)

{:ok, %{session: completed, asset: asset}} =
  Rindle.Upload.Broker.verify_completion(session.id)

{:ok, signed_url} =
  Rindle.Delivery.url(MyApp.MediaProfile, asset.storage_key)
```

**Behind-the-scenes async explanation to preserve** from lines 124-139:
```text
After `verify_completion/2` returns, several things are happening asynchronously
in Oban workers ...
1. `Rindle.Workers.PromoteAsset` advances the asset ...
2. `Rindle.Workers.ProcessVariant` is enqueued for each variant ...
3. Variants land in the `ready` state when their processing job completes.
```

**What the guide must update for Phase 09:** replace the current `mix ecto.migrate` shortcut with an install story that explicitly covers host-app plus Rindle migration paths, and make presigned PUT the declared first-run path while pointing multipart/capability nuance to `guides/storage_capabilities.md`.

## Shared Patterns

### Real consumer-proof lifecycle
**Sources:** `test/adopter/canonical_app/lifecycle_test.exs` lines 104-190, `test/rindle/storage/s3_test.exs` lines 111-163  
**Apply to:** `test/install_smoke/generated_app_smoke_test.exs`, any generated-app helper

```elixir
{:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
:ok = put_to_presigned_url(presigned.url, body)
{:ok, %{session: completed, asset: asset}} = Broker.verify_completion(session.id)
{:ok, signed_url} = Rindle.Delivery.url(Profile, asset.storage_key)
```

Do not replace the real HTTP PUT with repo-local storage shortcuts.

### Adopter-owned Repo and default Oban contract
**Sources:** `guides/getting_started.md` lines 43-57, `guides/background_processing.md` lines 20-29 and 43-74  
**Apply to:** README quickstart, generated-app helper setup, smoke runner setup

```elixir
config :rindle, :repo, MyApp.Repo

config :my_app, Oban,
  repo: MyApp.Repo,
  queues: [...]
```

The smoke path and docs must both show adopter-owned runtime wiring explicitly.

### Package-boundary assertions
**Sources:** `mix.exs` lines 96-115 and 154-161, `.github/workflows/release.yml` lines 60-80  
**Apply to:** CI package-smoke job, release helper reuse, README/install narrative

```elixir
extras: [
  "README.md",
  "guides/getting_started.md",
  ...
]

files: ~w(lib priv/repo/migrations mix.exs README.md LICENSE)
```

```yaml
- name: Build package artifact
  run: mix hex.build --unpack
```

Keep smoke and release logic focused on what Hex actually ships.

### Drift-gate pattern
**Sources:** `.github/workflows/ci.yml` lines 335-354, `test/adopter/canonical_app/profile.ex` lines 5-7  
**Apply to:** `test/install_smoke/docs_parity_test.exs`, README/getting-started alignment checks

```elixir
`guides/getting_started.md` ... must be updated to match (D-16; CI-08 adopter lane is the parity check).
```

```bash
grep -E "Broker\.initiate_session|Broker\.verify_completion|Rindle\.Delivery\.url"
```

Keep one declared canonical path, then enforce it with a narrow automated check.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| none | — | — | The codebase already has usable partial analogs for each inferred Phase 09 surface. |

## Metadata

**Analog search scope:** `.github/workflows/`, `guides/`, `mix.exs`, `test/adopter/`, `test/rindle/upload/`, `test/rindle/storage/`, `test/test_helper.exs`  
**Files scanned:** 10  
**Pattern extraction date:** 2026-04-28
