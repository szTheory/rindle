---
status: passed
review_mode: inline
---
# Code review

Reviewed the task's source diff across candidate admission, all collector/qualification
owners, immutable validator, workflow, retention and terminal/claim paths. Review was
inline under the active execution boundary; it is not an independent peer review.

Resolved findings:
- Qualification created fresh API transports in one immutable log directory. Rechecks
  now use distinct directories and the remaining qualification budget; a regression
  checks distinct paths across advancing-main observations.
- Terminal acceptance could mix a snapshot controller and a legacy bundle before
  later stored-byte rejection. It now rejects policy mismatch before refresh/verdict;
  the negative terminal-path test asserts nonpassing and no refresh.
- Control identity originally only equated two supplied maps. Snapshot replay now
  also pins every controller/policy digest to executing reviewed bytes. Fixtures use
  those actual bytes; arbitrary older policy and missing bindings are rejected.
- Explicit candidate arguments can no longer be silently ignored by legacy mode or
  overridden during refresh. A changed candidate needs a new admitted attempt.

Trust checks retained: authenticated main ancestry plus actual push-main provenance;
full latest CI and real scheduled Nightly jobs/incident artifacts; private-source
visibility; fresh current ledger/adoption authority bytes; separate producer SHA;
run/attempt, sidecar/transport/archive/manifest digests; immutable refresh and cleanup;
historical-only snapshot claims and synthetic-only adoption. No dependency added.
