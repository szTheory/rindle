defmodule AdoptionDemoWeb.UploadLive do
  use AdoptionDemoWeb, :live_view

  alias AdoptionDemo.{Accounts, Cohort, Media, MuxProfile, RindleProfile, VideoProfile}
  alias Rindle.Upload.Broker

  @secret_key_base Application.compile_env!(:adoption_demo, AdoptionDemoWeb.Endpoint)[
                     :secret_key_base
                   ]

  @impl true
  def mount(params, _session, socket) do
    :ok = ensure_inets()
    member = load_member!(params["member_id"] || params["user_id"])
    tab = params["tab"] || "image"

    socket =
      socket
      |> assign(:page_title, "Upload lab")
      |> assign(:member, member)
      |> assign(:tab, tab)
      |> assign(:image_status, "idle")
      |> assign(:tus_status, "idle")
      |> assign(:tus_error, nil)
      |> assign(:video_status, "idle")
      |> assign(:multipart_status, "idle")
      |> assign(:liveview_status, "idle")
      |> assign(:mux_status, "idle")
      |> assign(:mux_streaming_url, nil)
      |> assign(:last_asset_id, nil)
      |> allow_tus()
      |> allow_post_upload()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = params["tab"] || socket.assigns.tab
    member = load_member!(params["member_id"] || params["user_id"] || socket.assigns.member.id)

    {:noreply, assign(socket, tab: tab, member: member)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <h1 class="text-2xl font-semibold">Upload lab</h1>
      <p class="text-sm">
        Member: <strong id="upload-member-name" data-testid="upload-member-name">{@member.name}</strong>
      </p>

      <div class="tabs tabs-boxed mt-4 flex flex-wrap gap-2">
        <.tab_link member={@member} tab="image" current={@tab} label="Image presigned PUT" />
        <.tab_link member={@member} tab="tus" current={@tab} label="Tus resume" />
        <.tab_link member={@member} tab="video" current={@tab} label="Video AV" />
        <.tab_link member={@member} tab="multipart" current={@tab} label="Multipart" />
        <.tab_link member={@member} tab="liveview" current={@tab} label="LiveView upload" />
        <.tab_link member={@member} tab="mux" current={@tab} label="Mux streaming" />
      </div>

      <div :if={@tab == "image"} id="image-upload-panel" class="mt-6 space-y-3" data-testid="image-upload-panel">
        <p class="text-sm">Browser PUT to presigned URL, then attach as avatar.</p>
        <p id="image-upload-status" class="font-mono text-sm" data-testid="image-upload-status">{@image_status}</p>
        <input
          id="image-file-input"
          type="file"
          accept="image/png,image/jpeg"
          phx-hook="PresignedPut"
          data-testid="image-file-input"
        />
        <p :if={@last_asset_id} id="image-upload-asset-id" data-testid="image-upload-asset-id">
          Asset {@last_asset_id}
        </p>
      </div>

      <div :if={@tab == "tus"} id="tus-upload-panel" class="mt-6 space-y-3" data-testid="tus-upload-panel">
        <p class="text-sm">LiveView tus helper against MinIO.</p>
        <p id="tus-upload-status" class="font-mono text-sm" data-testid="tus-upload-status">{@tus_status}</p>
        <p :if={@tus_error} id="tus-upload-error" class="text-red-600 text-sm" data-testid="tus-upload-error">
          {@tus_error}
        </p>
        <.form for={%{}} id="tus-form" phx-change="tus_changed" phx-submit="save_tus">
          <.live_file_input upload={@uploads.video} data-testid="tus-file-input" />
          <button type="submit" id="tus-submit" data-testid="tus-submit">Submit tus upload</button>
        </.form>
      </div>

      <div :if={@tab == "video"} id="video-upload-panel" class="mt-6 space-y-3" data-testid="video-upload-panel">
        <p class="text-sm">Browser file pick → presigned PUT → AV variants.</p>
        <p id="video-upload-status" class="font-mono text-sm" data-testid="video-upload-status">{@video_status}</p>
        <input
          id="video-file-input"
          type="file"
          accept="video/webm,video/mp4"
          phx-hook="PresignedVideoPut"
          data-testid="video-file-input"
        />
      </div>

      <div :if={@tab == "multipart"} id="multipart-upload-panel" class="mt-6 space-y-3" data-testid="multipart-upload-panel">
        <p class="text-sm">Client-side multipart upload (5 MiB + tail part).</p>
        <p id="multipart-upload-status" class="font-mono text-sm" data-testid="multipart-upload-status">
          {@multipart_status}
        </p>
        <button id="multipart-upload-button" phx-hook="MultipartUpload" data-testid="multipart-upload-button" class="btn">
          Run multipart upload
        </button>
      </div>

      <div :if={@tab == "liveview"} id="liveview-upload-panel" class="mt-6 space-y-3" data-testid="liveview-upload-panel">
        <p class="text-sm">Phoenix LiveView upload to server, then attach to a community post.</p>
        <p id="liveview-upload-status" class="font-mono text-sm" data-testid="liveview-upload-status">
          {@liveview_status}
        </p>
        <.form for={%{}} id="liveview-form" phx-change="liveview_changed" phx-submit="save_liveview">
          <.live_file_input upload={@uploads.post_image} data-testid="liveview-file-input" />
          <button type="submit" id="liveview-submit" data-testid="liveview-submit">Attach to new post</button>
        </.form>
      </div>

      <div :if={@tab == "mux"} id="mux-upload-panel" class="mt-6 space-y-3" data-testid="mux-upload-panel">
        <p class="text-sm">MuxWeb profile with cassette HTTP client in test CI.</p>
        <p id="mux-upload-status" class="font-mono text-sm" data-testid="mux-upload-status">{@mux_status}</p>
        <input
          id="mux-file-input"
          type="file"
          accept="video/webm,video/mp4"
          phx-hook="PresignedMuxPut"
          data-testid="mux-file-input"
        />
        <p :if={@mux_streaming_url} id="mux-streaming-url" class="text-xs break-all" data-testid="mux-streaming-url">
          {@mux_streaming_url}
        </p>
      </div>
    </Layouts.app>
    """
  end

  attr :member, :map, required: true
  attr :tab, :string, required: true
  attr :current, :string, required: true
  attr :label, :string, required: true

  defp tab_link(assigns) do
    ~H"""
    <.link
      patch={~p"/upload?member_id=#{@member.id}&tab=#{@tab}"}
      class={tab_class(@current, @tab)}
      data-testid={"upload-tab-#{@tab}"}
    >
      {@label}
    </.link>
    """
  end

  @impl true
  def handle_event("presign", %{"filename" => filename} = params, socket) do
    content_type = Map.get(params, "content_type", "image/png")
    socket = assign(socket, :image_status, "presigning")

    {:ok, session} = Broker.initiate_session(RindleProfile, filename: filename)
    {:ok, %{presigned: presigned}} = Broker.sign_url(session.id)

    {:noreply,
     socket
     |> assign(:image_status, "uploading")
     |> push_event("presigned", %{
       url: presigned.url,
       session_id: session.id,
       content_type: content_type
     })}
  end

  @impl true
  def handle_event("presign_video", %{"filename" => filename} = params, socket) do
    content_type = Map.get(params, "content_type", "video/webm")
    socket = assign(socket, :video_status, "presigning")

    {:ok, session} = Rindle.initiate_upload(VideoProfile, filename: filename)
    {:ok, %{presigned: presigned}} = Broker.sign_url(session.id)

    {:noreply,
     socket
     |> assign(:video_status, "uploading")
     |> push_event("presigned_video", %{
       url: presigned.url,
       session_id: session.id,
       content_type: content_type
     })}
  end

  @impl true
  def handle_event("presign_mux", %{"filename" => filename} = params, socket) do
    content_type = Map.get(params, "content_type", "video/webm")
    socket = assign(socket, :mux_status, "presigning")

    {:ok, session} = Rindle.initiate_upload(MuxProfile, filename: filename)
    {:ok, %{presigned: presigned}} = Broker.sign_url(session.id)

    {:noreply,
     socket
     |> assign(:mux_status, "uploading")
     |> push_event("presigned_mux", %{
       url: presigned.url,
       session_id: session.id,
       content_type: content_type
     })}
  end

  @impl true
  def handle_event("multipart_start", %{"filename" => filename}, socket) do
    socket = assign(socket, :multipart_status, "initiating")

    case Rindle.initiate_multipart_upload(RindleProfile, filename: filename) do
      {:ok, %{session: session}} ->
        {:ok, %{presigned: part1}} = Rindle.sign_multipart_part(session.id, 1)
        {:ok, %{presigned: part2}} = Rindle.sign_multipart_part(session.id, 2)

        {:noreply,
         socket
         |> assign(:multipart_status, "uploading")
         |> push_event("multipart_parts", %{
           session_id: session.id,
           parts: [
             %{part_number: 1, url: part1.url},
             %{part_number: 2, url: part2.url}
           ]
         })}

      {:error, reason} ->
        {:noreply, assign(socket, :multipart_status, "error: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("multipart_complete", %{"session_id" => session_id, "etags" => etags}, socket) do
    member = socket.assigns.member
    parts = Enum.map(etags, fn %{"part_number" => n, "etag" => e} -> %{part_number: n, etag: e} end)

    with {:ok, %{asset: asset}} <- Rindle.complete_multipart_upload(session_id, parts),
         {:ok, _} <- safe_attach(member, asset.id) do
      {:noreply,
       socket
       |> assign(:multipart_status, "ready")
       |> assign(:last_asset_id, asset.id)}
    else
      {:error, reason} ->
        {:noreply, assign(socket, :multipart_status, "error: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("upload_failed", %{"message" => message}, socket) do
    tab = socket.assigns.tab

    status_key =
      case tab do
        "video" -> :video_status
        "mux" -> :mux_status
        _ -> :image_status
      end

    {:noreply, assign(socket, status_key, "error: #{message}")}
  end

  @impl true
  def handle_event("verify", %{"session_id" => session_id}, socket) do
    verify_and_attach(socket, session_id, :image_status, RindleProfile, :avatar)
  end

  @impl true
  def handle_event("verify_video", %{"session_id" => session_id}, socket) do
    verify_and_attach(socket, session_id, :video_status, VideoProfile, :avatar)
  end

  @impl true
  def handle_event("verify_mux", %{"session_id" => session_id}, socket) do
    member = socket.assigns.member

    case Broker.verify_completion(session_id) do
      {:ok, %{asset: asset}} ->
        case safe_attach(member, asset.id) do
          {:ok, _} ->
            try do
              Oban.drain_queue(queue: :rindle_promote, with_safety: false)
              Oban.drain_queue(queue: :rindle_process, with_safety: false)
              Oban.drain_queue(queue: :rindle_media, with_safety: false)
            rescue
              _ -> :ok
            end

            streaming =
              case Media.await_streaming_url(MuxProfile, asset.id, 10) do
                {:ok, url} -> url
                _ -> "mux provider sync pending"
              end

            {:noreply,
             socket
             |> assign(:mux_status, "ready")
             |> assign(:mux_streaming_url, streaming)
             |> assign(:last_asset_id, asset.id)
             |> put_flash(:info, "Mux upload attached")}

          {:error, reason} ->
            {:noreply, assign(socket, :mux_status, "error: #{inspect(reason)}")}
        end

      {:error, reason} ->
        {:noreply, assign(socket, :mux_status, "error: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("tus_changed", _params, socket), do: {:noreply, socket}
  @impl true
  def handle_event("liveview_changed", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("save_tus", _params, socket) do
    socket = assign(socket, :tus_status, "verifying")
    member = socket.assigns.member

    case Rindle.LiveView.consume_uploaded_entries(socket, :video, fn _entry, meta ->
           {:ok, meta.asset_id}
         end) do
      [{:error, {:rindle_verify_failed, reason}}] ->
        {:noreply, socket |> assign(:tus_status, "error") |> assign(:tus_error, inspect(reason))}

      [asset_id | _] ->
        case safe_attach(member, asset_id) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:tus_status, "ready")
             |> assign(:tus_error, nil)
             |> assign(:last_asset_id, asset_id)}

          {:error, reason} ->
            {:noreply,
             socket |> assign(:tus_status, "error") |> assign(:tus_error, inspect(reason))}
        end

      [] ->
        {:noreply,
         socket
         |> assign(:tus_status, "error")
         |> assign(:tus_error, "no completed tus upload entries")}
    end
  end

  @impl true
  def handle_event("save_liveview", _params, socket) do
    socket = assign(socket, :liveview_status, "uploading")
    member = socket.assigns.member

    case Phoenix.LiveView.consume_uploaded_entries(socket, :post_image, fn %{path: path}, entry ->
           body = File.read!(path)

           with {:ok, session} <- Broker.initiate_session(RindleProfile, filename: entry.client_name),
                {:ok, %{presigned: presigned}} <- Broker.sign_url(session.id),
                :ok <- put_bytes(presigned.url, body, entry.client_type || "image/png"),
                {:ok, %{asset: asset}} <- Broker.verify_completion(session.id) do
             {:ok, asset.id}
           end
         end) do
      [asset_id | _] when is_binary(asset_id) ->
        post =
          Cohort.seed_post!(%{
            title: "LiveView upload #{System.unique_integer([:positive])}",
            body: "Attached via LiveView server upload.",
            member_id: member.id
          })

        case safe_attach_post(post, asset_id) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:liveview_status, "ready")
             |> assign(:last_asset_id, asset_id)}

          {:error, reason} ->
            {:noreply, assign(socket, :liveview_status, "error: #{inspect(reason)}")}
        end

      [{:error, reason}] ->
        {:noreply, assign(socket, :liveview_status, "error: #{inspect(reason)}")}

      [] ->
        {:noreply, assign(socket, :liveview_status, "error: no upload entries")}
    end
  end

  defp verify_and_attach(socket, session_id, status_key, _profile, slot) do
    member = socket.assigns.member

    with {:ok, %{asset: asset}} <- Broker.verify_completion(session_id),
         {:ok, _} <- safe_attach(member, asset.id, slot) do
      {:noreply,
       socket
       |> assign(status_key, "ready")
       |> assign(:last_asset_id, asset.id)
       |> put_flash(:info, "Attached")}
    else
      {:error, reason} ->
        {:noreply, assign(socket, status_key, "error: #{inspect(reason)}")}
    end
  end

  defp safe_attach(member, asset_id, slot \\ :avatar) do
    try do
      {:ok, Media.attach!(member, asset_id, slot)}
    rescue
      error in Rindle.Error -> {:error, error}
    end
  end

  defp safe_attach_post(post, asset_id) do
    try do
      {:ok, Media.attach!(post, asset_id, :image)}
    rescue
      error in Rindle.Error -> {:error, error}
    end
  end

  defp allow_tus(socket) do
    Rindle.LiveView.allow_tus_upload(socket, :video, VideoProfile,
      path: "/uploads/tus",
      secret_key_base: @secret_key_base,
      accept: ~w(.webm .mp4),
      max_entries: 1,
      max_file_size: 10_485_760,
      auto_upload: true,
      progress: &handle_tus_progress/3
    )
  end

  defp allow_post_upload(socket) do
    allow_upload(socket, :post_image,
      accept: ~w(.png .jpg .jpeg),
      max_entries: 1,
      max_file_size: 10_485_760,
      auto_upload: true,
      progress: &handle_liveview_progress/3
    )
  end

  defp handle_tus_progress(:video, entry, socket) do
    status = if entry.progress > 0 or entry.done?, do: "uploading", else: socket.assigns.tus_status
    {:noreply, assign(socket, :tus_status, status)}
  end

  defp handle_liveview_progress(:post_image, entry, socket) do
    status = if entry.progress > 0 or entry.done?, do: "uploading", else: socket.assigns.liveview_status
    {:noreply, assign(socket, :liveview_status, status)}
  end

  defp put_bytes(url, body, content_type) do
    request = {String.to_charlist(url), [], String.to_charlist(content_type), body}

    case :httpc.request(:put, request, [], []) do
      {:ok, {{_version, status, _reason}, _headers, _body}} when status in 200..299 -> :ok
      other -> {:error, other}
    end
  end

  defp load_member!(nil), do: Accounts.list_members() |> List.first() || raise "no seeded members"

  defp load_member!(id), do: Accounts.get_member!(id)

  defp tab_class(current, tab) do
    base = "tab px-3 py-1 rounded border"
    if current == tab, do: base <> " bg-gray-200", else: base
  end

  defp ensure_inets do
    case :inets.start() do
      :ok -> :ok
      {:error, {:already_started, :inets}} -> :ok
    end
  end
end
