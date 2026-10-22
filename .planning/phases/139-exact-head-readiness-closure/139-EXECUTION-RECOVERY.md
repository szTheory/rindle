# Phase 139 execution handoff

Use `/Users/jon/projects/rindle/.claude/worktrees/phase136-execution` on
`gsd/phase-136-execution` for this handoff. The parent checkout lacks the
delivered Phase 134–138 source and must not be used to execute these plans.
At handoff, HEAD was `47945252` before the Phase 139 planning changes. Check
`git status` and the actual HEAD before starting; the handoff SHA is provenance,
not an exact-head readiness subject.

Run from that worktree:

```sh
bash .planning/phases/139-exact-head-readiness-closure/139-preflight-test.sh
./scripts/maintainer/automation_first_contract.sh
```

The preflight checks passed verifications and summaries for Phases 133–138
against `HEAD`, rejects dirty upstream evidence, recomputes Phase 138's declared
covered-file digest through an identity-verified installed GSD tool, and calls
the separate retained matrix verifier. Its negative test uses a temporary git
wrapper to simulate dirty upstream evidence without altering tracked files.
Its default inputs are
`/private/tmp/rindle-138-matrix-verified/inputs.json` and `receipt.json`;
override `RINDLE_138_EVIDENCE_DIR` only to verify a relocated, complete
retained pair. The separate direct command is:

```sh
python3 scripts/maintainer/built_package_twin.py verify \
  --inputs /private/tmp/rindle-138-matrix-verified/inputs.json \
  --receipt /private/tmp/rindle-138-matrix-verified/receipt.json
```

`scripts/maintainer/built_package_twin.py`, `twin_receipt.py`, and
`twin_cleanup.py` are the delivered package/recovery contract. The twin's
`package_tar_sha256`, `package_metadata_sha256`, and `package_tree_sha256`
are different identities. Read `guides/built_package_twin.md` for the supported
Elixir 1.17.3-otp-27, OTP 27.3.4.15 and Node 20.18.1 cell and exact run,
verify and cleanup commands. Phase 134 dispositions are in
`.planning/INBOX-LEDGER.json`, checked by
`scripts/maintainer/validate_inbox_ledger.sh`; Phase 136 receipt validation is
in `scripts/maintainer/verify_phase136_qualification.sh`. The original Phase
136 timing qualification remains blocked; `136-SPEED-DEFERRAL.json` records
the user's no-credit deferral to SEED-261021-918. Do not change that receipt
or claim median/p95 success.

Execution order is wave 1: Plans 00 and 01; wave 2: Plans 02, 03, 04; wave 3:
Plan 05; wave 4: Plan 06; wave 5: Plan 07. Plan 02 depends on 00 and 01.
Plan 00 repairs public Doctor's versioned host migration ledger false failure;
its supported host path lives in
`test/twin/host/priv/repo/migrations/20261021000000_install_twin.exs`.
Plan 07 is live terminal acceptance only after all tracked Phase 139 changes
merge to `main` through the normal PR train. It still requires same-subject
qualification, green complete main CI, an eligible real scheduled Nightly,
effective protection, complete authorized remote sources, a run-bound uploaded
digest sidecar, verified durable archive bytes, and refreshed adoption parity.
No preflight result, fixture, historical SHA, or prior-phase verifier grants
READY-01–05. If any live source is missing or inaccessible, keep the
requirement open with its machine-readable `not_ready` reason.
