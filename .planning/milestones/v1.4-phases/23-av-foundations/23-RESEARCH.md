# Phase 23: AV Foundations - Research

**Researched:** 2024-05-02
**Domain:** External Subprocess Execution, Resource Capping, Security
**Confidence:** HIGH

<user_constraints>
## User Constraints

### Locked Decisions
- Phase 23: AV Foundations — Capability vocabulary, FFmpeg/FFprobe shim, MuonTrap subprocess discipline, boot probe, `mix rindle.doctor`, security argv hygiene, four-cap resource enforcement
- Security invariants for AV:
  - argv-array discipline (no shells, no string interpolation)
  - mandatory `-protocol_whitelist file,crypto,data`
  - four-cap enforcement (`-t` / `-fs` / `-timelimit` / external wall-clock)
  - MuonTrap-supervised subprocess with cgroup parent-death kill
  - sweepable `Rindle.tmp/` root with scheduled orphan reaper
  - FFmpeg minimum version 6.0 enforced at boot
  - HLS / DASH / MKV ingest explicitly rejected
  - container metadata treated as untrusted UGC
- Lock `Rindle.Processor.AV` over Membrane / NIFs / bundled providers based on cross-language peer-lib evidence.

### the agent's Discretion
- Module structure for AV capabilities and security boundaries based on existing analogs (e.g., `lib/rindle/security/argv.ex`).
- How to manage MuonTrap cgroup fallbacks on non-Linux OSes (macOS/Windows during development).

### Deferred Ideas (OUT OF SCOPE)
- N/A
</user_constraints>

## Summary

This phase establishes the foundational infrastructure to safely execute FFmpeg and FFprobe without risking system stability or exposing command injection vulnerabilities. We avoid Elixir NIFs (which can crash the VM) and Membrane (overkill for simple media wedge processing) in favor of isolated, closely monitored OS processes. 

The approach relies heavily on **MuonTrap** for process supervision and Linux `cgroups` for memory/CPU capping. Since `ffmpeg` can run away with system resources or execute arbitrary reads via malicious inputs, we implement strict `argv` hygiene (no string interpolation) and apply a "four-cap" limit: `-t` for duration, `-fs` for file size, `-timelimit` for CPU time, and a wall-clock timeout on the MuonTrap supervisor. A synchronous boot probe ensures FFmpeg >= 6.0 is present.

**Primary recommendation:** Use `MuonTrap.cmd/4` wrapped in a OS-aware shim (`lib/rindle/av/subprocess.ex`) that applies `cgroup_sets` on Linux but safely omits them on macOS/FreeBSD to ensure developer ergonomics.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Subprocess Lifecycle | Ops / Adapter | — | `MuonTrap` owns the process to prevent zombie `ffmpeg` processes if the Elixir parent crashes. |
| Resource Containment | Subprocess | OS (cgroups) | CPU and memory are aggressively clamped using Linux cgroups and FFmpeg's built-in flags. |
| AV Capability Vocabulary | Domain | — | Centralized atoms (`:video_transcode`, `:audio_normalize`, etc.) mirror `Rindle.Storage.Capabilities`. |
| Execution Security | Security | — | Argv string building and format validation (`lib/rindle/security/argv.ex`) prevents shell injection. |
| Environment Integrity | Mix Task / Ops | — | `mix rindle.doctor` and boot probes verify external dependencies (FFmpeg >= 6.0). |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `muontrap` | `~> 1.7` | Subprocess execution | Ensures orphaned processes are killed when the Elixir supervisor dies. Native cgroups support. |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `ffmpeg` | `>= 6.0` | CLI Binary | Used externally for video/audio manipulation. Not installed via Mix. |
| `ffprobe` | `>= 6.0` | CLI Binary | Used externally for inspecting media metadata. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `MuonTrap` | `System.cmd` | `System.cmd` leaks processes if the Elixir parent crashes (zombies). No native cgroup hooks. |
| External CLI | `membrane_core` | Too complex for simple transactional media wedge capabilities. Better suited for streaming topologies. |

**Installation:**
```bash
mix deps.add muontrap
```

*Version verification: `muontrap` `1.7.0` verified via Hex registry.*

## Architecture Patterns

### Recommended Project Structure
```text
lib/mix/tasks/rindle.doctor.ex       # User-facing environment check
lib/rindle/av/capability.ex          # Domain vocabulary for processing caps
lib/rindle/av/probe.ex               # Synchronous boot check logic
lib/rindle/av/subprocess.ex          # MuonTrap execution wrapper + 4-cap enforcement
lib/rindle/processor/ffmpeg.ex       # The processor adapter implementation
lib/rindle/security/argv.ex          # Argv sanitization and format validation
```

### Pattern 1: MuonTrap OS-Aware Cgroup Execution
**What:** Wrapping `MuonTrap.cmd/3` to apply cgroups only when running on Linux.
**When to use:** Whenever executing `ffmpeg` or `ffprobe`.
**Example:**
```elixir
defmodule Rindle.AV.Subprocess do
  @cgroup_base "rindle_av"

  def run(cmd, args, opts \\ []) do
    muon_opts = build_muon_opts(opts)
    MuonTrap.cmd(cmd, args, muon_opts)
  end

  defp build_muon_opts(opts) do
    base = [into: "", stderr_to_stdout: true]
    
    if :os.type() == {:unix, :linux} and Keyword.get(opts, :use_cgroups, true) do
      # Calculate memory limits and cpu quotas
      cgroup_sets = [
        {"memory", "memory.limit_in_bytes", "536870912"},
        {"cpu", "cpu.cfs_period_us", "100000"},
        {"cpu", "cpu.cfs_quota_us", "50000"}
      ]
      
      base ++ [
        cgroup_controllers: ["memory", "cpu"],
        cgroup_base: @cgroup_base,
        cgroup_sets: cgroup_sets
      ]
    else
      base
    end
  end
end
```

### Pattern 2: Four-Cap Resource Enforcement
**What:** Layered defense against abusive media files (decompression bombs, infinite streams).
**When to use:** Generating arguments for `ffmpeg`.
**Example:**
```elixir
def build_ffmpeg_args(input, output) do
  [
    "-protocol_whitelist", "file,crypto,data",
    "-timelimit", "120",   # Cap 1: Max 120s of CPU time
    "-t", "300",           # Cap 2: Max 5 minutes of input media duration
    "-i", input,
    "-fs", "50000000",     # Cap 3: Max 50MB output file size
    output
  ]
  # Cap 4 (Wall-clock) is handled by passing `timeout: 120_000` to MuonTrap.cmd
end
```

### Anti-Patterns to Avoid
- **String Interpolation for Commands:** Never use `"ffmpeg -i #{user_input}"`. Always use list arguments `["-i", user_input]` to bypass the shell and prevent command injection.
- **Missing Protocol Whitelist:** `ffmpeg` supports HTTP, FTP, and other protocols. If `-protocol_whitelist` is omitted, malicious metadata (like HLS playlists) can force `ffmpeg` to make SSRF requests.
- **Assuming Cgroups on Mac:** Attempting to configure `cgcreate` or cgroup sets via MuonTrap on macOS will crash the command. Always check `:os.type()`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Subprocess supervision | GenServer wrapper around `Port` | `MuonTrap` | Port doesn't handle SIGKILL propagation accurately, leading to zombie FFmpeg processes on VM crash. |
| CPU/Mem limits | OS process tracking / Polling | Linux `cgroups` | Cgroups are enforced natively by the kernel. Userland polling is too slow and can miss spikes. |
| FFmpeg versions | Regex-parsing `-help` | `rindle.doctor` task | Use `-version` parsing strictly and centralize it in `Rindle.AV.Probe`. |

## Common Pitfalls

### Pitfall 1: Ghost FFmpeg Processes
**What goes wrong:** Elixir application restarts or crashes, leaving `ffmpeg` running in the background at 100% CPU.
**Why it happens:** Using standard `System.cmd` or raw `Port` without proper termination propagation.
**How to avoid:** Always use `MuonTrap`, which spawns a lightweight C wrapper to guarantee the child process dies when the port closes.

### Pitfall 2: SSRF via External Formats
**What goes wrong:** A user uploads a malicious text file with a `.avi` extension containing HLS playlist URLs pointing to AWS internal IP `169.254.169.254`. FFmpeg attempts to download it.
**Why it happens:** FFmpeg parses playlists and protocols automatically.
**How to avoid:** Reject MKV/HLS/DASH outright (`lib/rindle/security/argv.ex`) and strictly enforce `-protocol_whitelist file,crypto,data`.

## Code Examples

### Boot Probe & Rindle.Doctor Logic
```elixir
# Source: Custom derivation based on FFmpeg CLI parsing standard
defmodule Rindle.AV.Probe do
  def check_ffmpeg! do
    case System.cmd("ffmpeg", ["-version"]) do
      {output, 0} ->
        case Regex.run(~r/ffmpeg version (\d+\.\d+)/, output) do
          [_, version] ->
            if Version.compare(version <> ".0", "6.0.0") == :lt do
              raise "Rindle requires FFmpeg >= 6.0, found: #{version}"
            end
            :ok
          _ -> raise "Could not parse FFmpeg version."
        end
      _ ->
        raise "FFmpeg is not installed or not in PATH."
    end
  end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `System.cmd` / Ports | `MuonTrap` | ~Elixir 1.8+ era | Process trees are natively cleaned up; zombies eliminated. |
| Hand-written limits | Kernel `cgroups` | Modern Linux | Strict kernel-level cutoff for memory instead of app-level crashing. |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `muontrap` 1.7.0 is compatible with Elixir 1.15+ and the target platforms | Standard Stack | [LOW] If incompatible, we'll need to drop down to older versions, but 1.7 is standard. |
| A2 | Cgroups will fail on macOS | Patterns | [MEDIUM] If MuonTrap doesn't swallow cgroup errors gracefully, development on Mac will fail unless explicitly disabled. |

## Open Questions

1. **Cgroups permissions**
   - What we know: Cgroups require system configuration (`cgcreate` or systemd).
   - What's unclear: Does the target deployment environment (e.g., Docker, fly.io, Heroku) allow the Rindle application to create or attach to cgroups?
   - Recommendation: Ensure `use_cgroups` is configurable or gracefully falls back to non-cgroup execution if cgroups are unavailable or lack permissions.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `ffmpeg` | Subprocess processing | ✓ | 8.0.1 (local) | — (Boot probe will halt) |
| `ffprobe` | Media metadata extraction | ✓ | 8.0.1 (local) | — (Boot probe will halt) |
| `cgroups` | MuonTrap resource capping | ✗ (macOS) | — | Fallback to wall-clock / timeout without hard memory limit |

**Missing dependencies with no fallback:**
- `ffmpeg` and `ffprobe` (Must be installed on the host OS).

**Missing dependencies with fallback:**
- Linux cgroups (macOS development environment uses fallback).

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit |
| Config file | `mix.exs` |
| Quick run command | `mix test` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AV-CAP | Defines capability vocabulary | unit | `mix test test/rindle/av/capability_test.exs` | ❌ |
| AV-PROBE | Halts if ffmpeg < 6.0 | unit | `mix test test/rindle/av/probe_test.exs` | ❌ |
| AV-ARGV | Strips shell injection / enforces whitelist | unit | `mix test test/rindle/security/argv_test.exs` | ❌ |
| AV-CMD | Four-cap enforcement in args | unit | `mix test test/rindle/av/subprocess_test.exs` | ❌ |

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | yes | `lib/rindle/security/argv.ex` string validation, avoiding shell interpolation. |
| V6 Cryptography | no | — |

### Known Threat Patterns for External Subprocesses

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Command Injection | Tampering / Elevation | Use exact list-based `exec` arguments, avoiding shell (`/bin/sh -c`). |
| Server Side Request Forgery (SSRF) | Information Disclosure | `-protocol_whitelist file,crypto,data` on all FFmpeg commands. |
| Resource Exhaustion (Decompression Bomb) | Denial of Service | Four-cap enforcement: `-fs`, `-t`, `-timelimit`, and cgroups memory/cpu limit. |
| Zombie Processes | Denial of Service | MuonTrap parent-death SIGKILL propagation. |

## Sources

### Primary (HIGH confidence)
- `/fhunleth/muontrap` - `muontrap` documentation and cgroups configuration via Context7.
- `ffmpeg` CLI documentation - Validated `-timelimit`, `-fs`, and `-protocol_whitelist` via `ffmpeg -h full`.
- `.planning/PROJECT.md` - Verified 13 security invariants and phase roadmap requirements.

### Secondary (MEDIUM confidence)
- N/A

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - `muontrap` is the de facto standard in Elixir for containing untrusted C binaries.
- Architecture: HIGH - Closely follows established patterns from `rindle.verify_storage` and `rindle/security/filename.ex`.
- Pitfalls: HIGH - Well-known FFmpeg CVE classes (SSRF via HLS, infinite loops) are mitigated by the four-cap design.

**Research date:** 2024-05-02
**Valid until:** 2025-05-02
