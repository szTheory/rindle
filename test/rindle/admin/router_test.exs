defmodule Rindle.Admin.RouterTest do
  use ExUnit.Case, async: true

  if Code.ensure_loaded?(Phoenix.LiveView) do
    Rindle.Admin.LiveStubSupport.ensure_placeholder_modules!()

    defmodule HostAuth do
      def on_mount(:default, _params, _session, socket), do: {:cont, socket}
    end

    defmodule GuardedHostRouter do
      use Phoenix.Router, helpers: false

      import Rindle.Admin.Router

      scope "/admin" do
        rindle_admin("/rindle",
          on_mount: [HostAuth],
          as: :rindle_ops,
          home_path: "/admin",
          live_socket_path: "/custom-live",
          transport: "longpoll",
          csp_nonce_assign_key: %{
            img: :img_csp_nonce,
            style: :style_csp_nonce,
            script: :script_csp_nonce
          }
        )
      end
    end

    defmodule AcknowledgedHostRouter do
      use Phoenix.Router, helpers: false

      import Rindle.Admin.Router

      scope "/ops" do
        rindle_admin("/media", auth_guarded?: true)
      end
    end

    describe "rindle_admin/2 mount contract" do
      test "D-89-01 exposes the router macro when LiveView is loaded" do
        assert Code.ensure_loaded?(Rindle.Admin.Router)
        assert function_exported?(Rindle.Admin.Router, :__info__, 1)
        assert macro_exported?(Rindle.Admin.Router, :rindle_admin, 2)
      end

      test "D-89-02 accepts host on_mount auth and explicit auth_guarded? acknowledgement" do
        assert {:ok, opts} =
                 Rindle.Admin.Router.__validate_rindle_admin_mount_opts__(
                   [on_mount: [HostAuth]],
                   :prod
                 )

        assert opts.on_mount == [HostAuth]

        assert {:ok, opts} =
                 Rindle.Admin.Router.__validate_rindle_admin_mount_opts__(
                   [auth_guarded?: true],
                   :prod
                 )

        assert opts.auth_guarded? == true
      end

      test "D-89-03 rejects allow_unauthenticated? as a production escape hatch" do
        assert_raise ArgumentError, ~r/allow_unauthenticated\?/, fn ->
          Rindle.Admin.Router.__validate_rindle_admin_mount_opts__(
            [allow_unauthenticated?: true],
            :prod
          )
        end
      end

      test "D-89-04 preserves host route, socket, transport, CSP, and on_mount options" do
        assert {:ok, opts} =
                 Rindle.Admin.Router.__validate_rindle_admin_mount_opts__(
                   [
                     on_mount: [HostAuth],
                     as: :rindle_ops,
                     home_path: "/admin",
                     live_socket_path: "/custom-live",
                     transport: "longpoll",
                     csp_nonce_assign_key: %{
                       img: :img_csp_nonce,
                       style: :style_csp_nonce,
                       script: :script_csp_nonce
                     }
                   ],
                   :prod
                 )

        assert opts.as == :rindle_ops
        assert opts.home_path == "/admin"
        assert opts.live_socket_path == "/custom-live"
        assert opts.transport == "longpoll"

        assert opts.csp_nonce_assign_key == %{
                 img: :img_csp_nonce,
                 style: :style_csp_nonce,
                 script: :script_csp_nonce
               }

        assert opts.on_mount == [HostAuth]
      end

      test "D-89-03 allows explicit unauthenticated mounts only outside production" do
        assert {:ok, opts} =
                 Rindle.Admin.Router.__validate_rindle_admin_mount_opts__(
                   [allow_unauthenticated?: true],
                   :test
                 )

        assert opts.allow_unauthenticated? == true
      end
    end

    describe "generated host routes" do
      test "D-89-01 expands all read-surface LiveView routes" do
        routes = Phoenix.Router.routes(GuardedHostRouter)

        assert_route(routes, "/admin/rindle", Rindle.Admin.Live.HomeLive, :index)
        assert_route(routes, "/admin/rindle/assets", Rindle.Admin.Live.AssetsLive, :index)
        assert_route(routes, "/admin/rindle/assets/:id", Rindle.Admin.Live.AssetsLive, :show)

        assert_route(
          routes,
          "/admin/rindle/upload-sessions",
          Rindle.Admin.Live.UploadSessionsLive,
          :index
        )

        assert_route(
          routes,
          "/admin/rindle/upload-sessions/:id",
          Rindle.Admin.Live.UploadSessionsLive,
          :show
        )

        assert_route(
          routes,
          "/admin/rindle/variants-jobs",
          Rindle.Admin.Live.VariantsJobsLive,
          :index
        )

        assert_route(
          routes,
          "/admin/rindle/runtime-doctor",
          Rindle.Admin.Live.RuntimeDoctorLive,
          :index
        )

        assert_route(routes, "/admin/rindle/actions", Rindle.Admin.Live.ActionsLive, :index)
      end

      test "D-89-05 expands exact namespaced static asset routes" do
        routes = Phoenix.Router.routes(GuardedHostRouter)

        for file <- ~w(rindle-admin.css rindle-admin.js logo.svg favicon.svg) do
          assert Enum.any?(routes, fn route ->
                   route.path == "/admin/rindle/assets/#{file}" and
                     route.plug == Rindle.Admin.Router.StaticAssetsPlug and
                     route.plug_opts == file
                 end),
                 "expected static route for #{file}"
        end
      end

      test "D-89-02 accepts auth_guarded? acknowledgement during route expansion" do
        assert_route(
          Phoenix.Router.routes(AcknowledgedHostRouter),
          "/ops/media",
          Rindle.Admin.Live.HomeLive,
          :index
        )
      end
    end
  else
    test "Rindle.Admin.Router compiles away when LiveView is not loaded" do
      refute Code.ensure_loaded?(Rindle.Admin.Router)
    end
  end

  defp assert_route(routes, path, plug, live_action) do
    assert Enum.any?(routes, fn route ->
             route.path == path and live_route?(route, plug, live_action)
           end),
           "expected route #{path} to #{inspect(plug)} #{inspect(live_action)}"
  end

  defp live_route?(route, plug, live_action) do
    match?(
      %{plug: Phoenix.LiveView.Plug, plug_opts: ^live_action},
      route
    ) and match?({^plug, ^live_action, _opts, _session}, route.metadata[:phoenix_live_view])
  end
end
