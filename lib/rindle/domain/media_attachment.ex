defmodule Rindle.Domain.MediaAttachment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{}

  schema "media_attachments" do
    field :owner_type, :string
    field :owner_id, :binary_id
    field :slot, :string

    belongs_to :asset, Rindle.Domain.MediaAsset

    timestamps()
  end

  @spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(attachment, attrs) do
    attachment
    |> cast(attrs, [:asset_id, :owner_type, :owner_id, :slot])
    |> validate_required([:asset_id, :owner_type, :owner_id, :slot])
    |> foreign_key_constraint(:asset_id)
    |> unique_constraint([:owner_type, :owner_id, :slot])
  end
end
