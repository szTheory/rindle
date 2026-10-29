# Completed acceptance timing receipt — 2026-10-29

The completed evidence localizes the long tail: **25 fresh async-isolation seeds consumed 3h 11m 52.939s**, or **82.29% of the18 native commands' summed elapsed time**. Native setup caching alone cannot materially change that dominant cost. The separate host refresh took **14m 05.118224s**, with serial run/remote collectors consuming96.05% of that interval. These measurements explain this one completed execution; they establish no new READY or CI-16 credit, speed target, percentile, causal saving or billable cost.

Source is the existing immutable output at `/Users/jon/Library/Application Support/Rindle/readiness/accept-v3-48407bac-renewed-20261029`. Subject `48407bac7691c459395760b06f7714bbb6c3545b`, producer `40864930767/1`. The [existing terminal verdict](</Users/jon/Library/Application Support/Rindle/readiness/accept-v3-48407bac-renewed-20261029/terminal-verdict.json>) records `ready`, historical scope and `current_readiness: false`; this research does not rerun or extend that authority. The machine-readable [timing extraction](current-acceptance-timings.json) deliberately sets research requirement credit to false.

## Independent integrity checks

Read existing files only. Recomputed and matched all8 terminal reference hashes and158 distinct object references found in the manifest and its24 proof receipts. Independently matched archive/manifest digests against both sidecar and durable locator, matched the sidecar digest against the locator, and confirmed the refresh manifest is byte-identical to the durable manifest. No missing file or digest mismatch occurred. Terminal SHA256: `3a4a2c03b49474bd6118d65386b223ade7555738731469ce8180defb5da9b9c5`.

The JSON retains the actual computed terminal digest, all8 terminal reference identities and aggregate request-metadata inventory digests. No raw API path, response body, header, credential, command output or cleanup inventory was copied. Hash checking is byte-integrity research; it does not execute the subject's graph validator or create another acceptance.

## Nested elapsed intervals

| Interval | Actual retained timestamps, UTC | Elapsed |
|---|---|---:|
| Outer controller terminal interval | 11:22:36.801043–15:56:53.252718 | **4h 34m 16.451675s** |
| Producer candidate manifest interval | 11:25:40.642311–15:41:32.819768 | **4h 15m 52.177457s** |
| All18 native receipt commands, summed monotonic `duration_ms` | Nested in candidate interval | **3h 53m 09.972s** |
| First native receipt start through last native receipt end | 11:34:13.557739–15:27:33.083503 | **3h 53m 19.525764s** |
| Host refresh envelope interval | 15:42:24.092120–15:56:29.210344 | **14m 05.118224s** |

These rows overlap. Do not add native time to candidate time or refresh time to outer time, and do not label them summed hosted runner-minutes. Candidate time contains preflight/acquisition, native proof, cleanup and other gaps. The outer controller also contains dispatch/polling/retrieval/final checks. No job-start/job-end API fetch was made for this extraction.

Receipt monotonic durations are truncated to integer milliseconds; timestamp subtraction can differ below one millisecond. The JSON preserves both representations. The first-to-last receipt span exceeds the command sum by9.553764s; this is not evidence of another test run.

## Native commands

All18 command receipts completed with exit0. These are actual retained command elapsed times, not estimates or tool budgets.

| Native gate | Elapsed |
|---|---:|
| async-isolation | **3h 11m 52.939s** |
| twin-recovery | 11m 37.699s |
| contributor-bootstrap | 10m 22.665s |
| coverage, ordinary single invocation | 7m 03.057s |
| release-truth | 5m 01.753s |
| dialyzer-fresh | 3m 23.774s |
| docs | 1m 32.322s |
| generated-consumer | 1m 18.946s |
| hygiene | 15.045s |
| contracts | 13.095s |
| dialyzer-restored | 10.430s |
| credo | 6.259s |
| compile | 4.826s |
| doctor | 4.076s |
| security | 1.108s |
| format | 1.092s |
| package | 0.758s |
| inbox-ledger | 0.128s |

The hash-verified async JSONL contains25 iteration records, all exit0 on the subject, plus its schema record. It contains **no per-seed duration fields**. Therefore no seed min/max, slowest seed, median or p95 is available. Dividing total time by25 would be a wrapper-inclusive average, not a measured iteration duration. The retained native gate intentionally runs fresh processes under its existing contract; no seed deletion, batching, async conversion, receipt reuse or timeout change follows from this timing observation.

## Host refresh acquisition

Counts come from existing `*-request.json` recorder metadata, which records every physical attempt under the reviewed acquisition code. Only status/count/time fields were extracted. Collector elapsed times come from each collector's verdict interval, rather than first-to-last response timestamps, which omit the first request's acquisition time.

| Host collector | Physical attempts | Statuses | Collector elapsed |
|---|---:|---|---:|
| runs-before | 163 | 162×200, 1×502 | 1m 52.387552s |
| remote-before | 493 | 493×200 | 5m 13.847725s |
| runs-after | 162 | 162×200 | 1m 30.890638s |
| remote-after | 493 | 493×200 | 4m 54.611939s |
| **Four collectors total** | **1,311** | 1,310×200, 1×502 | **13m 31.737854s** |

The four serial collectors account for96.05% of the14m05.118224s envelope interval. Remote inventories alone cost986 attempts and10m08.459664s; this is measured acquisition work, not proof that its pages or two-observation consistency checks can safely be skipped. The one retained502 appears in a completed collector, consistent with bounded physical-attempt recovery. It is not an unchanged producer retry or a reason to weaken failure handling.

The refresh-level outer recorder contains another103 attempts,78 inside the envelope interval and25 after its declared completion. Thus **1,389 recorded attempts fall within the envelope window**, while **1,414 exist across all five refresh recorders**. The25 later attempts are final checks outside the envelope; do not divide the1,414 total by envelope elapsed time or report all of it as inner collection.

The separate top-level controller recorder contains573 attempts spanning admission/polling/retrieval/final checks across the whole acceptance. It is neither the remote collector's count nor an extra573 refresh attempts. This extraction makes no invoice/API-quota estimate and does not count registry/tool/network activity absent from these recorders.

## Decisive lessons

1. **Treat multi-hour collection as expected when the retained gate is still progressing.** The dominant current measurement is the fresh25-seed gate, not a hung Actions setup step. Surface fixed gate identity and elapsed/exit evidence when needed; keep the original finite budget and failure record.
2. **Profile within the dominant gate before choosing another optimization.** Its proof contract and observed runtime are concrete; per-seed attribution is absent. A future narrowly authorized measurement could add monotonic per-iteration duration without changing argv, process freshness, fixed seeds or verdicts. This report neither implements that measurement nor launches another run.
3. **Keep inner and outer acquisition accounting separate.** Existing host refresh collectors are the useful API-efficiency target, while terminal final checks and long polling have different ownership. Any acquisition optimization must preserve complete inventories, current attempts, signed sources, the paired observations and fail-closed equality. Existing successful counts provide a baseline, not permission to replace checks with cached authority.
4. **Keep main CI scheduling and native acceptance tail work distinct.** The prepared main-matrix overlap changes ordering on ordinary main CI; it does not accelerate this251-minute-scale native proof. Its latency model remains separate from these measured receipts and from billable usage.

No source, control bytes, receipts, terminal verdict, REPORT, requirement state or remote system was modified. Only the two requested research artifacts were written.
