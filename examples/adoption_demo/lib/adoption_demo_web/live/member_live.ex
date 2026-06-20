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
      <.ck_page title="Member" theme={@theme}>
        <h1 class="ck-hero__title" data-testid="member-profile-title">{@member.name}</h1>
        <p class="ck-hero__lede">{@member.email} · {@member.role}</p>

        <section id="member-avatar" class="ck-section" data-testid="member-avatar-section">
          <div class="ck-section__head">
            <h2 class="ck-section__title">Avatar</h2>
          </div>
          <%= if @asset do %>
            <div id="member-picture-tag" data-testid="member-picture-tag">
              {Rindle.HTML.picture_tag(RindleProfile, @asset,
                variants: [{:thumb, nil}],
                alt: "#{@member.name} avatar",
                class: "max-w-xs border"
              )}
            </div>
            <p id="member-avatar-state" data-testid="member-avatar-state">
              Asset {@asset.id} — {@asset.state}
            </p>
          <% else %>
            <p id="member-no-avatar" data-testid="member-no-avatar">No avatar attached.</p>
          <% end %>
        </section>

        <section id="replace-detach" class="ck-section" data-testid="replace-detach-section">
          <div class="ck-section__head">
            <h2 class="ck-section__title">Replace / detach</h2>
          </div>
          <p id="replace-status" class="ck-output" data-testid="replace-status">{@replace_status}</p>
          <div class="ck-toolbar">
            <button id="replace-avatar-button" phx-click="replace_avatar" class="ck-btn ck-btn--primary" data-testid="replace-avatar-button">
              Replace avatar
            </button>
            <button id="detach-avatar-button" phx-click="detach_avatar" class="ck-btn" data-testid="detach-avatar-button">
              Detach avatar
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

    with {:ok, session} <- Rindle.Upload.Broker.initiate_session(RindleProfile, filename: "replacement.png"),
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
