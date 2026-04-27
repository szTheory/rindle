defmodule Rindle.Domain.MediaAttachment do
  @moduledoc """
  Ecto schema linking a `Rindle.Domain.MediaAsset` to an owning entity.

  Attachments are the polymorphic association layer: any application
  record (a `User`, a `Post`, an `Article`) can own one or more assets
  via attachment rows. The attachment record carries the owner type,
  owner id, and an optional slot name (e.g. `"avatar"`, `"hero"`)
  that disambiguates multiple attachments of the same kind.

  Attachments have no lifecycle state machine of their own — they
  reflect a current ownership claim. Use `Rindle.attach/4` and
  `Rindle.detach/3` to mutate attachment rows; both functions
  participate in the same DB transaction as the asset state change
  they describe.

  Concurrent replacement (two clients attaching different assets to
  the same owner+slot) is detected by reloading inside the transaction
  and returning `{:error, :replaced}` rather than overwriting the
  newer attachment (see `Rindle.attach/4`).
  """

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
