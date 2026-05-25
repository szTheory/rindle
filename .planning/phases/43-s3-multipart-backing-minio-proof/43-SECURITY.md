---
phase: 43
slug: s3-multipart-backing-minio-proof
status: verified
threats_open: 0
asvs_level: 2
created: 2026-05-23
---

# Phase 43 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.
> S3 multipart tus backing (server-mediated PATCH streaming) proven against MinIO.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| tus HTTP edge (`TusPlug`) | Untrusted client ↔ BEAM. HMAC-signed tus URL is the only handle; token is the final path segment, verified on every HEAD/PATCH/DELETE. | PATCH body bytes, `Upload-Offset`, `Upload-Length` (in signed token), opaque `Upload-Metadata` |
| Storage adapter boundary (`Rindle.Storage` behaviour) | BEAM ↔ S3-compatible object store via ExAws. Polymorphic dispatch; no `if adapter == Local` branch. | object bytes (streamed), multipart `UploadId`, server-issued ETags, `aws_config` (never logged/returned) |
| Node-local disk (tus tail/part buffer) | Per-node `Rindle.tmp/tus/` holds the sub-5-MiB tail remainder; authoritative offset/upload_id/parts live in shared DB. Single-node / sticky-session contract; cross-node misroute fails loudly. | sub-5-MiB tail bytes keyed on server-issued session UUID |
| Reaper / sweeper (`UploadMaintenance`, `SweepOrphanedTempFiles`) | Background ↔ S3 + DB + disk. Aborts orphaned multiparts (cost leak) and ages out tail/part files. | multipart abort calls, FSM-gated state transitions, file deletions confined to `<root>/tus/` |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation / Evidence | Status |
|-----------|----------|-----------|-------------|-----------------------|--------|
| T-43-01 | InfoDisc/DoS-cost | tus callback contract gating | mitigate | `storage.ex:370-375` `@optional_callbacks upload_part_stream:5, complete_part_stream:4`; `:tus_upload` in `t:capability/0` `storage.ex:25`. S3 advertises `s3.ex:239`, Local advertises `local.ex:130`; GCS correctly omits `gcs.ex:141`. Init gate raises if unadvertised `tus_plug.ex:100-108`. | CLOSED |
| T-43-03 | DoS (memory) | tail buffer streaming | mitigate | Tail spilled to disk via `append_to_tail/2` `s3.ex:332-349` (temp_file→tail in `@tail_copy_chunk` 1 MiB chunks, never a binary); 5 MiB slice cap `@s3_min_part_size` `s3.ex:35`; `read_leading_part/1` reads exactly one slice `s3.ex:407-423`; `truncate_tail_head/2` streams leftover `s3.ex:429-466`. | CLOSED |
| T-43-04 | Tampering | ETag/part assembly | mitigate | ETag read from S3 response **headers** `etag_from_headers/1` `s3.ex:481-487`; 1-based strictly-increasing `part_number` `next_part_number/1` `s3.ex:491-493`, incremented in `drain_tail_parts/7` `s3.ex:368`; `complete_multipart_upload` with ordered parts `s3.ex:204`. | CLOSED |
| T-43-05 | InfoDisc | aws_config / S3 creds | mitigate | `aws_config` resolved via opts only `request/2` `s3.ex:535-539`, `s3_config/1` `s3.ex:549-551`; ZERO `Logger` calls in `s3.ex`; no creds in any return map (returns key/bucket/upload_id/response/body only). | CLOSED |
| T-43-06 | Tampering | tail-buffer path traversal | mitigate | `tail_path/2` keys on server-issued `:session_id` under `Rindle.tmp/tus/` `s3.ex:499-503`; single base64url encode site `tail_filename/1` `s3.ex:505-507`. | CLOSED |
| T-43-cost-leak | InfoDisc/DoS-cost (HIGH, blocking) | orphaned S3 multipart | mitigate | `expire_session/2` branches `tus_session?` FIRST (before resumable check) `upload_maintenance.ex:425-435`; `expire_tus_session/2`→`abort_tus_backing/2` aborts via `adapter.abort_multipart_upload/3`, idempotent on `{:error,:not_found}` `upload_maintenance.ex:624-633`. End-to-end `list_multipart_uploads`-empty assertion `tus_s3_integration_test.exs:213-217`. | CLOSED |
| T-43-07 | DoS | reaper crash isolation | mitigate | `expire_tus_session/2` returns `acc` on error + increments `:abort_errors`, leaves row `upload_maintenance.ex:485-503`; test `treats a tus multipart abort returning not_found as idempotent expiry` + per-session reduce never aborted `upload_maintenance_test.exs:449,710-721`. | CLOSED |
| T-43-08 | Tampering/Elevation | completion verify lane | mitigate | `broker.ex` `verify_completion/2` remains `c:head/2`-based single trust gate `broker.ex:470-489`; tus completion converges into it `complete_upload/3` `tus_plug.ex:373-390`. SUMMARY 05 confirms `broker.ex` byte-for-byte unchanged (D-08). | CLOSED |
| T-43-09 | DoS (memory) | PATCH drain to disk | mitigate | `drain/6`+`write_chunk/7` with `@read_length` 1 MiB `tus_plug.ex:90,297-330`; per-PATCH ceiling `> ceiling → :too_large` and `Upload-Length` bound → 413 `tus_plug.ex:319-325`; streamed to per-PATCH temp file `stream_append/4` `tus_plug.ex:240-264`. Tests: 413 over Tus-Max-Size `tus_plug_test.exs:236`, 413 over Upload-Length `tus_plug_test.exs:396`. | CLOSED |
| T-43-10 | InfoDisc | bucket/aws_config through Plug | mitigate | `call_opts/2` threads only `session_id`+`root`, no creds `tus_plug.ex:401-403`; S3 adapter resolves bucket via app-env fallback `bucket/1` `s3.ex:528-533`. Dispatch path tested via Mox `tus_plug_test.exs:629-641`. | CLOSED |
| T-43-11 | Tampering | per-PATCH temp path traversal | mitigate | temp `<dir>/<session.id>.patch` keyed on server-issued `session.id` `stream_append/4` `tus_plug.ex:241`; tail/part paths likewise UUID-keyed (`s3.ex:499-503`, `local.ex:167-169`). | CLOSED |
| T-43-12 | DoS (memory, test-side) | 1 GiB synthetic stream | mitigate | `synthetic_bytes/1` lazy `Stream.cycle/take` generator, never one binary `tus_s3_integration_test.exs:137-146`; 1 GiB upload split into ~600 MiB first PATCH + remainder, full size never materialized. | CLOSED |
| T-43-06-01 | Tampering | cross-node resume guard | mitigate | `guard_local_tail_present/3` returns `{:error,:tus_tail_missing}` when mid-multipart but tail absent `s3.ex:312-327`; called first in `upload_part_stream/5` `s3.ex:164`. Test `mid-multipart resume with no local tail` `s3_tus_test.exs:182-203`. | CLOSED |
| T-43-06-02 | InfoDisc | `:tus_tail_missing` error term | mitigate | Bare atom only `s3.ex:323`; tests assert exact `{:error, :tus_tail_missing}` term (no path/session_uri rides) `s3_tus_test.exs:202,251`. | CLOSED |
| T-43-07-01 | DoS | tus/*.tail / *.part accumulation | mitigate | `sweep_tus_dir/4`+`age_tus_file/4` per-file mtime aging under `tus/` `sweep_orphaned_temp_files.ex:122-153`. Tests: aged `.tail` removed, fresh preserved, `.part` aged `sweep_orphaned_temp_files_test.exs:174-203`. | CLOSED |
| T-43-07-02 | Tampering | sweeper deletion blast radius | mitigate | Deletes ONLY `type: :regular` under `<root>/tus/` (gated `Path.basename == "tus"`) `sweep_orphaned_temp_files.ex:97,138-153`; non-regular left untouched `:147-149`. Containment test `confines deletion to <root>/tus/` `sweep_orphaned_temp_files_test.exs:213-234`. | CLOSED |
| T-43-08-01 | InfoDisc (cost leak) | reaper tail/part cleanup root | mitigate | `abort_tus_backing/1` threads `root` so delete uses SAME root as write path (CR-02/IN-03) `upload_maintenance.ex:572-594,617-642`; `remove_tus_tail/2` delegates to `S3.tus_tail_path/2` canonical helper `upload_maintenance.ex:653-658`. Tests `upload_maintenance_test.exs:800-851,995-1024`. | CLOSED |
| T-43-08-02 | Tampering | FSM invariant on tus expiry | mitigate | `gated_expire/2` routes through `UploadSessionFSM.transition/3` (WR-01) `upload_maintenance.ex:454-468`; tus timeout-expiry settles via `gated_expire` `upload_maintenance.ex:532-537`. Test `gates tus expiry through the FSM and refuses an FSM-forbidden transition` `upload_maintenance_test.exs:864-887`. | CLOSED |
| T-43-09-01 | InfoDisc (cost leak) | DELETE backing abort | mitigate | `handle_delete/2` calls `abort_delete_backing/2` BEFORE the state transition (CR-01) `tus_plug.ex:412-444,459-477`; abort fires even when row update fails. Tests `tus_plug_test.exs:481-499` (success) + `:502-528` (abort fired despite update failure). | CLOSED |
| T-43-09-02 | Spoofing/auth bypass | DELETE token verification | mitigate | Abort runs only after `verify_token`+`load_active_session` succeed `tus_plug.ex:413-424`. Test `a tampered token returns 404 and NEVER invokes abort_multipart_upload` (no Mox expect → would raise) `tus_plug_test.exs:530-540`. | CLOSED |
| T-43-09-03 | Repudiation/false success | DELETE update result | mitigate | Failed `repo().update()` → `tus_error(conn, 500, "")`, never 204 (WR-02) `tus_plug.ex:431-440`. Test `DELETE returns 5xx (not 204) when the state update fails` `tus_plug_test.exs:502-528`. | CLOSED |
| T-43-09-04 | InfoDisc | DELETE / cross-node error surface | mitigate | `status_for/1` maps to bare tus status codes only `tus_plug.ex:553-560`; `tus_error/3` sends status + empty/short body, no session_uri/path `tus_plug.ex:562-567`. | CLOSED |
| T-43-10-01 | InfoDisc (cost leak) | DELETE-path multipart leak | mitigate | `list_multipart_uploads` empty after DELETE through real `TusPlug.call` `tus_s3_integration_test.exs:230-268`. | CLOSED |
| T-43-10-02 | DoS | residual tail-file accumulation | mitigate | Post-reap tail-gone case at resolved write-path root via `S3.tus_tail_path/2` `tus_s3_integration_test.exs:280-322`. | CLOSED |
| T-43-11-01 | DoS (cost exhaustion) | DELETE-time abort failure → orphan | mitigate | Plug persists `tus_abort_failed:<reason>` marker `abort_delete_backing/2` `tus_plug.ex:459-490`; reaper `fetch_retryable_tus_abort_sessions/0` re-selects `upload_maintenance.ex:186-205`, re-aborts `upload_maintenance.ex:485-503`. Tests `tus_plug_test.exs:551-568` + `upload_maintenance_test.exs:1038-1067,1092-1114`. | CLOSED |
| T-43-11-02 | DoS (silent infinite retry) | aborted-tus row routing | mitigate | `settle_tus_abort_success/2` settles recovered `aborted` row via dedicated persist WITHOUT FSM gate (WR-03), avoiding forbidden `aborted→expired` `upload_maintenance.ex:516-566`. Test asserts `abort_errors == 0` on settle (no invalid transition) `upload_maintenance_test.exs:1038-1067`. | CLOSED |
| T-43-11-04 | InfoDisc | failure_reason marker surface | mitigate | `tus_abort_marker/1` bounded `tus_abort_failed:<short_reason>`, atom-only verbatim else `transport`, sliced to 64 chars, no path/session_uri `tus_plug.ex:484-490`. | CLOSED |
| T-43-12-01 | Tampering (integrity) | pre-first-part guard window | mitigate | `guard_local_tail_present/3` requires tail when `offset > committed_part_bytes (= length(parts)*@s3_min_part_size)` (CR-04) `s3.ex:312-327`. Test `pre-first-part resume ... fails loudly` `s3_tus_test.exs:226-252`. | CLOSED |
| T-43-12-02 | InfoDisc | `:tus_tail_missing` error surface | mitigate | Bare atom only `s3.ex:323`; exact-term assertions `s3_tus_test.exs:202,251`. | CLOSED |
| T-43-12-03 | DoS (false positive) | strengthened guard over-firing | mitigate | Guard false for offset 0 first PATCH (`0 > 0` false) and when tail present (same-node) `s3.ex:318-326`. Tests `first PATCH ... no false positive` `s3_tus_test.exs:205-224` + `pre-first-part resume with the local tail present still succeeds` `s3_tus_test.exs:254-281`. | CLOSED |
| T-43-02 | Tampering | part identity typing | accept | See Accepted Risks Log. | CLOSED |
| T-43-06-03 | Tampering | `tus_tail_path/2` traversal-proof | accept | See Accepted Risks Log. | CLOSED |
| T-43-07-03 | Tampering | mtime-based aging window | accept | See Accepted Risks Log. | CLOSED |
| T-43-08-03 | Tampering | `abort_tus_backing/2` path safety | accept | See Accepted Risks Log. | CLOSED |
| T-43-10-03 | Tampering | MinIO test creds surface | accept | See Accepted Risks Log. | CLOSED |
| T-43-11-03 | Repudiation/false success | DELETE 204-on-success by design | accept | See Accepted Risks Log. | CLOSED |
| T-43-SC | Tampering (supply chain) | package legitimacy | n/a | Phase installs NO packages (RESEARCH §Package Legitimacy Audit: N/A). SUMMARY 02 confirms `mix deps.get` was a lockfile fetch only, no `mix.exs`/version change. No install task; checkpoint not applicable. | CLOSED |

*Status: open · closed*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party) · n/a (not applicable)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-43-02 | T-43-02 | `@type tus_part_state` fixes `part_number` as `pos_integer()` and ETag as server-sourced `String.t()` (`storage.ex:113-118`); no client-supplied part identity exists. Accept-by-design. | gsd-security-auditor | 2026-05-23 |
| AR-43-06-03 | T-43-06-03 | `tus_tail_path/2` id is the server-issued session UUID, base64url-encoded under the fixed `Rindle.tmp/tus/` prefix (`s3.ex:499-507`) — structurally traversal-proof; the public helper does not widen surface (it reuses the single encode site). | gsd-security-auditor | 2026-05-23 |
| AR-43-07-03 | T-43-07-03 | mtime-based aging deletes a file only when its OWN mtime is past the operator-configured threshold (default 4h / `@default_threshold_sec 14_400`, `sweep_orphaned_temp_files.ex:30,136-143`); in-flight tails stay fresh within an upload window. Accept. | gsd-security-auditor | 2026-05-23 |
| AR-43-08-03 | T-43-08-03 | `abort_tus_backing/2` uses server-issued `session.id` (UUID) and a root resolved from profile config, not request input (`upload_maintenance.ex:617-642`, `653-658`). Paths stay traversal-proof. Accept. | gsd-security-auditor | 2026-05-23 |
| AR-43-10-03 | T-43-10-03 | MinIO test harness reads `RINDLE_MINIO_*` env (existing convention) — no new secret surface; `@tag :minio` keeps these out of the default suite. Accept. | gsd-security-auditor | 2026-05-23 |
| AR-43-11-03 | T-43-11-03 | DELETE returns 204 on a successful row UPDATE by design; a transient backend abort failure is recorded as a retryable `tus_abort_failed:%` marker and compensated by the reaper, not surfaced to the client (`tus_plug.ex:425-440,459-490`). WR-02 (failed DB UPDATE → 5xx) remains in force (`tus_plug.ex:438-440`). Accept (mitigated by compensation). | gsd-security-auditor | 2026-05-23 |

*Accepted risks do not resurface in future audit runs.*

---

## Unregistered Flags

None. All 12 SUMMARY files declare no new threat surface beyond the plan's
`<threat_model>` (43-03 "No new security-relevant surface introduced", 43-06 /
43-07 "No new threat surface introduced beyond the plan's threat register",
43-11 "No threat flags", 43-12 explicit T-43-12-0x coverage). No new endpoints,
schema/migration changes, or trust boundaries appeared during implementation
(`broker.ex` byte-for-byte unchanged, D-08).

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-05-23 | 37 | 37 | 0 | gsd-security-auditor |

*37 = 30 mitigate + 6 accept + 1 n/a. T-43-cost-leak de-duplicated (plans 03/05); T-43-SC de-duplicated (plans 01-05).*

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer / n/a)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-05-23
