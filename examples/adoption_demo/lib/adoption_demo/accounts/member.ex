defmodule AdoptionDemo.Accounts.Member do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "members" do
    field :email, :string
    field :name, :string
    field :role, :string, default: "student"

    timestamps(type: :utc_datetime_usec)
  end
end
