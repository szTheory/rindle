if Code.ensure_loaded?(Phoenix.LiveView) and Code.ensure_loaded?(Phoenix.Router) and
     Code.ensure_loaded?(Plug.Static) do
  defmodule Rindle.Admin.Router do
    @moduledoc """
    Router integration for the mountable Rindle Admin console.

    Host applications mount the console inside their own authenticated Phoenix router
    scope. The host owns browser pipelines, authentication, and LiveView `:on_mount`
    hooks; Rindle owns only the console route expansion and library static assets.
    """

    @default_opts %{
      as: :rindle_admin,
      home_path: "/",
      live_socket_path: "/live",
      transport: "websocket",
      csp_nonce_assign_key: %{},
      on_mount: [],
      auth_guarded?: false,
      allow_unauthenticated?: false
    }

    @static_asset_files ~w(rindle-admin.css rindle-admin.js logo.svg favicon.svg)

    defmodule StaticAssetsPlug do
      @moduledoc false

      import Plug.Conn

      @content_types %{
        "rindle-admin.css" => "text/css",
        "rindle-admin.js" => "application/javascript",
        "logo.svg" => "image/svg+xml",
        "favicon.svg" => "image/svg+xml"
      }

      def init(file), do: file

      def call(conn, file) when is_binary(file) and is_map_key(@content_types, file) do
        path = Path.join([:code.priv_dir(:rindle), "static", "rindle_admin", file])

        conn
        |> put_resp_content_type(Map.fetch!(@content_types, file))
        |> send_file(200, path)
      end

      def call(conn, _file), do: send_resp(conn, 404, "not found")
    end

    @doc """
    Mounts Rindle Admin routes at `path`.

    In production, the mount must include a non-empty `:on_mount` list or an
    explicit `auth_guarded?: true` acknowledgement from the host application.
    The `allow_unauthenticated?: true` escape hatch is only accepted outside
    production for examples, CI fixtures, and local previews.
    """
    defmacro rindle_admin(path, opts \\ []) do
      env = rindle_admin_validation_env()

      expanded_opts =
        opts
        |> Macro.expand(__CALLER__)
        |> expand_option_aliases(__CALLER__)

      {:ok, config} = __validate_rindle_admin_mount_opts__(expanded_opts, env)

      session_config = %{
        "rindle_admin" => %{
          "home_path" => config.home_path,
          "live_socket_path" => config.live_socket_path,
          "transport" => config.transport,
          "csp_nonce_assign_key" => config.csp_nonce_assign_key
        }
      }

      quote bind_quoted: [
              path: path,
              config: Macro.escape(config),
              session_config: Macro.escape(session_config),
              static_asset_files: @static_asset_files
            ] do
        import Phoenix.LiveView.Router, only: [live: 3, live: 4, live_session: 3]

        scoped_base_path = Phoenix.Router.scoped_path(__MODULE__, path)
        session = put_in(session_config, ["rindle_admin", "base_path"], scoped_base_path)

        for file <- static_asset_files do
          get(Path.join(path, "/assets/#{file}"), Rindle.Admin.Router.StaticAssetsPlug, file)
        end

        get(Path.join(path, "/assets/tokens.json"), Rindle.Admin.Router.StaticAssetsPlug, :deny)

        live_session config.as, on_mount: config.on_mount, session: session do
          live(path, Rindle.Admin.Live.HomeLive, :index)
          live(Path.join(path, "/assets"), Rindle.Admin.Live.AssetsLive, :index)
          live(Path.join(path, "/assets/:id"), Rindle.Admin.Live.AssetsLive, :show)
          live(Path.join(path, "/upload-sessions"), Rindle.Admin.Live.UploadSessionsLive, :index)

          live(
            Path.join(path, "/upload-sessions/:id"),
            Rindle.Admin.Live.UploadSessionsLive,
            :show
          )

          live(Path.join(path, "/variants-jobs"), Rindle.Admin.Live.VariantsJobsLive, :index)
          live(Path.join(path, "/runtime-doctor"), Rindle.Admin.Live.RuntimeDoctorLive, :index)
          live(Path.join(path, "/actions"), Rindle.Admin.Live.ActionsLive, :index)
        end
      end
    end

    @doc false
    def __validate_rindle_admin_mount_opts__(opts, env) when is_list(opts) do
      opts
      |> normalize_mount_opts()
      |> validate_mount_opts(env)
    end

    def __validate_rindle_admin_mount_opts__(opts, _env) do
      raise ArgumentError,
            "expected Rindle.Admin.Router.rindle_admin/2 options to be a keyword list, " <>
              "got: #{inspect(opts)}"
    end

    defp normalize_mount_opts(opts) do
      on_mount = opts |> Keyword.get(:on_mount, []) |> List.wrap()

      @default_opts
      |> Map.merge(%{
        as: Keyword.get(opts, :as, @default_opts.as),
        home_path: Keyword.get(opts, :home_path, @default_opts.home_path),
        live_socket_path: Keyword.get(opts, :live_socket_path, @default_opts.live_socket_path),
        transport: Keyword.get(opts, :transport, @default_opts.transport),
        csp_nonce_assign_key:
          Keyword.get(opts, :csp_nonce_assign_key, @default_opts.csp_nonce_assign_key),
        on_mount: on_mount,
        auth_guarded?: Keyword.get(opts, :auth_guarded?, @default_opts.auth_guarded?),
        allow_unauthenticated?:
          Keyword.get(opts, :allow_unauthenticated?, @default_opts.allow_unauthenticated?)
      })
    end

    defp expand_option_aliases(opts, caller) when is_list(opts) do
      Macro.prewalk(opts, fn
        {:__aliases__, _, _} = alias_ast -> Macro.expand(alias_ast, caller)
        other -> other
      end)
    end

    defp expand_option_aliases(opts, _caller), do: opts

    defp validate_mount_opts(%{allow_unauthenticated?: true}, :prod) do
      raise ArgumentError,
            "allow_unauthenticated?: true is not permitted for production Rindle Admin mounts"
    end

    defp validate_mount_opts(%{on_mount: [], auth_guarded?: auth_guarded?}, :prod)
         when auth_guarded? != true do
      raise ArgumentError,
            "production Rindle Admin mounts require host auth via non-empty :on_mount " <>
              "or explicit auth_guarded?: true acknowledgement"
    end

    defp validate_mount_opts(config, _env) do
      {:ok, config}
    end

    defp rindle_admin_validation_env do
      Application.get_env(:rindle, :admin_router_env, Mix.env())
    end
  end
end
