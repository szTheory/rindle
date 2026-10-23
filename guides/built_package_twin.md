# Built-package twin

The twin produces **maintainer-operated synthetic evidence** with
`independent_pilot_credit: false`. The default run checks six lifecycle recovery
cases against one freshly built Hex archive. Each case has its own runtime,
database and bucket. A focused case is diagnostic evidence; full-matrix acceptance
requires all six cases and a separate verifier process.

Use the supported Elixir 1.17.3 / OTP 27.3.4.15 build cell, Python 3, and a running
Docker engine with Compose. The consumer image supplies PostgreSQL, MinIO, libvips
and FFmpeg/ffprobe. The provider case uses a local Mux protocol fixture and dummy
credentials. Keep enough Docker disk space for the images and disposable data;
the runner never prunes shared resources. Cold image builds need network access.

```sh
export ASDF_ERLANG_VERSION=27.3.4.15
export ASDF_ELIXIR_VERSION=1.17.3-otp-27
export ASDF_NODEJS_VERSION=20.18.1
python3 scripts/maintainer/built_package_twin.py check
python3 scripts/maintainer/built_package_twin.py run \
  --evidence-dir /absolute/new-or-empty/evidence
python3 scripts/maintainer/built_package_twin.py verify \
  --inputs /absolute/new-or-empty/evidence/inputs.json \
  --receipt /absolute/new-or-empty/evidence/receipt.json
python3 scripts/maintainer/built_package_twin.py cleanup \
  --descriptor /absolute/new-or-empty/evidence/resources.json
```

Choose a new or empty evidence directory; existing evidence is refused. `run`
prints the retained input, receipt and resource descriptor paths. Evidence
directories are private (0700), and files are created exclusively. `run --cleanup`
also disposes owned infrastructure after freezing the observed verdict. `--verify`
requests semantic verification during a run; a full run always verifies the full
matrix. Keep the separate `verify` invocation above for acceptance.

The runner hashes the actual archive bytes, safely extracts the package and
compiles each external consumer from that same archive. Checkout, home and socket
mounts, private calls, local BEAM output and repository fallbacks are refused. Each
host owns its Repo, default Oban instance and migrations. The root library lock
and user `.tool-versions` stay unchanged.

## Cases and focused reproduction

| Case | Required observation |
|------|----------------------|
| `tus-resume` | One HTTP client stops after a nonfinal PATCH; another resumes the same upload. A wrong offset is rejected, and final bytes and the image variant match. |
| `purge-absence` | A persisted purge retry encounters an independently removed original object and completes the same job without repeating the initiating action. |
| `av-repair` | A real AV processing job exhausts five ordinary attempts under a bounded input fault. Supported requeue repairs the selected variant, and the output fully decodes. |
| `provider-events` | Actual signed webhook ingress and queued processing handle replay and older events without regressing accepted provider state or repeating effects. |
| `promotion-restart` | The host is killed with promotion still pending. A fresh runtime completes the same persisted job without another upload. |
| `interrupted-cleanup` | Genuine expiry and a real multipart part exercise supported maintenance. A maintenance process dies after remote deletion but before row deletion; two reruns converge. |

Reproduce one case without claiming a complete matrix:

```sh
python3 scripts/maintainer/built_package_twin.py run \
  --case av-repair --evidence-dir /absolute/new-or-empty/av-evidence --cleanup
python3 scripts/maintainer/built_package_twin.py verify --case av-repair \
  --inputs /absolute/new-or-empty/av-evidence/inputs.json \
  --receipt /absolute/new-or-empty/av-evidence/receipt.json
```

Use any case ID from the table. Default `verify` rejects a focused receipt, even
when that case passed. The interrupted cleanup case distinguishes two standard
operations: `rindle.abort_incomplete_uploads` marks the session expired, then
`rindle.cleanup_orphans` aborts its remote multipart upload. It does not backdate
session rows. Its interruption affects only the owned maintenance process.

The earlier foundation image/purge scenario remains available through explicit
`run --legacy` and `verify --legacy --inputs PATH --receipt PATH`. `--legacy` and
`--case` are mutually exclusive. Legacy evidence keeps its original meaning: a
controlled restart between purge attempts, with AV unexercised. It cannot satisfy
the six-case matrix.

## Verify retained evidence

Retain the complete directory: the root `package.tar`, inputs, receipt and resource
descriptor, together with every case's inputs and receipt. Move or copy them
together. The verifier rehashes the archive and compares package, source, host,
lock, configuration, fixture, contract and toolchain identities against retained
runner inputs. Each case has a distinct run identity and must bind to the common
archive. Omitted, duplicate, unknown, skipped or swapped cases fail verification.

Strict keys, types, limits, job and runtime identities, observation order, effects
and complete inventories are required. A submitted success flag cannot replace
these checks. Failed or incomplete evidence returns nonzero. Semantic verification
cannot authenticate a wholly fabricated trusted input/receipt pair; there is no
signing or witness service.

## Cleanup and failures

The runner stops writers and inventories domain resources **before** infrastructure
disposal. It checks database rows, exact permitted Oban history and fixture rows,
source and derivative objects, provider fixture effects, multipart uploads and
parts, temporary files and owned processes. Each case declares its exact permitted
identities. Unknown, denied, missing, truncated, raced or residual inventory cannot
mean zero. Baseline bucket versioning must be disabled.

For an interrupted or failed run, use its printed descriptor with the `cleanup`
command above. A matrix descriptor binds a finite set of owned case descriptors.
Cleanup checks exact ownership labels, mounts and liveness and refuses running,
paused or unobservable hosts and foreign resource users. Stop the exact run host
and confirm termination before retrying. There is no active-host override, force
removal or shared prune. Preserve the descriptor and configuration rather than
reconstructing ownership from a receipt.

Cleanup rechecks liveness before each removal, is safe to repeat after successful
disposal and preserves original evidence. Emergency disposal cannot turn a failed
domain verdict into a pass. Private `.env` and bounded raw captures remain for
local diagnosis; do not publish them.

The CLI reports `passed`, `failed`, `incomplete` or `blocked`, and every unsuccessful
outcome exits nonzero. `RUNNING` identifies a started stage. Add `--json` after an
operation for one labeled result containing allowlisted status fields and retained
paths. Argument errors use argparse usage and a nonzero exit. Child output is
capped at 4 MiB; builds at 900 seconds, service readiness at 120 seconds, ordinary
lifecycle waits at 90 seconds and AV retry observation at 600 seconds. Cleanup
commands are bounded. Archive bytes and extracted contents have size and member
limits. Diagnostics use fixed stage, reason and dependency codes.

This remains synthetic package-consumer evidence. It grants no independent pilot,
cloud-provider parity, readiness, release or CI-speed credit. The local provider
fixture tests the adapter protocol. Historical matrix receipts retain their original
exclusion of Doctor; exact-head readiness separately exercises the corrected public
Doctor. Matrix acceptance
uses direct schema/catalog, effective-version and real processing/storage probes.
No new recurring heavy CI lane or required context is introduced.

## Maintainer regression

```sh
mix test test/install_smoke/twin_*_test.exs --seed 0
```

These fast checks use existing test lanes and never start Docker. They cover
committed PostgreSQL counters, receipt mutations, privacy canaries, CLI authority
and safe cleanup. A fresh full run and separate retained-evidence verifier remain
required acceptance. Follow [Running](running.html) for the relevant public
surface, quality and full-suite gates.
