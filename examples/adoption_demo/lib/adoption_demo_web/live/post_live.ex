defmodule AdoptionDemoWeb.PostLive do
  use AdoptionDemoWeb, :live_view

  alias AdoptionDemo.{Cohort, Media, RindleProfile}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    post = Cohort.get_post!(id)
    attachment = Media.attachment_for(post, :image)
    asset = Media.asset_for_attachment(attachment)

    {:ok,
     assign(socket,
       page_title: post.title,
       post: post,
       asset: asset
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <h1 class="text-2xl font-semibold" data-testid="post-title">{@post.title}</h1>
      <p class="text-sm">By {@post.member.name}</p>
      <p class="mt-4">{@post.body}</p>

      <section id="post-image" class="mt-6" data-testid="post-image-section">
        <h2 class="text-lg font-semibold">Post image</h2>
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
    </Layouts.app>
    """
  end
end
