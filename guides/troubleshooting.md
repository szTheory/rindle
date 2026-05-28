# Troubleshooting

This guide covers the FSM error states and the common error tuples Rindle
returns. The pattern is the same across the lifecycle: every "stuck" or
"degraded" outcome has a queryable state, an explicit recovery path, and
typically a Mix task that automates the recovery.

For the full state diagrams, see [Core Concepts](core_concepts.html). For
the day-2 task reference, see [Operations](operations.html).

## Diagnostics Split

Start with the read-only surfaces first:

- `mix rindle.doctor` validates setup and drift.
- `mix rindle.runtime_status` reports degraded or stuck work.
- The repair verbs perform change only after diagnostics identify the right lane.

In short: doctor validates setup and drift, runtime status reports degraded or stuck work, and repair verbs perform change.

The contract intentionally has no dashboard and no auto-remediation layer in
this release.

For upgrade troubleshooting, keep the same order: explicit migrations,
`mix rindle.doctor`, optional `mix rindle.runtime_status`, then the repair verb
that matches the actual state.

If the failing profile uses `Rindle.Storage.GCS`, keep the same order and then
use [Storage (GCS)](storage_gcs.html) for the bucket, CORS, `session_uri`, and
resumable-upload operator runbook instead of rebuilding that flow from logs.

## Supported Recovery Verbs

Five supported recovery verbs cover the common repair lanes:

- `reprobe` — `Rindle.reprobe/1` for probe-derived field drift on one asset
- `requeue` — `Rindle.requeue_variants/2` for failed or cancelled variants on
  one asset
- `regenerate` — `mix rindle.regenerate_variants` for broad `stale` or
  `missing` derivative drift
- `cleanup` — `mix rindle.cleanup_orphans` after
  `mix rindle.abort_incomplete_uploads` for expired upload residue
- `sweep` — `mix rindle.sweep_orphaned_temp_files` for AV temp-run-dir residue

Use the same verb vocabulary here that the operations guide teaches. If one of
these verbs applies, prefer it over direct DB row mutation.

## AV Error Contract

Rindle documents these AV-facing error reasons as a public operator
vocabulary:

- `:processor_capability_missing`
- `:ffmpeg_not_found`
- `:capability_drift`
- `:variant_source_not_found`
- `:unsupported_codec`
- `:streaming_not_configured`
- `:variant_processing_cancelled`
- `:range_unparseable`
- `:tus_session_not_found`
- `:tus_session_expired`
- `:tus_offset_conflict`
- `:tus_size_exceeded`
- `:tus_url_signature_invalid`

The exact user-facing text for those reasons is owned by
`Rindle.Error.message/1`. Treat this guide as the recovery map, not a second wording authority.

| Reason | What it usually means | First operator move |
| ------ | --------------------- | ------------------- |
| `:processor_capability_missing` | The configured processor cannot satisfy a declared AV variant. | Run `mix rindle.doctor` and compare the profile's variants to the processor capability list. |
| `:ffmpeg_not_found` | FFmpeg is missing from PATH or not configured at `:ffmpeg_path`. | Install FFmpeg, then re-run `mix rindle.doctor`. |
| `:capability_drift` | A storage or processor capability disappeared after the profile was already in use. | Re-check runtime configuration, then use the supported `cleanup`, `requeue`, or `regenerate` lane that matches the affected work before retrying. |
| `:variant_source_not_found` | Variant processing could not download the original media from storage. | Confirm the original object still exists and that the adapter can read it. |
| `:unsupported_codec` | The declared codec is not available in the current FFmpeg build or processor allowlist. | Inspect `ffmpeg -codecs` and compare it to the variant recipe. |
| `:streaming_not_configured` | A caller asked for streaming playback without a configured streaming provider. | Fall back to progressive delivery with `Rindle.Delivery.url/3`. |
| `:variant_processing_cancelled` | An in-flight transcode was intentionally cancelled. | Verify whether `Rindle.cancel_processing/1` was invoked, then use `Rindle.requeue_variants/2` if the asset should resume work. |
| `:range_unparseable` | A malformed HTTP `Range` header reached the local streaming surface. | Fix the caller/header generator or enable strict parsing if your app wants hard failures. |
| `:tus_session_not_found` | The client retried a deleted, stale, or never-issued tus URL. | Start a fresh tus upload and ensure the client reuses the exact `Location` URL from the original tus `POST`. |
| `:tus_session_expired` | The tus upload URL or session aged out before resume completed. | Start a new tus upload or increase the upload-session TTL if long pauses are expected. |
| `:tus_offset_conflict` | The client resumed from a stale byte offset. | Re-`HEAD` for the authoritative `Upload-Offset` and let the tus client resume from the server-reported offset. |
| `:tus_size_exceeded` | The client sent more bytes than declared or allowed. | Correct the file size or max-size config and restart the upload with a fresh tus URL. |
| `:tus_url_signature_invalid` | The signed tus `Location` URL was mutated or tampered with. | Treat the tus URL as opaque and restart the upload if the client no longer has the exact original URL. |

The common FFmpeg- and capability-related recovery path is still
`mix rindle.doctor`, because it exercises the same runtime boundary that emits
these reasons.

## Quarantined Assets

**State:** `MediaAsset.state == "quarantined"`

**What it means:** The asset failed an upload-time policy check. Common
triggers:

- MIME mismatch — the magic-byte sniff disagrees with the profile's
  `allow_mime` allowlist (e.g., user uploaded `evil.png.exe` and the
  bytes are an executable, not a PNG)
- Size or pixel limits exceeded
- Scanner verdict (if you've wired a `Rindle.Scanner` adapter)
- Manual quarantine by an operator

**Telemetry / logs:** `Logger.warning("rindle.asset.quarantined", asset_id:
..., detected_mime: ..., reason: ...)` — search your log aggregator for
this string.

**Recovery options:**

1. **Confirm + delete** (most common): The user uploaded something we
   should not host. Run a deletion through `Rindle.delete/3` (which
   transitions to `deleted` and enqueues `PurgeStorage`).
2. **False positive — un-quarantine manually**: There is no public API
   for this because it should be rare and audited. Manual DB update remains
   the exception path here:

   ```elixir
   asset
   |> Ecto.Changeset.change(state: "available")
   |> MyApp.Repo.update!()
   ```

   Document the audit trail (who reversed the quarantine, why, when).
3. **Inspect the storage object**: The original is still in storage at
   `asset.storage_key`. Download it through your storage adapter to
   verify the verdict before any reversal.

The `quarantined` → `deleted` transition is allowed; `quarantined` →
`available` is **not** allowed by the FSM. This is one of the narrow cases
where the supported repair verbs do not apply and a documented manual update
is still required.

## Failed Variants

**State:** `MediaVariant.state == "failed"`

**What it means:** The variant exhausted its retry budget (default 5
attempts on the internal variant-processing worker). The Oban job is in the
`discarded` state; the variant row is in `failed`.

**Diagnosing root cause:**

1. Inspect the Oban job: `MyApp.Repo.get!(Oban.Job, job_id)` — the `errors`
   column has the stack trace from each attempt.
2. Check the variant's recipe: did the spec change recently? A recipe
   bug (e.g., `quality: 200`, which is out of range) will fail every
   attempt the same way.
3. Check the source asset: is the original still in storage? A missing
   original prevents any variant from regenerating.
4. Check libvips / Image: very large images can OOM the BEAM; check
   memory metrics around the failure time.

**Recovery options:**

| Cause | Action |
| ----- | ------ |
| Transient (network, storage) | `Rindle.requeue_variants/2` for the affected asset (`requeue`) |
| Intentional cancellation that should be resumed | `Rindle.requeue_variants/2` for the affected asset (`requeue`) |
| Recipe bug fixed for many assets | Update the profile, then `mix rindle.regenerate_variants` (`regenerate`) |
| Corrupt source repaired for one asset | Fix the source bytes, then `Rindle.requeue_variants/2` (`requeue`) |
| OOM / resource exhaustion | Reduce `rindle_process` concurrency or move to a larger node before retrying with `requeue` or `regenerate` |

The supported split is intentional: `requeue` is asset-scoped repair for
failed/cancelled work, while `regenerate` remains the broad maintenance lane
for `stale`/`missing` drift. If the underlying issue persists, the variant will
flip back to `failed` after another 5 attempts; investigate further rather than
re-enqueuing in a loop.

That same split applies to upgraded adopters: use `Rindle.requeue_variants/2`
for one failed or cancelled upgraded asset, and keep `mix
rindle.regenerate_variants` for broader drift only.

## Stale Variants

**State:** `MediaVariant.state == "stale"`

**What it means:** The variant's stored `recipe_digest` no longer
matches the profile's current digest. You changed the variant spec
(quality, dimensions, format, mode) and existing variants predate
the change.

**Detection:** Stale detection happens on read — when Rindle resolves
a variant URL, it compares the stored digest to the current profile
digest, and if they differ, transitions the variant to `stale`. So
"stale" is observable as soon as you change a profile.

**Recovery:** `mix rindle.regenerate_variants` (`regenerate`) walks all stale
variants and re-enqueues them. Filter by profile or variant name if
you only want to regenerate a subset:

```bash
mix rindle.regenerate_variants --profile Elixir.MyApp.PostImageProfile
mix rindle.regenerate_variants --variant thumb
```

While stale variants are being regenerated, `Rindle.Delivery.variant_url/4`
serves the original asset as a fallback (the default `:stale_mode`
is `:fallback_original`). To serve stale variants during regeneration
instead, pass `stale_mode: :serve_stale` — this is appropriate when
the visual diff between recipes is small and you'd rather show the
old variant than the unsized original.

## Missing Variants

**State:** `MediaVariant.state == "missing"`

**What it means:** `mix rindle.verify_storage` HEAD-checked the
variant's storage object and got `not_found`. The DB still has the
row; the storage object is gone.

**Common causes:**

- Out-of-band deletion (operator using S3 console, CDN purge gone wrong)
- Storage lifecycle policy expired the object
- Multi-region replication gap during failover
- Storage backup restore that pre-dated the variant

**Detection:** Run `mix rindle.verify_storage` periodically. The task
emits a deterministic summary:

```
Rindle: verifying storage for variants...
  checked:      120
  present:      117
  missing:      2
  fsm_blocked:  1
  errors:       0
Done.
```

**Recovery:** `mix rindle.regenerate_variants` (`regenerate`) re-enqueues missing
variants the same way it does stale ones. The processor downloads
the original (which must still be present) and re-derives the
variant.

If the original is **also** missing, the variant cannot be regenerated
— you have data loss. The asset should be quarantined or deleted
depending on your data-recovery posture.

## Expired Upload Sessions

**State:** `MediaUploadSession.state == "expired"`

**What it means:** The session's `expires_at` elapsed before
`Broker.verify_completion/2` was called. The presigned URL is no
longer valid; the upload either never happened or never reached
verification.

**Detection:** `Logger.info("rindle.upload_session.expired",
session_id: ..., reason: %{event: :expired, elapsed_seconds: ...})`.
The transition itself happens in `Rindle.Workers.AbortIncompleteUploads`
(scheduled via Oban cron) or via `mix rindle.abort_incomplete_uploads`.

**Recovery:** Expired sessions are terminal — the FSM does not allow
transitions out of `expired`. The flow is:

1. `mix rindle.abort_incomplete_uploads` flips timed-out `signed`/`uploading`
   sessions to `expired`.
2. `mix rindle.cleanup_orphans` removes `expired` sessions and any
   staged storage objects they reference.

This is the supported `cleanup` lane. Do not remove expired upload-session rows
manually unless the cleanup workflow itself is broken and you have preserved an
audit trail.

## Probe Drift

**Symptom:** An asset's source object is still authoritative, but the stored
probe-derived fields are stale or were persisted before improved detection
landed.

**Recovery:** Use `Rindle.reprobe/1` (`reprobe`) for that asset. This refreshes
probe-owned fields such as MIME, kind, dimensions, duration, and track booleans
without mutating unrelated lifecycle state, variants, or upload sessions.

If the problem is analyzer metadata rather than probe facts, stay on
`mix rindle.backfill_metadata`; `reprobe` is not a metadata backfill surrogate.

## AV Temp Residue

**Symptom:** AV processing left abandoned directories under `Rindle.tmp/`.

**Recovery:** Use `mix rindle.sweep_orphaned_temp_files` (`sweep`). Start in
dry-run, confirm the counts, then opt into live deletion with `--no-dry-run`
or a cron job configured with `"dry_run" => false` if you want destructive
execution.

This is separate from upload-session `cleanup`: temp sweeping targets local
transcoding residue, not staged upload objects or upload-session rows.

If the user wants to retry their upload, they must call
`Broker.initiate_session/2` to start a new session. There is no
"resume" path — by design, because the half-uploaded bytes (if any)
are not trustworthy.

## Common Error Tuples

| Error                                              | Where Returned                                | Meaning + Recovery                                                                |
| -------------------------------------------------- | --------------------------------------------- | --------------------------------------------------------------------------------- |
| `{:error, :not_found}`                             | `Broker.sign_url/2`, `Broker.verify_completion/2` | Session ID does not exist. Surfaces as a 404 in your controller.              |
| `{:error, :storage_object_missing}`                | `Broker.verify_completion/2`                  | The presigned PUT was never made (or hit the wrong URL). User should retry.       |
| `{:error, {:invalid_transition, from, to}}`        | Any FSM transition                            | A worker tried an FSM transition that is not allowlisted. Indicates a bug or a race; check `rindle.*.transition_failed` log entries. |
| `{:error, {:delivery_unsupported, :signed_url}}`   | `Rindle.Delivery.url/3`                       | A private profile is pointed at a storage adapter that does not support signed URLs. Either flip the profile to public, or switch adapters. |
| `{:error, :forbidden}` (or any authorizer error)   | `Rindle.Delivery.url/3`                       | The configured authorizer rejected the request. Check the actor and the subject. |
| `{:error, {:storage_adapter_exception, term}}`     | Storage adapter calls                         | The storage adapter raised. Inspect `term` for the underlying cause (network, auth, malformed config). |

## Diagnostics Cheatsheet

Quick queries you can run to triage state distribution:

```elixir
# Asset state distribution
import Ecto.Query
MyApp.Repo.all(
  from a in Rindle.Domain.MediaAsset,
    group_by: a.state,
    select: {a.state, count(a.id)}
)

# Variants in non-ready state
MyApp.Repo.all(
  from v in Rindle.Domain.MediaVariant,
    where: v.state in ["failed", "stale", "missing"],
    group_by: [v.state, v.name],
    select: {v.state, v.name, count(v.id)}
)

# Upload sessions past their TTL but not yet expired
MyApp.Repo.all(
  from s in Rindle.Domain.MediaUploadSession,
    where: s.state in ["signed", "uploading"] and s.expires_at < ago(0, "second"),
    select: count(s.id)
)
```

These three queries cover most "what's wrong with my media pipeline?"
triage situations. Wire them into a LiveDashboard page or an admin
LiveView for at-a-glance health.

## Getting Help

If you encounter a state or error tuple that is not covered here,
the canonical references are:

- The lifecycle/state tables in the core concepts guide for transition rules
- `Rindle.Upload.Broker`, `Rindle.Delivery`, `Rindle` (the public
  facade module) for the public API contracts
- `Rindle.Error.message/1` for user-facing error text and remediation wording
- The Mix task `@moduledoc` blocks for command-line behavior
- [Background Processing](background_processing.html) for the locked telemetry event surface

When in doubt, **the FSM is the source of truth.** If the FSM forbids
a transition, that is by design — work with the FSM (queue → process →
ready, or queue → purge), not around it.
