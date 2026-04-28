# Troubleshooting

This guide covers the FSM error states and the common error tuples Rindle
returns. The pattern is the same across the lifecycle: every "stuck" or
"degraded" outcome has a queryable state, an explicit recovery path, and
typically a Mix task that automates the recovery.

For the full state diagrams, see [Core Concepts](core_concepts.html). For
the day-2 task reference, see [Operations](operations.html).

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
   for this because it should be rare and audited. Direct DB update:

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
`available` is **not** allowed by the FSM (you must update the row
directly to recover from a false positive).

## Failed Variants

**State:** `MediaVariant.state == "failed"`

**What it means:** The variant exhausted its retry budget (default 5
attempts on `Rindle.Workers.ProcessVariant`). The Oban job is in the
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

| Cause                          | Action                                                                  |
| ------------------------------ | ----------------------------------------------------------------------- |
| Transient (network, storage)   | `mix rindle.regenerate_variants --variant <name>` re-enqueues          |
| Recipe bug (now fixed)         | Update the profile, then `mix rindle.regenerate_variants`              |
| Corrupt source                 | Fix the source bytes, then re-enqueue (or accept the variant as lost) |
| OOM / resource exhaustion      | Reduce `rindle_process` concurrency or move to a larger node           |

The variant FSM allows `failed → queued`, so re-enqueueing is always a
valid transition. If the underlying issue persists, the variant will
flip back to `failed` after another 5 attempts; investigate further
rather than re-enqueuing in a loop.

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

**Recovery:** `mix rindle.regenerate_variants` walks all stale
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

**Recovery:** `mix rindle.regenerate_variants` re-enqueues missing
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

- `Rindle.Domain.AssetFSM`, `Rindle.Domain.VariantFSM`,
  `Rindle.Domain.UploadSessionFSM` for the transition rules
- `Rindle.Upload.Broker`, `Rindle.Delivery`, `Rindle` (the public
  facade module) for the public API contracts
- The Mix task `@moduledoc` blocks for command-line behavior
- The telemetry contract test (`test/rindle/telemetry/contract_test.exs`)
  for the locked event surface

When in doubt, **the FSM is the source of truth.** If the FSM forbids
a transition, that is by design — work with the FSM (queue → process →
ready, or queue → purge), not around it.
