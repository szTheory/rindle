# Built-package twin

The twin is **maintainer-operated synthetic evidence** with
`independent_pilot_credit: false`. It checks one image lifecycle and a controlled
host restart between purge attempts against one freshly built Hex archive.
It does not satisfy independent adoption or authorize a readiness/release claim.

Use the repository's supported Elixir 1.17.3 / OTP 27.3.4.15 build cell, Python 3,
and a running Docker engine with Compose. The consumer image supplies PostgreSQL,
MinIO, libvips and FFmpeg/ffprobe. No live provider credentials are needed. Keep
enough Docker disk space for the image and disposable data; the runner never
prunes shared Docker resources. Network access is needed on a cold image build.

```sh
export ASDF_ERLANG_VERSION=27.3.4.15
export ASDF_ELIXIR_VERSION=1.17.3-otp-27
export ASDF_NODEJS_VERSION=20.18.1
python3 scripts/maintainer/built_package_twin.py check
python3 scripts/maintainer/built_package_twin.py run --verify --cleanup
```

`run` prints the exact retained inputs, receipt and resource descriptor paths.
For an explicit location, use `--evidence-dir /absolute/new-or-empty-directory`.
Existing evidence is refused. Evidence directories are private (0700), and files
are created exclusively. A run builds one tar, hashes its actual bytes, safely
extracts that archive, and compiles it in a small external consumer context.
Checkout/home/socket mounts, private calls, local BEAM output and repository
fallbacks are refused. The host owns its Repo, default Oban instance and migrations.
The root library lock and user `.tool-versions` are unchanged.

The scenario uploads through a signed HTTP PUT, waits for one ready image variant,
attaches and finally detaches once, and injects one original-key delete failure
through the storage behaviour. Its counter is committed in PostgreSQL. The same
Oban job must be retryable at attempt one with an error and retained source. The
runner pauses the queue, checks no running jobs and rereads that row, confirms the
whole old host exited, then starts a new runtime. Ordinary scheduling must complete
that job at attempt two without repeating upload or detach. Earlier variant deletion
is a legitimate partial effect and is recorded.

This checks a controlled restart **between attempts**. It grants no executing-job
crash, disk-loss, exactly-once, full recovery-matrix or AV execution credit. Actual
FFmpeg/ffprobe floors are checked, while the receipt marks AV unexercised.

## Verify retained evidence

Run verification in a separate process using both explicit paths:

```sh
python3 scripts/maintainer/built_package_twin.py verify \
  --inputs /absolute/evidence/inputs.json \
  --receipt /absolute/evidence/receipt.json
```

Keep `package.tar` beside those files. The verifier checks its bytes and extracted
identity, then compares the receipt with the retained runner-owned expectations:
run, source SHA, package, host, lock, fixture, configuration, contract and toolchain.
The expected scenario and success predicates come from source. Strict keys, types,
limits, job/runtime identity, observation order, effects and complete inventories
are required; a submitted success flag cannot replace them. A failed or incomplete
receipt returns nonzero. Semantic verification cannot authenticate a wholly
fabricated trusted manifest/receipt pair; there is no signing or witness service.

## Cleanup and failures

Domain cleanup is observed before infrastructure disposal. All domain rows, objects,
multipart uploads, temp files and host processes must be absent. Only the fixed
migration metadata, two fixture rows, bounded peer infrastructure and three completed
Oban history rows are allowed. Unknown, denied, truncated or residual inventory
cannot mean zero. Baseline bucket versioning must be disabled.

For interrupted or failed runs, use the printed descriptor:

```sh
python3 scripts/maintainer/built_package_twin.py cleanup \
  --descriptor /absolute/evidence/resources.json
```

Cleanup refuses running, paused or unobservable hosts and foreign resource users.
There is no active-host override. Stop the exact run host and confirm termination
before cleanup; preserve the descriptor/configuration rather than reconstructing
ownership from a receipt. Cleanup rechecks liveness before each removal, touches
only exact run-owned resources, and is safe to repeat after successful disposal.
It preserves the original inputs and receipt. Emergency disposal cannot turn a
failed domain verdict into a pass. Private `.env` and bounded raw capture files
are retained for local diagnosis; do not publish them.

The CLI reports `passed`, `failed`, `incomplete` or `blocked`. Every unsuccessful
outcome exits nonzero. `RUNNING` identifies a started stage rather than a percentage
or completed claim. Child output is capped at 4 MiB, builds at 900 seconds, service
readiness at 120 seconds and each lifecycle wait at 90 seconds. Individual cleanup
commands are also bounded. Diagnostics use safe stage/reason/dependency codes.
For machine output add `--json` after the operation; well-formed invocations emit
one labeled JSON result. Argument errors use normal argparse usage and nonzero exit.

The public Doctor currently compares the host's versioned migration ledger with
legacy package migration files and can falsely report pending/unresolved migrations
for this supported setup. This issue remains open. Twin acceptance uses direct
schema/catalog, effective-version and real image/storage probes and claims no
Doctor pass.

## Maintainer regression

```sh
mix test test/install_smoke/twin_*_test.exs --seed 0
```

These fast checks run in existing test lanes and never start Docker. They include
ordinary committed PostgreSQL counter controls, contamination/receipt mutations,
privacy canaries and safe-cleanup controls. The explicit real run and a separate
verifier remain required acceptance. No new recurring heavy CI lane, required
context or release coupling is introduced.
