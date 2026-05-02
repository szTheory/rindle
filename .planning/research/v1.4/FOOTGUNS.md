# v1.4 Footguns: Adding Video & Audio to Rindle

**Project:** Rindle (Elixir/Phoenix/Ecto media lifecycle library)
**Milestone:** v1.4 (video/audio expansion)
**Researched:** 2026-05-02
**Mode:** Ecosystem + Feasibility (security-and-ops-leaning)
**Overall confidence:** HIGH on security CVE patterns; HIGH on peer-library design; MEDIUM on Elixir-specific subprocess discipline (small ecosystem, validated against multiple sources).

---

## 1. TL;DR — Top 5 Risks Ranked by Likelihood × Blast Radius

| # | Risk | Likelihood | Blast Radius | Locked Mitigation |
|---|------|------------|--------------|-------------------|
| 1 | **FFmpeg argv injection** via user-supplied codec/filter/filename → arbitrary file read/write/RCE on adopter host | HIGH (default-trap; any string interpolation triggers it) | CRITICAL (file disclosure, RCE, full host compromise) | argv array discipline; allowlist codecs/filters/presets; reject any user-controllable string as a CLI flag; never `System.shell/2`, only `System.cmd/3` with arg list |
| 2 | **HLS/DASH playlist SSRF + local file read** via `file:` / `http:` / `concat:` protocols in untrusted manifests (CVE-2016-1897, CVE-2020-13904, multiple HackerOne reports) | HIGH (default-trap on any HLS support) | CRITICAL (SSRF to internal services, AWS metadata, local file disclosure) | mandatory `-protocol_whitelist` of `file,crypto,data` for ingest probing only; never trust adopter or end-user HLS URLs as input; refuse `.m3u8` / `.mpd` ingest in v1.4 unless behind explicit opt-in |
| 3 | **Resource-exhaustion DoS** — pathological inputs (long durations, infinite-loop streams, dense codec frames, attacker-controlled output dimensions) saturating CPU, memory, disk, wall time | HIGH (cheap to craft, expensive to defend) | HIGH (worker pool starvation, /tmp full, OOM kills, hosting bill spike) | hard caps: `-t` (duration), `-fs` (file size), `-timelimit` (CPU), wall-clock timeout via subprocess wrapper, output dimension allowlist, named-preset-only transforms |
| 4 | **Orphan FFmpeg processes & temp files** when worker dies mid-transcode (BEAM crash, Oban timeout, container kill) — disk fills, processes survive their parent | HIGH (it WILL happen in production) | MEDIUM (silent disk pressure, eventual /tmp full, ENOSPC failures) | use `MuonTrap` (cgroup-attached subprocess) not raw `Port`; place tempfiles under a known prefix (`Rindle.tmp/`); orphan-tempfile sweeper in `Rindle.Ops`; document host-OS `/tmp` sizing |
| 5 | **CVE exposure window from outdated FFmpeg** in adopter environments — Rindle does not vendor FFmpeg, so adopters running stale Debian/Ubuntu/Alpine images inherit known RCEs (e.g., CVE-2020-13904 still on FFmpeg ≤ 4.2.3 boxes) | MEDIUM (adopters lag on system upgrades) | HIGH (publicly disclosed RCEs against the binary Rindle hands untrusted bytes to) | startup capability probe of `ffmpeg -version`; Rindle refuses to start on FFmpeg < documented minimum; published `RUNNING.md` with patch-level guidance and an Aptfile for Fly.io / Heroku buildpacks |

---

## 2. Security Footguns (numbered, with mitigations)

### S-1. argv injection via user-controlled strings

**Pitfall:** Any string interpolated into the FFmpeg command line — codec name, filter graph, output filename, watermark text, subtitle path — becomes an argument-injection vector if the spawn call uses a shell or if the value is allowed to start with `-`.

**Reference incidents:**
- Jellyfin **GHSA-866x-wj5j-2vf4** & **GHSA-2c3c-r7gp-q32m** — `videoCodec` / `audioCodec` query params injected into the FFmpeg arg list, achieving arbitrary file read/write via `-attach` and `-dump_attachment:t`. Critically, **`UseShellExecute=false` did NOT save them** because the args were still concatenated into a single string before `argv[]` parsing.
- **CVE-2023-39018** (bramp `ffmpeg-cli-wrapper`) — assumed code injection via constructor arg.
- **`-attach` / `-dump_attachment:t`** + MKV containers gives arbitrary file read/write **without** any shell metacharacter — pure FFmpeg-flag abuse.

**Mitigation (locked):**
1. **Always pass `argv` as a list of binaries to `System.cmd/3`** — never join into a single string, never use `System.shell/2`, never use `:os.cmd/1`.
2. **Allowlist for every adopter-facing parameter:**
   - codecs: `~w(libx264 libx265 libvpx-vp9 aac libmp3lame libopus copy)`
   - containers: `~w(mp4 webm m4a mp3 ogg)`
   - filter graphs: named presets only; raw `filter_complex` strings forbidden in v1.4.
3. **Reject any user-supplied value beginning with `-`** at validation boundary, even if allowlisted. (Defense in depth — protects against allowlist drift.)
4. **No user-controlled output filenames passed to FFmpeg** — Rindle controls all paths via `Rindle.Security.StorageKey`.
5. **Refuse Matroska (mkv) ingest in v1.4 unless explicitly opted in.** MKV's attachment mechanism is the canonical exfiltration vector; webm (a Matroska subset) only on a strict subset of allowed elements.

### S-2. HLS / DASH playlist SSRF & local file disclosure

**Pitfall:** FFmpeg defaults to a permissive protocol set (file, http, https, tcp, udp, rtp, gopher, hls, concat, subfile, crypto…). A crafted `.m3u8` / `.mpd` playlist references arbitrary URLs, which FFmpeg will fetch when probing — bypassing the application's network ACLs.

**Reference incidents:**
- **CVE-2016-1897 / CVE-2016-1898** — original SSRF via crafted m3u8 (Black Hat USA 2016: "Viral Video — Exploiting SSRF in Video Converters" by Nikolay Ermishkin).
- **CVE-2020-13904** — HLS use-after-free RCE in FFmpeg ≤ 4.2.3 via crafted `EXTINF` duration in m3u8.
- **CVE-2023-6603** — HLS playlist null-pointer-deref DoS.
- **HackerOne #237381 (Automattic)** — SSRF + local file disclosure via FFmpeg HLS.
- **HackerOne #1062888 (TikTok)** — external SSRF + local file read via FFmpeg.

**Mitigation (locked):**
1. **Always pass `-protocol_whitelist file,crypto,data`** when probing or transcoding any user-supplied media. (`crypto` and `data` are required for legitimate AES-encrypted segments and inline data URIs respectively; `file` is required to read the local input — but no `http`, `https`, `tcp`, `concat`, `subfile`, `gopher`.)
2. **Pass `-protocol_whitelist` BEFORE `-i`** in argv. (FFmpeg parses left-to-right; misplacement is silently ignored.)
3. **Refuse `.m3u8` / `.mpd` / `.f4m` / playlist-style inputs in v1.4.** If ingested, demux only locally-resolved segments — never let FFmpeg follow URLs. This is a deliberate scope-narrower for the milestone; a future "live ingest" milestone can reopen with a manifest sanitizer.
4. **For `concat` demuxer (if ever exposed): always pass `-safe 1`** — rejects unsafe paths and protocol specs in concat lists.
5. **Run inside a network namespace / egress firewall** when adopter has the option (document but do not require). Note: even with `-protocol_whitelist`, defense in depth is cheap.

### S-3. Resource-exhaustion DoS (CPU / memory / disk / wall time / output size)

**Pitfall:** A small malicious input can cause unbounded output. Examples:
- Audio with `loop -1` or extremely long duration (FFmpeg ticket #9361 — `av_read_frame` infinite loop).
- Pathological codec inputs (CVE-2018-7751 SVG infinite-loop probe; **multiple "hang on seek-near-end" reports** for ffmpeg in audio tools).
- Tiny input → giant output via codec choice + scaling (e.g., 1KB input upscaled to 8K output).
- Subtitle text overflows (drawtext filter heap overflow, 2024).

**Reference incidents:**
- **CVE-2018-7751** — `svg_probe` infinite loop DoS.
- **MediaWiki / Wikipedia** uses **firejail + `ulimit -t` (CPU time) + `timeout` (wallclock)** for ImageMagick/FFmpeg/rsvg.
- Frigate, Tdarr, MythTV public bug threads on **ENOSPC during transcode** when `/tmp` fills.

**Mitigation (locked):**

| Limit | FFmpeg Flag | Recommended Default | Why |
|-------|-------------|---------------------|-----|
| Output duration | `-t <seconds>` | `min(input_duration, profile.max_duration_s)` | Stops infinite-loop streams |
| Output file size | `-fs <bytes>` | `profile.max_output_bytes` (e.g. 500 MB) | Stops decompression-bomb-style outputs |
| CPU time | `-timelimit <seconds>` | `profile.max_cpu_seconds` (e.g. 300) | FFmpeg's internal guard |
| Wall-clock time | external (`MuonTrap`/`Task.yield_or_kill` w/ kill) | `profile.max_wall_seconds` (e.g. 600) | FFmpeg's `-timelimit` is CPU-time only; wall guard catches stalls |
| Threads | `-threads <n>` | `profile.threads` (default 2) | Predictable scheduler load |
| Output dimensions | filter validation | allowlist or capped scale | Prevents 1KB → 8K bombs |
| Bitrate | `-maxrate` + `-bufsize` | `profile.max_bitrate` | Caps memory in encoder |
| Probe size | `-probesize` + `-analyzeduration` | conservative defaults | Caps CPU on input probe |

**Rindle invariant:** every transcode runs under all four caps (`-t`, `-fs`, `-timelimit`, wall-clock). Missing any one is a regression.

### S-4. Magic-byte detection: spoofable but not bypassable for *our* purposes

**Pitfall:** Magic bytes are spoofable in two ways:
1. **Polyglot files** — a single byte sequence valid as both JPEG and ZIP, etc. Real risk.
2. **Container-carried payloads** — a legitimate MP4 carrying malicious metadata strings, attached pictures, or embedded subtitles.

**Reference:**
- T1036.008 (MITRE ATT&CK) — Masquerade File Type via magic-byte manipulation and polyglots.
- Active Storage / Shrine / Spatie all rely on `marcel` / `mimemagic` / `php-fileinfo`, which sniff first ~8KB. Same approach Rindle already uses (`Rindle.Security.Mime` with `ExMarcel`, 8192-byte probe).

**Mitigation (locked):**
1. Keep current `ExMarcel`-based magic-byte check; it is the SOTA approach. **Don't trust client-supplied MIME or extension; we already enforce this — extend the same pattern to video/audio types.**
2. **Add ffprobe as a second-stage validator** for video/audio: after magic-byte check passes, run `ffprobe -v error -print_format json -show_streams -show_format -protocol_whitelist file -i $path`. If FFprobe rejects the file, quarantine. This catches "valid header, malformed body" cases magic-byte sniffing misses.
3. **FFprobe must run with the same security hardening as FFmpeg** — `-protocol_whitelist`, timeout, resource limits. FFprobe is FFmpeg with a different driver; it has the same SSRF/RCE surface.
4. **Treat container-carried metadata (title, artist, comment, embedded subtitles, attached pictures) as untrusted user input**. Never interpolate into shell commands, log lines that get rendered as HTML, or filenames. Sanitize before storing in DB; truncate to reasonable lengths.
5. **Polyglot risk is mostly an image problem; for video/audio, the higher risk is "valid container + malicious decoder payload"** (the FFmpeg CVE class). Mitigation #2 (FFprobe re-validation) is the better lever than polyglot detection.

**Reliability of magic-byte detection per format:**

| Format | Magic | Reliability | Notes |
|--------|-------|-------------|-------|
| MP4 / M4A / MOV | `....ftyp` at offset 4 | HIGH | The `ftyp` brand inside disambiguates mp4/m4a/mov |
| WebM | `1A 45 DF A3` (EBML) | MEDIUM | Same magic as MKV; brand check needed |
| MKV | `1A 45 DF A3` (EBML) | MEDIUM | Discouraged for v1.4 (attachment exfil vector) |
| Ogg | `OggS` | HIGH | But codec inside (Vorbis, Opus, Theora) needs disambiguation |
| MP3 | `ID3` or `FF Fx/Ex/Dx` | LOW | MP3 has no proper container magic; can be confused with raw streams |
| WAV | `RIFF....WAVE` | HIGH | |
| FLAC | `fLaC` | HIGH | |
| AAC raw | none (ADTS sync `FFF1/FFF9`) | LOW | Reject raw AAC; require m4a container |

**Rindle position:** magic-byte + ffprobe-reject-on-error + container-brand sub-check for ftyp/EBML/Ogg.

### S-5. Container metadata as a XSS / template-injection vector

**Pitfall:** Adopters render uploaded video metadata (title, artist, comment) in their UI, admin pages, telemetry dashboards, log aggregation. Crafted metadata can carry script tags, ANSI escapes, format-string injections, log-injection (`\n`).

**Reference:** Generic OWASP guidance; multiple bug bounty reports on metadata-driven XSS.

**Mitigation (locked):**
1. Rindle stores container metadata as opaque strings; **does not interpret, does not sanitize for HTML**. Sanitization is the adopter's render layer's job.
2. **Truncate metadata strings to 1024 bytes** before storage — caps DB bloat and limits worst-case payload.
3. **Strip control characters** (`\x00-\x1F` except `\t`) from metadata at ingest — prevents log injection in operator dashboards.
4. **Document this contract loudly** in `RUNNING.md` and in the moduledoc of `Rindle.Domain.MediaAsset` — adopters MUST treat metadata as untrusted UGC.

### S-6. Filename / path safety for adopter-visible outputs

**Pitfall:** Container metadata can carry crafted filenames intended to escape sandboxes when adopters use them as `Content-Disposition` filenames or download names.

**Mitigation (locked):**
- Already addressed for images via `Rindle.Security.Filename.sanitize/1`. **Extend the same regex-based normalization to video/audio uploads.** No new code needed beyond test coverage.
- For `Content-Disposition: attachment; filename=...` delivery (a likely v1.4 ask), use **`filename*=UTF-8''<percent-encoded>` (RFC 5987)** with the sanitized basename — never the raw container metadata.

### S-7. FFmpeg version drift: adopter inherits known CVEs

**Pitfall:** Rindle does not (and should not) vendor FFmpeg. Adopters on stale OS images run vulnerable FFmpeg versions. Recent examples:
- **CVE-2024-7055** (heap overflow in `pnm_decode_frame`)
- **CVE-2024-7272** (heap buffer overflow)
- **CVE-2025-1373** (use-after-free)
- **JPEG2000 cdef heap overflow** (Google security-research advisory)
- **RFC4175 RTP integer overflow → heap overflow** (ZeroPath 2025 disclosures)
- **drawtext filter heap overflow** (ZeroPath 2025)

**Mitigation (locked):**
1. **Capability probe at startup** (`ffmpeg -version`) — Rindle reads version, refuses to start if below documented minimum.
2. **Documented minimum FFmpeg in `mix.exs` package metadata**: target FFmpeg ≥ 6.0 for v1.4. (Justification: 6.0 is in Ubuntu 24.04 LTS / Debian 12 / Alpine 3.19. Anything older has known unpatched CVEs.)
3. **`Rindle.Capabilities.report/0`** function adopters can log/display in admin pages — surfaces version to operators.
4. **Telemetry event `[:rindle, :media, :ffmpeg, :version_check]`** at startup so dashboards alert on drift.
5. **`RUNNING.md` lists CVE rationale** — adopters with stale FFmpeg understand WHY they need to upgrade.

---

## 3. Operational Footguns (numbered, with mitigations)

### O-1. Long-running Oban jobs vs. job timeout / re-enqueue

**Pitfall:** Default Oban worker behavior is "perform/1 returns when done; system reboots = job lost or duplicated." A 10-minute video transcode that gets killed at minute 9 by a deploy retries from scratch — wastes 9 minutes of CPU AND duplicates the partial output.

**Reference (Oban docs):**
- `timeout/1` callback per worker — Oban kills the worker process after N ms.
- Without `timeout/1`, an Oban worker can run forever (until the BEAM dies or the job is manually pruned).
- Sidekiq Pro's "Reliable Fetch" pattern is the Ruby equivalent.

**Mitigation (locked):**
1. **`timeout/1` is mandatory on every video/audio worker.** Make it a behavior callback Rindle's variant-processor module enforces.
2. **Worker is fully idempotent** — same `(asset_id, variant_name)` invocation produces same output, safe to replay.
3. **No partial-output side effects** — variant only flips to `ready` after the *full* upload to storage succeeds. (This is already the v1.0 contract — extend it; do not break it.)
4. **Profile-level `:max_wall_seconds`** maps to both Oban `timeout/1` and FFmpeg subprocess wallclock.
5. **Document Oban `prune` interaction** — operators need to know that a `prune` of in-flight jobs is destructive; provide a checked example.

### O-2. Disk pressure during transcode

**Pitfall:** FFmpeg writes large intermediate files. Default `/tmp` on a Phoenix container is often small (Fly.io, Heroku dynos default to a small ephemeral volume). 10 concurrent transcodes × 500MB each = 5GB; if `/tmp` is 1GB, ENOSPC kills jobs mid-flight, leaves orphan files. Frigate, Tdarr, MythTV bug trackers all document this exact failure.

**Mitigation (locked):**
1. **Configurable temp dir** via `:rindle, :tmp_dir` (default: `System.tmp_dir!()`). Adopters mount large ephemeral volumes here.
2. **Disk-space precheck before starting transcode** — refuse to enqueue if free space < `2 × profile.max_output_bytes`. Cheap, prevents most ENOSPC.
3. **Streaming output where possible** — if delivery target is S3, prefer `ffmpeg -f mp4 -movflags +faststart pipe:1 | aws s3 cp -` style flow; avoid local temp file entirely. (Defer to v1.5 if too complex; v1.4 can write to local temp and upload.)
4. **Check `close()` return value, not just `write()`** — ENOSPC often surfaces only at close. Rindle's storage adapter `head/2` after upload catches the resulting truncated file.
5. **Document tmpfs inode exhaustion** — even with space, tmpfs can exhaust inodes if many tiny files accumulate. Sweeper (O-3) handles this.

### O-3. Orphan temp files & orphan FFmpeg processes when worker dies

**Pitfall:** When the Oban worker process dies (BEAM crash, supervisor kill, container OOM kill, Oban timeout), spawned FFmpeg subprocesses can survive the parent and keep running, AND temp files in `/tmp` are not cleaned up. Both are well-documented BEAM/Erlang `Port` failure modes.

**Reference:**
- Erlang Forum discussion on `open_port` and zombie processes (3111).
- `MuonTrap` library's entire raison d'être is solving this — it attaches subprocesses to Linux cgroups so they die when the parent does.
- `Rambo` solves the same problem on macOS/Linux/Windows via a wrapper binary.
- `Porcelain` is documented-abandoned and leaks processes.
- Elixir issue #9171 on zombie process wrapper script not exiting on wrapped program exit.

**Mitigation (locked):**
1. **Use `MuonTrap.cmd/3` or `Rambo.run/2` for subprocess invocation, NOT raw `Port.open/2` or `System.cmd/3`.** Rindle's port wrapper module enforces this single entrypoint.
2. **Recommendation: `MuonTrap`** (by Frank Hunleth, well-maintained, used in Nerves) on Linux production hosts. Reason: cgroup attach gives kill-on-parent-death AND optional CPU/memory limits.
3. **Fallback: `Rambo`** if portability to macOS dev / Windows CI is required.
4. **All temp files under `Rindle.tmp/<uuid>/`** prefix — single sweepable root.
5. **`Rindle.Ops.SweepOrphanedTempFiles` Oban worker**, runs hourly, deletes anything in `Rindle.tmp/` older than a configurable threshold (default 4h, longer than any reasonable transcode + retry).
6. **Telemetry event when sweeper finds orphans** — operators get alerted on accumulating orphan rate (signal of worker crashes).

### O-4. Concurrent transcode of same asset (race)

**Pitfall:** Two operators kick off "regenerate variant" simultaneously, OR a regen + a fresh upload, OR a stale Oban job retries while a fresh job runs. Result: variant record state thrashes, output gets overwritten mid-write, S3 PUT race, attachment pointer flips between the two outputs.

**Reference:**
- Shrine `atomic_persist` / `Shrine::AttachmentChanged` — Ruby-side solution: reload-and-compare before commit.
- Rindle already has Oban uniqueness on `(worker, queue, asset_id, variant_name)` in `VariantMaintenance` (good). Need to extend to v1.4 video/audio worker classes.

**Mitigation (locked):**
1. **Oban `unique` constraint on `(worker, args.asset_id, args.variant_name)` for `:available, :scheduled, :executing, :retryable` states** — already the pattern in `Rindle.Ops.VariantMaintenance`. Replicate verbatim for video/audio workers.
2. **Atomic-promote check** — before flipping variant to `ready`, reload the asset, compare `storage_key`, abort if changed. Equivalent to Shrine's `AttachmentChanged`. Rindle's `ProcessVariant.process/3` already has the scaffolding; harden for v1.4.
3. **Oban job ID logged in telemetry** — operators can grep races back to the jobs that lost.

### O-5. Observability: what operators MUST see

**Pitfall:** Operators get paged because "video processing slow." Without the right telemetry, they can't tell:
- Is FFmpeg running but slow?
- Is the queue backed up?
- Is `/tmp` full?
- Is there an FFmpeg version mismatch?
- Are jobs orphaning on a specific input pattern?

**Mitigation (locked):** add these telemetry events for v1.4:

| Event | Measurements | Metadata |
|-------|--------------|----------|
| `[:rindle, :media, :transcode, :start]` | system_time | asset_id, profile, variant_name, codec, attempt |
| `[:rindle, :media, :transcode, :stop]` | duration, output_bytes | asset_id, profile, variant_name, exit_status |
| `[:rindle, :media, :transcode, :exception]` | duration | kind, reason, asset_id |
| `[:rindle, :media, :ffmpeg, :version_check]` | system_time | version, supported? |
| `[:rindle, :media, :probe, :stop]` | duration | format, codec, duration_s, width, height |
| `[:rindle, :media, :sweep_orphans, :stop]` | files_removed, bytes_freed | sweep_root |
| `[:rindle, :media, :tmp_dir, :pressure]` | free_bytes, used_pct | (emitted on precheck failure) |

Existing image-variant telemetry naming convention applies — extend, don't replace.

### O-6. Capacity-planning knobs

**Pitfall:** Adopter starts a v1.4 deploy, gets two big videos uploaded simultaneously, and 100% CPU + OOM the dyno because nothing throttles concurrency.

**Mitigation (locked):** expose these knobs explicitly:

| Knob | Where | Default | Why |
|------|-------|---------|-----|
| Oban queue concurrency for `:rindle_process` | adopter's `oban` config | 2 | Conservative; image queue stays separate |
| Per-profile `:max_concurrent_transcodes` | profile DSL | 2 | Caps in-flight per profile (per asset class) |
| `:ffmpeg_threads` | profile DSL | 2 | FFmpeg `-threads`; predictable per-job CPU |
| `:max_wall_seconds` | profile DSL | 600 | Worker timeout + FFmpeg wallclock kill |
| `:max_cpu_seconds` | profile DSL | 300 | FFmpeg `-timelimit` |
| `:max_output_bytes` | profile DSL | 500 MB | FFmpeg `-fs` |
| `:max_duration_seconds` | profile DSL | 7200 (2h) | FFmpeg `-t` |

**Anti-knob:** do NOT expose raw `filter_complex`, raw `-vf`, raw `-codec:v` — those become S-1 vectors. Surface only validated profile fields.

### O-7. Backpressure: when GenStage / Broadway becomes the right answer

**Pitfall:** Burst ingestion (10K videos in an hour from a content migration) overwhelms Oban + storage even with concurrency caps. Oban handles this by queueing — but for high-throughput streaming pipelines (live ingest), Broadway's pull-based backpressure is materially better.

**Mitigation (locked, but scoped):**
- **v1.4 sticks with Oban** (matches v1.0–v1.3 invariant; adopter-owned Oban). Burst handling = Oban queue concurrency + adopter scaling.
- **Document the Broadway escape hatch** in `RUNNING.md` for adopters with high-throughput live ingest. Rindle's variant pipeline could be re-fronted with a Broadway producer in a future milestone — but v1.4 does not ship it. (Avoids scope creep; Oban-only stays the v1.4 invariant.)
- **Anti-pattern:** do NOT introduce GenStage as a parallel runtime alongside Oban for v1.4. Two job systems is the worst of both worlds.

### O-8. Cleanup of failed-mid-upload variants

**Pitfall:** Transcode succeeds locally, S3 PUT fails halfway through (network blip), local temp file cleaned up, S3 left with a partial object. Variant record stuck in `processing`. Storage costs accrue silently.

**Mitigation (locked):**
1. Use **multipart upload with `abort_on_failure: true`** for any output > 5 MB (already a v1.1 capability — reuse).
2. Variant FSM transition `processing → failed` always pairs with a "delete partial S3 object if storage_key was set" step.
3. **`Rindle.Ops.CleanupOrphans` already exists** — extend it to scan for storage objects with a `storage_key` matching variant naming pattern but no DB record.
4. Telemetry on partial-cleanup so operators see the rate.

---

## 4. Cross-Language Peer Lessons (one paragraph each)

### Rails Active Storage + ffmpeg analyzer

Active Storage's video story is **incomplete by design**: `ActiveStorage::Analyzer::VideoAnalyzer` extracts width, height, duration, and aspect ratio via `ffprobe`, and `ActiveStorage::Previewer::VideoPreviewer` extracts a poster via `ffmpeg`. **It does not transcode** — variants are images-only. **Notorious weakness:** the previewer historically did not check for `ffmpeg` presence and threw a 500 in production when the binary was missing (rails/rails#39047, fixed late). **Lesson for Rindle:** capability-probe at startup, fail loudly if FFmpeg is missing, don't surprise adopters at first video upload. **Strength to copy:** the analyzer-vs-previewer split is clean — *probe metadata* and *generate poster* are different concerns with different failure semantics. Active Storage also got the **MuPDF-AGPL footgun** wrong by not flagging the licensing implication; Rindle should keep PDF/MuPDF firmly out of v1.4 scope (already in PROJECT.md "Out of Scope"). **Anti-pattern to avoid:** Active Storage hides the transcoder behind ActiveJob inheritance — when a job lifecycle issue surfaces, debugging requires diving into Rails internals. Rindle's pattern (explicit Oban worker, explicit FSM transitions, explicit telemetry) is materially better for production debugging. ([rails/rails#39047](https://github.com/rails/rails/pull/39047), [Active Storage Overview](https://guides.rubyonrails.org/active_storage_overview.html))

### Shrine (Ruby) + streamio-ffmpeg

Shrine's video story is the **strongest peer reference for Rindle's v1.4**. Pattern: derivatives plugin defines named transformations; backgrounding plugin runs them in Sidekiq; `atomic_persist` raises `Shrine::AttachmentChanged` if the source changed during processing. **Lesson:** the `AttachmentChanged` exception is exactly the right shape for the "asset replaced mid-transcode" race — Rindle has an equivalent reload-and-compare in `ProcessVariant`, **harden it for v1.4 with explicit named-state transitions** so the failure is observable, not silent. **Strength to copy:** Shrine's docs explicitly say "set a generous timeout — a 500MB video can take several minutes to process" and "ensure FFmpeg installation in production." Both should be in Rindle's `RUNNING.md` verbatim. **Weakness to avoid:** streamio-ffmpeg uses Ruby string interpolation for some FFmpeg args in older versions (now fixed), and the mental model is "the wrapper handles escaping." Don't trust wrapper escaping — pass argv lists; this is the S-1 pitfall from another angle. ([Shrine processing docs](https://shrinerb.com/docs/processing), [Shrine atomic_helpers](https://shrinerb.com/docs/plugins/atomic_helpers), [Better File Uploads with Shrine: Processing](https://janko.io/better-file-uploads-with-shrine-processing/))

### CarrierWave (+ carrierwave-video)

CarrierWave is **the cautionary tale**. Issues per public trackers: temp-file lifecycle bugs (#1338 closed-stream errors; #1662 `ENOENT` unless `delete_tmp_file_after_storage = false`), the only background-job extension (`carrierwave_backgrounder`) hasn't released since 2015, and cache directories don't auto-clean. The pattern Rindle should reject: **synchronous-by-default with bolted-on backgrounding**. CarrierWave's video flavor inherits all of these plus FFmpeg invocation via Ruby string interpolation in older variants. **Lesson:** Rindle's "Oban-required, async-by-default, atomic FSM" stance is the inverse and the right one. **Lesson on temp files:** CarrierWave's "delete after storage" toggle is a footgun; either always clean (with confirmation that storage write succeeded) or never clean (with sweeper). Don't make the adopter choose. Rindle's sweeper-based approach (O-3) is correct. ([carrierwave#1338](https://github.com/carrierwaveuploader/carrierwave/issues/1338), [carrierwave#1662](https://github.com/carrierwaveuploader/carrierwave/issues/1662), [carrierwave_backgrounder](https://github.com/lardawge/carrierwave_backgrounder))

### Spatie Media Library (Laravel)

Spatie's "day-2 ergonomics" reputation is real, but its **video story is deliberately narrow**: the built-in video integration extracts thumbnails via PHP-FFMpeg / FFProbe — it does not transcode. Adopters who want full video conversions roll custom event listeners and call FFmpeg directly. **Critical operational lesson** lifted from Spatie's docs verbatim: "FFMPEG does not support uploading files to S3 or GCS — handle conversions locally first." **This is the correct boundary**: Rindle should write transcoded output to a local temp file, then explicitly upload via the configured storage adapter, never try to be clever with FFmpeg's built-in S3/HTTP outputs (which would also reopen S-2 SSRF concerns). Spatie's also-correct lesson: "use a long queue, don't rely on default queue timeout." Same advice as Shrine. **Anti-pattern from Spatie:** the doc/issue history shows a steady drumbeat of adopters wanting "video conversions" that the library punts to "build it yourself" — Rindle should ship at least one named-preset video pipeline (e.g., 720p MP4 web-streaming preset) so v1.4 has a real demo, not just primitives. ([Spatie defining conversions](https://spatie.be/docs/laravel-medialibrary/v11/converting-images/defining-conversions), [Spatie video image generator](https://github.com/spatie/laravel-medialibrary/blob/main/src/Conversions/ImageGenerators/Video.php))

### Django (django-video-encoding / django-ffmpeg)

**Both are unmaintained.** `django-video-encoding` has had no PyPI release in 12+ months; `django-ffmpeg` is older still. The Django video community has largely **abandoned in-process transcoding** in favor of either (a) Cloudinary/Mux/Bunny.net managed services or (b) Celery jobs that shell to FFmpeg with no abstraction. **Lesson for Rindle:** the Django landscape is a market signal that "thin FFmpeg wrappers" don't survive — the value is in the lifecycle (FSM, retries, atomic attach, observability), not in the FFmpeg call itself. Rindle's existing image-lifecycle architecture is the differentiator; v1.4 should keep the FFmpeg call dumb and the lifecycle smart. **Strength to copy:** django-video-encoding's "implement your own backend" pattern (default ffmpeg, but pluggable) maps cleanly to Rindle's existing processor behaviour. Pluggability lets Mux/Transloadit adapters slot in without reopening core. ([django-video-encoding](https://github.com/escaped/django-video-encoding), [Snyk Advisor analysis](https://snyk.io/advisor/python/django-video-encoding))

### Mux SDK / Mux Direct Upload

Mux's API is the **gold standard for "what to hide"**. Adopter creates a direct-upload URL via server-side API (never client-side; CORS/credential exposure is documented as a security risk), client uploads to that signed URL, Mux processes async, webhook fires when ready (signed with HMAC, adopter verifies). **Adopter never sees:** transcode parameters, codec choice, ladder configuration, FFmpeg, temp files, retry policy. **Adopter sees:** asset ID, playback ID, status webhook. **Lessons for Rindle:** (1) the **server-only credential boundary** is non-negotiable — Rindle already enforces this for presigned PUT; reuse pattern verbatim for video. (2) **Webhook-style "asset ready" callback** is a great DX for adopters not wanting to poll — Rindle's telemetry-emitted `[:rindle, :media, :variant, :ready]` is the equivalent; document it as the integration point. (3) **`playback_id` as a stable opaque token** instead of leaking storage keys is a lesson Rindle hasn't fully internalized — for v1.4, consider a `delivery_id` that's signing-scoped and doesn't leak the underlying storage_key path structure. (4) **Mux "static rendition vs HLS" distinction** maps to Rindle's named-preset model — adopter chooses progressive MP4 (single file) vs adaptive HLS (multi-file ladder) at the profile level. v1.4 should ship progressive MP4 only; HLS = future milestone. ([Mux create direct upload](https://www.mux.com/docs/api-reference/video/direct-uploads/create-direct-upload), [Mux verify direct uploads with webhooks](https://www.mux.com/blog/verify-direct-uploads-with-mux-webhooks), [Mux static renditions](https://www.mux.com/docs/guides/enable-static-mp4-renditions))

### Cloudinary video API

Cloudinary's DX excellence is the **named-transformation model with strict-transformations enforcement**. Adopter defines a transformation by name on the dashboard or via API; URLs reference the name. Strict-transformations mode requires every URL to be either pre-defined OR signed — rejects arbitrary ad-hoc transformations. **This is exactly Rindle's "named presets only by default; dynamic = signed" stance, validated externally.** Cloudinary also exposes user-defined variables inside named transformations (e.g., a `text:$watermark_text` variable filled at request time) — sophisticated, but worth flagging as an S-1 vector if Rindle ever does it: variable interpolation must go through allowlist + escape, never raw concat. **Lesson:** Rindle's profile DSL should not gain a "raw FFmpeg filter graph" field; instead, named presets compose pre-validated primitives (resize, crop, fps, bitrate, codec). **DX wins to copy:** Cloudinary's URL signing scheme (HMAC-SHA1 of canonical params) is well-understood and library-implementable; document Rindle's signing scheme similarly. ([Cloudinary transformation reference](https://cloudinary.com/documentation/transformation_reference), [Cloudinary named transformations](https://cloudinary.com/documentation/named_transformations_tutorial), [Cloudinary access control](https://cloudinary.com/documentation/control_access_to_media))

### imgproxy / Thumbor for video

There is **no truly-equivalent open-source product** for video transformation that matches imgproxy's posture (signed URLs, server binary, opinionated security defaults). Closest candidates: **`thumbor` with the video plugin** (not actively maintained), **`imaginary`** (image-only), self-hosted **`Bento4`** for MP4 ops, and the FFmpeg-server-style ad-hoc projects (none production-grade). **Why this matters for Rindle:** Rindle is **not trying to be imgproxy-for-video**. Rindle's role is the lifecycle — variants persisted as DB rows, atomic attach, FSM, retries — and FFmpeg is the unsexy plumbing. Adopters needing dynamic per-request video transforms should reach for Mux or Cloudinary; Rindle's named-preset transcoded outputs serve the 80% case. **Lesson:** don't try to ship a dynamic video transform engine in v1.4 (or ever). The PROJECT.md "Out of Scope" line on "Full HLS/DASH streaming platform" already encodes this — extend it explicitly to "Dynamic per-request video transformation" in v1.4. ([imgproxy signing](https://docs.imgproxy.net/usage/signing_url), [imgproxy alternatives benchmark](https://gist.github.com/DarthSim/9d971d2859f3714a29cf8ce094b3fc55))

### Membrane Framework (Elixir)

Membrane is the **Elixir-native alternative to FFmpeg-port-wrapping** and it is a much heavier abstraction. Membrane builds pipelines from elements (sources, filters, sinks); each element is a GenServer; the framework handles backpressure, format negotiation, demuxing/muxing. **Strengths:** real-time streaming (WebRTC, RTSP, RTMP), live ingest, complex multi-source compositions, fault-isolation per element. **Weaknesses for Rindle's use case:** (a) much larger surface area to consume — Membrane core + plugins for each codec/container — versus a single FFmpeg subprocess; (b) FFmpeg-backed plugins (`membrane_h264_ffmpeg_plugin`) still link FFmpeg as a NIF, inheriting FFmpeg CVE risk *without* the process-isolation benefit a subprocess gives; (c) much more code to learn for adopters. **Locked recommendation:** Rindle v1.4 = **FFmpeg subprocess via MuonTrap**, not Membrane. Reasons: (1) the "single subprocess + temp files" model fits Rindle's FSM-and-Oban architecture cleanly; (2) NIFs that crash the BEAM are worse than subprocesses that crash a single Oban worker; (3) Membrane is the right answer for live streaming, which is explicitly out of scope per PROJECT.md. **Document the boundary** in `RUNNING.md`: "Need WebRTC ingest? Reach for Membrane. Need transcoded variants of uploaded files? Stay with Rindle." ([Membrane framework](https://membrane.stream/learn/get_started_with_membrane), [Elixir for Multimedia practical guide](https://swmansion.com/blog/elixir-for-multimedia-a-practical-guide-for-developers-169adb0eb523), [membrane_h264_ffmpeg_plugin](https://github.com/membraneframework/membrane_h264_ffmpeg_plugin))

### Wallaroo / GenStage / Broadway for backpressure

GenStage and Broadway shine when **the input rate is bursty and producer-driven** — message queues, IoT telemetry, log streams — and consumer pull-throttles the producer. For Rindle's typical use case (user uploads, adopter calls Rindle to enqueue a variant job), the input rate is bounded by users and Oban already provides backpressure via queue concurrency. **Lesson:** GenStage/Broadway is the **right call for live-ingest pipelines** (RTMP feed → live transcode → segment storage) but the **wrong call for upload-driven transcode**. v1.4 stays Oban-only; live-ingest in scope = a future Broadway-fronted milestone. **Anti-pattern:** layering Broadway over Oban inside Rindle (two job systems) is strictly worse than either alone. ([Broadway docs](https://hexdocs.pm/broadway/Broadway.html), [GenStage backpressure tale](https://medium.com/@baaalaji.arumugam/unleash-the-elixir-superpower-with-genstage-caped-crusader-approved-8e08bf9f5854))

---

## 5. Adoption Risks: Per-Platform Compatibility Matrix

| Platform | FFmpeg available? | How to install | Rindle viability | Notes |
|----------|-------------------|----------------|------------------|-------|
| **Local dev — macOS** | No (default) | `brew install ffmpeg` | OK | Document in INSTALL.md; recommend explicit version pin (`brew install ffmpeg@6`) |
| **Local dev — Linux (apt)** | No (default on Ubuntu/Debian) | `apt-get install ffmpeg` | OK | `ffmpeg` package on Ubuntu 24.04 = FFmpeg 6.1; on 22.04 = 4.4 (older — flag) |
| **Local dev — Windows** | No (default) | `choco install ffmpeg` or pre-built static binary | OK with caveats | Windows isn't a Phoenix production target; document for dev only. MuonTrap is Linux-cgroup-specific; on Windows, fallback to Rambo. |
| **CI — GitHub Actions `ubuntu-latest`** | YES | preinstalled on `ubuntu-22.04` and `ubuntu-24.04` runner images | Good | FFmpeg version drifts with image; document in CI: `ffmpeg -version` step. Use `FedericoCarboni/setup-ffmpeg` for pinned versions. |
| **Fly.io** | No (default) | Custom Dockerfile w/ `apt-get install ffmpeg`, OR `fagiani/apt` buildpack with `Aptfile` | Good | Most common Phoenix host; document Dockerfile snippet in INSTALL.md |
| **Heroku** | No (default) | `heroku-buildpack-apt` with `Aptfile` containing `ffmpeg` | Acceptable | Document but flag dyno disk size (`/tmp` is small, ephemeral) |
| **Render** | No (default) | Custom Dockerfile | Good | Same pattern as Fly.io |
| **AWS Lambda / Vercel / similar ephemeral** | No | FFmpeg layer required; runtime caps | **Not recommended** | 15-min execution cap, 512MB-10GB `/tmp`. **Rindle should refuse to run video transcodes here** — flag at startup if `LAMBDA_TASK_ROOT` or `VERCEL` env vars are set, log a warning. Image variants OK; video variants flagged. |
| **Adopter's own Docker image** | Adopter responsibility | `RUN apt-get install -y ffmpeg` | Good | Provide a recommended Dockerfile snippet |

**"I just want to add video to my Phoenix app" — smallest install path:**
1. `mix deps.get` (Rindle declares no FFmpeg-vendored dep — system binary required)
2. `apt-get install ffmpeg` (or brew/choco for dev)
3. Profile DSL: declare `media_type :video`, define a named preset
4. `Rindle.Capabilities.report/0` confirms FFmpeg detected at startup

**If FFmpeg is not installed:** Rindle MUST fail loudly at supervision-tree boot (NOT silently at first upload). Pattern: a `Rindle.Capability.FFmpeg` `GenServer.start_link` that runs `ffmpeg -version` and either succeeds or returns `{:stop, {:ffmpeg_unavailable, reason}}`. Adopter sees the error in their startup logs immediately.

---

## 6. Anti-Patterns — The Top 10 "Rindle MUST NOT" for v1.4 Video/Audio

1. **MUST NOT** invoke FFmpeg via `System.shell/2`, `:os.cmd/1`, or any path that interpolates strings into a shell command line. Argv list only, via `MuonTrap.cmd/3` (preferred) or `System.cmd/3`.

2. **MUST NOT** accept user-controlled values in any FFmpeg flag position — codec, container, filter graph, output filename, watermark text, subtitle path. All adopter-facing parameters are validated against a named-preset allowlist.

3. **MUST NOT** invoke FFmpeg or FFprobe without `-protocol_whitelist file,crypto,data` on user-supplied inputs. SSRF is the default failure mode.

4. **MUST NOT** invoke FFmpeg without `-t`, `-fs`, `-timelimit`, AND an external wall-clock kill. Missing any one is a known DoS vector.

5. **MUST NOT** support HLS / DASH / m3u8 / mpd ingest in v1.4. Manifests are an SSRF and RCE surface; postpone behind a sanitizer milestone.

6. **MUST NOT** support raw `filter_complex` or arbitrary FFmpeg filter graphs in the adopter API. Named presets only; presets compose pre-validated primitives.

7. **MUST NOT** treat container metadata (title, comment, embedded subtitles, attached pictures) as trusted. Metadata is opaque user-controlled content; sanitize on rendering boundary, never on FFmpeg call boundary.

8. **MUST NOT** block the BEAM scheduler with synchronous FFmpeg calls. All FFmpeg invocations run in Oban workers (already the v1.0 invariant — extend, don't break). NIFs that wrap libavcodec are forbidden in v1.4.

9. **MUST NOT** auto-cleanup temp files only "after storage write succeeds" without a sweeper. Worker death between local write and remote upload leaves orphans; the sweeper is mandatory, not optional.

10. **MUST NOT** ship a v1.4 release without a documented FFmpeg minimum version, a startup capability probe, and a per-platform install path (macOS dev, Linux dev, Fly.io, Heroku, Render, GitHub Actions CI). Adopter surprise at first upload is a milestone failure.

---

## 7. Recommended Security Invariants to Add to PROJECT.md

These extend the existing v1.0 list. Numbered in order, surgical, copy-pasteable:

> **8.** FFmpeg/FFprobe subprocess invocation uses argv list only — never shell. All user-controllable parameters (codec, container, dimensions, duration, bitrate) are validated against named-preset allowlists before reaching the argv list.
>
> **9.** Every FFmpeg/FFprobe invocation passes `-protocol_whitelist file,crypto,data` and is wrapped in subprocess time, CPU, memory, and output-size limits. Wall-clock kill is enforced externally; FFmpeg's `-timelimit` alone is insufficient.
>
> **10.** Container metadata (title, artist, comment, embedded subtitles, attachments) is treated as untrusted user-controlled content end-to-end. Rindle stores it opaquely (truncated, control-chars stripped); adopters MUST sanitize on render.
>
> **11.** HLS / DASH / playlist-style ingest is out of scope. Inputs accepted by ingest are single-container files only (mp4, webm, m4a, mp3, ogg, wav, flac).
>
> **12.** Rindle declares an FFmpeg minimum version, capability-probes at supervisor boot, and refuses to start with stale or missing FFmpeg. Adopters never silently inherit FFmpeg CVE exposure.
>
> **13.** Temp files for transcoding live under a single sweepable root (`Rindle.tmp/`); orphans are reaped by a scheduled `Rindle.Ops` worker. No transcode is allowed without an enforceable parent-death subprocess kill (MuonTrap on Linux; Rambo on macOS/Windows dev).

---

## 8. Open Questions Worth Escalating (max 2)

These are the only decisions that materially affect adopter runtime cost or public API and should not be silently chosen by an executor agent.

### Q1. Default resource-limit values: what hard caps does Rindle ship?

**Why this matters:** these defaults directly cap adopter user-supplied workloads. Too tight and legitimate two-hour podcasts fail. Too loose and a DoS attacker burns the adopter's hosting bill before the limit kicks in. The numbers ship in the public `Rindle.Profile` DSL; changing them is a breaking change.

**Proposed (conservative) defaults:**

| Cap | Default | Rationale |
|-----|---------|-----------|
| `max_duration_seconds` | 7200 (2h) | Covers podcasts, lectures, conference talks; rejects pathological inputs |
| `max_output_bytes` | 500 MB | One 1080p H.264 720p hour is ~500MB; tighter than 4K but adopter overrides per-profile |
| `max_wall_seconds` | 600 (10 min) | Covers most 2h transcodes at modest quality; aggressive presets need explicit override |
| `max_cpu_seconds` | 300 (5 min) | FFmpeg `-timelimit`; multiplexed by `-threads` |
| `ffmpeg_threads` | 2 | Predictable per-job CPU; adopter can scale concurrency separately |

**Decision needed from human:** are these the ship-defaults, or should they be even tighter (e.g., 30-min max duration default and adopters must explicitly raise) to protect adopters who don't read the docs? Trade-off: tighter defaults = more "why doesn't my upload work?" support load; looser defaults = more "my hosting bill exploded" support load.

### Q2. v1.4 scope: ship Mux/Cloudinary adapter alongside FFmpeg, or FFmpeg-only?

**Why this matters:** there are two viable v1.4 stories.
- **Story A (FFmpeg-only):** v1.4 ships in-process FFmpeg transcoding. Adopters get the simple "apt-get install ffmpeg + define preset" experience. Footprint: small, fast to ship, matches the existing image-processing wedge architecturally.
- **Story B (FFmpeg + adapter pluggability):** v1.4 also defines a `Rindle.Processor.Video` behaviour with reference adapters for Mux and Cloudinary alongside the default FFmpeg adapter. Adopters who don't want to run FFmpeg can BYO managed-service. Footprint: larger, more public surface, more docs, more failure modes.

The existing image processor is `Rindle.Processor.Image` (single, FFmpeg-style local pattern). The "AI processor extension point" in PROJECT.md "Out of Scope" suggests the project has explicitly chosen to keep external-service adapters out of core. Story A maintains that boundary. Story B opens a pattern that's hard to retract.

**Decision needed from human:** stay narrow (Story A — FFmpeg-only, document the Mux escape hatch in prose only) or broaden (Story B — define the adapter behaviour in v1.4 even if only the FFmpeg adapter ships)? Recommendation from research: **Story A**. Reasons: (1) v1.2/v1.3 lessons say tight scope shipped; broad scope generated cleanup phases. (2) The "media-agnostic core, image-first" decision in PROJECT.md was deliberately delayed-binding for video; v1.4 can ship the FFmpeg path and v1.5 can add adapter pluggability if real-world adopters request it. (3) Deferring the adapter behaviour avoids locking a potentially-wrong public API before adopter feedback.

---

## Sources

### FFmpeg CVE / security research

- [FFmpeg Security page (canonical CVE list)](https://ffmpeg.org/security.html)
- [FFmpeg CVE list at cvedetails](https://www.cvedetails.com/vulnerability-list/vendor_id-3611/Ffmpeg.html)
- [Black Hat USA 2016 — Viral Video: Exploiting SSRF in Video Converters (Ermishkin)](https://blackhat.com/docs/us-16/materials/us-16-Ermishkin-Viral-Video-Exploiting-Ssrf-In-Video-Converters.pdf)
- [HackerOne #237381 — Automattic SSRF and local file disclosure via FFmpeg HLS](https://hackerone.com/reports/237381)
- [HackerOne #1062888 — TikTok external SSRF and local file read via FFmpeg](https://hackerone.com/reports/1062888)
- [Writeups.io — SSRF via FFmpeg HLS Processing](https://writeups.io/summaries/technical-analysis-of-ssrf-vulnerability-via-ffmpeg-hls-processing/)
- [Krevetk0 / Medium — SSRF vulnerability via FFmpeg HLS processing](https://krevetk0.medium.com/ssrf-vulnerability-via-ffmpeg-hls-processing-f3823c16f3c7)
- [GitHub PoC — 0xcoyote/FFmpeg-HLS-SSRF](https://github.com/0xcoyote/FFmpeg-HLS-SSRF)
- [Jellyfin GHSA-866x-wj5j-2vf4 — Argument Injection in FFmpeg codec parameters](https://github.com/jellyfin/jellyfin/security/advisories/GHSA-866x-wj5j-2vf4)
- [Jellyfin GHSA-2c3c-r7gp-q32m — FFmpeg Argument Injection](https://github.com/jellyfin/jellyfin/security/advisories/GHSA-2c3c-r7gp-q32m)
- [Snyk SNYK-JS-EXTRAFFMPEG-607911 — Command injection in extra-ffmpeg](https://security.snyk.io/vuln/SNYK-JS-EXTRAFFMPEG-607911)
- [bramp/ffmpeg-cli-wrapper #291 — CVE-2023-39018 assumed code injection](https://github.com/bramp/ffmpeg-cli-wrapper/issues/291)
- [Staaldraad — Argument injection and getting past shellwords.escape](https://staaldraad.github.io/post/2019-11-24-argument-injection/)
- [SentinelOne — CVE-2024-7272 FFmpeg Heap Buffer Overflow](https://www.sentinelone.com/vulnerability-database/cve-2024-7272/)
- [SentinelOne — CVE-2025-1373 FFmpeg Use-After-Free](https://www.sentinelone.com/vulnerability-database/cve-2025-1373/)
- [GitHub Advisory CVE-2024-7055 — pnm_decode_frame heap overflow](https://github.com/advisories/GHSA-5gxm-744m-qfgp)
- [Google security-research GHSA-39q3-f8jq-v6mg — JPEG2000 cdef heap-buffer-overflow](https://github.com/google/security-research/security/advisories/GHSA-39q3-f8jq-v6mg)
- [ZeroPath — Autonomously finding 7 FFmpeg vulnerabilities (2025)](https://zeropath.com/blog/autonomously-finding-7-ffmpeg-vulnerabilities-with-ai-2025)
- [Rapid7 — CVE-2018-7751 svg_probe infinite loop](https://www.rapid7.com/db/vulnerabilities/ffmpeg-cve-2018-7751/)
- [FFmpeg trac #9361 — av_read_frame infinite loop](https://trac.ffmpeg.org/ticket/9361)
- [Hoop.dev — FFmpeg Security Review](https://hoop.dev/blog/ffmpeg-security-review-risks-vulnerabilities-and-mitigation-strategies)
- [Hacker News — FFmpeg dealing with a security researcher (community context)](https://news.ycombinator.com/item?id=45785291)

### FFmpeg documentation & hardening references

- [FFmpeg main documentation](https://ffmpeg.org/ffmpeg.html)
- [FFmpeg protocols documentation](https://ffmpeg.org/ffmpeg-protocols.html)
- [FFmpeg formats documentation (concat demuxer `safe` option)](https://ffmpeg.org/ffmpeg-formats.html)
- [FFmpeg codecs documentation](https://ffmpeg.org/ffmpeg-codecs.html)
- [Yo1.dog — Fix for FFmpeg "protocol not on whitelist" error for HTTPS URLs](https://blog.yo1.dog/fix-for-ffmpeg-protocol-not-on-whitelist-error-for-urls/)
- [ffprobe documentation](https://ffmpeg.org/ffprobe.html)
- [Caduh — Safe File Uploads](https://www.caduh.com/blog/safe-file-uploads)

### Magic-byte detection & file-type spoofing

- [List of file signatures (Wikipedia)](https://en.wikipedia.org/wiki/List_of_file_signatures)
- [SecurityScientist — Masquerade File Type T1036.008](https://www.securityscientist.net/blog/12-questions-and-answers-about-masquerade-file-type-t1036-008/)
- [NetSPI — Magic Bytes: Identifying common file formats at a glance](https://www.netspi.com/blog/technical-blog/web-application-pentesting/magic-bytes-identifying-common-file-formats-at-a-glance/)
- [polyglot-generator (research tool)](https://github.com/Chessiie/polyglot-generator)

### Active Storage / Shrine / CarrierWave / Spatie / Django

- [Rails Active Storage Overview (video analyzer + previewer)](https://guides.rubyonrails.org/active_storage_overview.html)
- [rails/rails#39047 — VideoPreviewer should check ffmpeg presence](https://github.com/rails/rails/pull/39047)
- [ActiveStorage::Analyzer::VideoAnalyzer source](https://github.com/rails/rails/blob/main/activestorage/lib/active_storage/analyzer/video_analyzer.rb)
- [Schneems — Rails 5.2 Active Storage: previews, Poppler, AGPL licensing pitfalls](https://schneems.com/2018/05/11/rails-52-active-storage-previews-poppler-and-solving-licensing-pitfalls/)
- [Shrine processing docs](https://shrinerb.com/docs/processing)
- [Shrine atomic_helpers](https://shrinerb.com/docs/plugins/atomic_helpers)
- [Janko — Better File Uploads with Shrine: Processing](https://janko.io/better-file-uploads-with-shrine-processing/)
- [Martin Jarosinski — Video processing with Shrine and FFmpeg](https://www.martinjarosinski.com/posts/video-processing-with-shrine-and-ffmpeg/)
- [streamio-ffmpeg](https://github.com/streamio/streamio-ffmpeg)
- [carrierwave#1338 — closed stream error caused by temp file deletion](https://github.com/carrierwaveuploader/carrierwave/issues/1338)
- [carrierwave#1662 — ENOENT unless delete_tmp_file_after_storage = false](https://github.com/carrierwaveuploader/carrierwave/issues/1662)
- [carrierwave_backgrounder (last release 2015 — abandoned signal)](https://github.com/lardawge/carrierwave_backgrounder)
- [Spatie laravel-medialibrary defining conversions](https://spatie.be/docs/laravel-medialibrary/v11/converting-images/defining-conversions)
- [Spatie #604 — Converting video after saving](https://github.com/spatie/laravel-medialibrary/issues/604)
- [Spatie video image generator source](https://github.com/spatie/laravel-medialibrary/blob/main/src/Conversions/ImageGenerators/Video.php)
- [django-video-encoding (low/no maintenance)](https://github.com/escaped/django-video-encoding)
- [Snyk Advisor — django-video-encoding maintenance analysis](https://snyk.io/advisor/python/django-video-encoding)
- [django-ffmpeg](https://github.com/PixxxeL/django-ffmpeg)

### Mux / Cloudinary / imgproxy

- [Mux create direct upload API reference](https://www.mux.com/docs/api-reference/video/direct-uploads/create-direct-upload)
- [Mux upload files directly guide](https://www.mux.com/docs/guides/upload-files-directly)
- [Mux verify direct uploads with webhooks](https://www.mux.com/blog/verify-direct-uploads-with-mux-webhooks)
- [Mux webhook reference](https://www.mux.com/docs/webhook-reference)
- [Mux assets API reference](https://www.mux.com/docs/api-reference/video/assets)
- [Mux static MP4/M4A renditions](https://www.mux.com/docs/guides/enable-static-mp4-renditions)
- [Cloudinary transformation URL reference](https://cloudinary.com/documentation/transformation_reference)
- [Cloudinary named transformations tutorial](https://cloudinary.com/documentation/named_transformations_tutorial)
- [Cloudinary access control & strict transformations](https://cloudinary.com/documentation/control_access_to_media)
- [Cloudinary video transformations](https://cloudinary.com/documentation/video_manipulation_and_delivery)
- [imgproxy — Signing a URL](https://docs.imgproxy.net/usage/signing_url)
- [imgproxy alternatives benchmark](https://gist.github.com/DarthSim/9d971d2859f3714a29cf8ce094b3fc55)
- [Evil Martians — Introducing imgproxy](https://evilmartians.com/chronicles/introducing-imgproxy)

### Elixir-specific (Membrane, ports, subprocess discipline, Oban)

- [Membrane Framework get started](https://membrane.stream/learn/get_started_with_membrane)
- [Software Mansion — Elixir for multimedia: practical guide](https://swmansion.com/blog/elixir-for-multimedia-a-practical-guide-for-developers-169adb0eb523)
- [membrane_h264_ffmpeg_plugin](https://github.com/membraneframework/membrane_h264_ffmpeg_plugin)
- [Membrane core](https://github.com/membraneframework/membrane_core)
- [FFmpex — Elixir wrapper for FFmpeg CLI](https://github.com/talklittle/ffmpex)
- [Xav — Elixir wrapper over FFmpeg (decode-focused)](https://github.com/mickel8/xav)
- [Tony Cunningham — Managing external commands in Elixir with Ports](https://tonyc.github.io/posts/managing-external-commands-in-elixir-with-ports/)
- [Akash-akya — Video streaming in Elixir (port discipline)](https://akash-akya.github.io/posts/video-streaming-in-elixir/)
- [Elixir Port docs](https://hexdocs.pm/elixir/Port.html)
- [MuonTrap (Hunleth — Linux cgroup-attached subprocess)](https://github.com/fhunleth/muontrap)
- [Rambo (jayjun — cross-platform subprocess wrapper)](https://github.com/jayjun/rambo)
- [Porcelain #13 (terminate external processes cleanly — long-standing issue)](https://github.com/alco/porcelain/issues/13)
- [Erlang Forum — open_port and zombie processes](https://erlangforums.com/t/open-port-and-zombie-processes/3111)
- [The Missing Bit — Ensure no zombie process when esbuild started from Elixir](https://www.kuon.ch/post/2024-11-12-til-ensure-no-zombie/)
- [elixir-lang/elixir#9171 — Zombie process wrapper script does not exit](https://github.com/elixir-lang/elixir/issues/9171)
- [Oban Worker docs (timeout/1)](https://hexdocs.pm/oban/Oban.Worker.html)
- [Oban reliable scheduling](https://hexdocs.pm/oban/reliable-scheduling.html)
- [Oban Pro DynamicLifeline plugin](https://getoban.pro/docs/pro/0.13.1/Oban.Pro.Plugins.DynamicLifeline.html)
- [Broadway docs](https://hexdocs.pm/broadway/Broadway.html)
- [GenStage backpressure mechanism explained](https://dev.to/dcdourado/understanding-genstage-back-pressure-mechanism-1b0i)

### AWS Lambda / Fly.io / Heroku / GitHub Actions runtime constraints

- [serverlesspub/ffmpeg-aws-lambda-layer](https://github.com/serverlesspub/ffmpeg-aws-lambda-layer)
- [AWS — Processing user-generated content using AWS Lambda and FFmpeg](https://aws.amazon.com/blogs/media/processing-user-generated-content-using-aws-lambda-and-ffmpeg/)
- [Intoli — Running FFmpeg on AWS Lambda](https://intoli.com/blog/transcoding-on-aws-lambda/)
- [Fly.io community — Install FFmpeg in v2](https://community.fly.io/t/install-ffmpeg-in-the-v2/12130)
- [Phoenix on Fly.io getting started](https://fly.io/docs/elixir/getting-started/)
- [Phoenix Heroku deployment guide](https://hexdocs.pm/phoenix/heroku.html)
- [actions/runner-images Ubuntu 24.04 README](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md)
- [actions/runner-images Ubuntu 22.04 README](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2204-Readme.md)
- [FedericoCarboni/setup-ffmpeg (pinned-version GitHub Action)](https://github.com/FedericoCarboni/setup-ffmpeg)
- [actions/runner-images#1139 — Add ffmpeg](https://github.com/actions/runner-images/issues/1139)

### Disk pressure / ENOSPC / tmpfs

- [Frigate / blakeblackshear — ffmpeg processing issues: No space left on device](https://github.com/blakeblackshear/frigate/discussions/16986)
- [MythTV #12602 — lossless transcode that fills the disk loses tail of recording](https://code.mythtv.org/trac/ticket/12602)
- [Tdarr #645 — Transcode ffmpeg command fails on disk pressure](https://github.com/HaveAGitGat/Tdarr/issues/645)
- [Arch BBS — tmpfs running out of inodes ENOSPC](https://bbs.archlinux.org/viewtopic.php?id=272839)
- [Red Hat 1058512 — ENOSPC when there is plenty available (tmpfs and ext4)](https://bugzilla.redhat.com/show_bug.cgi?id=1058512)
