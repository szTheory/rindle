if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.LiveView do
    @moduledoc """
    LiveView integration helpers for direct-to-storage uploads via Rindle.

    These helpers wrap Phoenix LiveView's upload primitives to configure
    external (direct-to-storage) uploads using Rindle's presigned URL
    generation and the `Rindle.verify_completion/2` post-upload verification
    pipeline.

    ## Usage

    In your LiveView:

        def mount(_params, _session, socket) do
          socket =
            socket
            |> Rindle.LiveView.allow_upload(:avatar, MyApp.AvatarProfile,
                 accept: ~w(.jpg .jpeg .png),
                 max_entries: 1,
                 max_file_size: 10_000_000
               )
            |> assign(:asset_topic, Rindle.LiveView.subscribe(:asset, "asset-id"))

          {:ok, socket}
        end

        def handle_event("save", _params, socket) do
          results =
            Rindle.LiveView.consume_uploaded_entries(socket, :avatar, fn _entry, meta ->
              {:ok, meta.asset_id}
            end)

          {:noreply, assign(socket, :uploaded_asset_ids, results)}
        end

        def handle_info({:rindle_event, type, payload}, socket) do
          case type do
            :variant_started -> {:noreply, assign(socket, :variant_status, payload.state)}
            :variant_progress -> {:noreply, assign(socket, :variant_progress, payload.progress)}
            :variant_ready -> {:noreply, assign(socket, :variant_status, payload.state)}
            :variant_failed -> {:noreply, assign(socket, :variant_error, payload)}
            :variant_cancelled -> {:noreply, assign(socket, :variant_status, payload.state)}
          end
        end

    The `:external` option is set automatically — you do not need to provide it.
    """

    require Logger

    alias Phoenix.PubSub
    alias Phoenix.LiveView.Upload
    alias Rindle.Config
    alias Rindle.Domain.MediaUploadSession
    alias Rindle.Upload.Broker

    @type consume_result :: {:ok, term()} | {:postpone, term()}
    @type consume_func :: (Phoenix.LiveView.UploadEntry.t(), map() -> consume_result())
    @type subscription_scope :: :variant | :asset | :upload_session

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

    @doc """
    Subscribes the current process to a Rindle PubSub topic for a supported scope.

    Supported scopes are `:variant`, `:asset`, and `:upload_session`. The
    returned topic string can be passed back to `unsubscribe/1` later.
    """
    @spec subscribe(subscription_scope(), term()) :: String.t()
    def subscribe(:variant, id), do: subscribe_topic(topic_for(:variant, id))
    def subscribe(:asset, id), do: subscribe_topic(topic_for(:asset, id))
    def subscribe(:upload_session, id), do: subscribe_topic(topic_for(:upload_session, id))

    @doc """
    Unsubscribes the current process from a topic returned by `subscribe/2`.
    """
    @spec unsubscribe(String.t()) :: :ok
    def unsubscribe(topic) when is_binary(topic) do
      PubSub.unsubscribe(pubsub_server(), topic)
    end

    defp do_allow_upload(entry, socket, profile) do
      filename = entry.client_name

      case Rindle.initiate_upload(profile, filename: filename) do
        {:ok, session} ->
          handle_initiate_upload(session, profile, socket)

        {:error, reason} ->
          log_upload_error("initiate", reason)
          {:error, %{reason: "upload_unavailable", code: "upload_init_failed"}, socket}
      end
    end

    defp handle_initiate_upload(session, _profile, socket) do
      case Broker.sign_url(session.id) do
        {:ok, %{session: signed_session, presigned: presigned}} ->
          meta = %{
            uploader: "Rindle",
            url: presigned.url,
            method: Map.get(presigned, :method, "PUT"),
            headers: Map.get(presigned, :headers, %{}),
            session_id: signed_session.id,
            asset_id: signed_session.asset_id
          }

          {:ok, meta, socket}

        {:error, reason} ->
          log_upload_error("sign", reason)
          {:error, %{reason: "upload_unavailable", code: "upload_sign_failed"}, socket}
      end
    end

    @doc """
    Consumes completed upload entries and verifies them through Rindle.

    For each completed entry, calls `Rindle.verify_completion/2` to confirm
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
    @spec consume_uploaded_entries(Phoenix.LiveView.Socket.t(), atom(), consume_func()) :: list()
    def consume_uploaded_entries(socket, name, func) when is_function(func, 2) do
      Upload.consume_uploaded_entries(socket, name, fn meta, entry ->
        do_consume(meta, entry, func)
      end)
    end

    defp do_consume(meta, entry, func) do
      case Map.get(meta, "session_id") || Map.get(meta, :session_id) do
        nil ->
          raise ArgumentError,
                "Rindle.LiveView.consume_uploaded_entries/3 requires :session_id in upload meta. " <>
                  "Got keys: #{inspect(Map.keys(meta))}"

        session_id ->
          if already_completed?(session_id) do
            func.(entry, meta)
          else
            case Rindle.verify_completion(session_id) do
              {:ok, %{asset: _asset}} ->
                func.(entry, meta)

              {:error, reason} ->
                {:postpone, {:error, {:rindle_verify_failed, reason}}}
            end
          end
      end
    end

    defp already_completed?(session_id) do
      case Config.repo().get(MediaUploadSession, session_id) do
        %MediaUploadSession{state: "completed"} -> true
        _ -> false
      end
    end

    defp log_upload_error(stage, reason) do
      Logger.warning("Rindle.LiveView #{stage} upload failed: #{inspect(reason)}")
    end

    defp subscribe_topic(topic) do
      :ok = PubSub.subscribe(pubsub_server(), topic)
      topic
    end

    defp topic_for(:variant, id), do: "rindle:variant:#{id}"
    defp topic_for(:asset, id), do: "rindle:asset:#{id}"
    defp topic_for(:upload_session, id), do: "rindle:upload_session:#{id}"

    defp pubsub_server do
      Application.get_env(:rindle, :pubsub_server, Rindle.PubSub)
    end
  end
end
