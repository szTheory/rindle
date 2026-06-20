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
      <.ck_page eyebrow="Lesson" title={@lesson.title} theme={@theme}>
        <p class="ck-hero__lede" data-testid="lesson-title">
          {@lesson.title} · {@lesson.course.title}
        </p>

        <section
          id="lesson-video"
          class="ck-section ck-reveal"
          data-testid="lesson-video-section"
          style="--d:.06s"
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Lesson video</h2>
            <span class="ck-section__hint">
              The attached video asset, its state, and streaming URL.
            </span>
          </div>
          <%= if @asset do %>
            <div id="lesson-video-tag" data-testid="lesson-video-tag">
              {Rindle.HTML.video_tag(VideoProfile, @asset,
                variants: [{:web_720p, nil}],
                poster: :poster,
                controls: true,
                class: "ck-result__thumb"
              )}
            </div>
            <p id="lesson-asset-state" data-testid="lesson-asset-state" class="ck-statusbar">
              <.state_badge state={@asset.state} />
              <span class="ck-statusbar__token">Asset {@asset.id}</span>
            </p>
            <p
              :if={@streaming_url}
              id="lesson-streaming-url"
              class="ck-output"
              data-testid="lesson-streaming-url"
            >
              Streaming: {@streaming_url}
            </p>
          <% else %>
            <div data-testid="lesson-no-video" class="ck-empty">
              <p class="ck-empty__title">No lesson video attached</p>
              <p class="ck-empty__body">Attach one from the upload lab's video tab.</p>
            </div>
          <% end %>
        </section>

        <section
          id="lesson-variants"
          class="ck-section ck-reveal"
          data-testid="lesson-variants"
          style="--d:.12s"
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Variants</h2>
            <span class="ck-section__hint">Derived renditions and their lifecycle state.</span>
          </div>
          <.ck_table
            rows={@variants}
            row_id={fn v -> "variant-#{v.name}" end}
            row_attrs={fn v -> %{"data-testid" => "variant-#{v.name}"} end}
            empty_title="No variants yet"
            empty_body="Variants appear here as processing completes."
          >
            <:col :let={v} label="Variant"><strong>{v.name}</strong></:col>
            <:col :let={v} label="State"><.state_badge state={v.state} /></:col>
          </.ck_table>
        </section>
      </.ck_page>
    </Layouts.app>
    """
  end
end
