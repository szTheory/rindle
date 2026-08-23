defmodule Rindle.InstallSmoke.GeneratedApp.Patcher do
  @moduledoc false

  @doc false
  def patch!(
        root,
        app_name,
        app_module,
        package_root,
        network_version,
        profile_mode,
        compile_prefix,
        oban_requirement,
        mux_use_real_api?
      ) do
    patch_mix_exs!(root, package_root, network_version, profile_mode, oban_requirement)
    patch_test_config!(root, app_name, profile_mode, compile_prefix, mux_use_real_api?)
    patch_test_helper!(root, profile_mode)
    patch_runtime_config!(root, app_name, app_module, profile_mode)
    patch_application!(root, app_name, app_module, profile_mode)
    patch_router!(root, app_name, app_module, profile_mode)
    write_tus_live_view!(root, app_name, app_module, profile_mode)
    write_profile!(root, app_name, app_module, profile_mode)
  end

  defp patch_test_helper!(root, :mux) do
    path = Path.join(root, "test/test_helper.exs")
    existing = if File.exists?(path), do: File.read!(path), else: ""

    # Phase 36: define the Mox mock in the generated app's test_helper.
    # `Rindle.Streaming.Provider.Mux.ClientMock` is normally defined in
    # the library's `test/support/mocks.ex`, which is NOT shipped in the
    # Hex package. The generated app must define its own mock pointing at
    # the same `@behaviour` (which IS in the package: `lib/.../mux/client.ex`).
    mox_setup = """

    # Phase 36 cassette lane (D-16): Mox mock for the Mux HTTP client behaviour.
    # The behaviour itself lives in the published package
    # (`lib/rindle/streaming/provider/mux/client.ex`); the mock is defined
    # here at test_helper time so the package consumer can pin
    # `:http_client` to `Rindle.Streaming.Provider.Mux.ClientMock` without
    # depending on the library's test-support files.
    Mox.defmock(Rindle.Streaming.Provider.Mux.ClientMock,
      for: Rindle.Streaming.Provider.Mux.Client
    )
    """

    File.write!(path, existing <> mox_setup)
  end

  defp patch_test_helper!(_root, _profile_mode), do: :ok

  defp patch_mix_exs!(root, package_root, network_version, profile_mode, oban_requirement) do
    path = Path.join(root, "mix.exs")

    rindle_dep =
      if network_version do
        "{:rindle, \"~> #{network_version}\"}"
      else
        "{:rindle, path: #{inspect(package_root)}}"
      end

    extra_deps =
      case profile_mode do
        :gcs ->
          """
                {:goth, "~> 1.4"},
                {:finch, "~> 0.21"},
                {:gcs_signed_url, "~> 0.6"},
          """

        :mux ->
          """
                {:mux, "~> 3.2"},
                {:jose, "~> 1.11"},
          """

        _ ->
          ""
      end

    updated =
      path
      |> File.read!()
      |> String.replace(
        "{:bandit, \"~> 1.5\"}",
        """
        {:bandit, "~> 1.5"},
              {:oban, "#{oban_requirement}"},
              {:req, "~> 0.6"},
              {:mox, "~> 1.1", only: :test},
        #{extra_deps}
              #{rindle_dep}
        """
      )

    File.write!(path, updated)
  end

  defp patch_test_config!(root, app_name, profile_mode, compile_prefix, mux_use_real_api?) do
    path = Path.join(root, "config/test.exs")

    base_updated =
      path
      |> File.read!()
      |> String.replace(
        ~r/username: "postgres"/,
        "username: System.get_env(\"PGUSER\") || System.get_env(\"USER\") || \"postgres\""
      )
      |> String.replace(~r/password: "postgres"/, "password: System.get_env(\"PGPASSWORD\")")
      |> String.replace(
        ~r/hostname: "localhost"/,
        "hostname: System.get_env(\"PGHOST\") || \"localhost\""
      )
      |> String.replace(
        ~r/database: "#{app_name}_test#\{System.get_env\("MIX_TEST_PARTITION"\)\}"/,
        "database: System.fetch_env!(\"RINDLE_INSTALL_SMOKE_DB\")"
      )
      |> Kernel.<>("""

      config :#{app_name}, Oban,
        repo: #{Macro.camelize(app_name)}.Repo,
        testing: :manual,
        queues: #{oban_queues_block(profile_mode)}

      config :#{app_name}, #{Macro.camelize(app_name)}.Repo,
        migration_primary_key: [type: :binary_id],
        migration_timestamps: [type: :utc_datetime_usec]

      config :rindle, :repo, #{Macro.camelize(app_name)}.Repo
      config :rindle, :rindle_prefix, #{inspect(compile_prefix)}
      """)

    base_updated =
      if profile_mode == :tus do
        base_updated <>
          """

          config :rindle, :tus_profiles, [#{Macro.camelize(app_name)}.VideoProfile]
          """
      else
        base_updated
      end

    # Phase 36 D-21 / Pitfall 3: Mux config block is appended AFTER the
    # existing Oban + repo blocks. The `RINDLE_MUX_USE_REAL_API` conditional
    # is evaluated HOST-SIDE at patch time (NOT inside the generated app's
    # runtime), so the generated `config/test.exs` either contains
    # `http_client: ClientMock` (cassette) or omits the key (soak).
    final =
      if profile_mode == :mux do
        stage_mux_fixtures!(root)
        base_updated <> mux_config_block(mux_use_real_api?)
      else
        base_updated
      end

    File.write!(path, final)
  end

  defp patch_router!(_root, _app_name, _app_module, profile_mode)
       when profile_mode not in [:tus],
       do: :ok

  defp patch_router!(root, app_name, app_module, :tus) do
    path = Path.join(root, "lib/#{app_name}_web/router.ex")

    updated =
      path
      |> File.read!()
      |> String.replace(
        "scope \"/\", #{app_module}Web do",
        """
        forward "/uploads/tus", Rindle.Upload.TusPlug,
          profile: #{app_module}.VideoProfile,
          secret_key_base:
            Application.compile_env!(:#{app_name}, #{app_module}Web.Endpoint)[:secret_key_base]

        scope "/", #{app_module}Web do
        """
      )
      |> String.replace(
        ~S(get "/", PageController, :home),
        ~S(live "/rindle-smoke/tus", RindleTusSmokeLive
    get "/", PageController, :home)
      )

    File.write!(path, updated)
  end

  defp write_tus_live_view!(_root, _app_name, _app_module, profile_mode)
       when profile_mode != :tus,
       do: :ok

  defp write_tus_live_view!(root, app_name, app_module, :tus) do
    path = Path.join(root, "lib/#{app_name}_web/live/rindle_tus_smoke_live.ex")
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      """
      defmodule #{app_module}Web.RindleTusSmokeLive do
        use #{app_module}Web, :live_view
        @secret_key_base Application.compile_env!(
                           :#{app_name},
                           #{app_module}Web.Endpoint
                         )[:secret_key_base]

        def mount(_params, _session, socket) do
          {:ok,
           socket
           |> assign(:status, "idle")
           |> assign(:error_message, nil)
           |> assign(:uploaded_asset_ids, [])
           |> Rindle.LiveView.allow_tus_upload(:video, #{app_module}.VideoProfile,
             path: "/uploads/tus",
             secret_key_base: @secret_key_base,
             accept: ~w(.mp4),
             max_entries: 1,
             max_file_size: 524_288_000,
             progress: &handle_video_progress/3
           )}
        end

        def render(assigns) do
          ~H\"\"\"
          <div>
            <p id="upload-state"><%= @status %></p>
            <p :if={@error_message} id="upload-error"><%= @error_message %></p>
            <.form for={%{}} id="tus-form" phx-submit="save">
              <.live_file_input upload={@uploads.video} />
              <button type="submit">Submit upload</button>
            </.form>
            <ul id="uploaded-asset-ids">
              <li :for={asset_id <- @uploaded_asset_ids}><%= asset_id %></li>
            </ul>
          </div>
          \"\"\"
        end

        def handle_event("save", _params, socket) do
          socket =
            socket
            |> assign(:status, "verifying")
            |> assign(:error_message, nil)

          case Rindle.LiveView.consume_uploaded_entries(socket, :video, fn _entry, meta ->
                 {:ok, meta.asset_id}
               end) do
            [{:error, {:rindle_verify_failed, reason}}] ->
              {:noreply,
               socket
               |> assign(:status, "error")
               |> assign(:error_message, inspect(reason))}

            uploaded_asset_ids ->
              {:noreply,
               socket
               |> assign(:status, "ready")
               |> assign(:uploaded_asset_ids, uploaded_asset_ids)}
          end
        end

        defp handle_video_progress(:video, entry, socket) do
          next_status =
            if entry.progress > 0 or entry.done? do
              "uploading"
            else
              socket.assigns.status
            end

          {:noreply, assign(socket, :status, next_status)}
        end
      end
      """
    )
  end

  defp mux_config_block(mux_use_real_api?) do
    if mux_use_real_api? do
      # Soak mode: omit :http_client; defaults to Rindle.Streaming.Provider.Mux.HTTP
      """

      config :rindle, Rindle.Streaming.Provider.Mux,
        token_id: System.get_env("RINDLE_MUX_TOKEN_ID"),
        token_secret: System.get_env("RINDLE_MUX_TOKEN_SECRET"),
        signing_key_id: System.get_env("RINDLE_MUX_SIGNING_KEY_ID"),
        signing_private_key: System.get_env("RINDLE_MUX_SIGNING_PRIVATE_KEY"),
        webhook_secrets:
          System.get_env("RINDLE_MUX_WEBHOOK_SECRETS", "") |> String.split(",", trim: true)
      """
    else
      # Cassette mode: Mox client; fixture creds still set so resolution works
      """

      config :rindle, Rindle.Streaming.Provider.Mux,
        http_client: Rindle.Streaming.Provider.Mux.ClientMock,
        token_id: System.get_env("RINDLE_MUX_TOKEN_ID"),
        token_secret: System.get_env("RINDLE_MUX_TOKEN_SECRET"),
        signing_key_id: System.get_env("RINDLE_MUX_SIGNING_KEY_ID"),
        signing_private_key: System.get_env("RINDLE_MUX_SIGNING_PRIVATE_KEY"),
        webhook_secrets:
          System.get_env("RINDLE_MUX_WEBHOOK_SECRETS", "") |> String.split(",", trim: true)
      """
    end
  end

  defp stage_mux_fixtures!(root) do
    fixture_dir = Path.join(root, "test/fixtures/mux")
    File.mkdir_p!(fixture_dir)

    fixtures = ~w(
      asset_create_201.json
      asset_get_ready.json
      asset_get_processing.json
      webhook_video_asset_ready.json
      test_signing_private_key.pem
      test_signing_public_key.pem
    )

    # Phase 36 CR-03: raise loudly on missing fixtures rather than
    # silently skipping. Previously, an `if File.exists?(src)` guard
    # silently dropped missing fixtures; the eventual failure surfaced
    # in the generated-app test as a confusing "private key parse
    # error" or "cassette stub returned wrong shape" stack trace
    # instead of a clear "the Mux profile requires fixture X". A loud
    # failure here pins the diagnosis to the staging step.
    for fixture <- fixtures do
      src = Path.join("test/fixtures/mux", fixture)

      unless File.exists?(src) do
        raise """
        stage_mux_fixtures!/1: required Mux fixture missing at #{src}

        The :mux profile install-smoke lane requires the full Mux fixture
        tree to be present in the source repo. If you cleaned the test
        fixtures (or are running against a leaner checkout), restore the
        files under test/fixtures/mux/ from git before re-running.

        Fix: `git checkout -- test/fixtures/mux/`
        """
      end

      File.cp!(src, Path.join(fixture_dir, fixture))
    end
  end

  defp patch_runtime_config!(root, app_name, app_module, profile_mode) do
    path = Path.join(root, "config/runtime.exs")

    runtime_append =
      case profile_mode do
        :gcs ->
          """

          gcs_credentials_json = System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")

          gcs_signing_key =
            case gcs_credentials_json do
              json when is_binary(json) and json != "" ->
                Jason.decode!(json)

              _ ->
                %{
                  "private_key" => "-----BEGIN PRIVATE KEY-----\\ninvalid\\n-----END PRIVATE KEY-----\\n",
                  "client_email" => "generated-install-smoke@example.invalid"
                }
            end

          config :rindle, :repo, #{app_module}.Repo
          config :ex_aws, http_client: ExAws.Request.Req

          config :rindle, Rindle.Storage.GCS,
            bucket: System.get_env("RINDLE_GCS_BUCKET", "generated-install-smoke-bucket"),
            goth: #{app_module}.Goth,
            finch: #{app_module}.Finch,
            signing_key: gcs_signing_key

          config :#{app_name}, Oban,
            repo: #{app_module}.Repo,
            testing: :manual,
            queues: #{oban_queues_block(profile_mode)}
          """

        _ ->
          """

          minio_url = System.get_env("RINDLE_MINIO_URL", "http://localhost:9000")
          bucket = System.get_env("RINDLE_MINIO_BUCKET", "rindle-test")
          access_key = System.get_env("RINDLE_MINIO_ACCESS_KEY", "minioadmin")
          secret_key = System.get_env("RINDLE_MINIO_SECRET_KEY", "minioadmin")
          region = System.get_env("RINDLE_MINIO_REGION", "us-east-1")

          %URI{host: host, port: port, scheme: scheme} = URI.parse(minio_url)

          config :rindle, :repo, #{app_module}.Repo
          config :ex_aws, http_client: ExAws.Request.Req
          config :rindle, Rindle.Storage.S3, bucket: bucket

          config :ex_aws, :s3,
            scheme: "\#{scheme}://",
            host: host,
            port: port,
            region: region,
            access_key_id: access_key,
            secret_access_key: secret_key

          config :#{app_name}, Oban,
            repo: #{app_module}.Repo,
            testing: :manual,
            queues: #{oban_queues_block(profile_mode)}
          """
      end

    File.write!(path, File.read!(path) <> runtime_append)
  end

  # Phase 36 WR-04: single source of truth for the generated app's Oban
  # queue list. patch_test_config!/3 and patch_runtime_config!/4 both
  # render this so the two blocks cannot drift. The :mux profile mode
  # adds `rindle_provider` (Phase 36 WR-03 / streaming guide §6 — the
  # MuxSyncCoordinator and MuxIngestVariant workers enqueue here).
  defp oban_queues_block(profile_mode) do
    queues =
      [
        {:rindle_media, 1},
        {:rindle_promote, 1},
        {:rindle_process, 1},
        {:rindle_purge, 1},
        {:rindle_maintenance, 1}
      ] ++
        if profile_mode == :mux do
          [{:rindle_provider, 1}]
        else
          []
        end

    rendered =
      Enum.map_join(queues, ",\n        ", fn {name, concurrency} ->
        "#{name}: #{concurrency}"
      end)

    "[\n        #{rendered}\n      ]"
  end

  defp patch_application!(root, app_name, app_module, profile_mode) do
    path = Path.join(root, "lib/#{app_name}/application.ex")

    updated =
      path
      |> File.read!()
      |> maybe_patch_gcs_children(app_module, profile_mode)
      |> String.replace(
        "#{app_module}.Repo,",
        "#{app_module}.Repo,\n      {Oban, Application.fetch_env!(:#{app_name}, Oban)},"
      )

    File.write!(path, updated)
  end

  defp maybe_patch_gcs_children(source, _app_module, profile_mode) when profile_mode != :gcs,
    do: source

  defp maybe_patch_gcs_children(source, app_module, :gcs) do
    source
    |> String.replace(
      "children = [",
      """
      gcs_children =
        case System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON") do
          json when is_binary(json) and json != "" ->
            decoded = Jason.decode!(json)

            [
              {Finch, name: #{app_module}.Finch},
              {Goth, name: #{app_module}.Goth, source: {:service_account, decoded}}
            ]

          _ ->
            []
        end

      children = gcs_children ++ [
      """
    )
  end

  defp write_profile!(root, app_name, app_module, profile_mode) do
    path = Path.join(root, "lib/#{app_name}/rindle_profile.ex")

    # The `:mux` lane swaps Rindle.Profile.Presets.Web for
    # Rindle.Profile.Presets.MuxWeb (Plan 01) — same web_720p + poster
    # variants verbatim (D-04 byte-identical), but with a locked streaming
    # block. Module name `VideoProfile` stays so the assertion sites in
    # the lifecycle test source remain byte-identical to the :video lane.
    video_preset =
      case profile_mode do
        :mux -> "Rindle.Profile.Presets.MuxWeb"
        _ -> "Rindle.Profile.Presets.Web"
      end

    image_storage =
      case profile_mode do
        :gcs -> "Rindle.Storage.GCS"
        _ -> "Rindle.Storage.S3"
      end

    File.write!(
      path,
      """
      defmodule #{app_module}.RindleProfile do
        @moduledoc false

        use Rindle.Profile,
          storage: #{image_storage},
          variants: [thumb: [mode: :fit, width: 64, height: 64]],
          allow_mime: ["image/png", "image/jpeg"],
          max_bytes: 10_485_760
      end

      defmodule #{app_module}.VideoProfile do
        @moduledoc false

        use #{video_preset},
          storage: Rindle.Storage.S3,
          allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
          max_bytes: 524_288_000
      end
      """
    )
  end
end
