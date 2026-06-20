defmodule AdoptionDemoWeb.DashboardLive do
  use AdoptionDemoWeb, :live_view

  import AdoptionDemoWeb.CohortComponents

  alias AdoptionDemo.{Accounts, Cohort, Media}
  alias AdoptionDemoWeb.CohortTheme

  @impl true
  def mount(params, _session, socket) do
    theme = CohortTheme.normalize(params["theme"], "light")

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
      <.ck_page title="Cohort" theme={@theme}>
        <p class="ck-hero__lede" data-testid="cohort-dashboard-title">
          Course-and-community SaaS demo for Rindle adoption proof. Storage:
          <code>Rindle.Storage.S3</code>
          on MinIO.
        </p>

        <section id="demo-members" data-testid="demo-members" class="ck-section">
          <div class="ck-section__head">
            <h2 class="ck-section__title">Members</h2>
          </div>
          <ul>
            <li
              :for={member <- @members}
              id={"member-#{member.id}"}
              data-testid={"member-row-#{member.email}"}
            >
              <strong>{member.name}</strong>
              ({member.email}, {member.role})
              — avatar:
              <%= if Media.attachment_for(member, :avatar) do %>
                <.link navigate={~p"/members/#{member.id}"} data-testid="member-avatar-link">
                  attached
                </.link>
              <% else %>
                <span data-testid="member-no-avatar">none</span>
              <% end %>
              ·
              <.link navigate={~p"/upload?member_id=#{member.id}"} data-testid="member-upload-link">
                upload
              </.link>
              ·
              <.link navigate={~p"/account/#{member.id}/delete"} data-testid="member-delete-link">
                delete
              </.link>
            </li>
          </ul>
        </section>

        <section id="demo-courses" data-testid="demo-courses" class="ck-section">
          <div class="ck-section__head">
            <h2 class="ck-section__title">Courses</h2>
          </div>
          <ul>
            <li :for={course <- @courses}>
              <strong>{course.title}</strong>
              <ul>
                <li :for={lesson <- course.lessons}>
                  <.link navigate={~p"/lessons/#{lesson.id}"} data-testid={"lesson-link-#{lesson.id}"}>
                    {lesson.title}
                  </.link>
                </li>
              </ul>
            </li>
          </ul>
        </section>

        <section id="demo-posts" data-testid="demo-posts" class="ck-section">
          <div class="ck-section__head">
            <h2 class="ck-section__title">Community posts</h2>
          </div>
          <ul>
            <li :for={post <- @posts}>
              <.link navigate={~p"/posts/#{post.id}"} data-testid={"post-link-#{post.id}"}>
                {post.title}
              </.link>
              — by {post.member.name}
            </li>
          </ul>
        </section>

        <section id="demo-assets" data-testid="demo-assets" class="ck-section">
          <div class="ck-section__head">
            <h2 class="ck-section__title">Recent assets</h2>
          </div>
          <ul>
            <li :for={asset <- @assets}>
              <.link navigate={~p"/media/#{asset.id}"}>{asset.id}</.link>
              — {asset.state} ({asset.content_type || "unknown"})
            </li>
          </ul>
        </section>

        <nav class="ck-section" aria-label="Demo navigation">
          <.ck_button href={~p"/upload"} data-testid="nav-upload">Upload lab</.ck_button>
          <.ck_button href={~p"/ops"} data-testid="nav-ops">Ops surfaces</.ck_button>
        </nav>
      </.ck_page>
    </Layouts.app>
    """
  end
end
