---
phase: 23-av-foundations
verified: 2026-05-05T22:45:00Z
status: passed
score: 5/5 success criteria verified
overrides_applied: 0
---

# Phase 23: AV Foundations - Verification

**Phase Goal:** Establish capability vocabulary, FFmpeg/FFprobe shim, MuonTrap subprocess discipline, boot probe, mix rindle.doctor, security argv hygiene, four-cap resource enforcement, and temp orphan reaper.

## Automated Verification

Run the entire test suite for the AV foundations phase to verify all unit and integration behaviors.

```bash
mix test test/rindle/av test/rindle/security/argv_test.exs test/rindle/doctor_test.exs test/rindle/processor/ffmpeg_test.exs test/rindle/ops/orphan_reaper_test.exs
```

### Specific Domain Checks

1. **Vocabulary & Argv Security (AV-CAP, AV-ARGV)**
   - `mix test test/rindle/av/capability_test.exs`: Confirms capability terms are properly defined and mapped.
   - `mix test test/rindle/security/argv_test.exs`: Confirms shell interpolation and invalid format strings are successfully stripped or blocked.

2. **MuonTrap & Four-Cap Subprocess Enforcement (AV-CMD)**
   - `mix test test/rindle/av/subprocess_test.exs`: Confirms:
     - `MuonTrap.cmd/3` is correctly wrapped.
     - Four-caps (`-t`, `-fs`, `-timelimit`, `timeout`) are injected into the args.
     - `-protocol_whitelist file,crypto,data` is hard-applied.
     - `cgroup` logic evaluates cleanly (whether activated on Linux or skipped gracefully on Mac).

3. **FFmpeg Adapter Integration (AV-CMD)**
   - `mix test test/rindle/processor/ffmpeg_test.exs`: Confirms the `Rindle.Processor` behaviour is satisfied and correctly calls the subprocess wrapper with validated CLI arguments.

4. **Environment Integrity & Boot Probe (AV-PROBE)**
   - `mix test test/rindle/av/probe_test.exs`: Confirms `ffmpeg` >= 6.0 validation string parsing.
   - `mix test test/rindle/doctor_test.exs`: Confirms the `mix rindle.doctor` task halts and reports appropriate outputs.

5. **FFprobe Shim & Orphan Reaper (AV-PROBE, AV-ORPHAN)**
   - `mix test test/rindle/av/ffprobe_test.exs`: Confirms metadata is extracted safely and treated as UGC.
   - `mix test test/rindle/ops/orphan_reaper_test.exs`: Confirms expired temporary files in `Rindle.tmp/` are correctly reaped.

## Manual/UAT Verification Checks

1. **mix rindle.doctor CLI Output**
   Run the CLI command manually in your environment:
   ```bash
   mix rindle.doctor
   ```
   **Expected Result:** The task evaluates the locally installed `ffmpeg` version. It should succeed silently (or with an info log) if `ffmpeg` >= 6.0 is present. If missing or older, it should cleanly exit with an error.

2. **Boot Probe Execution**
   Start an interactive Elixir session:
   ```bash
   iex -S mix
   ```
   **Expected Result:** Booting the application shouldn't crash if `ffmpeg` is properly installed, confirming `Rindle.AV.Probe.check_ffmpeg!/0` triggers and succeeds synchronously during boot sequence (if wired to application startup).

3. **Missing Dependency Simulation (Optional)**
   Temporarily rename or remove `ffmpeg` from your `PATH` and run `mix rindle.doctor` again.
   **Expected Result:** You should see a clear failure message indicating that FFmpeg could not be found, rather than a cryptic Erlang port crash.

## Security Gates Completed

- **Command Injection:** Prevented by `Rindle.Security.Argv` rejecting `;|&()$` characters and strict list formatting for args.
- **Decompression Bombs:** Defeated by four-cap resource limits.
- **SSRF:** Prevented via whitelist restrictions.
- **Zombie Processes:** Solved by delegating subprocess execution natively to MuonTrap.
- **Malicious Metadata:** FFprobe shim treats all extracted metadata as untrusted UGC.

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| AV-01-01 | 23-01 | AV capability vocabulary exists as a first-class processor namespace | ✓ SATISFIED | `23-01-SUMMARY.md` |
| AV-01-02 | 23-04 | `Rindle.Processor` AV adapter path compiles through the shared processor seam | ✓ SATISFIED | `23-04-SUMMARY.md` |
| AV-01-03 | 23-03 | FFmpeg probe runs and gates runtime/doctor behavior | ✓ SATISFIED | `23-03-SUMMARY.md` |
| AV-01-04 | 23-03 | Profile capability validation and fix-guidance path exists | ✓ SATISFIED | `23-03-SUMMARY.md` |
| AV-01-05 | 23-03 | `mix rindle.doctor` validates AV readiness and exits non-zero on failure | ✓ SATISFIED | `23-03-SUMMARY.md` |
| AV-01-06 | 23-02, 23-04, 23-05 | FFmpeg/FFprobe calls route through the guarded subprocess/adapter seam | ✓ SATISFIED | `23-02-SUMMARY.md`, `23-04-SUMMARY.md`, `23-05-SUMMARY.md` |
| AV-01-07 | 23-02 | Protocol whitelist and four-cap enforcement exist | ✓ SATISFIED | `23-02-SUMMARY.md` |
| AV-01-08 | 23-03 | FFmpeg >= 6.0 runtime/doctor gate exists | ✓ SATISFIED | `23-03-SUMMARY.md` |
| AV-01-09 | 23-01, 23-03 | AV capability discovery/reporting path exists for operators and CI | ✓ SATISFIED | `23-01-SUMMARY.md`, `23-03-SUMMARY.md` |
| AV-01-10 | 23-02 | Stock resource caps are enforced in the subprocess seam | ✓ SATISFIED | `23-02-SUMMARY.md` |

## Gaps Summary

No blocking gaps found. The phase already had verification prose and scoped checks; this update makes the requirements mapping explicit for the milestone audit.
