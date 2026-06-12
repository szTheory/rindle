defmodule Rindle.Admin.QueriesTest do
  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Repo

  alias Rindle.Admin.Queries
  alias Rindle.Domain.{
    MediaAsset,
    MediaAttachment,
    MediaProcessingRun,
    MediaProviderAsset,
    MediaUploadSession,
    MediaVariant
  }

  defmodule AdminImageProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [thumb: [mode: :fit, width: 64, height: 64]],
      allow_mime: ["image/png"],
      max_bytes: 10_485_760
  end

  defmodule AdminVideoProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [web_720p: [kind: :video, preset: :web_720p]],
      allow_mime: ["video/mp4"],
      max_bytes: 524_288_000
  end

  test "home_status/1 returns runtime, doctor, counts, generated timestamp, and recommendations" do
    asset = insert_asset(%{state: "ready", profile: to_string(AdminImageProfile)})
    _variant = insert_variant(asset, %{state: "failed", updated_at: age_ago(600)})

    assert {:ok, model} =
             Queries.home_status(
               profiles: [AdminImageProfile],
               runtime_opts: [limit: 2],
               doctor_opts: [probe: fn -> :ok end, oban_config: [repo: Rindle.Repo, queues: []]]
             )

    assert %DateTime{} = model.generated_at
    assert is_map(model.runtime_status)
    assert is_map(model.doctor)
    assert model.counts.assets.total >= 1
    assert model.counts.variants.total >= 1
    assert is_list(model.recommendations)
  end

  test "assets/1 filters by state, profile, and kind, rejects unknown filters, and returns bounded rows" do
    image_asset =
      insert_asset(%{state: "ready", profile: to_string(AdminImageProfile), kind: "image"})

    _video_asset =
      insert_asset(%{
        state: "ready",
        profile: to_string(AdminVideoProfile),
        kind: "video",
        content_type: "video/mp4",
        duration_ms: 12_000,
        width: 1280,
        height: 720,
        has_video_track: true
      })

    assert {:ok, model} =
             Queries.assets(
               state: "ready",
               profile: to_string(AdminImageProfile),
               kind: "image",
               limit: 1
             )

    assert model.filters.state == "ready"
    assert [%{id: id, profile: profile, kind: "image"}] = model.rows
    assert id == image_asset.id
    assert profile == to_string(AdminImageProfile)
    assert model.limit == 1

    assert {:error, {:unknown_filters, [:surprise]}} = Queries.assets(%{surprise: true})
  end

  test "asset_detail/1 returns one asset with attachments, variants, upload sessions, processing runs, and provider summaries" do
    asset = insert_asset(%{state: "ready"})
    attachment = insert_attachment(asset, %{slot: "hero"})
    variant = insert_variant(asset, %{name: "thumb", state: "ready"})
    session = insert_upload_session(asset, %{state: "completed"})
    run = insert_processing_run(asset, %{variant_name: "thumb", state: "succeeded"})

    provider =
      insert_provider_asset(asset, %{
        provider_asset_id: "provider-secret-id-0000111122223333",
        state: "ready"
      })

    assert {:ok, model} = Queries.asset_detail(asset.id)

    assert model.asset.id == asset.id
    assert [%{id: attachment_id}] = model.attachments
    assert attachment_id == attachment.id
    assert [%{id: variant_id}] = model.variants
    assert variant_id == variant.id
    assert [%{id: session_id}] = model.upload_sessions
    assert session_id == session.id
    assert [%{id: run_id}] = model.processing_runs
    assert run_id == run.id
    assert [%{id: provider_id, provider_asset_id: "Provider identifier redacted"}] =
             model.provider_assets

    assert provider_id == provider.id

    encoded = inspect(model)
    refute encoded =~ provider.provider_asset_id
  end

  test "upload_sessions/1 and upload_session_detail/1 redact session_uri values as Redacted by Rindle Admin" do
    asset = insert_asset(%{profile: to_string(AdminImageProfile)})
    raw_uri = "https://storage.example/session-secret"

    session =
      insert_upload_session(asset, %{
        state: "signed",
        upload_strategy: "resumable",
        resumable_protocol: "gcs",
        session_uri: raw_uri,
        session_uri_expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })

    assert {:ok, list_model} =
             Queries.upload_sessions(
               state: "signed",
               profile: to_string(AdminImageProfile),
               strategy: "resumable"
             )

    assert [%{id: session_id, session_uri: "Redacted by Rindle Admin"}] = list_model.rows
    assert session_id == session.id

    assert {:ok, detail_model} = Queries.upload_session_detail(session.id)
    assert detail_model.upload_session.session_uri == "Redacted by Rindle Admin"

    encoded = inspect({list_model, detail_model})
    refute encoded =~ raw_uri

    assert {:error, {:unknown_filters, [:session_uri]}} =
             Queries.upload_sessions(%{session_uri: raw_uri})
  end

  test "variants_jobs/1 composes RuntimeStatus findings without executing repair" do
    asset = insert_asset(%{profile: to_string(AdminImageProfile)})
    _variant = insert_variant(asset, %{state: "failed", updated_at: age_ago(600)})

    assert {:ok, model} =
             Queries.variants_jobs(profile: to_string(AdminImageProfile), class: :failed_work)

    assert model.runtime_status.variants.counts.failed == 1
    assert Enum.any?(model.findings, &(&1.class == :failed_work))

    refute_receive {:repair_executed, _}

    assert {:error, {:unknown_filters, [:execute]}} = Queries.variants_jobs(%{execute: true})
  end

  test "runtime_doctor/1 returns doctor and runtime status without shelling out to Mix tasks" do
    assert {:ok, model} =
             Queries.runtime_doctor(
               profiles: [AdminImageProfile],
               runtime_opts: [limit: 2],
               doctor_opts: [probe: fn -> :ok end, oban_config: [repo: Rindle.Repo, queues: []]]
             )

    assert is_map(model.doctor)
    assert is_map(model.runtime_status)
    assert model.doctor.total >= 1

    encoded = inspect(model)
    refute encoded =~ "Mix.Tasks.Rindle.Doctor"
  end

  test "actions_directory/0 returns read-only Phase 90 operation metadata with no executable callbacks" do
    assert {:ok, model} = Queries.actions_directory()

    assert Enum.map(model.actions, & &1.id) == [
             :owner_erasure,
             :batch_erasure,
             :variant_regeneration,
             :quarantine_review,
             :lifecycle_repair
           ]

    for action <- model.actions do
      assert action.phase == 90
      assert action.enabled? == false
      refute Map.has_key?(action, :mfa)
      refute Map.has_key?(action, :callback)
      refute Map.has_key?(action, :function)
    end
  end

  defp insert_asset(attrs) do
    params =
      %{
        state: "available",
        profile: to_string(AdminImageProfile),
        storage_key: "assets/#{System.unique_integer([:positive])}.bin",
        kind: "image",
        content_type: "image/png",
        byte_size: 1234,
        filename: "sample.png",
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

  defp insert_attachment(asset, attrs) do
    params =
      %{
        asset_id: asset.id,
        owner_type: "User",
        owner_id: Ecto.UUID.generate(),
        slot: "avatar"
      }
      |> Map.merge(attrs)

    %MediaAttachment{}
    |> MediaAttachment.changeset(params)
    |> Rindle.Repo.insert!()
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
        storage_key: "variants/#{System.unique_integer([:positive])}.bin",
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

  defp insert_processing_run(asset, attrs) do
    params =
      %{
        asset_id: asset.id,
        variant_name: "thumb",
        worker: "Rindle.Workers.ProcessVariant",
        state: "queued",
        attempt: 1
      }
      |> Map.merge(attrs)

    %MediaProcessingRun{}
    |> MediaProcessingRun.changeset(params)
    |> Rindle.Repo.insert!()
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
      |> Map.merge(Map.drop(attrs, [:provider_asset_id, :state]))

    %MediaProviderAsset{}
    |> MediaProviderAsset.changeset(params)
    |> Rindle.Repo.insert!()
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
