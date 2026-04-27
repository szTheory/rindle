defmodule Rindle.Domain.MediaVariant do
  @moduledoc """
  Ecto schema for a derived variant of a media asset.

  A `MediaVariant` represents one named output (e.g. `:thumb`, `:large`)
  derived from a source asset. Each variant moves through the
  `Rindle.Domain.VariantFSM` lifecycle and stores its own storage key,
  recipe digest, and ready/failed/stale state.

  ## States

  | State | Meaning |
  |-------|---------|
  | `"planned"` | Variant row exists; processing not yet enqueued. |
  | `"queued"` | Oban job enqueued; awaiting processor. |
  | `"processing"` | Processor is generating the variant. |
  | `"ready"` | Variant generated and stored; deliverable. |
  | `"failed"` | Processing failed past the retry budget. |
  | `"stale"` | Recipe digest changed; existing object outdated. |
  | `"missing"` | Storage reconciliation found the object absent. |
  | `"purged"` | Variant explicitly removed; storage object deleted. |

  See `Rindle.Domain.VariantFSM` for valid state transitions and
  `Rindle.Domain.StalePolicy` for stale-serving behavior.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @states ["planned", "queued", "processing", "ready", "stale", "missing", "failed", "purged"]

  @type t :: %__MODULE__{}

  schema "media_variants" do
    field :name, :string
    field :state, :string, default: "planned"
    field :recipe_digest, :string
    field :storage_key, :string
    field :byte_size, :integer
    field :content_type, :string
    field :error_reason, :string
    field :generated_at, :utc_datetime_usec

    belongs_to :asset, Rindle.Domain.MediaAsset

    timestamps()
  end

  @spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(variant, attrs) do
    variant
    |> cast(attrs, [
      :asset_id,
      :name,
      :state,
      :recipe_digest,
      :storage_key,
      :byte_size,
      :content_type,
      :error_reason,
      :generated_at
    ])
    |> validate_required([:asset_id, :name, :state, :recipe_digest])
    |> validate_inclusion(:state, @states)
    |> foreign_key_constraint(:asset_id)
    |> unique_constraint([:asset_id, :name])
  end
end
