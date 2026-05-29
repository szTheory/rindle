defmodule AdoptionDemoWeb.MediaLive do
  use AdoptionDemoWeb, :live_view

  alias AdoptionDemo.{Accounts, Media, RindleProfile}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    asset = Media.get_asset!(id)
    variants = Media.variants_for(asset.id)
    {:ok, delivery} = Media.delivery_url(RindleProfile, asset.storage_key)

    {:ok,
     assign(socket,
       page_title: "Media #{asset.id}",
       asset: asset,
       variants: variants,
       delivery_url: delivery,
       members: Accounts.list_members(),
       replace_status: "idle"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <h1 class="text-2xl font-semibold">Media detail</h1>
      <dl class="text-sm space-y-1 mt-4">
        <div><dt class="inline font-semibold">ID:</dt> <dd class="inline" id="media-id" data-testid="media-id">{@asset.id}</dd></div>
        <div><dt class="inline font-semibold">State:</dt> <dd class="inline" id="media-state" data-testid="media-state">{@asset.state}</dd></div>
        <div><dt class="inline font-semibold">Delivery:</dt> <dd class="inline break-all" id="media-delivery-url" data-testid="media-delivery-url">{@delivery_url}</dd></div>
      </dl>

      <section id="media-variants" class="mt-6" data-testid="media-variants">
        <h2 class="text-lg font-semibold">Variants</h2>
        <ul class="list-disc pl-5">
          <li :for={variant <- @variants} id={"variant-#{variant.name}"}>
            {variant.name} — {variant.state}
          </li>
        </ul>
      </section>

      <section class="mt-8">
        <.link navigate={~p"/members/#{alex_id(@members)}"} class="underline" data-testid="media-alex-profile-link">
          Open Alex profile for replace/detach
        </.link>
      </section>
    </Layouts.app>
    """
  end

  defp alex_id(members) do
    members
    |> Enum.find(%{id: "missing"}, &(&1.email == "alex@cohort.test"))
    |> Map.fetch!(:id)
  end
end
