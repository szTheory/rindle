defmodule AdoptionDemoWeb.MediaLive do
  use AdoptionDemoWeb, :live_view

  alias AdoptionDemo.{Accounts, Media, RindleProfile}
  alias Rindle.Upload.Broker

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    asset = Media.get_asset!(id)
    variants = Media.variants_for(asset.id)
    {:ok, delivery} = Media.delivery_url(asset.storage_key)

    {:ok,
     assign(socket,
       page_title: "Media #{asset.id}",
       asset: asset,
       variants: variants,
       delivery_url: delivery,
       users: Accounts.list_users(),
       replace_status: "idle"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <h1 class="text-2xl font-semibold">Media detail</h1>
      <dl class="text-sm space-y-1 mt-4">
        <div><dt class="inline font-semibold">ID:</dt> <dd class="inline" id="media-id">{@asset.id}</dd></div>
        <div><dt class="inline font-semibold">State:</dt> <dd class="inline" id="media-state">{@asset.state}</dd></div>
        <div><dt class="inline font-semibold">Delivery:</dt> <dd class="inline break-all" id="media-delivery-url">{@delivery_url}</dd></div>
      </dl>

      <section id="media-variants" class="mt-6">
        <h2 class="text-lg font-semibold">Variants</h2>
        <ul class="list-disc pl-5">
          <li :for={variant <- @variants} id={"variant-#{variant.name}"}>
            {variant.name} — {variant.state}
          </li>
        </ul>
      </section>

      <section id="replace-detach" class="mt-8 space-y-3">
        <h2 class="text-lg font-semibold">Replace / detach</h2>
        <p class="text-sm">Attach a fresh avatar for Alice, then detach.</p>
        <p id="replace-status" class="font-mono text-sm">{@replace_status}</p>
        <button id="replace-avatar-button" phx-click="replace_avatar" class="btn">Replace Alice avatar</button>
        <button id="detach-avatar-button" phx-click="detach_avatar" class="btn">Detach Alice avatar</button>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("replace_avatar", _params, socket) do
    alice = Enum.find(socket.assigns.users, &(&1.email == "alice@acme.test")) || hd(socket.assigns.users)
    png = File.read!(fixture_path("avatar.png"))

    with {:ok, session} <- Broker.initiate_session(RindleProfile, filename: "replacement.png"),
         {:ok, %{presigned: presigned}} <- Broker.sign_url(session.id),
         :ok <- put_bytes(presigned.url, png),
         {:ok, %{asset: asset}} <- Broker.verify_completion(session.id),
         {:ok, _} <- safe_attach(alice, asset.id) do
      {:noreply, assign(socket, :replace_status, "replaced:#{asset.id}")}
    else
      {:error, reason} -> {:noreply, assign(socket, :replace_status, "error:#{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("detach_avatar", _params, socket) do
    alice = Enum.find(socket.assigns.users, &(&1.email == "alice@acme.test")) || hd(socket.assigns.users)

    try do
      Media.detach!(alice, :avatar)
      {:noreply, assign(socket, :replace_status, "detached")}
    rescue
      error in Rindle.Error ->
        {:noreply, assign(socket, :replace_status, "error:#{inspect(error)}")}
    end
  end

  defp safe_attach(user, asset_id) do
    try do
      {:ok, Media.attach!(user, asset_id, :avatar)}
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
