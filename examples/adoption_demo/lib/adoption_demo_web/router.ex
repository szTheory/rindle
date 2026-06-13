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

    live("/", DashboardLive, :index)
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

    rindle_admin("/rindle", allow_unauthenticated?: true)
  end
end
