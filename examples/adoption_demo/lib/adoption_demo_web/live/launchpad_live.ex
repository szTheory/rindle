defmodule AdoptionDemoWeb.LaunchpadLive do
  @moduledoc """
  The `/` launchpad: a self-documenting hub that orients a developer by job —
  shows the live access info (URLs + MinIO credentials) inline, then links out
  to each Rindle flow in the example app. Renders Cohort's own design system
  (see `AdoptionDemoWeb.CohortComponents` + `priv/static/assets/cohort.css`)
  rather than the daisyUI chrome the inner pages use.
  """
  use AdoptionDemoWeb, :live_view

  import AdoptionDemoWeb.CohortComponents

  @tasks [
    %{
      icon: :upload,
      title: "Upload straight to storage",
      desc:
        "Pick a file — it PUTs directly to MinIO via a presigned URL (bytes never touch the server), then verifies, attaches, and renders.",
      href: "/upload?tab=image",
      path: "/upload · image"
    },
    %{
      icon: :video,
      title: "Transcode a video + poster",
      desc:
        "Upload a video and watch it move processing → ready as Rindle probes it, transcodes a 720p variant, and extracts a poster.",
      href: "/upload?tab=video",
      path: "/upload · video"
    },
    %{
      icon: :resume,
      title: "Resume a huge upload",
      desc:
        "Stage a multipart upload in 5 MiB parts (or a resumable tus session) that survives a dropped connection.",
      href: "/upload?tab=multipart",
      path: "/upload · multipart / tus"
    },
    %{
      icon: :liveview,
      title: "Upload inside LiveView",
      desc:
        "Wire uploads into a LiveView form with live progress and reactive asset-state updates over the socket.",
      href: "/upload?tab=liveview",
      path: "/upload · liveview"
    },
    %{
      icon: :erase,
      title: "Erase a user's media (GDPR)",
      desc:
        "Preview then run owner erasure — detach, purge newly-orphaned assets, retain still-shared ones. Batch-capable.",
      href: "/ops",
      path: "/ops"
    },
    %{
      icon: :ops,
      title: "Diagnose & inspect",
      desc:
        "Run doctor and runtime status, then browse assets and upload sessions — quarantined, degraded, failed — in the admin console.",
      href: "/admin/rindle",
      path: "/admin/rindle",
      external: true
    }
  ]

  @cast [
    %{name: "Maya Rivera", role: "instructor · has an avatar", persona: :instructor},
    %{name: "Alex Kim", role: "student · avatar shared with Jordan", persona: :student},
    %{name: "Jordan Lee", role: "student · fresh upload target", persona: :student},
    %{name: "Ops", role: "operator · batch erasure", persona: :operator}
  ]

  @impl true
  def mount(_params, _session, socket) do
    # Explicit title so the home tab reads "Rindle adoption demo · Cohort"
    # instead of doubling the default + suffix.
    {:ok,
     assign(socket,
       page_title: "Rindle adoption demo",
       access: access_info(),
       tasks: @tasks,
       cast: @cast
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ck">
      <.cohort_nav active={:home} />

      <main class="ck__wrap">
        <.hero
          eyebrow="Rindle adoption demo"
          title="Cohort — see Rindle's media lifecycle, end to end."
          lede="A course-and-community SaaS running Rindle on MinIO, in Docker. Pick a job below to jump into a live flow, or open the seeded app and click around. The data is seeded; the flows are real."
        >
          <:actions>
            <.ck_button href={~p"/dashboard"} variant="primary" arrow>Open the app</.ck_button>
            <.ck_button href="/admin/rindle">Admin console</.ck_button>
          </:actions>
        </.hero>

        <.access_panel>
          <.cred label="App" value={@access.app_url} href={@access.app_url} />
          <.cred label="Admin console" value={@access.admin_url} href="/admin/rindle" />
          <.cred
            :if={@access.minio_console_url}
            label="MinIO console"
            value={@access.minio_console_url}
            href={@access.minio_console_url}
          />
          <.cred :if={@access.minio_api_url} label="MinIO S3 endpoint" value={@access.minio_api_url} />
          <.cred label="MinIO user" value={@access.minio_user} />
          <.cred label="MinIO password" value={@access.minio_secret} />
          <.cred label="Bucket" value={@access.bucket} />
        </.access_panel>

        <section class="ck-section">
          <div class="ck-section__head">
            <h2 class="ck-section__title">What do you want to do?</h2>
            <span class="ck-section__hint">Each opens a live flow in the example app.</span>
          </div>
          <.task_grid>
            <.task_card
              :for={{t, i} <- Enum.with_index(@tasks)}
              icon={t.icon}
              title={t.title}
              desc={t.desc}
              href={t.href}
              path={t.path}
              external={Map.get(t, :external, false)}
              delay={"#{0.12 + i * 0.05}s"}
            />
          </.task_grid>
        </section>

        <section class="ck-section ck-reveal" style="--d:.5s">
          <div class="ck-section__head">
            <h2 class="ck-section__title">The seeded cast</h2>
            <span class="ck-section__hint">Open any member from the app.</span>
          </div>
          <ul class="ck-cast">
            <li :for={m <- @cast}>
              <span class="ck-cast__icon">{cast_icon(%{persona: m.persona})}</span>
              <span class="ck-cast__text">
                <strong>{m.name}</strong><span>{m.role}</span>
              </span>
            </li>
          </ul>
        </section>

        <.cohort_footer />
      </main>
    </div>
    """
  end

  # --- persona icons for the seeded cast ------------------------------------
  defp cast_icon(%{persona: :instructor} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M22 10 12 5 2 10l10 5 10-5Z" /><path d="M6 12v4c0 1.5 2.7 3 6 3s6-1.5 6-3v-4" />
    </svg>
    """
  end

  defp cast_icon(%{persona: :student} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M12 7c-2-1.3-5-1.5-8-1v12c3-.5 6-.3 8 1 2-1.3 5-1.5 8-1V6c-3-.5-6-.3-8 1Z" />
      <path d="M12 7v12" />
    </svg>
    """
  end

  defp cast_icon(%{persona: :operator} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M14.7 6.3a4 4 0 0 0-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 0 0 5.4-5.4l-2.3 2.3-2-2 2.3-2.3Z" />
    </svg>
    """
  end

  # Live access info. Prefers the host-published ports passed into the container
  # (so auto-bumped ports are accurate), then falls back to endpoint/ex_aws config.
  defp access_info do
    s3 = Application.get_env(:ex_aws, :s3, [])

    app_url =
      case System.get_env("COHORT_DEMO_PORT") do
        nil -> AdoptionDemoWeb.Endpoint.url()
        port -> "http://localhost:#{port}"
      end

    minio_api_port = System.get_env("COHORT_MINIO_PORT") || port_str(s3[:port])
    minio_api_url = minio_api_port && "http://localhost:#{minio_api_port}"

    console_url =
      case System.get_env("COHORT_MINIO_CONSOLE_PORT") do
        nil -> Application.get_env(:adoption_demo, :minio_console_url)
        port -> "http://localhost:#{port}"
      end

    bucket = Application.get_env(:rindle, Rindle.Storage.S3, [])[:bucket] || "rindle-test"

    %{
      app_url: app_url,
      admin_url: app_url <> "/admin/rindle",
      minio_api_url: minio_api_url,
      minio_console_url: console_url,
      minio_user: s3[:access_key_id] || System.get_env("RINDLE_MINIO_ACCESS_KEY") || "minioadmin",
      minio_secret:
        s3[:secret_access_key] || System.get_env("RINDLE_MINIO_SECRET_KEY") || "minioadmin",
      bucket: bucket
    }
  end

  defp port_str(nil), do: nil
  defp port_str(port), do: to_string(port)
end
