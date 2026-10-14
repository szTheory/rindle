---
status: resolved
trigger: unblock us get us on track; figure out shared-cache loss autonomously
created: 2026-10-10T15:23:00Z
updated: 2026-10-10T15:47:15Z
---

## Current Focus

Root cause: authority was bound to a mutable cache shared by unrelated Hex clients. Plan 148 successfully proved repaired DNS and froze zero-request readiness, but the cache disappeared and reappeared with different raw bytes before production verification. An unrelated Threadline mix ci.all was active in the default shared Hex home; no direct write trace was collected.

Fix: preserve terminal Plans 147/148; snapshot stable observed cache bytes into a dedicated worktree-bound path, authenticate bootstrap provenance and offline ETS integrity, then freeze a fresh separately bound Plan 149 route. Shared cache changes must not affect its readiness; private drift must still fail. No other project's process or files are modified.

Implemented the private-cache route and authenticated terminal histories. Initial red run: 0/6; first expanded green run: 8/8. DNS regression: 9/9. Review found the new ETS audit was using the unpublished final preflight path; it now uses an exclusively published disposable input, removed on either result. A ninth regression covers that production helper. The generated Plan 149 Elixir program parsed on the pinned Elixir 1.17.3 / OTP 27.3.4.15 runtime. Source syntax, git diff checks and automation-first passed. See `/private/tmp/rindle-p149-final-reviewed.log` for final cache results.

Next: commit source and planning, publish read-only DNS and exclusive private bootstrap, commit those inputs, then prove actual-host cache/DNS/guard/route and publish one zero-request preflight before its own exact decision. All five requirements remain Pending, eleven edge rows unresolved, qualification credit zero.


## Terminal verification boundary

Final cache suite: 9/9, zero failures (`/private/tmp/rindle-p149-final-reviewed.log`). Actual DNS and exclusive private bootstrap were committed at `894d0cfc`. The one actual-host preflight stopped before publication with `private cache audit is not network-denying`. The cache proof and `verifyGuardProof` passed; the final check incorrectly expected request-only fields on the offline guard, whose actual contract uses `profile`, `control_exit` and `denied_child_exit`. No preflight, authorization, marker, retrieval or supply exists; network requests and qualification credit are zero. Preserve the private bytes and original bootstrap as read-only terminal inputs. A separately bound Plan 150 must authenticate this history, correct the field mapping and prove all live offline stages before its preflight.
