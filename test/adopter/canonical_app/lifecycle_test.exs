defmodule Rindle.Adopter.CanonicalApp.LifecycleTest do
  @moduledoc """
  Canonical adopter lane: full lifecycle exercised by an adopter-shaped
  consumer of Rindle. Runs against MinIO (via Rindle.Storage.S3) and the
  shared test PostgreSQL.

  This file is the source of truth for `guides/getting_started.md` (D-16).
  The snippet shown in that guide must match the public API calls below;
  drift between this file and the guide breaks DOC-01 acceptance.
  """

  use Rindle.DataCase, async: false
  use Oban.Testing, repo: Rindle.Adopter.CanonicalApp.Repo

  alias Rindle.Adopter.CanonicalApp.Profile, as: AdopterProfile
  alias Rindle.Adopter.CanonicalApp.Repo
  alias Rindle.Adopter.CanonicalApp.VideoProfile, as: AdopterVideoProfile
  alias Rindle.Domain.{MediaAsset, MediaAttachment, MediaUploadSession, MediaVariant}
  alias Rindle.Ops.UploadMaintenance
  alias Rindle.Upload.Broker
  alias Rindle.Workers.{ProcessVariant, PromoteAsset, PurgeStorage}

  @multipart_min_part_size 5 * 1024 * 1024
  @v13_thumb_digest "3a9ab2f60b2d26217471f22cc329252acba546c6341111a3ef89a8d9978d30a7"

  @moduletag :adopter
  @moduletag sandbox_repo: Rindle.Adopter.CanonicalApp.Repo

  # 1×1 transparent PNG — matches the fixture used in the proxied integration
  # test (test/rindle/upload/lifecycle_integration_test.exs L9-13).
  @png_1x1 <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
             0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00,
             0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08,
             0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0x44, 0x74,
             0x06, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82>>

  defmodule Owner do
    @moduledoc false
    defstruct [:id]
  end

  setup do
    # Start :inets so :httpc is available for the presigned PUT step.
    # In some Elixir releases :inets is started by default; this call is
    # idempotent and ensures we don't crash if it isn't.
    case :inets.start() do
      :ok -> :ok
      {:error, {:already_started, :inets}} -> :ok
    end

    # Start the adopter Repo (Sandbox-wrapped). Uses the same test DB as
    # Rindle.Repo per A3 in 05-RESEARCH.md. start_supervised handles
    # cleanup automatically on test exit.
    case start_supervised(Rindle.Adopter.CanonicalApp.Repo) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    # Configure the S3 adapter for MinIO from env vars (CI sets these; locally
    # they default to a localhost MinIO at :9000 with the published default
    # credentials).
    minio_url = System.get_env("RINDLE_MINIO_URL", "http://localhost:9000")
    bucket = System.get_env("RINDLE_MINIO_BUCKET", "rindle-test")
    access_key = System.get_env("RINDLE_MINIO_ACCESS_KEY", "minioadmin")
    secret_key = System.get_env("RINDLE_MINIO_SECRET_KEY", "minioadmin")
    region = System.get_env("RINDLE_MINIO_REGION", "us-east-1")

    %URI{host: host, port: port, scheme: scheme} = URI.parse(minio_url)

    previous_repo = Application.get_env(:rindle, :repo)
    previous_s3 = Application.get_env(:rindle, Rindle.Storage.S3)
    previous_ex_aws = Application.get_env(:ex_aws, :s3)

    Application.put_env(:rindle, :repo, Rindle.Adopter.CanonicalApp.Repo)
    Application.put_env(:rindle, Rindle.Storage.S3, bucket: bucket)

    Application.put_env(:ex_aws, :s3,
      scheme: "#{scheme}://",
      host: host,
      port: port,
      region: region,
      access_key_id: access_key,
      secret_access_key: secret_key
    )

    on_exit(fn ->
      case previous_repo do
        nil -> Application.delete_env(:rindle, :repo)
        value -> Application.put_env(:rindle, :repo, value)
      end

      case previous_s3 do
        nil -> Application.delete_env(:rindle, Rindle.Storage.S3)
        value -> Application.put_env(:rindle, Rindle.Storage.S3, value)
      end

      case previous_ex_aws do
        nil -> Application.delete_env(:ex_aws, :s3)
        value -> Application.put_env(:ex_aws, :s3, value)
      end
    end)

    :ok
  end

  describe "canonical adopter lifecycle" do
    test "direct upload through MinIO promotes asset, generates ready variant, and serves signed URL" do
      assert_upload_capabilities!(AdopterProfile.storage_adapter().capabilities())

      # ── Step 1: Adopter initiates an upload session ──────────────────────
      {:ok, session} = Broker.initiate_session(AdopterProfile, filename: "adopter.png")
      assert session.state == "initialized"

      # ── Step 2: Adopter requests a presigned PUT URL ─────────────────────
      {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
      assert signed.state == "signed"
      assert is_binary(presigned.url)
      assert String.starts_with?(presigned.url, "http")

      # ── Step 3: Client PUTs the file BYTES to the presigned URL ──────────
      # Per Blocker 5 / D-08: this MUST exercise the actual presigned PUT
      # path, NOT bypass it via Rindle.Storage.S3.store/3. The adopter's
      # production app does an HTTPS PUT directly from the client to the
      # presigned URL; we mirror that here using Erlang's :httpc.
      :ok = put_to_presigned_url(presigned.url, @png_1x1)

      # ── Step 4: Verify completion — transitions session, promotes asset ──
      {:ok, %{session: completed, asset: asset}} = Broker.verify_completion(session.id)
      assert completed.state == "completed"
      assert asset.state == "validating"
      assert_enqueued(worker: PromoteAsset, args: %{"asset_id" => asset.id})
      assert Repo.get!(Rindle.Domain.MediaUploadSession, session.id).state == "completed"

      # ── Step 5: Run promotion synchronously ──────────────────────────────
      assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

      asset = Repo.get!(MediaAsset, asset.id)
      assert asset.state in ["available", "processing", "ready"]

      # ── Step 6: Run any enqueued ProcessVariant jobs ─────────────────────
      # ProcessVariant takes %{"asset_id", "variant_name"} (NOT variant_id);
      # see lib/rindle/workers/process_variant.ex:14.
      variants =
        Repo.all(Ecto.Query.from(v in MediaVariant, where: v.asset_id == ^asset.id))

      assert variants != []

      for variant <- variants do
        assert :ok =
                 perform_job(ProcessVariant, %{
                   "asset_id" => asset.id,
                   "variant_name" => variant.name
                 })
      end

      # Reload variants to confirm they reached :ready.
      ready_variants =
        Repo.all(Ecto.Query.from(v in MediaVariant, where: v.asset_id == ^asset.id))

      assert Enum.all?(ready_variants, &(&1.state == "ready"))

      # ── Step 7: Adopter requests a signed delivery URL ───────────────────
      {:ok, signed_url} = Rindle.Delivery.url(AdopterProfile, asset.storage_key)
      assert is_binary(signed_url)
      assert String.contains?(signed_url, asset.storage_key)

      # ── Step 8: Adopter attaches the asset to an owner ───────────────────
      # Public signature (lib/rindle.ex:63):
      #   Rindle.attach(asset_or_id, owner, slot, _opts \\ [])
      #   → {:ok, %MediaAttachment{}} | {:error, term()}
      owner = %Owner{id: Ecto.UUID.generate()}
      {:ok, attachment} = Rindle.attach(asset.id, owner, "primary")
      assert attachment.asset_id == asset.id

      attachments =
        Repo.all(
          Ecto.Query.from(a in MediaAttachment,
            where:
              a.owner_type == ^to_string(Owner) and a.owner_id == ^owner.id and
                a.slot == ^"primary"
          )
        )

      assert length(attachments) == 1

      # ── Step 9: Adopter detaches and triggers async purge ────────────────
      # Public signature (lib/rindle.ex:112):
      #   Rindle.detach(owner, slot, _opts \\ [])
      #   → :ok | {:error, term()}
      assert :ok = Rindle.detach(owner, "primary")
      assert Repo.all(MediaAttachment) == []
      assert_enqueued(worker: PurgeStorage, args: %{"asset_id" => asset.id})
    end

    test "multipart upload through MinIO promotes asset, generates ready variant, and serves signed URL" do
      assert_upload_capabilities!(AdopterProfile.storage_adapter().capabilities())

      {part1, part2} = multipart_png_fixture_parts()

      {:ok, %{session: session, multipart: multipart}} =
        Rindle.initiate_multipart_upload(AdopterProfile, filename: "adopter-multipart.png")

      assert session.state == "initialized"
      assert session.upload_strategy == "multipart"
      assert multipart.upload_id != nil

      {:ok, %{session: signed, presigned: presigned_part1}} =
        Rindle.sign_multipart_part(session.id, 1)

      {:ok, %{session: signed_again, presigned: presigned_part2}} =
        Rindle.sign_multipart_part(session.id, 2)

      assert signed.state == "signed"
      assert signed_again.state == "signed"

      etag1 = put_part_to_presigned_url(presigned_part1.url, part1)
      etag2 = put_part_to_presigned_url(presigned_part2.url, part2)

      {:ok, %{session: completed, asset: asset}} =
        Rindle.complete_multipart_upload(session.id, [
          %{part_number: 1, etag: etag1},
          %{part_number: 2, etag: etag2}
        ])

      assert completed.state == "completed"
      assert asset.state == "validating"
      assert_enqueued(worker: PromoteAsset, args: %{"asset_id" => asset.id})
      assert Repo.get!(MediaUploadSession, session.id).state == "completed"

      assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

      asset = Repo.get!(MediaAsset, asset.id)
      assert asset.state in ["available", "processing", "ready"]

      variants =
        Repo.all(Ecto.Query.from(v in MediaVariant, where: v.asset_id == ^asset.id))

      assert variants != []

      for variant <- variants do
        assert :ok =
                 perform_job(ProcessVariant, %{
                   "asset_id" => asset.id,
                   "variant_name" => variant.name
                 })
      end

      ready_variants =
        Repo.all(Ecto.Query.from(v in MediaVariant, where: v.asset_id == ^asset.id))

      assert Enum.all?(ready_variants, &(&1.state == "ready"))

      {:ok, signed_url} = Rindle.Delivery.url(AdopterProfile, asset.storage_key)
      assert is_binary(signed_url)
      assert String.contains?(signed_url, asset.storage_key)

      owner = %Owner{id: Ecto.UUID.generate()}
      {:ok, attachment} = Rindle.attach(asset.id, owner, "primary")
      assert attachment.asset_id == asset.id

      assert :ok = Rindle.detach(owner, "primary")
      assert Repo.all(MediaAttachment) == []
      assert_enqueued(worker: PurgeStorage, args: %{"asset_id" => asset.id})
    end

    test "multipart uploads expire first and are deleted only after cleanup aborts them remotely" do
      {:ok, %{session: session}} =
        Rindle.initiate_multipart_upload(AdopterProfile, filename: "stale-multipart.png")

      expired_session =
        session
        |> MediaUploadSession.changeset(%{
          expires_at: DateTime.add(DateTime.utc_now(), -120, :second)
        })
        |> Repo.update!()

      {:ok, abort_report} = UploadMaintenance.abort_incomplete_uploads([])
      assert abort_report.sessions_aborted >= 1

      assert Repo.get!(MediaUploadSession, expired_session.id).state == "expired"

      {:ok, cleanup_report} =
        UploadMaintenance.cleanup_orphans(
          dry_run: false,
          storage: AdopterProfile.storage_adapter()
        )

      assert cleanup_report.sessions_deleted >= 1
      assert Repo.get(MediaUploadSession, expired_session.id) == nil
    end

    test "owner erasure uses the public preview and execute facade for account deletion" do
      owner = %Owner{id: Ecto.UUID.generate()}
      other_owner = %Owner{id: Ecto.UUID.generate()}
      orphan_asset = insert_adopter_asset("adopter-owner-erasure/orphan.png")
      shared_asset = insert_adopter_asset("adopter-owner-erasure/shared.png")

      owner_orphan_attachment = insert_adopter_attachment(orphan_asset, owner, "avatar")
      owner_shared_attachment = insert_adopter_attachment(shared_asset, owner, "hero")
      surviving_attachment = insert_adopter_attachment(shared_asset, other_owner, "hero")

      assert {:ok, preview_report} = Rindle.preview_owner_erasure(owner)
      assert preview_report.mode == :preview
      assert preview_report.purge_enqueued == 0
      assert preview_report.purge_already_queued == 0

      assert preview_report.attachments_to_detach.count == 2

      assert Enum.sort_by(preview_report.attachments_to_detach.entries, & &1.slot) == [
               %{
                 asset_id: orphan_asset.id,
                 attachment_id: owner_orphan_attachment.id,
                 slot: "avatar"
               },
               %{
                 asset_id: shared_asset.id,
                 attachment_id: owner_shared_attachment.id,
                 slot: "hero"
               }
             ]

      assert preview_report.assets_to_purge == %{
               count: 1,
               entries: [%{asset_id: orphan_asset.id, profile: orphan_asset.profile}]
             }

      assert preview_report.retained_shared_assets == %{
               count: 1,
               entries: [
                 %{
                   asset_id: shared_asset.id,
                   profile: shared_asset.profile,
                   surviving_attachment_count: 1
                 }
               ]
             }

      assert {:ok, execute_report} = Rindle.erase_owner(owner)
      assert execute_report.mode == :execute
      assert execute_report.purge_enqueued == 1
      assert execute_report.purge_already_queued == 0
      refute Repo.get(MediaAttachment, owner_orphan_attachment.id)
      refute Repo.get(MediaAttachment, owner_shared_attachment.id)
      assert Repo.get(MediaAttachment, surviving_attachment.id)

      assert_enqueued worker: PurgeStorage,
                      args: %{"asset_id" => orphan_asset.id, "profile" => orphan_asset.profile}

      assert :ok =
               perform_job(PurgeStorage, %{
                 "asset_id" => orphan_asset.id,
                 "profile" => orphan_asset.profile
               })

      refute Repo.get(MediaAsset, orphan_asset.id)
      assert Repo.get(MediaAsset, shared_asset.id)

      assert {:ok, rerun_report} = Rindle.erase_owner(owner)
      assert rerun_report.attachments_to_detach == %{count: 0, entries: []}
      assert rerun_report.assets_to_purge == %{count: 0, entries: []}
      assert rerun_report.retained_shared_assets == %{count: 0, entries: []}
      assert rerun_report.purge_enqueued == 0
      assert rerun_report.purge_already_queued == 0
    end

    test "stock web preset round-trips realistic smartphone uploads end to end" do
      assert_upload_capabilities!(AdopterVideoProfile.storage_adapter().capabilities())

      for fixture <- smartphone_fixture_matrix() do
        {:ok, session} =
          Rindle.initiate_upload(AdopterVideoProfile, filename: fixture.upload_filename)

        {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
        assert signed.state == "signed"
        :ok = put_to_presigned_url(presigned.url, File.read!(fixture.path))

        {:ok, %{session: completed, asset: asset}} = Rindle.verify_completion(session.id)
        assert completed.state == "completed"
        assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

        promoted_asset = Repo.get!(MediaAsset, asset.id)
        assert promoted_asset.kind == "video"
        assert promoted_asset.has_video_track == true
        assert promoted_asset.has_audio_track == true
        assert promoted_asset.duration_ms > 0
        assert_fixture_probe!(fixture, promoted_asset)

        variants =
          Repo.all(
            Ecto.Query.from(v in MediaVariant, where: v.asset_id == ^asset.id, order_by: v.name)
          )

        assert Enum.map(variants, & &1.name) == ["poster", "web_720p"]

        for variant <- variants do
          assert :ok =
                   perform_job(ProcessVariant, %{
                     "asset_id" => asset.id,
                     "variant_name" => variant.name
                   })
        end

        ready_variants =
          Repo.all(
            Ecto.Query.from(v in MediaVariant, where: v.asset_id == ^asset.id, order_by: v.name)
          )

        assert Enum.map(ready_variants, &{&1.name, &1.output_kind, &1.state}) == [
                 {"poster", "image", "ready"},
                 {"web_720p", "video", "ready"}
               ]

        assert Enum.all?(ready_variants, &(is_binary(&1.storage_key) and &1.byte_size > 0))

        poster_variant = Enum.find(ready_variants, &(&1.name == "poster"))
        web_variant = Enum.find(ready_variants, &(&1.name == "web_720p"))

        assert is_binary(poster_variant.storage_key)
        assert is_binary(web_variant.storage_key)
        assert String.contains?(web_variant.storage_key, "web_720p")

        {:ok, signed_url} = Rindle.url(AdopterVideoProfile, promoted_asset.storage_key)
        assert is_binary(signed_url)
        assert String.contains?(signed_url, promoted_asset.storage_key)

        {:ok, playback_url} = Rindle.url(AdopterVideoProfile, web_variant.storage_key)
        assert is_binary(playback_url)
        assert String.contains?(playback_url, web_variant.storage_key)
      end
    end
  end

  describe "v1.0 → v1.4 backward-compat parity (AV-02-11, D-22)" do
    alias Rindle.Adopter.CanonicalApp.Profile, as: AdopterProfile

    test "image-only canonical profile compiles unchanged on v1.4 (D-22 condition 1)" do
      assert Code.ensure_loaded?(AdopterProfile)
      assert function_exported?(AdopterProfile, :variants, 0)
      assert function_exported?(AdopterProfile, :recipe_digest, 1)
    end

    test "Profile.variants()[:thumb] does NOT contain :kind key (D-14 + D-22 condition 2)" do
      thumb = AdopterProfile.variants()[:thumb]

      refute Map.has_key?(thumb, :kind),
             "image-default canonical profile must omit :kind from validated map " <>
               "(D-14); persisting :kind would break recipe digest stability for every " <>
               "existing image-only adopter."
    end

    test "Profile.recipe_digest(:thumb) matches v1.3 snapshot byte-for-byte (D-22 condition 3 — THE load-bearing assertion)" do
      assert AdopterProfile.recipe_digest(:thumb) == @v13_thumb_digest
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # Helpers
  # ─────────────────────────────────────────────────────────────────────────

  # PUT the body to the presigned URL using Erlang's :httpc (no extra dep).
  # Per Blocker 5 / D-08: the adopter-facing path uses HTTP PUT to the
  # presigned URL the broker issued; we MUST exercise that here, not
  # bypass via Rindle.Storage.S3.store/3.
  #
  # If the adopter lane discovers MinIO presigned PUT semantics differ
  # enough to require workarounds (e.g., specific signature-version
  # header behaviors), document the gap explicitly in the SUMMARY as
  # "DEFERRED to v1.1: full presigned PUT verification requires X" rather
  # than silently falling back to the S3 adapter store path.
  defp put_to_presigned_url(presigned_url, body)
       when is_binary(presigned_url) and is_binary(body) do
    url_charlist = String.to_charlist(presigned_url)
    headers = []
    content_type = ~c"application/octet-stream"
    request = {url_charlist, headers, content_type, body}

    case :httpc.request(:put, request, [], []) do
      {:ok, {{_http_version, status, _reason}, _resp_headers, _resp_body}}
      when status in 200..299 ->
        :ok

      {:ok, {{_http_version, status, reason}, _resp_headers, resp_body}} ->
        raise "Presigned PUT failed with status #{status} #{reason}: #{inspect(resp_body)}"

      {:error, reason} ->
        raise "Presigned PUT to MinIO failed: #{inspect(reason)}"
    end
  end

  defp put_part_to_presigned_url(presigned_url, body)
       when is_binary(presigned_url) and is_binary(body) do
    url_charlist = String.to_charlist(presigned_url)
    request = {url_charlist, [], ~c"application/octet-stream", body}

    case :httpc.request(:put, request, [], []) do
      {:ok, {{_http_version, status, _reason}, response_headers, _resp_body}}
      when status in 200..299 ->
        response_headers
        |> Enum.find_value(fn
          {header, value} when header in [~c"etag", ~c"ETag"] -> List.to_string(value)
          _other -> nil
        end)
        |> case do
          nil -> raise "Multipart UploadPart response did not include an ETag header"
          etag -> etag
        end

      {:ok, {{_http_version, status, reason}, _response_headers, resp_body}} ->
        raise "Multipart UploadPart failed with status #{status} #{reason}: #{inspect(resp_body)}"

      {:error, reason} ->
        raise "Multipart UploadPart to MinIO failed: #{inspect(reason)}"
    end
  end

  defp multipart_png_fixture_parts do
    padding_size = @multipart_min_part_size - byte_size(@png_1x1)
    first_part = @png_1x1 <> :binary.copy(<<0>>, padding_size)
    second_part = "multipart-tail"
    {first_part, second_part}
  end

  defp assert_upload_capabilities!(capabilities) do
    assert :presigned_put in capabilities
    assert :multipart_upload in capabilities
  end

  defp smartphone_fixture_matrix do
    root = Path.expand("../../support/fixtures/smartphone", __DIR__)

    [
      %{
        name: "portrait quicktime rotation",
        path: Path.join(root, "portrait_rotation.mov"),
        upload_filename: "portrait_rotation.mov",
        content_type: "video/quicktime",
        width: 360,
        height: 640,
        rotation: 90
      },
      %{
        name: "android webm",
        path: Path.join(root, "android_capture.webm"),
        upload_filename: "android_capture.webm",
        content_type: "video/webm",
        width: 640,
        height: 360,
        rotation: nil
      }
    ]
  end

  defp assert_fixture_probe!(fixture, asset) do
    assert asset.content_type == fixture.content_type
    assert asset.width == fixture.width
    assert asset.height == fixture.height

    assert fixture_rotation(fixture.path) == fixture.rotation
  end

  defp insert_adopter_asset(storage_key) do
    %MediaAsset{}
    |> MediaAsset.changeset(%{
      state: "available",
      profile: to_string(AdopterProfile),
      storage_key: storage_key
    })
    |> Repo.insert!()
  end

  defp insert_adopter_attachment(asset, owner, slot) do
    %MediaAttachment{}
    |> MediaAttachment.changeset(%{
      asset_id: asset.id,
      owner_type: to_string(owner.__struct__),
      owner_id: owner.id,
      slot: slot
    })
    |> Repo.insert!()
  end

  defp fixture_rotation(path) do
    {json, 0} =
      System.cmd("ffprobe", [
        "-v",
        "error",
        "-print_format",
        "json",
        "-show_format",
        "-show_streams",
        path
      ])

    json
    |> Jason.decode!()
    |> Map.get("streams", [])
    |> Enum.find(fn stream -> stream["codec_type"] == "video" end)
    |> case do
      nil ->
        nil

      stream ->
        stream
        |> Map.get("side_data_list", [])
        |> Enum.find_value(fn side_data -> side_data["rotation"] end)
    end
  end
end
