defmodule AdoptionDemoWeb.DashboardLive do
  use AdoptionDemoWeb, :live_view

  import AdoptionDemoWeb.CohortComponents

  alias AdoptionDemo.{Accounts, Cohort, Media}
  alias AdoptionDemoWeb.CohortTheme

  @impl true
  def mount(params, _session, socket) do
    theme = CohortTheme.normalize(params["theme"], "auto")

    {:ok,
     assign(socket,
       page_title: "Dashboard",
       theme: theme,
       members: Accounts.list_members(),
       courses: Cohort.list_courses(),
       posts: Cohort.list_posts(),
       assets: Media.list_assets()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title} nav={:app}>
      <.ck_page eyebrow="Adoption demo" title="Cohort" theme={@theme}>
        <p class="ck-hero__lede" data-testid="cohort-dashboard-title">
          A course-and-community SaaS, wired to Rindle as proof you can adopt it for real. Storage runs on
          <code>Rindle.Storage.S3</code>
          against MinIO; every record below is seeded.
        </p>

        <section
          id="demo-members"
          data-testid="demo-members"
          class="ck-section ck-reveal"
          style="--d:.06s"
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Members</h2>
            <span class="ck-section__hint">The seeded cast — open one to manage its avatar.</span>
          </div>
          <.ck_table
            rows={@members}
            row_id={fn m -> "member-#{m.id}" end}
            row_attrs={fn m -> %{"data-testid" => "member-row-#{m.email}"} end}
            empty_title="No members seeded"
            empty_body="Seed the demo data to populate the cast."
          >
            <:col :let={m} label="Name"><strong>{m.name}</strong></:col>
            <:col :let={m} label="Email">{m.email}</:col>
            <:col :let={m} label="Role">{m.role}</:col>
            <:col :let={m} label="Avatar">
              <.link
                :if={Media.attachment_for(m, :avatar)}
                navigate={~p"/members/#{m.id}"}
                data-testid="member-avatar-link"
              >
                Attached
              </.link>
              <span
                :if={!Media.attachment_for(m, :avatar)}
                data-testid="member-no-avatar"
                class="ck-help"
              >
                None
              </span>
            </:col>
            <:col :let={m} label="Actions">
              <.link navigate={~p"/upload?member_id=#{m.id}"} data-testid="member-upload-link">
                Upload
              </.link>
              ·
              <.link navigate={~p"/account/#{m.id}/delete"} data-testid="member-delete-link">
                Delete
              </.link>
            </:col>
          </.ck_table>
        </section>

        <section
          id="demo-courses"
          data-testid="demo-courses"
          class="ck-section ck-reveal"
          style="--d:.1s"
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Courses</h2>
            <span class="ck-section__hint">Lessons carry the seeded video assets.</span>
          </div>
          <.ck_table
            rows={Enum.flat_map(@courses, fn c -> Enum.map(c.lessons, &{c, &1}) end)}
            empty_title="No lessons yet"
            empty_body="Seed a course with lessons to populate this view."
          >
            <:col :let={{course, _lesson}} label="Course"><strong>{course.title}</strong></:col>
            <:col :let={{_course, lesson}} label="Lesson">
              <.link navigate={~p"/lessons/#{lesson.id}"} data-testid={"lesson-link-#{lesson.id}"}>
                {lesson.title}
              </.link>
            </:col>
          </.ck_table>
        </section>

        <section
          id="demo-posts"
          data-testid="demo-posts"
          class="ck-section ck-reveal"
          style="--d:.14s"
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Community posts</h2>
            <span class="ck-section__hint">Each post can carry a LiveView-uploaded image.</span>
          </div>
          <.ck_table
            rows={@posts}
            empty_title="No posts yet"
            empty_body="Seed community posts to populate this view."
          >
            <:col :let={post} label="Title">
              <.link navigate={~p"/posts/#{post.id}"} data-testid={"post-link-#{post.id}"}>
                {post.title}
              </.link>
            </:col>
            <:col :let={post} label="Author">{post.member.name}</:col>
          </.ck_table>
        </section>

        <section
          id="demo-assets"
          data-testid="demo-assets"
          class="ck-section ck-reveal"
          style="--d:.18s"
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Recent assets</h2>
            <span class="ck-section__hint">Lifecycle state across the seeded media set.</span>
          </div>
          <.ck_table
            rows={@assets}
            empty_title="No assets yet"
            empty_body="Run an upload from the lab to create one."
          >
            <:col :let={asset} label="Asset">
              <.link navigate={~p"/media/#{asset.id}"}>{asset.id}</.link>
            </:col>
            <:col :let={asset} label="State"><.state_badge state={asset.state} /></:col>
            <:col :let={asset} label="Type">{asset.content_type || "unknown"}</:col>
          </.ck_table>
        </section>

        <div class="ck-toolbar ck-reveal" role="group" aria-label="Demo navigation" style="--d:.22s">
          <.ck_button href={~p"/upload"} variant="primary" arrow data-testid="nav-upload">
            Upload lab
          </.ck_button>
          <.ck_button href={~p"/ops"} data-testid="nav-ops">Ops surfaces</.ck_button>
        </div>
      </.ck_page>
    </Layouts.app>
    """
  end
end
