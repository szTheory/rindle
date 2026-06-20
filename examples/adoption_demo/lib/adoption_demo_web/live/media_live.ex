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
      <.ck_page eyebrow="Asset" title="Media detail" theme={@theme}>
        <dl class="ck-detail ck-reveal" style="--d:.06s">
          <div class="ck-detail__row">
            <dt class="ck-detail__term">ID</dt>
            <dd class="ck-detail__desc" id="media-id" data-testid="media-id">{@asset.id}</dd>
          </div>
          <div class="ck-detail__row">
            <dt class="ck-detail__term">State</dt>
            <dd class="ck-detail__desc" id="media-state" data-testid="media-state">
              <.state_badge state={@asset.state} />
            </dd>
          </div>
          <div class="ck-detail__row">
            <dt class="ck-detail__term">Delivery</dt>
            <dd
              class="ck-detail__desc ck-output"
              id="media-delivery-url"
              data-testid="media-delivery-url"
            >
              {@delivery_url}
            </dd>
          </div>
        </dl>

        <section
          id="media-variants"
          class="ck-section ck-reveal"
          data-testid="media-variants"
          style="--d:.12s"
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Variants</h2>
            <span class="ck-section__hint">Derived renditions and their lifecycle state.</span>
          </div>
          <.ck_table
            rows={@variants}
            row_id={fn v -> "variant-#{v.name}" end}
            empty_title="No variants yet"
            empty_body="Variants appear here as processing completes."
          >
            <:col :let={v} label="Variant"><strong>{v.name}</strong></:col>
            <:col :let={v} label="State"><.state_badge state={v.state} /></:col>
          </.ck_table>
        </section>

        <div class="ck-toolbar ck-reveal" role="group" aria-label="Actions" style="--d:.16s">
          <.link
            navigate={~p"/members/#{alex_id(@members)}"}
            class="ck-btn"
            data-testid="media-alex-profile-link"
          >
            Open Alex profile to replace or detach
          </.link>
        </div>
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
