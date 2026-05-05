defmodule Rindle.Domain.MediaVariant do
  @moduledoc """
  Ecto schema for a derived variant of a media asset.

  A `MediaVariant` represents one named output (e.g. `:thumb`, `:large`)
  derived from a source asset. Each variant moves through the
  variant lifecycle and stores its own storage key,
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

  See the state table below for valid transitions and stale-serving
  behavior.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @states ~w(planned queued processing ready stale missing failed cancelled purged)

  @output_kinds ~w(image video audio waveform)

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
    field :output_kind, :string, default: "image"
    field :duration_ms, :integer
    field :width, :integer
    field :height, :integer

    belongs_to :asset, Rindle.Domain.MediaAsset

    timestamps()
  end

  @doc """
  Builds a changeset for a variant row.

  Casts the variant-recipe, storage, and lifecycle columns; requires the
  minimum invariants (`:asset_id`, `:name`, `:state`, `:recipe_digest`);
  validates the lifecycle state against the canonical state list and enforces
  uniqueness across `(:asset_id, :name)` so each variant exists at most once
  per asset.
  """
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
      :generated_at,
      :output_kind,
      :duration_ms,
      :width,
      :height
    ])
    |> validate_required([:asset_id, :name, :state, :recipe_digest, :output_kind])
    |> validate_inclusion(:state, @states)
    |> validate_inclusion(:output_kind, @output_kinds)
    |> foreign_key_constraint(:asset_id)
    |> unique_constraint([:asset_id, :name])
  end
end
