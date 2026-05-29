defmodule AdoptionDemoWeb.UploadLive do
  use AdoptionDemoWeb, :live_view

  alias AdoptionDemo.{Accounts, Media, RindleProfile, VideoProfile}
  alias Rindle.Upload.Broker

  @secret_key_base Application.compile_env!(:adoption_demo, AdoptionDemoWeb.Endpoint)[
                     :secret_key_base
                   ]

  @impl true
  def mount(params, _session, socket) do
    :ok = ensure_inets()
    user = load_user!(params["user_id"])
    tab = params["tab"] || "image"

    socket =
      socket
      |> assign(:page_title, "Upload lab")
      |> assign(:user, user)
      |> assign(:tab, tab)
      |> assign(:image_status, "idle")
      |> assign(:tus_status, "idle")
      |> assign(:tus_error, nil)
      |> assign(:video_status, "idle")
      |> assign(:last_asset_id, nil)
      |> allow_tus()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = params["tab"] || socket.assigns.tab
    user = load_user!(params["user_id"] || socket.assigns.user.id)

    {:noreply, assign(socket, tab: tab, user: user)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <h1 class="text-2xl font-semibold">Upload lab</h1>
      <p class="text-sm">User: <strong id="upload-user-name">{@user.name}</strong></p>

      <div class="tabs tabs-boxed mt-4">
        <.link patch={~p"/upload?user_id=#{@user.id}&tab=image"} class={tab_class(@tab, "image")}>
          Image presigned PUT
        </.link>
        <.link patch={~p"/upload?user_id=#{@user.id}&tab=tus"} class={tab_class(@tab, "tus")}>
          Tus resume
        </.link>
        <.link patch={~p"/upload?user_id=#{@user.id}&tab=video"} class={tab_class(@tab, "video")}>
          Video AV
        </.link>
      </div>

      <div :if={@tab == "image"} id="image-upload-panel" class="mt-6 space-y-3">
        <p class="text-sm">Browser PUT to presigned URL, then attach as avatar.</p>
        <p id="image-upload-status" class="font-mono text-sm">{@image_status}</p>
        <input
          id="image-file-input"
          type="file"
          accept="image/png,image/jpeg"
          phx-hook="PresignedPut"
          data-testid="image-file-input"
        />
        <p :if={@last_asset_id} id="image-upload-asset-id">Asset {@last_asset_id}</p>
      </div>

      <div :if={@tab == "tus"} id="tus-upload-panel" class="mt-6 space-y-3">
        <p class="text-sm">LiveView tus helper against MinIO (small demo clip).</p>
        <p id="tus-upload-status" class="font-mono text-sm">{@tus_status}</p>
        <p :if={@tus_error} id="tus-upload-error" class="text-red-600 text-sm">{@tus_error}</p>
        <.form for={%{}} id="tus-form" phx-change="tus_changed" phx-submit="save_tus">
          <.live_file_input upload={@uploads.video} />
          <button type="submit" id="tus-submit">Submit tus upload</button>
        </.form>
      </div>

      <div :if={@tab == "video"} id="video-upload-panel" class="mt-6 space-y-3">
        <p class="text-sm">Server-side initiate + presigned PUT for AV profile (demo clip).</p>
        <button id="video-upload-button" phx-click="upload_video" class="btn">Upload demo video</button>
        <p id="video-upload-status" class="font-mono text-sm">{@video_status}</p>
      </div>
    </Layouts.app>
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
  def handle_event("upload_failed", %{"message" => message}, socket) do
    {:noreply, assign(socket, :image_status, "error: #{message}")}
  end

  @impl true
  def handle_event("verify", %{"session_id" => session_id}, socket) do
    user = socket.assigns.user

    with {:ok, %{asset: asset}} <- Broker.verify_completion(session_id),
         {:ok, _attachment} <- safe_attach(user, asset.id) do
      {:noreply,
       socket
       |> assign(:image_status, "ready")
       |> assign(:last_asset_id, asset.id)
       |> put_flash(:info, "Avatar attached")}
    else
      {:error, reason} ->
        {:noreply, assign(socket, :image_status, "error: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("tus_changed", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save_tus", _params, socket) do
    socket = assign(socket, :tus_status, "verifying")

    case Rindle.LiveView.consume_uploaded_entries(socket, :video, fn _entry, meta ->
           {:ok, meta.asset_id}
         end) do
      [{:error, {:rindle_verify_failed, reason}}] ->
        {:noreply,
         socket
         |> assign(:tus_status, "error")
         |> assign(:tus_error, inspect(reason))}

      [asset_id | _] ->
        user = socket.assigns.user

        case safe_attach(user, asset_id) do
          {:ok, _} ->
            {:noreply,
             socket
             |> assign(:tus_status, "ready")
             |> assign(:tus_error, nil)
             |> assign(:last_asset_id, asset_id)
             |> put_flash(:info, "Tus upload attached")}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:tus_status, "error")
             |> assign(:tus_error, inspect(reason))}
        end

      [] ->
        {:noreply,
         socket
         |> assign(:tus_status, "error")
         |> assign(:tus_error, "no completed tus upload entries")}
    end
  end

  @impl true
  def handle_event("upload_video", _params, socket) do
    fixture = Path.join(:code.priv_dir(:adoption_demo), "fixtures/demo-video.webm")

    socket = assign(socket, :video_status, "uploading")

    with {:ok, session} <- Rindle.initiate_upload(VideoProfile, filename: "demo-video.webm"),
         {:ok, %{presigned: presigned}} <- Broker.sign_url(session.id),
         :ok <- put_bytes(presigned.url, File.read!(fixture)),
         {:ok, %{asset: asset}} <- Rindle.verify_completion(session.id),
         {:ok, _} <- safe_attach(socket.assigns.user, asset.id) do
      {:noreply,
       socket
       |> assign(:video_status, "ready")
       |> assign(:last_asset_id, asset.id)
       |> put_flash(:info, "Video uploaded")}
    else
      {:error, reason} ->
        {:noreply, assign(socket, :video_status, "error: #{inspect(reason)}")}
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

  defp handle_tus_progress(:video, entry, socket) do
    status = if entry.progress > 0 or entry.done?, do: "uploading", else: socket.assigns.tus_status
    {:noreply, assign(socket, :tus_status, status)}
  end

  defp safe_attach(user, asset_id) do
    try do
      {:ok, Media.attach!(user, asset_id, :avatar)}
    rescue
      error in Rindle.Error -> {:error, error}
    end
  end

  defp put_bytes(url, body) do
    request = {String.to_charlist(url), [], ~c"application/octet-stream", body}

    case :httpc.request(:put, request, [], []) do
      {:ok, {{_version, status, _reason}, _headers, _body}} when status in 200..299 ->
        :ok

      other ->
        {:error, other}
    end
  end

  defp load_user!(nil), do: Accounts.list_users() |> List.first() || raise "no seeded users"
  defp load_user!(id), do: Accounts.get_user!(id)

  defp tab_class(current, tab) do
    base = "tab px-3 py-1 rounded"
    if current == tab, do: base <> " bg-gray-200", else: base
  end

  defp ensure_inets do
    case :inets.start() do
      :ok -> :ok
      {:error, {:already_started, :inets}} -> :ok
    end
  end
end
