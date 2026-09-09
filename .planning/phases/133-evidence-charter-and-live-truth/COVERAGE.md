# API Coverage — GitHub CLI

> Full coverage by default. Opt-outs are explicit, reasoned decisions. Scope is the two GitHub CLI capability namespaces integrated by Phase 133: workflow-run evidence (`gh run`) and rolling-incident persistence (`gh issue`), plus the one read-only REST lookup needed to bind a run to current `main`.

| capability | decision | reason |
|---|---|---|
| `gh run list` | INTEGRATE | Enumerate the bounded Nightly runs used to select pre-mutation and fresh/restored evidence. |
| `gh run view` | INTEGRATE | Read exact run, job, attempt, SHA, conclusion, and log evidence. |
| `gh run watch` | INTEGRATE | Wait for the explicitly dispatched diagnostic run to reach a terminal state. |
| `gh run download` | OPT-OUT | Phase 133 validates run metadata and bounded logs; it does not introduce a workflow artifact contract. |
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
| `GET /repos/{owner}/{repo}/git/ref/heads/{default_branch}` | INTEGRATE | Read the current remote default-branch SHA before authorizing incident closure. |
| Other `gh api` REST/GraphQL endpoints and mutation methods | OPT-OUT | Phase 133 needs one bounded read-only ref lookup; all other API capabilities are outside its evidence and incident contracts. |
