defmodule Twin.Tracer do
  use GenServer
  import Ecto.Query
  import SweetXml, only: [sigil_x: 2]
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

  defp scenario("cleanup-begin", %{}) do
    Process.put(:twin_stage, "cleanup")
    false = :persistent_term.get({Twin, :cleanup}, false)

    {:ok, %{session: multipart, multipart: %{upload_id: upload_id}}} =
      Rindle.initiate_multipart_upload(Twin.Profile, filename: "multipart.png", expires_in: 5)

    {:ok, %{session: signed_multipart, presigned: signed}} =
      Rindle.sign_multipart_part(multipart.id, 1)

    png =
      Base.decode64!(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVQI12P4//8/AAX+Av7cRHQGAAAAAElFTkSuQmCC"
      )

    etag = cleanup_put(signed.url, png)
    {:ok, orphan} = Rindle.initiate_upload(Twin.Profile, filename: "orphan.png", expires_in: 5)

    {:ok, %{session: signed_orphan, presigned: orphan_signed}} =
      Rindle.Upload.Broker.sign_url(orphan.id)

    _ = cleanup_put(orphan_signed.url, png)
    {:ok, %{size: 69}} = Rindle.head(Twin.Profile, orphan.upload_key)
    true = Repo.aggregate(Rindle.Domain.MediaUploadSession, :count) == 2
    true = Repo.aggregate(MediaAsset, :count) == 2
    true = Repo.aggregate(Oban.Job, :count) == 0

    private = %{
      multipart: signed_multipart,
      orphan: signed_orphan,
      upload_id: upload_id,
      etag: etag,
      expires: [signed_multipart.expires_at, signed_orphan.expires_at]
    }

    :persistent_term.put({Twin, :cleanup}, private)
    parts = cleanup_observe_multipart(private)
    observed = DateTime.utc_now()
    true = Enum.all?(private.expires, &(DateTime.compare(observed, &1) == :lt))

    for {operation, key} <- [
          {"cleanup-multipart", multipart.upload_key},
          {"cleanup-orphan", orphan.upload_key}
        ] do
      %{num_rows: 1} =
        Repo.query!(
          "INSERT INTO twin_fault_counters(run_id,operation,source_key,claims) VALUES ($1,$2,$3,1)",
          [run_id(), operation, key]
        )
    end

    %{
      "multipart_session_id" => multipart.id,
      "orphan_session_id" => orphan.id,
      "multipart_asset_id" => multipart.asset_id,
      "orphan_asset_id" => orphan.asset_id,
      "multipart_key" => multipart.upload_key,
      "orphan_key" => orphan.upload_key,
      "upload_sha256" => hash(upload_id),
      "parts" => parts,
      "expiry_seconds" => 5,
      "observed_at" => DateTime.to_iso8601(observed),
      "expires_at" => Enum.map(private.expires, &DateTime.to_iso8601/1),
      "stimuli" => %{"multipart" => 1, "orphan" => 1}
    }
  end

  defp scenario("cleanup-expired", %{}) do
    Process.put(:twin_stage, "cleanup")
    now = DateTime.utc_now()
    %{"expired" => Enum.all?(cleanup_private().expires, &(DateTime.compare(now, &1) != :lt))}
  end

  defp scenario("cleanup-after-abort", %{}) do
    Process.put(:twin_stage, "cleanup")
    private = cleanup_private()
    sessions = cleanup_sessions(private)
    true = Enum.map(sessions, & &1.state) == ["expired", "expired"]
    observed = DateTime.utc_now()
    true = Enum.all?(private.expires, &(DateTime.compare(observed, &1) != :lt))

    %{
      "states" => ["expired", "expired"],
      "observed_at" => DateTime.to_iso8601(observed),
      "task_exit" => 0,
      "multipart_present" => true,
      "parts" => cleanup_observe_multipart(private),
      "listing_complete" => true
    }
  end

  defp scenario("cleanup-arm", %{}) do
    Process.put(:twin_stage, "cleanup")
    private = cleanup_private()
    true = Enum.all?(cleanup_sessions(private), &(&1.state == "expired"))
    {:ok, %{size: 69}} = Rindle.head(Twin.Profile, private.orphan.upload_key)

    %{num_rows: 1} =
      Repo.query!(
        "INSERT INTO twin_fault_counters(run_id,operation,source_key,claims) VALUES ($1,'cleanup-arm',$2,1)",
        [run_id(), private.orphan.upload_key]
      )

    %{"armed" => true}
  end

  defp scenario("cleanup-barrier", %{}) do
    Process.put(:twin_stage, "cleanup")
    private = cleanup_private()

    case cleanup_barrier(private) do
      [] ->
        %{"ready" => false}

      [[pid]] when is_integer(pid) and pid > 1 ->
        true = pid != String.to_integer(System.pid())

        %{
          "ready" => true,
          "maintenance_pid" => pid,
          "main_pid" => String.to_integer(System.pid())
        }
    end
  end

  defp scenario("cleanup-interrupted", %{}) do
    Process.put(:twin_stage, "cleanup")
    private = cleanup_private()
    orphan = Repo.get!(Rindle.Domain.MediaUploadSession, private.orphan.id)
    true = orphan.state == "expired" and orphan.upload_key == private.orphan.upload_key
    {:error, :not_found} = Rindle.head(Twin.Profile, orphan.upload_key)
    [[pid]] = cleanup_barrier(private)
    true = pid > 1 and pid != String.to_integer(System.pid())

    [[0]] =
      Repo.query!(
        "SELECT claims FROM twin_fault_counters WHERE run_id=$1 AND operation='cleanup-arm' AND source_key=$2",
        [run_id(), orphan.upload_key]
      ).rows

    %{
      "orphan_session_id" => orphan.id,
      "orphan_key" => orphan.upload_key,
      "row_retained" => true,
      "row_state" => orphan.state,
      "object_head" => "not_found",
      "barrier" => "after_delete_before_row",
      "maintenance_pid" => pid,
      "main_pid" => String.to_integer(System.pid()),
      "main_boot_id" => health()["boot_id"]
    }
  end

  defp scenario("cleanup-converged", %{}) do
    Process.put(:twin_stage, "cleanup")
    private = cleanup_private()
    true = Repo.aggregate(Rindle.Domain.MediaUploadSession, :count) == 0
    true = Repo.aggregate(Oban.Job, :count) == 0

    for original <- [private.multipart, private.orphan] do
      asset = Repo.get!(MediaAsset, original.asset_id)
      true = asset.state == "staged" and asset.storage_key == original.upload_key
      {:error, :not_found} = Rindle.head(Twin.Profile, original.upload_key)
    end

    true = Repo.aggregate(MediaAsset, :count) == 2
    true = cleanup_missing_upload?(cleanup_list_parts(private))
    {:ok, []} = cleanup_list_uploads()

    {:ok, %{status_code: 200, body: xml}} =
      cleanup_s3(ExAws.S3.list_objects_v2(System.fetch_env!("TWIN_BUCKET"), max_keys: 1000))

    {:ok, []} = cleanup_objects(xml, System.fetch_env!("TWIN_BUCKET"))

    %{
      "task_exit" => 0,
      "sessions" => 0,
      "objects" => 0,
      "multipart" => 0,
      "parts" => 0,
      "listing_complete" => true
    }
  end

  defp scenario("cleanup-finish", %{}) do
    Process.put(:twin_stage, "cleanup")
    private = cleanup_private()
    true = Repo.aggregate(Rindle.Domain.MediaUploadSession, :count) == 0
    true = Repo.aggregate(Oban.Job, :count) == 0
    ids = Enum.sort([private.multipart.asset_id, private.orphan.asset_id])

    for id <- ids do
      %{state: "staged"} = Repo.get!(MediaAsset, id)
      owner = %Owner{id: Ecto.UUID.generate()}
      {:ok, _} = Rindle.attach(id, owner, "cleanup")
      :ok = Rindle.detach(owner, "cleanup")
    end

    jobs =
      wait(fn ->
        jobs = Repo.all(from j in Oban.Job, order_by: j.id)
        true = length(jobs) == 2
        true = Enum.sort(Enum.map(jobs, & &1.args["asset_id"])) == ids
        true = Enum.all?(jobs, &(&1.queue == "rindle_purge"))

        cond do
          Enum.all?(jobs, &(&1.state == "completed" and &1.attempt == 1)) ->
            jobs

          Enum.any?(jobs, &(&1.state in ["discarded", "cancelled"] or &1.attempt > 1)) ->
            raise "cleanup_purge_failed"

          true ->
            false
        end
      end)

    tables =
      Repo.query!("SELECT tablename FROM pg_tables WHERE schemaname='rindle' ORDER BY tablename").rows

    domain =
      ~w(media_assets media_attachments media_processing_runs media_provider_assets media_upload_sessions media_variants)

    true = Enum.sort(Enum.map(tables, &hd/1)) == Enum.sort(["rindle_migration_versions" | domain])

    for table <- domain do
      quoted = String.replace(table, "\"", "\"\"")
      [[0]] = Repo.query!("SELECT count(*) FROM rindle.\"#{quoted}\"").rows
    end

    %{
      "asset_ids" => ids,
      "purge_jobs" => Enum.map(jobs, &Map.take(&1, [:id, :queue, :state, :attempt])),
      "domain_empty" => true
    }
  end

  defp scenario("promotion-begin", %{}) do
    Process.put(:twin_stage, "promotion")

    %{num_rows: 1} =
      Repo.query!(
        "INSERT INTO twin_fault_counters(run_id,operation,source_key,claims) VALUES ($1,'promotion-upload','one-upload',1) ON CONFLICT DO NOTHING",
        [run_id()]
      )

    :ok = Oban.pause_queue(queue: :rindle_promote)

    wait(fn ->
      q = Oban.check_queue(queue: :rindle_promote)
      q.paused and q.running == []
    end)

    {:ok, session} = Rindle.initiate_upload(Twin.Profile, filename: "twin.png")
    {:ok, %{presigned: signed}} = Rindle.Upload.Broker.sign_url(session.id)

    png =
      Base.decode64!(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVQI12P4//8/AAX+Av7cRHQGAAAAAElFTkSuQmCC"
      )

    {:ok, {{_, status, _}, _, _}} =
      :httpc.request(
        :put,
        {String.to_charlist(signed.url), [], ~c"image/png", png},
        [timeout: 10_000],
        []
      )

    true = status in 200..299
    {:ok, %{asset: asset}} = Rindle.verify_completion(session.id)

    %{num_rows: 1} =
      Repo.query!(
        "INSERT INTO twin_fault_counters(run_id,operation,source_key,claims) VALUES ($1,'promotion-completion',$2,1)",
        [run_id(), session.id]
      )

    [job] = Repo.all(Oban.Job)
    true = job.queue == "rindle_promote"
    promotion_cut(session.id, asset.id, job.id)
  end

  defp scenario("promotion-cut", %{"session_id" => session, "asset_id" => asset, "job_id" => job}) do
    Process.put(:twin_stage, "promotion")
    promotion_cut(session, asset, job)
  end

  defp scenario("promotion-finish", %{
         "session_id" => session_id,
         "asset_id" => asset_id,
         "job_id" => job_id
       }) do
    Process.put(:twin_stage, "promotion")
    :ok = Oban.resume_queue(queue: :rindle_promote)

    [variant] =
      wait(fn ->
        case Rindle.ready_variants_for(asset_id) do
          [v] -> [v]
          _ -> false
        end
      end)

    for queue <- [:rindle_promote, :rindle_process] do
      :ok = Oban.pause_queue(queue: queue)

      wait(fn ->
        q = Oban.check_queue(queue: queue)
        q.paused and q.running == []
      end)
    end

    asset = Repo.get!(MediaAsset, asset_id)
    session = Repo.get!(Rindle.Domain.MediaUploadSession, session_id)
    job = Repo.get!(Oban.Job, job_id)
    %{state: "completed", attempt: 1, args: %{"asset_id" => ^asset_id}} = job
    %{state: "ready"} = asset
    %{state: "completed", asset_id: ^asset_id} = session
    target = "/retained/promotion-source.png"
    {:ok, ^target} = Rindle.download(Twin.Profile, asset.storage_key, target)
    checksum = hash(File.read!(target))
    File.rm!(target)
    jobs = Repo.all(from j in Oban.Job, order_by: j.id)

    %{
      "after" => %{
        "session_id" => session.id,
        "asset_id" => asset.id,
        "source_key" => asset.storage_key,
        "job_id" => job.id,
        "attempt" => job.attempt,
        "state" => job.state,
        "asset_state" => asset.state,
        "session_state" => session.state,
        "upload_stimuli" => promotion_count("promotion-upload"),
        "completion_stimuli" => promotion_count("promotion-completion"),
        "boot_id" => health()["boot_id"],
        "checksum_sha256" => checksum,
        "variant_key" => variant.storage_key
      },
      "jobs" => Enum.map(jobs, &Map.take(&1, [:id, :queue, :state, :attempt]))
    }
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

  defp scenario("audit-prepare", %{"case_id" => case_id, "asset_ids" => asset_ids}) do
    Process.put(:twin_stage, "audit")
    current_ids = Repo.all(from a in MediaAsset, order_by: a.id, select: a.id)
    true = audit_scope?(case_id, asset_ids, current_ids)
    audit_pause_queues()
    if case_id == "provider-events", do: audit_provider_cleanup(asset_ids)

    for id <- current_ids do
      owner = %Owner{id: Ecto.UUID.generate()}
      {:ok, _} = Rindle.attach(id, owner, "twin-cleanup")
      :ok = Rindle.detach(owner, "twin-cleanup")
    end

    if current_ids != [], do: :ok = Oban.resume_queue(queue: :rindle_purge)

    purge_jobs =
      wait(fn ->
        jobs = Repo.all(from j in Oban.Job, where: j.queue == "rindle_purge", order_by: j.id)
        true = Enum.sort(Enum.map(jobs, & &1.args["asset_id"])) == asset_ids

        cond do
          Enum.all?(jobs, &(&1.state == "completed")) -> jobs
          Enum.any?(jobs, &(&1.state in ["cancelled", "discarded"])) -> raise "audit_purge_failed"
          true -> false
        end
      end)

    audit_pause_queues()
    true = Repo.aggregate(MediaAsset, :count) == 0
    %{type: :directory} = File.lstat!("/retained/tmp")
    [] = audit_temp_entries("/retained/tmp")

    %{
      "writers_paused" => true,
      "temp_files" => [],
      "purge_job_ids" => Enum.map(purge_jobs, & &1.id)
    }
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

  def audit_scope?(case_id, requested, current) when is_list(requested) and is_list(current) do
    expected =
      Map.get(
        %{
          "tus-resume" => 1,
          "purge-absence" => 1,
          "av-repair" => 1,
          "provider-events" => 1,
          "promotion-restart" => 1,
          "interrupted-cleanup" => 2
        },
        case_id,
        0
      )

    expected > 0 and length(requested) == expected and
      requested == Enum.sort(Enum.uniq(requested)) and
      Enum.all?(requested, &audit_uuid?/1) and
      current == Enum.sort(Enum.uniq(current)) and
      MapSet.subset?(MapSet.new(current), MapSet.new(requested))
  end

  def audit_scope?(_, _, _), do: false

  defp audit_uuid?(id) when is_binary(id), do: Ecto.UUID.cast(id) == {:ok, id}
  defp audit_uuid?(_), do: false

  defp audit_pause_queues do
    for queue <- [
          :rindle_media,
          :rindle_promote,
          :rindle_process,
          :rindle_purge,
          :rindle_maintenance,
          :rindle_provider
        ] do
      :ok = Oban.pause_queue(queue: queue)

      wait(fn ->
        status = Oban.check_queue(queue: queue)
        status.paused and status.running == []
      end)
    end
  end

  defp audit_provider_cleanup(asset_ids) do
    calls = provider_count("provider-delete")
    true = calls in [0, 1]

    if calls == 0 do
      [row] = Repo.all(Rindle.Domain.MediaProviderAsset)
      true = row.asset_id in asset_ids and row.provider_name == "mux"
      true = row.provider_asset_id == provider_id()
      audit_stop_provider_observers(false)
      :ok = Rindle.Streaming.Provider.Mux.delete_asset(row.provider_asset_id)
      true = provider_count("provider-delete") == 1
    else
      audit_stop_provider_observers(true)
    end
  end

  defp audit_stop_provider_observers(allow_absent?) do
    case :persistent_term.get({Twin, :provider_handler}, nil) do
      nil ->
        true = allow_absent?

      handler ->
        :ok = :telemetry.detach(handler)
        :persistent_term.erase({Twin, :provider_handler})
    end

    case :persistent_term.get({Twin, :provider_observer}, nil) do
      nil ->
        true = allow_absent?

      observer ->
        true = Process.alive?(observer)
        monitor = Process.monitor(observer)
        send(observer, {:stop, self()})

        receive do
          :provider_observer_stopped -> :ok
        after
          5000 -> raise "audit_observer_timeout"
        end

        receive do
          {:DOWN, ^monitor, :process, ^observer, :normal} -> :ok
        after
          5000 -> raise "audit_observer_alive"
        end

        :persistent_term.erase({Twin, :provider_observer})
    end
  end

  defp audit_temp_entries(directory) do
    directory
    |> File.ls!()
    |> Enum.sort()
    |> Enum.flat_map(fn name ->
      path = Path.join(directory, name)

      case File.lstat!(path).type do
        :directory -> audit_temp_entries(path)
        _ -> [path]
      end
    end)
  end

  defp cleanup_private, do: :persistent_term.get({Twin, :cleanup})

  defp cleanup_sessions(private) do
    Enum.map([private.multipart, private.orphan], fn original ->
      session = Repo.get!(Rindle.Domain.MediaUploadSession, original.id)
      true = session.asset_id == original.asset_id and session.upload_key == original.upload_key
      true = session.expires_at == original.expires_at
      session
    end)
  end

  defp cleanup_put(url, png) do
    {:ok, {{_, status, _}, headers, _}} =
      :httpc.request(
        :put,
        {String.to_charlist(url), [], ~c"image/png", png},
        [timeout: 10_000],
        []
      )

    true = status in 200..299
    {_, etag} = Enum.find(headers, fn {name, _} -> String.downcase(to_string(name)) == "etag" end)
    to_string(etag)
  end

  defp cleanup_observe_multipart(private) do
    bucket = System.fetch_env!("TWIN_BUCKET")
    {:ok, [{key, upload}]} = cleanup_list_uploads()
    true = key == private.multipart.upload_key and upload == private.upload_id
    {:ok, %{status_code: 200, body: xml}} = cleanup_list_parts(private)
    {:ok, [part]} = cleanup_parts(xml, bucket, key, upload)
    true = part["etag_sha256"] == hash(private.etag)
    [part]
  end

  defp cleanup_list_parts(private) do
    ExAws.S3.list_parts(
      System.fetch_env!("TWIN_BUCKET"),
      private.multipart.upload_key,
      private.upload_id,
      [{"max-parts", 1000}, {"part-number-marker", 0}]
    )
    |> cleanup_s3()
  end

  defp cleanup_list_uploads do
    bucket = System.fetch_env!("TWIN_BUCKET")

    {:ok, %{status_code: 200, body: xml}} =
      cleanup_s3(ExAws.S3.list_multipart_uploads(bucket, max_uploads: 1000))

    cleanup_uploads(xml, bucket)
  end

  # Keep pagination and error XML intact: the SDK's convenient list parsers
  # omit IsTruncated, so an empty parsed collection cannot prove completion.
  defp cleanup_s3(operation), do: ExAws.request(%{operation | parser: &Function.identity/1})

  defp cleanup_barrier(private) do
    Repo.query!(
      "SELECT claims FROM twin_fault_counters WHERE run_id=$1 AND operation='cleanup-barrier' AND source_key=$2",
      [run_id(), private.orphan.upload_key]
    ).rows
  end

  def cleanup_parts(xml, bucket, key, upload) do
    doc = cleanup_xml(xml)
    [root] = SweetXml.xpath(doc, ~x"/ListPartsResult"l)
    ^bucket = SweetXml.xpath(root, ~x"./Bucket/text()"s)
    ^key = SweetXml.xpath(root, ~x"./Key/text()"s)
    ^upload = SweetXml.xpath(root, ~x"./UploadId/text()"s)
    "false" = SweetXml.xpath(root, ~x"./IsTruncated/text()"s)
    "0" = SweetXml.xpath(root, ~x"./PartNumberMarker/text()"s)
    "1000" = SweetXml.xpath(root, ~x"./MaxParts/text()"s)
    true = SweetXml.xpath(root, ~x"./NextPartNumberMarker/text()"s) in ["", "0", "1"]
    [part] = SweetXml.xpath(root, ~x"./Part"l)
    "1" = SweetXml.xpath(part, ~x"./PartNumber/text()"s)
    "69" = SweetXml.xpath(part, ~x"./Size/text()"s)
    etag = SweetXml.xpath(part, ~x"./ETag/text()"s)
    true = Regex.match?(~r/^"[0-9a-f]{32}"$/, etag)
    {:ok, [%{"number" => 1, "etag_sha256" => hash(etag), "bytes" => 69}]}
  rescue
    _ -> {:error, :incomplete_inventory}
  catch
    _, _ -> {:error, :incomplete_inventory}
  end

  def cleanup_uploads(xml, bucket) do
    doc = cleanup_xml(xml)
    [root] = SweetXml.xpath(doc, ~x"/ListMultipartUploadsResult"l)
    ^bucket = SweetXml.xpath(root, ~x"./Bucket/text()"s)
    "false" = SweetXml.xpath(root, ~x"./IsTruncated/text()"s)
    "" = SweetXml.xpath(root, ~x"./KeyMarker/text()"s)
    "" = SweetXml.xpath(root, ~x"./UploadIdMarker/text()"s)
    "1000" = SweetXml.xpath(root, ~x"./MaxUploads/text()"s)
    "" = SweetXml.xpath(root, ~x"./EncodingType/text()"s)
    [] = SweetXml.xpath(root, ~x"./CommonPrefixes"l)

    uploads =
      Enum.map(SweetXml.xpath(root, ~x"./Upload"l), fn entry ->
        key = SweetXml.xpath(entry, ~x"./Key/text()"s)
        upload = SweetXml.xpath(entry, ~x"./UploadId/text()"s)
        true = key != "" and upload != ""
        {key, upload}
      end)

    true = length(uploads) < 1000 and length(Enum.uniq(uploads)) == length(uploads)
    {last_key, last_upload} = List.last(uploads) || {"", ""}
    true = SweetXml.xpath(root, ~x"./NextKeyMarker/text()"s) in ["", last_key]
    true = SweetXml.xpath(root, ~x"./NextUploadIdMarker/text()"s) in ["", last_upload]
    {:ok, uploads}
  rescue
    _ -> {:error, :incomplete_inventory}
  catch
    _, _ -> {:error, :incomplete_inventory}
  end

  def cleanup_objects(xml, bucket) do
    doc = cleanup_xml(xml)
    [root] = SweetXml.xpath(doc, ~x"/ListBucketResult"l)
    ^bucket = SweetXml.xpath(root, ~x"./Name/text()"s)
    "false" = SweetXml.xpath(root, ~x"./IsTruncated/text()"s)
    "1000" = SweetXml.xpath(root, ~x"./MaxKeys/text()"s)
    "0" = SweetXml.xpath(root, ~x"./KeyCount/text()"s)
    "" = SweetXml.xpath(root, ~x"./ContinuationToken/text()"s)
    "" = SweetXml.xpath(root, ~x"./NextContinuationToken/text()"s)
    "" = SweetXml.xpath(root, ~x"./StartAfter/text()"s)
    [] = SweetXml.xpath(root, ~x"./CommonPrefixes"l)
    [] = SweetXml.xpath(root, ~x"./Contents"l)
    {:ok, []}
  rescue
    _ -> {:error, :incomplete_inventory}
  catch
    _, _ -> {:error, :incomplete_inventory}
  end

  def cleanup_missing_upload?({:error, {:http_error, 404, %{body: xml}}}) do
    doc = cleanup_xml(xml)
    [root] = SweetXml.xpath(doc, ~x"/Error"l)
    SweetXml.xpath(root, ~x"./Code/text()"s) == "NoSuchUpload"
  rescue
    _ -> false
  catch
    _, _ -> false
  end

  def cleanup_missing_upload?(_), do: false

  defp cleanup_xml(xml) when is_binary(xml) and byte_size(xml) in 1..1_048_576,
    do: SweetXml.parse(xml, dtd: :none, quiet: true)

  defp promotion_count(operation) do
    [[1]] =
      Repo.query!("SELECT claims FROM twin_fault_counters WHERE run_id=$1 AND operation=$2", [
        run_id(),
        operation
      ]).rows

    1
  end

  defp promotion_cut(session_id, asset_id, job_id) do
    session = Repo.get!(Rindle.Domain.MediaUploadSession, session_id)
    asset = Repo.get!(MediaAsset, asset_id)
    job = Repo.get!(Oban.Job, job_id)
    q = Oban.check_queue(queue: :rindle_promote)
    true = promotion_barrier?(q, job)
    %{state: "available", attempt: 0, args: %{"asset_id" => ^asset_id}} = job
    %{state: "validating"} = asset
    %{state: "completed", asset_id: ^asset_id} = session
    true = Repo.aggregate(Oban.Job, :count) == 1

    %{
      "session_id" => session.id,
      "asset_id" => asset.id,
      "source_key" => asset.storage_key,
      "job_id" => job.id,
      "attempt" => job.attempt,
      "state" => job.state,
      "asset_state" => asset.state,
      "session_state" => session.state,
      "paused" => q.paused,
      "running" => length(q.running),
      "upload_stimuli" => promotion_count("promotion-upload"),
      "completion_stimuli" => promotion_count("promotion-completion"),
      "boot_id" => health()["boot_id"]
    }
  end

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

  def promotion_barrier?(%{paused: true, running: []}, %{state: "available", attempt: 0}),
    do: true

  def promotion_barrier?(_, _), do: false

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
