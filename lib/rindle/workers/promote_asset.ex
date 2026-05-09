defmodule Rindle.Workers.PromoteAsset do
  @moduledoc false
  use Oban.Worker, queue: :rindle_promote, max_attempts: 3

  import Ecto.Changeset

  alias Rindle.Config
  alias Rindle.Domain.AssetFSM
  alias Rindle.Domain.{MediaAsset, MediaVariant}
  alias Rindle.Probe.AVProbe
  alias Rindle.Probe.Image
  alias Rindle.Processor.AV
  alias Rindle.Processor.AV.RuntimeGuard
  alias Rindle.Security.Mime
  alias Rindle.Workers.ProcessVariant

  @probe_fields [
    :content_type,
    :kind,
    :width,
    :height,
    :duration_ms,
    :has_video_track,
    :has_audio_track
  ]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"asset_id" => asset_id}}) do
    repo = Config.repo()

    with %MediaAsset{} = asset <- repo.get(MediaAsset, asset_id) do
      promote(repo, asset)
    else
      nil -> {:error, :not_found}
    end
  end

  @spec probe_fields() :: [atom()]
  def probe_fields, do: @probe_fields

  @spec probe_asset(MediaAsset.t()) :: {:ok, map()} | {:error, {:probe_failed, term()}}
  def probe_asset(asset) do
    tmp_path = Path.join(tmp_dir(), "rindle_probe_#{Ecto.UUID.generate()}")

    try do
      with :ok <- download_to(asset, tmp_path),
           {:ok, mime} <- Mime.detect(tmp_path),
           {:ok, probe_module} <- dispatch_probe(mime),
           {:ok, result} <- probe_module.probe(tmp_path) do
        {:ok, build_probe_attrs(mime, result)}
      else
        {:error, reason} -> {:error, {:probe_failed, reason}}
      end
    after
      _ = File.rm(tmp_path)
    end
  end

  @spec persist_probe_result(Ecto.Repo.t(), MediaAsset.t(), map(), keyword()) ::
          {:ok, MediaAsset.t()} | {:error, Ecto.Changeset.t()}
  def persist_probe_result(repo, asset, attrs, opts \\ []) do
    allowed_fields = Keyword.get(opts, :allowed_fields, @probe_fields ++ [:metadata])
    clear_missing? = Keyword.get(opts, :clear_missing?, true)

    persisted_attrs =
      Enum.reduce(allowed_fields, %{}, fn field, acc ->
        cond do
          Map.has_key?(attrs, field) ->
            Map.put(acc, field, Map.fetch!(attrs, field))

          clear_missing? and field in @probe_fields ->
            Map.put(acc, field, nil)

          true ->
            acc
        end
      end)

    asset
    |> MediaAsset.changeset(persisted_attrs)
    |> put_change(:updated_at, NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
    |> repo.update()
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
    with {:ok, attrs} <- probe_asset(asset),
         {:ok, asset} <- persist_probe_result(repo, asset, attrs) do
      {:ok, asset}
    else
      {:error, {:probe_failed, reason}} -> {:error, :probe_failed, reason}
      {:error, reason} -> {:error, :probe_failed, reason}
    end
  end

  defp build_probe_attrs(mime, result) do
    result
    |> Map.put(:content_type, mime)
    |> stringify_kind()
    |> normalize_probe_attrs_for_storage()
  end

  defp dispatch_probe(mime) do
    cond do
      AVProbe.accepts?(mime) -> {:ok, AVProbe}
      Image.accepts?(mime) -> {:ok, Image}
      true -> {:error, {:no_probe_for_mime, mime}}
    end
  end

  defp stringify_kind(%{kind: kind} = result) when is_atom(kind),
    do: Map.put(result, :kind, Atom.to_string(kind))

  defp stringify_kind(result), do: result

  defp normalize_probe_attrs_for_storage(%{kind: "audio"} = result) do
    Map.drop(result, [:width, :height, :has_video_track])
  end

  defp normalize_probe_attrs_for_storage(%{kind: "image"} = result) do
    Map.drop(result, [:duration_ms, :has_video_track, :has_audio_track])
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
