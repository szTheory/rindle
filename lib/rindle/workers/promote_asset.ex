defmodule Rindle.Workers.PromoteAsset do
  @moduledoc """
  Oban worker responsible for promoting a MediaAsset to the 'available' state.
  Triggers async variant generation upon successful promotion.
  """
  use Oban.Worker, queue: :rindle_promote, max_attempts: 3

  alias Rindle.Config
  alias Rindle.Domain.AssetFSM
  alias Rindle.Domain.{MediaAsset, MediaVariant}
  alias Rindle.Workers.ProcessVariant

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"asset_id" => asset_id}}) do
    repo = Config.repo()

    with %MediaAsset{} = asset <- repo.get(MediaAsset, asset_id) do
      promote(repo, asset)
    else
      nil -> {:error, :not_found}
    end
  end

  defp promote(repo, asset) do
    # 1. Advance state chain to 'available'
    # We follow: validating -> analyzing -> promoting -> available
    # Some steps might have happened already, so we handle them gracefully.

    with :ok <- advance_to_promoting(repo, asset),
         asset <- repo.get!(MediaAsset, asset.id),
         :ok <- AssetFSM.transition(asset.state, "available", %{asset_id: asset.id}) do
      Ecto.Multi.new()
      |> Ecto.Multi.update(:asset, MediaAsset.changeset(asset, %{state: "available"}))
      |> enqueue_variants(asset)
      |> repo.transaction()
      |> case do
        {:ok, _} -> :ok
        {:error, _name, reason, _changes} -> {:error, reason}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp advance_to_promoting(_repo, %{state: "promoting"}), do: :ok

  defp advance_to_promoting(repo, %{state: "analyzing"} = asset) do
    with :ok <- AssetFSM.transition(asset.state, "promoting", %{asset_id: asset.id}),
         {:ok, _asset} <-
           asset
           |> MediaAsset.changeset(%{state: "promoting"})
           |> repo.update() do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp advance_to_promoting(repo, %{state: "validating"} = asset) do
    with :ok <- AssetFSM.transition(asset.state, "analyzing", %{asset_id: asset.id}),
         {:ok, asset} <-
           asset
           |> MediaAsset.changeset(%{state: "analyzing"})
           |> repo.update() do
      advance_to_promoting(repo, asset)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp advance_to_promoting(_repo, asset) do
    {:error, {:invalid_start_state, asset.state}}
  end

  defp enqueue_variants(multi, asset) do
    profile_module = String.to_existing_atom(asset.profile)
    variants = profile_module.variants()

    Enum.reduce(variants, multi, fn {name, _spec}, acc ->
      name_str = Atom.to_string(name)
      digest = profile_module.recipe_digest(name)

      variant_changeset =
        %MediaVariant{}
        |> MediaVariant.changeset(%{
          asset_id: asset.id,
          name: name_str,
          state: "planned",
          recipe_digest: digest
        })

      job =
        ProcessVariant.new(%{
          "asset_id" => asset.id,
          "variant_name" => name_str
        })

      acc
      |> Ecto.Multi.insert({:variant, name}, variant_changeset)
      |> Oban.insert({:job, name}, job)
    end)
  end
end
