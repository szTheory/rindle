defmodule AdoptionDemoWeb.PostLive do
  use AdoptionDemoWeb, :live_view

  import AdoptionDemoWeb.CohortComponents

  alias AdoptionDemo.{Cohort, Media, RindleProfile}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    post = Cohort.get_post!(id)
    attachment = Media.attachment_for(post, :image)
    asset = Media.asset_for_attachment(attachment)

    {:ok,
     assign(socket,
       page_title: post.title,
       theme: "light",
       post: post,
       asset: asset
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <.ck_page title="Post" theme={@theme}>
        <h1 class="ck-hero__title" data-testid="post-title">{@post.title}</h1>
        <p class="ck-hero__lede">By {@post.member.name}</p>
        <p>{@post.body}</p>

        <section id="post-image" class="ck-section" data-testid="post-image-section">
          <div class="ck-section__head">
            <h2 class="ck-section__title">Post image</h2>
          </div>
          <%= if @asset do %>
            <div data-testid="post-picture-tag">
              {Rindle.HTML.picture_tag(RindleProfile, @asset,
                variants: [{:thumb, nil}],
                alt: @post.title,
                class: "max-w-md border"
              )}
            </div>
          <% else %>
            <p data-testid="post-no-image">No image attached.</p>
          <% end %>
        </section>
      </.ck_page>
    </Layouts.app>
    """
  end
end
