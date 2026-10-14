---
status: fixing
trigger: unblock us get us on track
created: 2026-10-10T14:14:00Z
updated: 2026-10-10T15:08:00Z
---

## Symptoms

Expected: one guarded signed mux GET produces verified durable offline supply.
Actual: Plan 147 consumed its one attempt, then failed resolving repo.hex.pm with :nxdomain. No signed object or supply exists.
Timeline: request-once on 2026-10-10; original branch and receipts are immutable.
Reproduction: pinned Elixir 1.17.3 / OTP 27.3.4.15, :inet.getaddr(~c"repo.hex.pm", :inet) under the request profile.

## Current Focus

hypothesis: (deny network*) blocks the macOS native resolver's Unix socket despite UDP/TCP 53 allowances.
test: compare unrestricted, original profile, and exact /private/var/run/mDNSResponder exception.
expecting: host and exact-exception succeed; original fails; loopback remains denied.
next_action: preserve Plan 148 cache invalidation with zero authorization/requests, then isolate a dedicated cache in successor Plan 149.

## Evidence

- Host pinned-runtime DNS lookup: {:ok, {151, 101, 1, 91}}.
- Original request profile: {:error, :nxdomain}.
- Original profile plus (allow network-outbound (remote unix-socket (path "/private/var/run/mDNSResponder"))): {:ok, {151, 101, 1, 91}}.
- All three diagnostics exited 0 and made DNS lookups only; no HTTP GET or cache write occurred.
- Apple documents the native resolver socket and sandbox denial at https://developer.apple.com/documentation/security/discovering-and-diagnosing-app-sandbox-violations.
- The bounded production diagnostic independently reproduced original DNS exit 78 / DNS_UNAVAILABLE:nxdomain, host and repaired DNS success, request-profile control exit 0, and loopback exit 77 / POLICY_DENIAL:EPERM. Its report digest is c88bc20a1b8b6e649fbbd19a819bd87e0a045af3d80966a438ecb4f30295d0ab; registry requests and qualification credit are zero.
- Nine successor regression tests passed, including copied production readiness, immutable Plan 147 history, spent-authorization rejection, private-cache drift, no retry, origin/signature checks and distinct-process offline readback.
- The automation-first contract and registry source syntax check passed.
- The first full registry run finished 34/48: adding the DNS helper to the old fixture source inventory invalidated historical fixture identities and omitted the helper from one copied CLI; two collectors also observed the shared Hex cache temporarily absent. No test or DNS diagnostic wrote to that live cache. Separate current helper inventory and copied-CLI dependency fixes are now under focused and full regression verification; historical inventories remain unchanged.
- A later read-only cache observation saw SHA-256 a867e3336d7c70ee7a0efa0f9d4a4d5ba34ae573d26431cbb05a610f3c8d465e, differing from Plan 147's historical baseline. Plan 148 must freeze and revalidate current live cache bytes; Plan 147's terminal history continues to bind its original baseline.

## Eliminated

The corrected full registry run finished 47/48, with its only failure a local `git status` timeout in Plan 143 copied production readiness. That unchanged check then passed 1/1 in isolation. Both nested history tests passed: before and after publication for each of Plans 143 and 145, with 46/46 child tests in all four scenarios and no request or authority publication. The focused inventory/CLI run passed 10/11, with a local `git show` timeout in Plan 134 copied readiness; that unchanged check also passed 1/1 in isolation. The final successor suite passed 9/9 against committed source. No timeout or live-cache verifier was weakened; these host-process timeouts were rechecked individually instead of repeating the passing nested histories. No production preflight has been published.

- General DNS outage: the same runtime resolves successfully outside the profile.
- Bad hostname: the unchanged hostname resolves after exactly one socket exception.
- Need for broad network permission: the narrow resolver exception suffices.

## Resolution

root_cause: the request sandbox omitted the macOS native resolver's Unix-domain socket.
fix: Plan 148 uses the exact socket exception; old profiles and Plan 147 terminal evidence remain unchanged.
verification: live DNS/loopback proof, final 9/9 successor tests, all four 46/46 nested history scenarios, isolated timeout rechecks, syntax and automation-first passed. The full-run timeout and its recheck are explicitly retained above. Independent production preflight remains pending. No Plan 148 HTTP request is authorized or started.

## Shared-cache invalidation

The actual-host Plan 148 preflight passed and was committed at 2c8d6024. Production readiness failed when the shared cache disappeared. Ordinary and actual-host read-only checks confirmed absence; it later reappeared with different bytes. The original baseline was a867e3336d7c70ee7a0efa0f9d4a4d5ba34ae573d26431cbb05a610f3c8d465e; the later report observed 3aab64a4647246c1a06a769b6fd3ec669d35affc49d92013cc3d27e363356187. No exact-byte backup was found among owned temporary cache snapshots. Sanitized process inspection observed another project running mix ci.all against the default shared Hex home, without a captured write trace. No Plan 148 authorization was requested or received, and no GET occurred. Its summary and invalidation report are immutable historical inputs to a dedicated-cache successor.
