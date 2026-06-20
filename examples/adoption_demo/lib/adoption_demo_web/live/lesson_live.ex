defmodule AdoptionDemoWeb.LessonLive do
  use AdoptionDemoWeb, :live_view

  import AdoptionDemoWeb.CohortComponents

  alias AdoptionDemo.{Cohort, Media, VideoProfile}

  @impl true
  def mount(%{"id" => id} = params, _session, socket) do
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
       theme: AdoptionDemoWeb.CohortTheme.normalize(params["theme"], "auto"),
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
      <.ck_page title="Lesson" theme={@theme}>
        <h1 class="ck-hero__title" data-testid="lesson-title">{@lesson.title}</h1>
        <p class="ck-hero__lede">Course: {@lesson.course.title}</p>

        <section id="lesson-video" class="ck-section" data-testid="lesson-video-section">
          <div class="ck-section__head">
            <h2 class="ck-section__title">Lesson video</h2>
          </div>
          <%= if @asset do %>
            <div id="lesson-video-tag" data-testid="lesson-video-tag">
              {Rindle.HTML.video_tag(VideoProfile, @asset,
                variants: [{:web_720p, nil}],
                poster: :poster,
                controls: true,
                class: "max-w-xl"
              )}
            </div>
            <p id="lesson-asset-state" data-testid="lesson-asset-state">
              Asset {@asset.id} — {@asset.state}
            </p>
            <p :if={@streaming_url} id="lesson-streaming-url" class="ck-output" data-testid="lesson-streaming-url">
              Streaming: {@streaming_url}
            </p>
          <% else %>
            <p data-testid="lesson-no-video">No lesson video attached.</p>
          <% end %>
        </section>

        <section id="lesson-variants" class="ck-section" data-testid="lesson-variants">
          <div class="ck-section__head">
            <h2 class="ck-section__title">Variants</h2>
          </div>
          <ul>
            <li :for={variant <- @variants} id={"variant-#{variant.name}"} data-testid={"variant-#{variant.name}"}>
              {variant.name} — {variant.state}
            </li>
          </ul>
        </section>
      </.ck_page>
    </Layouts.app>
    """
  end
end
