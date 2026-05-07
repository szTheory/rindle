defmodule Rindle.Workers.MuxIngestVariantTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo
  import Mox
  import Ecto.Query, only: [from: 2]

  alias Rindle.Domain.{MediaAsset, MediaVariant, MediaProviderAsset}
  alias Rindle.Workers.MuxIngestVariant
  alias Rindle.Streaming.Provider.Mux.ClientMock

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestProfile do
    # Plan-level test profile. Phase 33 DSL nests delivery options under
    # `:delivery`; the top-level `streaming:` key is invalid (Plan 01 deviation).
    # Variant DSL uses the AV shape `[kind: :video, preset: :web_720p]` which
    # the validator routes through `@video_variant_schema` (Phase 24 / AV-02).
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [hero: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000,
      delivery: [signed_url_ttl_seconds: 900]
  end

  setup do
    prev = Application.get_env(:rindle, Rindle.Streaming.Provider.Mux, [])

    Application.put_env(
      :rindle,
      Rindle.Streaming.Provider.Mux,
      Keyword.merge(prev,
        http_client: ClientMock,
        token_id: "test_token_id",
        token_secret: "test_token_secret",
        signing_key_id: "test_kid",
        signing_private_key: File.read!("test/fixtures/mux/test_signing_private_key.pem")
      )
    )

    on_exit(fn -> Application.put_env(:rindle, Rindle.Streaming.Provider.Mux, prev) end)

    # StorageMock stubs for `Rindle.Delivery.url/3`. The Delivery dispatch
    # checks `adapter.capabilities()` and then calls `adapter.url/2` — both
    # need to pass through the mock.
    stub(Rindle.StorageMock, :capabilities, fn -> [:signed_url] end)

    stub(Rindle.StorageMock, :url, fn _key, opts ->
      {:ok, "https://signed.example/v.mp4?expires=#{Keyword.get(opts, :expires_in, 0)}"}
    end)

    asset_id = Ecto.UUID.generate()
    storage_key = "media/#{asset_id}/source.mp4"
    recipe_digest = "sha256:" <> String.duplicate("a", 64)

    # B3 fix: use REAL MediaAsset schema field names.
    #   - `content_type` (NOT `mime`)
    #   - validate_required([:state, :storage_key, :profile, :kind])
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

    # B3 fix: use REAL MediaVariant schema field names.
    #   - `output_kind` (NOT `kind`)
    #   - validate_required([:asset_id, :name, :state, :recipe_digest, :output_kind])
    {:ok, variant} =
      %MediaVariant{}
      |> MediaVariant.changeset(%{
        asset_id: asset.id,
        name: "hero",
        state: "ready",
        recipe_digest: recipe_digest,
        storage_key: storage_key,
        output_kind: "video"
      })
      |> Repo.insert()

    args = %{
      "asset_id" => asset.id,
      "profile" => to_string(TestProfile),
      "variant_name" => "hero",
      "expected_storage_key" => storage_key,
      "expected_recipe_digest" => recipe_digest
    }

    %{asset: asset, variant: variant, args: args}
  end

  defp fixture(name), do: File.read!("test/fixtures/mux/#{name}") |> Jason.decode!()

  # ===========================================================
  # MUX-03 — happy path
  # ===========================================================

  test "ingests variant, persists provider_asset_id + playback_ids (PLURAL), advances FSM to :processing",
       ctx do
    expect(ClientMock, :create_asset, fn params ->
      # D-04 memo correction: PLURAL keys at SDK boundary.
      assert [%{"url" => url}] = params["inputs"]
      assert is_binary(url) and url =~ "https://signed.example/v.mp4"
      assert params["playback_policies"] == ["signed"]
      assert params["mp4_support"] == "standard"
      {:ok, fixture("asset_create_201.json")}
    end)

    assert :ok = perform_job(MuxIngestVariant, ctx.args)

    row =
      Repo.get_by!(MediaProviderAsset,
        asset_id: ctx.asset.id,
        profile: to_string(TestProfile),
        provider_name: "mux"
      )

    assert row.state == "processing"
    assert is_binary(row.provider_asset_id)
    # B1 fix: row.playback_ids is a PLURAL ARRAY (Phase 33 schema field).
    assert is_list(row.playback_ids)
    assert [first | _] = row.playback_ids
    assert is_binary(first)
  end

  # ===========================================================
  # MUX-05 — idempotency
  # ===========================================================

  test "Oban.unique semantics: enqueue with unique opts deduplicates at the JOB level", ctx do
    # B6 fix: opts are wrapped as `unique:` keyword option (matches process_variant.ex:51).
    job = MuxIngestVariant.new(ctx.args, unique: MuxIngestVariant.unique_job_opts())
    assert {:ok, _inserted} = Oban.insert(job)

    # Re-enqueue same args within period — should return existing job, not new.
    job2 = MuxIngestVariant.new(ctx.args, unique: MuxIngestVariant.unique_job_opts())
    assert {:ok, returned} = Oban.insert(job2)
    assert returned.conflict?
  end

  test "re-running perform on a row already in :processing yields :ok no-op (does not retry forbidden FSM edge)",
       ctx do
    # ClientMock.expect with arity 1: must be called EXACTLY once across both
    # perform_job/2 calls. `verify_on_exit!` enforces this.
    expect(ClientMock, :create_asset, 1, fn _params ->
      {:ok, fixture("asset_create_201.json")}
    end)

    # First run: rows reach :processing.
    assert :ok = perform_job(MuxIngestVariant, ctx.args)

    rows_after_first =
      Repo.all(from r in MediaProviderAsset, where: r.asset_id == ^ctx.asset.id)

    assert length(rows_after_first) == 1
    assert hd(rows_after_first).state == "processing"

    # Second run on the same args. ClientMock was set with `1, fn -> ...` so a
    # second create_asset call would raise. The worker must short-circuit via
    # maybe_skip_already_in_progress/4 and return :ok WITHOUT attempting the
    # forbidden processing -> uploading transition (B5).
    assert :ok = perform_job(MuxIngestVariant, ctx.args)

    rows_after_second =
      Repo.all(from r in MediaProviderAsset, where: r.asset_id == ^ctx.asset.id)

    assert length(rows_after_second) == 1
    assert hd(rows_after_second).state == "processing"
  end

  # ===========================================================
  # MUX-06 — atomic-promote race protection
  # ===========================================================

  test "atomic_promote: storage_key drift returns {:cancel, {:stale_source, :asset_changed}}",
       ctx do
    # No ClientMock expectation: drift is detected before the SDK call.
    # Drift: mutate storage_key after enqueue (simulates a re-upload during ingest).
    {:ok, _updated} =
      ctx.asset
      |> MediaAsset.changeset(%{storage_key: "media/" <> ctx.asset.id <> "/different.mp4"})
      |> Repo.update()

    assert {:cancel, {:stale_source, :asset_changed}} =
             perform_job(MuxIngestVariant, ctx.args)
  end

  test "atomic_promote: recipe_digest drift returns {:cancel, {:stale_source, :recipe_changed}}",
       ctx do
    {:ok, _updated} =
      ctx.variant
      |> MediaVariant.changeset(%{recipe_digest: "sha256:" <> String.duplicate("b", 64)})
      |> Repo.update()

    assert {:cancel, {:stale_source, :recipe_changed}} =
             perform_job(MuxIngestVariant, ctx.args)
  end

  # ===========================================================
  # BL-02 — :errored row terminal-cancel (no FSM-violation retry burn)
  # ===========================================================

  test "BL-02: re-ingest against an :errored row returns {:cancel, _} (no FSM transition attempted)",
       ctx do
    # The FSM only allows errored → processing|deleted (provider_asset_fsm.ex:14).
    # Falling through to transition_uploading/4 would produce
    # {:invalid_transition, "errored", "uploading"} on every retry up to
    # max_attempts: 5. The fix MUST return :cancel so Oban does not retry.
    {:ok, _row} =
      %MediaProviderAsset{}
      |> MediaProviderAsset.changeset(%{
        asset_id: ctx.asset.id,
        profile: to_string(TestProfile),
        provider_name: "mux",
        playback_policy: "signed",
        state: "errored",
        last_sync_error: "previous attempt failed"
      })
      |> Repo.insert()

    # ClientMock.create_asset MUST NOT be called: the worker short-circuits
    # before calling the SDK. `verify_on_exit!` enforces this — any expect()
    # that fires would surface as an unexpected call.
    Mox.stub(ClientMock, :create_asset, fn _ ->
      raise "create_asset must not be called for :errored rows"
    end)

    assert {:cancel, {:provider_asset_errored, "previous attempt failed"}} =
             perform_job(MuxIngestVariant, ctx.args)

    # Row state must remain `:errored` (no spurious FSM transition attempted).
    row =
      Repo.get_by!(MediaProviderAsset,
        asset_id: ctx.asset.id,
        profile: to_string(TestProfile),
        provider_name: "mux"
      )

    assert row.state == "errored"
  end

  test "BL-02: re-ingest against a :deleted row returns {:cancel, :provider_asset_deleted}",
       ctx do
    {:ok, _row} =
      %MediaProviderAsset{}
      |> MediaProviderAsset.changeset(%{
        asset_id: ctx.asset.id,
        profile: to_string(TestProfile),
        provider_name: "mux",
        playback_policy: "signed",
        state: "deleted"
      })
      |> Repo.insert()

    Mox.stub(ClientMock, :create_asset, fn _ ->
      raise "create_asset must not be called for :deleted rows"
    end)

    assert {:cancel, :provider_asset_deleted} =
             perform_job(MuxIngestVariant, ctx.args)
  end

  # ===========================================================
  # BL-01 — compensating Mux delete on post-create drift detection
  # ===========================================================

  test "BL-01: post-create storage_key drift triggers compensating Adapter.delete_asset/1",
       ctx do
    # Sequence: create_asset succeeds (Mux asset is now billed) -> drift is
    # mutated AFTER create -> persist_provider_processing/4 detects drift in
    # its post-create re-fetch -> worker MUST best-effort delete the asset
    # before returning {:cancel, _}.
    test_pid = self()

    expect(ClientMock, :create_asset, fn _params ->
      # Mutate storage_key BETWEEN the SDK call and the post-create re-check.
      # This simulates a concurrent re-upload landing during the Mux REST
      # round trip — the exact race BL-01 protects against.
      {:ok, _} =
        ctx.asset
        |> MediaAsset.changeset(%{
          storage_key: "media/" <> ctx.asset.id <> "/raced.mp4"
        })
        |> Repo.update()

      {:ok, fixture("asset_create_201.json")}
    end)

    # The compensating delete MUST fire with the freshly-created Mux asset id.
    expect(ClientMock, :delete_asset, fn provider_asset_id ->
      send(test_pid, {:compensating_delete_called, provider_asset_id})
      :ok
    end)

    assert {:cancel, {:stale_source, :asset_changed}} =
             perform_job(MuxIngestVariant, ctx.args)

    assert_receive {:compensating_delete_called, "AbCd1234EfGh5678IjKl9012MnOp3456QrSt"}, 500
  end

  test "BL-01: post-create recipe_digest drift triggers compensating Adapter.delete_asset/1",
       ctx do
    test_pid = self()

    expect(ClientMock, :create_asset, fn _params ->
      # Mutate recipe_digest BETWEEN SDK call and post-create re-check.
      {:ok, _} =
        ctx.variant
        |> MediaVariant.changeset(%{
          recipe_digest: "sha256:" <> String.duplicate("c", 64)
        })
        |> Repo.update()

      {:ok, fixture("asset_create_201.json")}
    end)

    expect(ClientMock, :delete_asset, fn provider_asset_id ->
      send(test_pid, {:compensating_delete_called, provider_asset_id})
      :ok
    end)

    assert {:cancel, {:stale_source, :recipe_changed}} =
             perform_job(MuxIngestVariant, ctx.args)

    assert_receive {:compensating_delete_called, "AbCd1234EfGh5678IjKl9012MnOp3456QrSt"}, 500
  end

  test "BL-01: compensating delete failure does NOT change the {:cancel, _} return", ctx do
    # Belt-and-suspenders: best-effort delete absorbs adapter errors so the
    # worker still returns the {:cancel, _} verdict (the row's eventual
    # reconciliation lives with the sync coordinator's stuck-threshold path).
    expect(ClientMock, :create_asset, fn _params ->
      {:ok, _} =
        ctx.asset
        |> MediaAsset.changeset(%{
          storage_key: "media/" <> ctx.asset.id <> "/raced2.mp4"
        })
        |> Repo.update()

      {:ok, fixture("asset_create_201.json")}
    end)

    expect(ClientMock, :delete_asset, fn _provider_asset_id ->
      {:error, :provider_sync_failed}
    end)

    assert {:cancel, {:stale_source, :asset_changed}} =
             perform_job(MuxIngestVariant, ctx.args)
  end

  test "atomic_promote: drift emits [:rindle, :provider, :ingest, :exception] with kind: :cancelled",
       ctx do
    test_pid = self()
    handler_id = "ingest-cancelled-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:rindle, :provider, :ingest, :exception],
      fn _event, measurements, metadata, _ ->
        send(test_pid, {:tele, measurements, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    {:ok, _updated} =
      ctx.asset
      |> MediaAsset.changeset(%{storage_key: "media/" <> ctx.asset.id <> "/drifted.mp4"})
      |> Repo.update()

    assert {:cancel, _reason} = perform_job(MuxIngestVariant, ctx.args)
    assert_receive {:tele, _measurements, %{kind: :cancelled}}, 1_000
  end

  # ===========================================================
  # Pitfall 3 — 429 Retry-After extraction (SDK Issue #42)
  # ===========================================================

  test "429 from Mux returns {:snooze, retry_after_seconds}", ctx do
    expect(ClientMock, :create_asset, fn _params ->
      {:error, "rate limit",
       %Tesla.Env{status: 429, headers: [{"retry-after", "60"}], body: ""}}
    end)

    assert {:snooze, 60} = perform_job(MuxIngestVariant, ctx.args)
  end

  test "429 with missing Retry-After defaults to 60s snooze", ctx do
    expect(ClientMock, :create_asset, fn _params ->
      {:error, "rate limit", %Tesla.Env{status: 429, headers: [], body: ""}}
    end)

    assert {:snooze, 60} = perform_job(MuxIngestVariant, ctx.args)
  end

  # ===========================================================
  # Security invariant 14 — telemetry asset_id is redacted
  # ===========================================================

  test "every [:rindle, :provider, :ingest, _] event has redacted asset_id (last-4-char tag)",
       ctx do
    expect(ClientMock, :create_asset, fn _params ->
      {:ok, fixture("asset_create_201.json")}
    end)

    test_pid = self()
    handler_id = "ingest-redact-#{System.unique_integer([:positive])}"

    :telemetry.attach_many(
      handler_id,
      [
        [:rindle, :provider, :ingest, :start],
        [:rindle, :provider, :ingest, :stop]
      ],
      fn event, _measurements, metadata, _ ->
        send(test_pid, {:tele, event, metadata})
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    assert :ok = perform_job(MuxIngestVariant, ctx.args)

    # :start has nil asset_id (no Mux response yet); :stop has redacted last-4-char tag.
    assert_receive {:tele, [:rindle, :provider, :ingest, :start], %{asset_id: nil}}, 500
    assert_receive {:tele, [:rindle, :provider, :ingest, :stop], %{asset_id: redacted}}, 500

    assert is_binary(redacted) and redacted =~ ~r/^\.\.\.[A-Za-z0-9]{4}$/,
           "Telemetry must redact provider_asset_id to last-4-char tag (security invariant 14); got: #{inspect(redacted)}"
  end
end
