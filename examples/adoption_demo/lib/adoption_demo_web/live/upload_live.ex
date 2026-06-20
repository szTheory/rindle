defmodule AdoptionDemoWeb.UploadLive do
  use AdoptionDemoWeb, :live_view

  import AdoptionDemoWeb.CohortComponents

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
    theme = normalize_theme(params["theme"], "auto")

    socket =
      socket
      |> assign(:page_title, "Upload lab")
      |> assign(:member, member)
      |> assign(:tab, tab)
      |> assign(:theme, theme)
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
    theme = normalize_theme(params["theme"], socket.assigns.theme)

    {:noreply, assign(socket, tab: tab, member: member, theme: theme)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title} nav={:upload}>
      <.ck_page
        eyebrow="Upload lab"
        title="Every Rindle upload path, live."
        lede="Six ingest flows against real MinIO — presigned PUT, tus resume, multipart, LiveView server upload, AV variants, and Mux streaming. Pick a tab to run one end to end; the data is seeded, the uploads are real."
        theme={@theme}
      >
        <div class="ck-toolbar" role="group" aria-label="Upload session">
          <span class="ck-help">
            Acting as
            <strong id="upload-member-name" data-testid="upload-member-name">{@member.name}</strong>
          </span>
          <div class="ck-toolbar__group ck-toolbar__group--actions" role="group" aria-label="Theme">
            <button
              type="button"
              class={["ck-btn", @theme == "light" && "ck-btn--primary"]}
              phx-click="set_theme"
              phx-value-theme="light"
              aria-pressed={to_string(@theme == "light")}
              data-ck-theme="light"
            >
              Light
            </button>
            <button
              type="button"
              class={["ck-btn", @theme == "dark" && "ck-btn--primary"]}
              phx-click="set_theme"
              phx-value-theme="dark"
              aria-pressed={to_string(@theme == "dark")}
              data-ck-theme="dark"
            >
              Dark
            </button>
          </div>
        </div>

        <div class="ck-tabs__list" role="navigation" aria-label="Upload strategy">
          <.tab_link member={@member} tab="image" current={@tab} label="Image (presigned PUT)" />
          <.tab_link member={@member} tab="tus" current={@tab} label="Tus (resumable)" />
          <.tab_link member={@member} tab="video" current={@tab} label="Video (AV variants)" />
          <.tab_link member={@member} tab="multipart" current={@tab} label="Multipart" />
          <.tab_link member={@member} tab="liveview" current={@tab} label="LiveView upload" />
          <.tab_link member={@member} tab="mux" current={@tab} label="Mux streaming" />
        </div>

        <div
          :if={@tab == "image"}
          id="image-upload-panel"
          data-testid="image-upload-panel"
          class={["ck-section ck-reveal", @image_status =~ "uploading" && "ck-dropzone--uploading"]}
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Image — presigned PUT</h2>
            <span class="ck-section__hint">Bytes go straight to storage.</span>
          </div>
          <p class="ck-help">
            The browser PUTs the file to a presigned URL, then Rindle verifies the object
            landed and attaches it as an avatar — your server never buffers the upload.
            This is the default path you'll ship.
          </p>
          <.dropzone input_id="image-file-input" lead="Drop an image or browse" hint="PNG or JPEG">
            <input
              id="image-file-input"
              type="file"
              accept="image/png,image/jpeg"
              phx-hook="PresignedPut"
              class="ck-input ck-dropzone__input"
              data-testid="image-file-input"
            />
            <span class="ck-dropzone__rail" aria-hidden="true"></span>
          </.dropzone>
          <.status_bar id="image-upload-status" testid="image-upload-status" status={@image_status} />
          <div :if={@last_asset_id} class="ck-result ck-reveal">
            <div class="ck-result__head"><.badge variant="ready" label="Attached" /></div>
            <p
              id="image-upload-asset-id"
              class="ck-statusbar__note"
              data-testid="image-upload-asset-id"
            >
              Asset {@last_asset_id}
            </p>
          </div>
        </div>

        <div
          :if={@tab == "tus"}
          id="tus-upload-panel"
          data-testid="tus-upload-panel"
          class="ck-section ck-reveal"
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Tus — resumable</h2>
            <span class="ck-section__hint">Survives a dropped connection.</span>
          </div>
          <p class="ck-help">
            A resumable tus session against MinIO — pause, lose Wi-Fi, resume. Proof that
            large uploads don't have to restart from zero.
          </p>
          <.form for={%{}} id="tus-form" phx-change="tus_changed" phx-submit="save_tus">
            <.dropzone
              input_id="tus-file-input"
              lead="Drop a video or browse"
              hint="Resumable · WebM or MP4"
            >
              <.live_file_input
                upload={@uploads.video}
                class="ck-input ck-dropzone__input"
                data-testid="tus-file-input"
              />
            </.dropzone>
            <button
              type="submit"
              id="tus-submit"
              class="ck-btn ck-btn--primary"
              data-testid="tus-submit"
            >
              Complete tus upload
            </button>
          </.form>
          <.status_bar id="tus-upload-status" testid="tus-upload-status" status={@tus_status} />
          <p
            :if={@tus_error}
            id="tus-upload-error"
            class="ck-error"
            role="alert"
            data-testid="tus-upload-error"
          >
            <svg
              class="ck-icon"
              viewBox="0 0 24 24"
              width="16"
              height="16"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <path d="M10.3 3.7 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.7a2 2 0 0 0-3.4 0Z" />
              <path d="M12 9v4" /><path d="M12 17h.01" />
            </svg>
            <span>{@tus_error}</span>
          </p>
        </div>

        <div
          :if={@tab == "video"}
          id="video-upload-panel"
          data-testid="video-upload-panel"
          class={["ck-section ck-reveal", @video_status =~ "uploading" && "ck-dropzone--uploading"]}
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Video — AV variants</h2>
            <span class="ck-section__hint">Probe, transcode, poster.</span>
          </div>
          <p class="ck-help">
            Upload a clip and watch Rindle derive AV variants — a rendition and an extracted
            poster — as the asset moves Processing → Completed.
          </p>
          <.dropzone input_id="video-file-input" lead="Drop a video or browse" hint="WebM or MP4">
            <input
              id="video-file-input"
              type="file"
              accept="video/webm,video/mp4"
              phx-hook="PresignedVideoPut"
              class="ck-input ck-dropzone__input"
              data-testid="video-file-input"
            />
            <span class="ck-dropzone__rail" aria-hidden="true"></span>
          </.dropzone>
          <.status_bar id="video-upload-status" testid="video-upload-status" status={@video_status} />
        </div>

        <div
          :if={@tab == "multipart"}
          id="multipart-upload-panel"
          data-testid="multipart-upload-panel"
          class="ck-section ck-reveal"
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Multipart — 5 MiB parts</h2>
            <span class="ck-section__hint">Big files, in parts.</span>
          </div>
          <p class="ck-help">
            A multipart upload staged as a 5 MiB part plus a tail part, each signed
            independently and completed atomically — the mechanism behind multi-gigabyte ingest.
          </p>
          <div class="ck-dropzone ck-dropzone--synthetic">
            <span class="ck-dropzone__icon" aria-hidden="true">
              <svg
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                <path d="M7 10l5-5 5 5" /><path d="M12 5v12" />
              </svg>
            </span>
            <span class="ck-dropzone__text">
              <strong class="ck-dropzone__lead">Synthetic payload — no file needed</strong>
              <span class="ck-dropzone__hint">5 MiB part + tail part</span>
            </span>
            <button
              id="multipart-upload-button"
              phx-hook="MultipartUpload"
              class="ck-btn ck-btn--primary"
              data-testid="multipart-upload-button"
            >
              Start multipart upload
            </button>
          </div>
          <.status_bar
            id="multipart-upload-status"
            testid="multipart-upload-status"
            status={@multipart_status}
          />
        </div>

        <div
          :if={@tab == "liveview"}
          id="liveview-upload-panel"
          data-testid="liveview-upload-panel"
          class="ck-section ck-reveal"
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">LiveView — server upload</h2>
            <span class="ck-section__hint">Uploads inside a socket.</span>
          </div>
          <p class="ck-help">
            A Phoenix LiveView upload with live progress over the socket, then attached to a
            fresh community post — no REST endpoint required.
          </p>
          <.form for={%{}} id="liveview-form" phx-change="liveview_changed" phx-submit="save_liveview">
            <.dropzone
              input_id="liveview-file-input"
              lead="Drop an image or browse"
              hint="Server upload over the socket"
            >
              <.live_file_input
                upload={@uploads.post_image}
                class="ck-input ck-dropzone__input"
                data-testid="liveview-file-input"
              />
            </.dropzone>
            <button
              type="submit"
              id="liveview-submit"
              class="ck-btn ck-btn--primary"
              data-testid="liveview-submit"
            >
              Attach to new post
            </button>
          </.form>
          <.status_bar
            id="liveview-upload-status"
            testid="liveview-upload-status"
            status={@liveview_status}
          />
        </div>

        <div
          :if={@tab == "mux"}
          id="mux-upload-panel"
          data-testid="mux-upload-panel"
          class={["ck-section ck-reveal", @mux_status =~ "uploading" && "ck-dropzone--uploading"]}
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Mux — streaming</h2>
            <span class="ck-section__hint">Hand off to a streaming provider.</span>
          </div>
          <p class="ck-help">
            Ingest, then hand the asset to Mux and get back a playable streaming URL — the same
            flow, a different provider profile (a cassette HTTP client stands in for Mux in CI).
          </p>
          <.dropzone input_id="mux-file-input" lead="Drop a video or browse" hint="WebM or MP4">
            <input
              id="mux-file-input"
              type="file"
              accept="video/webm,video/mp4"
              phx-hook="PresignedMuxPut"
              class="ck-input ck-dropzone__input"
              data-testid="mux-file-input"
            />
            <span class="ck-dropzone__rail" aria-hidden="true"></span>
          </.dropzone>
          <.status_bar id="mux-upload-status" testid="mux-upload-status" status={@mux_status} />
          <div :if={@mux_streaming_url} class="ck-result ck-reveal">
            <div class="ck-result__head"><.badge variant="ready" label="Streaming" /></div>
            <p id="mux-streaming-url" class="ck-statusbar__token" data-testid="mux-streaming-url">
              {@mux_streaming_url}
            </p>
          </div>
        </div>
      </.ck_page>
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
      class="ck-tabs__tab ck-tab"
      aria-current={@current == @tab && "page"}
      data-testid={"upload-tab-#{@tab}"}
    >
      {@label}
    </.link>
    """
  end

  # Server-owned theme toggle (mirrors styleguide_live; deterministic for e2e — no
  # localStorage/flash). Pins light/dark for the session; the page otherwise follows
  # the OS via `ck_page` "auto" (no `data-theme`).
  @impl true
  def handle_event("set_theme", %{"theme" => theme}, socket) when theme in ~w(light dark) do
    {:noreply, assign(socket, theme: theme)}
  end

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

    parts =
      Enum.map(etags, fn %{"part_number" => n, "etag" => e} -> %{part_number: n, etag: e} end)

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

           with {:ok, session} <-
                  Broker.initiate_session(RindleProfile, filename: entry.client_name),
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
    status =
      if entry.progress > 0 or entry.done?, do: "uploading", else: socket.assigns.tus_status

    {:noreply, assign(socket, :tus_status, status)}
  end

  defp handle_liveview_progress(:post_image, entry, socket) do
    status =
      if entry.progress > 0 or entry.done?, do: "uploading", else: socket.assigns.liveview_status

    {:noreply, assign(socket, :liveview_status, status)}
  end

  defp put_bytes(url, body, content_type) do
    request = {String.to_charlist(url), [], String.to_charlist(content_type), body}

    case :httpc.request(:put, request, [], []) do
      {:ok, {{_version, status, _reason}, _headers, _body}} when status in 200..299 -> :ok
      other -> {:error, other}
    end
  end

  defp load_member!(nil),
    do: Accounts.list_members() |> List.first() || raise("no seeded members")

  defp load_member!(id), do: Accounts.get_member!(id)

  defp normalize_theme(theme, _default) when theme in ~w(light dark), do: theme
  defp normalize_theme(_theme, default), do: default

  defp ensure_inets do
    case :inets.start() do
      :ok -> :ok
      {:error, {:already_started, :inets}} -> :ok
    end
  end
end
