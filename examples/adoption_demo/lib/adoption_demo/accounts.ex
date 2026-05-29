defmodule AdoptionDemo.Accounts do
  @moduledoc false

  import Ecto.Query

  alias AdoptionDemo.Accounts.User
  alias AdoptionDemo.Repo

  def list_users do
    Repo.all(from u in User, order_by: [asc: u.email])
  end

  def get_user!(id), do: Repo.get!(User, id)

  def seed_user!(attrs) do
    %User{}
    |> Ecto.Changeset.change(attrs)
    |> Repo.insert!(on_conflict: :nothing, conflict_target: :email)
  end
end
