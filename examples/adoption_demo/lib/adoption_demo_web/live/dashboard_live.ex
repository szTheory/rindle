defmodule AdoptionDemoWeb.DashboardLive do
  use AdoptionDemoWeb, :live_view

  alias AdoptionDemo.{Accounts, Media}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Adoption demo",
       users: Accounts.list_users(),
       assets: Media.list_assets()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <h1 class="text-2xl font-semibold">Rindle adoption demo</h1>
      <p class="text-sm opacity-80">
        Minimal SaaS-shaped host for browser E2E and manual journey checks. Storage: MinIO via
        <code>Rindle.Storage.S3</code>.
      </p>

      <section id="demo-users">
        <h2 class="text-lg font-semibold mt-6">Seeded users</h2>
        <ul class="list-disc pl-5 space-y-2">
          <li :for={user <- @users} id={"user-#{user.id}"}>
            <strong>{user.name}</strong> ({user.email})
            — avatar: <%= if attachment = Media.attachment_for(user, :avatar) do %>
              <.link navigate={~p"/media/#{attachment.asset_id}"}>attached</.link>
            <% else %>
              <span id={"user-#{user.id}-no-avatar"}>none</span>
            <% end %>
            · <.link navigate={~p"/upload?user_id=#{user.id}"}>upload</.link>
          </li>
        </ul>
      </section>

      <section id="demo-assets">
        <h2 class="text-lg font-semibold mt-6">Recent assets</h2>
        <ul class="list-disc pl-5">
          <li :for={asset <- @assets}>
            <.link navigate={~p"/media/#{asset.id}"}>{asset.id}</.link>
            — {asset.state} ({asset.content_type || "unknown"})
          </li>
        </ul>
      </section>

      <nav class="flex gap-4 mt-8 text-sm">
        <.link navigate={~p"/upload"} class="underline">Upload lab</.link>
        <.link navigate={~p"/ops"} class="underline">Ops surfaces</.link>
      </nav>
    </Layouts.app>
    """
  end
end
