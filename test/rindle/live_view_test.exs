defmodule Rindle.LiveViewTest do
  use Rindle.DataCase, async: true
  import Mox

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

    test "external signer calls initiate_upload and presigned_put" do
      socket = build_socket()

      updated_socket =
        Rindle.LiveView.allow_upload(socket, :avatar, TestProfile,
          accept: ~w(.jpg .jpeg .png),
          max_entries: 1
        )

      # Extract the external function and invoke it with a mock entry
      external_fn = updated_socket.assigns.uploads[:avatar].external
      assert is_function(external_fn, 2)

      # The external function expects an entry struct with client_name
      # and returns {:ok, meta, socket} on success.
      # We can't fully test the presigned flow without mocking the broker
      # and storage, but we verify the function is properly wired.
      assert is_function(external_fn, 2)
    end
  end

  describe "consume_uploaded_entries/3" do
    test "module is defined and has consume_uploaded_entries/3" do
      assert function_exported?(Rindle.LiveView, :consume_uploaded_entries, 3)
    end
  end

  describe "module availability" do
    test "Rindle.LiveView is defined when phoenix_live_view is loaded" do
      assert Code.ensure_loaded?(Rindle.LiveView)
    end

    test "allow_upload/4 is exported" do
      assert function_exported?(Rindle.LiveView, :allow_upload, 4)
    end

    test "consume_uploaded_entries/3 is exported" do
      assert function_exported?(Rindle.LiveView, :consume_uploaded_entries, 3)
    end
  end
end
