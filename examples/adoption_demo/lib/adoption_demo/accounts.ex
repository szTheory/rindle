defmodule AdoptionDemo.Accounts do
  @moduledoc false

  import Ecto.Query

  alias AdoptionDemo.Accounts.Member
  alias AdoptionDemo.Repo

  def list_members do
    Repo.all(from m in Member, order_by: [asc: m.email])
  end

  # Back-compat for gradual refactors
  def list_users, do: list_members()

  def get_member!(id), do: Repo.get!(Member, id)

  def get_user!(id), do: get_member!(id)

  def get_member_by_email!(email) do
    Repo.one!(from m in Member, where: m.email == ^email)
  end

  def seed_member!(attrs) do
    %Member{}
    |> Ecto.Changeset.change(attrs)
    |> Repo.insert!(on_conflict: :nothing, conflict_target: :email)
  end

  def seed_user!(attrs), do: seed_member!(attrs)
end
