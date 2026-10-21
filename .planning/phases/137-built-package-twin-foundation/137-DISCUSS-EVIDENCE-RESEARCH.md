# Phase 137 evidence, security, SRE, and automation DX research

Researched 2026-10-21 in `/Users/jon/projects/rindle/.claude/worktrees/phase136-execution`.
Scope: discussion input, not implementation or acceptance evidence. Repository facts below refer to this worktree; external facts use first-party documentation. Recommendations and inferences are identified explicitly. No dependencies were installed, services started, tests run, or remote state changed for this research.

## Recommended direction

Build a small, dedicated external Phoenix consumer with one ordinary maintainer runner, scenario tests, a versioned JSON receipt, and a pure validator that derives acceptance from bounded observations. Use existing Jason and Elixir/OTP primitives. Keep orchestration outside the host runtime so a host restart does not restart the scenario or lose fault counters. Export only selected, typed, synthetic observations. Keep cleanup evidence separate from emergency infrastructure teardown. Begin with maintainer-local execution and fast validator/contract tests in the existing test lanes; defer broad CI matrix execution to Phase 138 after measuring its cost.

This is a test harness, not an attestation service, new public API, release authorization layer, or execution framework. D-134-01 explicitly targets at most six plans and three tasks per plan, forbids bespoke qualification/authorization/journal frameworks, and requires rescoping after two halts at the same gate (`.planning/phases/134-dependency-security-and-inbox-disposition/134-CONTEXT.md:26`). Borrow small proven functions when useful; do not import Phase 133/136's qualification machinery.

Every receipt and human-readable summary should carry this literal meaning: **Maintainer-operated synthetic evidence. Does not satisfy the named independent Phoenix pilot requirement and does not authorize a 1.0 claim.** This is a product boundary, not a disclaimer: `.planning/PROJECT.md:36`, `.planning/REQUIREMENTS.md:48`, and `.planning/ROADMAP.md:795` preserve it.

## Repository truth and lessons that constrain the design

| Evidence | Implication |
|---|---|
| Phase 137 requires a fresh external Hex artifact, host-owned services, documented seams, real database-backed jobs, restart, and schema-validated receipts (`.planning/ROADMAP.md:754`). | A receipt about a unit mock or repository-path demo cannot close the foundation requirements. |
| The six specific recovery scenarios belong to Phase 138; exact-head aggregate readiness belongs to Phase 139 (`.planning/ROADMAP.md:769`, `:784`). | Establish the reusable runner and genuine retry/restart proofs now, without pretending the full recovery matrix ran. |
| Existing generated workspace accepts an existing package directory (`test/install_smoke/support/generated_app/workspace.ex:22`); its provenance map reports fallback false (`:95`). | A new foundation must observe freshness and dependency origin, not copy these self-reported flags as acceptance. Preserve old receipts under their original claims. |
| Existing generated package receipt's `package_sha256` hashes `hex_metadata.config`, and separately hashes the unpacked tree (`test/install_smoke/support/generated_app_helper.ex:358`). | New receipt must name and hash the actual Hex archive bytes; metadata hash is not the package artifact hash. |
| Existing workspace cleanup ignores `File.rm_rf/1`'s result and returns `:ok` (`test/install_smoke/support/generated_app/workspace.ex:14`). | Use successful deletion plus postcondition observation; cleanup invocation alone cannot prove zero residue. |
| Existing generated command runner captures merged child output and interpolates it into raised failures (`test/install_smoke/support/generated_app/command_runner.ex:7`, `:41`). | Do not reuse this publication behavior for potentially credential-bearing HTTP/provider errors. |
| Phase 136's decoder rejects duplicate keys and nonfinite numbers, limits file sizes, checks artifact digests, and creates evidence exclusively (`scripts/maintainer/phase136_evidence.py:45`, `:145`, `:429`). | These are useful narrow implementation patterns. Copy only necessary pieces, with behavioral tests. |
| Phase 136 sanitization replaces inherited environment values selected by secret-like variable names (`scripts/maintainer/phase136_evidence.py:115`). | Helpful defense in depth, insufficient for presigned URLs, generated credentials, remote error bodies, encoded secrets, or unexpected metadata fields. |
| Qualification verify exits zero for an authentic blocked manifest (`scripts/maintainer/phase136_evidence.py:683`); learnings distinguish integrity from acceptance (`.planning/phases/136-measured-quality-and-ci-ratchets/136-LEARNINGS.md:28`). | Twin acceptance command must return nonzero for every failed, incomplete, unreadable, or skipped required scenario, even if the JSON is authentic and well formed. |
| Durable live tools must not consume phase directories (`.planning/phases/134-dependency-security-and-inbox-disposition/134-CONTEXT.md:32`). | Put reusable code at stable test/support or scripts paths. Accept an explicit receipt path. Phase artifacts can cite results without becoming runtime dependencies. |
| Artifact ledger retains Phase 133 receipts because a live verifier consumes their path (`scripts/maintainer/artifact_ledger.json:701`). | Do not rewrite/move historical evidence as part of this phase; do not create another archive-sensitive path dependency. |

The project DNA prefers behavior boundaries, explicit transactional ownership, metadata allowlists, layered CI, and no forced OTel dependency (`prompts/gsd-rindle-elixir-oss-dna.md:39`, `:95`, `:154`, `:175`). Bootstrap framing asks for copy-pasteable production-aware docs and one recommended direction, with routine decisions made by agents (`prompts/gsd-rindle-gsd-bootstrap-brief.md:54`, `:164`; `prompts/gsd-rindle-bootstrap-command.md:79`). The brand voice is precise and composed, with honest failure modes (`prompts/rindle-brand-book.md:76`, `:614`). This phase needs clear CLI output and documentation, not visual design or another console.

## Minimum foundation contract versus deferred enhancements

**Minimum in Phase 137:** one runner and isolated package consumer; a small source-owned scenario registry; actual archive/source/toolchain/selected-input identity; one real persisted retry and one actual runtime restart with one stimulus; a typed versioned receipt; independent semantic validation; safe output; owned-resource cleanup with authoritative observations; basic janitor idempotence; ordinary behavioral/negative tests. Keep the implementation within normal GSD execution and the established plan-size fence.

**Deferred to Phase 138:** the six full recovery scenarios and interruption-specific multipart/provider/AV cleanup checks. **Deferred to Phase 139:** aggregate exact-head/remote CI readiness closure. **Optional only with demonstrated demand:** JSON Schema interoperability, signing/attestation, OTel exporter, resource-dashboard UI, a separate scheduler, historical query store, generalized fault DSL, automatic CI topology changes, and broad repeated runtime matrices. None is a prerequisite for TWIN-06. Do not create extension points merely because later phases may need them.

## Decision matrix: receipt representation and validation

| Approach | Benefits | Costs / failure modes | Decision |
|---|---|---|---|
| A JSON map with schema version, explicit field/type checks and scenario predicates in a small Elixir module; existing Jason for encoding/decoding | No dependency growth, idiomatic host language, same assertions usable from ExUnit and CLI, semantic validation is explicit | Maintainer owns a small schema implementation; must test unknown/missing keys and nested variants | **Use.** Keep one authoritative shape and one scenario registry. Typespecs document the contract but do not perform runtime validation. |
| JSON Schema document plus a new validator package | Familiar portable shape vocabulary, good if multiple independent consumers later need the contract | New dependency and schema draft/version/security surface; semantic job/cleanup invariants still need Elixir; duplicated schema/assertions invite drift | Defer until a real external consumer makes interoperability valuable. Requirement says schema-validated, not that a JSON Schema dependency is mandatory. |
| Reuse the whole Python Phase 136 collector/qualification system | Has bounds, subprocess handling, source identities and prior tamper tests | Cross-language orchestration plus phase-specific authorities and history rules; larger maintenance burden than the twin | Do not extend it into a general twin platform. A tiny existing-language wrapper can invoke host tests without owning domain assertions. |
| Store only ExUnit/JUnit output or `passed: true` | Very simple | Cannot prove required observations, cleanup, same-subject binding, missing scenarios, real retries, or restart | Reject as sole receipt. Test exit and assertions remain required, alongside structured observations. |

Jason is already locked at 1.4.5 (`mix.lock:32`). It supports string keys and ordered-object decoding; use these to reject duplicate object keys recursively before converting to maps, and never create atoms from receipt input. [Jason documentation](https://hexdocs.pm/jason/Jason.html) documents these options and the atom-creation risk. This is a small decoder guard, not a second JSON parser.

Recommended validation rules:

- Reject unsupported schema versions, unknown keys, duplicate keys, malformed IDs/digests, invalid enums, negative counts, noninteger counts, oversized strings/arrays/files, unsafe evidence paths, and symlinks in evidence references.
- Use strings for external JSON keys; integer counts/offsets and sequence numbers; bounded duration values. A field being present is not evidence its observation succeeded.
- Require each registered scenario exactly once, with explicit executed/failed/not-run state. Keep an independently source-controlled expected scenario set; never infer the expected set from the submitted receipt.
- Recompute the scenario result from observations. Treat any stored `outcome` as redundant information to compare against the derived result, never as an authority.
- A shape-valid failed receipt is useful diagnostic evidence. The acceptance CLI still exits nonzero. There is no successful verification mode that silently promotes a blocked run.
- Write the final receipt atomically to a new run directory, retain failures, and refuse clobbering existing results. A small initial run descriptor can enable janitor discovery after an abort; it needs only owned resource identities, not an authorization or journal protocol.

## Minimal receipt contract

The following is a recommended field inventory, not a second implementation schema. Keep one JSON document per run with a keyed record per registered scenario, or one per scenario plus a small summary when that is easier for the runner. Avoid duplicated command-output trees and embedded base64 transcripts.

| Field group | Required observed facts | Validation / trust boundary |
|---|---|---|
| Identity | `schema_version`, `evidence_type`, explicit `independent_pilot_credit: false`, source SHA, actual archive SHA256, unpacked package digest when extracted material is what is compiled | Parent build step computes archive digest; external host reports package location/module origin; expected SHA and archive hash are supplied by the trusted runner, not read solely from the receipt being checked. |
| Reproduction inputs | Host/fixture/scenario-contract digest, generated host lockfile digest, normalized public configuration digest, Elixir/OTP/Hex/PostgreSQL/MinIO/media runtime versions or image digests actually used | Restrict configuration input to declared nonsecret values. Do not hash an entire environment or include credentials even in a hash input. Record effective values, not requested versions alone. |
| Execution | Run ID, scenario ID/version, attempt ID, start/finish time, process result, bounded failure code, required-step execution status | IDs distinguish reruns; wall time helps diagnosis but is not proof of freshness. Expected source/contract/package/scenario identities establish applicability. |
| Fault declaration | Existing documented boundary, exact operation, deterministic fail count, fixed failure class, delegated operation count | Wrapper records failure before delegating subsequent calls. These observations prove the injected condition occurred; they do not prove database retry by themselves. |
| Transitions | Sequence-numbered public state-change events plus selected public API/status snapshots before and after meaningful boundaries | Telemetry expresses observed transitions, while separately fetched public state proves durable outcome. Do not invent a transition merely because a command returned success. |
| Jobs | Host-owned `Oban.Job` ID, worker, state, attempt/max attempts, scheduled/attempted/completed times, bounded error class per persisted failed attempt | Read committed rows from an independent host Repo connection with real queues running. No raw job args, `errors[].error`, `unsaved_error`, or arbitrary inspect output in receipts. |
| External effects | Object count/size/digest for known synthetic media, status codes, provider surrogate effect IDs/counts, resumable offset where relevant | Query actual MinIO/provider surrogate state independently of wrapper invocation counters. A call recorded is not a completed side effect. |
| Restart | Old host runtime identity, observed termination, replacement runtime identity, durable pre-restart IDs, stimulus count, post-restart outcome | Parent driver outlives runtime; replacement connects to the same committed database and MinIO namespace; no second lifecycle stimulus. |
| Cleanup | Ordered public maintenance/API calls, result statuses, bounded errors, final resource inventory, completeness per resource class | Observe state before emergency teardown. A cleanup report or deleted-namespace flag alone is insufficient. |
| Residue | Database rows above approved bootstrap baseline, job states/counts, objects, multipart sessions, provider effects, temporary files, remaining child processes | Every count has a successful complete observation and declared scope. Unknown, denied, truncated, missing, and not-applicable are different states; only observed zero is zero. |

SLSA's applicable lesson is the separation of artifact identity, build inputs, execution details, and consumer expectations; it also recommends keeping parameters small and rejecting unexpected inputs. Borrow that structure, **not** an attestation protocol or a SLSA conformance claim. [SLSA provenance specification](https://slsa.dev/spec/v1.1/provenance). A checksum detects changed bytes when compared against a trusted digest. It does not establish who ran the test or whether a malicious collector fabricated all fields.

### Choose hashes by what can change the result

Recommended inputs: immutable source commit; actual tar archive; extracted material if applicable; host template/scenario source and fixture bytes; host `mix.lock`; selected public config and fault plan; schema/scenario contract version. Hash exact artifact bytes. If canonicalizing configuration, use a deliberately tiny representation with recursively sorted string keys and integer/string/boolean/null values; document order-sensitive arrays. No floating-point cross-language canonicalization library is needed.

Do not hash the entire worktree, every receipt, unrelated branding/planning history, machine home paths, caches, or secrets. Whole-checkout hashes are expensive and can bind evidence to documentation changes that cannot affect the run. Source SHA already identifies the revision; selected input identities explain the behavior. Require a clean dedicated source checkout for an acceptance run and reject mismatched expected HEAD rather than allowing arbitrary dirty execution and reconstructing commit ancestry afterward. Phase 139 owns the aggregate exact-head readiness decision (`.planning/REQUIREMENTS.md:66`).

Hex officially builds a local package archive without publishing it, and `--unpack` explicitly produces an unpacked directory. Build the archive once, hash its bytes, and compile the material extracted from **that same archive**; avoid two independently built artifacts being silently treated as identical. [Hex build documentation](https://hexdocs.pm/hex/Mix.Tasks.Hex.Build.html).

A current source SHA with an old scenario/host contract can still be stale evidence. Check all selected identities against caller expectations. Run ID uniqueness prevents accidental output collision; it is not an authenticity mechanism. Do not create a registry of spent source commits or prohibit ordinary reruns.

## Observations, independently asserted data, and honest limits

Use three distinct forms of evidence together:

1. **External driver facts:** package build/hash, child launch/exit, parent-observed runtime replacement, one submitted stimulus, expected scenario set.
2. **Supported host observations:** Rindle public API/status returns and public telemetry, host-owned Oban job rows, supported maintenance commands.
3. **Resource observations:** committed SQL inventory in the dedicated host database, S3-compatible object/multipart queries, provider surrogate effect store, and filesystem/process inventory inside the run namespace.

The validator checks relations across these sources. Examples:

- A storage wrapper returns one fixed transient delete error. The receipt must show the same persisted Oban job entering retryable with a recorded failed attempt and later completing on a higher attempt, while the relevant object is independently observed absent. `attempts: 2` from a wrapper counter is not enough.
- On host restart, the parent observes old runtime exit, starts a new runtime, reads the same durable asset/job identifiers, and never repeats the upload/attach/delete stimulus. A different runtime ID without observed termination is insufficient.
- A state-change event to ready is cross-checked with `Rindle.attachment_for/3` or another documented public status/read surface, its returned asset/variants, and actual object existence. Public read helpers return documented structures (`lib/rindle.ex:527`, `:571`). Fixed read-only Repo queries against documented public `MediaAsset`/`MediaVariant` schemas are also valid (`guides/core_concepts.md:14`, `:200`; `guides/troubleshooting.md:358`). Use these for exact retained/absent asset checks when a bounded degraded-status list cannot prove absence. No internal FSM calls, unsupported schema coupling, or direct lifecycle row mutations are needed.

Locked Oban 2.21.1 exposes persisted job attempt, state, error-attempt records, timestamps, and worker fields through its public schema. These are the appropriate host-owned database authority. [Oban.Job 2.21.1](https://hexdocs.pm/oban/2.21.1/Oban.Job.html). Real queues require testing disabled; inline/manual test modes do not establish autonomous supervised retry or restart. [Oban 2.21.1 configuration](https://hexdocs.pm/oban/2.21.1/Oban.html). Do not keep this multi-runtime scenario inside an Ecto SQL Sandbox transaction: connection ownership/rollback models process-scoped transactional tests, not independently committed runtimes. [Ecto SQL Sandbox](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html).

**Authenticity limit:** An offline validator can reject missing facts, contradictions, changed artifacts, incorrect identities, stale contracts, and nonzero residue. It cannot distinguish a wholly fabricated but internally consistent receipt from a genuine one if the attacker can rewrite all observations and their digests. The collector and its execution environment are trusted. Re-execute from trusted pinned source for consequential acceptance, and use ordinary CI run identity where CI provides the authority. Do not promise malicious-runner resistance through self-hashes, signatures made by the same runner, or more layers of JSON.

### Public boundary guard: static and dynamic checks complement each other

Recommended static guard scans **the twin host and harness**, with a narrow allowlist of documented Rindle entrypoints/configuration/behaviors. Reject repository-relative dependencies, private module calls, source-file reads, dynamic `apply/3` to Rindle internals, repository fixture imports, direct worker `perform` calls, inline Oban, and test-only overrides. The guard is a drift check, not an Elixir security sandbox.

Dynamic provenance checks establish the external dependency/build roots, fresh host compilation, absence of inherited repository BEAM/code paths, and the package module locations. Removing repository visibility from the host's filesystem/runtime makes the boundary stronger than searching source for forbidden strings. Clear inherited VM/code-path/Mix-build overrides and do not share `_build` output. Deliberately test a forbidden repository dependency and imported BEAM path; a static pass does not prove inaccessible private files.

Do not add a production API to make a private dependency easier to test. Documented public schemas are not private coupling merely because scenarios read them through the adopter Repo; forbid unsupported access and direct lifecycle writes, not every schema reference. A documented `@behaviour` alone does not prove a runtime-configurable seam exists; use the storage adapter that is actually configurable. Processor/AV recovery can later use real invalid media or executable failure plus supported repair, rather than introducing a twin-only processor injection interface. Public telemetry remains an observation surface whose vocabulary must be preserved (`guides/background_processing.md:161`).

## Security and redaction: prevent collection, then defend output

**Recommendation:** Project from raw observations into allowlisted typed fields before serialization. Reject unknown receipt fields. Keep arbitrary errors, request/response bodies, session URIs, headers, signed URLs, database connection strings, provider payloads, environment dumps, and raw stderr out of durable evidence. This follows the existing resumable telemetry owner's allowlist pattern (`lib/rindle/upload/resumable_telemetry.ex:11`, `:117`) and project DNA (`prompts/gsd-rindle-elixir-oss-dna.md:154`).

| Surface | Common leak | Safe exported representation |
|---|---|---|
| HTTP/tus/presigned upload | Query-string signatures, Authorization, cookies, session URI, response body | Fixed operation name, status code, byte/offset counts, run-local synthetic label; URL omitted or limited to known endpoint label |
| Storage/provider errors | SDK exception contains URL, XML body, account details, signed response | Bounded known error code/class and numeric status; unexpected error becomes `unexpected_dependency_error` |
| Oban errors | Persisted formatted error string includes request arguments, media path or credential | Attempt number, timestamp, state, explicit safe error classification; no raw formatted string |
| Logging/telemetry | Correct key has a secret-bearing string value; unknown nested key bypasses blacklist | Event-name allowlist plus per-event selected typed metadata; reject credential canaries in raw captured events in memory before projection |
| Child stderr/stdout | FFmpeg input URI, `mix` config inspection, crash dump, access log request target | Private transient capture with bounds; emit only safe stage/error code and selected sanitized lines when provably safe |
| Fixture/object labels | Real customer names, URLs, user identifiers | Generated synthetic fixture names and run-local labels; allow only bundled deterministic fixtures for baseline scenarios |

A blacklist of names is not sufficient: `reason`, `message`, and an otherwise allowed string can contain credentials. Replacing environment secret values is insufficient for generated/upload credentials and encoded values. Avoid hashing raw secrets or tiny secret-bearing bodies merely to preserve a diagnostic fingerprint; a hash is not universal redaction.

Use a small public diagnostic envelope: `stage`, `reason_code`, `dependency`, `exit_status`, `timed_out`, `retryable`. Build readable summaries from this envelope. Sanitization is defense in depth for necessary diagnostics, not permission to upload arbitrary subprocess logs. Do not let exception handlers print the raw error while attempting to report a redaction failure.

OWASP explicitly identifies access/session tokens, passwords, connection strings, and keys as logging exclusions, and calls for log-data validation/sanitization and injection protection. [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html). Apply this to receipts, console output, failure messages, artifact filenames, process command lines, HTTP access logs, and CI uploads—not just the final JSON.

Recommended negative cases inject distinguishable secret canaries into nested metadata, signed URL query values, request/response bodies, SDK errors, job failure text, stderr, and access logs. Assert no canary appears in **any** exported output; also assert the expected failure remains observable through safe codes. Catching a leak after publicly streaming the raw line is too late. Phase 137 proves export safety; Phase 138's provider-event scenario additionally proves the production telemetry path does not emit secret-bearing metadata (`.planning/REQUIREMENTS.md:60`).

## SRE: resource ownership, cleanup, and janitor

Use one unique run namespace across a dedicated database, MinIO bucket or strong run prefix, host processes, temporary root, and provider-surrogate effect store. Prefer a dedicated bucket/database where current public operations lack fine-grained filters. Avoid pointing this runner at shared developer or production resources. Validate ownership identities and endpoints before mutations. Synthetic namespaces and local services avoid live API spend and credentials for the baseline.

A run's small resource descriptor contains only run ID, owned resource names, parent-generated creation time, fixed local endpoint labels, and selected contract version. Save it before the first creation so janitor can rediscover resources if allocation partly fails. Do not invent an event ledger, authorization capsule, or state machine framework. Janitor reconstructs ownership from the descriptor and names; it never trusts arbitrary receipt-provided deletion paths. Refuse symlinks, path escape, missing namespace prefix, or a live run ownership lock.

### Distinguish domain cleanup from infrastructure disposal

**Domain cleanup:** exercise the documented API/maintenance sequence and observe its effects. **Infrastructure disposal:** stop processes and remove the private database/bucket/workspace after observation. Both are necessary, but forced disposal must not overwrite a failed cleanup result.

Rindle's public sequence is abort expired/incomplete uploads, then explicitly live cleanup of expired sessions, with a separate temp sweep. Both cleanup and sweep default to dry-run; task exit zero includes dry-run/zero-match success (`lib/mix/tasks/rindle.abort_incomplete_uploads.ex:5`, `lib/mix/tasks/rindle.cleanup_orphans.ex:13`, `lib/mix/tasks/rindle.sweep_orphaned_temp_files.ex:15`). Use explicit destructive flags within the disposable namespace. No CLI exit zero should be translated directly into `residue: 0`. Owner/account removal uses `Rindle.erase_owner/2`; upload-maintenance is not a replacement (`guides/operations.md:18`, `:58`).

| Resource | Authoritative final observation | Reject / important limit |
|---|---|---|
| Domain rows | Public lifecycle/owner/status APIs or fixed documented read-only public-schema queries, plus schema-agnostic inventory of user relations in the **dedicated host database**, compared with a declared bootstrap baseline | Do not couple to private Rindle Ecto modules or mutate lifecycle rows. Any catalog/count permission error is unknown, not empty. Baseline exceptions identify reason and bounded count/rule; account explicitly for migrations and legitimate host/Oban infrastructure metadata. A booted baseline and stopped final host can differ legitimately; do not require every table to equal zero or silently approve every row matching a broad prefix. |
| Oban jobs | Host Repo queries `Oban.Job`; count each state and compare to explicit retained-history policy, then dispose owned DB | Running/available/scheduled/retryable jobs are unapproved after terminal cleanup. Completed history is not a leak if explicitly bounded and approved before disposal. Capture terminal states and attempts before host-owned job cleanup; verify removal separately before database disposal. Infrastructure metadata/peers have an explicit allowance, not an implicit all-tables-zero rule. |
| Objects | Complete successful paginated listing for the owned bucket/prefix; HEAD known created keys where useful | Delete response or wrapped delete counter is insufficient. Failed listing, wrong prefix, first-page-only listing, or `403` is not zero. Baseline bucket versioning is off; if enabled, enumerate versions/delete markers or reject unsupported config. |
| Multipart | Separate complete multipart-upload inventory and part verification for known interrupted uploads | Listing objects does not enumerate incomplete multipart uploads. S3 pagination and concurrent part-upload semantics require special handling; MinIO proof remains local S3-compatible evidence, not AWS certification. |
| Provider effects | Enumerate the controlled local surrogate's effect store under run ID; verify deduplicated effects and deletion/absence | A wrapper invocation count does not prove provider state. A cassette is not live-provider evidence. Missing live credentials means not-run, not passed. |
| Temporary files | Enumerate isolated Rindle temp root after public sweep; count files/dirs and observe filesystem errors | Workspace deletion can hide failed temp cleanup. Capture pre-disposal inventory; no symlink traversal. |
| Processes | Parent-observed child exits and owned process-group/container shutdown, with descendant/residue check | Killing only an Elixir Task around a command does not establish child/FFmpeg termination. Never global `pkill` or remove unrelated resources. |

S3's object and multipart lists are different authorities. Multipart listing is paginated, and aborting while parts are in flight can require another abort plus part verification. [ListMultipartUploads API](https://docs.aws.amazon.com/AmazonS3/latest/API/API_ListMultipartUploads.html), [AbortMultipartUpload API](https://docs.aws.amazon.com/AmazonS3/latest/API/API_AbortMultipartUpload.html). Recommended implementation stops new writers before final absence checks; it does not poll until an arbitrary empty response happens to appear.

A schema-agnostic SQL inventory is an **operator-owned infrastructure observation**, not a supported Rindle domain API. It can count owned relations without baking library table names/column assumptions into scenarios. If the public cleanup contract intentionally retains terminal domain rows, name and bound that exception in the scenario; do not silently truncate those tables and claim Rindle cleaned them. If a required domain claim cannot be observed through existing public contracts and schema-agnostic inventory, record the gap and resolve scope before adding a new API.

### Interruptions and bounded retention

- Register cleanup immediately after each successful allocation. Parent `after`/trap handlers perform best-effort cleanup for ordinary failure and TERM/INT. SIGKILL, power loss, and CI cancellation may bypass these handlers; janitor is required.
- Keep the driver separate from the supervised runtime. Fault counters/effect store and run ownership must survive a child restart. A tiny fixed host-owned PostgreSQL table is a reasonable counter implementation using the existing Repo, with no new storage dependency or file-locking protocol. Capture committed stage and job IDs before stopping it. A runtime stop must not resubmit stimulus.
- Give startup, readiness, each scenario, cleanup, and total execution explicit deadlines. Poll observable conditions with bounded intervals/backoff; avoid hardcoded sleep-as-proof and automatic rerun-until-green.
- Janitor can be rerun idempotently for abandoned namespaces, and should produce a fresh cleanup observation rather than edit the original failed receipt. Refuse active runs and any resource outside the descriptor's validated namespace.
- Default: raw transient output and media workspaces removed at completion; interrupted raw captures private and janitored within 24 hours. Retain redacted receipts plus safe diagnostic summary for 14 days in CI, and retain a compact final acceptance receipt with milestone records. No indefinite debug-resource preservation by default. These are recommended local policy values, not externally mandated requirements.
- Preserve the initial failed receipt when cleanup later succeeds. Phase 138's interrupted-cleanup test proves janitor convergence; Phase 137 supplies and exercises basic idempotent cleanup and the restartable ownership model (`.planning/REQUIREMENTS.md:62`).

GitHub supports bounded artifact retention; the repository already uses 14-day JUnit/coverage retention (`.github/workflows/ci.yml:245`). Upload only allowlisted redacted files rather than a workspace glob. [GitHub artifact documentation](https://docs.github.com/en/actions/tutorials/store-and-share-data).

## Successful ecosystem patterns to copy selectively

| Primary source / pattern | Useful lesson | Rindle application / tradeoff |
|---|---|---|
| [Shrine testing](https://shrinerb.com/docs/testing) distinguishes fast in-memory tests from MinIO integration | Keep cheap unit contracts and real external-service proof as different evidence classes | Continue ordinary mocks/unit tests for fast checks; use actual MinIO for the twin. Do not replace the suite with expensive system tests, or label memory-adapter proof as storage recovery. |
| [Rails Active Storage testing](https://guides.rubyonrails.org/active_storage_overview.html#discarding-files-created-during-tests) explains why transactional test rollback does not clean external files and why parallel runs need separate roots | Database rollback is not object cleanup; isolate roots per worker | Dedicated twin DB/bucket/temp namespaces, explicit teardown, authoritative postconditions. |
| [pytest safe fixture structure](https://docs.pytest.org/en/stable/how-to/fixtures.html#safe-fixture-structure) couples each allocation with its cleanup | Partial setup failures must not skip earlier cleanup | Small Elixir setup functions or ordinary `try/after`; no new fixture DSL or package required. |
| [Testcontainers readiness](https://java.testcontainers.org/features/startup_and_waits/) separates running processes from ready services | A container started is not a usable DB/storage/host | Probe migrations/DB connectivity, MinIO API, host supported doctor, and real queue consumption before scenarios; reuse current Compose/service tools. |
| [Testcontainers reuse guidance](https://java.testcontainers.org/features/reuse/) explicitly cautions against reusable containers in CI | Reuse can trade startup speed for stale state and cleanup ambiguity | Fresh namespaces for acceptance; optional cached dependency downloads must not mean shared BEAM output or persistent scenario state. No need to add Testcontainers itself. |
| [Oban public APIs](https://hexdocs.pm/oban/2.21.1/Oban.html) keep history, queue control, cancellation, and supervision in the existing queue system | Use the real durable queue rather than a second scheduler | Read `Oban.Job` and use host-owned queues/public cancellation. Tune supported test-host timing conservatively without patching library backoff or marking directly performed jobs as real retries. |
| [SLSA provenance](https://slsa.dev/spec/v1.1/provenance) makes consumer expectations explicit | Bind what was built and which inputs influenced it | Small source/package/toolchain/contract identities, with no attestation framework, signing/key management, or claimed security level. |

These are architectural inferences from successful projects' own documentation; they are not evidence that those projects implement Rindle's scenario or guarantee equivalent behavior. Prior local media research highlighted the same external cleanup/async persistence lessons (`prompts/phoenix-media-uploads-lib-deep-research.md:67`), and the adoption lab already treats Cohort and generated consumers as complementary (`.planning/threads/adoption-evidence-lab.md:7`). Preserve that separation.

## CI architecture and consumer-facing automation DX

The existing CI topology deliberately runs representative image package proof on PRs and broader profiles on main/release (`RUNNING.md:43`, `.github/workflows/ci.yml:616`, `:742`). `CI Summary` omits the conditionally skipped full package lane; release uses the exact push-main workflow conclusion (`.github/workflows/ci.yml:1522`). Broad compatibility/Dialyzer/live GCS belong to Nightly, whose missing/skipped semantics are explicit (`RUNNING.md:49`). Do not change those identities casually or make synthetic local evidence stand in for a missing remote gate.

**Recommended Phase 137 placement:** one documented maintainer-local twin command, with fast receipt/contract/redaction/forbidden-boundary tests in ordinary existing Quality/CI Script Tests as appropriate. No new required PR job, no provider secrets, no full matrix on the PR critical path, and no new readiness aggregation service. Record one real measured runtime and failure path. Phase 138 can place a measured representative/full matrix in an existing appropriate main-only package proof or Nightly lane; execute once per applicable toolchain/profile rather than duplicating it in every existing lane. Phase 139 consumes the actual result and expected identities and remains fail-closed. This fits `.planning/PROJECT.md:44`'s cost-justified CI policy and avoids reintroducing the speed burden that remains explicitly unfinished (`.planning/PROJECT.md:28`).

An alternative is to add a representative twin immediately to the existing main-only `package-consumer-full` image leg. It gains continuous drift detection but adds expensive work before its runtime/flakiness profile is known. Prefer that only if implementation measurement shows a small justified cost; adding a dedicated workflow/required context is unnecessary for foundation acceptance.

The maintainer-facing flow should offer, conceptually:

1. `check` — read-only prerequisite/configuration validation, with fixed safe errors and no installs or resource allocation.
2. `run [scenario]` — build once, run registered foundation scenarios against external package, emit receipt, clean up, exit nonzero on failure or unapproved residue.
3. `verify RECEIPT` — pure bounded validation against caller-provided expected source/package/contract identities; no silent rebuilding or live-service mutation.
4. `cleanup RUN_ID` — idempotent janitor for exactly the owned abandoned namespace.

These are subcommands of one small runner, not four services or new public Rindle Mix tasks. Choose exact names during implementation and document copy-pasteable commands, prerequisites, output location, resource ownership, exit meanings, and one-scenario reproduction. `check` must report missing dependencies; it should not install them behind the user's back. Build archive and host deps once per run; never require editing workflow YAML to understand local prerequisites (`RUNNING.md:34`, `:151`).

Example human summary: `synthetic twin: failed; scenario=storage_retry; stage=cleanup_inventory; reason=multipart_inventory_unreadable; receipt=<safe relative path>`. This conveys the next diagnostic step without exposing request data. The receipt can preserve successful earlier observations, but a later cleanup or export-safety failure still makes acceptance red.

## Adversarial pass and required behavioral regressions

These tests should exercise validator/runner behavior, not assert implementation strings. They are implementation recommendations, not tests executed for this research.

| Adversary / fault | Naive false success | Required rejection / check |
|---|---|---|
| Old receipt copied into current run | Top-level SHA edited or timestamp refreshed | Trusted expected archive/source/host-contract/scenario identities and actual consumed artifact differ; fail before counting it. |
| Changed receipt with rehashed sidecars | Every digest is internally consistent | Semantic invariants reject contradictions; wholly consistent fabrication remains outside offline trust. Require trusted collection/rerun for acceptance; make no malicious-runner claim. |
| Missing scenario or skipped provider path | Only present successes aggregated | Source-owned expected scenario set compared exactly; missing/not-run/partial is not accepted. Explicit inapplicable resource class must be predeclared by scenario, not opportunistically omitted. |
| `passed: true` with one job attempt | Wrapper's fail-N counter mistaken for retry | Committed Oban attempt/error/state evidence and later completion of same job required. |
| Fake restart with second stimulus | New process creates a fresh asset that succeeds | Parent-observed old exit, new runtime, preserved asset/job identity, exactly one input stimulus and bounded external effect cardinality. |
| Cleanup task in default dry-run | Exit zero and report printed | Explicit live execution plus complete final inventories; a dry-run receipt cannot pass cleanup. |
| Forbidden/failed object list becomes empty array | Zero reported despite `403`, timeout, or wrong namespace | Inventory status/completeness/scope checked independently; error means unknown and failure. |
| Unfinished multipart upload | Object list empty | Separate multipart/parts inventory rejects; pagination must terminate correctly. |
| DB/bucket force-drop before observation | Empty final system hides broken Rindle cleanup | Preserve pre-disposal domain observations and failure; force disposal only protects environment. |
| Secret in allowed metadata `reason` | Key allowlist passes | Typed bounded reason enums and secret canaries across all exported outputs. Raw telemetry additionally checked where telemetry-safety claim is made. |
| Secret-bearing SDK/FFmpeg failure | Receipt clean but stacktrace/CI log leaks | Capture before publication; safe diagnostic envelope; canary test includes stderr, exceptions, access logs, filenames, process args. |
| Cleanup runner killed after resource creation | `after` assumed sufficient | Janitor rediscovers validated namespace from prewritten descriptor; preserves failed receipt; repeated cleanup succeeds without touching decoy resources. |
| Symlink/path escape/PID reuse | Cleanup deletes another run's data or kills unrelated process | Canonical namespace/root checks, no symlink traversal, owned process-group/container identity, decoy resource test. |
| Boundary guard bypass via dynamic call | Static forbidden-string search passes | Host filesystem/code-path isolation plus deliberate forbidden-import tests; document that guard is drift detection, not a complete sandbox. |
| Output flood or stuck dependency | Runner never terminates or fills disk | Per-stage deadline, output/receipt size limits, process-group termination, final residue scan. |

Phase 137 should implement the high-value foundation subset: malformed/forged green receipt, wrong source/archive, missing required scenario, actual retry, actual restart without duplicate stimulus, dry-run/failed cleanup rejection, output redaction, namespace isolation, and janitor idempotence. Phase 138 owns the full interruption matrix including multipart/provider/AV-specific convergence and deliberately interrupted cleanup. Phase 139 owns remote exact-head readiness and aggregate stale/partial/skipped evidence rejection. All three retain the synthetic-only label.

## Consequential uncertainty and escalation boundary

No routine choice here needs a maintainer question: use existing Jason, one simple receipt validator, local-first execution, documented public seams, one owned namespace, a bounded safe-output policy, and ordinary GSD plans/tests. Do not reopen receipt wording, helper names, or minor schema layout in discussion.

Escalate only if implementation demonstrates one of these concrete conditions: a required lifecycle claim cannot be observed or driven through existing supported public contracts; proposed cleanup would affect shared/live resources; live provider credentials/spend are newly necessary; a production API/schema/telemetry change is required; or CI scheduling materially changes the release gate or adds unjustified recurring cost. Otherwise record the evidence and make the routine choice. If the same gate fails twice, rescope under D-134-01 instead of inventing a new evidence protocol.


## Validation Architecture

Planning normalization of the existing research above; no new runtime evidence.
Use the repository's existing ExUnit/Jason and shell tooling, without a new test
dependency. Fast tests exercise receipt semantics through valid fixtures and
mutations, staged-package/public-boundary rejection, persistent fault consumption,
redaction canaries and namespace-safe cleanup against decoys. Each new executable
command must be created by its owning task before it is used for acceptance.

A bounded Docker/Compose run is the acceptance authority for the combined image
tracer: fresh external archive, ordinary Repo/default Oban, real MinIO, committed
first-attempt failure, quiescent restart barrier, observed runtime replacement,
same-job automatic completion, terminal observations and complete cleanup. Fast
fixture tests cannot substitute for this run. Verify receipts independently with
trusted expected identities; missing/unknown/skipped evidence and nonzero residue
fail. Record elapsed time rather than promising a fabricated runtime budget.

Automate every TWIN-01–06 predicate. No human verification closes a requirement.
Map per-task commands and threat references in 137-VALIDATION.md as plans become
concrete; mark new test paths as pending creation and do not claim them green.
Preserve existing CI topology and run the automation-first contract whenever
active planning artifacts change. Full RECOV coverage remains Phase 138.
