defmodule Rindle.Workers.PromoteAsset do
  @moduledoc false
  use Oban.Worker, queue: :rindle_promote, max_attempts: 3

  alias Rindle.Config
  alias Rindle.Domain.AssetFSM
  alias Rindle.Domain.{MediaAsset, MediaVariant}
  alias Rindle.Processor.AV
  alias Rindle.Processor.AV.RuntimeGuard
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
    with {:ok, asset} <- maybe_run_probe_step(repo, asset),
         :ok <- AssetFSM.transition(asset.state, "promoting", %{asset_id: asset.id}),
         {:ok, _asset} <-
           asset
           |> MediaAsset.changeset(%{state: "promoting"})
           |> repo.update() do
      :ok
    else
      {:error, :probe_failed, reason} ->
        quarantine_asset(repo, asset, reason)

      {:error, reason} ->
        {:error, reason}
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

    RuntimeGuard.warn_unsupported_runtime([
      %{
        name: profile_module,
        variants: Enum.map(variants, fn {_name, spec} -> normalized_variant_spec(spec) end)
      }
    ])

    Enum.reduce(variants, multi, fn {name, spec}, acc ->
      name_str = Atom.to_string(name)
      digest = profile_module.recipe_digest(name)
      normalized_spec = normalized_variant_spec(spec)

      variant_changeset =
        %MediaVariant{}
        |> MediaVariant.changeset(%{
          asset_id: asset.id,
          name: name_str,
          state: "planned",
          recipe_digest: digest,
          output_kind: normalized_spec |> Map.get(:output_kind, :image) |> to_string()
        })

      job_args = ProcessVariant.job_args_for_variant(asset.id, name_str, normalized_spec)
      job_opts = ProcessVariant.job_opts_for_variant(normalized_spec)
      job = ProcessVariant.new(job_args, job_opts)

      acc
      |> Ecto.Multi.insert({:variant, name}, variant_changeset)
      |> Oban.insert({:job, name}, job)
    end)
  end

  defp maybe_run_probe_step(repo, asset), do: run_probe_step(repo, asset)

  defp run_probe_step(repo, asset) do
    tmp_path = Path.join(tmp_dir(), "rindle_probe_#{Ecto.UUID.generate()}")

    try do
      with :ok <- download_to(asset, tmp_path),
           {:ok, mime} <- Rindle.Security.Mime.detect(tmp_path),
           {:ok, probe_module} <- dispatch_probe(mime),
           {:ok, result} <- probe_module.probe(tmp_path),
           {:ok, asset} <- write_probe_result(repo, asset, mime, result) do
        {:ok, asset}
      else
        {:error, reason} -> {:error, :probe_failed, reason}
      end
    after
      _ = File.rm(tmp_path)
    end
  end

  defp dispatch_probe(mime) do
    cond do
      Rindle.Probe.AVProbe.accepts?(mime) -> {:ok, Rindle.Probe.AVProbe}
      Rindle.Probe.Image.accepts?(mime) -> {:ok, Rindle.Probe.Image}
      true -> {:error, {:no_probe_for_mime, mime}}
    end
  end

  defp write_probe_result(repo, asset, mime, result) do
    attrs =
      result
      |> Map.put(:content_type, mime)
      |> stringify_kind()
      |> normalize_probe_attrs_for_storage()

    asset
    |> MediaAsset.changeset(attrs)
    |> repo.update()
  end

  defp stringify_kind(%{kind: kind} = result) when is_atom(kind),
    do: Map.put(result, :kind, Atom.to_string(kind))

  defp stringify_kind(result), do: result

  defp normalize_probe_attrs_for_storage(%{kind: "audio"} = result) do
    Map.drop(result, [:width, :height, :has_video_track])
  end

  defp normalize_probe_attrs_for_storage(result), do: result

  defp quarantine_asset(repo, asset, reason) do
    reason_string = inspect(reason)

    with :ok <-
           AssetFSM.transition(asset.state, "quarantined", %{
             asset_id: asset.id,
             reason: reason_string
           }),
         {:ok, _asset} <-
           asset
           |> MediaAsset.changeset(%{state: "quarantined", error_reason: reason_string})
           |> repo.update() do
      {:error, {:quarantined, reason}}
    end
  end

  defp tmp_dir, do: Application.get_env(:rindle, :tmp_dir, System.tmp_dir!())

  defp normalized_variant_spec(spec) when is_list(spec),
    do: normalized_variant_spec(Map.new(spec))

  defp normalized_variant_spec(%{} = spec) do
    if normalized_av_spec?(spec) do
      spec
    else
      case AV.normalize(spec) do
        {:ok, normalized} -> normalized
        {:error, _reason} -> spec
      end
    end
  end

  defp normalized_av_spec?(%{} = spec) do
    Map.has_key?(spec, :output_kind) or
      Map.has_key?(spec, :container) or
      Map.has_key?(spec, :video_codec) or
      Map.has_key?(spec, :audio_codec)
  end

  defp normalized_av_spec?(_spec), do: false

  defp download_to(asset, destination_path) do
    profile_module = String.to_existing_atom(asset.profile)

    case Rindle.download(profile_module, asset.storage_key, destination_path) do
      {:ok, _path} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
