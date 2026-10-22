defmodule Twin.Tracer do
  use GenServer
  import Ecto.Query
  alias Twin.Repo
  alias Rindle.Domain.MediaAsset

  defmodule Owner do
    defstruct [:id]
  end

  def start_link(_), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  @impl true
  def init(_), do: {:ok, nil}
  def execute(operation, body), do: GenServer.call(__MODULE__, {operation, body}, 150_000)

  def health do
    %{
      "boot_id" => :persistent_term.get({Twin, :boot}),
      "elixir" => System.version(),
      "otp" =>
        File.read!(Path.join([:code.root_dir(), "releases", System.otp_release(), "OTP_VERSION"]))
        |> String.trim(),
      "oban" => Application.spec(:oban, :vsn) |> to_string(),
      "phoenix" => Application.spec(:phoenix, :vsn) |> to_string(),
      "origin" => :code.which(Rindle) |> to_string(),
      "lock_sha256" =>
        :crypto.hash(:sha256, File.read!("mix.lock")) |> Base.encode16(case: :lower)
    }
  end

  @impl true
  def handle_call({op, body}, _from, state) do
    result =
      try do
        scenario(op, body)
      rescue
        e ->
          %{
            "outcome" => "incomplete",
            "reason" =>
              Process.get(:twin_stage, "scenario") <>
                if(is_struct(e, MatchError), do: "_match", else: "_failed")
          }
      catch
        _, _ -> %{"outcome" => "incomplete", "reason" => "scenario_failed"}
      end

    {:reply, result, state}
  end

  # The fixture is local HTTP, reached only by the shipped adapter/SDK. Its
  # counters use a separate connection rather than calling this GenServer.
  def fixture_create(conn) do
    true =
      Plug.Conn.get_req_header(conn, "authorization") ==
        ["Basic " <> Base.encode64("twin-local-token:twin-local-secret")]

    %{
      "inputs" => [%{"url" => url}],
      "playback_policies" => ["signed"],
      "mp4_support" => "standard",
      "max_resolution_tier" => "1080p"
    } = conn.body_params

    [variant] = Repo.all(Rindle.Domain.MediaVariant)
    uri = URI.parse(url)
    true = uri.host == "minio"
    true = uri.path == "/" <> System.fetch_env!("TWIN_BUCKET") <> "/" <> variant.storage_key

    %{num_rows: 1} =
      Repo.query!(
        "UPDATE twin_fault_counters SET claims=claims+1,source_key=$2 WHERE run_id=$1 AND operation='provider-create'",
        [run_id(), hash(uri.path)]
      )

    %{"data" => %{"id" => provider_id(), "status" => "preparing", "playback_ids" => []}}
  end

  def fixture_delete(conn, id) do
    true = id == provider_id()

    true =
      Plug.Conn.get_req_header(conn, "authorization") ==
        ["Basic " <> Base.encode64("twin-local-token:twin-local-secret")]

    count_provider("provider-delete")
    :ok
  end

  defp provider_id, do: "MUX_PROVIDER_CANARY_" <> run_id()
  defp hash(nil), do: nil
  defp hash(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp count_provider(operation) do
    %{num_rows: 1} =
      Repo.query!(
        "UPDATE twin_fault_counters SET claims=claims+1 WHERE run_id=$1 AND operation=$2",
        [run_id(), operation]
      )

    :ok
  end

  defp provider_count(operation) do
    [[count]] =
      Repo.query!(
        "SELECT claims FROM twin_fault_counters WHERE run_id=$1 AND operation=$2",
        [run_id(), operation]
      ).rows

    count
  end

  defp provider_leak?(value) do
    encoded = inspect(value, limit: :infinity, printable_limit: :infinity)

    Enum.any?(
      [provider_id(), System.fetch_env!("TWIN_SECRET"), "BODY_CANARY"],
      &String.contains?(encoded, &1)
    )
  end

  defp provider_observers do
    for op <-
          ~w(provider-create provider-delete provider-state provider-processed provider-ready provider-leak provider-invalid) do
      %{num_rows: 1} =
        Repo.query!(
          "INSERT INTO twin_fault_counters(run_id,operation,source_key,claims) VALUES ($1,$2,'local-mux',0)",
          [run_id(), op]
        )
    end

    handler = {__MODULE__, run_id()}

    events =
      [[:rindle, :provider_asset, :state_change]] ++
        Enum.map(
          [:processed, :ignored, :exception, :verified, :rejected],
          &[:rindle, :provider, :webhook, &1]
        ) ++
        Enum.map([:start, :stop, :exception], &[:rindle, :provider, :ingest, &1]) ++
        Enum.map([:secret_used, :rejected], &[:rindle, :provider, :mux, :webhook_attempt, &1])

    :ok =
      :telemetry.attach_many(
        handler,
        events,
        fn event, _measurements, meta, _config ->
          if provider_leak?(meta), do: count_provider("provider-leak")

          case event do
            [:rindle, :provider_asset, :state_change] -> count_provider("provider-state")
            [:rindle, :provider, :webhook, :processed] -> count_provider("provider-processed")
            [:rindle, :provider, :webhook, :rejected] -> count_provider("provider-invalid")
            _ -> :ok
          end
        end,
        nil
      )

    :persistent_term.put({Twin, :provider_handler}, handler)
  end

  defp provider_messages(asset_id) do
    parent = self()

    observer =
      spawn_link(fn ->
        :ok = Phoenix.PubSub.subscribe(Rindle.PubSub, "rindle:provider_asset:" <> asset_id)
        :ok = Phoenix.PubSub.subscribe(Rindle.PubSub, "rindle:asset:" <> asset_id)
        send(parent, :provider_observer_ready)
        provider_message_loop()
      end)

    receive do
      :provider_observer_ready -> :persistent_term.put({Twin, :provider_observer}, observer)
    after
      5000 -> raise "observer_timeout"
    end
  end

  defp provider_message_loop do
    receive do
      {:rindle_event, :provider_asset_ready, payload} ->
        if provider_leak?(payload), do: count_provider("provider-leak")
        count_provider("provider-ready")
        provider_message_loop()

      {:rindle_event, type, _}
      when type in [:provider_asset_created, :provider_asset_errored, :provider_asset_deleted] ->
        count_provider("provider-leak")
        provider_message_loop()

      {:rindle_event, _, _} ->
        provider_message_loop()

      {:stop, parent} ->
        send(parent, :provider_observer_stopped)
    end
  end

  defp scenario("provider-begin", %{}) do
    Process.put(:twin_stage, "provider")
    provider_observers()
    :ok = Oban.pause_queue(queue: :rindle_promote)

    wait(fn ->
      q = Oban.check_queue(queue: :rindle_promote)
      q.paused and q.running == []
    end)

    {:ok, session} = Rindle.initiate_upload(Twin.ProviderProfile, filename: "twin.mp4")
    {:ok, %{presigned: signed}} = Rindle.Upload.Broker.sign_url(session.id)

    {:ok, {{_, status, _}, _, _}} =
      :httpc.request(
        :put,
        {String.to_charlist(signed.url), [], ~c"video/mp4", File.read!("/retained/av-input.mp4")},
        [timeout: 10_000],
        []
      )

    true = status in 200..299
    {:ok, %{asset: asset}} = Rindle.verify_completion(session.id)
    provider_messages(asset.id)
    :ok = Oban.resume_queue(queue: :rindle_promote)

    wait(fn ->
      case Repo.all(Rindle.Domain.MediaProviderAsset) do
        [%{state: "processing"}] -> true
        _ -> false
      end
    end)

    pause_provider()
    %{"snapshot" => provider_snapshot(), "effects" => provider_effects()}
  end

  defp scenario("provider-deliver", %{
         "label" => label,
         "event_type" => type,
         "created_at" => at,
         "invalid" => invalid
       }) do
    Process.put(:twin_stage, "provider")
    true = label in ["ready", "older-created", "older-error"]
    true = type in ["video.asset.ready", "video.asset.created", "video.asset.errored"]

    raw =
      Jason.encode!(%{
        "id" => label <> "-" <> run_id(),
        "type" => type,
        "created_at" => at,
        "data" => %{
          "id" => provider_id(),
          "status" => if(type == "video.asset.ready", do: "ready", else: "errored"),
          "playback_ids" => [%{"id" => "twin-playback"}],
          "profile" => "BODY_CANARY"
        }
      })

    timestamp = Integer.to_string(System.system_time(:second))

    signature =
      :crypto.mac(:hmac, :sha256, "twin-local-webhook-secret", timestamp <> "." <> raw)
      |> Base.encode16(case: :lower)

    signature = if invalid, do: String.duplicate("0", 64), else: signature

    {:ok, {{_, status, _}, _, _}} =
      :httpc.request(
        :post,
        {~c"http://localhost:4100/webhooks/mux",
         [{~c"mux-signature", String.to_charlist("t=" <> timestamp <> ",v1=" <> signature)}],
         ~c"application/json", raw},
        [timeout: 10_000],
        []
      )

    %{"status" => status}
  end

  defp scenario("provider-pending", %{}) do
    Process.put(:twin_stage, "provider")
    [job] = Repo.all(from j in Oban.Job, where: not is_nil(fragment("?->>'event_id'", j.args)))
    q = Oban.check_queue(queue: :rindle_provider)

    %{
      "paused" => q.paused,
      "running" => length(q.running),
      "job_id" => job.id,
      "count" => 1,
      "attempt" => job.attempt,
      "state" => job.state
    }
  end

  defp scenario("provider-advance", %{"completed" => expected, "ready" => ready}) do
    Process.put(:twin_stage, "provider")
    :ok = Oban.resume_queue(queue: :rindle_provider)

    wait(fn ->
      Repo.aggregate(
        from(j in Oban.Job,
          where: not is_nil(fragment("?->>'event_id'", j.args)) and j.state == "completed"
        ),
        :count
      ) == expected
    end)

    pause_provider()
    if ready, do: wait(fn -> provider_count("provider-ready") == 2 end)
    %{"snapshot" => provider_snapshot(), "effects" => provider_effects()}
  end

  defp scenario("provider-finish", %{}) do
    Process.put(:twin_stage, "provider")
    asset = Repo.one!(MediaAsset)
    [variant] = Rindle.ready_variants_for(asset.id)
    [row] = Repo.all(Rindle.Domain.MediaProviderAsset)
    jobs = Repo.all(from j in Oban.Job, order_by: j.id)
    [promotion, media, create | webhooks] = jobs

    true =
      promotion.queue == "rindle_promote" and media.queue == "rindle_media" and
        create.queue == "rindle_provider"

    true = Enum.all?(jobs, &(&1.state == "completed" and &1.attempt == 1))
    true = length(webhooks) == 4
    roles = ~w(promotion media create ready replay older_created older_errored)

    projected =
      Enum.zip_with(jobs, roles, fn j, role ->
        %{
          "id" => j.id,
          "role" => role,
          "queue" => j.queue,
          "state" => j.state,
          "attempt" => j.attempt,
          "event_sha256" => hash(j.args["event_id"])
        }
      end)

    [[path_hash]] =
      Repo.query!(
        "SELECT source_key FROM twin_fault_counters WHERE run_id=$1 AND operation='provider-create'",
        [run_id()]
      ).rows

    %{
      "asset_id" => asset.id,
      "source_key" => asset.storage_key,
      "variant_key" => variant.storage_key,
      "provider_row_id" => row.id,
      "provider_sha256" => hash(row.provider_asset_id),
      "jobs" => projected,
      "create_calls" => provider_count("provider-create"),
      "input_path_sha256" => path_hash,
      "invalid_signatures" => provider_count("provider-invalid"),
      "leaks" => provider_count("provider-leak"),
      "sdk_version" => to_string(Application.spec(:mux, :vsn)),
      "sdk_origin" => to_string(:code.which(Mux.Video.Assets))
    }
  end

  defp scenario("tus-start", %{}) do
    Process.put(:twin_stage, "tus")

    %{num_rows: 1} =
      Repo.query!(
        "INSERT INTO twin_fault_counters(run_id,operation,source_key,claims) VALUES ($1,'tus','one-upload',1) ON CONFLICT DO NOTHING",
        [run_id()]
      )

    %{"outcome" => "started"}
  end

  defp scenario("tus-finish", %{}) do
    Process.put(:twin_stage, "tus")
    [session] = Repo.all(Rindle.Domain.MediaUploadSession)
    true = session.state == "completed"
    true = session.resumable_protocol == "tus"

    [variant] =
      wait(fn ->
        case Rindle.ready_variants_for(session.asset_id) do
          [v] -> [v]
          _ -> false
        end
      end)

    asset = Repo.get!(MediaAsset, session.asset_id)
    true = asset.state == "ready"
    true = Repo.aggregate(MediaAsset, :count) == 1
    target = "/retained/tus-source.png"
    {:ok, ^target} = Rindle.download(Twin.Profile, asset.storage_key, target)
    checksum = :crypto.hash(:sha256, File.read!(target)) |> Base.encode16(case: :lower)
    File.rm!(target)

    [[1]] =
      Repo.query!("SELECT claims FROM twin_fault_counters WHERE run_id=$1 AND operation='tus'", [
        run_id()
      ]).rows

    %{
      "outcome" => "ready",
      "session_id" => session.id,
      "asset_id" => asset.id,
      "session_state" => session.state,
      "asset_state" => asset.state,
      "source_key" => asset.storage_key,
      "variant_keys" => [variant.storage_key],
      "checksum_sha256" => checksum,
      "sessions" => 1,
      "assets" => 1,
      "upload_stimuli" => 1,
      "offset" => session.last_known_offset,
      "boot_id" => health()["boot_id"]
    }
  end

  defp scenario("av-begin", %{}) do
    Process.put(:twin_stage, "av")

    %{num_rows: 1} =
      Repo.query!(
        "INSERT INTO twin_fault_counters(run_id,operation,source_key,claims) VALUES ($1,'av-stimulus','one-upload',1) ON CONFLICT DO NOTHING",
        [run_id()]
      )

    :ok = Oban.pause_queue(queue: :rindle_media)

    wait(fn ->
      q = Oban.check_queue(queue: :rindle_media)
      q.paused and q.running == []
    end)

    {:ok, session} = Rindle.initiate_upload(Twin.AVProfile, filename: "twin.mp4")
    {:ok, %{presigned: signed}} = Rindle.Upload.Broker.sign_url(session.id)

    {:ok, {{_, status, _}, _, _}} =
      :httpc.request(
        :put,
        {String.to_charlist(signed.url), [], ~c"video/mp4", File.read!("/retained/av-input.mp4")},
        [timeout: 10_000],
        []
      )

    true = status in 200..299
    {:ok, %{asset: asset}} = Rindle.verify_completion(session.id)

    job =
      wait(fn ->
        case Repo.all(from j in Oban.Job, where: j.queue == "rindle_media") do
          [%{state: "available", attempt: 0} = j] -> j
          [] -> false
          _ -> raise "unexpected_job"
        end
      end)

    [variant] = Repo.all(from v in Rindle.Domain.MediaVariant, where: v.asset_id == ^asset.id)
    fresh = Repo.get!(MediaAsset, asset.id)
    true = fresh.kind == "video" and fresh.has_video_track and fresh.has_audio_track
    true = fresh.duration_ms > 0

    %{num_rows: 2} =
      Repo.query!(
        "INSERT INTO twin_fault_counters(run_id,operation,source_key,claims) VALUES ($1,'av-enabled',$2,1),($1,'av-download',$2,0)",
        [run_id(), fresh.storage_key]
      )

    :ok = Oban.resume_queue(queue: :rindle_media)

    %{
      "asset_id" => asset.id,
      "session_id" => session.id,
      "source_key" => fresh.storage_key,
      "job_id" => job.id,
      "variant_id" => variant.id,
      "variant_name" => variant.name,
      "recipe_digest" => variant.recipe_digest,
      "max_attempts" => job.max_attempts,
      "source_video" => true,
      "source_audio" => true,
      "source_duration_ms" => fresh.duration_ms,
      "upload_stimuli" => 1,
      "boot_id" => health()["boot_id"]
    }
  end

  defp scenario("av-status", %{"job_id" => id, "asset_id" => asset_id}) do
    Process.put(:twin_stage, "av")
    job = Repo.get!(Oban.Job, id)
    true = job.args["asset_id"] == asset_id
    [variant] = Repo.all(from v in Rindle.Domain.MediaVariant, where: v.asset_id == ^asset_id)

    [[claims]] =
      Repo.query!(
        "SELECT claims FROM twin_fault_counters WHERE run_id=$1 AND operation='av-download'",
        [run_id()]
      ).rows

    diagnostic =
      if job.state == "discarded" do
        {:ok, report} = Rindle.runtime_status(profile: to_string(Twin.AVProfile))
        [finding] = Enum.filter(report.variants.findings, &(&1.class == :failed_work))
        true = finding.count == 1

        true =
          Enum.any?(finding.samples, &(&1.asset_id == asset_id and &1.variant_id == variant.id))

        "failed_work"
      else
        "pending"
      end

    %{
      "job_id" => job.id,
      "attempt" => job.attempt,
      "state" => job.state,
      "error_attempts" => Enum.map(job.errors, & &1["attempt"]),
      "variant_id" => variant.id,
      "variant_state" => variant.state,
      "diagnostic" => diagnostic,
      "fault_downloads" => claims,
      "processor_reason" =>
        if(variant.error_reason == ":unsupported_codec", do: "unsupported_codec", else: "pending")
    }
  end

  defp scenario("av-repair", %{"job_id" => old_id, "asset_id" => asset_id}) do
    Process.put(:twin_stage, "av")
    old = Repo.get!(Oban.Job, old_id)
    %{state: "discarded", attempt: 5, args: %{"asset_id" => ^asset_id}} = old
    [variant] = Repo.all(from v in Rindle.Domain.MediaVariant, where: v.asset_id == ^asset_id)
    true = variant.state == "failed"

    %{num_rows: 1} =
      Repo.query!(
        "UPDATE twin_fault_counters SET claims=0 WHERE run_id=$1 AND operation='av-enabled' AND claims=1",
        [run_id()]
      )

    {:ok, report} = Rindle.requeue_variants(asset_id, variant_names: [:web_720p])

    %{selected: 1, enqueued: 1, skipped: 0, errors: 0} = report

    [new_job] = Repo.all(from j in Oban.Job, where: j.queue == "rindle_media" and j.id != ^old_id)
    true = new_job.args["asset_id"] == asset_id and new_job.args["variant_name"] == "web_720p"

    completed =
      wait(fn ->
        j = Repo.get!(Oban.Job, new_job.id)

        cond do
          j.state == "completed" and j.attempt == 1 -> j
          j.state in ["discarded", "cancelled"] or j.attempt > 1 -> raise "repair_failed"
          true -> false
        end
      end)

    [ready] = Rindle.ready_variants_for(asset_id)
    %{name: "web_720p", error_reason: nil} = ready
    true = ready.id == variant.id
    asset = Repo.get!(MediaAsset, asset_id)
    true = asset.state == "ready"
    {:ok, _} = Rindle.download(Twin.AVProfile, asset.storage_key, "/retained/av-source-check.mp4")
    {:ok, _} = Rindle.download(Twin.AVProfile, ready.storage_key, "/retained/av-output.mp4")
    hash = fn path -> :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower) end

    %{
      "asset_id" => asset_id,
      "variant_id" => ready.id,
      "source_key" => asset.storage_key,
      "variant_key" => ready.storage_key,
      "source_sha256" => hash.("/retained/av-source-check.mp4"),
      "output_sha256" => hash.("/retained/av-output.mp4"),
      "asset_state" => asset.state,
      "variant_state" => ready.state,
      "discarded_job_id" => old_id,
      "new_job_id" => completed.id,
      "new_job_state" => completed.state,
      "new_job_attempt" => completed.attempt,
      "selected" => report.selected,
      "enqueued" => report.enqueued,
      "skipped" => report.skipped,
      "errors" => report.errors,
      "fault_restored" => true,
      "error_cleared" => true
    }
  end

  defp scenario("begin", %{}) do
    Process.put(:twin_stage, "stimulus")
    # Exclusive durable stimulus claim. A second request cannot upload/detach again.
    %{num_rows: 1} =
      Repo.query!(
        "INSERT INTO twin_fault_counters(run_id,operation,source_key,claims) VALUES ($1,'stimulus','lifecycle',1) ON CONFLICT DO NOTHING",
        [run_id()]
      )

    Process.put(:twin_stage, "upload_initiate")
    {:ok, session} = Rindle.initiate_upload(Twin.Profile, filename: "twin.png")
    Process.put(:twin_stage, "upload_sign")
    {:ok, %{presigned: signed}} = Rindle.Upload.Broker.sign_url(session.id)

    png =
      Base.decode64!(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVQI12P4//8/AAX+Av7cRHQGAAAAAElFTkSuQmCC"
      )

    Process.put(:twin_stage, "upload_put")

    {:ok, {{_, status, _}, _, _}} =
      :httpc.request(
        :put,
        {String.to_charlist(signed.url), [], ~c"application/octet-stream", png},
        [timeout: 10_000],
        []
      )

    true = status in 200..299
    Process.put(:twin_stage, "upload_verify")
    {:ok, %{asset: asset}} = Rindle.verify_completion(session.id)

    [variant] =
      wait(fn ->
        case Rindle.ready_variants_for(asset.id) do
          [v] -> [v]
          _ -> false
        end
      end)

    Process.put(:twin_stage, "asset_read")
    asset = Repo.get!(MediaAsset, asset.id)

    %{num_rows: 1} =
      Repo.query!(
        "INSERT INTO twin_fault_counters(run_id,operation,source_key,claims) VALUES ($1,'delete',$2,0)",
        [run_id(), asset.storage_key]
      )

    %{num_rows: 1} =
      Repo.query!(
        "UPDATE twin_fault_counters SET source_key=$2 WHERE run_id=$1 AND operation='stimulus'",
        [run_id(), asset.storage_key]
      )

    owner = %Owner{id: Ecto.UUID.generate()}
    Process.put(:twin_stage, "attach")
    {:ok, _} = Rindle.attach(asset.id, owner, "avatar")
    Process.put(:twin_stage, "detach")
    :ok = Rindle.detach(owner, "avatar")

    Process.put(:twin_stage, "job_retry")

    job =
      wait(fn ->
        case Repo.all(from j in Oban.Job, where: j.queue == "rindle_purge") do
          [%{state: "retryable", attempt: 1, errors: [_ | _]} = j] -> j
          [] -> false
          [%{attempt: a}] when a <= 1 -> false
          _ -> raise "unexpected_job"
        end
      end)

    true = job.args["asset_id"] == asset.id
    true = Repo.get(MediaAsset, asset.id) != nil
    {:ok, %{size: source_bytes}} = Twin.StorageFault.head(asset.storage_key, [])
    true = source_bytes > 0
    {:error, :not_found} = Twin.StorageFault.head(variant.storage_key, [])
    Process.put(:twin_stage, "pause")
    :ok = Oban.pause_queue(queue: :rindle_purge)

    queue =
      wait(fn ->
        q = Oban.check_queue(queue: :rindle_purge)
        if q.paused and q.running == [], do: q, else: false
      end)

    Process.put(:twin_stage, "barrier")
    fresh = Repo.get!(Oban.Job, job.id)
    true = barrier?(queue, fresh)

    %{
      "outcome" => "paused",
      "asset_id" => asset.id,
      "source_key" => asset.storage_key,
      "job_id" => job.id,
      "attempt" => fresh.attempt,
      "state" => fresh.state,
      "error_count" => length(fresh.errors),
      "asset_retained" => true,
      "source_present" => true,
      "ready_variant_count" => 1,
      "variant_deletes_before_failure" => 1,
      "paused" => true,
      "running" => 0,
      "stimuli" => %{"upload" => 1, "attach" => 1, "detach" => 1},
      "boot_id" => health()["boot_id"]
    }
  end

  defp scenario("resume", %{"job_id" => id, "asset_id" => asset_id}) when is_integer(id) do
    Process.put(:twin_stage, "job_retry")

    job =
      wait(fn ->
        j = Repo.get!(Oban.Job, id)
        true = j.args["asset_id"] == asset_id

        cond do
          j.state == "completed" and j.attempt == 2 -> j
          j.attempt > 2 or j.state in ["discarded", "cancelled"] -> raise "wrong_attempt"
          true -> false
        end
      end)

    true = Repo.get(MediaAsset, asset_id) == nil

    %{
      "outcome" => "completed",
      "job_id" => job.id,
      "attempt" => job.attempt,
      "state" => job.state,
      "asset_absent" => true,
      "error_count" => length(job.errors),
      "boot_id" => health()["boot_id"],
      "fault_claims" => fault_claims()
    }
  end

  defp scenario("purge-absent", %{"source_key" => key, "asset_id" => asset_id, "job_id" => id}) do
    Process.put(:twin_stage, "barrier")
    asset = Repo.get!(MediaAsset, asset_id)
    true = asset.storage_key == key
    queue = Oban.check_queue(queue: :rindle_purge)
    job = Repo.get!(Oban.Job, id)
    true = job.args["asset_id"] == asset_id
    true = barrier?(queue, job)
    {:error, :not_found} = Rindle.head(Twin.Profile, key)

    %{
      "source_key" => key,
      "asset_id" => asset_id,
      "job_id" => id,
      "head" => "not_found",
      "asset_retained" => true,
      "paused" => queue.paused,
      "running" => length(queue.running),
      "attempt" => job.attempt,
      "state" => job.state,
      "error_count" => length(job.errors)
    }
  end

  defp scenario("purge-resume", body) do
    :ok = Oban.resume_queue(queue: :rindle_purge)
    scenario("resume", body)
  end

  defp scenario("inventory", %{}) do
    for queue <- [
          :rindle_media,
          :rindle_promote,
          :rindle_process,
          :rindle_purge,
          :rindle_maintenance
        ] do
      :ok = Oban.pause_queue(queue: queue)

      wait(fn ->
        q = Oban.check_queue(queue: queue)
        q.paused and q.running == []
      end)
    end

    domain =
      Repo.query!("SELECT tablename FROM pg_tables WHERE schemaname='rindle' ORDER BY tablename").rows
      |> Map.new(fn [table] ->
        # Catalog supplied identifiers, quoted before use; no lifecycle writes.
        quoted = String.replace(table, "\"", "\"\"")
        [[count]] = Repo.query!("SELECT count(*) FROM rindle.\"#{quoted}\"").rows
        {table, count}
      end)

    jobs =
      Repo.all(
        from j in Oban.Job,
          select: %{id: j.id, state: j.state, attempt: j.attempt, queue: j.queue}
      )

    relations =
      Repo.query!(
        "SELECT schemaname,tablename FROM pg_tables WHERE schemaname IN ('public','rindle') ORDER BY schemaname,tablename"
      ).rows
      |> Enum.group_by(&hd/1, &List.last/1)

    [[fixture_rows]] = Repo.query!("SELECT count(*) FROM twin_fault_counters").rows
    [[migration_rows]] = Repo.query!("SELECT count(*) FROM public.schema_migrations").rows
    [[peer_rows]] = Repo.query!("SELECT count(*) FROM public.oban_peers").rows
    files = Path.wildcard("/retained/tmp/**/*", match_dot: true) |> Enum.reject(&File.dir?/1)

    %{
      "domain" => domain,
      "relations" => relations,
      "fixture_rows" => fixture_rows,
      "schema_migration_rows" => migration_rows,
      "peer_rows" => peer_rows,
      "listing_complete" => true,
      "jobs" => jobs,
      "temp_files" => length(files),
      "fault_claims" => fault_claims(),
      "writers_paused" => true
    }
  end

  defp scenario(_, _), do: %{"outcome" => "incomplete", "reason" => "operation_refused"}

  defp pause_provider do
    :ok = Oban.pause_queue(queue: :rindle_provider)

    wait(fn ->
      q = Oban.check_queue(queue: :rindle_provider)
      q.paused and q.running == []
    end)
  end

  defp provider_snapshot do
    [row] = Repo.all(Rindle.Domain.MediaProviderAsset)

    %{
      "row_id" => row.id,
      "asset_id" => row.asset_id,
      "provider_sha256" => hash(row.provider_asset_id),
      "state" => row.state,
      "playback_ids" => row.playback_ids,
      "last_event_at" =>
        if(row.last_event_at, do: DateTime.to_iso8601(row.last_event_at), else: nil),
      "event_sha256" => hash(row.last_event_id)
    }
  end

  defp provider_effects do
    %{
      "state_changes" => provider_count("provider-state"),
      "processed" => provider_count("provider-processed"),
      "ready_messages" => provider_count("provider-ready")
    }
  end

  def barrier?(%{paused: true, running: []}, %{state: "retryable", attempt: 1, errors: [_ | _]}),
    do: true

  def barrier?(_, _), do: false
  defp run_id, do: System.fetch_env!("TWIN_RUN_ID")

  defp fault_claims do
    [[n]] =
      Repo.query!(
        "SELECT claims FROM twin_fault_counters WHERE run_id=$1 AND operation='delete'",
        [run_id()]
      ).rows

    n
  end

  defp wait(fun), do: poll(fun, System.monotonic_time(:millisecond) + 90_000)

  defp poll(fun, deadline) do
    case fun.() do
      value when value not in [nil, false] ->
        value

      _ ->
        if System.monotonic_time(:millisecond) >= deadline, do: raise("deadline")
        Process.sleep(100)
        poll(fun, deadline)
    end
  end
end

defmodule Twin.ProviderProfile do
  use Rindle.Profile,
    storage: Twin.StorageFault,
    variants: [web_720p: [kind: :video, preset: :web_720p]],
    allow_mime: ["video/mp4"],
    max_bytes: 1_048_576,
    delivery: [
      streaming: [
        provider: Rindle.Streaming.Provider.Mux,
        playback_policy: :signed,
        ingest_mode: :server_push,
        source_variant: :web_720p
      ]
    ]
end
