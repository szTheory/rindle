# GSD continuity

Follow the **GSD command handoffs** section of DEVELOPMENT-TRAIN.md for every
GSD status, pause, completion, and resume response. Give the user the next
literal `$gsd-...` command, the correct worktree, and its timing/condition.

Before a handoff, run `python3 .planning/tools/check_gsd_handoff.py` and resolve
any reported conflict. This read-only guard complements GSD's routing owners;
it never authorizes execution or marks requirements complete.

Read matching `.planning/async-jobs/` manifests before dispatching incomplete
plans. Running jobs retain ownership. Preserve their process, outputs and
frozen source. A successful process exit still requires evidence verification.

Keep STATE.md as current resume context. Move superseded narrative to an
explicit history artifact; archive obsolete HANDOFF.json after successful
resumption. Never route using a handoff for a different phase.
