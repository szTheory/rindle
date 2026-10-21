---
phase: 136-measured-quality-and-ci-ratchets
plan: 11
status: complete
outcome: first-red
requirements-completed: [COV-06]
key-files:
  created: [136-SUBJECT.json, 136-COVERAGE-EVIDENCE.json, 136-CANONICAL-FIRST-RED.json, 136-CANONICAL-FIRST-RED.log]
coverage:
  - id: first-canonical-attempt
    description: Immutable committed subject and single supported canonical invocation with retained failure
    verification:
      - kind: probe
        ref: bash scripts/maintainer/phase136_measure.sh verify-subject --subject-file .planning/phases/136-measured-quality-and-ci-ratchets/136-SUBJECT.json
        status: pass
    human_judgment: false
completed: 2026-10-20
---

# Phase136 Plan11: Immutable First-Red Measurement

Pinned909318d99df0c64281ca314d5c1a2bf614eff15a / treed7c304008e7aaf36c07bd5d350cbfd70bc1732b5 before invoking the canonical local+JSON command once. Non-planning source was clean and stayed unchanged throughout this attempt.

The supported Elixir1.17.3/OTP27.3.4.15/Node20.18.1 command exited1:3doctests,1691tests,3failures,87excluded,4skipped,380.1seconds. The existing async-safety guard reports55file mutations in four newly introduced fixture modules. Both live-residue accounting and baseline idempotence fail. The local coverage analyzer also rejected its floored82.1 against minimum82.2 and stopped before JSON emission.

The full command output, exact exit, digest, subject and missing-artifact result are retained in new-only planning evidence. The existing coverage writer produced a blocked receipt for missing/stale artifact; verify-only correctly fails with missing fields. No exact JSON count credit or COV-06 closure is claimed. Source-projection verification returns complete and accepts only the planning evidence tail.

Plan11's measurement task is finished with its explicitly permitted first-red outcome. No suite was relaunched against this subject, no receipt overwritten, and no source change made within this attempt. The seven requirements remain Pending. A distinct gap-closure Plan12 ends this source freeze, repairs the newly exposed integration gates and creates a separately named committed replacement subject. Downstream final collectors must use that replacement; old evidence remains immutable.
