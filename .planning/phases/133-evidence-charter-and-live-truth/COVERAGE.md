# API Coverage — GitHub CLI

> Full coverage by default. Opt-outs are explicit, reasoned decisions. Scope is GitHub Actions run, job-log and artifact evidence, diagnostic workflow dispatch, and scheduled rolling-incident persistence. Plan 104's offline cache preflight adds no external API operation.

| capability | decision | reason |
|---|---|---|
| `git ls-remote --heads origin` | INTEGRATE | Read-only lookup for the exact SHA-derived ref; record argv, exit code, and output, and require successful empty output. This lookup grants no write or dispatch permission. |
| `git clone --no-checkout -- <pinned-url> <destination>` | INTEGRATE | One Plan 120 retrieval; detached checkout verifies the full commit. A fresh literal Plan 120 checkpoint binds source, URL, destination and preflight digest. Plan 115 permission cannot transfer. |
| Plan 122 non-force ref publish and one `workflow_dispatch` | INTEGRATE | These remote mutations require a separate fresh literal Plan 122 checkpoint bound to its preflight digest, source, and ref. Plan 120 fetch authorization grants neither operation. |
| `gh run list` | INTEGRATE | Enumerate the bounded Nightly runs used to select pre-mutation and fresh/restored evidence. |
| `gh run view` | INTEGRATE | Read exact run, job, attempt, SHA, conclusion, and log evidence. |
| `gh run watch` | INTEGRATE | Wait for the explicitly dispatched diagnostic run to reach a terminal state. |
| `gh run download` | INTEGRATE | Download exact named verdict and replay-checkpoint artifacts after run, attempt, and artifact identity checks. |
| `gh run rerun` | OPT-OUT | A rerun would blur first-attempt evidence and is not needed for the independent fresh/restored proof. |
| `gh run cancel` | OPT-OUT | The phase observes cancellation as a failing state but does not manage operator runs. |
| `gh run delete` | OPT-OUT | Destructive evidence removal contradicts the immutable evidence charter. |
| `gh workflow list` | INTEGRATE | Resolve the existing `nightly.yml` workflow before exact-head diagnostic dispatch. |
| `gh workflow view` | INTEGRATE | Confirm the selected workflow identity and dispatch support. |
| `gh workflow run` | INTEGRATE | Dispatch the existing diagnostic Nightly on an already-published ref for exact-run acceptance. |
| `gh workflow enable` | OPT-OUT | Workflow lifecycle administration is not part of evidence collection. |
| `gh workflow disable` | OPT-OUT | Disabling evidence production contradicts the phase goal and is outside scope. |
| `gh issue list` | INTEGRATE | Enforce zero-or-one open issue with the exact `nightly-failure` label. |
| `gh issue view` | INTEGRATE | Read issue #88 and exact rolling-incident state without mutation. |
| `gh issue create` | INTEGRATE | Open the rolling incident on a qualifying scheduled failure. |
| `gh issue comment` | INTEGRATE | Append exact failing-run evidence to the one existing incident. |
| `gh issue close` | INTEGRATE | Close only after exact scheduled current-main recovery evidence is added. |
| `gh issue status` | OPT-OUT | Repository-wide assignee/mention status is unrelated to the exact-label incident lifecycle. |
| `gh issue reopen` | OPT-OUT | A later failure creates or updates according to current open cardinality; reopening historical incidents is outside the one-open-incident policy. |
| `gh issue edit` | OPT-OUT | The lifecycle never rewrites prior incident evidence or issue metadata. |
| `gh issue delete` | OPT-OUT | Destructive removal is incompatible with incident auditability. |
| `gh issue develop` | OPT-OUT | Linked development branches are unrelated to Nightly incident persistence. |
| `gh issue lock` | OPT-OUT | Conversation moderation is not part of the lifecycle. |
| `gh issue unlock` | OPT-OUT | Conversation moderation is not part of the lifecycle. |
| `gh issue pin` | OPT-OUT | Repository issue presentation is not part of the lifecycle. |
| `gh issue unpin` | OPT-OUT | Repository issue presentation is not part of the lifecycle. |
| `gh issue transfer` | OPT-OUT | The incident remains in the current repository. |
| `actions/upload-artifact` | INTEGRATE | Publish immutable scheduled verdict and replay-checkpoint artifacts for authenticated replay. |
| `GET /repos/{owner}/{repo}/git/ref/heads/{default_branch}` | INTEGRATE | Read the current remote default-branch SHA before authorizing incident closure. |
| `GET /repos/{owner}/{repo}/actions/workflows/nightly.yml/runs` | INTEGRATE | Enumerate bounded scheduled Nightly runs for incident replay. |
| `GET /repos/{owner}/{repo}/actions/runs/{run_id}/attempts/{attempt}` | INTEGRATE | Authenticate each scheduled run attempt before consuming its verdict artifact. |
| `GET /repos/{owner}/{repo}/actions/artifacts` | INTEGRATE | Inventory verdict and replay-checkpoint artifacts and reject duplicate, expired, or foreign entries. |
| `GET /repos/{owner}/{repo}/actions/jobs/{job_id}/logs` | INTEGRATE | Collect authenticated job logs for bounded coverage and failure evidence. |
| Other GitHub Actions artifact upload/download and run/job mutation endpoints | OPT-OUT | This phase only publishes and reads named evidence artifacts; it never rewrites or deletes historical runs, jobs, or artifacts. |
| Other `gh api` REST/GraphQL endpoints and mutation methods | OPT-OUT | The enumerated reads and issue lifecycle cover Phase 133; broader repository administration is outside its evidence contract. |

## Plans 133, 135, 137, 138, 134, 145, 146 and 147: exact Hex source, supported build and mux registry input

| capability | decision | reason |
|---|---|---|
| One Plan 133 exact-source Hex clone | INTEGRATE | Acquire official Hex v2.5.1 source once after frozen preflight and fresh literal source authorization; detached checkout must equal `a43131c26aeca06064959297d737991163f5ac5d`. |
| One Plan 135 local build and offline proof | INTEGRATE | A separate exact-source/build answer authorized one pinned Elixir 1.17.3/OTP 27 build. Proof failed at SSL startup; its consumed answer and terminal halt remain immutable. |
| One Plan 138 successor build and offline proof | INTEGRATE | Plan 137 commits the SSL repair and gate. A separate frozen tuple and fresh literal answer permit one isolated build and offline cache proof before Plan 134 mux readiness. |
| Plan 139 canonicalizer repair | INTEGRATE | Distinct Plan 139 proof code and focused regression correct decoded null without editing Plan 138's frozen implementation or test and without running a child. |
| One Plan 140 separately authorized offline proof | INTEGRATE | A fresh Plan 140 tuple and literal answer permitted one local build and proof; Plan 138 remains terminal. Stop grants no mux provenance or requirement credit. |
| Git source push, tag write, additional clone or unpinned branch use | OPT-OUT | Source is read-only and pinned; extra or moving-source operations cannot qualify compatibility. |
| One exact signed mux 3.2.2 record request | INTEGRATE | Plan 150's exact-authorized GET passed signed metadata and offline proof; authority is spent and qualification credit remains zero. |
| Tarball fetch, registry refresh, alternate host or retry | OPT-OUT | Plan 126 already supplies the archive; recovery needs one authenticated metadata record and treats first red as terminal. |

Historical request sequence: Plans 145/146 halted with zero requests; Plan 147 consumed one DNS-failing attempt. Plan 148 proved the native resolver repair but halted when its shared cache changed before authorization, with zero GETs. Plan 149 copied a private cache but halted before preflight at an offline guard field mismatch. Plan 150 completed one fresh exact-authorized GET after private ETS/DNS/guard proof. Signed hexpm bytes, both lock hashes, private cache persistence, restarted offline readback and independent production supply verification passed. Its authority is consumed; this supplies the prerequisite with zero qualification credit.

The phase-scope API coverage detector returned `detected: true` for the final Phase 133 ROADMAP section plus Plan 173 draft. The matrix above continues to govern the phase's external GitHub, Git and signed Hex retrieval capabilities. Plan 173 adds only a local, denied-network qualification route; it grants no new external API operation or remote authority. Plan 170 is immutable terminal zero-credit history, and Plans 169 and 121–123 remain blocked until independently verified green successor evidence and a later separately reviewed rebind. All five requirements remain Pending, eleven edges unresolved and qualification credit zero.
