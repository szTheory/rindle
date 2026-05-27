defmodule Rindle.InstallSmoke.GeneratedAppHelper do
  @moduledoc false
  alias Mix.Dep.Lock

  @png_1x1 <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
             0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00,
             0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08,
             0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0x44, 0x74,
             0x06, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82>>

  @host_migration_version "20260428170000"
  @legacy_rindle_migration_version 20_260_428_110_000

  def profile_enabled?(profile_mode) when profile_mode in [:image, :video, :tus, :mux, :gcs] do
    selected_profiles()
    |> Enum.member?(profile_mode)
  end

  def prove_package_install!(profile_mode \\ :image)
      when profile_mode in [:image, :video, :tus, :mux, :gcs] do
    network_version = System.get_env("RINDLE_INSTALL_SMOKE_NETWORK_VERSION")
    install_mode = install_mode(network_version)

    workspace_root =
      Path.join(System.tmp_dir!(), "rindle-install-smoke-#{System.unique_integer([:positive])}")

    File.mkdir_p!(workspace_root)

    app_name = install_smoke_app_name(profile_mode)
    app_module = Macro.camelize(app_name)

    package_root =
      System.get_env("RINDLE_INSTALL_SMOKE_PACKAGE_ROOT") ||
        Path.join(workspace_root, "package/#{package_name()}")

    generated_app_root = Path.join(workspace_root, app_name)
    db_name = "#{app_name}_#{System.unique_integer([:positive])}_test"
    shared_env = shared_env(db_name, profile_mode)

    if is_nil(network_version) do
      ensure_package!(workspace_root, package_root)
    end

    generate_phoenix_app!(workspace_root, generated_app_root)

    patch_generated_app!(
      generated_app_root,
      app_name,
      app_module,
      package_root,
      network_version,
      profile_mode
    )

    fetch_deps!(generated_app_root, shared_env, network_version)

    compile_result = run_cmd!(generated_app_root, ["mix", "compile"], shared_env)
    _ = run_cmd!(generated_app_root, ["mix", "ecto.create"], shared_env)

    _ =
      run_cmd!(
        generated_app_root,
        ["mix", "run", "--no-start", "priv/install_smoke/migrate.exs"],
        shared_env
      )

    migration_report =
      read_json!(Path.join(generated_app_root, "tmp/install_smoke_migration_report.json"))

    boot_result = boot_app!(generated_app_root, app_module, shared_env)

    smoke_result =
      run_cmd(
        generated_app_root,
        ["mix", "test", "test/rindle_install_smoke_test.exs"],
        shared_env
      )

    deps_rindle_present? = File.exists?(Path.join(generated_app_root, "deps/rindle"))
    av_report_path = Path.join(generated_app_root, "tmp/install_smoke_av_report.json")
    av_report = if File.exists?(av_report_path), do: read_json!(av_report_path), else: %{}
    tus_report_path = Path.join(generated_app_root, "tmp/install_smoke_tus_report.json")
    tus_report = if File.exists?(tus_report_path), do: read_json!(tus_report_path), else: %{}

    tus_debug_report_path =
      Path.join(generated_app_root, "tmp/install_smoke_tus_debug_report.json")

    tus_debug_report =
      if File.exists?(tus_debug_report_path), do: read_json!(tus_debug_report_path), else: %{}

    gcs_report_path = Path.join(generated_app_root, "tmp/install_smoke_gcs_report.json")
    gcs_report = if File.exists?(gcs_report_path), do: read_json!(gcs_report_path), else: %{}

    tus_extensions = normalize_tus_extensions(tus_report["extensions"])
    tus_report_data = Map.put(tus_report, "extensions", tus_extensions)

    report = %{
      workspace_root: workspace_root,
      generated_app_root: generated_app_root,
      package_root: package_root,
      database_name: db_name,
      profile_mode: profile_mode,
      install_mode: install_mode,
      install_source: install_source(install_mode, package_root, network_version),
      compile_exit_code: compile_result.exit_code,
      boot_exit_code: boot_result.exit_code,
      smoke_exit_code: smoke_result.exit_code,
      network_mode?: install_mode == :network,
      deps_rindle_present?: deps_rindle_present?,
      host_migration_ran?: migration_report["host_migration_ran"] == true,
      migration_resolution: migration_report["resolver"] |> to_existing_atom_safe(),
      rindle_migration_path: migration_report["rindle_migration_path"],
      smoke_output: smoke_result.output,
      av_ready_variants: av_report["ready_variants"] || [],
      av_playback_storage_key: av_report["playback_storage_key"],
      av_delivery_path: av_report["delivery_path"],
      delivery_path: av_report["delivery_path"],
      streaming_url_kind: av_report["streaming_url_kind"],
      tus_upload_url: tus_report_data["upload_url"],
      tus_previous_uploads: tus_report_data["previous_uploads"],
      tus_byte_size: tus_report_data["byte_size"],
      tus_content_type: tus_report_data["content_type"],
      tus_ready_variants: tus_report_data["ready_variants"] || [],
      phoenix_helper_uploader: tus_report_data["phoenix_helper_uploader"],
      phoenix_helper_endpoint: tus_report_data["phoenix_helper_endpoint"],
      phoenix_helper_upload_url: tus_report_data["phoenix_helper_upload_url"],
      phoenix_helper_session_id: tus_report_data["phoenix_helper_session_id"],
      phoenix_helper_asset_id: tus_report_data["phoenix_helper_asset_id"],
      completion_surface: tus_report_data["completion_surface"],
      phoenix_state_sequence: tus_report_data["phoenix_state_sequence"] || [],
      phoenix_error_state: tus_report_data["phoenix_error_state"],
      extensions: tus_extensions,
      tus_report_path: tus_report_path,
      tus_debug_report_path: tus_debug_report_path,
      tus_report_data: tus_report_data,
      tus_debug_report_data: tus_debug_report,
      tus_failure_phase: tus_debug_report["failure_phase"] || tus_report_data["failure_phase"],
      tus_failure_endpoint: tus_debug_report["endpoint"] || tus_report_data["endpoint"],
      tus_failure_summary:
        tus_debug_report["failure_summary"] || tus_report_data["failure_summary"],
      tus_failure_mode: tus_debug_report["failure_mode"] || tus_report_data["failure_mode"],
      doctor_command: gcs_report["doctor_command"],
      doctor_success?: gcs_report["doctor_success"] == true,
      gcs_live_enabled?: gcs_report["live_enabled"] == true,
      gcs_status_surface: gcs_report["status_surface"],
      gcs_status_state: gcs_report["status_state"],
      gcs_status_committed_bytes: gcs_report["status_committed_bytes"],
      gcs_asset_state_after_verify: gcs_report["asset_state_after_verify"],
      gcs_asset_state_after_promote: gcs_report["asset_state_after_promote"],
      gcs_upload_key: gcs_report["upload_key"],
      lifecycle_proved?:
        smoke_result.exit_code == 0 and String.contains?(smoke_result.output, "0 failures")
    }

    maybe_write_tus_run_hint!(report)
    report
  end

  defp normalize_tus_extensions(raw_extensions) when is_map(raw_extensions) do
    %{
      "concatenation" =>
        normalize_tus_extension(
          Map.get(raw_extensions, "concatenation") || Map.get(raw_extensions, :concatenation),
          %{"parallel_uploads" => nil, "status" => nil}
        ),
      "creation_defer_length" =>
        normalize_tus_extension(
          Map.get(raw_extensions, "creation_defer_length") ||
            Map.get(raw_extensions, :creation_defer_length),
          %{"used_upload_defer_length" => false, "status" => nil}
        ),
      "checksum" =>
        normalize_tus_extension(
          Map.get(raw_extensions, "checksum") || Map.get(raw_extensions, :checksum),
          %{"algorithm" => nil, "status" => nil}
        )
    }
  end

  defp normalize_tus_extensions(_raw_extensions) do
    %{
      "concatenation" =>
        normalize_tus_extension(nil, %{"parallel_uploads" => nil, "status" => nil}),
      "creation_defer_length" =>
        normalize_tus_extension(nil, %{"used_upload_defer_length" => false, "status" => nil}),
      "checksum" => normalize_tus_extension(nil, %{"algorithm" => nil, "status" => nil})
    }
  end

  defp normalize_tus_extension(raw_extension, defaults) when is_map(raw_extension) do
    normalized =
      Enum.into(raw_extension, %{}, fn
        {key, value} when is_atom(key) -> {Atom.to_string(key), value}
        {key, value} -> {key, value}
      end)

    proved = normalized["proved"] == true

    defaults
    |> Map.put("proved", false)
    |> Map.merge(normalized)
    |> Map.put("proved", proved)
  end

  defp normalize_tus_extension(_raw_extension, defaults) do
    defaults
    |> Map.put("proved", false)
  end

  def prove_upgrade_install! do
    network_version = System.get_env("RINDLE_INSTALL_SMOKE_NETWORK_VERSION")
    install_mode = install_mode(network_version)

    workspace_root =
      Path.join(System.tmp_dir!(), "rindle-install-smoke-#{System.unique_integer([:positive])}")

    File.mkdir_p!(workspace_root)

    app_name = "rindle_smoke_app"
    app_module = Macro.camelize(app_name)

    package_root =
      System.get_env("RINDLE_INSTALL_SMOKE_PACKAGE_ROOT") ||
        Path.join(workspace_root, "package/#{package_name()}")

    generated_app_root = Path.join(workspace_root, app_name)
    db_name = "#{app_name}_#{System.unique_integer([:positive])}_test"
    shared_env = shared_env(db_name, :video)

    if is_nil(network_version) do
      ensure_package!(workspace_root, package_root)
    end

    generate_phoenix_app!(workspace_root, generated_app_root)

    patch_generated_app!(
      generated_app_root,
      app_name,
      app_module,
      package_root,
      network_version,
      :video
    )

    fetch_deps!(generated_app_root, shared_env, network_version)

    compile_result = run_cmd!(generated_app_root, ["mix", "compile"], shared_env)
    _ = run_cmd!(generated_app_root, ["mix", "ecto.create"], shared_env)

    _ =
      run_cmd!(
        generated_app_root,
        ["mix", "run", "--no-start", "priv/install_smoke/prepare_upgrade.exs"],
        shared_env
      )

    legacy_seed = read_json!(Path.join(generated_app_root, "tmp/install_smoke_upgrade_seed.json"))

    _ =
      run_cmd!(
        generated_app_root,
        ["mix", "run", "--no-start", "priv/install_smoke/migrate.exs"],
        shared_env
      )

    migration_report =
      read_json!(Path.join(generated_app_root, "tmp/install_smoke_migration_report.json"))

    boot_result = boot_app!(generated_app_root, app_module, shared_env)

    smoke_result =
      run_cmd!(
        generated_app_root,
        ["mix", "test", "test/rindle_install_smoke_test.exs"],
        shared_env
      )

    upgrade_report =
      read_json!(Path.join(generated_app_root, "tmp/install_smoke_upgrade_report.json"))

    deps_rindle_present? = File.exists?(Path.join(generated_app_root, "deps/rindle"))

    %{
      workspace_root: workspace_root,
      generated_app_root: generated_app_root,
      package_root: package_root,
      database_name: db_name,
      profile_mode: :upgrade,
      install_mode: install_mode,
      install_source: install_source(install_mode, package_root, network_version),
      compile_exit_code: compile_result.exit_code,
      boot_exit_code: boot_result.exit_code,
      smoke_exit_code: smoke_result.exit_code,
      network_mode?: install_mode == :network,
      deps_rindle_present?: deps_rindle_present?,
      host_migration_ran?: migration_report["host_migration_ran"] == true,
      migration_resolution: migration_report["resolver"] |> to_existing_atom_safe(),
      rindle_migration_path: migration_report["rindle_migration_path"],
      legacy_migration_cutoff: legacy_seed["legacy_rindle_migration_version"],
      canonical_upgrade_step_sequence: canonical_upgrade_step_sequence(),
      legacy_asset_kind: get_in(upgrade_report, ["legacy_asset", "kind"]),
      legacy_asset_profile: get_in(upgrade_report, ["legacy_asset", "profile"]),
      legacy_asset_upgrade_safe?:
        get_in(upgrade_report, ["legacy_asset", "upgrade_safe"]) == true,
      legacy_ready_variants: get_in(upgrade_report, ["legacy_asset", "ready_variants"]) || [],
      doctor_passed?: get_in(upgrade_report, ["doctor", "success"]) == true,
      runtime_status_classes: get_in(upgrade_report, ["runtime_status", "classes"]) || [],
      runtime_status_recommendation_actions:
        get_in(upgrade_report, ["runtime_status", "recommendation_actions"]) || [],
      runtime_status_recommendation_surfaces:
        get_in(upgrade_report, ["runtime_status", "recommendation_surfaces"]) || [],
      requeue_selected: get_in(upgrade_report, ["requeue", "selected"]),
      requeue_enqueued: get_in(upgrade_report, ["requeue", "enqueued"]),
      requeue_skipped: get_in(upgrade_report, ["requeue", "skipped"]),
      repaired_variant_state: get_in(upgrade_report, ["requeue", "repaired_variant_state"]),
      ready_sibling_state: get_in(upgrade_report, ["requeue", "ready_sibling_state"]),
      smoke_output: smoke_result.output,
      lifecycle_proved?:
        smoke_result.exit_code == 0 and String.contains?(smoke_result.output, "0 failures")
    }
  end

  def canonical_upgrade_step_sequence do
    [
      %{
        checkpoint: "Confirm runtime ownership and AV prerequisites",
        proof: "FFmpeg >= 6.0"
      },
      %{
        checkpoint: "Run explicit host and packaged migrations",
        proof: "Application.app_dir(:rindle, \"priv/repo/migrations\")"
      },
      %{
        checkpoint: "Validate the upgraded runtime",
        proof: "mix rindle.doctor"
      },
      %{
        checkpoint: "Inspect degraded upgraded work when needed",
        proof: "mix rindle.runtime_status",
        optional: true
      },
      %{
        checkpoint: "Repair one upgraded asset through the public facade",
        proof: "Rindle.requeue_variants/2"
      },
      %{
        checkpoint: "Reserve broad drift repair for stale or missing variants",
        proof: "mix rindle.regenerate_variants"
      }
    ]
  end

  def cleanup(%{generated_app_root: generated_app_root} = report) do
    _ = generated_app_root
    File.rm_rf(report.workspace_root)
    :ok
  end

  def cleanup(_report), do: :ok

  defp ensure_package!(workspace_root, package_root) do
    if File.dir?(package_root) do
      :ok
    else
      build_package!(workspace_root, package_root)
    end
  end

  defp build_package!(workspace_root, package_root) do
    File.mkdir_p!(Path.join(workspace_root, "package"))

    _ =
      run_cmd!(
        repo_root(),
        ["mix", "hex.build", "--unpack", "--output", package_root],
        [{"MIX_ENV", "dev"}]
      )
  end

  defp generate_phoenix_app!(workspace_root, generated_app_root) do
    _ =
      run_cmd!(
        workspace_root,
        [
          "mix",
          "phx.new",
          generated_app_root,
          "--no-assets",
          "--no-dashboard",
          "--no-mailer",
          "--no-gettext",
          "--install"
        ],
        [{"MIX_ENV", "dev"}]
      )
  end

  defp patch_generated_app!(
         root,
         app_name,
         app_module,
         package_root,
         network_version,
         profile_mode
       ) do
    patch_mix_exs!(root, package_root, network_version, profile_mode)
    patch_test_config!(root, app_name, profile_mode)
    patch_test_helper!(root, profile_mode)
    patch_runtime_config!(root, app_name, app_module, profile_mode)
    patch_application!(root, app_name, app_module, profile_mode)
    patch_router!(root, app_name, app_module, profile_mode)
    write_tus_live_view!(root, app_name, app_module, profile_mode)
    write_profile!(root, app_name, app_module, profile_mode)
    write_host_migration!(root)
    write_migration_runner!(root, app_name, app_module)
    write_legacy_upgrade_preparer!(root, app_module)
    write_smoke_test!(root, app_module, profile_mode)
    write_fixture!(root, profile_mode)
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

  defp patch_mix_exs!(root, package_root, network_version, profile_mode) do
    path = Path.join(root, "mix.exs")
    oban_requirement = oban_requirement()

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
                {:gcs_signed_url, "~> 0.4.6"},
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
              {:hackney, "~> 1.20"},
              {:mox, "~> 1.1", only: :test},
        #{extra_deps}
              #{rindle_dep}
        """
      )

    File.write!(path, updated)
  end

  defp patch_test_config!(root, app_name, profile_mode) do
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
        base_updated <> mux_config_block()
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

  defp mux_config_block do
    if System.get_env("RINDLE_MUX_USE_REAL_API") == "1" do
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

  defp write_host_migration!(root) do
    path =
      Path.join(
        root,
        "priv/repo/migrations/#{@host_migration_version}_create_install_smoke_markers.exs"
      )

    File.write!(
      path,
      """
      defmodule RindleSmokeApp.Repo.Migrations.CreateInstallSmokeMarkers do
        use Ecto.Migration

        def change do
          create table(:install_smoke_markers) do
            add :name, :string, null: false

            timestamps()
          end
        end
      end
      """
    )
  end

  defp write_migration_runner!(root, _app_name, app_module) do
    path = Path.join(root, "priv/install_smoke/migrate.exs")
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      """
      Application.ensure_all_started(:rindle)
      {:ok, _pid} = #{app_module}.Repo.start_link()

      host_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])
      rindle_path = Application.app_dir(:rindle, "priv/repo/migrations")

      unless File.dir?(rindle_path) do
        raise "Rindle migration path missing: \#{rindle_path}"
      end

      {:ok, _, _} =
        Ecto.Migrator.with_repo(#{app_module}.Repo, fn repo ->
          for path <- [host_path, rindle_path] do
            Ecto.Migrator.run(repo, path, :up, all: true)
          end
        end)

      {:ok, result} =
        #{app_module}.Repo.query(
          "select to_regclass('public.install_smoke_markers')::text"
        )

      File.mkdir_p!("tmp")

      File.write!(
        "tmp/install_smoke_migration_report.json",
        Jason.encode!(%{
          resolver: "application_app_dir",
          host_migration_ran: result.rows == [["install_smoke_markers"]],
          rindle_migration_path: rindle_path
        })
      )
      """
    )
  end

  defp write_legacy_upgrade_preparer!(root, app_module) do
    path = Path.join(root, "priv/install_smoke/prepare_upgrade.exs")
    File.mkdir_p!(Path.dirname(path))

    File.write!(
      path,
      """
      Application.ensure_all_started(:rindle)
      {:ok, _pid} = #{app_module}.Repo.start_link()

      host_path = Path.join([File.cwd!(), "priv", "repo", "migrations"])
      rindle_path = Application.app_dir(:rindle, "priv/repo/migrations")
      legacy_cutoff = #{@legacy_rindle_migration_version}

      {:ok, _, _} =
        Ecto.Migrator.with_repo(#{app_module}.Repo, fn repo ->
          Ecto.Migrator.run(repo, host_path, :up, all: true)
          Ecto.Migrator.run(repo, rindle_path, :up, to: legacy_cutoff)
        end)

      legacy_asset_id = Ecto.UUID.generate()
      legacy_variant_id = Ecto.UUID.generate()
      legacy_session_id = Ecto.UUID.generate()
      legacy_asset_db_id = Ecto.UUID.dump!(legacy_asset_id)
      legacy_variant_db_id = Ecto.UUID.dump!(legacy_variant_id)
      legacy_session_db_id = Ecto.UUID.dump!(legacy_session_id)
      recipe_digest = #{app_module}.RindleProfile.recipe_digest(:thumb)
      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
      expires_at = DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)

      #{app_module}.Repo.query!(
        \"\"\"
        insert into media_assets (
          id, state, storage_key, content_type, byte_size, filename, metadata,
          recipe_digest, profile, inserted_at, updated_at
        ) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        \"\"\",
        [
          legacy_asset_db_id,
          "ready",
          "legacy/assets/image-only-thumb.png",
          "image/png",
          68,
          "legacy-thumb.png",
          %{"upgrade_seed" => true},
          recipe_digest,
          "#{app_module}.RindleProfile",
          now,
          now
        ]
      )

      #{app_module}.Repo.query!(
        \"\"\"
        insert into media_variants (
          id, asset_id, name, state, recipe_digest, storage_key, generated_at,
          byte_size, content_type, inserted_at, updated_at
        ) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
        \"\"\",
        [
          legacy_variant_db_id,
          legacy_asset_db_id,
          "thumb",
          "ready",
          recipe_digest,
          "legacy/variants/thumb.png",
          now,
          68,
          "image/png",
          now,
          now
        ]
      )

      #{app_module}.Repo.query!(
        \"\"\"
        insert into media_upload_sessions (
          id, asset_id, state, upload_key, expires_at, verified_at, failure_reason,
          upload_strategy, multipart_upload_id, multipart_parts, inserted_at, updated_at
        ) values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        \"\"\",
        [
          legacy_session_db_id,
          legacy_asset_db_id,
          "completed",
          "legacy/uploads/image-only-thumb.png",
          expires_at,
          expires_at,
          nil,
          "presigned_put",
          nil,
          %{},
          now,
          now
        ]
      )

      File.mkdir_p!("tmp")

      File.write!(
        "tmp/install_smoke_upgrade_seed.json",
        Jason.encode!(%{
          legacy_rindle_migration_version: Integer.to_string(legacy_cutoff),
          legacy_asset_id: legacy_asset_id,
          legacy_variant_id: legacy_variant_id,
          legacy_session_id: legacy_session_id
        })
      )
      """
    )
  end

  defp write_smoke_test!(root, app_module, profile_mode) do
    path = Path.join(root, "test/rindle_install_smoke_test.exs")
    lifecycle_test = lifecycle_test_source(app_module, profile_mode)
    upgrade_test = upgrade_test_source(app_module)
    extra_imports = mux_test_imports(profile_mode)
    profile_helpers = profile_test_helpers(app_module, profile_mode)

    File.write!(
      path,
      """
      defmodule #{app_module}.RindleInstallSmokeTest do
        use #{app_module}.DataCase, async: false
        use Oban.Testing, repo: #{app_module}.Repo

        import ExUnit.CaptureIO
        import Ecto.Query
        import Phoenix.ConnTest
        import Phoenix.LiveViewTest
      #{extra_imports}
        alias Oban.Job
        alias #{app_module}.Repo
        alias #{app_module}.RindleProfile
        alias #{app_module}.VideoProfile
        alias #{app_module}Web.Endpoint
        alias Mix.Tasks.Rindle.{Doctor, RuntimeStatus}
        alias Rindle.Domain.MediaAsset
        alias Rindle.Domain.MediaUploadSession
        alias Rindle.Domain.MediaVariant
        alias Rindle.Upload.Broker
        alias Rindle.Workers.{ProcessVariant, PromoteAsset}

      #{profile_test_moduletag(profile_mode)}

        @png_1x1 #{inspect(@png_1x1, limit: :infinity)}
        @endpoint #{app_module}Web.Endpoint

        setup do
          case :inets.start() do
            :ok -> :ok
            {:error, {:already_started, :inets}} -> :ok
          end

          :ok
        end

        test "generated app boots with adopter repo ownership and default Oban wiring" do
          assert Application.fetch_env!(:rindle, :repo) == Repo
          assert Application.fetch_env!(:#{Macro.underscore(app_module)}, Oban)[:repo] == Repo
          assert File.dir?(Application.app_dir(:rindle, "priv/repo/migrations"))
          refute File.exists?(Path.join(File.cwd!(), "deps/rindle"))
        end

      #{lifecycle_test}

      if File.exists?(Path.expand("../tmp/install_smoke_upgrade_seed.json", __DIR__)) do
      #{upgrade_test}
      end

      #{profile_helpers}

        defp assert_install_smoke_marker! do
          assert {:ok, result} =
                   Repo.query("select to_regclass('public.install_smoke_markers')::text")

          assert result.rows == [["install_smoke_markers"]]
        end

        defp put_to_presigned_url(presigned_url, body) do
          request = {String.to_charlist(presigned_url), [], ~c"application/octet-stream", body}

          case :httpc.request(:put, request, [], []) do
            {:ok, {{_http_version, status, _reason}, _headers, _body}} when status in 200..299 ->
              :ok

            {:ok, {{_http_version, status, reason}, _headers, response_body}} ->
              flunk("presigned PUT failed with status \#{status} \#{reason}: \#{inspect(response_body)}")

            {:error, reason} ->
              flunk("presigned PUT failed: \#{inspect(reason)}")
          end
        end

        defp read_upgrade_seed! do
          "tmp/install_smoke_upgrade_seed.json"
          |> File.read!()
          |> Jason.decode!()
        end

        defp write_upgrade_report!(report) do
          File.mkdir_p!("tmp")
          File.write!("tmp/install_smoke_upgrade_report.json", Jason.encode!(report))
        end
      end
      """
    )
  end

  defp write_fixture!(root, profile_mode) do
    File.mkdir_p!(Path.join(root, "tmp"))
    File.write!(Path.join(root, "tmp/generated-app.png"), @png_1x1)

    if profile_mode in [:video, :tus, :mux] do
      File.cp!(video_fixture_path(), Path.join(root, "tmp/generated-app-video.webm"))
    end
  end

  defp boot_app!(generated_app_root, app_module, env) do
    run_cmd!(
      generated_app_root,
      [
        "mix",
        "run",
        "--no-start",
        "-e",
        "Application.ensure_all_started(:#{Macro.underscore(app_module)}); repo = Application.fetch_env!(:rindle, :repo); oban_repo = Application.fetch_env!(:#{Macro.underscore(app_module)}, Oban)[:repo]; if repo != #{app_module}.Repo or oban_repo != #{app_module}.Repo, do: raise(\"boot wiring invalid\"); IO.puts(\"boot ok\")"
      ],
      env
    )
  end

  defp read_json!(path) do
    path
    |> File.read!()
    |> Jason.decode!()
  end

  defp run_cmd!(cwd, argv, env) do
    case run_cmd(cwd, argv, env) do
      %{exit_code: 0} = result ->
        result

      %{exit_code: exit_code, output: output} ->
        raise """
        command failed (#{exit_code}): #{Enum.join(argv, " ")}
        cwd: #{cwd}

        #{output}
        """
    end
  end

  defp run_cmd(cwd, argv, env) do
    {output, exit_code} =
      System.cmd(List.first(argv), tl(argv),
        cd: cwd,
        env: env,
        stderr_to_stdout: true,
        into: ""
      )

    %{output: output, exit_code: exit_code}
  end

  defp shared_env(db_name, profile_mode) do
    base_env = [
      {"MIX_ENV", "test"},
      {"RINDLE_INSTALL_SMOKE_DB", db_name},
      {"PGUSER", env_or_default("PGUSER", System.get_env("USER") || "postgres")},
      {"PGPASSWORD", System.get_env("PGPASSWORD")},
      {"PGHOST", env_or_default("PGHOST", "localhost")},
      {"PGPORT", env_or_default("PGPORT", "5432")},
      {"RINDLE_MINIO_URL", env_or_default("RINDLE_MINIO_URL", "http://localhost:9000")},
      {"RINDLE_MINIO_BUCKET", env_or_default("RINDLE_MINIO_BUCKET", "rindle-test")},
      {"RINDLE_MINIO_ACCESS_KEY", env_or_default("RINDLE_MINIO_ACCESS_KEY", "minioadmin")},
      {"RINDLE_MINIO_SECRET_KEY", env_or_default("RINDLE_MINIO_SECRET_KEY", "minioadmin")},
      {"RINDLE_MINIO_REGION", env_or_default("RINDLE_MINIO_REGION", "us-east-1")}
    ]

    # Phase 36 CR-03: only the :mux profile reads the Mux fixture private
    # key. Previously this `File.read!/1` ran for every profile mode
    # (`:image`, `:video`, `:mux`), which coupled non-Mux runs to a
    # Mux-only fixture file — running `bash scripts/install_smoke.sh image`
    # against a checkout that lacked `test/fixtures/mux/test_signing_private_key.pem`
    # crashed with a low-level `File.Error` stack trace instead of cleanly
    # skipping. Push the read into the `:mux` branch so :image/:video runs
    # never touch the Mux fixture tree.
    full_env =
      case profile_mode do
        :mux -> base_env ++ build_mux_env()
        :gcs -> base_env ++ build_gcs_env()
        _other -> base_env
      end

    Enum.reject(full_env, fn {_key, value} -> is_nil(value) end)
  end

  # Phase 36 D-17 + CR-03: Mux fixture env vars. `env_or_default/2`
  # semantics — `System.get_env(name) || default` — are load-bearing: in
  # soak mode the GitHub Actions job's `env:` block (real `${{ secrets.* }}`)
  # wins via `System.get_env/1`; in cassette mode, fixtures win.
  defp build_mux_env do
    private_key_pem =
      System.get_env("RINDLE_MUX_SIGNING_PRIVATE_KEY") ||
        File.read!("test/fixtures/mux/test_signing_private_key.pem")

    [
      {"RINDLE_MUX_TOKEN_ID", env_or_default("RINDLE_MUX_TOKEN_ID", "test-token-id")},
      {"RINDLE_MUX_TOKEN_SECRET", env_or_default("RINDLE_MUX_TOKEN_SECRET", "test-token-secret")},
      {"RINDLE_MUX_SIGNING_KEY_ID",
       env_or_default("RINDLE_MUX_SIGNING_KEY_ID", "test-signing-key-id")},
      {"RINDLE_MUX_SIGNING_PRIVATE_KEY", private_key_pem},
      {"RINDLE_MUX_WEBHOOK_SECRETS",
       env_or_default(
         "RINDLE_MUX_WEBHOOK_SECRETS",
         "whsec_test_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
       )},
      {"RINDLE_MUX_USE_REAL_API", System.get_env("RINDLE_MUX_USE_REAL_API")},
      # Phase 36 CR-01: propagate the soak passthrough tag into the
      # generated app's worker process. Unset on cassette runs so the
      # cassette mock never sees the key (cassette test asserts the
      # request body matches the stub, no passthrough field expected).
      {"RINDLE_MUX_PASSTHROUGH_TAG", System.get_env("RINDLE_MUX_PASSTHROUGH_TAG")}
    ]
  end

  defp build_gcs_env do
    [
      {"GOOGLE_APPLICATION_CREDENTIALS_JSON",
       System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")},
      {"RINDLE_GCS_BUCKET", System.get_env("RINDLE_GCS_BUCKET")},
      {"RINDLE_INSTALL_SMOKE_GCS_PREFIX", System.get_env("RINDLE_INSTALL_SMOKE_GCS_PREFIX")},
      {"RINDLE_INSTALL_SMOKE_GCS_CLEANUP_FILE",
       System.get_env("RINDLE_INSTALL_SMOKE_GCS_CLEANUP_FILE")}
    ]
  end

  defp package_name do
    "#{Mix.Project.config()[:app]}-#{Mix.Project.config()[:version]}"
  end

  defp install_mode(nil), do: :package
  defp install_mode(_network_version), do: :network

  defp install_source(:package, package_root, _network_version), do: package_root
  defp install_source(:network, _package_root, network_version), do: "hex:#{network_version}"

  defp repo_root do
    File.cwd!()
  end

  defp maybe_write_tus_run_hint!(%{profile_mode: :tus} = report) do
    hint_path = Path.join([repo_root(), "tmp", "install_smoke_tus_last_run.json"])
    File.mkdir_p!(Path.dirname(hint_path))

    File.write!(
      hint_path,
      Jason.encode!(%{
        workspace_root: report.workspace_root,
        generated_app_root: report.generated_app_root,
        tus_report_path: report.tus_report_path,
        tus_debug_report_path: report.tus_debug_report_path,
        tus_report: report.tus_report_data,
        tus_debug_report: report.tus_debug_report_data,
        tus_failure_phase: report.tus_failure_phase,
        tus_failure_mode: report.tus_failure_mode,
        tus_failure_endpoint: report.tus_failure_endpoint,
        tus_failure_summary: report.tus_failure_summary,
        smoke_output: report.smoke_output
      })
    )
  end

  defp maybe_write_tus_run_hint!(_report), do: :ok

  defp oban_requirement do
    case Lock.read()[:oban] do
      {:hex, :oban, version, _checksum, _managers, _deps, _repo, _outer_checksum} ->
        "~> #{version}"

      other ->
        raise "unexpected Oban lock entry: #{inspect(other)}"
    end
  end

  defp to_existing_atom_safe(nil), do: nil
  defp to_existing_atom_safe(value) when is_binary(value), do: String.to_atom(value)

  defp fetch_deps!(generated_app_root, shared_env, network_version) do
    if network_version do
      retry_network_deps_get!(generated_app_root, shared_env)
    else
      _ = run_cmd!(generated_app_root, ["mix", "deps.get"], shared_env)
    end
  end

  defp retry_network_deps_get!(generated_app_root, shared_env) do
    Enum.reduce_while(1..30, :error, fn attempt, _acc ->
      case run_cmd(generated_app_root, ["mix", "deps.get"], shared_env) do
        %{exit_code: 0} ->
          {:halt, :ok}

        _ when attempt == 30 ->
          raise "deps.get failed after 30 attempts"

        _ ->
          Process.sleep(10_000)
          {:cont, :error}
      end
    end)
  end

  defp selected_profiles do
    case System.get_env("RINDLE_INSTALL_SMOKE_PROFILE", "all") do
      "all" -> [:image, :video, :tus, :mux, :gcs]
      "image" -> [:image]
      "video" -> [:video]
      "tus" -> [:tus]
      "mux" -> [:mux]
      "gcs" -> [:gcs]
      other -> raise "unsupported RINDLE_INSTALL_SMOKE_PROFILE: #{inspect(other)}"
    end
  end

  defp lifecycle_test_source(_app_module, :image) do
    """
        test "generated app completes the canonical presigned PUT lifecycle" do
          assert_install_smoke_marker!()

          {:ok, session} = Broker.initiate_session(RindleProfile, filename: "generated-app.png")
          {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
          assert signed.state == "signed"

          :ok = put_to_presigned_url(presigned.url, @png_1x1)

          {:ok, %{session: completed, asset: asset}} = Broker.verify_completion(session.id)
          assert completed.state == "completed"
          assert_enqueued(worker: PromoteAsset, args: %{"asset_id" => asset.id})
          assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

          asset = Repo.get!(MediaAsset, asset.id)
          assert asset.state in ["available", "processing", "ready"]

          variants = Repo.all(from variant in MediaVariant, where: variant.asset_id == ^asset.id)
          assert variants != []

          for variant <- variants do
            assert :ok =
                     perform_job(ProcessVariant, %{
                       "asset_id" => asset.id,
                       "variant_name" => variant.name
                     })
          end

          ready_variants = Repo.all(from variant in MediaVariant, where: variant.asset_id == ^asset.id)
          assert Enum.all?(ready_variants, &(&1.state == "ready"))

          {:ok, signed_url} = Rindle.Delivery.url(RindleProfile, asset.storage_key)
          assert String.contains?(signed_url, asset.storage_key)
        end
    """
  end

  defp lifecycle_test_source(_app_module, :video) do
    """
        test "generated app proves the canonical AV upload, processing, playback-ready variants, and signed delivery path" do
          assert_install_smoke_marker!()
          assert :presigned_put in VideoProfile.storage_adapter().capabilities()

          fixture_path = Path.expand("../tmp/generated-app-video.webm", __DIR__)

          {:ok, session} = Rindle.initiate_upload(VideoProfile, filename: "generated-app-video.webm")
          {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
          assert signed.state == "signed"

          :ok = put_to_presigned_url(presigned.url, File.read!(fixture_path))

          {:ok, %{session: completed, asset: asset}} = Rindle.verify_completion(session.id)
          assert completed.state == "completed"
          assert_enqueued(worker: PromoteAsset, args: %{"asset_id" => asset.id})
          assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

          promoted_asset = Repo.get!(MediaAsset, asset.id)
          assert promoted_asset.kind == "video"
          assert promoted_asset.has_video_track == true
          assert promoted_asset.has_audio_track == true
          assert promoted_asset.duration_ms > 0

          variants =
            Repo.all(
              from variant in MediaVariant,
                where: variant.asset_id == ^asset.id,
                order_by: variant.name
            )

          assert Enum.map(variants, & &1.name) == ["poster", "web_720p"]

          for variant <- variants do
            assert :ok =
                     perform_job(ProcessVariant, %{
                       "asset_id" => asset.id,
                       "variant_name" => variant.name
                     })
          end

          ready_variants =
            Repo.all(
              from variant in MediaVariant,
                where: variant.asset_id == ^asset.id,
                order_by: variant.name
            )

          assert Enum.map(ready_variants, &{&1.name, &1.output_kind, &1.state}) == [
                   {"poster", "image", "ready"},
                   {"web_720p", "video", "ready"}
                 ]

          poster_variant = Enum.find(ready_variants, &(&1.name == "poster"))
          web_variant = Enum.find(ready_variants, &(&1.name == "web_720p"))

          assert is_binary(poster_variant.storage_key) and poster_variant.byte_size > 0
          assert is_binary(web_variant.storage_key) and web_variant.byte_size > 0
          assert String.contains?(web_variant.storage_key, "web_720p")

          {:ok, signed_url} = Rindle.url(VideoProfile, web_variant.storage_key)
          assert String.contains?(signed_url, web_variant.storage_key)

          File.mkdir_p!("tmp")

          File.write!(
            "tmp/install_smoke_av_report.json",
            Jason.encode!(%{
              ready_variants: Enum.map(ready_variants, & &1.name),
              playback_storage_key: web_variant.storage_key,
              delivery_path: URI.parse(signed_url).path
            })
          )
        end
    """
  end

  defp lifecycle_test_source(_app_module, :tus) do
    """
        test "generated app serves the Phoenix helper path over a real socket and proves drop-and-resume against MinIO" do
          assert_install_smoke_marker!()
          assert :tus_upload in VideoProfile.storage_adapter().capabilities()

          Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

          port = 41_000 + rem(System.unique_integer([:positive]), 1000)
          start_endpoint_server!(port)

          fixture_path = Path.expand("../tmp/generated-app-tus-large.mp4", __DIR__)
          build_large_mp4_fixture!(fixture_path)
          assert File.stat!(fixture_path).size >= 200 * 1024 * 1024

          install_tus_js_client!()

          script_path = Path.expand("../tmp/install_smoke_tus_proof.cjs", __DIR__)
          write_tus_node_script!(script_path)

          assert {:ok, view, _html} = live(build_conn(), "/rindle-smoke/tus")

          upload =
            file_input(view, "#tus-form", :video, [
              %{
                name: "generated-app-tus-large.mp4",
                content: File.read!(fixture_path),
                type: "video/mp4"
              }
            ])

          assert {:ok, preflight} = preflight_upload(upload)
          :ok =
            Phoenix.LiveViewTest.UploadClient.allowed_ack(
              upload,
              preflight.ref,
              preflight.config,
              "generated-app-tus-large.mp4",
              preflight.entries,
              preflight.errors
            )

          [entry] = preflight_entries(preflight)
          meta = preflight_entry_meta!(entry)

          phoenix_helper_uploader = preflight_value!(entry, :uploader)
          phoenix_helper_endpoint = preflight_value!(meta, :endpoint)
          phoenix_helper_upload_url = preflight_value!(meta, :upload_url)
          phoenix_helper_session_id = preflight_value!(meta, :session_id)
          phoenix_helper_asset_id = preflight_value!(meta, :asset_id)

          merge_tus_report!(%{
            phoenix_helper_uploader: phoenix_helper_uploader,
            phoenix_helper_endpoint: phoenix_helper_endpoint,
            phoenix_helper_upload_url: phoenix_helper_upload_url,
            phoenix_helper_session_id: phoenix_helper_session_id,
            phoenix_helper_asset_id: phoenix_helper_asset_id,
            completion_surface: "consume_uploaded_entries->verify_completion",
            phoenix_state_sequence: ["uploading"],
            phoenix_error_state: nil
          })

          proof =
            try do
              proof =
                run_tus_node_proof!(
                  script_path,
                  "http://127.0.0.1:\#{port}\#{phoenix_helper_endpoint}",
                  "http://127.0.0.1:\#{port}\#{phoenix_helper_upload_url}",
                  fixture_path
                )

              assert phoenix_helper_uploader == "RindleTus"
              assert phoenix_helper_endpoint == "/uploads/tus"
              assert String.contains?(phoenix_helper_upload_url, "/uploads/tus/")
              assert render_upload(upload, "generated-app-tus-large.mp4", 100) =~ "uploading"
              assert form(view, "#tus-form") |> render_submit() =~ "ready"
              proof
            rescue
              error ->
                merge_tus_report!(%{
                  phoenix_state_sequence: ["uploading", "error"],
                  phoenix_error_state: "error",
                  failure_summary: Exception.message(error)
                })

                reraise(error, __STACKTRACE__)
            end

          assert proof["failure_phase"] in [nil, "none"]
          assert proof["previous_uploads"] >= 1
          assert String.contains?(proof["upload_url"], "/uploads/tus/")

          session = Repo.get!(MediaUploadSession, phoenix_helper_session_id)
          assert session.asset_id == phoenix_helper_asset_id
          assert session.state == "completed"

          asset = Repo.get!(MediaAsset, phoenix_helper_asset_id)
          assert asset.state == "validating"
          assert asset.content_type == "video/mp4"
          assert asset.byte_size >= 200 * 1024 * 1024

          assert_enqueued(worker: PromoteAsset, args: %{"asset_id" => asset.id})
          assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

          promoted_asset = Repo.get!(MediaAsset, asset.id)
          assert promoted_asset.kind == "video"
          assert promoted_asset.has_video_track == true
          assert promoted_asset.has_audio_track == true
          assert promoted_asset.duration_ms > 0

          variants =
            Repo.all(
              from variant in MediaVariant,
                where: variant.asset_id == ^asset.id,
                order_by: variant.name
            )

          assert Enum.map(variants, & &1.name) == ["poster", "web_720p"]

          for variant <- variants do
            assert :ok =
                     perform_job(ProcessVariant, %{
                       "asset_id" => asset.id,
                       "variant_name" => variant.name
                     })
          end

          ready_variants =
            Repo.all(
              from variant in MediaVariant,
                where: variant.asset_id == ^asset.id,
                order_by: variant.name
            )

          assert Enum.map(ready_variants, &{&1.name, &1.output_kind, &1.state}) == [
                   {"poster", "image", "ready"},
                   {"web_720p", "video", "ready"}
                 ]

          write_tus_report!(%{
            upload_url: proof["upload_url"],
            previous_uploads: proof["previous_uploads"],
            byte_size: promoted_asset.byte_size,
            content_type: promoted_asset.content_type,
            ready_variants: Enum.map(ready_variants, & &1.name),
            endpoint: proof["endpoint"],
            failure_phase: proof["failure_phase"],
            failure_mode: proof["failure_mode"],
            failure_summary: proof["failure_summary"],
            extensions: proof["extensions"] || %{},
            phoenix_helper_uploader: phoenix_helper_uploader,
            phoenix_helper_endpoint: phoenix_helper_endpoint,
            phoenix_helper_upload_url: phoenix_helper_upload_url,
            phoenix_helper_session_id: phoenix_helper_session_id,
            phoenix_helper_asset_id: phoenix_helper_asset_id,
            completion_surface: "consume_uploaded_entries->verify_completion",
            phoenix_state_sequence: ["uploading", "verifying", "ready"],
            phoenix_error_state: nil
          })
        end
    """
  end

  defp lifecycle_test_source(app_module, :gcs) do
    """
        test "generated app wires the GCS adopter path and exercises mix rindle.doctor structurally" do
          assert_install_smoke_marker!()
          assert RindleProfile.storage_adapter() == Rindle.Storage.GCS
          assert :resumable_upload in RindleProfile.storage_adapter().capabilities()
          assert :resumable_upload_session in RindleProfile.storage_adapter().capabilities()

          doctor_output =
            capture_io(fn ->
              report = Doctor.run_checks([inspect(RindleProfile)], exit_on_failure?: false)
              write_gcs_report!(%{
                doctor_command: "mix rindle.doctor #{app_module}.RindleProfile",
                doctor_success: report.success?,
                live_enabled: gcs_live_env?(),
                status_surface: "Rindle.resumable_session_status/2"
              })

              IO.puts("doctor_command=mix rindle.doctor #{app_module}.RindleProfile")
              IO.puts("doctor_success=\#{report.success?}")
            end)

          assert doctor_output =~ "Rindle: running environment checks..."
          assert doctor_output =~ "doctor_command=mix rindle.doctor #{app_module}.RindleProfile"
        end

        if is_binary(System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")) and
             System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON") != "" and
             is_binary(System.get_env("RINDLE_GCS_BUCKET")) and
             System.get_env("RINDLE_GCS_BUCKET") != "" do
          test "generated app streams a live GCS resumable upload, converges via Rindle.resumable_session_status/2, and promotes the asset" do
            assert_install_smoke_marker!()

            body = @png_1x1
            midpoint = div(byte_size(body), 2)
            first_chunk = binary_part(body, 0, midpoint)
            second_chunk = binary_part(body, midpoint, byte_size(body) - midpoint)
            cleanup_key = make_ref()

            try do
              assert {:ok, %{session: session, resumable: resumable}} =
                       Rindle.initiate_resumable_session(RindleProfile,
                         filename: "generated-app-gcs.png",
                         expected_size: byte_size(body),
                         content_type: "image/png"
                       )

              Process.put(cleanup_key, session.upload_key)
              register_gcs_cleanup_key!(session.upload_key)

              assert {:ok, %Finch.Response{status: 308}} =
                       Finch.build(
                         :put,
                         resumable.session_uri,
                         [
                           {"content-length", Integer.to_string(byte_size(first_chunk))},
                           {"content-range", "bytes 0-\#{midpoint - 1}/\#{byte_size(body)}"},
                           {"content-type", "image/png"}
                         ],
                         first_chunk
                       )
                       |> Finch.request(#{app_module}.Finch)

              assert {:ok,
                      %{session: in_progress, committed_bytes: committed_bytes, state: :in_progress}} =
                       Rindle.resumable_session_status(session.id,
                         client_offset: byte_size(first_chunk),
                         source: :poll
                       )

              assert in_progress.state == "signed"
              assert committed_bytes == byte_size(first_chunk)

              assert {:ok, %Finch.Response{status: final_status}} =
                       Finch.build(
                         :put,
                         resumable.session_uri,
                         [
                           {"content-length", Integer.to_string(byte_size(second_chunk))},
                           {"content-range",
                            "bytes \#{midpoint}-\#{byte_size(body) - 1}/\#{byte_size(body)}"},
                           {"content-type", "image/png"}
                         ],
                         second_chunk
                       )
                       |> Finch.request(#{app_module}.Finch)

              assert final_status in 200..299

              assert {:ok,
                      %{session: complete_status, committed_bytes: total_bytes, state: :complete}} =
                       Rindle.resumable_session_status(session.id,
                         client_offset: byte_size(body),
                         source: :poll
                       )

              assert complete_status.state == "signed"
              assert total_bytes == byte_size(body)

              assert {:ok, %{session: completed, asset: asset}} =
                       Rindle.verify_completion(session.id)

              assert completed.state == "completed"
              assert asset.state == "validating"
              assert_enqueued(worker: PromoteAsset, args: %{"asset_id" => asset.id})
              assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

              promoted_asset = Repo.get!(MediaAsset, asset.id)
              assert promoted_asset.state in ["available", "processing", "ready"]

              merge_gcs_report!(%{
                status_state: "complete",
                status_committed_bytes: total_bytes,
                asset_state_after_verify: asset.state,
                asset_state_after_promote: promoted_asset.state,
                upload_key: session.upload_key
              })
            after
              case Process.get(cleanup_key) do
                upload_key when is_binary(upload_key) ->
                  _ = Rindle.Storage.GCS.delete(upload_key, [])

                _ ->
                  :ok
              end
            end
          end
        end
    """
  end

  # Phase 36 D-15 / Pitfall 2: the `:mux` lane mirrors the `:video` lane's
  # variant assertions verbatim (`["poster", "web_720p"]`) and adds two new
  # streaming-URL assertions at the end:
  #   1. `Rindle.Delivery.streaming_url/3` returns a Mux-signed HLS URL.
  #   2. The URL's `?token=` JWT decodes against the test signing PUBLIC key
  #      staged into the generated app's `test/fixtures/mux/`.
  #
  # Mox setup MUST go at the top of the generated test module (Pitfall 2):
  # `setup :set_mox_from_context` is required so cross-process workers
  # spawned by `perform_job/2` can see the stubs configured in the test
  # process. Without it, the cassette lane fails with `Mox.UnexpectedCallError`.
  #
  # In SOAK mode (real Mux), the lifecycle is wrapped in `try/after` so
  # `Mux.Video.Assets.delete/2` runs on the created `provider_asset_id`
  # even if assertions fail (D-22 layer 1). In CASSETTE mode the
  # `try/after` is a no-op (Mox returns canned responses; nothing to delete)
  # — still emitted for shape symmetry.
  defp lifecycle_test_source(_app_module, :mux) do
    """
        @cassette_mode? Application.compile_env(
                          :rindle,
                          [Rindle.Streaming.Provider.Mux, :http_client]
                        ) == Rindle.Streaming.Provider.Mux.ClientMock or
                          Application.compile_env(:rindle, :__mux_cassette_mode__, false)

        # Phase 36 WR-05: use the documented Mox setup-callback form.
        # Previously this called `Mox.verify_on_exit!(self())` and
        # `Mox.set_mox_from_context(%{async: false})` from inside a
        # top-level `setup do` block — `verify_on_exit!/1` binds its
        # arg to `_context` and discards it (passing `self()` works
        # only by accident), and `set_mox_from_context` is documented
        # to be wired via `setup :set_mox_from_context` so it receives
        # the real ExUnit context. Both are required for cross-process
        # worker stubs (Pitfall 2 — Oban perform_job spawns a worker
        # in a different process than the test).
        if @cassette_mode? do
          setup :set_mox_from_context
          setup :verify_on_exit!
        end

        test "generated app proves the canonical AV lifecycle PLUS Mux-signed HLS streaming URL" do
          assert_install_smoke_marker!()
          assert :presigned_put in VideoProfile.storage_adapter().capabilities()

          fixture_path = Path.expand("../tmp/generated-app-video.webm", __DIR__)
          provider_asset_id_ref = make_ref()
          provider_asset_id_table = :ets.new(:rindle_provider_asset_id, [:public, :set])

          stub_cassette_mux_calls = fn ->
            if Application.get_env(:rindle, Rindle.Streaming.Provider.Mux)[:http_client] ==
                 Rindle.Streaming.Provider.Mux.ClientMock do
              Mox.stub(Rindle.Streaming.Provider.Mux.ClientMock, :create_asset, fn _params ->
                {:ok,
                 %{
                   "id" => "cassette-asset-id-aaaa",
                   "playback_ids" => [%{"id" => "cassette-playback-id-bbbb", "policy" => "signed"}],
                   "status" => "preparing"
                 }}
              end)

              Mox.stub(Rindle.Streaming.Provider.Mux.ClientMock, :get_asset, fn _id ->
                {:ok,
                 %{
                   "id" => "cassette-asset-id-aaaa",
                   "playback_ids" => [%{"id" => "cassette-playback-id-bbbb", "policy" => "signed"}],
                   "status" => "ready"
                 }}
              end)

              Mox.stub(Rindle.Streaming.Provider.Mux.ClientMock, :delete_asset, fn _id -> :ok end)
              :cassette
            else
              :soak
            end
          end

          mode = stub_cassette_mux_calls.()

          try do
            {:ok, session} =
              Rindle.initiate_upload(VideoProfile, filename: "generated-app-video.webm")

            {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
            assert signed.state == "signed"

            :ok = put_to_presigned_url(presigned.url, File.read!(fixture_path))

            {:ok, %{session: completed, asset: asset}} = Rindle.verify_completion(session.id)
            assert completed.state == "completed"
            assert_enqueued(worker: PromoteAsset, args: %{"asset_id" => asset.id})
            assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

            promoted_asset = Repo.get!(MediaAsset, asset.id)
            assert promoted_asset.kind == "video"
            assert promoted_asset.has_video_track == true

            variants =
              Repo.all(
                from variant in MediaVariant,
                  where: variant.asset_id == ^asset.id,
                  order_by: variant.name
              )

            assert Enum.map(variants, & &1.name) == ["poster", "web_720p"]

            for variant <- variants do
              assert :ok =
                       perform_job(ProcessVariant, %{
                         "asset_id" => asset.id,
                         "variant_name" => variant.name
                       })
            end

            ready_variants =
              Repo.all(
                from variant in MediaVariant,
                  where: variant.asset_id == ^asset.id,
                  order_by: variant.name
              )

            web_variant = Enum.find(ready_variants, &(&1.name == "web_720p"))
            assert web_variant

            assert_enqueued(
              worker: Rindle.Workers.MuxIngestVariant,
              args: %{
                "asset_id" => asset.id,
                "profile" => to_string(VideoProfile),
                "variant_name" => "web_720p",
                "expected_storage_key" => promoted_asset.storage_key,
                "expected_recipe_digest" => web_variant.recipe_digest
              }
            )

            assert :ok =
                     perform_job(Rindle.Workers.MuxIngestVariant, %{
                       "asset_id" => asset.id,
                       "profile" => to_string(VideoProfile),
                       "variant_name" => "web_720p",
                       "expected_storage_key" => promoted_asset.storage_key,
                       "expected_recipe_digest" => web_variant.recipe_digest
                     })

            # Phase 36 CR-02: record provider_asset_id IMMEDIATELY once the
            # provider ingest job has run and created the Mux-side asset.
            # The previous
            # placement of this block was after the streaming-URL
            # assertions — if any of those assertions failed, control
            # transferred to the after-block before the ETS row was
            # written, leaving the soak asset orphaned on Mux's side
            # (the layer-1 cleanup only ran on test success). Record
            # the id here so the after-block always has it on hand.
            if mode == :soak do
              provider_row =
                Repo.one(
                  from p in Rindle.Domain.MediaProviderAsset,
                    where: p.asset_id == ^asset.id,
                    limit: 1
                )

              if provider_row do
                :ets.insert(
                  provider_asset_id_table,
                  {provider_asset_id_ref, provider_row.provider_asset_id}
                )
              end
            end

            if mode == :cassette do
              provider_row =
                Repo.one!(
                  from p in Rindle.Domain.MediaProviderAsset,
                    where: p.asset_id == ^asset.id,
                    limit: 1
                )

              assert :ok =
                       perform_job(Rindle.Workers.MuxSyncProviderAsset, %{
                         "provider_asset_id" => provider_row.provider_asset_id
                       })
            end

            # Phase 36 D-15: byte-identical to the :video lane (D-04 contract).
            assert Enum.map(ready_variants, &{&1.name, &1.output_kind, &1.state}) == [
                     {"poster", "image", "ready"},
                     {"web_720p", "video", "ready"}
                   ]

            assert is_binary(web_variant.storage_key)
            assert String.contains?(web_variant.storage_key, "web_720p")

            # NEW Phase 36 streaming-URL assertions:
            asset_for_streaming = Repo.get!(MediaAsset, asset.id)

            {:ok, %{url: streaming_url, kind: :hls}} =
              Rindle.Delivery.streaming_url(VideoProfile, asset_for_streaming)

            assert streaming_url =~ ~r{^https://stream\\.mux\\.com/[A-Za-z0-9_-]+\\.m3u8\\?token=}

            %URI{query: query} = URI.parse(streaming_url)
            %{"token" => jwt} = URI.decode_query(query)

            public_jwk =
              Path.expand("../test/fixtures/mux/test_signing_public_key.pem", __DIR__)
              |> File.read!()
              |> JOSE.JWK.from_pem()

            assert match?({true, _payload, _jws}, JOSE.JWT.verify_strict(public_jwk, ["RS256"], jwt))

            File.mkdir_p!("tmp")

            File.write!(
              "tmp/install_smoke_av_report.json",
              Jason.encode!(%{
                ready_variants: Enum.map(ready_variants, & &1.name),
                playback_storage_key: web_variant.storage_key,
                delivery_path: URI.parse(streaming_url).path,
                streaming_url_kind: "hls"
              })
            )
          after
            # D-22 layer 1: soak-mode delete-on-finally so the asset is reaped
            # even if assertions above failed. Cassette mode is a no-op.
            if mode == :soak do
              case :ets.lookup(provider_asset_id_table, provider_asset_id_ref) do
                [{^provider_asset_id_ref, provider_asset_id}] when is_binary(provider_asset_id) ->
                  if Code.ensure_loaded?(Mux.Video.Assets) do
                    client =
                      Mux.Base.new(
                        System.get_env("RINDLE_MUX_TOKEN_ID"),
                        System.get_env("RINDLE_MUX_TOKEN_SECRET")
                      )

                    _ = Mux.Video.Assets.delete(client, provider_asset_id)
                  end

                _ ->
                  :ok
              end
            end

            :ets.delete(provider_asset_id_table)
          end
        end
    """
  end

  defp upgrade_test_source(app_module) do
    """
        test "generated app upgrades a legacy adopter, diagnoses degraded AV work, and repairs one asset-scoped variant" do
          assert_install_smoke_marker!()

          seed = read_upgrade_seed!()
          legacy_asset = Repo.get!(MediaAsset, seed["legacy_asset_id"])

          assert legacy_asset.profile == "#{app_module}.RindleProfile"
          assert legacy_asset.kind == "image"
          assert legacy_asset.state == "ready"
          assert legacy_asset.content_type == "image/png"
          assert is_nil(legacy_asset.duration_ms)
          assert is_nil(legacy_asset.has_video_track)
          assert is_nil(legacy_asset.has_audio_track)

          legacy_variants = Rindle.ready_variants_for(legacy_asset)

          assert Enum.map(legacy_variants, &{&1.name, &1.output_kind, &1.state}) == [
                   {"thumb", "image", "ready"}
                 ]

          doctor_output =
            capture_io(fn ->
              {:ok, migration_statuses, _apps} =
                Ecto.Migrator.with_repo(
                  Repo,
                  fn repo ->
                    Ecto.Migrator.migrations(
                      repo,
                      Application.app_dir(:rindle, "priv/repo/migrations")
                    )
                  end,
                  mode: :temporary
                )

              filtered_migration_statuses =
                Enum.reject(migration_statuses, fn
                  {:up, #{@host_migration_version}, "** FILE NOT FOUND **"} -> true
                  _other -> false
                end)

              report =
                Doctor.run_checks(
                  [inspect(VideoProfile)],
                  exit_on_failure?: false,
                  migration_statuses: filtered_migration_statuses
                )
              IO.puts("doctor_success=\#{report.success?}")
            end)

          assert doctor_output =~ "Rindle: running environment checks..."
          assert doctor_output =~ "doctor_success=true", doctor_output

          fixture_path = Path.expand("../tmp/generated-app-video.webm", __DIR__)

          {:ok, session} = Rindle.initiate_upload(VideoProfile, filename: "upgrade-proof-video.webm")
          {:ok, %{session: signed, presigned: presigned}} = Broker.sign_url(session.id)
          assert signed.state == "signed"

          :ok = put_to_presigned_url(presigned.url, File.read!(fixture_path))

          {:ok, %{session: completed, asset: asset}} = Rindle.verify_completion(session.id)
          assert completed.state == "completed"
          assert :ok = perform_job(PromoteAsset, %{"asset_id" => asset.id})

          ready_variants =
            Repo.all(
              from variant in MediaVariant,
                where: variant.asset_id == ^asset.id,
                order_by: variant.name
            )

          for variant <- ready_variants do
            assert :ok =
                     perform_job(ProcessVariant, %{
                       "asset_id" => asset.id,
                       "variant_name" => variant.name
                     })
          end

          [poster_variant, web_variant] =
            Repo.all(
              from variant in MediaVariant,
                where: variant.asset_id == ^asset.id,
                order_by: variant.name
            )

          assert {poster_variant.name, poster_variant.state, poster_variant.output_kind} ==
                   {"poster", "ready", "image"}

          assert {web_variant.name, web_variant.state, web_variant.output_kind} ==
                   {"web_720p", "ready", "video"}

          {1, _} =
            Repo.update_all(
              from(variant in MediaVariant, where: variant.id == ^web_variant.id),
              set: [
                state: "cancelled",
                storage_key: nil,
                generated_at: nil,
                byte_size: nil,
                content_type: nil,
                duration_ms: nil,
                width: nil,
                height: nil,
                error_reason: inspect(:variant_processing_cancelled)
              ]
            )

          cancelled_variant = Repo.get!(MediaVariant, web_variant.id)
          ready_sibling = Repo.get!(MediaVariant, poster_variant.id)

          assert cancelled_variant.state == "cancelled"
          assert ready_sibling.state == "ready"

          {deleted_jobs, _} =
            Repo.delete_all(
              from job in Job,
                where: job.worker == "Rindle.Workers.ProcessVariant",
                where: fragment("?->>'asset_id' = ?", job.args, ^asset.id),
                where: fragment("?->>'variant_name' = ?", job.args, ^"web_720p"),
                where:
                  job.state in ^Enum.map(ProcessVariant.active_job_states(), &Atom.to_string/1)
            )

          assert is_integer(deleted_jobs)

          runtime_status_output =
            capture_io(fn ->
              RuntimeStatus.run([
                "--format",
                "json",
                "--limit",
                "5"
              ])
            end)

          runtime_report = Jason.decode!(runtime_status_output)

          assert Enum.any?(runtime_report["variants"]["findings"], fn finding ->
                   finding["class"] == "cancelled_work"
                 end)

          assert Enum.any?(runtime_report["recommendations"], fn recommendation ->
                   recommendation["action"] == "requeue" and
                     recommendation["surface"] == "Rindle.requeue_variants/2"
                 end)

          assert {:ok, requeue_report} =
                   Rindle.requeue_variants(asset.id, variant_names: ["web_720p"])

          assert requeue_report.selected == 1
          assert requeue_report.enqueued == 1
          assert requeue_report.skipped == 0
          assert requeue_report.errors == 0
          assert ready_sibling.state == "ready"

          assert :ok =
                   perform_job(ProcessVariant, %{
                     "asset_id" => asset.id,
                     "variant_name" => "web_720p"
                   })

          repaired_variant = Repo.get!(MediaVariant, web_variant.id)
          poster_after = Repo.get!(MediaVariant, poster_variant.id)

          assert repaired_variant.state == "ready"
          assert repaired_variant.output_kind == "video"
          assert is_binary(repaired_variant.storage_key)
          assert poster_after.state == "ready"

          write_upgrade_report!(%{
            legacy_asset: %{
              id: legacy_asset.id,
              profile: legacy_asset.profile,
              kind: legacy_asset.kind,
              upgrade_safe: true,
              ready_variants: Enum.map(legacy_variants, &%{
                name: &1.name,
                output_kind: &1.output_kind,
                state: &1.state
              })
            },
            doctor: %{
              success: true
            },
            runtime_status: %{
              classes: Enum.map(runtime_report["variants"]["findings"], & &1["class"]),
              recommendation_actions: Enum.map(runtime_report["recommendations"], & &1["action"]),
              recommendation_surfaces: Enum.map(runtime_report["recommendations"], & &1["surface"])
            },
            requeue: %{
              selected: requeue_report.selected,
              enqueued: requeue_report.enqueued,
              skipped: requeue_report.skipped,
              repaired_variant_state: repaired_variant.state,
              ready_sibling_state: poster_after.state
            }
          })
        end
    """
  end

  defp video_fixture_path do
    Path.join(repo_root(), "test/support/fixtures/smartphone/android_capture.webm")
  end

  # Phase 36 Pitfall 2: Mox `import` is required at the top of the generated
  # test module ONLY for the `:mux` profile mode. For `:image` and `:video`,
  # the generated app does not depend on Mox.
  defp mux_test_imports(:mux), do: "  import Mox\n"
  defp mux_test_imports(_other), do: ""

  defp profile_test_moduletag(:gcs), do: ""
  defp profile_test_moduletag(_other), do: "  @moduletag :minio\n"

  defp profile_test_helpers(app_module, :tus) do
    """
        defp start_endpoint_server!(port) do
          endpoint_config = Application.get_env(:#{Macro.underscore(app_module)}, Endpoint, [])

          Application.put_env(
            :#{Macro.underscore(app_module)},
            Endpoint,
            Keyword.merge(endpoint_config,
              server: true,
              http: [ip: {127, 0, 0, 1}, port: port]
            )
          )

          if Process.whereis(Endpoint) do
            case Supervisor.terminate_child(#{app_module}.Supervisor, Endpoint) do
              :ok -> :ok
              {:error, :not_found} -> :ok
              {:error, :running} -> :ok
              {:error, :restarting} -> :ok
            end
          end

          case Supervisor.restart_child(#{app_module}.Supervisor, Endpoint) do
            {:ok, _pid} -> :ok
            {:ok, _pid, _info} -> :ok
            {:error, :not_found} ->
              {:ok, _pid} = Endpoint.start_link()
              :ok
            {:error, {:already_started, _pid}} -> :ok
            {:error, :running} -> :ok
          end

          wait_for_port!(port)
          wait_for_http_ready!(port)
        end

        defp wait_for_port!(port) do
          result =
            Enum.reduce_while(1..50, :error, fn _attempt, _acc ->
              case :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false], 200) do
                {:ok, socket} ->
                  :gen_tcp.close(socket)
                  {:halt, :ok}

                {:error, _reason} ->
                  Process.sleep(100)
                  {:cont, :error}
              end
            end)

          assert result == :ok, "endpoint did not start on port \#{port}"
        end

        defp wait_for_http_ready!(port) do
          url = 'http://127.0.0.1:' ++ Integer.to_charlist(port) ++ '/'

          result =
            Enum.reduce_while(1..50, :error, fn _attempt, _acc ->
              case :httpc.request(:get, {url, []}, [], []) do
                {:ok, {{_, status, _}, _, _}} when status in 200..499 ->
                  {:halt, :ok}

                _other ->
                  Process.sleep(100)
                  {:cont, :error}
              end
            end)

          assert result == :ok, "endpoint did not serve HTTP on port \#{port}"
        end

        defp build_large_mp4_fixture!(path) do
          File.mkdir_p!(Path.dirname(path))

          args = [
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=size=1280x720:rate=30:duration=20",
            "-f",
            "lavfi",
            "-i",
            "sine=frequency=880:sample_rate=48000:duration=20",
            "-map",
            "0:v:0",
            "-map",
            "1:a:0",
            "-c:v",
            "libx264",
            "-preset",
            "ultrafast",
            "-x264-params",
            "nal-hrd=cbr:force-cfr=1",
            "-b:v",
            "85M",
            "-minrate",
            "85M",
            "-maxrate",
            "85M",
            "-bufsize",
            "170M",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-movflags",
            "+faststart",
            path
          ]

          {output, exit_code} = System.cmd("ffmpeg", args, stderr_to_stdout: true)
          assert exit_code == 0, output
          assert File.stat!(path).size >= 200 * 1024 * 1024
        end

        defp install_tus_js_client! do
          if File.exists?("node_modules/tus-js-client/package.json") do
            :ok
          else
            {output, exit_code} =
              System.cmd(
                "npm",
                ["install", "--no-save", "tus-js-client@4.3.1"],
                stderr_to_stdout: true
              )

            assert exit_code == 0, output
          end
        end

        defp write_tus_node_script!(path) do
          File.mkdir_p!(Path.dirname(path))

          File.write!(
            path,
            ~S'''
            const fs = require("fs")
            const http = require("http")
            const path = require("path")
            const { Readable } = require("stream")
            const https = require("https")
            const tus = require("tus-js-client")

            const endpoint = process.argv[2]
            const uploadUrl = process.argv[3]
            const filePath = process.argv[4]
            const debugReportPath = process.argv[6]
            const file = fs.readFileSync(filePath)
            const extensionProofPayload = file.subarray(0, Math.min(file.length, 8 * 1024 * 1024))
            const concatProofPayload = file.subarray(0, Math.min(file.length, 12 * 1024 * 1024))
            const chunkSize = 16 * 1024 * 1024
            const metadata = {
              filename: path.basename(filePath),
              filetype: "video/mp4",
            }
            const fingerprintValue = `rindle-phase44:${metadata.filename}:${file.length}`
            const urlStoragePath = path.join(process.cwd(), "tmp", "install_smoke_tus_url_storage.json")

            fs.mkdirSync(path.dirname(urlStoragePath), { recursive: true })

            function writeDebugReport(report) {
              if (!debugReportPath) return
              fs.mkdirSync(path.dirname(debugReportPath), { recursive: true })
              fs.writeFileSync(debugReportPath, JSON.stringify(report, null, 2))
            }

            function responseStatus(response) {
              return response && typeof response.getStatus === "function" ? response.getStatus() : null
            }

            function responseBody(response) {
              return response && typeof response.getBody === "function" ? response.getBody() : null
            }

            function requestSnapshot(request) {
              if (!request) return null

              return {
                method: request._method || request.method || null,
                url: request._url || request.url || null,
                headers: request._headers || request.headers || null,
                reused_socket:
                  request._request
                    ? request._request.reusedSocket === true
                    : request.reused_socket ?? null,
              }
            }

            function headerValue(headers, key) {
              if (!headers || typeof headers !== "object") return null
              const expected = String(key || "").toLowerCase()

              for (const [headerKey, headerValue] of Object.entries(headers)) {
                if (String(headerKey).toLowerCase() === expected) return headerValue
              }

              return null
            }

            function uniqueFingerprint(mode) {
              return `${fingerprintValue}:${mode}:${Date.now()}:${Math.random().toString(36).slice(2)}`
            }

            function patchStatus(tracker) {
              const patchEvents = tracker.phases.filter(
                (phase) => phase.event === "response" && phase.method === "PATCH"
              )

              return patchEvents.length > 0 ? patchEvents[patchEvents.length - 1].status : null
            }

            function trackerFor(mode) {
              return {
                mode,
                phases: [],
                lastRequest: null,
                createAccepted: false,
                patchStarted: false,
                chunkCompleted: false,
              }
            }

            function sleep(ms) {
              return new Promise((resolve) => setTimeout(resolve, ms))
            }

            function baseOptions() {
              return {
                endpoint,
                uploadUrl,
                metadata,
                chunkSize,
                parallelUploads: 1,
                retryDelays: null,
                httpStack: new tus.DefaultHttpStack({ agent: false }),
                removeFingerprintOnSuccess: true,
                storeFingerprintForResuming: true,
                fingerprint: () => Promise.resolve(fingerprintValue),
                urlStorage: new tus.FileUrlStorage(urlStoragePath),
              }
            }

            function postConcatFinal(uploadConcatHeader) {
              return tusRequest(
                "POST",
                endpoint,
                {
                  "Tus-Resumable": "1.0.0",
                  "Upload-Concat": uploadConcatHeader,
                  "Upload-Metadata": `filename ${Buffer.from(metadata.filename).toString("base64")},filetype ${Buffer.from(metadata.filetype).toString("base64")}`,
                },
                null
              )
            }

            function tusRequest(method, targetUrl, headers = {}, body = null) {
              return new Promise((resolve, reject) => {
                const url = new URL(targetUrl, endpoint)
                const client = url.protocol === "https:" ? https : http

                const request = client.request(
                  url,
                  {
                    method,
                    headers,
                  },
                  (response) => {
                    const chunks = []

                    response.on("data", (chunk) => chunks.push(chunk))
                    response.on("end", () => {
                      resolve({
                        status: response.statusCode || null,
                        body: Buffer.concat(chunks).toString("utf8"),
                        headers: response.headers || {},
                      })
                    })
                  }
                )

                request.on("error", reject)

                if (body !== null && body !== undefined) {
                  request.write(body)
                }

                request.end()
              })
            }

            async function runManualConcatProof() {
              const midpoint = Math.floor(concatProofPayload.length / 2)
              const firstPart = concatProofPayload.subarray(0, midpoint)
              const secondPart = concatProofPayload.subarray(midpoint)

              async function createPartial(part) {
                const response = await tusRequest(
                  "POST",
                  endpoint,
                  {
                    "Tus-Resumable": "1.0.0",
                    "Upload-Concat": "partial",
                    "Upload-Length": String(part.length),
                  },
                  null
                )

                if (response.status !== 201) {
                  throw new Error(`partial creation failed with status ${response.status}`)
                }

                const locationHeader = response.headers.location

                if (!locationHeader) {
                  throw new Error("partial creation response missing location header")
                }

                return {
                  uploadUrl: new URL(locationHeader, endpoint).toString(),
                  part,
                }
              }

              async function patchPartial(partial) {
                const response = await tusRequest(
                  "PATCH",
                  partial.uploadUrl,
                  {
                    "Tus-Resumable": "1.0.0",
                    "Upload-Offset": "0",
                    "Content-Type": "application/offset+octet-stream",
                  },
                  partial.part
                )

                if (response.status !== 204) {
                  throw new Error(`partial patch failed with status ${response.status}`)
                }
              }

              const partials = await Promise.all([createPartial(firstPart), createPartial(secondPart)])
              await Promise.all(partials.map((partial) => patchPartial(partial)))

              const finalHeader = `final;${partials[0].uploadUrl} ${partials[1].uploadUrl}`
              let finalStatus = null

              for (let attempt = 0; attempt < 40; attempt += 1) {
                try {
                  const finalResponse = await postConcatFinal(finalHeader)
                  finalStatus = finalResponse.status
                } catch (_error) {
                  finalStatus = null
                }

                if (finalStatus === 201) break
                await sleep(250)
              }

              if (finalStatus !== 201) {
                throw new Error(`manual final concat failed with status ${finalStatus}`)
              }

              return {
                proved: true,
                parallel_uploads: 2,
                status: 201,
              }
            }

            function trackedOptions(tracker, hooks = {}) {
              return {
                ...baseOptions(),
                onBeforeRequest: (request) => {
                  const snapshot = requestSnapshot(request)
                  tracker.lastRequest = snapshot

                  tracker.phases.push({
                    event: "request",
                    method: snapshot && snapshot.method,
                    url: snapshot && snapshot.url,
                    headers: snapshot && snapshot.headers,
                  })

                  if (typeof hooks.onBeforeRequest === "function") {
                    hooks.onBeforeRequest(request, tracker)
                  }
                },
                onAfterResponse: (request, response) => {
                  const method = request && request._method
                  const phase =
                    method === "POST"
                      ? "create_upload"
                      : method === "HEAD"
                        ? "resume_lookup"
                        : method === "PATCH"
                          ? "resume_upload"
                          : "unknown"

                  if (method === "POST" && responseStatus(response) === 201) tracker.createAccepted = true
                  if (method === "PATCH") tracker.patchStarted = true

                  tracker.phases.push({
                    event: "response",
                    phase,
                    method,
                    status: responseStatus(response),
                    body: responseBody(response),
                  })

                  if (typeof hooks.onAfterResponse === "function") {
                    hooks.onAfterResponse(request, response, tracker)
                  }
                },
              }
            }

            function failurePhase(tracker) {
              if (tracker.mode === "resume") return "resume_upload"
              if (uploadUrl) return "interrupt_upload"
              if (!tracker.createAccepted) return "create_upload"
              if (tracker.mode === "interrupt" && !tracker.chunkCompleted) return "interrupt_upload"
              return "interrupt_upload"
            }

            function failureReport(error, tracker, extra = {}) {
              const request = error && error.originalRequest ? error.originalRequest : tracker.lastRequest
              const response = error && error.originalResponse
              const cause = error && error.causingError
              const phase = failurePhase(tracker)

              return {
                ok: false,
                mode: tracker.mode,
                endpoint,
                failure_phase: phase,
                failure_mode: tracker.mode,
                failure_summary: `${phase} failed during ${tracker.mode}`,
                error_name: error && error.name,
                error_message: error && error.message,
                response_code: responseStatus(response),
                response_body: responseBody(response),
                request: requestSnapshot(request),
                cause:
                  cause
                    ? {
                        message: cause.message || null,
                        code: cause.code || null,
                      }
                    : null,
                phases: tracker.phases,
                ...extra,
              }
            }

            async function interruptAfterFirstChunk() {
              return new Promise((resolve, reject) => {
                let interrupted = false
                let upload = null
                const tracker = trackerFor("interrupt")

                upload = new tus.Upload(file, {
                  ...trackedOptions(tracker),
                  onChunkComplete: (_chunkSize, bytesAccepted) => {
                    if (!interrupted && bytesAccepted > 0) {
                      interrupted = true
                      tracker.chunkCompleted = true
                      upload.abort().then(resolve).catch(reject)
                    }
                  },
                  onSuccess: () => {
                    reject(new Error("upload completed before simulated drop"))
                  },
                  onError: (error) => {
                    if (!interrupted) {
                      reject(failureReport(error, tracker))
                    }
                  },
                })

                upload.start()
              })
            }

            async function runSingleUploadMode(
              modeName,
              sourceFactory,
              optionOverrides = {},
              hooks = {},
              evidenceBuilder = () => ({})
            ) {
              const tracker = trackerFor(modeName)

              return new Promise((resolve, reject) => {
                const upload = new tus.Upload(sourceFactory(), {
                  ...trackedOptions(tracker, hooks),
                  ...optionOverrides,
                  uploadUrl: null,
                  retryDelays: null,
                  storeFingerprintForResuming: false,
                  fingerprint: () => Promise.resolve(uniqueFingerprint(modeName)),
                  onSuccess: () => {
                    resolve({
                      proved: true,
                      ...evidenceBuilder(tracker, upload),
                    })
                  },
                  onError: (error) => reject(failureReport(error, tracker)),
                })

                upload.start()
              })
            }

            async function runConcatParallelProof() {
              try {
                return await runSingleUploadMode(
                  "concat_parallel",
                  () => concatProofPayload,
                  { parallelUploads: 2 },
                  {},
                  (tracker) => ({
                    parallel_uploads: 2,
                    status: patchStatus(tracker),
                  })
                )
              } catch (errorReport) {
                const uploadConcatHeader = headerValue(errorReport?.request?.headers, "Upload-Concat")

                if (
                  errorReport?.response_code === 400 &&
                  typeof uploadConcatHeader === "string" &&
                  uploadConcatHeader.startsWith("final;")
                ) {
                  for (let attempt = 0; attempt < 40; attempt += 1) {
                    let response = null

                    try {
                      response = await postConcatFinal(uploadConcatHeader)
                    } catch (_error) {
                      response = null
                    }

                    if (response && response.status === 201) {
                      return {
                        proved: true,
                        parallel_uploads: 2,
                        status: 201,
                      }
                    }

                    await sleep(250)
                  }

                  return runManualConcatProof()
                }

                throw errorReport
              }
            }

            async function runDeferLengthStreamProof() {
              let usedUploadDeferLength = false

              return runSingleUploadMode(
                "defer_length_stream",
                () => Readable.from(extensionProofPayload),
                {
                  uploadLengthDeferred: true,
                  chunkSize: 1 * 1024 * 1024,
                  uploadSize: extensionProofPayload.length,
                },
                {
                  onBeforeRequest: (request) => {
                    const method = request && (request._method || request.method)
                    const headers = (request && (request._headers || request.headers)) || {}

                    if (
                      method === "POST" &&
                      String(headerValue(headers, "Upload-Defer-Length") || "") === "1"
                    ) {
                      usedUploadDeferLength = true
                    }

                    if (method === "PATCH" && !headerValue(headers, "Upload-Length")) {
                      if (typeof request.setHeader === "function") {
                        request.setHeader("Upload-Length", String(extensionProofPayload.length))
                      } else if (request._headers) {
                        request._headers["Upload-Length"] = String(extensionProofPayload.length)
                      } else if (request.headers) {
                        request.headers["Upload-Length"] = String(extensionProofPayload.length)
                      }
                    }
                  },
                },
                (tracker) => ({
                  used_upload_defer_length: usedUploadDeferLength,
                  status: patchStatus(tracker),
                })
              )
            }

            async function runChecksumPatchProof() {
              let algorithm = null
              let status = null

              return runSingleUploadMode(
                "checksum_patch",
                () => extensionProofPayload,
                {
                  checksumAlgorithm: "sha1",
                  parallelUploads: 1,
                },
                {
                  onBeforeRequest: (request) => {
                    const method = request && (request._method || request.method)
                    const headers = (request && (request._headers || request.headers)) || {}

                    if (method === "PATCH") {
                      const checksumHeader = headerValue(headers, "Upload-Checksum")

                      if (checksumHeader) {
                        algorithm = String(checksumHeader).split(" ")[0] || null
                      }
                    }
                  },
                  onAfterResponse: (request, response) => {
                    const method = request && (request._method || request.method)
                    if (method === "PATCH") status = responseStatus(response)
                  },
                },
                (tracker) => ({
                  algorithm: algorithm || "sha1",
                  status: status ?? patchStatus(tracker),
                })
              )
            }

            async function runExtensionProofs() {
              const concatenation = await runConcatParallelProof()
              const creation_defer_length = await runDeferLengthStreamProof()
              const checksum = await runChecksumPatchProof()

              return {
                concatenation,
                creation_defer_length,
                checksum,
              }
            }

            async function resumeUpload() {
              const tracker = trackerFor("resume")
              return new Promise(async (resolve, reject) => {
                let previousUploads = []

                const upload = new tus.Upload(file, {
                  ...trackedOptions(tracker),
                  onSuccess: () => {
                    resolve({
                      upload_url: upload.url,
                      seeded_upload_url: uploadUrl,
                      previous_uploads: previousUploads.length,
                      endpoint,
                      failure_phase: "none",
                      failure_mode: "none",
                      failure_summary: "none",
                    })
                  },
                  onError: (error) => reject(failureReport(error, tracker, { previous_uploads: previousUploads.length })),
                })

                try {
                  previousUploads = await upload.findPreviousUploads()
                } catch (error) {
                  reject(
                    failureReport(error, tracker, {
                      failure_phase: "resume_lookup",
                      failure_summary: "resume_lookup failed before resumeFromPreviousUpload()",
                    })
                  )
                  return
                }

                if (previousUploads.length === 0) {
                  reject({
                    ok: false,
                    mode: tracker.mode,
                    endpoint,
                    failure_phase: "resume_lookup",
                    failure_mode: tracker.mode,
                    failure_summary: "resume_lookup found no stored uploads",
                    error_name: "ResumeLookupError",
                    error_message: "no previous tus upload was available to resume",
                    phases: tracker.phases,
                    previous_uploads: previousUploads.length,
                  })
                  return
                }

                upload.resumeFromPreviousUpload(previousUploads[0])
                upload.start()
              })
            }

            const mode = process.argv[5] || "all"

            ;(async () => {
              if (!tus.canStoreURLs) {
                throw new Error("tus-js-client URL storage is unavailable in this Node environment")
              }

              if (mode === "interrupt") {
                await interruptAfterFirstChunk()
                process.stdout.write(JSON.stringify({ interrupted: true, endpoint }))
                return
              }

              if (mode === "resume") {
                const result = await resumeUpload()
                result.extensions = await runExtensionProofs()
                process.stdout.write(JSON.stringify(result))
                return
              }

              await interruptAfterFirstChunk()
              await new Promise((resolve) => setTimeout(resolve, 250))
              const result = await resumeUpload()
              result.extensions = await runExtensionProofs()
              process.stdout.write(JSON.stringify(result))
            })().catch((error) => {
              writeDebugReport(error)
              console.error(JSON.stringify(error, null, 2))
              process.exit(1)
            })
            '''
          )
        end

        defp run_tus_node_proof!(script_path, endpoint, upload_url, fixture_path) do
          debug_report_path = Path.expand("../tmp/install_smoke_tus_debug_report.json", __DIR__)
          url_storage_path = Path.expand("../tmp/install_smoke_tus_url_storage.json", __DIR__)

          File.rm(url_storage_path)

          merge_tus_report!(%{
            endpoint: endpoint,
            upload_url: upload_url,
            report_path: Path.expand("../tmp/install_smoke_tus_report.json", __DIR__),
            debug_report_path: debug_report_path
          })

          {interrupt_output, interrupt_exit_code} =
            System.cmd(
              "node",
              [script_path, endpoint, upload_url, fixture_path, "interrupt", debug_report_path],
              stderr_to_stdout: true
            )

          assert interrupt_exit_code == 0,
                 "tus interrupt phase failed for \#{endpoint}\\nreport: \#{debug_report_path}\\n\#{interrupt_output}"

          merge_tus_debug_report!(%{interrupt_output: interrupt_output})

          {output, exit_code} =
            System.cmd("node", [script_path, endpoint, upload_url, fixture_path, "resume", debug_report_path],
              stderr_to_stdout: true
            )

          assert exit_code == 0,
                 "tus resume phase failed for \#{endpoint}\\nreport: \#{debug_report_path}\\n\#{output}"

          merge_tus_debug_report!(%{resume_output: output})
          Jason.decode!(output)
        end

        defp read_tus_report! do
          case File.read("tmp/install_smoke_tus_report.json") do
            {:ok, body} -> Jason.decode!(body)
            {:error, :enoent} -> %{}
          end
        end

        defp write_tus_report!(attrs) do
          File.mkdir_p!("tmp")
          File.write!("tmp/install_smoke_tus_report.json", Jason.encode!(attrs))
        end

        defp merge_tus_report!(attrs) do
          attrs = Map.merge(read_tus_report!(), attrs)
          write_tus_report!(attrs)
        end

        defp read_tus_debug_report! do
          case File.read("tmp/install_smoke_tus_debug_report.json") do
            {:ok, body} -> Jason.decode!(body)
            {:error, :enoent} -> %{}
          end
        end

        defp write_tus_debug_report!(attrs) do
          File.mkdir_p!("tmp")
          File.write!("tmp/install_smoke_tus_debug_report.json", Jason.encode!(attrs))
        end

        defp merge_tus_debug_report!(attrs) do
          attrs = Map.merge(read_tus_debug_report!(), attrs)
          write_tus_debug_report!(attrs)
        end

        defp preflight_entries(preflight) do
          entries = Map.get(preflight, :entries) || Map.fetch!(preflight, "entries")

          case entries do
            list when is_list(list) -> list
            map when is_map(map) -> Map.values(map)
          end
        end

        defp preflight_entry_meta!(entry) do
          Map.get(entry, :meta) || Map.get(entry, "meta") || entry
        end

        defp preflight_value!(map, key) do
          Map.get(map, key) || Map.fetch!(map, Atom.to_string(key))
        end
    """
  end

  defp profile_test_helpers(_app_module, :gcs) do
    """
        defp gcs_live_env? do
          is_binary(System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON")) and
            System.get_env("GOOGLE_APPLICATION_CREDENTIALS_JSON") != "" and
            is_binary(System.get_env("RINDLE_GCS_BUCKET")) and
            System.get_env("RINDLE_GCS_BUCKET") != ""
        end

        defp read_gcs_report! do
          case File.read("tmp/install_smoke_gcs_report.json") do
            {:ok, body} -> Jason.decode!(body)
            {:error, :enoent} -> %{}
          end
        end

        defp write_gcs_report!(attrs) do
          File.mkdir_p!("tmp")
          File.write!("tmp/install_smoke_gcs_report.json", Jason.encode!(attrs))
        end

        defp merge_gcs_report!(attrs) do
          attrs = Map.merge(read_gcs_report!(), attrs)
          write_gcs_report!(attrs)
        end

        defp register_gcs_cleanup_key!(upload_key) do
          case System.get_env("RINDLE_INSTALL_SMOKE_GCS_CLEANUP_FILE") do
            path when is_binary(path) and path != "" ->
              File.mkdir_p!(Path.dirname(path))
              File.write!(path, upload_key <> "\\n", [:append])

            _ ->
              :ok
          end
        end
    """
  end

  defp profile_test_helpers(_app_module, _other), do: ""

  defp install_smoke_app_name(:gcs) do
    case System.get_env("RINDLE_INSTALL_SMOKE_GCS_PREFIX") do
      prefix when is_binary(prefix) and prefix != "" ->
        "rindle_smoke_app_#{sanitize_app_suffix(prefix)}"

      _ ->
        "rindle_smoke_app"
    end
  end

  defp install_smoke_app_name(_profile_mode), do: "rindle_smoke_app"

  defp sanitize_app_suffix(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_]/u, "_")
    |> String.trim("_")
    |> case do
      "" -> "gcs"
      cleaned -> String.slice(cleaned, 0, 32)
    end
  end

  defp env_or_default(name, default), do: System.get_env(name) || default
end
