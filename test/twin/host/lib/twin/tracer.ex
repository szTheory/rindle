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
