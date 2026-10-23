# Phase 138 discussion research and recommendations

**Date:** 2026-10-21
**Purpose:** Decision support for `138-CONTEXT.md`; no implementation or acceptance credit.
**Authority:** Shipped code first, active planning second, historical research/prompts third.
The user approved the full recommendation set and bounded correctness fixes after the
provider stale-event risk was surfaced. Doctor's ledger fix remains with Phase 139.

Four read-only specialists contributed: the GSD assumptions analyzer; protocol/Oban researcher;
AV/provider researcher; evidence/cleanup researcher. The protocol researcher then independently
challenged the combined proposal. All returned terminal results. No research child edited files
or executed the recovery matrix. This was native typed assumptions analysis plus explicitly
assigned research agents, not an isolated GSD executor run.

## Cohesive choices and tradeoffs

| Decision | Alternatives and tradeoffs | Recommendation |
|---|---|---|
| Consumer environment | Reusing checkout tests is cheap but misses packaging and adopter ownership. A new demo/fault platform increases maintenance. | Extend the existing packaged Phoenix twin; same fresh archive identity, separate case state, ordinary Repo/default Oban. |
| Tus cut | Mid-request disconnect adds transport ambiguity and a proxy/fault seam. Recreating a client after an acknowledged partial upload gives a deterministic persisted checkpoint. | New client process, same host/node, fresh HEAD offset, finish once; exact checksum and inventory. State the limited cut explicitly. |
| Object cardinality | Forcing one bucket key conflicts with configured variants and current ready aggregation. Broad object counts can hide extras. | Exactly one original plus named configured derivatives, no undeclared keys. |
| Delete retry/absence | Retry against a still-present key omits absence. Synthesizing not-found does not prove MinIO behaviour. | Real delete-once error and same-job retry; independently delete/observe absent key before the next scheduled attempt. |
| AV fault | Stubbed processor skips FFmpeg. Deleting binaries tests installation. Overwriting the stored source alters the original and needs separate restoration. | Fixed storage wrapper delegates download then corrupts only selected worker temp input; retain valid original, execute real processor failure, restore delegation and use public repair. |
| AV retry budget | Manual terminal-state edits or accelerated backoff save time but invalidate production-faithful retry evidence. | Wait for ordinary five-attempt discard, public failed-work diagnostics, a new supported repair enqueue, probe and full decode. |
| Provider fixture | Replacement provider behaviour is simpler but omits the shipped Mux client path. Cloud calls add spend, credentials and nondeterminism. | Existing Mux adapter/SDK against local HTTP via supported base_url, signed raw ingress and ordinary jobs; local protocol proof only. |
| Provider adversarial scope | Only pending duplicates/late-created events favour the existing implementation. A universal event ledger expands schema and scope. | Test pending and completed duplicates plus stale-created/stale-errored after newer-ready; repair confirmed defects within existing API/schema. |
| Restart cut | Graceful stop is narrower than abrupt death. Executing-job kill requires a different orphan-rescue/duplicate-effects contract. | Pause/quiesce before promotion claim, observe durable attempt-zero job, SIGKILL host and resume same work without new stimulus. |
| Cleanup interruption | Failure before a side effect is weak; deleting volumes hides application leaks. | Observe real storage deletion before janitor row deletion, kill maintenance process, rerun on live resources, then audit before infrastructure disposal. |
| Receipt design | Generic DSL can accept self-defined predicates. Separate envelopes drift. | Common strict envelope with finite source-selected scenario payloads/predicates; all six required. |
| DX and dependencies | New tools/frameworks increase setup and security burden. Extra GUI work serves no scoped job. | Existing CLI/std-library/locked dependencies, narrow fixtures, clear partial/failure output and reproducible commands. |

## Concrete observations and remaining research obligations

### Tus and storage

`lib/rindle/upload/tus_plug.ex` documents authoritative HEAD and the S3 node-local tail.
`lib/rindle/storage/s3.ex` retains sub-part bytes locally while shared bookkeeping is durable.
The generated-consumer helper already recreates clients after a committed chunk, but its
Sandbox/inline semantics cannot prove normal Oban execution. Copy only the narrow client setup.

The [tus 1.0 specification](https://tus.io/protocols/resumable-upload) defines the resume
offset contract and mismatch rejection. [AWS multipart overview](https://docs.aws.amazon.com/AmazonS3/latest/userguide/mpuoverview.html)
explains why a completed object HEAD is not an oracle for an unfinished upload. Test one
session/source identity, fresh server offset, final bytes and declared derivatives; no
mid-request transport-cut or cross-node claim.

`test/twin/host/lib/twin/storage.ex` already commits the exact-source delete fault once.
`lib/rindle/workers/purge_storage.ex` preserves DB handles until deletes succeed and permits
not-found/enoent success. [S3 DeleteObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_DeleteObject.html)
does not justify claiming a missing unversioned key returned 404. Establish absence through
an independent, authorised oracle; [HeadObject permissions](https://docs.aws.amazon.com/AmazonS3/latest/API/API_HeadObject.html)
make 403 ambiguous. Keep baseline bucket versioning disabled.

### Oban and restart

The lock pins Oban 2.21.1. Its [public API](https://oban.hexdocs.pm/2.21.1/Oban.html)
provides pause/check/resume; pause alone does not terminate executing work. The
[Basic engine](https://raw.githubusercontent.com/oban-bg/oban/v2.21.1/lib/oban/engines/basic.ex)
claims available jobs and persists attempts. Require no running work and reread the selected
job after pausing, then observe actual process death and a distinct boot identity.

`lib/rindle/upload/broker/completion.ex` supplies the durable completion/promotion enqueue
cut. Keep controller, DB, MinIO and retained resources alive while replacing only the host.
No Lifeline/executing-job-rescue claim is necessary for this cut.

Source checking corrected an early retry estimate: the pinned [worker source](https://raw.githubusercontent.com/oban-bg/oban/v2.21.1/lib/oban/worker.ex)
uses `15 + 2^attempt` with increasing jitter. Four delays have a 90-second base;
[jitter implementation](https://raw.githubusercontent.com/oban-bg/oban/v2.21.1/lib/oban/backoff.ex)
and actual execution/scheduling add margin. This is planning information, not a runtime SLA
or permission to make acceptance depend on a tight 110-second wall-clock guess.

### AV and public repair

`lib/rindle/workers/process_variant.ex` sets five attempts and routes video work to
`rindle_media`, distinct from promotion/image work. The fixture in
`test/rindle/processor/av_test.exs` demonstrates small valid video+audio generation.
The wrapper fault must be active only after promotion and only for the exact worker input.
This proves bad-input processing recovery, not an observed MinIO corruption incident.

`Rindle.runtime_status/1` classifies failed variants through
`lib/rindle/ops/runtime_status/collector.ex`; independently inspect the discarded Oban row,
because the diagnostic classification alone does not prove exhausted attempts.
`Rindle.requeue_variants/2` delegates to `lib/rindle/ops/lifecycle_repair.ex`; an active
unique job may return a skipped enqueue, which cannot count as a new repair.

The [ffprobe documentation](https://ffmpeg.org/ffprobe.html) supports structured stream/container
observations; [FFmpeg](https://ffmpeg.org/ffmpeg.html) documents full decoding and `-xerror`.
Probe and decode the downloaded derivative, not merely a local intermediate or installed binary.
Record consumer binary versions rather than inferring them from CI installer pins.

### Provider ordering and duplicate effects

`lib/rindle/streaming/provider/mux/http.ex` accepts `base_url`; host/root locks already
contain Mux 3.2.2. Declare it as an existing optional host dependency only if activation is
needed. The local fixture should preserve durable request/resource facts across host restart
and avoid logging dummy credential canaries; actual external egress must not be needed.

[Mux signature guidance](https://www.mux.com/docs/core/verify-webhook-signatures) requires
raw-body verification. [Mux delivery guidance](https://www.mux.com/docs/core/listen-for-webhooks)
describes retries and duplicate delivery, including duplicates after success. Its
[direct-upload guide](https://www.mux.com/docs/guides/upload-files-directly) discusses event
ordering. These support adverse duplicate/order tests; they do not establish Rindle correctness.

Local review finds that `ingest_provider_webhook.ex` writes event time without comparing
the watermark; `provider_asset_fsm.ex` permits ready-to-errored. A newer-ready then older-error
sequence can therefore regress state. Prove this with a behavioural regression before fixing.
Completed jobs are excluded from webhook uniqueness, so late duplicates can legitimately
enqueue another handler. Judge converged rows, outbound creation and observable lifecycle
effects, not an invented one-job/exactly-once guarantee. Test fresh newer errors too: preventing
stale regression must not make ready assets permanently immune to legitimate state changes.

Timestamp precision/ties, absent timestamps, concurrent updates and current telemetry semantics
need implementation research. The approved scope is a cohesive existing-owner correction,
not a new ledger, schema or broad public event-processing contract.

### Cleanup and independent inventories

`mix rindle.abort_incomplete_uploads` transitions genuinely timed-out sessions; then
`mix rindle.cleanup_orphans --no-dry-run` removes expired sessions and their staged storage.
`lib/rindle/ops/upload_maintenance.ex` performs external deletion before deleting the row,
providing a meaningful partial-effect cut through a fixed host-owned wrapper. Public expiry
options avoid fabricated backdated rows. Plan task-runtime supervision explicitly so a new
maintenance process does not collide with a live Endpoint or introduce competing consumers.

The abort lane also owns multipart cancellation. Include actual multipart/part state and its
removal, not just an empty final list. The upload janitor is not the cleanup owner for provider
assets or every temp path; all resource classes still need explicit ownership and inventory.
[AWS multipart listing](https://docs.aws.amazon.com/AmazonS3/latest/API/API_ListMultipartUploads.html)
and [abort semantics](https://docs.aws.amazon.com/AmazonS3/latest/API/API_AbortMultipartUpload.html)
require distinguishing uploads/parts from completed objects, stopping writers and handling
complete observations. [Object listing](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ListingKeysUsingAPIs.html)
must not silently truncate at a page boundary.

[Docker volume lifecycle](https://docs.docker.com/engine/storage/volumes/) and
[Compose down](https://docs.docker.com/reference/cli/docker/compose/down/) distinguish
persistent data from environment deletion. Validate exact names/labels/mounts/users, refuse
foreign/unknown ownership and recheck before removal. Volume deletion proves disposal,
never application convergence. Preserve original failed receipts even if emergency disposal
is necessary.

## Required negative controls and honest limits

- Wrong tus offset/foreign session cannot advance; new client must read HEAD rather than
  supply its remembered offset as evidence. Same-node constraint stays explicit.
- Retry must preserve the same job/asset and a real initial error; independent absent-key
  observation must distinguish permission errors. No forced retry or repeated stimulus.
- AV cannot pass from binary presence, fake processor errors, image output, skipped repair,
  active retry, local-only output or a discarded row without diagnostic failure.
- Provider tests include stale error, post-completion duplicate, fresh legitimate transitions,
  concurrency and secret canaries. No green claim from merely cancelling every difficult event.
- Restart cannot pass without actual old-runtime death, same persisted job and new identity.
- Cleanup cannot pass from dry-run, pre-effect failure, dropped volumes or unsupported
  assumption that one task owns all resources. Foreign-resource decoys must survive.
- Matrix verifier rejects omitted/skipped/duplicate/unknown cases, mixed archive/case inputs,
  count-preserving substituted identities, unknown inventory and contradictory observations.
- Trusted-runner semantic verification does not authenticate wholly fabricated trusted inputs.
  No signing/witness system is proposed. Every receipt remains explicitly synthetic evidence.

## Methodology and stopping point

Adopter-first and least-surprise lenses favour supported public recovery paths. Security/SRE
lenses require bounded secrets, durable observations and complete ownership. Testing/evidence
lenses require negative controls and separate verification. Maintainability/performance lenses
favour six finite families, existing dependencies, no extra GUI and no new heavy CI lane until
measured. Current `brandbook/` supersedes the old prompt brand seed; its calm, precise voice
applies to CLI messages, while graphical motifs/dark-mode UI are irrelevant to this headless scope.

The independent final pass produced no need for another framework, provider or chaos dimension.
Remaining details are ordinary implementation research/plan obligations. Target at most six
plans and three tasks per plan; stop repeated recovery cascades by rescoping. Doctor's ledger
defect, broad readiness, independent adoption and deferred CI-speed acceptance remain separate.
