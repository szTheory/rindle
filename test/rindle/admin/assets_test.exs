defmodule Rindle.Admin.AssetsTest do
  use ExUnit.Case, async: true

  import Plug.Conn
  import Plug.Test

  if Code.ensure_loaded?(Phoenix.LiveView) do
    for live_module <- [
          Rindle.Admin.Live.HomeLive,
          Rindle.Admin.Live.AssetsLive,
          Rindle.Admin.Live.UploadSessionsLive,
          Rindle.Admin.Live.VariantsJobsLive,
          Rindle.Admin.Live.RuntimeDoctorLive,
          Rindle.Admin.Live.ActionsLive
        ] do
      unless Code.ensure_loaded?(live_module) do
        Module.create(
          live_module,
          quote do
            use Phoenix.LiveView
          end,
          Macro.Env.location(__ENV__)
        )
      end
    end

    defmodule HostRouter do
      use Phoenix.Router, helpers: false

      import Rindle.Admin.Router

      defmodule NotFoundPlug do
        import Plug.Conn

        def init(opts), do: opts
        def call(conn, _opts), do: send_resp(conn, 404, "not found")
      end

      scope "/admin" do
        rindle_admin("/rindle", auth_guarded?: true)
      end

      forward("/", NotFoundPlug)
    end

    @served_assets ~w(rindle-admin.css rindle-admin.js logo.svg favicon.svg)

    test "serves only the allowlisted admin static assets from :rindle" do
      for file <- @served_assets do
        conn = request("/admin/rindle/assets/#{file}")

        assert conn.status == 200
        assert conn.resp_body != ""
      end
    end

    test "rejects traversal and unlisted static asset names" do
      for path <- [
            "/admin/rindle/assets/../mix.exs",
            "/admin/rindle/assets/%2E%2E/mix.exs",
            "/admin/rindle/assets/tokens.json"
          ] do
        conn = request(path)

        assert conn.status == 404
      end
    end

    defp request(path) do
      :get
      |> conn(path)
      |> HostRouter.call(HostRouter.init([]))
      |> maybe_send_not_found()
    end

    defp maybe_send_not_found(%Plug.Conn{state: :unset} = conn), do: send_resp(conn, 404, "not found")
    defp maybe_send_not_found(conn), do: conn
  else
    test "skips static asset route proof when LiveView is not loaded" do
      refute Code.ensure_loaded?(Rindle.Admin.Router)
    end
  end
end
