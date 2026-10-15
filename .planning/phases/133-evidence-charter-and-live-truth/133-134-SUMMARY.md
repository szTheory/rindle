---
phase: 133-evidence-charter-and-live-truth
plan: "134"
subsystem: testing
tags: [node, hex, one-shot-authority, immutable-evidence]
requires:
  - phase: 133-141
    provides: Authenticated committed true Plan 140 compatibility and portable readiness
provides:
  - Committed offline-observed exact mux preflight with live input and cache identities
  - Zero-request post-publication fixture failure evidence and a tested unapplied repair proposal
affects: [133-136, 133-129, evidence-charter-and-live-truth]
actuals:
  tokens: 33981
  tasks: 0
  commits: 3
plan_head_before: d8f338c523764295d711069c93f6633e03aece8b
plan_head_after: 1eb9d5edfb75125e5daeab32a2873df2c9eecc44
tech-stack:
  added: []
  patterns: [Digest-bound exclusive authority, guarded offline route observation, immutable post-freeze failure]
key-files:
  created:
    - .planning/phases/133-evidence-charter-and-live-truth/133-134-RED.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-134-REGISTRY-PREFLIGHT.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-134-POST-FREEZE-VERIFICATION.json
    - .planning/phases/133-evidence-charter-and-live-truth/133-134-SUMMARY.md
  modified:
    - scripts/maintainer/phase_133_registry_supply.mjs
    - test/install_smoke/phase_133_registry_supply_test.mjs
key-decisions:
  - "Preserve the existing RED commit and interrupted implementation; resume without resetting or recreating work."
  - "Seatbelt restricts outbound ports; the committed adapter restricts the exact URL and disables redirects."
  - "Do not modify frozen test bytes or replace the preflight after a post-publication acceptance failure."
  - "Withhold the Task 2 authorization question until executable Task 1 acceptance passes under a valid frozen tuple."
requirements-completed: []
requirements-addressed: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
requirements_pending: [EVID-01, EVID-02, EVID-03, EVID-04, TRUTH-08]
coverage:
  - id: D1
    description: The committed preflight authenticates readiness, live inputs, the actual offline Hex route and the exact tuple without granting request authority.
    verification:
      - kind: other
        ref: "node scripts/maintainer/phase_133_registry_supply.mjs verify-preflight --plan 133-134 --preflight .planning/phases/133-evidence-charter-and-live-truth/133-134-REGISTRY-PREFLIGHT.json"
        status: pass
      - kind: other
        ref: "node scripts/maintainer/phase_133_compatibility_bridge_141.mjs verify-readiness --root . --report .planning/phases/133-evidence-charter-and-live-truth/133-141-READINESS.json"
        status: pass
      - kind: other
        ref: "./scripts/maintainer/automation_first_contract.sh"
        status: pass
    human_judgment: false
duration: 106min
completed: 2026-10-09
status: halted
halt_reason: post_freeze_fixture_failure
current_task: 1
readiness_status: compatible
preflight_status: frozen
authorization_status: absent
authorization_count: 0
network_request_count: 0
qualification_credit: 0
unresolved_edge_rows: 11
preflight_sha256: c3ce495744c63cad3459babec573a1d15079acd38eb14c8aae3b6f0fc57cb8b0
stop_evidence_sha256: 980e7fa8ef577603351bada9f3690a12f8dbacead8fefd0d389c743be60e8872
---

# Phase 133 Plan 134: Compatibility-Gated Mux Preflight and Verification Halt

**The exact mux preflight is committed and production-verifiable, but a copied-checkout fixture fails after publication; execution stops before the human authorization gate with zero requests.**

## Performance

- **Elapsed duration:** 106 min, including the orchestrator interruption.
- **Started:** 2026-10-09T15:36:52Z (preserved RED commit time).
- **Stopped:** 2026-10-09T17:23:37Z.
- **Tasks fully accepted:** 0/3. Task 1 implementation and freeze are committed; its post-publication acceptance is incomplete.
- **Files modified:** 6, including this summary and the failure evidence.
- **Actuals scope:** tokens are chars/4 over the realized committed diff before this metadata commit. Commit count is measured from the preserved ledger before this metadata commit.

## Accomplishments

- Preserved RED commit `4237a7688032802ccd7bd246b79f688fb74b6bbe` and its actual intentional-failure record. The existing evidence classifier returned `RED_EVIDENCE_OK`; RED was neither rerun nor recommitted.
- Completed the interrupted production implementation, including canonical committed history and live byte checks, fresh literal authority, durable no-clobber markers, a single bounded signed-origin request path, lock matching, restarted offline readback and independent outcome validation. Historical reports remain unchanged.
- The 24-test suite passed before the freeze. Both actual-host guards passed their non-network control (0) and loopback policy-denial probe (77, EPERM). The actual supported Hex build observed `https://repo.hex.pm/packages/mux` using the offline adapter, with zero network requests.
- Published and committed the exact preflight digest `c3ce495744c63cad3459babec573a1d15079acd38eb14c8aae3b6f0fc57cb8b0`. Production readiness and preflight verifiers pass against current committed and live bytes.
- Detected and preserved a post-publication fixture failure. The repair proposal passes all 24 tests in a disposable copy and remains unapplied.

## Task Commits

1. **Task 1 RED, preserved:** `4237a768` — `test(133-134): require compatibility-gated exact mux request`.
2. **Task 1 GREEN, before freeze:** `4a7d2b9a` — `feat(133-134): implement compatibility-gated exact mux supply`.
3. **Task 1 preflight:** `1eb9d5ed` — `docs(133-134): freeze verified exact mux preflight`.

Failure evidence and this halted summary are committed together as plan metadata. Task 1 remains incomplete because the latest whole-suite run fails; Tasks 2 and 3 did not run.

## Verification

| Check | Latest result |
|---|---|
| Existing committed RED evidence classifier | PASS: RED_EVIDENCE_OK |
| Full suite before preflight publication | PASS: 24/24 |
| Full suite after preflight publication | FAIL: 23/24 |
| Focused reproduction of post-publication fixture | FAIL: expected false, actual true at test line 239 |
| Tested fixture repair in disposable copy | PASS: 24/24; proposal only |
| Plan 141 production readiness | PASS |
| Plan 134 production readiness | PASS |
| Plan 134 production preflight | PASS |
| Actual offline Hex route observation | PASS: child exit 0; zero requests |
| Offline and scoped host guard controls | PASS: controls 0; denied probes 77/EPERM |
| Node syntax and git diff checks | PASS |
| Automation-first contract | PASS |
| Task 2 authorization / Task 3 supply | NOT EXECUTED: Task 1 acceptance fails |

The isolated proposal does not override the failed current-worktree acceptance result.

## Exact Stop and Frozen Identity

- **Failure file SHA-256:** `980e7fa8ef577603351bada9f3690a12f8dbacead8fefd0d389c743be60e8872`.
- **Plan 141 readiness receipt:** `8d67fcf2ea08ec003fc12260c1d2b4ccee6dee3b5625104387d50c25cf7de05b`.
- **Plan 140 compatibility report:** `01c3eaf2a2049941323a19a1662f10e6cdb0498eaa7ad7a384ccbe86dd924cee`.
- **Plan 140 preflight canonical digest:** `1220fc449571f043729428c758d85cd34c704fe581ec4f0988b7ffa9fee0e9bd`.
- **Plan 140 preflight raw SHA-256:** `35cec1f00d30122ed13f9388e50d5de605b34a7fe34c3a80cdf241deb08686c0`.
- **Official Hex source commit/tree:** `a43131c26aeca06064959297d737991163f5ac5d` / `778c9a1387d22da9ea8830d1f02b84c9f7402c7d`.
- **Source inventory SHA-256:** `6f0ce86d4b0ea19fe588b9192dd9645aada1ad9ccdaa7f0519efbb453b8da682`.
- **BEAM inventory SHA-256:** `4a696c31960594df6588dc921149208310c896ecb8d973904959f547b4c6b913`.
- **Runtime inventory SHA-256:** `9afec346e4b0c3a6fc2202abca5b327c827a64c748168a2a431dbcd2b54884c9`.
- **Source receipt inventory SHA-256:** `b7c7c176c83487b71fe551db9161f26380fe9c8ea464595a0120f684afb577e1`.
- **Mux lock inner:** `3d5f86a173b646f4c675bf7cc817bb010a1fde4fdb3ecfdd56a374a039e8db58`.
- **Mux lock outer:** `103a8dd092066eae17b0116cac87fbbb9cf60574f88387bf030500503dc64be9`.
- **Actual cache baseline:** `23e3d46ec2f5d1055b0955a1ad7dbc7fb0c5ba26fe436658f08537a4650d9741`; unchanged at stop.
- **Authority:** authorization, request-started, retrieval and supply files and the signed object are absent.
- **Credit:** zero; all five IDs are Pending and all eleven rows unresolved. Plan 129 remains blocked.
- **Shared artifacts:** STATE.md, ROADMAP.md, REQUIREMENTS.md and historical evidence were not modified.

The full literal frozen tuple follows. It is preserved for review; **no authorization question was issued for it**.

```json
{
  "method": "GET",
  "url": "https://repo.hex.pm/packages/mux",
  "repo": "hexpm",
  "package": "mux",
  "version": "3.2.2",
  "ebin": "/private/tmp/rindle-phase133-hex-v2.5.1-a43131c26aeca06064959297d737991163f5ac5d-build-p140/_build/lib/hex/ebin",
  "cache_key": [
    "versions",
    "hexpm",
    "mux"
  ],
  "cache_destination": "/Users/jon/.hex/cache.ets",
  "cache_baseline_sha256": "23e3d46ec2f5d1055b0955a1ad7dbc7fb0c5ba26fe436658f08537a4650d9741",
  "object": "/private/tmp/rindle-phase133-mux-134.signed.gz",
  "route": {
    "argv": [
      "/Users/jon/.asdf/installs/elixir/1.17.3-otp-27/bin/elixir",
      "-pa",
      "/private/tmp/rindle-phase133-hex-v2.5.1-a43131c26aeca06064959297d737991163f5ac5d-build-p140/_build/lib/hex/ebin",
      "-e",
      "\ndefmodule Phase134HTTP do\n  def request(:get, \"https://repo.hex.pm/packages/mux\" = url, headers, body, opts) do\n    if Process.get(:mux_requests, 0) != 0, do: raise(\"second request refused\")\n    Process.put(:mux_requests, 1)\n    IO.puts(\"MUX_REQUEST_STARTED\")\n    result = apply(:mix_hex_http_httpc, :request, [:get, url, headers, body, opts])\n    case result do\n      {:ok, {200, _, signed}} when byte_size(signed) <= 8_388_608 ->\n        File.write!(Process.get(:object_path), signed, [:exclusive])\n      _ -> :ok\n    end\n    result\n  end\nend\ndefmodule Phase134Route do\n  def request(:get, url, _headers, _body, _opts) do\n    Process.put(:observed_url, url)\n    {:error, :offline_route_probe}\n  end\nend\n[stage, preflight_path] = System.argv()\np = preflight_path |> File.read!() |> :json.decode()\nt = p[\"tuple\"]\notp = :erlang.system_info(:otp_release) |> to_string()\npatch = Path.join([to_string(:code.root_dir()), \"releases\", otp, \"OTP_VERSION\"]) |> File.read!() |> String.trim()\nunless System.version() == \"1.17.3\" and patch == \"27.3.4.15\", do: raise(\"unsupported runtime\")\n{:module, _} = Code.ensure_loaded(Hex.Registry.Server)\nbeam = :code.which(Hex.Registry.Server) |> to_string() |> Path.expand()\nunless beam == Path.join(t[\"ebin\"], \"Elixir.Hex.Registry.Server.beam\"), do: raise(\"foreign Hex BEAM\")\n:ok = Application.load(:hex)\n{:ok, hex} = :application.get_key(:hex, :vsn)\nunless to_string(hex) == \"2.5.1\", do: raise(\"wrong Hex version\")\n{:ok, _} = Application.ensure_all_started(:ssl)\n{:ok, _} = Application.ensure_all_started(:inets)\nconfig = apply(:mix_hex_core, :default_config, [])\nunless config.repo_url == \"https://repo.hex.pm\" and config.repo_name == \"hexpm\" and\n         config.repo_verify and config.repo_verify_origin, do: raise(\"unexpected Hex origin contract\")\nhash = fn data -> :crypto.hash(:sha256, data) |> Base.encode16(case: :lower) end\nresult = if stage == \"route\" do\n  {:error, :offline_route_probe} = apply(:mix_hex_repo, :get_package, [%{config | http_adapter: {Phase134Route, %{}}}, \"mux\"])\n  unless Process.get(:observed_url) == t[\"url\"], do: raise(\"observed request route differs\")\n  %{stage: stage, url: Process.get(:observed_url), network_request_count: 0, elixir: System.version(),\n    otp_patch: patch, hex: to_string(hex), public_key_sha256: hash.(config.repo_public_key)}\nelse\n  if System.get_env(\"HEX_OFFLINE\") != \"1\" or System.get_env(\"HEX_UNSAFE_REGISTRY\") != \"0\" or\n       System.get_env(\"HEX_NO_VERIFY_REPO_ORIGIN\") != \"0\", do: raise(\"unsafe environment\")\n  signed = if stage == \"request\" do\n    Process.put(:object_path, t[\"object\"])\n    tls = [verify: :verify_peer, cacerts: :public_key.cacerts_get(), depth: 3,\n      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]]\n    adapter = {Phase134HTTP, %{http_options: [ssl: tls, autoredirect: false, timeout: 15_000, connect_timeout: 10_000]}}\n    {:ok, {200, _, _}} = apply(:mix_hex_repo, :get_package, [%{config | http_adapter: adapter}, \"mux\"])\n    File.read!(t[\"object\"])\n  else\n    File.read!(t[\"object\"])\n  end\n  {:ok, record} = apply(:mix_hex_registry, :unpack_package, [signed, \"hexpm\", \"mux\", config.repo_public_key])\n  unless record.repository == \"hexpm\" and record.name == \"mux\", do: raise(\"registry origin mismatch\")\n  [release] = Enum.filter(record.releases, &(&1.version == \"3.2.2\"))\n  inner = Base.encode16(release.inner_checksum, case: :lower)\n  outer = Base.encode16(release.outer_checksum, case: :lower)\n  unless inner == p[\"lock\"][\"inner_sha256\"] and outer == p[\"lock\"][\"outer_sha256\"], do: raise(\"lock mismatch\")\n  before = File.read!(t[\"cache_destination\"]) |> hash.()\n  Mix.start()\n  {:ok, _} = apply(Hex.State, :start_link, [[]])\n  apply(Hex.State, :put, [:repos, %{\"hexpm\" => apply(Hex.Repo, :default_hexpm_repo, [])}])\n  unless apply(Hex.State, :fetch!, [:offline]) and not apply(Hex.State, :fetch!, [:unsafe_registry]) and\n           not apply(Hex.State, :fetch!, [:no_verify_repo_origin]), do: raise(\"Hex safety state differs\")\n  {:ok, _} = apply(Hex.Registry.Server, :start_link, [[]])\n  :ok = apply(Hex.Registry.Server, :open, [[registry_path: t[\"cache_destination\"], check_version: false]])\n  if stage == \"request\" do\n    send(Hex.Registry.Server, {:get_package, \"hexpm\", \"mux\", {:ok, {200, %{}, record}}})\n    :ok = apply(Hex.Registry.Server, :persist, [])\n  end\n  :ok = apply(Hex.Registry.Server, :prefetch, [[{\"hexpm\", \"mux\"}]])\n  cached_inner = apply(Hex.Registry.Server, :inner_checksum, [\"hexpm\", \"mux\", \"3.2.2\"]) |> Base.encode16(case: :lower)\n  cached_outer = apply(Hex.Registry.Server, :outer_checksum, [\"hexpm\", \"mux\", \"3.2.2\"]) |> Base.encode16(case: :lower)\n  unless cached_inner == inner and cached_outer == outer, do: raise(\"offline cache mismatch\")\n  after_hash = File.read!(t[\"cache_destination\"]) |> hash.()\n  if stage == \"read\" and before != after_hash, do: raise(\"offline read modified cache\")\n  %{stage: stage, url: t[\"url\"], network_request_count: Process.get(:mux_requests, 0), elixir: System.version(),\n    otp_patch: patch, hex: to_string(hex), os_pid: System.pid(), signature_verified: true, origin_verified: true,\n    inner_sha256: inner, outer_sha256: outer, object_sha256: hash.(signed), public_key_sha256: hash.(config.repo_public_key),\n    cache_before: before, cache_sha256: after_hash, offline: true, persisted: stage == \"request\", restarted: stage == \"read\"}\nend\nIO.puts(\"MUX_PROOF \" <> (:json.encode(result) |> IO.iodata_to_binary()))\n",
      "--",
      "route",
      "/Users/jon/projects/rindle/.claude/worktrees/agent-p134-escalated-1791560070/.planning/phases/133-evidence-charter-and-live-truth/133-134-REGISTRY-PREFLIGHT.json"
    ],
    "cwd": "/Users/jon/projects/rindle/.claude/worktrees/agent-p134-escalated-1791560070",
    "environment": {
      "PATH": "/Users/jon/.asdf/installs/elixir/1.17.3-otp-27/bin:/Users/jon/.asdf/installs/erlang/27.3.4.15/bin:/usr/bin:/bin",
      "HOME": "/Users/jon",
      "HEX_HOME": "/Users/jon/.hex",
      "HEX_OFFLINE": "1",
      "HEX_UNSAFE_REGISTRY": "0",
      "HEX_NO_VERIFY_REPO_ORIGIN": "0",
      "MIX_ARCHIVES": "/private/tmp/rindle-phase133-no-global-archives",
      "ERL_CRASH_DUMP": "/private/tmp/rindle-phase133-134-erl-crash.dump"
    }
  },
  "request": {
    "argv": [
      "/Users/jon/.asdf/installs/elixir/1.17.3-otp-27/bin/elixir",
      "-pa",
      "/private/tmp/rindle-phase133-hex-v2.5.1-a43131c26aeca06064959297d737991163f5ac5d-build-p140/_build/lib/hex/ebin",
      "-e",
      "\ndefmodule Phase134HTTP do\n  def request(:get, \"https://repo.hex.pm/packages/mux\" = url, headers, body, opts) do\n    if Process.get(:mux_requests, 0) != 0, do: raise(\"second request refused\")\n    Process.put(:mux_requests, 1)\n    IO.puts(\"MUX_REQUEST_STARTED\")\n    result = apply(:mix_hex_http_httpc, :request, [:get, url, headers, body, opts])\n    case result do\n      {:ok, {200, _, signed}} when byte_size(signed) <= 8_388_608 ->\n        File.write!(Process.get(:object_path), signed, [:exclusive])\n      _ -> :ok\n    end\n    result\n  end\nend\ndefmodule Phase134Route do\n  def request(:get, url, _headers, _body, _opts) do\n    Process.put(:observed_url, url)\n    {:error, :offline_route_probe}\n  end\nend\n[stage, preflight_path] = System.argv()\np = preflight_path |> File.read!() |> :json.decode()\nt = p[\"tuple\"]\notp = :erlang.system_info(:otp_release) |> to_string()\npatch = Path.join([to_string(:code.root_dir()), \"releases\", otp, \"OTP_VERSION\"]) |> File.read!() |> String.trim()\nunless System.version() == \"1.17.3\" and patch == \"27.3.4.15\", do: raise(\"unsupported runtime\")\n{:module, _} = Code.ensure_loaded(Hex.Registry.Server)\nbeam = :code.which(Hex.Registry.Server) |> to_string() |> Path.expand()\nunless beam == Path.join(t[\"ebin\"], \"Elixir.Hex.Registry.Server.beam\"), do: raise(\"foreign Hex BEAM\")\n:ok = Application.load(:hex)\n{:ok, hex} = :application.get_key(:hex, :vsn)\nunless to_string(hex) == \"2.5.1\", do: raise(\"wrong Hex version\")\n{:ok, _} = Application.ensure_all_started(:ssl)\n{:ok, _} = Application.ensure_all_started(:inets)\nconfig = apply(:mix_hex_core, :default_config, [])\nunless config.repo_url == \"https://repo.hex.pm\" and config.repo_name == \"hexpm\" and\n         config.repo_verify and config.repo_verify_origin, do: raise(\"unexpected Hex origin contract\")\nhash = fn data -> :crypto.hash(:sha256, data) |> Base.encode16(case: :lower) end\nresult = if stage == \"route\" do\n  {:error, :offline_route_probe} = apply(:mix_hex_repo, :get_package, [%{config | http_adapter: {Phase134Route, %{}}}, \"mux\"])\n  unless Process.get(:observed_url) == t[\"url\"], do: raise(\"observed request route differs\")\n  %{stage: stage, url: Process.get(:observed_url), network_request_count: 0, elixir: System.version(),\n    otp_patch: patch, hex: to_string(hex), public_key_sha256: hash.(config.repo_public_key)}\nelse\n  if System.get_env(\"HEX_OFFLINE\") != \"1\" or System.get_env(\"HEX_UNSAFE_REGISTRY\") != \"0\" or\n       System.get_env(\"HEX_NO_VERIFY_REPO_ORIGIN\") != \"0\", do: raise(\"unsafe environment\")\n  signed = if stage == \"request\" do\n    Process.put(:object_path, t[\"object\"])\n    tls = [verify: :verify_peer, cacerts: :public_key.cacerts_get(), depth: 3,\n      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]]\n    adapter = {Phase134HTTP, %{http_options: [ssl: tls, autoredirect: false, timeout: 15_000, connect_timeout: 10_000]}}\n    {:ok, {200, _, _}} = apply(:mix_hex_repo, :get_package, [%{config | http_adapter: adapter}, \"mux\"])\n    File.read!(t[\"object\"])\n  else\n    File.read!(t[\"object\"])\n  end\n  {:ok, record} = apply(:mix_hex_registry, :unpack_package, [signed, \"hexpm\", \"mux\", config.repo_public_key])\n  unless record.repository == \"hexpm\" and record.name == \"mux\", do: raise(\"registry origin mismatch\")\n  [release] = Enum.filter(record.releases, &(&1.version == \"3.2.2\"))\n  inner = Base.encode16(release.inner_checksum, case: :lower)\n  outer = Base.encode16(release.outer_checksum, case: :lower)\n  unless inner == p[\"lock\"][\"inner_sha256\"] and outer == p[\"lock\"][\"outer_sha256\"], do: raise(\"lock mismatch\")\n  before = File.read!(t[\"cache_destination\"]) |> hash.()\n  Mix.start()\n  {:ok, _} = apply(Hex.State, :start_link, [[]])\n  apply(Hex.State, :put, [:repos, %{\"hexpm\" => apply(Hex.Repo, :default_hexpm_repo, [])}])\n  unless apply(Hex.State, :fetch!, [:offline]) and not apply(Hex.State, :fetch!, [:unsafe_registry]) and\n           not apply(Hex.State, :fetch!, [:no_verify_repo_origin]), do: raise(\"Hex safety state differs\")\n  {:ok, _} = apply(Hex.Registry.Server, :start_link, [[]])\n  :ok = apply(Hex.Registry.Server, :open, [[registry_path: t[\"cache_destination\"], check_version: false]])\n  if stage == \"request\" do\n    send(Hex.Registry.Server, {:get_package, \"hexpm\", \"mux\", {:ok, {200, %{}, record}}})\n    :ok = apply(Hex.Registry.Server, :persist, [])\n  end\n  :ok = apply(Hex.Registry.Server, :prefetch, [[{\"hexpm\", \"mux\"}]])\n  cached_inner = apply(Hex.Registry.Server, :inner_checksum, [\"hexpm\", \"mux\", \"3.2.2\"]) |> Base.encode16(case: :lower)\n  cached_outer = apply(Hex.Registry.Server, :outer_checksum, [\"hexpm\", \"mux\", \"3.2.2\"]) |> Base.encode16(case: :lower)\n  unless cached_inner == inner and cached_outer == outer, do: raise(\"offline cache mismatch\")\n  after_hash = File.read!(t[\"cache_destination\"]) |> hash.()\n  if stage == \"read\" and before != after_hash, do: raise(\"offline read modified cache\")\n  %{stage: stage, url: t[\"url\"], network_request_count: Process.get(:mux_requests, 0), elixir: System.version(),\n    otp_patch: patch, hex: to_string(hex), os_pid: System.pid(), signature_verified: true, origin_verified: true,\n    inner_sha256: inner, outer_sha256: outer, object_sha256: hash.(signed), public_key_sha256: hash.(config.repo_public_key),\n    cache_before: before, cache_sha256: after_hash, offline: true, persisted: stage == \"request\", restarted: stage == \"read\"}\nend\nIO.puts(\"MUX_PROOF \" <> (:json.encode(result) |> IO.iodata_to_binary()))\n",
      "--",
      "request",
      "/Users/jon/projects/rindle/.claude/worktrees/agent-p134-escalated-1791560070/.planning/phases/133-evidence-charter-and-live-truth/133-134-REGISTRY-PREFLIGHT.json"
    ],
    "cwd": "/Users/jon/projects/rindle/.claude/worktrees/agent-p134-escalated-1791560070",
    "environment": {
      "PATH": "/Users/jon/.asdf/installs/elixir/1.17.3-otp-27/bin:/Users/jon/.asdf/installs/erlang/27.3.4.15/bin:/usr/bin:/bin",
      "HOME": "/Users/jon",
      "HEX_HOME": "/Users/jon/.hex",
      "HEX_OFFLINE": "1",
      "HEX_UNSAFE_REGISTRY": "0",
      "HEX_NO_VERIFY_REPO_ORIGIN": "0",
      "MIX_ARCHIVES": "/private/tmp/rindle-phase133-no-global-archives",
      "ERL_CRASH_DUMP": "/private/tmp/rindle-phase133-134-erl-crash.dump"
    }
  },
  "read": {
    "argv": [
      "/Users/jon/.asdf/installs/elixir/1.17.3-otp-27/bin/elixir",
      "-pa",
      "/private/tmp/rindle-phase133-hex-v2.5.1-a43131c26aeca06064959297d737991163f5ac5d-build-p140/_build/lib/hex/ebin",
      "-e",
      "\ndefmodule Phase134HTTP do\n  def request(:get, \"https://repo.hex.pm/packages/mux\" = url, headers, body, opts) do\n    if Process.get(:mux_requests, 0) != 0, do: raise(\"second request refused\")\n    Process.put(:mux_requests, 1)\n    IO.puts(\"MUX_REQUEST_STARTED\")\n    result = apply(:mix_hex_http_httpc, :request, [:get, url, headers, body, opts])\n    case result do\n      {:ok, {200, _, signed}} when byte_size(signed) <= 8_388_608 ->\n        File.write!(Process.get(:object_path), signed, [:exclusive])\n      _ -> :ok\n    end\n    result\n  end\nend\ndefmodule Phase134Route do\n  def request(:get, url, _headers, _body, _opts) do\n    Process.put(:observed_url, url)\n    {:error, :offline_route_probe}\n  end\nend\n[stage, preflight_path] = System.argv()\np = preflight_path |> File.read!() |> :json.decode()\nt = p[\"tuple\"]\notp = :erlang.system_info(:otp_release) |> to_string()\npatch = Path.join([to_string(:code.root_dir()), \"releases\", otp, \"OTP_VERSION\"]) |> File.read!() |> String.trim()\nunless System.version() == \"1.17.3\" and patch == \"27.3.4.15\", do: raise(\"unsupported runtime\")\n{:module, _} = Code.ensure_loaded(Hex.Registry.Server)\nbeam = :code.which(Hex.Registry.Server) |> to_string() |> Path.expand()\nunless beam == Path.join(t[\"ebin\"], \"Elixir.Hex.Registry.Server.beam\"), do: raise(\"foreign Hex BEAM\")\n:ok = Application.load(:hex)\n{:ok, hex} = :application.get_key(:hex, :vsn)\nunless to_string(hex) == \"2.5.1\", do: raise(\"wrong Hex version\")\n{:ok, _} = Application.ensure_all_started(:ssl)\n{:ok, _} = Application.ensure_all_started(:inets)\nconfig = apply(:mix_hex_core, :default_config, [])\nunless config.repo_url == \"https://repo.hex.pm\" and config.repo_name == \"hexpm\" and\n         config.repo_verify and config.repo_verify_origin, do: raise(\"unexpected Hex origin contract\")\nhash = fn data -> :crypto.hash(:sha256, data) |> Base.encode16(case: :lower) end\nresult = if stage == \"route\" do\n  {:error, :offline_route_probe} = apply(:mix_hex_repo, :get_package, [%{config | http_adapter: {Phase134Route, %{}}}, \"mux\"])\n  unless Process.get(:observed_url) == t[\"url\"], do: raise(\"observed request route differs\")\n  %{stage: stage, url: Process.get(:observed_url), network_request_count: 0, elixir: System.version(),\n    otp_patch: patch, hex: to_string(hex), public_key_sha256: hash.(config.repo_public_key)}\nelse\n  if System.get_env(\"HEX_OFFLINE\") != \"1\" or System.get_env(\"HEX_UNSAFE_REGISTRY\") != \"0\" or\n       System.get_env(\"HEX_NO_VERIFY_REPO_ORIGIN\") != \"0\", do: raise(\"unsafe environment\")\n  signed = if stage == \"request\" do\n    Process.put(:object_path, t[\"object\"])\n    tls = [verify: :verify_peer, cacerts: :public_key.cacerts_get(), depth: 3,\n      customize_hostname_check: [match_fun: :public_key.pkix_verify_hostname_match_fun(:https)]]\n    adapter = {Phase134HTTP, %{http_options: [ssl: tls, autoredirect: false, timeout: 15_000, connect_timeout: 10_000]}}\n    {:ok, {200, _, _}} = apply(:mix_hex_repo, :get_package, [%{config | http_adapter: adapter}, \"mux\"])\n    File.read!(t[\"object\"])\n  else\n    File.read!(t[\"object\"])\n  end\n  {:ok, record} = apply(:mix_hex_registry, :unpack_package, [signed, \"hexpm\", \"mux\", config.repo_public_key])\n  unless record.repository == \"hexpm\" and record.name == \"mux\", do: raise(\"registry origin mismatch\")\n  [release] = Enum.filter(record.releases, &(&1.version == \"3.2.2\"))\n  inner = Base.encode16(release.inner_checksum, case: :lower)\n  outer = Base.encode16(release.outer_checksum, case: :lower)\n  unless inner == p[\"lock\"][\"inner_sha256\"] and outer == p[\"lock\"][\"outer_sha256\"], do: raise(\"lock mismatch\")\n  before = File.read!(t[\"cache_destination\"]) |> hash.()\n  Mix.start()\n  {:ok, _} = apply(Hex.State, :start_link, [[]])\n  apply(Hex.State, :put, [:repos, %{\"hexpm\" => apply(Hex.Repo, :default_hexpm_repo, [])}])\n  unless apply(Hex.State, :fetch!, [:offline]) and not apply(Hex.State, :fetch!, [:unsafe_registry]) and\n           not apply(Hex.State, :fetch!, [:no_verify_repo_origin]), do: raise(\"Hex safety state differs\")\n  {:ok, _} = apply(Hex.Registry.Server, :start_link, [[]])\n  :ok = apply(Hex.Registry.Server, :open, [[registry_path: t[\"cache_destination\"], check_version: false]])\n  if stage == \"request\" do\n    send(Hex.Registry.Server, {:get_package, \"hexpm\", \"mux\", {:ok, {200, %{}, record}}})\n    :ok = apply(Hex.Registry.Server, :persist, [])\n  end\n  :ok = apply(Hex.Registry.Server, :prefetch, [[{\"hexpm\", \"mux\"}]])\n  cached_inner = apply(Hex.Registry.Server, :inner_checksum, [\"hexpm\", \"mux\", \"3.2.2\"]) |> Base.encode16(case: :lower)\n  cached_outer = apply(Hex.Registry.Server, :outer_checksum, [\"hexpm\", \"mux\", \"3.2.2\"]) |> Base.encode16(case: :lower)\n  unless cached_inner == inner and cached_outer == outer, do: raise(\"offline cache mismatch\")\n  after_hash = File.read!(t[\"cache_destination\"]) |> hash.()\n  if stage == \"read\" and before != after_hash, do: raise(\"offline read modified cache\")\n  %{stage: stage, url: t[\"url\"], network_request_count: Process.get(:mux_requests, 0), elixir: System.version(),\n    otp_patch: patch, hex: to_string(hex), os_pid: System.pid(), signature_verified: true, origin_verified: true,\n    inner_sha256: inner, outer_sha256: outer, object_sha256: hash.(signed), public_key_sha256: hash.(config.repo_public_key),\n    cache_before: before, cache_sha256: after_hash, offline: true, persisted: stage == \"request\", restarted: stage == \"read\"}\nend\nIO.puts(\"MUX_PROOF \" <> (:json.encode(result) |> IO.iodata_to_binary()))\n",
      "--",
      "read",
      "/Users/jon/projects/rindle/.claude/worktrees/agent-p134-escalated-1791560070/.planning/phases/133-evidence-charter-and-live-truth/133-134-REGISTRY-PREFLIGHT.json"
    ],
    "cwd": "/Users/jon/projects/rindle/.claude/worktrees/agent-p134-escalated-1791560070",
    "environment": {
      "PATH": "/Users/jon/.asdf/installs/elixir/1.17.3-otp-27/bin:/Users/jon/.asdf/installs/erlang/27.3.4.15/bin:/usr/bin:/bin",
      "HOME": "/Users/jon",
      "HEX_HOME": "/Users/jon/.hex",
      "HEX_OFFLINE": "1",
      "HEX_UNSAFE_REGISTRY": "0",
      "HEX_NO_VERIFY_REPO_ORIGIN": "0",
      "MIX_ARCHIVES": "/private/tmp/rindle-phase133-no-global-archives",
      "ERL_CRASH_DUMP": "/private/tmp/rindle-phase133-134-erl-crash.dump"
    }
  },
  "maximum_requests": 1,
  "offline_profile": "(version 1) (allow default) (deny network*)",
  "request_profile": "(version 1) (allow default) (deny network*) (allow network-outbound (remote tcp \"*:443\")) (allow network-outbound (remote udp \"*:53\")) (allow network-outbound (remote tcp \"*:53\"))"
}
```

## TDD Gate Compliance

The preserved RED named test failed the planned strict equality assertion because the builder was absent, rather than because of setup, import, syntax or discovery failure. Its recorded semantic assessment and machine classifier are valid. The GREEN commit followed the existing RED and passed 24 tests before publication. No refactor commit was needed.

Post-publication acceptance remains failed and is not represented as GREEN or completion.

## Deviations from Plan

### Auto-fixed issues before freeze

1. **[Rule 1 - Bug] Host guard and worktree bindings.** Bound guard proofs to the canonical worktree root and replaced an invalid Seatbelt hostname rule with supported port rules. The frozen adapter still permits only the exact URL and disables redirects. Verified actual-host control/denial probes. Included in `4a7d2b9a`.
2. **[Rule 3 - Blocking] Copied historical fixture isolation.** Corrected copied-report buffer limits and temporary path aliases, and replaced dependence on the mutable developer cache with disposable historical publication fixtures. Current live cache bytes are frozen separately; historical receipts were not rewritten. The suite passed before freeze. Included in `4a7d2b9a`.

### Unresolved verification blocker

**[Rule 3 - Blocking] Copied readiness fixture includes the newly published preflight.** After `1eb9d5ed`, the helper copies current HEAD, which now includes the preflight. Line 239 still asserts absence. The fixture should copy the authenticated preflight's frozen source revision, when one exists, rather than the publication HEAD.

The concrete two-line repair is at `/private/tmp/phase133-134-fixture-repair.patch` (SHA-256 `83422083b6997130f83bc32908ce7229dcdefa6ab73f17c39825ec7c8ebc62d2`). Its real disposable-copy test run is at `/private/tmp/phase133-134-fixture-repair-verification.json` (SHA-256 `0a63888e0c063672f733d541d0c5bf31dbbe85e4d877e5c6f9f35237b4174e21`): 24 passed, 0 failed.

Applying it to the preserved test would change a frozen source blob. The test, source and preflight therefore remain untouched after publication. A separately scoped repair and new immutable preflight boundary are required before the authorization gate. No replacement tuple or inherited answer was created.

**Total deviations:** 2 auto-fixed before freeze; 1 unresolved acceptance blocker. No scope or requirement credit changed.

## Issues Encountered

The outer execution sandbox cannot start the nested host guard (non-network control exit 71). Narrowly escalated offline guard and route commands were approved automatically and passed on the actual host. No automatic approval rejection occurred and no registry request was attempted.

The current-worktree suite failed only after preflight publication. Production readiness still passes, but it does not replace the plan's requirement that all fixtures pass.

## User Setup Required

None. Task 2's human operation decision was not reached.

## Next Phase Readiness

Plan 134 is halted at Task 1 acceptance. Do not ask for or consume mux authorization, make a request, overwrite the preflight, or start Plan 129. The orchestrator must resolve the fixture repair and establish a fresh immutable tuple through the appropriate successor boundary. Preserve existing receipts and zero-request state. STATE.md and ROADMAP.md remain owned by the orchestrator.

## Self-Check: FAILED

- Publication integrity passed: preserved RED and new production/preflight commits exist on this branch; source and test blobs still match the preflight; production readiness and preflight verifiers pass.
- Task 1 acceptance failed: the latest actual suite is 23/24 after publication. The passing isolated repair proposal is not an applied fix.
- Authorization and all later operation artifacts remain absent; the cache and protected planning/history bytes remain unchanged.
