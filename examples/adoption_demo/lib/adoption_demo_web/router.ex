defmodule AdoptionDemoWeb.Router do
  use AdoptionDemoWeb, :router
  import Rindle.Admin.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {AdoptionDemoWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  forward("/uploads/tus", Rindle.Upload.TusPlug,
    profile: AdoptionDemo.VideoProfile,
    secret_key_base:
      Application.compile_env!(:adoption_demo, AdoptionDemoWeb.Endpoint)[:secret_key_base]
  )

  scope "/", AdoptionDemoWeb do
    pipe_through(:browser)

    live("/", LaunchpadLive, :index)
    live("/dashboard", DashboardLive, :index)
    live("/members/:id", MemberLive, :show)
    live("/lessons/:id", LessonLive, :show)
    live("/posts/:id", PostLive, :show)
    live("/upload", UploadLive, :index)
    live("/media/:id", MediaLive, :show)
    live("/ops", OpsLive, :index)
    live("/account/:member_id/delete", AccountLive, :delete)
  end

  scope "/admin" do
    pipe_through(:browser)

    # PREVIEW ONLY. `allow_unauthenticated?: true` is the library's sanctioned
    # escape hatch for examples and local previews; it is refused in :prod, which
    # is why this demo is built as a dev/preview env (see docker/Dockerfile.cohort-demo).
    #
    # In a real production app you auth-guard the console instead, e.g.:
    #
    #     scope "/admin", MyAppWeb do
    #       pipe_through [:browser, :require_admin]
    #       rindle_admin "/rindle", on_mount: [MyAppWeb.AdminLiveAuth]
    #     end
    #
    # (or assert the surrounding pipeline already enforces auth via
    # `auth_guarded?: true`). Never ship `allow_unauthenticated?: true`.
    rindle_admin("/rindle", allow_unauthenticated?: true)
  end
end
