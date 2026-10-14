---
status: halted
qualification: local-gates-failed
halt_stage: local-gates
halt_gate: ci
subject_sha: 4784d47e873c324910e5081d356d7772206cd15e
subject_tree: 50b330563a90ca8b519ca2ee99d49c67dc456068
local_gates_sha256: edc8be2f5911c28df7e4f344450407544e3455e70179dc97eeb1dc7626cc324b
prior_receipt_sha256: 1cc607545ff6d4061931105a156a42549bb375efafe6418b054e7d33e18861a4
remote_action: none
remote_ref: null
remote_lookup: not_run
census: not_run
requirements-completed: []
halt_reason: "mix ci exited 2; Rindle.DoctorThresholdsTest setup_all failed (1710 tests, 1 failure); coverage was not started"
---
Plan 69 halted at the first red local gate. The exact halt reason is: mix ci exited 2; Rindle.DoctorThresholdsTest setup_all failed (1710 tests, 1 failure); coverage was not started. The report records dependencies and JOSE preflight passing, with source and staged header hashes matching and the staged include resolving inside the worktree. Its structured CI counters show 97 tests and zero failures, while its bounded output ends with 1,710 tests and one failure; the structured counters do not represent the terminal full-suite result. Coverage, census, independent authorities, and the read-only ref lookup were not started. This result grants zero requirement credit. Plans 133-67 and 133-68 remain blocked, and the prior canonical receipt is unchanged.
