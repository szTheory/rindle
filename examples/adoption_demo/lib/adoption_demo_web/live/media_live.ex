defmodule AdoptionDemoWeb.MediaLive do
  use AdoptionDemoWeb, :live_view

  import AdoptionDemoWeb.CohortComponents

  alias AdoptionDemo.{Accounts, Media, RindleProfile}

  @impl true
  def mount(%{"id" => id} = params, _session, socket) do
    asset = Media.get_asset!(id)
    variants = Media.variants_for(asset.id)
    {:ok, delivery} = Media.delivery_url(RindleProfile, asset.storage_key)

    {:ok,
     assign(socket,
       page_title: "Media #{asset.id}",
       theme: AdoptionDemoWeb.CohortTheme.normalize(params["theme"], "auto"),
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
      <.ck_page title="Media detail" theme={@theme}>
        <dl class="ck-detail">
          <div class="ck-detail__row">
            <dt class="ck-detail__term">ID:</dt>
            <dd class="ck-detail__desc" id="media-id" data-testid="media-id">{@asset.id}</dd>
          </div>
          <div class="ck-detail__row">
            <dt class="ck-detail__term">State:</dt>
            <dd class="ck-detail__desc" id="media-state" data-testid="media-state">{@asset.state}</dd>
          </div>
          <div class="ck-detail__row">
            <dt class="ck-detail__term">Delivery:</dt>
            <dd
              class="ck-detail__desc ck-output"
              id="media-delivery-url"
              data-testid="media-delivery-url"
            >
              {@delivery_url}
            </dd>
          </div>
        </dl>

        <section id="media-variants" class="ck-section" data-testid="media-variants">
          <div class="ck-section__head">
            <h2 class="ck-section__title">Variants</h2>
          </div>
          <ul>
            <li :for={variant <- @variants} id={"variant-#{variant.name}"}>
              {variant.name} — {variant.state}
            </li>
          </ul>
        </section>

        <section class="ck-section">
          <.link
            navigate={~p"/members/#{alex_id(@members)}"}
            class="ck-btn"
            data-testid="media-alex-profile-link"
          >
            Open Alex profile for replace/detach
          </.link>
        </section>
      </.ck_page>
    </Layouts.app>
    """
  end

  defp alex_id(members) do
    members
    |> Enum.find(%{id: "missing"}, &(&1.email == "alex@cohort.test"))
    |> Map.fetch!(:id)
  end
end
