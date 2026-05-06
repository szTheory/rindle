---
phase: 33-provider-boundary-state-schema
plan: 02
subsystem: domain/state-schema
tags: [elixir, ecto, migration, schema, fsm, telemetry, security-invariant-14]
requires:
  - lib/rindle/domain/media_asset.ex (FK target — unchanged)
  - lib/rindle/domain/asset_fsm.ex (analog mirror — unchanged)
provides:
  - "media_provider_assets table (additive Ecto migration; binary_id PK; 4 indexes)"
  - "Rindle.Domain.MediaProviderAsset schema + changeset + custom Inspect impl (security invariant 14)"
  - "Rindle.Domain.ProviderAssetFSM transition allowlist + [:rindle, :provider_asset, :state_change] telemetry"
affects:
  - "Phase 34 MuxIngestVariant worker (consumes the row schema, FSM, and re-ingest re-entry edge errored→processing)"
  - "Phase 33 Plan 03 Rindle.Delivery.streaming_url/3 dispatch tree (Repo.get_by/2 against partial-where unique index from D-10)"
tech-stack:
  added: []
  patterns:
    - "Pattern B: binary_id PK + @foreign_key_type :binary_id + state-as-string + @states allowlist (mirror of media_asset.ex)"
    - "Pattern C: FSM as @allowed_transitions map + transition/3 returning :ok | {:error, {:invalid_transition, from, to}} + :telemetry.execute (mirror of asset_fsm.ex)"
    - "Pattern E: Adopter-owned migration handoff — additive only, no DDL transaction disabling, no lock_timeout"
    - "Pattern I: Custom defimpl Inspect for schema-level secret redaction (NEW for Phase 33; freezes security invariant 14)"
key-files:
  created:
    - priv/repo/migrations/20260506120000_create_media_provider_assets.exs
    - lib/rindle/domain/media_provider_asset.ex
    - lib/rindle/domain/provider_asset_fsm.ex
    - test/rindle/domain/media_provider_asset_test.exs
    - test/rindle/domain/provider_asset_fsm_test.exs
    - .planning/phases/33-provider-boundary-state-schema/deferred-items.md
  modified: []
decisions:
  - "Implemented states/0 reflection helper on MediaProviderAsset for downstream introspection (Plan 03 dispatch tree, Phase 34 workers)"
  - "Implemented allowed_transitions/0 reflection helper on ProviderAssetFSM for downstream introspection / docs"
  - "Schema field last_sync_error declared as :string with validate_length(max: 4096); DB column remains :text per D-09 (Ecto treats :string and :text interchangeably for cast)"
  - "Used Inspect.Any.inspect/2 to delegate pretty-printing after redaction substitution (the canonical 'redact then delegate' pattern)"
metrics:
  duration_seconds: 751
  duration_human: "~12 minutes"
  completed: "2026-05-06T17:19:22Z"
  tasks_completed: 4
  task_commits: 4
  files_created: 6
  files_modified: 0
  tests_added: 47
  tests_failed: 0
requirements: [STREAM-03, STREAM-04]
---

# Phase 33 Plan 02: Provider state schema + FSM (additive migration, custom Inspect redaction, telemetry-emitting transition allowlist)

Lands the additive `media_provider_assets` Ecto migration, the
`Rindle.Domain.MediaProviderAsset` schema (with the security-invariant-14
custom `Inspect` impl), and the `Rindle.Domain.ProviderAssetFSM` transition
allowlist + `[:rindle, :provider_asset, :state_change]` telemetry — locking
D-09..D-14 so Phase 34's `MuxIngestVariant` worker and Phase 33's Plan 03
dispatch tree can land against a frozen contract.

## Final migration column set + index set (verbatim)

The migration is `priv/repo/migrations/20260506120000_create_media_provider_assets.exs`.

**Columns (D-09, 13 user columns + binary_id PK + timestamps):**

```elixir
create table(:media_provider_assets, primary_key: false) do
  add :id, :binary_id, primary_key: true
  add :asset_id, references(:media_assets, type: :binary_id, on_delete: :delete_all), null: false
  add :profile, :string, null: false
  add :provider_name, :string, null: false
  add :provider_asset_id, :string
  add :playback_ids, {:array, :string}, null: false, default: []
  add :playback_policy, :string
  add :ingest_mode, :string
  add :state, :string, null: false, default: "pending"
  add :last_event_id, :string
  add :last_event_at, :utc_datetime_usec
  add :last_sync_error, :text
  add :raw_provider_metadata, :map, null: false, default: %{}
  timestamps()
end
```

**Indexes (D-10, four total):**

```elixir
create unique_index(:media_provider_assets, [:provider_name, :provider_asset_id],
         where: "provider_asset_id IS NOT NULL",
         name: :media_provider_assets_provider_name_provider_asset_id_index)
create unique_index(:media_provider_assets, [:asset_id, :profile, :provider_name])
create index(:media_provider_assets, [:state])
create index(:media_provider_assets, [:state, :updated_at])
```

**Migration posture:**

- No `@disable_ddl_transaction`, no `lock_timeout` — matches every prior in-repo migration (D-11). The `@moduledoc` documents the posture explicitly.
- Reversible via Ecto's automatic `change/0` reversal — `mix ecto.rollback --quiet -n 1 && mix ecto.migrate --quiet` cycle was verified working.
- No data backfill, no change to `media_assets`, no change to `media_variants` (Phase 33 ROADMAP success criterion #2).
- The first unique index is the load-bearing partial-where index Phase 34's idempotency keys depend on; the `WHERE provider_asset_id IS NOT NULL` clause is mandatory.

## Final schema field declarations + changeset rules

`lib/rindle/domain/media_provider_asset.ex`:

```elixir
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id

@states ~w(pending uploading processing ready errored deleted)

schema "media_provider_assets" do
  field :profile, :string
  field :provider_name, :string
  field :provider_asset_id, :string
  field :playback_ids, {:array, :string}, default: []
  field :playback_policy, :string
  field :ingest_mode, :string
  field :state, :string, default: "pending"
  field :last_event_id, :string
  field :last_event_at, :utc_datetime_usec
  field :last_sync_error, :string
  field :raw_provider_metadata, :map, default: %{}

  belongs_to :asset, Rindle.Domain.MediaAsset, foreign_key: :asset_id

  timestamps()
end

def changeset(asset, attrs) do
  asset
  |> cast(attrs, @writable)
  |> validate_required([:asset_id, :profile, :provider_name, :state])
  |> validate_inclusion(:state, @states)
  |> validate_length(:last_sync_error, max: 4096)
  |> unique_constraint([:provider_name, :provider_asset_id],
       name: :media_provider_assets_provider_name_provider_asset_id_index)
  |> unique_constraint([:asset_id, :profile, :provider_name])
  |> foreign_key_constraint(:asset_id)
end
```

**Changeset enforcement (D-09):**

- `validate_required([:asset_id, :profile, :provider_name, :state])` — minimum invariants for a row to land.
- `validate_inclusion(:state, @states)` — the 6-state vocabulary is the only legal `state` value (NOT `Ecto.Enum` — mirrors `MediaAsset` per RESEARCH "Alternatives Considered").
- `validate_length(:last_sync_error, max: 4096)` — load-bearing truncation enforcement at the changeset layer (DB column is `:text` with no length cap; the changeset is the freeze point).
- `unique_constraint` on `(:provider_name, :provider_asset_id)` with the literal index name `:media_provider_assets_provider_name_provider_asset_id_index` to match the partial-where unique index. The second `unique_constraint` on `(:asset_id, :profile, :provider_name)` matches the auto-named full unique index.
- `foreign_key_constraint(:asset_id)` — surfaces the FK violation as a changeset error (verified via the bogus-UUID test).

**`states/0` reflection helper:** Implemented under "Claude's Discretion" — exposes `@states` as `Rindle.Domain.MediaProviderAsset.states/0` for downstream callers (Plan 03 dispatch tree introspection) without bypassing the changeset's validation contract.

## Final FSM transition map (verbatim D-13 encoding)

`lib/rindle/domain/provider_asset_fsm.ex`:

```elixir
@allowed_transitions %{
  "pending" => ["uploading", "errored"],
  "uploading" => ["processing", "errored"],
  "processing" => ["ready", "errored"],
  "ready" => ["errored", "deleted"],
  "errored" => ["deleted", "processing"],   # re-ingest re-entry edge
  "deleted" => []
}
```

Notes:

- The map encodes D-13 verbatim. `"deleted" => []` makes deleted a terminal sink.
- `"errored" => ["deleted", "processing"]` is the re-ingest re-entry edge — Phase 34's `MuxIngestVariant` retry path locks against this edge being present.
- `"pending" => ["uploading", "errored"]` includes the `pending → errored` direct edge (e.g., `create_asset/3` failure before upload begins).

**`transition/3` shape (D-12):**

```elixir
def transition(current_state, target_state, context \\ %{}) do
  if target_state in Map.get(@allowed_transitions, current_state, []) do
    :ok
    |> tap(fn _ ->
      :telemetry.execute(
        [:rindle, :provider_asset, :state_change],
        %{system_time: System.system_time()},
        %{
          profile: Map.get(context, :profile, :unknown),
          provider: Map.get(context, :provider, :unknown),
          asset_id: Map.get(context, :asset_id),
          from: current_state,
          to: target_state
        }
      )
    end)
  else
    log_transition_failure(current_state, target_state, context)
    {:error, {:invalid_transition, current_state, target_state}}
  end
end
```

**Phase-33 differences from `Rindle.Domain.AssetFSM` analog:**

- Telemetry event name is `[:rindle, :provider_asset, :state_change]` (NOT `[:rindle, :asset, :state_change]`) — distinct stream so adopters can attach to provider transitions independently.
- Metadata uses the `:provider` key (NOT `:adapter` like the AssetFSM analog) — matches PATTERNS.md Pattern C explicit guidance and reflects the new boundary the row participates in.
- Includes `asset_id` in metadata so audit-log consumers can correlate the transition with the parent `media_assets` row without a follow-up Repo.get/2.
- `tap/2` ensures the `:ok` return shape is preserved after telemetry fires.

**`allowed_transitions/0` reflection helper:** Implemented under "Claude's Discretion" — returns the static map for introspection / documentation tooling. Pure read; no risk of bypass.

**Pure validator:** No `Repo` writes inside the FSM. Caller (Phase 34 `MuxIngestVariant`, future Plan 03 dispatch tree) owns the changeset apply / persistence step. This mirrors the analog's discipline.

## Inspect-impl redaction behavior (security invariant 14, D-14)

The custom `defimpl Inspect, for: Rindle.Domain.MediaProviderAsset` is the schema-layer freeze point for security invariant 14. It substitutes two fields in the rendered struct, then delegates pretty-printing to `Inspect.Any.inspect/2`:

- `provider_asset_id` → `"...<last4>"` when `byte_size(id) >= 4`; `"...redacted"` for shorter binaries; `nil` passes through.
- `raw_provider_metadata` → `%{redacted: true}` (opaque sentinel; no key from the original map leaks).

**Example (manual smoke test):**

Before the impl was wired, naive Elixir would render:

```
%Rindle.Domain.MediaProviderAsset{
  provider_asset_id: "abc-123-XYZ-9999",
  raw_provider_metadata: %{secret: "leak"},
  ...
}
```

After the impl is wired (verified via `mix run --no-start -e 'IO.inspect(...)'`):

```
%Rindle.Domain.MediaProviderAsset{
  provider_asset_id: "...9999",
  raw_provider_metadata: %{redacted: true},
  ...
}
```

The original `"abc-123-XYZ"` and `"leak"` substrings do NOT appear anywhere in the output — verified by `refute String.contains?/2` assertions in five Inspect tests covering: ≥4-char IDs, nil IDs, <4-char IDs, raw_provider_metadata leakage, and the combined case.

This is the only schema-layer enforcement of invariant 14; every `inspect/2` boundary, telemetry-metadata logging, `Logger`/`IO.inspect` call, and Sentry-style error reporter that touches a `MediaProviderAsset` struct now goes through this redaction.

## Test counts

| File | Tests | Failures | Coverage |
|------|-------|----------|----------|
| `test/rindle/domain/media_provider_asset_test.exs` | 26 | 0 | Migration smoke (column set, partial-where index), schema reflection (table source, states/0, belongs_to), changeset state vocab (6 valid × 1 test each + 8 invalid in batch), validate_required (4 fields), last_sync_error 4096-char truncation (over + at limit), unique constraints (partial-where via shared provider_asset_id, three-tuple, FK), Inspect redaction (5 cases) |
| `test/rindle/domain/provider_asset_fsm_test.exs` | 21 | 0 | Nominal happy path, errored branches (4), terminal-delete (3 states + 1 batch reject), re-ingest re-entry edge, rejection coverage (7), telemetry on success (full + default-context), refute telemetry on rejection, Logger.warning emit, allowed_transitions/0 reflection |
| **Total** | **47** | **0** | — |

Full focused suite (`mix test test/rindle/domain/`) — **114 tests, 0 failures.**

## Decisions Made (Claude's Discretion)

1. **`states/0` reflection helper on `MediaProviderAsset`.** Public function returning `@states`. Justification: lets Plan 03's dispatch tree assert state-set equality without duplicating the literal `~w(pending ...)` in two places (DRY across schema + dispatch). Pure read; bypasses nothing. Test "states/0 returns the locked 6-state vocabulary" locks the contract.
2. **`allowed_transitions/0` reflection helper on `ProviderAssetFSM`.** Public function returning `@allowed_transitions`. Justification: parallel to (1) — lets ops tooling and future docs consume the map without re-declaring D-13. Test "allowed_transitions/0 returns the locked D-13 map" locks the wording.
3. **`last_sync_error` declared as `:string` (not `:text`) in the schema.** Ecto treats `:string` and `:text` interchangeably for `cast/3`. The DB-side `:text` column avoids a varchar length cap; the `validate_length(max: 4096)` is the load-bearing truncation enforcement. PATTERNS.md "Phase-33-specific schema" line ~247 explicitly lists this as the intended approach.
4. **`Inspect.Any.inspect/2` for delegation.** The standard Elixir pattern for "redact then delegate" — substitute sensitive fields on a struct copy, then call `Inspect.Any.inspect/2` to render with the default struct printer. This avoids re-implementing the algebra in the impl.

None of these touched any locked contract surface (D-09..D-14 are byte-for-byte verbatim).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking format issue] Reformatted `test/rindle/domain/media_provider_asset_test.exs`**

- **Found during:** Task 4 quality gate (`mix format --check-formatted`).
- **Issue:** Two long lines exceeded the formatter's 98-column line length: a `for bad <- ~w(...)` list and a `MediaProviderAsset.changeset(...)` call site.
- **Fix:** Ran `mix format` on the file. The reformat is purely whitespace; tests still pass (47/47). No production-source code was touched.
- **Files modified:** `test/rindle/domain/media_provider_asset_test.exs` (whitespace-only).
- **Commit:** `42460db`.

### Deferred Issues (out-of-scope per SCOPE BOUNDARY)

Three pre-existing test failures in unrelated files (`test/rindle/av/ffprobe_test.exs:13` `:epipe` from local ffprobe behavior; two `Rindle.ApplicationTest` failures from canonical-app fixture profile leaking into `Application.get_env(:rindle, :profiles)` via `elixirc_paths(:test)`). Verified pre-existing on phase base commit (`c6aeead`) — `git diff c6aeead HEAD -- test/rindle/application_test.exs test/rindle/av/ffprobe_test.exs` returns zero diff. Logged to `.planning/phases/33-provider-boundary-state-schema/deferred-items.md` per the deviation-rules SCOPE BOUNDARY.

Pre-existing credo / dialyzer / format issues in unrelated files (`lib/rindle/workers/process_variant.ex`, `lib/rindle/workers/promote_asset.ex`, `lib/rindle/ops/lifecycle_repair.ex`, etc.) are also out of scope. Verified that **zero credo, dialyzer, or format issues come from any Plan 02 file** via `mix credo --strict lib/rindle/domain/media_provider_asset.ex lib/rindle/domain/provider_asset_fsm.ex` (clean) and `mix format --check-formatted <plan-02 files>` (clean after Rule-3 fix above).

## Quality Gate Status

| Gate | Status | Notes |
|------|--------|-------|
| `mix test test/rindle/domain/ --color` | PASS | 114 tests, 0 failures |
| `mix test test/rindle/domain/media_provider_asset_test.exs` | PASS | 26 tests, 0 failures |
| `mix test test/rindle/domain/provider_asset_fsm_test.exs` | PASS | 21 tests, 0 failures |
| `mix test --color` (full suite) | PASS for Plan-02 work | 600/603 pass; the 3 failures are pre-existing in unrelated files (deferred-items.md) |
| `mix credo --strict` on Plan 02 files | PASS | 11 mods/funs, 0 issues |
| `mix dialyzer` on Plan 02 files | PASS | 0 warnings touching Plan 02 |
| `mix format --check-formatted` on Plan 02 files | PASS | After Rule-3 fix |
| `mix ecto.migrate` (fresh DB) | PASS | Idempotent; second run is a no-op |
| `mix ecto.rollback -n 1 && mix ecto.migrate` | PASS | Reversibility verified |
| `git diff` against `mix.exs`, `media_asset.ex`, prior migrations | PASS | All zero diff |

## Self-Check: PASSED

**Files verified:**
- `priv/repo/migrations/20260506120000_create_media_provider_assets.exs` — FOUND
- `lib/rindle/domain/media_provider_asset.ex` — FOUND
- `lib/rindle/domain/provider_asset_fsm.ex` — FOUND
- `test/rindle/domain/media_provider_asset_test.exs` — FOUND
- `test/rindle/domain/provider_asset_fsm_test.exs` — FOUND
- `.planning/phases/33-provider-boundary-state-schema/deferred-items.md` — FOUND

**Commits verified (in `git log --oneline`):**
- `4ce124f` (Task 1) — FOUND
- `198d152` (Task 2) — FOUND
- `67a12d8` (Task 3) — FOUND
- `42460db` (Task 4) — FOUND
