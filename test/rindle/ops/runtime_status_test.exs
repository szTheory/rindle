defmodule Rindle.Ops.RuntimeStatusTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

  alias Rindle.Domain.{MediaAsset, MediaProviderAsset, MediaUploadSession, MediaVariant}
  alias Rindle.Ops.RuntimeStatus
  alias Rindle.Workers.ProcessVariant

  defmodule StatusImageProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [thumb: [mode: :fit, width: 64, height: 64]],
      allow_mime: ["image/png"],
      max_bytes: 10_485_760
  end

  defmodule StatusVideoProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [web_720p: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000
  end

  test "classifies failed, cancelled, stale, missing, and queue-starved variants" do
    failed_asset = insert_asset(%{profile: to_string(StatusImageProfile)})
    cancelled_asset = insert_asset(%{profile: to_string(StatusImageProfile)})
    stale_asset = insert_asset(%{profile: to_string(StatusImageProfile)})
    missing_asset = insert_asset(%{profile: to_string(StatusImageProfile)})
    starved_asset = insert_asset(%{profile: to_string(StatusImageProfile)})

    _failed = insert_variant(failed_asset, %{state: "failed", updated_at: age_ago(600)})
    _cancelled = insert_variant(cancelled_asset, %{state: "cancelled", updated_at: age_ago(600)})
    _stale = insert_variant(stale_asset, %{state: "stale", updated_at: age_ago(600)})

    _missing =
      insert_variant(missing_asset, %{
        state: "missing",
        updated_at: age_ago(600),
        storage_key: "variants/missing.png"
      })

    _starved = insert_variant(starved_asset, %{state: "queued", updated_at: age_ago(601)})

    assert {:ok, report} = RuntimeStatus.runtime_status(limit: 2)

    classes = Enum.map(report.variants.findings, & &1.class)

    assert :failed_work in classes
    assert :cancelled_work in classes
    assert :recipe_drift in classes
    assert :storage_drift in classes
    assert :queue_starved in classes
  end

  test "does not classify queued work as starved when an active oban job exists" do
    asset = insert_asset(%{profile: to_string(StatusImageProfile)})
    _variant = insert_variant(asset, %{name: "thumb", state: "queued", updated_at: age_ago(601)})

    assert {:ok, _job} =
             ProcessVariant.new(%{"asset_id" => asset.id, "variant_name" => "thumb"})
             |> Oban.insert()

    assert {:ok, report} = RuntimeStatus.runtime_status(limit: 2)

    refute Enum.any?(report.variants.findings, &(&1.class == :queue_starved))
  end

  test "classifies orphan suspects for old processing variants without executing job corroboration" do
    asset =
      insert_asset(%{
        profile: to_string(StatusVideoProfile),
        kind: "video",
        content_type: "video/mp4",
        duration_ms: 10_000,
        has_video_track: true
      })

    _variant =
      insert_variant(asset, %{name: "web_720p", state: "processing", updated_at: age_ago(1_201)})

    assert {:ok, report} = RuntimeStatus.runtime_status(limit: 2)

    assert Enum.any?(report.variants.findings, &(&1.class == :orphan_suspect))
  end

  test "surfaces bounded probe drift findings for persisted asset inconsistencies" do
    _asset =
      insert_asset(%{
        profile: to_string(StatusVideoProfile),
        state: "ready",
        kind: "video",
        content_type: "video/mp4",
        duration_ms: nil,
        width: nil,
        height: 720,
        has_video_track: nil,
        updated_at: age_ago(720)
      })

    assert {:ok, report} = RuntimeStatus.runtime_status(limit: 1)

    assert report.runtime_checks.counts.probe_drift == 1

    [finding] = report.runtime_checks.findings
    assert finding.class == :probe_drift
    assert length(finding.samples) == 1
    assert hd(finding.samples).reason =~ "missing probe-owned AV fields"
  end

  test "reports expired and failed upload sessions with cleanup recommendation" do
    asset = insert_asset(%{profile: to_string(StatusImageProfile)})

    _expired =
      insert_upload_session(asset, %{
        state: "expired",
        expires_at: DateTime.add(DateTime.utc_now(), -900, :second)
      })

    _failed = insert_upload_session(asset, %{state: "failed", failure_reason: "mime_mismatch"})

    assert {:ok, report} = RuntimeStatus.runtime_status(limit: 2)

    states = Enum.map(report.upload_sessions.findings, & &1.state)
    assert "expired" in states
    assert "failed" in states

    assert Enum.any?(report.recommendations, &(&1.action == :cleanup))
  end

  test "reports bounded resumable counters under upload_sessions without exposing URIs" do
    asset = insert_asset(%{profile: to_string(StatusImageProfile)})

    _pending =
      insert_upload_session(asset, %{
        state: "signed",
        upload_strategy: "resumable",
        session_uri: "https://secret.example/live-session",
        session_uri_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    _expired_resolved =
      insert_upload_session(asset, %{
        state: "expired",
        upload_strategy: "resumable",
        session_uri: nil,
        session_uri_expires_at: DateTime.add(DateTime.utc_now(), -60, :second)
      })

    _expired_stale =
      insert_upload_session(asset, %{
        state: "expired",
        upload_strategy: "resumable",
        session_uri: "https://secret.example/stale-session",
        session_uri_expires_at: DateTime.add(DateTime.utc_now(), -120, :second)
      })

    assert {:ok, report} = RuntimeStatus.runtime_status(limit: 2)

    assert report.upload_sessions.resumable == %{
             resumable_sessions_pending: 1,
             resumable_sessions_expired: 2,
             resumable_session_uris_stale: 1
           }

    encoded = Jason.encode!(report)
    refute encoded =~ "\"session_uri\":"
    refute encoded =~ "secret.example"
  end

  test "rejects unknown filter keys instead of widening into a query dsl" do
    assert {:error, {:unknown_filters, [:unknown]}} =
             RuntimeStatus.runtime_status(%{unknown: :value})
  end

  test "filters by profile and older_than without changing the public report shape" do
    old_asset = insert_asset(%{profile: to_string(StatusImageProfile)})

    _old_variant =
      insert_variant(old_asset, %{name: "thumb", state: "failed", updated_at: age_ago(800)})

    fresh_asset = insert_asset(%{profile: to_string(StatusVideoProfile)})

    _fresh_variant =
      insert_variant(fresh_asset, %{name: "web_720p", state: "failed", updated_at: age_ago(10)})

    assert {:ok, report} =
             RuntimeStatus.runtime_status(
               profile: to_string(StatusImageProfile),
               older_than: 300,
               limit: 3,
               format: :json
             )

    assert report.filters.profile == to_string(StatusImageProfile)
    assert report.filters.older_than == 300
    assert report.filters.format == :json
    assert report.variants.counts.failed == 1
    assert Map.has_key?(report.upload_sessions, :resumable)

    assert Enum.all?(report.variants.findings, fn finding ->
             Enum.all?(finding.samples, &(&1.asset_id == old_asset.id))
           end)
  end

  describe "provider_assets report (MUX-14)" do
    setup do
      previous = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])
      on_exit(fn -> Application.put_env(:rindle, Rindle.Streaming.Provider.Mux, previous) end)
      :ok
    end

    test "runtime_status/1 always returns a provider_assets field" do
      assert {:ok, report} = RuntimeStatus.runtime_status([])
      assert is_map(report.provider_assets)
      assert Map.has_key?(report.provider_assets, :counts)
      assert Map.has_key?(report.provider_assets, :findings)
      assert Map.has_key?(report.provider_assets, :threshold_seconds)
      assert report.provider_assets.findings == []
    end

    test "provider_stuck filter true with no rows past threshold yields empty findings" do
      asset = insert_asset(%{profile: to_string(StatusVideoProfile)})
      _row = insert_provider_asset(asset, %{state: "processing", updated_at: age_ago(60)})

      assert {:ok, report} = RuntimeStatus.runtime_status(provider_stuck: true)
      assert report.provider_assets.findings == []
      assert is_map(report.provider_assets.counts)
      assert is_integer(report.provider_assets.counts.total)
    end

    test "provider_stuck filter true surfaces a row past the 7200s default threshold" do
      asset = insert_asset(%{profile: to_string(StatusVideoProfile)})

      _row =
        insert_provider_asset(asset, %{
          state: "processing",
          provider_asset_id: "test-asset-id-aaaa1111bbbb2222cccc3333dddd",
          updated_at: age_ago(7300)
        })

      assert {:ok, report} = RuntimeStatus.runtime_status(provider_stuck: true)
      assert [finding] = report.provider_assets.findings
      assert finding.class == :provider_stuck
      assert finding.count == 1

      [sample] = finding.samples
      assert sample.asset_id == asset.id
      assert is_binary(sample.asset_id)
      assert sample.provider_asset_id == "...dddd"
    end

    test "sample shape contract: 9 keys present + redacted provider_asset_id + full asset_id" do
      asset = insert_asset(%{profile: to_string(StatusVideoProfile)})

      _row =
        insert_provider_asset(asset, %{
          state: "uploading",
          provider_asset_id: "id-with-suffix-zzzz",
          last_sync_error: "transient",
          updated_at: age_ago(8000)
        })

      assert {:ok, report} = RuntimeStatus.runtime_status(provider_stuck: true)
      assert [%{samples: [sample]}] = report.provider_assets.findings

      expected_keys = [
        :asset_id,
        :provider_asset_id,
        :profile,
        :provider,
        :state,
        :updated_at,
        :last_event_at,
        :last_sync_error,
        :reason
      ]

      Enum.each(expected_keys, fn key ->
        assert Map.has_key?(sample, key), "sample missing key #{inspect(key)}"
      end)

      assert sample.provider_asset_id == "...zzzz"
      assert String.starts_with?(sample.provider_asset_id, "...")
      assert sample.asset_id == asset.id
    end

    test "older_than override wins over the app-config default" do
      Application.put_env(:rindle, Rindle.Streaming.Provider.Mux,
        provider_stuck_threshold_seconds: 7200
      )

      asset = insert_asset(%{profile: to_string(StatusVideoProfile)})

      _row =
        insert_provider_asset(asset, %{
          state: "processing",
          updated_at: age_ago(120)
        })

      assert {:ok, report} =
               RuntimeStatus.runtime_status(provider_stuck: true, older_than: 60)

      assert report.provider_assets.threshold_seconds == 60
      assert [finding] = report.provider_assets.findings
      assert finding.class == :provider_stuck
    end

    test "threshold default reads from app config" do
      Application.put_env(:rindle, Rindle.Streaming.Provider.Mux,
        provider_stuck_threshold_seconds: 30
      )

      asset = insert_asset(%{profile: to_string(StatusVideoProfile)})

      _row =
        insert_provider_asset(asset, %{
          state: "processing",
          updated_at: age_ago(60)
        })

      assert {:ok, report} = RuntimeStatus.runtime_status(provider_stuck: true)
      assert report.provider_assets.threshold_seconds == 30
      assert [finding] = report.provider_assets.findings
      assert finding.class == :provider_stuck
    end

    test "recommendation surfaces resync action when provider_stuck findings exist" do
      asset = insert_asset(%{profile: to_string(StatusVideoProfile)})

      _row =
        insert_provider_asset(asset, %{
          state: "processing",
          updated_at: age_ago(8000)
        })

      assert {:ok, report} = RuntimeStatus.runtime_status(provider_stuck: true)

      rec = Enum.find(report.recommendations, &(&1.class == :provider_stuck))

      assert rec,
             "expected :provider_stuck recommendation, got: #{inspect(report.recommendations)}"

      assert rec.action == :resync
      assert rec.surface == "Rindle.Workers.MuxSyncProviderAsset"
    end

    test "profile filter narrows the query" do
      asset_a = insert_asset(%{profile: to_string(StatusImageProfile)})
      _row_a = insert_provider_asset(asset_a, %{state: "processing", updated_at: age_ago(8000)})

      assert {:ok, report} =
               RuntimeStatus.runtime_status(
                 provider_stuck: true,
                 profile: to_string(StatusVideoProfile)
               )

      assert report.provider_assets.findings == []
    end

    test "counts populated with at least :total" do
      asset = insert_asset(%{profile: to_string(StatusVideoProfile)})
      _row = insert_provider_asset(asset, %{state: "uploading", updated_at: age_ago(60)})

      assert {:ok, report} = RuntimeStatus.runtime_status([])

      counts = report.provider_assets.counts
      assert is_integer(counts.total)
      assert counts.total >= 1
      # uploading row is in the counts
      assert Map.get(counts, :uploading, 0) >= 1
    end
  end

  defp insert_provider_asset(asset, attrs) do
    params =
      %{
        asset_id: asset.id,
        profile: asset.profile,
        provider_name: "mux",
        provider_asset_id:
          Map.get(
            attrs,
            :provider_asset_id,
            "mux-asset-#{System.unique_integer([:positive])}-tail"
          ),
        state: Map.get(attrs, :state, "processing")
      }
      |> Map.merge(Map.drop(attrs, [:updated_at, :provider_asset_id, :state]))

    row =
      %MediaProviderAsset{}
      |> MediaProviderAsset.changeset(params)
      |> Rindle.Repo.insert!()

    case attrs[:updated_at] do
      nil ->
        :ok

      ts ->
        from(r in MediaProviderAsset, where: r.id == ^row.id)
        |> Rindle.Repo.update_all(set: [updated_at: ts])
    end

    Rindle.Repo.get!(MediaProviderAsset, row.id)
  end

  defp insert_asset(attrs) do
    params =
      %{
        state: "available",
        profile: to_string(StatusImageProfile),
        storage_key: "assets/#{System.unique_integer([:positive])}.bin",
        kind: "image",
        content_type: "image/png",
        updated_at: age_ago(60)
      }
      |> Map.merge(Map.drop(attrs, [:updated_at]))

    asset =
      %MediaAsset{}
      |> MediaAsset.changeset(params)
      |> Rindle.Repo.insert!()

    maybe_backdate(MediaAsset, asset.id, attrs[:updated_at])
    Rindle.Repo.get!(MediaAsset, asset.id)
  end

  defp insert_variant(asset, attrs) do
    variant_name = Map.get(attrs, :name, "thumb")
    profile_module = String.to_existing_atom(asset.profile)
    variant_atom = String.to_existing_atom(variant_name)

    params =
      %{
        asset_id: asset.id,
        name: variant_name,
        state: "ready",
        recipe_digest: profile_module.recipe_digest(variant_atom),
        output_kind: "image",
        updated_at: age_ago(60)
      }
      |> Map.merge(Map.drop(attrs, [:updated_at]))

    variant =
      %MediaVariant{}
      |> MediaVariant.changeset(params)
      |> Rindle.Repo.insert!()

    maybe_backdate(MediaVariant, variant.id, attrs[:updated_at])
    Rindle.Repo.get!(MediaVariant, variant.id)
  end

  defp insert_upload_session(asset, attrs) do
    params =
      %{
        asset_id: asset.id,
        state: "completed",
        upload_key: "uploads/#{System.unique_integer([:positive])}.bin",
        upload_strategy: "presigned_put",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        updated_at: age_ago(60)
      }
      |> Map.merge(Map.drop(attrs, [:updated_at]))

    session =
      %MediaUploadSession{}
      |> MediaUploadSession.changeset(params)
      |> Rindle.Repo.insert!()

    maybe_backdate(MediaUploadSession, session.id, attrs[:updated_at])
    Rindle.Repo.get!(MediaUploadSession, session.id)
  end

  defp age_ago(seconds) do
    DateTime.utc_now()
    |> DateTime.add(-seconds, :second)
    |> DateTime.to_naive()
  end

  defp maybe_backdate(_schema, _id, nil), do: :ok

  defp maybe_backdate(schema, id, %NaiveDateTime{} = updated_at) do
    from(record in schema, where: record.id == ^id)
    |> Rindle.Repo.update_all(set: [updated_at: updated_at])

    :ok
  end
end
