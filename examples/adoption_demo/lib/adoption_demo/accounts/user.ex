defmodule AdoptionDemo.Accounts.User do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "users" do
    field :email, :string
    field :name, :string

    timestamps(type: :utc_datetime_usec)
  end
end
