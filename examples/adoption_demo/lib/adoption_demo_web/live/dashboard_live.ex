defmodule AdoptionDemoWeb.DashboardLive do
  use AdoptionDemoWeb, :live_view

  alias AdoptionDemo.{Accounts, Cohort, Media}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Cohort",
       members: Accounts.list_members(),
       courses: Cohort.list_courses(),
       posts: Cohort.list_posts(),
       assets: Media.list_assets()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <h1 class="text-2xl font-semibold" data-testid="cohort-dashboard-title">Cohort</h1>
      <p class="text-sm opacity-80">
        Course-and-community SaaS demo for Rindle adoption proof. Storage:
        <code>Rindle.Storage.S3</code> on MinIO.
      </p>

      <section id="demo-members" data-testid="demo-members">
        <h2 class="text-lg font-semibold mt-6">Members</h2>
        <ul class="list-disc pl-5 space-y-2">
          <li :for={member <- @members} id={"member-#{member.id}"} data-testid={"member-row-#{member.email}"}>
            <strong>{member.name}</strong> ({member.email}, {member.role})
            — avatar: <%= if Media.attachment_for(member, :avatar) do %>
              <.link navigate={~p"/members/#{member.id}"} data-testid="member-avatar-link">attached</.link>
            <% else %>
              <span data-testid="member-no-avatar">none</span>
            <% end %>
            · <.link navigate={~p"/upload?member_id=#{member.id}"} data-testid="member-upload-link">upload</.link>
            · <.link navigate={~p"/account/#{member.id}/delete"} data-testid="member-delete-link">delete</.link>
          </li>
        </ul>
      </section>

      <section id="demo-courses" data-testid="demo-courses">
        <h2 class="text-lg font-semibold mt-6">Courses</h2>
        <ul class="list-disc pl-5 space-y-2">
          <li :for={course <- @courses}>
            <strong>{course.title}</strong>
            <ul class="list-disc pl-5">
              <li :for={lesson <- course.lessons}>
                <.link navigate={~p"/lessons/#{lesson.id}"} data-testid={"lesson-link-#{lesson.id}"}>
                  {lesson.title}
                </.link>
              </li>
            </ul>
          </li>
        </ul>
      </section>

      <section id="demo-posts" data-testid="demo-posts">
        <h2 class="text-lg font-semibold mt-6">Community posts</h2>
        <ul class="list-disc pl-5 space-y-2">
          <li :for={post <- @posts}>
            <.link navigate={~p"/posts/#{post.id}"} data-testid={"post-link-#{post.id}"}>{post.title}</.link>
            — by {post.member.name}
          </li>
        </ul>
      </section>

      <section id="demo-assets" data-testid="demo-assets">
        <h2 class="text-lg font-semibold mt-6">Recent assets</h2>
        <ul class="list-disc pl-5">
          <li :for={asset <- @assets}>
            <.link navigate={~p"/media/#{asset.id}"}>{asset.id}</.link>
            — {asset.state} ({asset.content_type || "unknown"})
          </li>
        </ul>
      </section>

      <nav class="flex gap-4 mt-8 text-sm">
        <.link navigate={~p"/upload"} class="underline" data-testid="nav-upload">Upload lab</.link>
        <.link navigate={~p"/ops"} class="underline" data-testid="nav-ops">Ops surfaces</.link>
      </nav>
    </Layouts.app>
    """
  end
end
