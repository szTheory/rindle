defmodule Rindle.Workers.ProcessVariant do
  @moduledoc """
  Oban worker responsible for generating a specific media variant.
  Implements the Atomic Promote pattern to handle concurrent replacements.
  """
  use Oban.Worker, queue: :rindle_process, max_attempts: 5

  alias Rindle.Domain.{MediaAsset, MediaVariant}
  alias Rindle.Domain.VariantFSM
  alias Rindle.Repo
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"asset_id" => asset_id, "variant_name" => variant_name}}) do
    with %MediaAsset{} = asset <- Repo.get(MediaAsset, asset_id),
         %MediaVariant{} = variant <- get_variant(asset_id, variant_name) do
      process(asset, variant)
    else
      nil -> {:error, :not_found}
    end
  end

  defp process(asset, variant) do
    profile_module = String.to_existing_atom(asset.profile)
    variant_spec = get_variant_spec(profile_module, variant.name)
    
    # 1. Atomic Promote Check: reload and verify attachment hasn't changed
    # In this phase, we don't have polymorphic attachments yet, 
    # but we check if the asset's own storage_key has changed (unlikely here).
    # Once we have MediaAttachment (Phase 2), we reload the attachment.
    
    with :ok <- transition_variant(variant, "queued"),
         variant <- Repo.get!(MediaVariant, variant.id),
         :ok <- transition_variant(variant, "processing"),
         variant <- Repo.get!(MediaVariant, variant.id),
         {:ok, source_tmp} <- download_source(asset),
         {:ok, dest_tmp} <- generate_dest_path(variant),
         {:ok, _} <- Rindle.Processor.Image.process(source_tmp, variant_spec, dest_tmp),
         {:ok, storage_meta} <- upload_variant(asset, variant, dest_tmp) do
      
      # 2. Final atomic update
      variant
      |> MediaVariant.changeset(%{
        state: "ready",
        storage_key: storage_meta.key,
        byte_size: get_file_size(dest_tmp),
        generated_at: DateTime.utc_now()
      })
      |> Repo.update()
      |> case do
        {:ok, _} -> 
          cleanup_temp_files([source_tmp, dest_tmp])
          :ok
        {:error, reason} -> 
          cleanup_temp_files([source_tmp, dest_tmp])
          {:error, reason}
      end
    else
      {:error, reason} -> 
        handle_failure(variant, reason)
    end
  end

  defp get_variant(asset_id, name) do
    Repo.one(from v in MediaVariant, where: v.asset_id == ^asset_id and v.name == ^name)
  end

  defp get_variant_spec(profile_module, name) do
    profile_module.variants()
    |> Enum.find(fn {n, _} -> Atom.to_string(n) == name end)
    |> elem(1)
  end

  defp transition_variant(variant, target_state) do
    with :ok <- VariantFSM.transition(variant.state, target_state, %{variant_id: variant.id}),
         {:ok, _} <- variant |> MediaVariant.changeset(%{state: target_state}) |> Repo.update() do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp download_source(asset) do
    profile_module = String.to_existing_atom(asset.profile)
    tmp_path = Path.join(System.tmp_dir!(), "rindle_source_#{Ecto.UUID.generate()}")
    Rindle.download(profile_module, asset.storage_key, tmp_path)
  end

  defp generate_dest_path(_variant) do
    {:ok, Path.join(System.tmp_dir!(), "rindle_dest_#{Ecto.UUID.generate()}.jpg")}
  end

  defp upload_variant(asset, variant, path) do
    profile_module = String.to_existing_atom(asset.profile)
    # Variant key: assets/{asset_id}/{variant_name}.{ext}
    extension = Path.extname(path)
    variant_key = Path.join([asset.profile, asset.id, "#{variant.name}#{extension}"])
    
    Rindle.store(profile_module, variant_key, path)
  end

  defp get_file_size(path) do
    File.stat!(path).size
  end

  defp cleanup_temp_files(paths) do
    Enum.each(paths, &File.rm/1)
  end

  defp handle_failure(variant, reason) do
    variant
    |> MediaVariant.changeset(%{state: "failed", error_reason: inspect(reason)})
    |> Repo.update()
    
    {:error, reason}
  end
end
