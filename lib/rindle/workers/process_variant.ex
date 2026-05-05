defmodule Rindle.Workers.ProcessVariant do
  @moduledoc false
  use Oban.Worker, queue: :rindle_process, max_attempts: 5

  alias Oban.Job
  alias Phoenix.PubSub
  alias Rindle.AV.TempRunDir
  alias Rindle.Config
  alias Rindle.Domain.AssetAggregate
  alias Rindle.Domain.{MediaAsset, MediaVariant}
  alias Rindle.Processor.AV
  alias Rindle.Processor.AV.{Audio, Video}
  alias Rindle.Processor.AV.{OutputProbe, RuntimeGuard}
  alias Rindle.Domain.VariantFSM
  alias Rindle.Processor.{Image, Waveform}
  import Ecto.Query

  @av_queue :rindle_media
  @av_timeout_ms :timer.minutes(10)
  @unique_states [:available, :scheduled, :executing, :retryable]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"asset_id" => asset_id, "variant_name" => variant_name}}) do
    repo = Config.repo()

    with %MediaAsset{} = asset <- repo.get(MediaAsset, asset_id),
         %MediaVariant{} = variant <- get_variant(repo, asset_id, variant_name) do
      process(repo, asset, variant)
    else
      nil -> {:error, :not_found}
    end
  end

  @impl Oban.Worker
  def timeout(%Job{args: %{"timeout" => timeout}}) when is_integer(timeout), do: timeout

  def timeout(%Job{}), do: :infinity

  @spec job_args_for_variant(Ecto.UUID.t(), String.t(), map() | keyword()) :: map()
  def job_args_for_variant(asset_id, variant_name, variant_spec) do
    normalized_spec = normalize_variant_spec(variant_spec)

    %{"asset_id" => asset_id, "variant_name" => variant_name}
    |> maybe_put_timeout(normalized_spec)
  end

  @spec job_opts_for_variant(map() | keyword()) :: keyword()
  def job_opts_for_variant(variant_spec) do
    normalized_spec = normalize_variant_spec(variant_spec)

    base_opts = [unique: unique_job_opts()]

    if av_variant?(normalized_spec) do
      Keyword.put(base_opts, :queue, @av_queue)
    else
      base_opts
    end
  end

  @doc false
  @spec cancel_processing(Ecto.UUID.t()) :: :ok | {:error, :not_processing}
  def cancel_processing(asset_id) when is_binary(asset_id) do
    repo = Config.repo()

    with %MediaAsset{} = asset <- repo.get(MediaAsset, asset_id),
         [_ | _] = variants <- processing_variants(repo, asset_id) do
      :ok = cancel_jobs(asset_id)
      :ok = cancel_variants(repo, variants)
      :ok = AssetAggregate.recompute(repo, asset_id)

      Enum.each(variants, fn variant ->
        broadcast_progress(asset, variant, 0, "cancelled")
      end)

      :ok
    else
      _ -> {:error, :not_processing}
    end
  end

  defp process(repo, asset, variant) do
    profile_module = String.to_existing_atom(asset.profile)
    variant_spec = get_variant_spec(profile_module, variant.name) |> normalize_variant_spec()

    if variant.state == "ready" do
      :ok
    else
      execute_with_contract(asset, variant, variant_spec, fn ->
        with :ok <- ensure_variant_state(repo, variant, "queued"),
             variant <- repo.get!(MediaVariant, variant.id),
             :ok <- ensure_variant_state(repo, variant, "processing"),
             :ok <- AssetAggregate.recompute(repo, asset.id),
             variant <- repo.get!(MediaVariant, variant.id),
             {:ok, run_dir} <- TempRunDir.create() do
          try do
            with :ok <- RuntimeGuard.check!(variant_spec, path: run_dir),
                 {:ok, source_tmp} <- download_source(asset, run_dir),
                 {:ok, dest_tmp} <- generate_dest_path(variant, variant_spec, run_dir),
                 {:ok, _} <- process_variant(source_tmp, variant_spec, dest_tmp),
                 {:ok, output_attrs} <- OutputProbe.verify!(dest_tmp, asset, variant_spec),
                 {:ok, storage_meta} <- upload_variant(asset, variant, dest_tmp, variant_spec),
                 :ok <-
                   persist_ready(
                     repo,
                     asset,
                     variant,
                     storage_meta,
                     dest_tmp,
                     variant_spec,
                     output_attrs
                   ) do
              :ok
            else
              {:cancel, reason} ->
                _ = handle_cancel(repo, variant, reason)
                {:cancel, normalize_public_reason(reason)}

              {:error, reason} ->
                handle_failure(repo, variant, reason)
            end
          after
            _ = TempRunDir.cleanup(run_dir)
          end
        else
          {:cancel, reason} ->
            _ = handle_cancel(repo, variant, reason)
            {:cancel, normalize_public_reason(reason)}

          {:error, reason} ->
            handle_failure(repo, variant, reason)
        end
      end)
    end
  end

  defp get_variant(repo, asset_id, name) do
    repo.one(from v in MediaVariant, where: v.asset_id == ^asset_id and v.name == ^name)
  end

  defp processing_variants(repo, asset_id) do
    repo.all(
      from v in MediaVariant,
        where: v.asset_id == ^asset_id and v.state in ["queued", "processing"],
        order_by: [asc: v.name]
    )
  end

  defp cancel_jobs(asset_id) do
    asset_query =
      from j in Job,
        where: j.worker == "Rindle.Workers.ProcessVariant",
        where: fragment("?->>'asset_id' = ?", j.args, ^asset_id)

    with {:ok, _count} <- Oban.cancel_all_jobs(asset_query) do
      :ok
    end
  end

  defp cancel_variants(repo, variants) do
    Enum.reduce_while(variants, :ok, fn variant, :ok ->
      case update_variant_state(repo, variant, "cancelled", %{
             error_reason: inspect(:variant_processing_cancelled)
           }) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp get_variant_spec(profile_module, name) do
    profile_module.variants()
    |> Enum.find(fn {n, _} -> Atom.to_string(n) == name end)
    |> elem(1)
  end

  defp ensure_variant_state(_repo, %{state: target_state}, target_state), do: :ok

  defp ensure_variant_state(repo, variant, target_state) do
    update_variant_state(repo, variant, target_state, %{})
  end

  defp update_variant_state(repo, variant, target_state, attrs) do
    with :ok <- VariantFSM.transition(variant.state, target_state, %{variant_id: variant.id}),
         {:ok, _} <-
           variant
           |> MediaVariant.changeset(Map.put(attrs, :state, target_state))
           |> repo.update() do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp download_source(asset, run_dir) do
    profile_module = String.to_existing_atom(asset.profile)
    source_name = "source#{Path.extname(asset.storage_key || "")}"
    tmp_path = TempRunDir.child(run_dir, source_name)
    Rindle.download(profile_module, asset.storage_key, tmp_path)
  end

  defp generate_dest_path(variant, variant_spec, run_dir) do
    extension = output_extension(variant_spec)
    {:ok, TempRunDir.child(run_dir, "#{variant.name}#{extension}")}
  end

  defp upload_variant(asset, variant, path, variant_spec) do
    profile_module = String.to_existing_atom(asset.profile)
    extension = output_extension(variant_spec)
    variant_key = deterministic_storage_key(asset, variant, extension)

    Rindle.store(profile_module, variant_key, path)
  end

  defp process_variant(source_tmp, variant_spec, dest_tmp) do
    case processor_for(variant_spec).(source_tmp, variant_spec, dest_tmp) do
      {:ok, _path} = ok -> ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp persist_ready(repo, asset, variant, storage_meta, dest_tmp, variant_spec, output_attrs) do
    current_asset = repo.get!(MediaAsset, asset.id)
    current_variant = repo.get!(MediaVariant, variant.id)

    cond do
      current_asset.storage_key != asset.storage_key ->
        {:cancel, {:stale_source, :asset_changed}}

      current_variant.recipe_digest != variant.recipe_digest ->
        {:cancel, {:stale_source, :recipe_changed}}

      true ->
        with :ok <-
               update_variant_state(
                 repo,
                 current_variant,
                 "ready",
                 %{
                   storage_key: storage_meta.key,
                   byte_size: get_file_size(dest_tmp),
                   content_type: content_type_for(variant_spec),
                   output_kind: output_kind_for(variant_spec),
                   generated_at: DateTime.utc_now(),
                   error_reason: nil
                 }
                 |> Map.merge(Map.take(output_attrs, [:duration_ms, :width, :height]))
               ),
             :ok <- AssetAggregate.recompute(repo, asset.id) do
          :ok
        end
    end
  end

  defp get_file_size(path) do
    File.stat!(path).size
  end

  defp handle_cancel(repo, variant, reason) do
    public_reason = normalize_public_reason(reason)
    variant = repo.get!(MediaVariant, variant.id)

    with :ok <-
           update_variant_state(repo, variant, "cancelled", %{error_reason: inspect(public_reason)}),
         :ok <- AssetAggregate.recompute(repo, variant.asset_id) do
      :ok
    end
  end

  defp handle_failure(repo, variant, reason) do
    public_reason = normalize_public_reason(reason)
    variant = repo.get!(MediaVariant, variant.id)

    _ =
      update_variant_state(repo, variant, "failed", %{
        error_reason: inspect(public_reason)
      })

    _ = AssetAggregate.recompute(repo, variant.asset_id)

    {:error, public_reason}
  end

  defp processor_for(%{kind: :video, output_kind: :video}), do: &Video.transcode/3
  defp processor_for(%{kind: :image, output_kind: :image}), do: &Video.image_output/3
  defp processor_for(%{kind: :audio, output_kind: :audio}), do: &Audio.transcode/3
  defp processor_for(%{kind: :waveform, output_kind: :waveform}), do: &Waveform.generate/3
  defp processor_for(_variant_spec), do: &Image.process/3

  defp normalize_variant_spec(variant_spec) when is_list(variant_spec) do
    normalize_variant_spec(Map.new(variant_spec))
  end

  defp normalize_variant_spec(%{} = variant_spec) do
    if normalized_av_spec?(variant_spec) do
      variant_spec
    else
      case AV.normalize(variant_spec) do
        {:ok, normalized} -> normalized
        {:error, _reason} -> variant_spec
      end
    end
  end

  defp execute_with_contract(asset, variant, variant_spec, fun) do
    if av_variant?(variant_spec) do
      started_at = System.monotonic_time()
      metadata = transcode_metadata(asset, variant, variant_spec)

      emit_transcode_event(:start, %{system_time: System.system_time()}, metadata)
      broadcast_progress(asset, variant, 0, "processing")

      case fun.() do
        :ok = ok ->
          broadcast_progress(asset, variant, 100, "ready")
          emit_transcode_event(:stop, duration_measurements(started_at), metadata)
          ok

        {:cancel, reason} ->
          public_reason = normalize_public_reason(reason)
          broadcast_progress(asset, variant, 0, "cancelled")

          emit_transcode_event(
            :exception,
            duration_measurements(started_at),
            Map.merge(metadata, %{kind: :error, reason: public_reason})
          )

          {:cancel, public_reason}

        {:error, reason} ->
          public_reason = normalize_public_reason(reason)
          broadcast_progress(asset, variant, 0, "failed")

          emit_transcode_event(
            :exception,
            duration_measurements(started_at),
            Map.merge(metadata, %{kind: :error, reason: public_reason})
          )

          {:error, public_reason}
      end
    else
      fun.()
    end
  end

  defp normalize_public_reason(:not_found), do: :variant_source_not_found
  defp normalize_public_reason(:variant_processing_cancelled), do: :variant_processing_cancelled
  defp normalize_public_reason({:stale_source, _why}), do: :variant_source_not_found
  defp normalize_public_reason({:unsupported_ephemeral_runtime, _runtime}), do: :processor_capability_missing
  defp normalize_public_reason({:output_duration_mismatch, _details}), do: :capability_drift
  defp normalize_public_reason({:ffmpeg_failed, _middle, _output}), do: :unsupported_codec
  defp normalize_public_reason({:ffmpeg_missing_output, _kind}), do: :capability_drift
  defp normalize_public_reason(reason), do: reason

  defp av_variant?(%{kind: kind}) when kind in [:video, :audio, :waveform], do: true

  defp av_variant?(%{preset: preset})
       when preset in [:video_poster_scene, :video_thumbnail_strip], do: true

  defp av_variant?(_variant_spec), do: false

  defp normalized_av_spec?(%{} = variant_spec) do
    Map.has_key?(variant_spec, :output_kind) or
      Map.has_key?(variant_spec, :container) or
      Map.has_key?(variant_spec, :video_codec) or
      Map.has_key?(variant_spec, :audio_codec)
  end

  defp normalized_av_spec?(_variant_spec), do: false

  defp maybe_put_timeout(args, variant_spec) do
    if av_variant?(variant_spec) do
      Map.put(args, "timeout", @av_timeout_ms)
    else
      args
    end
  end

  defp unique_job_opts do
    [
      fields: [:args, :worker, :queue],
      keys: [:asset_id, :variant_name],
      states: @unique_states,
      period: :infinity
    ]
  end

  defp deterministic_storage_key(asset, variant, extension) do
    Path.join([asset.profile, asset.id, "#{variant.name}-#{variant.recipe_digest}#{extension}"])
  end

  defp output_extension(%{kind: :video, container: container}), do: ".#{container}"
  defp output_extension(%{kind: :audio, container: container}), do: ".#{container}"
  defp output_extension(%{kind: :waveform}), do: ".json"
  defp output_extension(%{format: format}), do: ".#{normalize_format(format)}"
  defp output_extension(_variant_spec), do: ".jpg"

  defp normalize_format(format) when format in [:jpg, :jpeg, :png, :webp], do: format
  defp normalize_format(format) when is_binary(format), do: String.trim_leading(format, ".")
  defp normalize_format(_format), do: "jpg"

  defp content_type_for(%{kind: :video, container: :mp4}), do: "video/mp4"
  defp content_type_for(%{kind: :audio, container: :m4a}), do: "audio/mp4"
  defp content_type_for(%{kind: :audio, container: :mp3}), do: "audio/mpeg"
  defp content_type_for(%{kind: :waveform}), do: "application/json"
  defp content_type_for(%{format: :png}), do: "image/png"
  defp content_type_for(%{format: :webp}), do: "image/webp"
  defp content_type_for(_variant_spec), do: "image/jpeg"

  defp output_kind_for(%{output_kind: output_kind}), do: to_string(output_kind)
  defp output_kind_for(%{kind: kind}), do: to_string(kind)
  defp output_kind_for(_variant_spec), do: "image"

  defp duration_measurements(started_at) do
    %{
      duration: max(System.monotonic_time() - started_at, 1),
      system_time: System.system_time()
    }
  end

  defp transcode_metadata(asset, variant, variant_spec) do
    %{
      asset_id: asset.id,
      output_kind: output_kind_for(variant_spec),
      preset: Map.get(variant_spec, :preset),
      profile: asset.profile,
      variant_id: variant.id,
      variant_name: variant.name
    }
  end

  defp emit_transcode_event(stage, measurements, metadata) do
    :telemetry.execute([:rindle, :media, :transcode, stage], measurements, metadata)
  end

  defp broadcast_progress(asset, variant, progress, state) do
    ensure_pubsub_started()

    payload = %{
      asset_id: asset.id,
      progress: progress,
      variant_id: variant.id,
      variant_name: variant.name,
      state: state
    }

    event_type = public_event_type(progress, state)

    for topic <- ["rindle:variant:#{variant.id}", "rindle:asset:#{asset.id}"] do
      :ok = PubSub.broadcast(pubsub_server(), topic, {:rindle_event, event_type, payload})
    end

    :ok
  end

  defp public_event_type(0, "processing"), do: :variant_started
  defp public_event_type(_progress, "processing"), do: :variant_progress
  defp public_event_type(_progress, "ready"), do: :variant_ready
  defp public_event_type(_progress, "failed"), do: :variant_failed
  defp public_event_type(_progress, "cancelled"), do: :variant_cancelled

  defp ensure_pubsub_started do
    case Process.whereis(pubsub_server()) do
      nil -> :ok
      _pid -> :ok
    end
  end

  defp pubsub_server do
    Application.get_env(:rindle, :pubsub_server, Rindle.PubSub)
  end
end
