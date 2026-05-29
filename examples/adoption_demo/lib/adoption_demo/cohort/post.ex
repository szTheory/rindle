defmodule AdoptionDemo.Cohort.Post do
  @moduledoc false
  use Ecto.Schema

  alias AdoptionDemo.Accounts.Member

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "posts" do
    field :title, :string
    field :body, :string

    belongs_to :member, Member, type: :binary_id

    timestamps(type: :utc_datetime_usec)
  end
end
