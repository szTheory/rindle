# Phase 122: Live Truth & Compile Clarity - Pattern Map

**Mapped:** 2026-08-22  
**Files analyzed:** 16 likely modified/tested surfaces  
**Analogs found:** 16 / 16

This map is based on the approved phase context and roadmap/requirements, the verified Phase 121
SAFE-01 contract, and current shipped source, tests, and documentation. Historical
`.planning/milestones/` and Phase 121 artifacts are intentionally out of implementation scope.

## File Classification

| New/Modified File | Role | Data flow | Closest analog | Match quality |
|---|---|---|---|---|
| `lib/rindle/schema.ex` | compile-time macro / utility | transform | current `Rindle.Schema` macro and validator | exact |
| `test/rindle/schema_prefix_contract_test.exs` | structural + behavior test | transform | current AST/source and dynamic-consumer guard | exact |
| `test/rindle/config/config_test.exs` | public-behavior test | transform | current compile-time prefix authority tests | exact |
| `test/rindle/schema_prefix_integration_test.exs` | integration test | CRUD / request-response | current selected-versus-decoy schema test | exact |
| `test/support/schema_prefix_case.ex` | test support | CRUD | current two-prefix fixture | exact |
| `scripts/maintainer/refactor_contract.sh` | preservation runner config | batch | Phase 121 SAFE-01 runner | exact |
| `test/install_smoke/refactor_contract_test.exs` | runner-meta test | transform | current SAFE-01 runner test | exact |
| `test/install_smoke/docs_parity_test.exs` | docs parity test | file-I/O | current current-doc parity suite | exact |
| `test/install_smoke/phoenix_tus_truth_parity_test.exs` | docs/source parity test | file-I/O | shipped-artifacts-only truth test | exact |
| `test/planning_path_hygiene_test.exs` | scope guard test | file-I/O | current no-planning-runtime-read lock | exact |
| `README.md`, `CONTRIBUTING.md`, `RUNNING.md` | adopter / maintainer docs | transform | `DocsParityTest` setup + narrow assertions | role-match |
| `guides/admin_console.md`, `guides/admin_console_ia.md`, `guides/admin_design_system.md` | operator docs | transform | canonical nav-label contract | exact |
| `guides/resumable_uploads.md`, `guides/streaming_providers.md` | adopter docs | transform | Phoenix tus and streaming cancellation parity tests | exact |
| selected live `lib/**/*.ex` and `test/**/*.exs` comments | source / test rationale | transform | semantic `why:` and public-contract comments | role-match |

## Pattern Assignments

### `lib/rindle/schema.ex` (compile-time macro, transform)

**Analog:** current [`lib/rindle/schema.ex`](../../../lib/rindle/schema.ex), lines 4-17 and 28-84.

The cycle originates in a compile-time macro module holding a literal list of six domain-module
aliases (lines 5-12), while each of those domains `use Rindle.Schema`. Retain every externally
observed macro outcome; remove only the compile dependency direction from `Rindle.Schema` to its
consumers.

**Prefix ownership pattern** (lines 4-26):

```elixir
@supported_prefixes ["rindle", "public"]
@rindle_prefix Application.compile_env(:rindle, :rindle_prefix, "rindle")

unless @rindle_prefix in @supported_prefixes do
  raise ArgumentError,
        "expected :rindle_prefix to be one of \"rindle\" or \"public\", got: #{inspect(@rindle_prefix)}"
end

def prefix, do: @rindle_prefix
def supported_prefixes, do: @supported_prefixes
```

**Macro and post-compile invariant** (lines 28-68):

```elixir
defmacro __using__(_opts) do
  validate_owned_schema!(__CALLER__.module)
  prefix = Rindle.Schema.prefix()

  quote bind_quoted: [prefix: prefix] do
    use Ecto.Schema
    import Ecto.Schema, except: [schema: 2]
    import Rindle.Schema, only: [schema: 2]
    @primary_key {:id, :binary_id, autogenerate: true}
    @foreign_key_type :binary_id
    @schema_prefix prefix
    @after_compile Rindle.Schema
  end
end
```

**Implementation caution:** The equivalent owner allowlist must be a non-alias representation
(for example, module-name segments or strings compared to `__CALLER__.module`), not another
compile-time reference to the six domain modules. Do not drop the rejection guard or the
`@after_compile` check merely to make the cycle disappear. Keep `prefix/0`,
`supported_prefixes/0`, `validate_prefix!/1`, exception classes/messages, and macro-generated
metadata compatible unless a test proves an intentionally internal-only wording change.

### Six `lib/rindle/domain/media_*.ex` schemas (model, transform)

**Analogs:** `MediaAsset` lines 28-69, `MediaAttachment` lines 23-35,
`MediaProcessingRun` lines 16-32, `MediaProviderAsset` lines 32-59,
`MediaUploadSession` lines 27-54, and `MediaVariant` lines 27-50.

Every owned schema currently begins with the same narrow shape:

```elixir
use Rindle.Schema
import Ecto.Changeset

schema "media_assets" do
  # fields and associations
end
```

**Implementation caution:** These modules should not need a source-level rewrite. Keeping their
`use Rindle.Schema` shape is the lowest-risk proof that the shared prefix ownership boundary stays
centralized; moving six copies to raw `Ecto.Schema` would alter the boundary the contract protects.

### `test/rindle/schema_prefix_contract_test.exs` (structural + behavior test, transform)

**Analog:** current file lines 4-112.

The existing test combines (1) source-AST guardrails for all six owned schemas, (2) runtime
metadata compatibility checks, and (3) a dynamically compiled hostile consumer. Preserve that
three-layer design.

**Structural and runtime metadata pattern** (lines 4-40):

```elixir
for schema <- @domain_schemas do
  source = schema.module_info(:compile)[:source] |> to_string()
  {:ok, ast} = Code.string_to_quoted(File.read!(source))

  assert uses_rindle_schema?(ast)
  refute uses_ecto_schema_directly?(ast)
  refute imports_ecto_schema_directly?(ast)
  refute calls_ecto_schema_directly?(ast)
  refute sets_schema_prefix_directly?(ast)

  assert schema.__schema__(:prefix) == Rindle.Schema.prefix()
  assert struct(schema).__meta__.prefix == Rindle.Schema.prefix()
end
```

**Hostile-consumer guard** (lines 43-112):

```elixir
error =
  assert_raise ArgumentError, fn ->
    module
    |> raw_ecto_callback_deletion_consumer_source(actual_prefix)
    |> Code.compile_string()
  end

assert Exception.message(error) =~ inspect(module)
assert Exception.message(error) =~ "internal"
```

**Cycle-regression test caution:** Do not assert compiler implementation details by grepping a
cached `_build` graph. Prefer a stable source invariant: `lib/rindle/schema.ex` must not contain
the six `Rindle.Domain.Media*` aliases (or a direct, equivalent list), while the existing dynamic
consumer test keeps owner validation real. If a fresh compile test is added, use a clean targeted
build invocation and assert only success/no cycle diagnostic—not incidental compiler ordering.

### `test/rindle/config/config_test.exs` and `test/rindle/schema_prefix_integration_test.exs` (behavior/integration tests, transform and CRUD)

**Analogs:** config test lines 72-112; integration test lines 8-60;
[`test/support/schema_prefix_case.ex`](../../../test/support/schema_prefix_case.ex) lines 18-75.

**Compile-time ownership pattern**:

```elixir
Application.put_env(:rindle, :rindle_prefix, configured_prefix)
assert configured_prefix != Rindle.Schema.prefix()

for schema <- owned_schemas do
  assert Rindle.Schema.prefix() == schema.__schema__(:prefix)
  assert Rindle.Schema.prefix() == struct(schema).__meta__.prefix
end
```

**Selected-versus-decoy persistence pattern**:

```elixir
assert {:ok, attachment} = Rindle.attach(selected, owner, "avatar")
assert attachment.__meta__.prefix == selected_prefix
assert Repo.get(MediaAsset, decoy.id) == nil
```

**Implementation caution:** `async: false` is intentional for tests mutating application prefix
config or using the shared SQL sandbox. Continue proving both `__schema__(:prefix)` and
`__meta__.prefix`, plus an actual facade/worker persistence path, so metadata compatibility is not
mistaken for routing compatibility.

### `scripts/maintainer/refactor_contract.sh` and `test/install_smoke/refactor_contract_test.exs` (batch config + meta test)

**Analog:** script lines 1-16 and test lines 6-56.

The SAFE-01 runner is a single foreground command with deterministic seed and explicitly selected
contract suites:

```bash
exec mix test --include contract --seed 0 \
  test/rindle/api_surface_boundary_test.exs \
  test/rindle/schema_prefix_contract_test.exs \
  ...
```

When Phase 122 adds a durable compile-cycle or docs-truth proof, add it to both `@required_suites`
and the script only if it is a preservation-domain test—not a cosmetic source snapshot. Keep the
runner planning-independent, fail-closed, single-process, and free of output masking, exactly as
the meta-test requires.

### `test/install_smoke/docs_parity_test.exs` (docs parity test, file-I/O)

**Analog:** lines 7-49, 705-757, 781-843, and 901-940.

This is the canonical current-document parity shape: module attributes name real shipped files,
`setup_all` reads them once, then narrow tests assert a behavior-facing sentence/token and reject
the exact stale statement.

```elixir
@running_path Path.expand("../../RUNNING.md", __DIR__)

setup_all do
  {:ok, %{running: File.read!(@running_path)}}
end

test "running guide documents proof job as merge-blocking", %{running: running} do
  assert running =~ "`proof`"
  assert running =~ "merge-blocking"
  refute running =~ "Canonical lifecycle + doc parity"
end
```

For the navigation contract, use the six labels rendered by `Rindle.Admin.Components` and frozen by
the primary Admin behavior tests: `Overview`, `Assets`, `Upload sessions`, `Processing`, `Doctor`, and
`Maintenance`. The current guide spellings `Home/Status`, `Variants/Jobs`, `Runtime/Doctor`, and
`Actions` are retired navigation labels and must be rejected by the corrected parity contract. Verify
README/guide claims against `guides/admin_console.md`'s unchanged route table and the live router/UI
tests rather than adding a second vocabulary or changing route suffixes/active keys.

**Caution:** Do not turn this into a whole-doc byte snapshot. Assert only stable shipped claims:
CI lane placement/severity, documented support posture, exact navigation labels, and active tus /
streaming behavior. Avoid historical version/Phase sentences when the claim itself remains useful;
rewrite them to explain the domain reason.

### `test/install_smoke/phoenix_tus_truth_parity_test.exs` and `test/install_smoke/streaming_cancel_docs_parity_test.exs` (cross-surface parity tests, file-I/O)

**Analogs:** Phoenix tus test lines 16-67; streaming cancel test lines 4-19.

Use the existing three-surface parity approach when an adopter guide must agree with source and
generated-app proof:

```elixir
guide = File.read!(@guide_path)
live_view = File.read!(@live_view_path)
generated_helper = File.read!(@generated_helper_path)

assert guide =~ "allow_tus_upload/4"
assert live_view =~ "allow_tus_upload/4"
assert generated_helper =~ "allow_tus_upload("
```

The intentional pattern is current shipped truth only. The Phoenix test explicitly explains why
planning-path assertions were removed (lines 6-12); retain that boundary while replacing old
Phase/Plan/EXPECTED-RED commentary in the test name/moduledoc with the behavioral reason.

### `test/planning_path_hygiene_test.exs` (scope guard, file-I/O)

**Analog:** lines 22-83.

The anti-coupling guard scans all `test/**/*.exs`, fails on a runtime `File.read!`/`File.exists?`/
`Path.expand` call that names `.planning`, and deliberately constructs its own regex token in
fragments. It establishes the Phase 122 rule for all new parity tests:

```elixir
@planning_dir_token "." <> "planning"
@planning_read_regex Regex.compile!(
  "(File\\.(read!|exists\\?)|Path\\.expand)[^)]*" <> Regex.escape(@planning_dir_token)
)
```

**Caution:** Historical planning archives may mention phases and plans; do not edit them and do
not read them from merge-blocking tests. A current-source cleanup guard, if introduced, must
explicitly scope `lib/`, current `test/`, scripts, docs, and workflows; it must exclude
`CHANGELOG.md`, `prompts/`, `.planning/`, generated/vendor directories, and fixtures whose literal
is test data.

## Shared Patterns

### Domain rationale instead of delivery-process residue

**Source examples:** `test/rindle/config/config_test.exs` lines 4-8 and
`test/support/schema_prefix_case.ex` lines 25-38.

Use a concise `# why:` comment only where the code would otherwise hide an unusual safety choice,
and state the runtime reason (global app-env mutation, selected-versus-decoy routing), not the
phase or plan that introduced it. Existing domain moduledocs in the six schema modules demonstrate
the desired alternative: state invariants, ownership, and operator consequences.

### Preserve public metadata, not source mechanics

**Source:** `schema_prefix_contract_test.exs` lines 34-40 and
`schema_prefix_integration_test.exs` lines 8-60.

Public compatibility is the tuple of shared `Rindle.Schema.prefix/0`, each owned schema's
`__schema__(:prefix)`, a fresh struct's `__meta__.prefix`, and real facade/worker reads and writes
in the selected schema. Those are the regression targets; exact internal data representation is
not.

### Current-document truth is independently checked

**Source:** `docs_parity_test.exs` lines 734-757 and 901-940.

Pair a positive shipped assertion with a negative stale-claim assertion where a prior false claim
is likely to return. Keep assertions focused enough that normal wording improvements remain
possible. The CI `proof` job already runs `docs_parity_test.exs`
([`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml) lines 502-555), so no new lane is
needed for a docs-parity extension.

## No Analog Found

| File / concern | Role | Data flow | Guidance |
|---|---|---|---|
| Optional dedicated compile-graph regression test | test | transform | No existing test asserts module compile edges. Add only if source-invariant plus fresh compile proof cannot be expressed cleanly in `schema_prefix_contract_test.exs`; avoid checking `_build` artifacts. |
| Optional bounded current-residue audit | test | file-I/O | No current source-comment audit exists. Reuse the path-glob/anti-vacuity style from `planning_path_hygiene_test.exs`, but use an allowlisted current surface and domain-language exceptions rather than a blanket Phase-token ban. |

## Metadata

**Analog search scope:** `lib/`, `test/`, `scripts/maintainer/`, `.github/workflows/`, root docs,
`guides/`, and Phase 121 SAFE-01 artifacts.  
**Files scanned:** 60+ candidate source/test/doc files; 16 concrete analogs extracted.  
**Pattern extraction date:** 2026-08-22.
