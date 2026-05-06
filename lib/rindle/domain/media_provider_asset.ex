defmodule Rindle.Domain.MediaProviderAsset do
  @moduledoc """
  Ecto schema for a provider-side asset row (Phase 33 — `media_provider_assets`).

  One row per `(asset, profile, provider)`. Tracks durable provider-side state
  (FSM lives in `Rindle.Domain.ProviderAssetFSM`) and the public-side
  `playback_ids` array.

  ## Security invariant 14

  Provider-internal identifiers (`provider_asset_id`, raw provider metadata) are
  treated as secrets at rest and in transit. The custom `Inspect` impl below
  redacts `provider_asset_id` to a last-4-char tag (`"...abcd"`) and replaces
  `raw_provider_metadata` with `%{redacted: true}` so telemetry, log lines, and
  `inspect/2` output never leak provider-internal state.

  ## States

  | State | Meaning |
  |-------|---------|
  | `"pending"` | Row created; `create_asset/3` not yet invoked. |
  | `"uploading"` | Server-push or direct-creator upload in flight. |
  | `"processing"` | Provider is transcoding / preparing playback. |
  | `"ready"` | Provider asset is playable; `playback_ids` populated. |
  | `"errored"` | Provider sync failed; inspect `last_sync_error`. |
  | `"deleted"` | Soft-deleted; provider asset may already be purged. |

  See `Rindle.Domain.ProviderAssetFSM` for the locked transition allowlist.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @states ~w(pending uploading processing ready errored deleted)

  @type t :: %__MODULE__{}

  @doc "Locked state vocabulary (matches `Rindle.Domain.ProviderAssetFSM` keys)."
  @spec states() :: [String.t()]
  def states, do: @states

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

  @writable [
    :asset_id,
    :profile,
    :provider_name,
    :provider_asset_id,
    :playback_ids,
    :playback_policy,
    :ingest_mode,
    :state,
    :last_event_id,
    :last_event_at,
    :last_sync_error,
    :raw_provider_metadata
  ]

  @doc """
  Redact a `provider_asset_id` to its last-4-character tag (`"...abcd"`).
  Returns `nil` for `nil`, `"...redacted"` for ids shorter than 4 chars.

  Used by telemetry emit sites and log lines to enforce security invariant 14
  (provider-internal identifiers never cross into adopter-facing telemetry,
  log lines, or `inspect/2` output). The `defimpl Inspect` block below
  delegates to this helper so the Inspect rendering and the telemetry emit
  sites use the same redaction routine.
  """
  @spec redact_id(nil | String.t()) :: nil | String.t()
  def redact_id(nil), do: nil

  def redact_id(id) when is_binary(id) and byte_size(id) >= 4 do
    "..." <> String.slice(id, -4, 4)
  end

  def redact_id(_), do: "...redacted"

  @doc """
  Builds a changeset for a `MediaProviderAsset` row.

  Casts the writable fields, requires the minimum invariants, validates the
  lifecycle state, enforces `last_sync_error` 4096-char truncation per D-09, and
  asserts the two unique constraints from D-10.
  """
  @spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(asset, attrs) do
    asset
    |> cast(attrs, @writable)
    |> validate_required([:asset_id, :profile, :provider_name, :state])
    |> validate_inclusion(:state, @states)
    |> validate_length(:last_sync_error, max: 4096)
    |> unique_constraint([:provider_name, :provider_asset_id],
      name: :media_provider_assets_provider_name_provider_asset_id_index
    )
    |> unique_constraint([:asset_id, :profile, :provider_name])
    |> foreign_key_constraint(:asset_id)
  end
end

defimpl Inspect, for: Rindle.Domain.MediaProviderAsset do
  def inspect(asset, opts) do
    redacted = %{
      asset
      | provider_asset_id: Rindle.Domain.MediaProviderAsset.redact_id(asset.provider_asset_id),
        raw_provider_metadata: %{redacted: true}
    }

    Inspect.Any.inspect(redacted, opts)
  end
end
