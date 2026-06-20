defmodule AdoptionDemoWeb.MemberLive do
  use AdoptionDemoWeb, :live_view

  import AdoptionDemoWeb.CohortComponents

  alias AdoptionDemo.{Accounts, Media, RindleProfile}

  @impl true
  def mount(%{"id" => id} = params, _session, socket) do
    member = Accounts.get_member!(id)
    attachment = Media.attachment_for(member, :avatar)
    asset = Media.asset_for_attachment(attachment)

    {:ok,
     assign(socket,
       page_title: member.name,
       theme: AdoptionDemoWeb.CohortTheme.normalize(params["theme"], "auto"),
       member: member,
       attachment: attachment,
       asset: asset,
       replace_status: "idle"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <.ck_page eyebrow="Member" title={@member.name} theme={@theme}>
        <p class="ck-hero__lede" data-testid="member-profile-title">
          {@member.name} · {@member.email} · {@member.role}
        </p>

        <section
          id="member-avatar"
          class="ck-section ck-reveal"
          data-testid="member-avatar-section"
          style="--d:.06s"
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Avatar</h2>
            <span class="ck-section__hint">The attached image asset and its lifecycle state.</span>
          </div>
          <%= if @asset do %>
            <div class="ck-result">
              <div id="member-picture-tag" data-testid="member-picture-tag" class="ck-result__head">
                {Rindle.HTML.picture_tag(RindleProfile, @asset,
                  variants: [{:thumb, nil}],
                  alt: "#{@member.name} avatar",
                  class: "ck-result__thumb"
                )}
              </div>
              <p id="member-avatar-state" data-testid="member-avatar-state" class="ck-statusbar">
                <.state_badge state={@asset.state} />
                <span class="ck-statusbar__token">Asset {@asset.id}</span>
              </p>
            </div>
          <% else %>
            <div id="member-no-avatar" data-testid="member-no-avatar" class="ck-empty">
              <p class="ck-empty__title">No avatar attached</p>
              <p class="ck-empty__body">Upload one from the upload lab, or replace it below.</p>
            </div>
          <% end %>
        </section>

        <section
          id="replace-detach"
          class="ck-section ck-reveal"
          data-testid="replace-detach-section"
          style="--d:.12s"
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Replace / detach</h2>
            <span class="ck-section__hint">Swap the avatar with a fresh upload, or remove it.</span>
          </div>
          <p id="replace-status" class="ck-output" data-testid="replace-status">{@replace_status}</p>
          <div class="ck-toolbar" role="group" aria-label="Avatar actions">
            <button
              id="replace-avatar-button"
              phx-click="replace_avatar"
              class="ck-btn ck-btn--primary"
              data-testid="replace-avatar-button"
            >
              Upload new avatar
            </button>
            <button
              id="detach-avatar-button"
              phx-click="detach_avatar"
              class="ck-btn"
              data-testid="detach-avatar-button"
            >
              Remove avatar
            </button>
          </div>
        </section>
      </.ck_page>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("replace_avatar", _params, socket) do
    member = socket.assigns.member
    png = File.read!(fixture_path("avatar.png"))

    with {:ok, session} <-
           Rindle.Upload.Broker.initiate_session(RindleProfile, filename: "replacement.png"),
         {:ok, %{presigned: presigned}} <- Rindle.Upload.Broker.sign_url(session.id),
         :ok <- put_bytes(presigned.url, png),
         {:ok, %{asset: asset}} <- Rindle.Upload.Broker.verify_completion(session.id),
         {:ok, _} <- safe_attach(member, asset.id) do
      {:noreply,
       socket
       |> assign(:replace_status, "replaced:#{asset.id}")
       |> assign(:asset, asset)}
    else
      {:error, reason} -> {:noreply, assign(socket, :replace_status, "error:#{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("detach_avatar", _params, socket) do
    member = socket.assigns.member

    try do
      Media.detach!(member, :avatar)
      {:noreply, socket |> assign(:replace_status, "detached") |> assign(:asset, nil)}
    rescue
      error in Rindle.Error ->
        {:noreply, assign(socket, :replace_status, "error:#{inspect(error)}")}
    end
  end

  defp safe_attach(member, asset_id) do
    try do
      {:ok, Media.attach!(member, asset_id, :avatar)}
    rescue
      error in Rindle.Error -> {:error, error}
    end
  end

  defp put_bytes(url, body) do
    request = {String.to_charlist(url), [], ~c"image/png", body}

    case :httpc.request(:put, request, [], []) do
      {:ok, {{_version, status, _reason}, _headers, _body}} when status in 200..299 -> :ok
      other -> {:error, other}
    end
  end

  defp fixture_path(name) do
    Path.join([:code.priv_dir(:adoption_demo), "fixtures", name])
  end
end
