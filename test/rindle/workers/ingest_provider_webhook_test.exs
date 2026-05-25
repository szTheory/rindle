defmodule Rindle.Workers.IngestProviderWebhookTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

  alias Phoenix.PubSub
  alias Rindle.Domain.{MediaAsset, MediaProviderAsset}
  alias Rindle.Workers.IngestProviderWebhook

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [hero: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000,
      delivery: [signed_url_ttl_seconds: 900]
  end

  @worker_events [
    [:rindle, :provider, :webhook, :processed],
    [:rindle, :provider, :webhook, :ignored],
    [:rindle, :provider, :webhook, :exception]
  ]

  setup do
    handler_id = "ingest-provider-webhook-test-#{System.unique_integer([:positive])}"
    test_pid = self()

    :telemetry.attach_many(
      handler_id,
      @worker_events,
      fn evt, measurements, metadata, _ ->
        send(test_pid, {:tele, evt, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    asset_id = Ecto.UUID.generate()
    storage_key = "media/#{asset_id}/source.mp4"

    {:ok, asset} =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        id: asset_id,
        state: "ready",
        storage_key: storage_key,
        profile: to_string(TestProfile),
        kind: "video",
        content_type: "video/mp4",
        byte_size: 100_000
      })
      |> Repo.insert()

    %{asset: asset, handler_id: handler_id}
  end

  defp insert_provider_row(asset, state, attrs \\ %{}) do
    base = %{
      asset_id: asset.id,
      profile: to_string(TestProfile),
      provider_name: "mux",
      provider_asset_id: "mux-asset-id-" <> Ecto.UUID.generate(),
      playback_policy: "signed",
      state: state
    }

    %MediaProviderAsset{}
    |> MediaProviderAsset.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end

  defp event_args(provider_asset_id, event_type, event_overrides \\ %{}) do
    occurred_at = "2026-05-06T00:00:00.000Z"

    event =
      Map.merge(
        %{
          "type" => stringified_type(event_type),
          "provider_asset_id" => provider_asset_id,
          "playback_ids" => [],
          "state" => state_for(event_type),
          "occurred_at" => occurred_at,
          "raw" => %{}
        },
        event_overrides
      )

    %{
      "event_id" => "evt-" <> Ecto.UUID.generate(),
      "provider" => "mux",
      "event_type" => event_type,
      "event" => event
    }
  end

  defp stringified_type("video.asset.ready"), do: "ready"
  defp stringified_type("video.asset.errored"), do: "errored"
  defp stringified_type("video.asset.deleted"), do: "deleted"
  defp stringified_type("video.asset.created"), do: "created"
  defp stringified_type("video.upload.asset_created"), do: "upload_asset_created"
  defp stringified_type(_), do: "unknown"

  defp state_for("video.asset.ready"), do: "ready"
  defp state_for("video.asset.errored"), do: "errored"
  defp state_for("video.asset.deleted"), do: "deleted"
  defp state_for("video.asset.created"), do: "processing"
  defp state_for(_), do: nil

  defp drain_telemetry(filter_event, acc) do
    receive do
      {:tele, evt, _, _} = msg ->
        if filter_event == nil or evt == filter_event do
          drain_telemetry(filter_event, [msg | acc])
        else
          drain_telemetry(filter_event, acc)
        end
    after
      50 -> Enum.reverse(acc)
    end
  end

  defp last_telemetry(filter_event) do
    drain_telemetry(filter_event, []) |> List.last()
  end

  # ============================================================
  # 1. Idempotency under Oban unique
  # ============================================================

  test "Oban unique on event_id deduplicates re-delivery at the JOB level", ctx do
    row = insert_provider_row(ctx.asset, "processing")
    args = event_args(row.provider_asset_id, "video.asset.ready")

    job1 =
      IngestProviderWebhook.new(args, unique: IngestProviderWebhook.unique_job_opts())

    assert {:ok, _inserted} = Oban.insert(job1)

    job2 =
      IngestProviderWebhook.new(args, unique: IngestProviderWebhook.unique_job_opts())

    assert {:ok, returned} = Oban.insert(job2)
    assert returned.conflict?
  end

  # ============================================================
  # 2. video.asset.ready dispatch — happy path + telemetry + PubSub
  # ============================================================

  test "video.asset.ready: flips :processing -> :ready, persists playback_ids, broadcasts on two topics with redacted telemetry",
       ctx do
    row = insert_provider_row(ctx.asset, "processing", %{last_sync_error: "previous boom"})

    PubSub.subscribe(Rindle.PubSub, "rindle:provider_asset:#{ctx.asset.id}")
    PubSub.subscribe(Rindle.PubSub, "rindle:asset:#{ctx.asset.id}")

    args =
      event_args(row.provider_asset_id, "video.asset.ready", %{
        "playback_ids" => ["pb-id-1", "pb-id-2"],
        "raw" => %{"data" => %{"id" => row.provider_asset_id}}
      })

    assert :ok = perform_job(IngestProviderWebhook, args)

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "ready"
    assert updated.playback_ids == ["pb-id-1", "pb-id-2"]
    assert updated.last_sync_error == nil

    # Two-topic broadcast with locked payload contract.
    assert_receive {:rindle_event, :provider_asset_ready, payload1}
    assert_receive {:rindle_event, :provider_asset_ready, payload2}

    for payload <- [payload1, payload2] do
      assert payload.asset_id == ctx.asset.id
      assert payload.playback_ids == ["pb-id-1", "pb-id-2"]
      assert payload.profile == to_string(TestProfile)
      assert payload.provider == :mux
      assert payload.state == "ready"
      # Security invariant 14: payload MUST NOT carry provider_asset_id.
      refute Map.has_key?(payload, :provider_asset_id)
    end

    # Telemetry :processed with redacted asset_id (last-4 prefix).
    assert {:tele, [:rindle, :provider, :webhook, :processed], _, metadata} =
             last_telemetry([:rindle, :provider, :webhook, :processed])

    assert metadata.provider == :mux
    assert metadata.event_type == "video.asset.ready"
    assert metadata.from_state == "processing"
    assert metadata.to_state == "ready"
    assert is_binary(metadata.asset_id)
    assert String.starts_with?(metadata.asset_id, "...")
    refute metadata.asset_id == row.provider_asset_id
  end

  # ============================================================
  # 3. video.asset.errored dispatch
  # ============================================================

  test "video.asset.errored: populates last_sync_error from raw.data.errors and broadcasts :provider_asset_errored",
       ctx do
    row = insert_provider_row(ctx.asset, "processing")
    PubSub.subscribe(Rindle.PubSub, "rindle:asset:#{ctx.asset.id}")

    args =
      event_args(row.provider_asset_id, "video.asset.errored", %{
        "raw" => %{
          "data" => %{
            "id" => row.provider_asset_id,
            "errors" => %{
              "type" => "input_error",
              "messages" => ["Failed to fetch input from signed URL"]
            }
          }
        }
      })

    assert :ok = perform_job(IngestProviderWebhook, args)

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "errored"
    assert updated.last_sync_error == "input_error: Failed to fetch input from signed URL"

    assert_receive {:rindle_event, :provider_asset_errored, payload}
    assert payload.state == "errored"
    refute Map.has_key?(payload, :provider_asset_id)
  end

  # ============================================================
  # 4. video.asset.deleted dispatch
  # ============================================================

  test "video.asset.deleted: flips :ready -> :deleted and broadcasts :provider_asset_deleted",
       ctx do
    row = insert_provider_row(ctx.asset, "ready", %{playback_ids: ["pb-1"]})
    PubSub.subscribe(Rindle.PubSub, "rindle:asset:#{ctx.asset.id}")

    args = event_args(row.provider_asset_id, "video.asset.deleted")
    assert :ok = perform_job(IngestProviderWebhook, args)

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "deleted"

    assert_receive {:rindle_event, :provider_asset_deleted, payload}
    assert payload.state == "deleted"
    refute Map.has_key?(payload, :provider_asset_id)
  end

  # ============================================================
  # 5. video.asset.created dispatch — FSM transition, NO broadcast
  # ============================================================

  test "video.asset.created: flips :uploading -> :processing, NO broadcast",
       ctx do
    row = insert_provider_row(ctx.asset, "uploading")
    PubSub.subscribe(Rindle.PubSub, "rindle:provider_asset:#{ctx.asset.id}")
    PubSub.subscribe(Rindle.PubSub, "rindle:asset:#{ctx.asset.id}")

    args = event_args(row.provider_asset_id, "video.asset.created")
    assert :ok = perform_job(IngestProviderWebhook, args)

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "processing"

    refute_receive {:rindle_event, _, _}, 100

    assert {:tele, [:rindle, :provider, :webhook, :processed], _, metadata} =
             last_telemetry([:rindle, :provider, :webhook, :processed])

    assert metadata.kind == nil
    assert metadata.from_state == "uploading"
    assert metadata.to_state == "processing"
  end

  # ============================================================
  # 6. video.upload.asset_created dispatch — row exists
  # ============================================================

  test "video.upload.asset_created links by mux_passthrough, stamps provider_asset_id, moves to processing, and broadcasts :provider_asset_created",
       ctx do
    row =
      insert_provider_row(ctx.asset, "uploading", %{
        provider_asset_id: nil,
        mux_passthrough: "mux-pass-#{System.unique_integer([:positive])}"
      })

    PubSub.subscribe(Rindle.PubSub, "rindle:provider_asset:#{ctx.asset.id}")
    PubSub.subscribe(Rindle.PubSub, "rindle:asset:#{ctx.asset.id}")

    args =
      event_args("mux-provider-asset-123", "video.upload.asset_created", %{
        "raw" => %{
          "data" => %{
            "id" => "mux-upload-123",
            "asset_id" => "mux-provider-asset-123",
            "passthrough" => row.mux_passthrough
          }
        }
      })

    assert :ok = perform_job(IngestProviderWebhook, args)

    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "processing"
    assert updated.provider_asset_id == "mux-provider-asset-123"
    assert updated.last_event_at

    assert_receive {:rindle_event, :provider_asset_created, payload1}
    assert_receive {:rindle_event, :provider_asset_created, payload2}

    for payload <- [payload1, payload2] do
      assert payload.asset_id == ctx.asset.id
      assert payload.state == "processing"
      refute Map.has_key?(payload, :provider_asset_id)
    end

    assert {:tele, [:rindle, :provider, :webhook, :processed], _, metadata} =
             last_telemetry([:rindle, :provider, :webhook, :processed])

    assert metadata.kind == nil
    assert metadata.from_state == "uploading"
    assert metadata.to_state == "processing"
  end

  # ============================================================
  # 7. video.upload.asset_created — no matching row (Phase 37 forward-compat)
  # ============================================================

  test "video.upload.asset_created with no matching row: uses the normal race-snooze path",
       _ctx do
    args =
      event_args("missing-provider-asset-id-no-row", "video.upload.asset_created", %{
        "raw" => %{
          "data" => %{
            "id" => "mux-upload-404",
            "asset_id" => "missing-provider-asset-id-no-row",
            "passthrough" => "missing-passthrough"
          }
        }
      })

    job = %Oban.Job{
      args: args,
      attempt: 1,
      worker: "Rindle.Workers.IngestProviderWebhook",
      queue: "rindle_provider"
    }

    assert {:snooze, 5} = IngestProviderWebhook.perform(job)

    assert {:tele, [:rindle, :provider, :webhook, :ignored], _, metadata} =
             last_telemetry([:rindle, :provider, :webhook, :ignored])

    assert metadata.kind == :race_snooze
  end

  # ============================================================
  # 8. Unknown event type
  # ============================================================

  test "unknown event_type with matching row: bumps last_event_at, telemetry :ignored kind: :unknown_event",
       ctx do
    row = insert_provider_row(ctx.asset, "ready")
    args = event_args(row.provider_asset_id, "video.foo.bar")

    assert :ok = perform_job(IngestProviderWebhook, args)

    updated = Repo.get!(MediaProviderAsset, row.id)
    # State unchanged.
    assert updated.state == "ready"
    assert updated.last_event_at

    assert {:tele, [:rindle, :provider, :webhook, :ignored], _, metadata} =
             last_telemetry([:rindle, :provider, :webhook, :ignored])

    assert metadata.kind == :unknown_event
  end

  # ============================================================
  # 9. Race-snooze attempt 1 (5s)
  # ============================================================

  test "race-snooze attempt 1 (row missing): returns {:snooze, 5} + telemetry :ignored kind: :race_snooze attempt 1",
       _ctx do
    args = event_args("missing-asset-id-race-snooze", "video.asset.ready")

    job = %Oban.Job{
      args: args,
      attempt: 1,
      worker: "Rindle.Workers.IngestProviderWebhook",
      queue: "rindle_provider"
    }

    assert {:snooze, 5} = IngestProviderWebhook.perform(job)

    assert {:tele, [:rindle, :provider, :webhook, :ignored], _, metadata} =
             last_telemetry([:rindle, :provider, :webhook, :ignored])

    assert metadata.kind == :race_snooze
    assert metadata.attempt == 1
    assert metadata.delay_seconds == 5
  end

  # ============================================================
  # 10. Race-snooze attempt 5 — exhausted
  # ============================================================

  test "race-snooze attempt 5 (row missing): returns {:cancel, :provider_asset_row_missing} + telemetry :exception kind: :race_snooze_exhausted",
       _ctx do
    args = event_args("missing-asset-id-exhausted", "video.asset.ready")

    job = %Oban.Job{
      args: args,
      attempt: 5,
      worker: "Rindle.Workers.IngestProviderWebhook",
      queue: "rindle_provider"
    }

    assert {:cancel, :provider_asset_row_missing} = IngestProviderWebhook.perform(job)

    assert {:tele, [:rindle, :provider, :webhook, :exception], _, metadata} =
             last_telemetry([:rindle, :provider, :webhook, :exception])

    assert metadata.kind == :race_snooze_exhausted
  end

  # ============================================================
  # 11. FSM rejection — :deleted -> :ready violation
  # ============================================================

  test "FSM rejection: :deleted row + video.asset.ready event returns {:cancel, {:invalid_transition, _, _}}",
       ctx do
    # FSM allowlist: deleted -> [] (terminal). ready event tries deleted -> ready,
    # which is rejected.
    row = insert_provider_row(ctx.asset, "deleted")

    args =
      event_args(row.provider_asset_id, "video.asset.ready", %{
        "playback_ids" => ["pb"]
      })

    assert {:cancel, {:error, {:invalid_transition, "deleted", "ready"}}} =
             perform_job(IngestProviderWebhook, args)

    # State unchanged.
    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "deleted"

    assert {:tele, [:rindle, :provider, :webhook, :exception], _, metadata} =
             last_telemetry([:rindle, :provider, :webhook, :exception])

    assert metadata.kind == :invalid_transition
    assert metadata.from_state == "deleted"
    assert metadata.to_state == "ready"
  end

  # ============================================================
  # 12. Repo error simulation — invalid state passes FSM but fails changeset
  # ============================================================
  # We can't easily force changeset failure on the locked-state column without
  # injecting a fake repo. Instead we exercise the changeset-validation path
  # by feeding `last_sync_error` longer than 4096 chars on the errored branch
  # — this fails MediaProviderAsset.changeset/2's validate_length and the
  # worker MUST surface {:error, _}.

  test "Repo error: oversize last_sync_error fails changeset validation -> {:error, _}",
       ctx do
    row = insert_provider_row(ctx.asset, "processing")

    huge_message = String.duplicate("x", 5000)

    args =
      event_args(row.provider_asset_id, "video.asset.errored", %{
        "raw" => %{
          "data" => %{
            "id" => row.provider_asset_id,
            "errors" => %{
              "type" => "input_error",
              "messages" => [huge_message]
            }
          }
        }
      })

    assert {:error, %Ecto.Changeset{}} = perform_job(IngestProviderWebhook, args)

    # Row should remain untouched (changeset rejected).
    updated = Repo.get!(MediaProviderAsset, row.id)
    assert updated.state == "processing"
  end

  # ============================================================
  # 13. PubSub payload omits provider_asset_id (explicit)
  # ============================================================

  test "PubSub payload contract: payload MUST NOT contain :provider_asset_id key",
       ctx do
    row = insert_provider_row(ctx.asset, "processing")
    PubSub.subscribe(Rindle.PubSub, "rindle:asset:#{ctx.asset.id}")

    args =
      event_args(row.provider_asset_id, "video.asset.ready", %{
        "playback_ids" => ["pb"]
      })

    assert :ok = perform_job(IngestProviderWebhook, args)

    assert_receive {:rindle_event, :provider_asset_ready, payload}
    refute Map.has_key?(payload, :provider_asset_id)
    # Spot-check the locked allowed keys.
    assert Map.keys(payload) |> Enum.sort() ==
             [:asset_id, :playback_ids, :profile, :provider, :state]
  end

  # ============================================================
  # 14. Telemetry asset_id is redacted (security invariant 14)
  # ============================================================

  test "telemetry metadata: asset_id is routed through MediaProviderAsset.redact_id/1",
       ctx do
    raw_id = "sensitive-provider-asset-id-1234567890ABCD"
    row = insert_provider_row(ctx.asset, "processing", %{provider_asset_id: raw_id})

    args =
      event_args(row.provider_asset_id, "video.asset.ready", %{
        "playback_ids" => ["pb"]
      })

    assert :ok = perform_job(IngestProviderWebhook, args)

    assert {:tele, [:rindle, :provider, :webhook, :processed], _, metadata} =
             last_telemetry([:rindle, :provider, :webhook, :processed])

    # Redaction prefix is "..." per MediaProviderAsset.redact_id/1.
    assert is_binary(metadata.asset_id)
    assert String.starts_with?(metadata.asset_id, "...")
    refute metadata.asset_id =~ raw_id
    assert metadata.asset_id == "...ABCD"
  end
end
