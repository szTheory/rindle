# Phase 87: Docker & Demo DX - Pattern Map

**Mapped:** 2026-06-11
**Files analyzed:** 8 new/modified files
**Analogs found:** 8 / 8

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `docker/compose.cohort-demo.yml` | config | request-response | `docker/compose.cohort-demo.yml` | exact |
| `docker/Dockerfile.cohort-demo` | config | batch | `docker/Dockerfile.cohort-demo` | exact |
| `scripts/demo/up.sh` | utility | request-response | `scripts/demo/up.sh` + `scripts/ensure_minio.sh` | exact |
| `scripts/demo/down.sh` | utility | request-response | `scripts/demo/down.sh` | exact |
| `scripts/demo/reset.sh` | utility | request-response | `scripts/demo/reset.sh` | exact |
| `examples/adoption_demo/config/runtime.exs` | config | request-response | `examples/adoption_demo/config/runtime.exs` | exact |
| `examples/adoption_demo/README.md` | documentation | transform | `examples/adoption_demo/README.md` | exact |
| `examples/adoption_demo/docs/adoption-proof-matrix.md` | documentation | transform | `examples/adoption_demo/docs/adoption-proof-matrix.md` | exact |

## Pattern Assignments

### `docker/compose.cohort-demo.yml` (config, request-response)

**Analog:** `docker/compose.cohort-demo.yml`

**Service topology pattern** (lines 3-17):
```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: adoption_demo_dev
    volumes:
      - cohort-demo-postgres:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d adoption_demo_dev"]
      interval: 2s
      timeout: 5s
      retries: 15
```

**MinIO service + health pattern** (lines 18-34):
```yaml
  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
      MINIO_API_CORS_ALLOW_ORIGIN: "*"
    ports:
      - "9000:9000"
      - "9001:9001"
    volumes:
      - cohort-demo-minio:/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/ready"]
      interval: 2s
      timeout: 5s
      retries: 15
```

Copy the service shape, but replace fixed published ports with Phase 87 loopback interpolation:
`127.0.0.1:${COHORT_MINIO_PORT:-9000}:9000` and
`127.0.0.1:${COHORT_MINIO_CONSOLE_PORT:-9001}:9001`.

**Bucket/CORS init pattern** (lines 36-59):
```yaml
  minio-init:
    image: minio/mc:latest
    depends_on:
      minio:
        condition: service_healthy
    entrypoint: /bin/sh
    command:
      - -c
      - |
        set -e
        mc alias set local http://minio:9000 minioadmin minioadmin
        mc mb --ignore-existing local/rindle-test
        cat > /tmp/cors.json <<'EOF'
        [
          {
            "AllowedOrigin": ["*"],
            "AllowedMethod": ["GET", "PUT", "POST", "HEAD", "DELETE", "PATCH", "OPTIONS"],
            "AllowedHeader": ["*"],
            "ExposeHeader": ["ETag", "x-amz-request-id", "x-amz-version-id"]
          }
        ]
        EOF
        mc cors set local/rindle-test /tmp/cors.json || true
    restart: "no"
```

Keep internal MinIO wiring as `http://minio:9000`; only browser-facing URLs should use the published host API port.

**App service env pattern** (lines 61-88):
```yaml
  cohort-demo:
    build:
      context: ..
      dockerfile: docker/Dockerfile.cohort-demo
    depends_on:
      postgres:
        condition: service_healthy
      minio:
        condition: service_healthy
      minio-init:
        condition: service_completed_successfully
    ports:
      - "4102:4102"
    environment:
      MIX_ENV: prod
      COHORT_DEMO_DOCKER: "1"
      PHX_SERVER: "true"
      PORT: "4102"
      PHX_HOST: localhost
      DATABASE_URL: ecto://postgres:postgres@postgres:5432/adoption_demo_dev
      SECRET_KEY_BASE: cohort-demo-docker-preview-only-not-for-production-use-0123456789abcdef0123456789abcdef
      RINDLE_MINIO_URL: http://host.docker.internal:9000
      RINDLE_MINIO_ACCESS_KEY: minioadmin
      RINDLE_MINIO_SECRET_KEY: minioadmin
      RINDLE_MINIO_BUCKET: rindle-test
      RINDLE_MINIO_REGION: us-east-1
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Replace only the host-facing values: app port binding should become
`127.0.0.1:${COHORT_DEMO_PORT:-4102}:4102`, and `RINDLE_MINIO_URL` should derive from
`${COHORT_MINIO_PORT:-9000}` while keeping internal `PORT: "4102"` stable.

---

### `docker/Dockerfile.cohort-demo` (config, batch)

**Analog:** `docker/Dockerfile.cohort-demo`

**Base image and package install pattern** (lines 1-12):
```dockerfile
FROM hexpm/elixir:1.17.3-erlang-27.1.1-debian-bookworm-20251117-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    ffmpeg \
    git \
    libvips-dev \
    postgresql-client \
  && rm -rf /var/lib/apt/lists/*
```

**Current cache anti-pattern to replace** (lines 14-26):
```dockerfile
WORKDIR /app

COPY . /app

WORKDIR /app/examples/adoption_demo

ENV MIX_ENV=prod

RUN mix local.hex --force \
  && mix local.rebar --force \
  && mix deps.get \
  && mix assets.vendor \
  && mix compile
```

Copy the existing install/build steps, but split dependency fetch from source build. The planner should require this order:
```dockerfile
WORKDIR /app
COPY mix.exs mix.lock /app/
COPY examples/adoption_demo/mix.exs examples/adoption_demo/mix.lock /app/examples/adoption_demo/

WORKDIR /app/examples/adoption_demo
ENV MIX_ENV=prod

RUN mix local.hex --force \
  && mix local.rebar --force \
  && mix deps.get

COPY . /app

RUN mix assets.vendor \
  && mix compile
```

**Entrypoint pattern** (lines 28-33):
```dockerfile
COPY docker/cohort-demo-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 4102

ENTRYPOINT ["/entrypoint.sh"]
```

Keep `EXPOSE 4102`; Phase 87 changes host publishing, not the container port.

---

### `scripts/demo/up.sh` (utility, request-response)

**Analog:** `scripts/demo/up.sh`

**Wrapper skeleton pattern** (lines 1-6):
```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

exec docker compose -f "${repo_root}/docker/compose.cohort-demo.yml" up --build "$@"
```

Preserve strict mode, repo-root resolution, compose file path, `up --build`, and argument passthrough. Add URL-map output before the final `exec`.

**Env default/helper pattern** from `scripts/ensure_minio.sh` (lines 4-12):
```bash
MINIO_URL="${RINDLE_MINIO_URL:-http://localhost:9000}"
MINIO_BUCKET="${RINDLE_MINIO_BUCKET:-rindle-test}"
MINIO_ACCESS_KEY="${RINDLE_MINIO_ACCESS_KEY:-minioadmin}"
MINIO_SECRET_KEY="${RINDLE_MINIO_SECRET_KEY:-minioadmin}"
MINIO_RESET_BUCKET="${RINDLE_MINIO_RESET_BUCKET:-}"

healthcheck_url() {
  printf '%s/minio/health/ready' "${MINIO_URL%/}"
}
```

Use the same quoted `${VAR:-default}` style for:
`COHORT_DEMO_PORT`, `COHORT_MINIO_PORT`, and `COHORT_MINIO_CONSOLE_PORT`.

**Locked URL map content** from `guides/docker_demo_dx.md` (lines 53-63):
```markdown
| Label | URL |
| --- | --- |
| `app` | `http://localhost:${COHORT_DEMO_PORT:-4102}` |
| `admin console` | `http://localhost:${COHORT_DEMO_PORT:-4102}/admin/rindle` |
| `MinIO console` | `http://localhost:${COHORT_MINIO_CONSOLE_PORT:-9001}` |

The labels are locked as `app`, `admin console`, and `MinIO console`.
```

Concrete wrapper output should use exactly these labels and derive ports from the same env vars compose consumes.

---

### `scripts/demo/down.sh` (utility, request-response)

**Analog:** `scripts/demo/down.sh`

**Stop wrapper pattern** (lines 1-6):
```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

exec docker compose -f "${repo_root}/docker/compose.cohort-demo.yml" down "$@"
```

Keep this quiet pass-through unless a shared helper is introduced for all demo wrappers. Do not hard-code a different compose project or file.

---

### `scripts/demo/reset.sh` (utility, request-response)

**Analog:** `scripts/demo/reset.sh`

**Reset wrapper pattern** (lines 1-6):
```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

exec docker compose -f "${repo_root}/docker/compose.cohort-demo.yml" down -v "$@"
```

Keep `down -v` behavior and argument passthrough. It must continue targeting the same compose stack contract as `up.sh`.

---

### `examples/adoption_demo/config/runtime.exs` (config, request-response)

**Analog:** `examples/adoption_demo/config/runtime.exs`

**Port runtime pattern** (lines 19-32):
```elixir
if System.get_env("PHX_SERVER") do
  config :adoption_demo, AdoptionDemoWeb.Endpoint, server: true
end

port = String.to_integer(System.get_env("PORT") || "4102")

config :adoption_demo, AdoptionDemoWeb.Endpoint, http: [port: port]

if System.get_env("COHORT_DEMO_DOCKER") == "1" do
  config :adoption_demo, AdoptionDemoWeb.Endpoint,
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}, port: port],
    check_origin: false,
    server: true
end
```

Internal Phoenix port remains env-driven through `PORT`, with Docker setting `PORT=4102`.

**MinIO env parsing pattern** (lines 34-53):
```elixir
if config_env() in [:dev, :test] or System.get_env("COHORT_DEMO_DOCKER") == "1" do
  minio_url = System.get_env("RINDLE_MINIO_URL", "http://localhost:9000")
  bucket = System.get_env("RINDLE_MINIO_BUCKET", "rindle-test")
  access_key = System.get_env("RINDLE_MINIO_ACCESS_KEY", "minioadmin")
  secret_key = System.get_env("RINDLE_MINIO_SECRET_KEY", "minioadmin")
  region = System.get_env("RINDLE_MINIO_REGION", "us-east-1")

  %URI{host: host, port: port, scheme: scheme} = URI.parse(minio_url)

  config :rindle, :repo, AdoptionDemo.Repo
  config :rindle, Rindle.Storage.S3, bucket: bucket

  config :ex_aws, :s3,
    scheme: "#{scheme}://",
    host: host,
    port: port,
    region: region,
    access_key_id: access_key,
    secret_access_key: secret_key
end
```

Prefer changing compose-provided `RINDLE_MINIO_URL` over changing this parser unless implementation finds a concrete runtime conflict.

---

### `examples/adoption_demo/README.md` (documentation, transform)

**Analog:** `examples/adoption_demo/README.md`

**Docker quick-try docs pattern** (lines 7-35):
````markdown
## Quick try (Docker)

**Preview only** - spin up Postgres, MinIO, and the Cohort UI without installing Elixir, FFmpeg,
or libvips on your machine. First build may take a few minutes.

From the **repository root** (requires Docker Desktop or Docker Engine + Compose):

```bash
./scripts/demo/up.sh
# -> http://localhost:4102
```

Stop and remove containers:

```bash
./scripts/demo/down.sh
```

Wipe database and object storage (fresh seeds on next start):

```bash
./scripts/demo/reset.sh
```

Equivalent compose command:

```bash
docker compose -f docker/compose.cohort-demo.yml up --build
```
````

Update this section with the URL map, env port override examples, `COMPOSE_PROJECT_NAME`, and port-conflict guidance. Keep the preview-only framing.

**Proof matrix pointer pattern** (lines 87-90):
```markdown
## Proof matrix

See [`docs/adoption-proof-matrix.md`](docs/adoption-proof-matrix.md) for what each lane proves
and where. The matrix is drift-checked by `scripts/maintainer/check_adoption_proof_matrix.sh`.
```

Keep docs/proof claims aligned when the Docker contract changes.

---

### `examples/adoption_demo/docs/adoption-proof-matrix.md` (documentation, transform)

**Analog:** `examples/adoption_demo/docs/adoption-proof-matrix.md`

**Local preview row pattern** (lines 24-40):
```markdown
| Concern | Realism | Proof | Where | CI severity |
|---------|---------|-------|-------|-------------|
| Local click-around preview | MinIO | Docker compose - Postgres + MinIO + seeded Cohort UI | `docker/compose.cohort-demo.yml`, `scripts/demo/up.sh` | Optional / not CI-blocking |
```

Keep this row honest about compose/script behavior after env-driven ports and URL output land.

**Try-locally docs pattern** (lines 47-58):
````markdown
## Try the Cohort demo locally

**Docker (preview):** from repo root, `./scripts/demo/up.sh` -> http://localhost:4102

**Native (hack / E2E):**

```bash
bash scripts/ensure_minio.sh
cd examples/adoption_demo && mix setup && mix phx.server
```

Open http://localhost:4102 - dashboard shows members, lessons, posts, and upload lab tabs.
````

Adjust fixed URL claims so the matrix does not contradict wrapper output and env override guidance.

## Shared Patterns

### Shell Strict Mode And Repo Root

**Source:** `scripts/demo/up.sh` lines 1-6; `scripts/ci/adoption_demo_e2e.sh` lines 1-6
**Apply to:** `scripts/demo/up.sh`, `scripts/demo/down.sh`, `scripts/demo/reset.sh`, any small verification helper

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
```

Keep variables quoted and pass external arguments as `"$@"`. Do not use `eval` in new wrapper code.

### Shell Error Handling

**Source:** `scripts/maintainer/check_adoption_proof_matrix.sh` lines 8-20
**Apply to:** Any new static assertion helper

```bash
if [[ ! -f "${matrix}" ]]; then
  echo "check_adoption_proof_matrix: missing ${matrix}" >&2
  exit 1
fi

require_substring() {
  local needle="$1"
  local label="$2"
  if ! grep -Fq "${needle}" "${matrix}"; then
    echo "check_adoption_proof_matrix: matrix missing ${label} (expected: ${needle})" >&2
    exit 1
  fi
}
```

Use explicit stderr messages plus nonzero exits for deterministic checks.

### Runtime Env Defaults

**Source:** `examples/adoption_demo/config/dev.exs` lines 22-28; `examples/adoption_demo/playwright.config.js` lines 5-7
**Apply to:** Runtime and verification code that needs default port behavior

```elixir
config :adoption_demo, AdoptionDemoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4102")],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "S06G2dWKWiRU+RnIZjytSYiC8ybwlH3JBrlT2VQP1qFmY36jG/WHXjC4vLqA+9NI",
  watchers: []
```

```javascript
const port = process.env.ADOPTION_DEMO_BROWSER_PORT || "4102";
const baseURL = `http://localhost:${port}`;
```

For Phase 87, compose and wrapper defaults should mirror this env-default style without changing app-internal port semantics.

### Verification Commands

**Source:** `87-RESEARCH.md` code examples; `scripts/maintainer/check_adoption_proof_matrix.sh` lines 43-48
**Apply to:** Plan verification section

```bash
bash -n scripts/demo/up.sh scripts/demo/down.sh scripts/demo/reset.sh docker/cohort-demo-entrypoint.sh
shellcheck scripts/demo/up.sh scripts/demo/down.sh scripts/demo/reset.sh docker/cohort-demo-entrypoint.sh
COHORT_DEMO_PORT=4212 \
COHORT_MINIO_PORT=9200 \
COHORT_MINIO_CONSOLE_PORT=9201 \
COMPOSE_PROJECT_NAME=rindle-cohort-check \
docker compose -f docker/compose.cohort-demo.yml config
scripts/maintainer/check_adoption_proof_matrix.sh
```

Planner should include rendered-config assertions for loopback host IPs, overridden ports, project name, and `RINDLE_MINIO_URL`.

## No Analog Found

No Phase 87 file lacks a close codebase analog. The implementation should use the existing Docker/demo files as the primary source of truth rather than creating parallel preview infrastructure.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| None | - | - | All planned files have exact or role-match analogs. |

## Metadata

**Analog search scope:** `docker/`, `scripts/`, `examples/adoption_demo/`, `guides/`, `RUNNING.md`
**Files scanned:** 20+
**Pattern extraction date:** 2026-06-11
**Primary constraints:** Preserve preview-only posture, use `COMPOSE_PROJECT_NAME`, bind published ports to loopback, keep internal container ports stable, avoid Traefik/release-build redesign.
