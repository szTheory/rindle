defmodule Rindle.Domain.MediaVariant do
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
    field :error_reason, :string
    field :generated_at, :utc_datetime_usec

    belongs_to :asset, Rindle.Domain.MediaAsset

    timestamps()
  end

  @spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(variant, attrs) do
    variant
    |> cast(attrs, [:asset_id, :name, :state, :recipe_digest, :storage_key, :error_reason, :generated_at])
    |> validate_required([:asset_id, :name, :state, :recipe_digest])
    |> validate_inclusion(:state, @states)
    |> foreign_key_constraint(:asset_id)
    |> unique_constraint([:asset_id, :name])
  end
end
