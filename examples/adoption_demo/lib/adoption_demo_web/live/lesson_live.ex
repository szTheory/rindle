defmodule AdoptionDemoWeb.LessonLive do
  use AdoptionDemoWeb, :live_view

  alias AdoptionDemo.{Cohort, Media, VideoProfile}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    lesson = Cohort.get_lesson!(id)
    attachment = Media.attachment_for(lesson, :video)
    asset = Media.asset_for_attachment(attachment)
    variants = if asset, do: Media.variants_for(asset.id), else: []

    streaming =
      if asset do
        case Media.streaming_url(VideoProfile, asset) do
          {:ok, url} when is_binary(url) -> url
          {:ok, %{url: url}} when is_binary(url) -> url
          _ -> nil
        end
      end

    {:ok,
     assign(socket,
       page_title: lesson.title,
       lesson: lesson,
       asset: asset,
       variants: variants,
       streaming_url: streaming
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <h1 class="text-2xl font-semibold" data-testid="lesson-title">{@lesson.title}</h1>
      <p class="text-sm opacity-80">Course: {@lesson.course.title}</p>

      <section id="lesson-video" class="mt-6" data-testid="lesson-video-section">
        <h2 class="text-lg font-semibold">Lesson video</h2>
        <%= if @asset do %>
          <div id="lesson-video-tag" data-testid="lesson-video-tag">
            {Rindle.HTML.video_tag(VideoProfile, @asset,
              variants: [{:web_720p, nil}],
              poster: :poster,
              controls: true,
              class: "max-w-xl"
            )}
          </div>
          <p id="lesson-asset-state" class="text-sm mt-2" data-testid="lesson-asset-state">
            Asset {@asset.id} — {@asset.state}
          </p>
          <p :if={@streaming_url} id="lesson-streaming-url" class="text-xs break-all mt-2" data-testid="lesson-streaming-url">
            Streaming: {@streaming_url}
          </p>
        <% else %>
          <p data-testid="lesson-no-video">No lesson video attached.</p>
        <% end %>
      </section>

      <section id="lesson-variants" class="mt-6" data-testid="lesson-variants">
        <h2 class="text-lg font-semibold">Variants</h2>
        <ul class="list-disc pl-5">
          <li :for={variant <- @variants} id={"variant-#{variant.name}"} data-testid={"variant-#{variant.name}"}>
            {variant.name} — {variant.state}
          </li>
        </ul>
      </section>
    </Layouts.app>
    """
  end
end
