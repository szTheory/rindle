---
status: resolved
slug: s3-tus-imds-cred-resolution
trigger: |
  4 test failures in test/rindle/storage/s3_tus_test.exs that surface ONLY in CI
  (GitHub Actions run 27916861643 on origin/main), in the `Integration` and
  `Package Consumer Proof Matrix + Release Preflight` jobs, during the
  `Generate coverage JSON artifact` step (`mix coveralls.json`). ExAws tries to
  resolve REAL AWS credentials via EC2 instance-metadata (IMDS) → HTTP 404 →
  RuntimeError. The same tests PASS in the `Quality` job. Backlog item 999.1.
created: 2026-06-21T21:14:45Z
updated: 2026-06-21T21:14:45Z
---

# Debug: s3_tus_test ExAws IMDS credential resolution (404) in CI

## Symptoms

- **Expected:** `test/rindle/storage/s3_tus_test.exs` is a pure unit test of TUS
  tail-buffer slicing logic against a local `root:` fixture. It should never reach
  real AWS/S3 or resolve live credentials. All 4 tests should pass in every CI job.
- **Actual:** 4 tests fail in CI — `1234 tests, 4 failures` — the job's
  `mix coveralls.json` step exits 2.
- **Error (identical on each failure):**
  ```
  ** (RuntimeError) Instance Meta Error: HTTP response status code 404
      (ex_aws 2.6.1) lib/ex_aws/instance_meta.ex:51: ExAws.InstanceMeta.retry_or_raise/4
  ** (exit) exited in: GenServer.call(ExAws.Config.AuthCache,
      {:refresh_auth, %{host: "s3.amazonaws.com",
        access_key_id: [{:system,"AWS_ACCESS_KEY_ID"}, :pod_identity, :instance_role],
        secret_access_key: [{:system,"AWS_SECRET_ACCESS_KEY"}, :pod_identity, :instance_role],
        region: "us-east-1", ...}}, 30000)
  ```
- **Timeline:** First observed 2026-06-21 on the FIRST real CI run of the accumulated
  v1.20 work (origin/main had been 64 commits behind; this code never ran in CI before).
  Not introduced by the branch-protection-flip change.
- **Reproduction:** CI run 27916861643, jobs `Integration` and
  `Package Consumer Proof Matrix + Release Preflight`, step `Generate coverage JSON
  artifact` (`mix coveralls.json` — the DEFAULT suite, no `--include`/`--only` filter).
  Failing test locations: `s3_tus_test.exs:80, :98, :118, :205`.

## Current Focus

hypothesis: |
  ExAws credential resolution differs by job ENV. The `Integration` /
  `Package Consumer` jobs set (or fail to set) AWS_*/`:ex_aws` config such that
  ExAws.Config.AuthCache attempts a live `:instance_role` (IMDS) refresh against
  s3.amazonaws.com, whereas the `Quality` job has static dummy creds in env/config
  that short-circuit IMDS. The s3_tus tests exercise an S3 code path that triggers
  AuthCache even though the assertions are about local tail-buffer slicing.
test: |
  Compare AWS_*/ExAws-related env + service config across the Quality vs
  Integration vs Package-Consumer jobs in .github/workflows/ci.yml; inspect how
  s3_tus_test.exs / lib/rindle/storage/s3.ex build the ExAws config (static creds
  vs default provider chain) and whether config/test.exs sets dummy AWS creds.
expecting: |
  Quality job (or its composite/env) sets AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
  (or :ex_aws static creds) that the Integration/Package-Consumer jobs do not — so
  ExAws falls through to :instance_role and hits IMDS only in those jobs.
next_action: |
  Add deterministic dummy `config :ex_aws` static creds (access_key_id /
  secret_access_key / region) to config/test.exs so the ExAws credential chain
  resolves statically in EVERY test job and never falls through to :instance_role
  (IMDS). Per-call aws_config: overrides in s3_test.exs keep real MinIO coverage
  intact.
reasoning_checkpoint:
  hypothesis: |
    The untagged s3_tus_test.exs calls S3.upload_part_stream/complete_part_stream
    with `aws_config: []` (empty). The configured request_module is the
    S3MultipartRequestStub, which DELEGATES to real ExAws.request/2 whenever all
    four RINDLE_MINIO_* env vars are set (minio_configured?/0). The Integration and
    Package-Consumer jobs set those four vars; the Quality job does not. So ONLY in
    the MinIO jobs does the stub pass these untagged-test calls through to real
    ExAws — with empty aws_config and NO AWS_ACCESS_KEY_ID/SECRET set anywhere and
    NO config :ex_aws — and ExAws walks its default credential chain to
    :instance_role, hits IMDS, and gets HTTP 404. The Quality job short-circuits at
    the stub (offline), so it passes.
  confirming_evidence:
    - "ci.yml: Quality job (line 23) has NO RINDLE_MINIO_* env; Integration (294-297) and Package Consumer (541-544) set all four RINDLE_MINIO_* vars."
    - "s3_multipart_request_stub.ex: minio_configured?/0 requires all 4 RINDLE_MINIO_* present, then `ExAws.request(op, config)` (real network/cred path)."
    - "s3_tus_test.exs lines 40 & 133 pass `aws_config:` only as part of opts with no access_key_id/secret — request/2 uses Keyword.get(opts,:aws_config,[]) == [] (s3.ex:610)."
    - "grep: NO AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY in ci.yml or config/; NO `config :ex_aws` anywhere in config/."
    - "Error key in symptoms shows access_key_id chain [{:system,\"AWS_ACCESS_KEY_ID\"}, :pod_identity, :instance_role] resolving to IMDS — the ex_aws default chain with nothing static set."
  falsification_test: |
    If adding static `config :ex_aws` dummy creds did NOT stop the IMDS call, the
    hypothesis would be wrong (e.g. if the failure came from a different op path).
    Locally: set all four RINDLE_MINIO_* to bogus values (no MinIO running) and run
    the s3_tus_test.exs default suite — pre-fix it should attempt a real ExAws
    request (connection/cred error, NOT a clean stub pass); post-fix the static
    creds make ExAws build a config without IMDS. The math assertions never need a
    live endpoint for the sub-5-MiB paths.
  fix_rationale: |
    Root cause is the absence of any static ExAws credentials, so the default
    credential chain reaches :instance_role/IMDS for any caller passing empty
    aws_config. Setting `config :ex_aws, access_key_id: "test", secret_access_key:
    "test", region: "us-east-1"` in config/test.exs makes the chain resolve
    statically in ALL test jobs — addressing the root cause, not the symptom. It
    does NOT weaken tagged MinIO coverage: s3_test.exs passes explicit per-call
    aws_config (access_key_id/secret/host/port) which ExAws merges LAST (step 4),
    overriding the global dummy. The MinIO lane still drives real UploadPart.
  blind_spots: |
    Cannot reproduce the live IMDS 404 locally (no EC2 metadata endpoint). Relying
    on static analysis of the ex_aws credential-resolution order. Will verify the
    full default suite passes locally (where minio_configured?/0 is false and the
    stub short-circuits) and confirm the dummy creds do not break any test that
    relied on the chain. Untested: whether some other untagged test elsewhere
    depends on ExAws raising on missing creds (grep shows none).

## Evidence

- timestamp: 2026-06-21T21:14:45Z
  note: |
    CI run 27916861643 failed jobs (gh run view): `Integration`,
    `Package Consumer Proof Matrix + Release Preflight`, `CI Summary` (cascade).
    Both real failures are the `Generate coverage JSON artifact` step.
- timestamp: 2026-06-21T21:14:45Z
  note: |
    The gating test steps in these jobs run SCOPED tests (e.g. Integration runs
    `mix test ...lifecycle_integration_test.exs --include integration` and
    `...storage_adapter_test.exs --include minio`), but the SEPARATE
    `Generate coverage JSON artifact` step runs plain `mix coveralls.json` =
    full default suite, which includes the untagged s3_tus_test.exs. That is where
    the IMDS 404 hits.
- timestamp: 2026-06-21T21:14:45Z
  note: |
    s3_tus_test.exs: `use ExUnit.Case, async: true`, NO @moduletag/@tag exclusion;
    tests use a local `root:` fixture and assert tail-buffer slicing (TUS-06) /
    cross-node resume guard (CR-04). Lines 80/98/118/205 are the 4 failures.
- timestamp: 2026-06-21T21:14:45Z
  note: |
    KEY DISCRIMINATOR: the `Quality` job runs the same default suite via
    `mix coveralls` (ci.yml ~line 164) and PASSES these tests. So the bug is
    environmental/config drift between jobs, not a logic bug in the test.

- timestamp: 2026-06-21T21:18:00Z
  checked: |
    config/test.exs, lib/rindle/storage/s3.ex, test/support/s3_multipart_request_stub.ex,
    test/rindle/storage/s3_test.exs, test/rindle/upload/tus_s3_integration_test.exs,
    and the env blocks of every job in .github/workflows/ci.yml.
  found: |
    ROOT CAUSE confirmed. config/test.exs wires request_module:
    Rindle.Support.S3MultipartRequestStub. The stub's request/2 had a
    `minio_configured?()` branch that DELEGATED to real ExAws.request/2 whenever
    all four RINDLE_MINIO_* env vars were set. The Quality job sets NONE of them
    (stub stays offline -> tests pass); Integration (ci.yml 294-297) and Package
    Consumer (541-544) set all four -> stub delegates. The untagged offline specs
    in s3_tus_test.exs pass empty `aws_config: []`, and there is NO config :ex_aws
    and NO AWS_ACCESS_KEY_ID/SECRET anywhere -> delegated ExAws walked its default
    credential chain to :instance_role -> IMDS -> HTTP 404 -> RuntimeError. The 4
    failures (s3_tus_test.exs:80/98/118/205) are exactly the multipart paths that
    delegate.
  implication: |
    The delegation branch served no real purpose: the genuine MinIO tests
    (s3_test.exs @tag :minio, tus_s3_integration_test.exs @moduletag :minio) do NOT
    rely on the stub — they REPLACE request_module with real ExAws in setup
    (tus_s3_integration_test.exs:76 Application.put_env(...S3, bucket: ...) drops
    request_module:) and supply explicit MinIO aws_config / config :ex_aws, :s3.
    Removing the delegation makes the stub deterministic offline in ALL jobs
    without weakening any tagged coverage.
- timestamp: 2026-06-21T21:20:00Z
  checked: |
    Verification runs (local). Reproduced the CI condition by setting all four
    RINDLE_MINIO_* to the CI values with NO MinIO running, then running the
    untagged s3_tus_test.exs and the full default suite.
  found: |
    PRE-FIX (dummy-creds only, stub still delegating): MinIO-env run raised the
    real ExAws path and returned {:http_error, 403, InvalidAccessKeyId} from
    s3.amazonaws.com — IMDS crash gone but still hitting the network (symptom, not
    root cause). POST-FIX (stub delegation removed): s3_tus_test.exs = 11 tests, 0
    failures BOTH with and without RINDLE_MINIO_* set. Full default suite with
    RINDLE_MINIO_* set = 1158 tests, 0 failures, 4 skipped (the @tag :minio cases),
    76 excluded.
  implication: |
    The exact failing CI condition now passes deterministically offline. Fix
    confirmed; no regression in the default suite.

## Eliminated

- hypothesis: "The branch-protection-flip change (commit ca70075) caused it."
  why: |
    That change only touches scripts/ci/*, setup_branch_protection.sh, the
    ci-summary/ci-script-tests jobs, and 105-UAT.md — nothing in lib/rindle/storage
    or test/. The failing tests and their code path are untouched by it. Pre-existing
    in the never-CI'd accumulated work.

## Resolution

root_cause: |
  Rindle.Support.S3MultipartRequestStub (the test request_module wired in
  config/test.exs) delegated to the real ExAws.request/2 whenever all four
  RINDLE_MINIO_* env vars were present (`minio_configured?/0`). The untagged,
  network-free TUS tail-buffer specs (s3_tus_test.exs) call S3.upload_part_stream/
  complete_part_stream with empty `aws_config: []`. In the CI jobs that set
  RINDLE_MINIO_* (Integration, Package Consumer) the stub therefore passed those
  calls through to real ExAws, which — with no static credentials anywhere
  (no config :ex_aws, no AWS_ACCESS_KEY_ID/SECRET) — walked its default credential
  chain to :instance_role and queried EC2 instance-metadata (IMDS), getting HTTP
  404 and raising RuntimeError. The Quality job sets no RINDLE_MINIO_*, so the stub
  stayed offline and the same tests passed — the cross-job discriminator.
fix: |
  1. test/support/s3_multipart_request_stub.ex: REPLACED the ambient-env
     `minio_configured?()` delegation check with an INTENT-based one — the stub
     delegates the three multipart ops to real `ExAws.request/2` only when the
     caller passed a non-empty `aws_config` (`config not in [nil, []]`), and
     fabricates offline responses otherwise. The untagged tail-buffer specs call
     `upload_part_stream`/`complete_part_stream` with NO `aws_config` (config == [])
     so they stay fully offline in every job (no network, no IMDS). The unused
     `minio_configured?/0` helper was removed.
     NOTE (correction to first-pass reasoning): simply removing the delegation
     branch entirely (the initial fix) WOULD have weakened real coverage — the
     `@tag :minio` multipart round-trip in s3_test.exs never overrides
     request_module, so it relies on this stub delegating; with delegation gone it
     would have received fabricated initiate/complete responses and silently lost
     its genuine MinIO round-trip. The intent-based check preserves it (s3_test.exs
     passes an explicit non-empty aws_config → delegated).
  2. config/test.exs: added deterministic dummy `config :ex_aws` static creds
     (access_key_id/secret_access_key/region) as defense-in-depth so the ExAws
     default chain can NEVER fall through to :instance_role/IMDS for any caller that
     passes empty aws_config. Per-call aws_config overrides in the MinIO tests still
     take precedence (ExAws merges overrides last).
verification: |
  Reproduced the CI failure condition locally (all four RINDLE_MINIO_* set to the
  CI values, no MinIO running). POST-FIX (intent-based delegation): s3_tus_test.exs
  = 11 tests, 0 failures; full default suite WITH MinIO env = 1158 tests, 0
  failures, 4 skipped (the @tag :minio cases), 76 excluded — no IMDS access on any
  path, and `mix format --check-formatted` clean. The :minio multipart round-trips
  (s3_test.exs explicit aws_config → delegated; tus_s3_integration_test.exs →
  request_module replaced) are preserved but not locally runnable (no real MinIO).
  Could not reproduce the live IMDS 404 directly (no EC2 metadata locally);
  verification relies on reproducing the delegation path that caused it.
files_changed:
  - test/support/s3_multipart_request_stub.ex
  - config/test.exs
