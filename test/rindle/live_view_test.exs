defmodule Rindle.LiveViewTest do
  use Rindle.DataCase, async: true
  import Mox

  Code.ensure_loaded!(Rindle.LiveView)

  alias Phoenix.LiveView.{UploadConfig, UploadEntry}
  alias Rindle.Domain.{MediaAsset, MediaUploadSession}

  setup :set_mox_from_context
  setup :verify_on_exit!

  defmodule TestProfile do
    use Rindle.Profile,
      storage: Rindle.StorageMock,
      variants: [],
      allow_mime: ["image/jpeg", "image/png"],
      max_bytes: 10_485_760
  end

  defp build_socket do
    %Phoenix.LiveView.Socket{
      assigns: %{__changed__: %{}},
      private: %{live_temp: %{}}
    }
  end

  describe "allow_upload/4" do
    test "configures upload with external signer on socket" do
      socket = build_socket()

      updated_socket =
        Rindle.LiveView.allow_upload(socket, :avatar, TestProfile,
          accept: ~w(.jpg .jpeg .png),
          max_entries: 1
        )

      uploads = updated_socket.assigns[:uploads]
      assert uploads != nil
      assert Map.has_key?(uploads, :avatar)

      avatar_config = uploads[:avatar]
      assert avatar_config.name == :avatar
      assert avatar_config.max_entries == 1
      # external is set to a function (the Rindle signer)
      assert is_function(avatar_config.external, 2)
    end

    test "merges user opts with external signer" do
      socket = build_socket()

      updated_socket =
        Rindle.LiveView.allow_upload(socket, :document, TestProfile,
          accept: :any,
          max_entries: 5,
          max_file_size: 50_000_000
        )

      config = updated_socket.assigns.uploads[:document]
      assert config.max_entries == 5
      assert config.max_file_size == 50_000_000
    end

    test "external signer returns broker-owned session and asset metadata" do
      socket = build_socket()

      updated_socket =
        Rindle.LiveView.allow_upload(socket, :avatar, TestProfile,
          accept: ~w(.jpg .jpeg .png),
          max_entries: 1
        )

      external_fn = updated_socket.assigns.uploads[:avatar].external
      entry = %UploadEntry{client_name: "avatar.png", ref: "avatar-ref"}

      expect(Rindle.StorageMock, :presigned_put, fn key, _expires_in, _opts ->
        assert key =~ ".png"
        {:ok, %{url: "https://example.com/upload", method: :put, headers: %{"x-test" => "1"}}}
      end)

      {:ok, meta, returned_socket} = external_fn.(entry, updated_socket)

      assert returned_socket == updated_socket
      assert meta.uploader == "Rindle"
      assert meta.url == "https://example.com/upload"
      assert meta.method == :put
      assert meta.headers == %{"x-test" => "1"}

      session = Repo.get!(MediaUploadSession, meta.session_id)
      assert session.state == "signed"
      assert meta.asset_id == session.asset_id

      asset = Repo.get!(MediaAsset, meta.asset_id)
      assert asset.id == session.asset_id
      assert asset.storage_key == session.upload_key
    end

    test "external signer returns a LiveView-compatible error tuple when signing fails" do
      socket = build_socket()

      updated_socket =
        Rindle.LiveView.allow_upload(socket, :avatar, TestProfile,
          accept: ~w(.jpg .jpeg .png),
          max_entries: 1
        )

      external_fn = updated_socket.assigns.uploads[:avatar].external
      entry = %UploadEntry{client_name: "avatar.png", ref: "avatar-ref"}

      expect(Rindle.StorageMock, :presigned_put, fn _key, _expires_in, _opts ->
        {:error, :timeout}
      end)

      assert {:error,
              %{reason: "upload_unavailable", code: "upload_sign_failed"},
              ^updated_socket} = external_fn.(entry, updated_socket)
    end
  end

  describe "consume_uploaded_entries/3" do
    test "verifies the persisted broker session before invoking the callback" do
      socket = build_socket()

      updated_socket =
        Rindle.LiveView.allow_upload(socket, :avatar, TestProfile,
          accept: ~w(.jpg .jpeg .png),
          max_entries: 1
        )

      external_fn = updated_socket.assigns.uploads[:avatar].external
      entry = %UploadEntry{client_name: "avatar.png", ref: "avatar-ref"}

      expect(Rindle.StorageMock, :presigned_put, fn _key, _expires_in, _opts ->
        {:ok, %{url: "https://example.com/upload", method: :put, headers: %{}}}
      end)

      {:ok, meta, _socket} = external_fn.(entry, updated_socket)

      expect(Rindle.StorageMock, :head, fn key, _opts ->
        session = Repo.get!(MediaUploadSession, meta.session_id)
        assert key == session.upload_key
        {:ok, %{size: 1234, content_type: "image/png"}}
      end)

      completed_socket = put_completed_entry(updated_socket, :avatar, entry, meta)

      results =
        Rindle.LiveView.consume_uploaded_entries(completed_socket, :avatar, fn uploaded_entry, uploaded_meta ->
          {:ok, {uploaded_entry.client_name, uploaded_meta.asset_id}}
        end)

      assert results == [{"avatar.png", meta.asset_id}]

      session = Repo.get!(MediaUploadSession, meta.session_id)
      asset = Repo.get!(MediaAsset, meta.asset_id)

      assert session.state == "completed"
      assert session.verified_at != nil
      assert asset.state == "validating"
      assert asset.byte_size == 1234
      assert asset.content_type == "image/png"
    end

    test "raises when upload meta is missing session_id" do
      socket = build_socket()
      entry = %UploadEntry{client_name: "avatar.png", ref: "avatar-ref"}
      completed_socket = put_completed_entry(socket_with_upload(socket), :avatar, entry, %{asset_id: Ecto.UUID.generate()})

      assert_raise ArgumentError, ~r/requires :session_id/, fn ->
        Rindle.LiveView.consume_uploaded_entries(completed_socket, :avatar, fn _uploaded_entry, _uploaded_meta ->
          {:ok, :unexpected}
        end)
      end
    end

    test "postpones the entry when verify_completion fails" do
      %{completed_socket: completed_socket, meta: meta} = completed_socket_fixture()

      expect(Rindle.StorageMock, :head, fn _key, _opts ->
        {:error, :not_found}
      end)

      assert [{:error, {:rindle_verify_failed, :storage_object_missing}}] =
               Rindle.LiveView.consume_uploaded_entries(completed_socket, :avatar, fn _uploaded_entry, _uploaded_meta ->
                 {:ok, :unexpected}
               end)

      persisted_session = Repo.get!(MediaUploadSession, meta.session_id)
      assert persisted_session.state == "signed"
    end

    test "allows idempotent duplicate consume calls for a completed session" do
      %{updated_socket: updated_socket, completed_socket: completed_socket, entry: entry, meta: meta} =
        completed_socket_fixture()

      expect(Rindle.StorageMock, :head, fn _key, _opts ->
        {:ok, %{size: 1234, content_type: "image/png"}}
      end)

      assert Rindle.LiveView.consume_uploaded_entries(completed_socket, :avatar, fn uploaded_entry, uploaded_meta ->
               {:ok, {uploaded_entry.client_name, uploaded_meta.asset_id}}
             end) == [{"avatar.png", meta.asset_id}]

      replay_socket = put_completed_entry(updated_socket, :avatar, entry, meta)

      assert ["avatar.png"] =
               Rindle.LiveView.consume_uploaded_entries(replay_socket, :avatar, fn uploaded_entry, _uploaded_meta ->
                 {:ok, uploaded_entry.client_name}
               end)
    end
  end

  describe "moduledoc" do
    test "teaches verify_completion/2 as the verification path" do
      {:docs_v1, _, _, _, moduledoc, _, _} = Code.fetch_docs(Rindle.LiveView)
      rendered_doc = extract_doc(moduledoc)

      assert rendered_doc =~ "Rindle.verify_completion/2"
      refute rendered_doc =~ "Rindle.verify_upload/2"
    end

    test "uses meta.asset_id in the consume example" do
      {:docs_v1, _, _, _, moduledoc, _, _} = Code.fetch_docs(Rindle.LiveView)
      rendered_doc = extract_doc(moduledoc)

      assert rendered_doc =~ "{:ok, meta.asset_id}"
      refute rendered_doc =~ "entry.asset_id"
    end
  end

  describe "module availability" do
    test "Rindle.LiveView is defined when phoenix_live_view is loaded" do
      assert Code.ensure_loaded!(Rindle.LiveView) == Rindle.LiveView
    end

    test "allow_upload/4 is exported" do
      assert function_exported?(Rindle.LiveView, :allow_upload, 4)
    end

    test "consume_uploaded_entries/3 is exported" do
      assert function_exported?(Rindle.LiveView, :consume_uploaded_entries, 3)
    end
  end

  defp completed_socket_fixture do
    socket = build_socket()
    updated_socket = socket_with_upload(socket)
    entry = %UploadEntry{client_name: "avatar.png", ref: "avatar-ref"}

    expect(Rindle.StorageMock, :presigned_put, fn _key, _expires_in, _opts ->
      {:ok, %{url: "https://example.com/upload", method: :put, headers: %{}}}
    end)

    {:ok, meta, _socket} = updated_socket.assigns.uploads[:avatar].external.(entry, updated_socket)

    %{
      updated_socket: updated_socket,
      completed_socket: put_completed_entry(updated_socket, :avatar, entry, meta),
      entry: entry,
      meta: meta
    }
  end

  defp socket_with_upload(socket) do
    Rindle.LiveView.allow_upload(socket, :avatar, TestProfile,
      accept: ~w(.jpg .jpeg .png),
      max_entries: 1
    )
  end

  defp put_completed_entry(socket, name, %UploadEntry{} = entry, meta) do
    %UploadConfig{} = conf = socket.assigns.uploads[name]

    completed_entry = %UploadEntry{
      entry
      | done?: true,
        progress: 100,
        upload_config: name,
        upload_ref: conf.ref,
        uuid: "upload-entry-uuid",
        valid?: true
    }

    updated_conf = %UploadConfig{
      conf
      | entries: [completed_entry],
        entry_refs_to_metas: %{completed_entry.ref => meta}
    }

    put_in(socket.assigns.uploads[name], updated_conf)
  end

  defp extract_doc(%{"en" => doc}), do: doc
  defp extract_doc(doc) when is_binary(doc), do: doc
  defp extract_doc(_doc), do: ""
end
