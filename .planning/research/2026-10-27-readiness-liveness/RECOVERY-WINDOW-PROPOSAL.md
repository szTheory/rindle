# Proposed genuine scheduled recovery window — approval required

Status: prepared only. Do not merge this proposal without explicit approval to
change production cadence. The prior approved139-07 amendment kept it unchanged.

## Concrete change

Preserve daily07:27UTC and add `27 11 27 10 *` in the existing Nightly workflow.
The intended occurrence is2026-10-27 11:27UTC (07:27 America/New_York). GitHub cron
has no year field: this entry is annual until removed, not intrinsically one-shot.
The finite Nightly verifier hash is reviewed and updated for these exact bytes.
No new workflow, job, permission, secret, dependency or external scheduler.
All scheduled jobs, strict verdict and authenticated incident replay run normally.

## Execution and automatic acceptance

1. Deliver the strict artifact-inventory acquisition repair first through full
   ordinary protected PR/main CI. Never reset or relabel prior failed evidence.
2. After explicit cadence approval, merge this proposal through full ordinary
   protected PR/main CI before the target slot. If that slot has passed, do not
   activate a stale annual entry; propose a newly reviewed future slot instead.
3. Capture/admit the final merged source after all control changes. Obtain its
   actual on-demand Nightly qualification using the single dispatch owner.
4. Observe a new actual `schedule` attempt1 on default main. Do not merge our own
   follow-up metadata during its lifecycle; its current-main high-watermark guard
   stays strict. A delayed/dropped/failed run remains ineligible. Manual dispatch,
   the old schedule rerun, human acknowledgment and fixture success grant no
   operational health or READY credit.
5. Verify complete jobs, verdict/checkpoint artifact bytes, matching transitive
   control identity, current incident journal and unchanged finite freshness.
   Then run one newly owned durable139-07 acceptance. Only its actual verified
   terminal ready result may grant qualified historical READY-01–05 credit.
   PR189 remains unmerged and held throughout unless separately instructed.

## Cleanup

After successful retained historical acceptance, remove exactly the extra cron
and its temporary comments through a new ordinary protected PR, restore the
finite verifier hash for the resulting workflow bytes, and rerun relevant
fixtures/full CI. If recovery fails or is abandoned, prepare the same removal
without claiming acceptance. Do not leave an annual recovery job dormant.
Cleanup changes control identity again: the retained old snapshot remains
historical; it does not establish current readiness after removal. A later new
acceptance needs its own genuine compatible health proof. Record the actual run,
subject, interval, durable locator and cleanup PR in the inline139-07 cursor.

## Why this scope

Today schedule40468662976 passed compute but failed lifecycle metadata acquisition.
The old run SHA no longer matches current main, so a rerun cannot repair its
high-watermark authentication. Adding one controlled real scheduled opportunity
can recover today without inventing a schedule event or bypassing incident health.
Keep the daily interval as the normal operating cost; do not run the heavy whole
Nightly hourly just to mask acquisition bugs.

Primary source: [GitHub schedule event and cron semantics](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule).
GitHub documents possible queue delay/drop; the proposed time is an opportunity,
not a promise of completion. This proposal does not change the daily freshness
bound, so newest successful compatible actual schedule is still mandatory.
