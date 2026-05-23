defmodule Rindle.Storage.LocalTusTest do
  @moduledoc """
  Proves the Phase 42 tus foundation that `TusPlug` (Plans 02/03) stands on:
  the `:tus_upload` capability, the additive `resumable_protocol` column,
  `Broker.initiate_tus_upload/2`, and the Local tmp-append/atomic-rename helpers.
  """

  alias Rindle.Adopter.CanonicalApp.Repo, as: AdopterRepo
  alias Rindle.Domain.{MediaAsset, MediaUploadSession}
  alias Rindle.Storage.{Capabilities, GCS, Local}
  alias Rindle.Upload.Broker

  use Rindle.DataCase, async: false

  alias Ecto.Adapters.SQL.Sandbox

  defmodule TusProfile do
    use Rindle.Profile,
      storage: Local,
      variants: [
        thumb: [mode: :crop, width: 100, height: 100]
      ],
      allow_mime: ["image/jpeg"],
      max_bytes: 10_485_760
  end

  setup do
    case start_supervised(AdopterRepo) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    Sandbox.checkout(AdopterRepo)
    Sandbox.mode(AdopterRepo, {:shared, self()})

    previous_repo = Application.get_env(:rindle, :repo)
    Application.put_env(:rindle, :repo, AdopterRepo)

    root = Path.join(System.tmp_dir!(), "rindle-local-tus-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)

    on_exit(fn ->
      File.rm_rf(root)

      case previous_repo do
        nil -> Application.delete_env(:rindle, :repo)
        value -> Application.put_env(:rindle, :repo, value)
      end
    end)

    {:ok, root: root}
  end

  describe "capability honesty (D-09)" do
    test ":tus_upload is registered and advertised by Local only" do
      assert Capabilities.supports?(Local, :tus_upload)
      refute Capabilities.supports?(GCS, :tus_upload)
      assert :tus_upload in Capabilities.known()
    end
  end

  describe "Broker.initiate_tus_upload/2 (D-10/D-11)" do
    test "creates a signed/resumable session stamped with the tus protocol" do
      assert {:ok, %{session: session}} =
               Broker.initiate_tus_upload(TusProfile, filename: "clip.jpg")

      assert session.resumable_protocol == "tus"
      assert session.state == "signed"
      assert session.upload_strategy == "resumable"
      assert session.last_known_offset == 0
    end

    test "fails closed when the adapter does not advertise :tus_upload" do
      defmodule NoTusStorage do
        @moduledoc false
        def capabilities, do: [:local, :presigned_put]
      end

      defmodule NoTusProfile do
        use Rindle.Profile,
          storage: NoTusStorage,
          variants: [thumb: [mode: :crop, width: 100, height: 100]]
      end

      assert {:error, {:upload_unsupported, :tus_upload}} =
               Broker.initiate_tus_upload(NoTusProfile, filename: "clip.jpg")
    end
  end

  describe "Local tmp-append + atomic-rename backing (D-01/Pitfall 5)" do
    test "tus_append/3 grows the .part file by the chunk size across calls", %{root: root} do
      opts = [root: root]
      session_id = Ecto.UUID.generate()
      part_path = Local.tus_part_path(session_id, opts)

      assert :ok = Local.tus_append(session_id, "0123456789", opts)
      assert File.stat!(part_path).size == 10

      assert :ok = Local.tus_append(session_id, "abcdef", opts)
      assert File.stat!(part_path).size == 16
    end

    test "tus_complete/3 atomic-renames the part into the final key with full size", %{root: root} do
      opts = [root: root]
      session_id = Ecto.UUID.generate()
      key = "assets/asset-1/clip.jpg"

      chunk_a = "0123456789"
      chunk_b = "abcdef"
      assert :ok = Local.tus_append(session_id, chunk_a, opts)
      assert :ok = Local.tus_append(session_id, chunk_b, opts)

      part_path = Local.tus_part_path(session_id, opts)
      final_path = Local.path_for(key, opts)

      assert {:ok, ^final_path} = Local.tus_complete(session_id, key, opts)
      refute File.exists?(part_path)
      assert File.exists?(final_path)

      assert File.stat!(final_path).size == byte_size(chunk_a) + byte_size(chunk_b)
      assert File.read!(final_path) == chunk_a <> chunk_b
    end
  end

  describe "upload_part_stream/5 + complete_part_stream/4 (TUS-06 Local, Plan 04)" do
    # The polymorphic tus-sink callbacks wrap the Phase-42 helpers so the Plug can
    # dispatch through the behaviour (adapter.upload_part_stream/5 +
    # adapter.complete_part_stream/4) without hard-wiring Local. part_number
    # semantics do not exist for Local; the return is %{offset: n} with NO
    # :upload_id/:parts keys (Pitfall 5).

    test "upload_part_stream/5 appends the temp-file bytes and returns %{offset: base + n}", %{
      root: root
    } do
      session_id = Ecto.UUID.generate()
      key = "assets/asset-1/clip.jpg"
      temp_path = Path.join(root, "patch-1.part")
      File.write!(temp_path, "0123456789")

      assert {:ok, state} =
               Local.upload_part_stream(key, temp_path, 0, %{offset: 0},
                 session_id: session_id,
                 root: root
               )

      assert state.offset == 10
      # Local has no part semantics — no :upload_id/:parts keys (Pitfall 5).
      refute Map.has_key?(state, :upload_id)
      refute Map.has_key?(state, :parts)

      part_path = Local.tus_part_path(session_id, root: root)
      assert File.stat!(part_path).size == 10
    end

    test "upload_part_stream/5 accumulates across PATCHes (offset advances by base_offset)", %{
      root: root
    } do
      session_id = Ecto.UUID.generate()
      key = "assets/asset-2/clip.jpg"

      temp_a = Path.join(root, "patch-a.part")
      File.write!(temp_a, "01234567")

      assert {:ok, s1} =
               Local.upload_part_stream(key, temp_a, 0, %{offset: 0},
                 session_id: session_id,
                 root: root
               )

      assert s1.offset == 8

      temp_b = Path.join(root, "patch-b.part")
      File.write!(temp_b, "89abcdef")

      assert {:ok, s2} =
               Local.upload_part_stream(key, temp_b, s1.offset, s1,
                 session_id: session_id,
                 root: root
               )

      assert s2.offset == 16
      assert File.stat!(Local.tus_part_path(session_id, root: root)).size == 16
    end

    test "upload_part_stream/5 streams large temp files without buffering whole into memory", %{
      root: root
    } do
      session_id = Ecto.UUID.generate()
      key = "assets/asset-large/clip.bin"
      temp_path = Path.join(root, "patch-large.part")
      payload = String.duplicate("x", 3 * 1024 * 1024)
      File.write!(temp_path, payload)

      assert {:ok, state} =
               Local.upload_part_stream(key, temp_path, 0, %{offset: 0},
                 session_id: session_id,
                 root: root
               )

      assert state.offset == byte_size(payload)
      assert File.stat!(Local.tus_part_path(session_id, root: root)).size == byte_size(payload)
    end

    test "complete_part_stream/4 atomic-renames the part into the final key", %{root: root} do
      session_id = Ecto.UUID.generate()
      key = "assets/asset-3/clip.jpg"
      temp_path = Path.join(root, "patch-final.part")
      File.write!(temp_path, "0123456789abcdef")

      {:ok, _state} =
        Local.upload_part_stream(key, temp_path, 0, %{offset: 0},
          session_id: session_id,
          root: root
        )

      part_path = Local.tus_part_path(session_id, root: root)
      assert File.exists?(part_path)

      assert {:ok, %{upload_key: ^key}} =
               Local.complete_part_stream(key, nil, %{offset: 16},
                 session_id: session_id,
                 root: root
               )

      final_path = Local.path_for(key, root: root)
      refute File.exists?(part_path)
      assert File.exists?(final_path)
      assert File.read!(final_path) == "0123456789abcdef"
    end

    test "complete_part_stream/4 propagates an error when there is no part file", %{root: root} do
      session_id = Ecto.UUID.generate()
      key = "assets/asset-missing/clip.jpg"

      assert {:error, _reason} =
               Local.complete_part_stream(key, nil, %{offset: 0},
                 session_id: session_id,
                 root: root
               )
    end
  end

  describe "resumable_protocol column (D-10)" do
    test "a row persisted with the tus protocol reads back as tus" do
      assert {:ok, %{session: session}} =
               Broker.initiate_tus_upload(TusProfile, filename: "clip.jpg")

      reloaded = AdopterRepo.get!(MediaUploadSession, session.id)
      assert reloaded.resumable_protocol == "tus"
    end

    test "a legacy-style row without the column reads nil" do
      changeset =
        MediaUploadSession.changeset(%MediaUploadSession{}, %{
          asset_id: insert_staged_asset().id,
          state: "signed",
          upload_key: "assets/legacy/clip.jpg",
          upload_strategy: "presigned_put",
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
        })

      assert {:ok, session} = AdopterRepo.insert(changeset)
      assert session.resumable_protocol == nil
    end
  end

  defp insert_staged_asset do
    {:ok, asset} =
      %MediaAsset{}
      |> MediaAsset.changeset(%{
        state: "staged",
        profile: "legacy",
        storage_key: "assets/legacy/clip.jpg",
        filename: "clip.jpg"
      })
      |> AdopterRepo.insert()

    asset
  end
end
