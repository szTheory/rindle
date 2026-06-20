defmodule AdoptionDemoWeb.PostLive do
  use AdoptionDemoWeb, :live_view

  import AdoptionDemoWeb.CohortComponents

  alias AdoptionDemo.{Cohort, Media, RindleProfile}

  @impl true
  def mount(%{"id" => id} = params, _session, socket) do
    post = Cohort.get_post!(id)
    attachment = Media.attachment_for(post, :image)
    asset = Media.asset_for_attachment(attachment)

    {:ok,
     assign(socket,
       page_title: post.title,
       theme: AdoptionDemoWeb.CohortTheme.normalize(params["theme"], "auto"),
       post: post,
       asset: asset
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <.ck_page eyebrow="Community post" title={@post.title} theme={@theme}>
        <p class="ck-hero__lede" data-testid="post-title">{@post.title} · by {@post.member.name}</p>
        <p class="ck-help">{@post.body}</p>

        <section
          id="post-image"
          class="ck-section ck-reveal"
          data-testid="post-image-section"
          style="--d:.06s"
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Post image</h2>
            <span class="ck-section__hint">A LiveView-uploaded image attached to this post.</span>
          </div>
          <%= if @asset do %>
            <div data-testid="post-picture-tag">
              {Rindle.HTML.picture_tag(RindleProfile, @asset,
                variants: [{:thumb, nil}],
                alt: @post.title,
                class: "ck-result__thumb"
              )}
            </div>
          <% else %>
            <div data-testid="post-no-image" class="ck-empty">
              <p class="ck-empty__title">No image attached</p>
              <p class="ck-empty__body">Attach one from the upload lab's LiveView tab.</p>
            </div>
          <% end %>
        </section>
      </.ck_page>
    </Layouts.app>
    """
  end
end
