# Verification and Fast Feedback

This is the operating policy for GSD verification, UAT, CI, and release evidence.
Apply it before preparing a human checkpoint or expanding a test suite.

## Automate acceptance

- Start from each requirement and its observable result. Reuse existing tests, probes, and evidence collectors before adding checks.
- Drive repeatable behavior through executable unit, contract, seam, integration, browser, or live-evidence checks. Aim for zero human UAT where software can drive and judge the behavior.
- Keep human handoffs for subjective experience, physical observation, credentials, or irreversible actions. A human response may authorize an operation; it never supplies pass evidence for an active requirement.
- If remote evidence is held, state the exact missing machine evidence, authorization boundary, and resume trigger. Keep the requirement open with zero credit; do not substitute a walkthrough or silently replay a held operation.
- Reopen a completed or deferred verification only when its source, code, evidence, policy, or authorization has materially changed. Carry the recorded result forward instead of asking the same question again.

## Keep Nightly advisory and continue during remote evidence waits

Scheduled Nightly results are advisory for ordinary development, branch protection, release
readiness, general candidate readiness, and new DevOps certifications. Keep the Nightly workflow
strict within its own summary and incident reporting; a red or stale result triggers triage in that
lane, not an automatic hold. A concrete defect may be gated under its own severity policy, regardless
of how it was found. New general readiness uses exact-head v2 or snapshot v4. Exact-source push-main CI, effective branch
protection, local qualification, fresh remote dispositions and adoption parity remain machine gates.
The historical exact-head v1 and snapshot v3 receipts retain their original Nightly criteria.

Other scheduled or remote evidence gates only claims that require that evidence. At session resume,
run `$gsd-resume-work`, reload the current handoff in `STATE.md`, and query the authoritative provider
for the recorded event and exact source; a session-local monitor is not durable state. While the result
is pending, start or continue an independent, already-approved local task in the shared checkout and
preserve the active evidence subject. Do not make waiting or polling the only next development action
while useful approved work remains.

If no independent approved task exists, follow the release-train pause and do not invent a phase or
milestone. State the exact non-Nightly event/source trigger and the literal next GSD command. Use
`$gsd-progress --next` without `--auto` when resume returns without dispatching the saved action;
respect its verification gates and never use `--force` to bypass them. Do not manually dispatch a
scheduled workflow when an explicitly scoped contract requires a real `schedule` event. After that
exact run succeeds, continue only the saved, authorized collection, first checking that no monitor or
agent already started it. Preserve earlier attempts and their zero-credit results.

When gap planning finds that every remaining verification gap is waiting on an external event and
the existing authorization already defines the follow-up, record the verification fingerprint,
event trigger, and one-time planning result in `STATE.md`. Do not repeat the same gap-planning pass
while that fingerprint and evidence source are unchanged; revisit it only after the external result
or covered source changes. This keeps the GSD gap visible without turning an unchanged wait into a
planning loop.

## Order checks by cost

Run the cheapest relevant deterministic checks first: diff and syntax checks, configuration and identity checks, generated-artifact/idempotence checks, then focused fixtures and unit tests. Move to seam/integration and end-to-end checks when they cover a real boundary. Run broad CI or live workflows after the candidate passes those preflights.

Use a local throwaway probe when feedback is useful once. Put a check in recurring CI when it prevents a likely regression or protects a release boundary often enough to justify its runtime and maintenance. Do not add a suite to CI just because it can run there.

In Elixir/Mix projects, confirm the GSD regression gate resolved a real test command. Its generic command detector may fall through to `true` when `workflow.test_command` is unset. Use the phase's scoped commands from `VALIDATION.md` for meaningful feedback; do not set `mix test` globally just to activate the gate, since that repeats the full suite for every phase.

## Keep CI and release feedback fast

After each meaningful CI run, inspect job and step durations and dependency order for a low-risk critical-path improvement. Preserve the required behavior and quality signal. Compare like-for-like runs; distinguish wall latency from aggregate runner time, and label billed cost unknown unless billing data is available. Record reusable findings under `.planning/research/`; stop investigating when more analysis cannot change a decision.

Prefer a cheap deterministic preflight before a long lane. Fix the narrow cause of a failure and use focused evidence for the retest when it is sufficient. Do not add speculative caches, concurrency, or dependencies without measurements.

For release and CD evidence, retain exact-source and protected-main gates. Keep credential admission and irreversible release actions as explicit boundaries. A failed credential gate stays stopped until its cause and authorization change.

## Record the result once

Record each automated command, its source/subject, result, and limits in the phase `VALIDATION.md` or evidence artifact. Mark automated UAT rows with their machine evidence. For a held row, record why it is held, its zero-credit effect, and the condition that would make it useful to resume. Do not label an automated evidence gap as a request for manual verification.
