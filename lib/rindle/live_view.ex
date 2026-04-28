if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.LiveView do
    @moduledoc """
    LiveView integration helpers for direct-to-storage uploads via Rindle.

    These helpers wrap Phoenix LiveView's upload primitives to configure
    external (direct-to-storage) uploads using Rindle's presigned URL
    generation and post-upload verification pipeline.

    ## Usage

    In your LiveView:

        def mount(_params, _session, socket) do
          {:ok,
           socket
           |> Rindle.LiveView.allow_upload(:avatar, MyApp.AvatarProfile,
                accept: ~w(.jpg .jpeg .png),
                max_entries: 1,
                max_file_size: 10_000_000
              )}
        end

        def handle_event("save", _params, socket) do
          results =
            Rindle.LiveView.consume_uploaded_entries(socket, :avatar, fn entry, _meta ->
              {:ok, entry.asset_id}
            end)

          {:noreply, socket}
        end

    The `:external` option is set automatically — you do not need to provide it.
    """

    alias Phoenix.LiveView.Upload

    @doc """
    Configures an upload on the socket with Rindle's external upload signer.

    Wraps LiveView upload configuration and sets the `:external` option to a
    function that initiates a Rindle upload session and returns a presigned PUT
    URL.

    ## Parameters

      * `socket` - The LiveView socket
      * `name` - The upload name (atom), e.g. `:avatar`
      * `profile` - The Rindle profile module to use for storage/validation
      * `opts` - Options passed through to the LiveView upload configuration
        (for example `:accept`, `:max_entries`, `:max_file_size`). The
        `:external` key is set by Rindle and should not be provided.

    ## Returns

    The updated socket with the upload configured.
    """
    @spec allow_upload(Phoenix.LiveView.Socket.t(), atom(), module(), keyword()) ::
            Phoenix.LiveView.Socket.t()
    def allow_upload(socket, name, profile, opts \\ []) do
      external_fn = fn entry, socket ->
        do_allow_upload(entry, socket, profile)
      end

      merged_opts = Keyword.merge(opts, external: external_fn)
      Upload.allow_upload(socket, name, merged_opts)
    end

    defp do_allow_upload(entry, socket, profile) do
      filename = entry.client_name

      case Rindle.initiate_upload(profile, filename: filename) do
        {:ok, session} ->
          handle_initiate_upload(session, profile, socket)

        {:error, reason} ->
          {:error, reason}
      end
    end

    defp handle_initiate_upload(session, profile, socket) do
      adapter = profile.storage_adapter()

      case adapter.presigned_put(session.upload_key, 3600, []) do
        {:ok, presigned} ->
          meta = %{
            uploader: "Rindle",
            url: presigned.url,
            method: Map.get(presigned, :method, "PUT"),
            headers: Map.get(presigned, :headers, %{}),
            session_id: session.id,
            asset_id: Ecto.UUID.generate()
          }

          {:ok, meta, socket}

        {:error, reason} ->
          {:error, reason}
      end
    end

    @doc """
    Consumes completed upload entries and verifies them through Rindle.

    For each completed entry, calls `Rindle.verify_upload/2` to confirm
    the object landed in storage, then invokes the user-provided function
    with the entry and its metadata.

    ## Parameters

      * `socket` - The LiveView socket
      * `name` - The upload name (atom)
      * `func` - A 2-arity function `fn entry, meta -> result` called for
        each completed entry. The `meta` map includes `:session_id` and
        `:asset_id` from the upload session.

    ## Returns

    A list of results from the user function.
    """
    @spec consume_uploaded_entries(Phoenix.LiveView.Socket.t(), atom(), function()) :: list()
    def consume_uploaded_entries(socket, name, func) when is_function(func, 2) do
      Upload.consume_uploaded_entries(socket, name, fn meta, entry ->
        do_consume(meta, entry, func)
      end)
    end

    defp do_consume(meta, entry, func) do
      session_id = Map.get(meta, "session_id") || Map.get(meta, :session_id)

      if session_id do
        case Rindle.verify_upload(session_id) do
          {:ok, %{asset: _asset}} ->
            func.(entry, meta)

          {:error, reason} ->
            {:error, reason}
        end
      else
        func.(entry, meta)
      end
    end
  end
end
