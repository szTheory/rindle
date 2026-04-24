defmodule Rindle.Domain.MediaUploadSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @states [
    "initialized",
    "signed",
    "uploading",
    "uploaded",
    "verifying",
    "completed",
    "aborted",
    "expired",
    "failed"
  ]

  @type t :: %__MODULE__{}

  schema "media_upload_sessions" do
    field :state, :string, default: "initialized"
    field :upload_key, :string
    field :expires_at, :utc_datetime_usec
    field :verified_at, :utc_datetime_usec
    field :failure_reason, :string

    belongs_to :asset, Rindle.Domain.MediaAsset

    timestamps()
  end

  @spec changeset(t() | %__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(upload_session, attrs) do
    upload_session
    |> cast(attrs, [:asset_id, :state, :upload_key, :expires_at, :verified_at, :failure_reason])
    |> validate_required([:asset_id, :state, :upload_key, :expires_at])
    |> validate_inclusion(:state, @states)
    |> foreign_key_constraint(:asset_id)
  end
end
