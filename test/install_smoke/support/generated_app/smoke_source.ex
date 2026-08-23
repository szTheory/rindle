defmodule Rindle.InstallSmoke.GeneratedApp.SmokeSource do
  @moduledoc false

  alias Rindle.InstallSmoke.GeneratedApp.ProfileHelpers
  alias Rindle.InstallSmoke.GeneratedApp.CommandRunner
  alias Rindle.InstallSmoke.GeneratedApp.Workspace

  @png_1x1 <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
             0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02, 0x00, 0x00,
             0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, 0x54, 0x08,
             0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F, 0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0x44, 0x74,
             0x06, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82>>
  @generated_command_timeout_ms :timer.minutes(20)

  def write!(
        root,
        app_module,
        profile_mode,
        network_version,
        extra_imports,
        profile_tag,
        profile_helpers
      ) do
    path = Path.join(root, "test/rindle_install_smoke_test.exs")
    lifecycle_test = lifecycle_test_source(app_module, profile_mode)
    upgrade_test = upgrade_test_source(app_module)

    deps_rindle_assertion =
      if network_version do
        """
              assert File.exists?(Path.join(File.cwd!(), "deps/rindle"))
        """
      else
        """
              refute File.exists?(Path.join(File.cwd!(), "deps/rindle"))
        """
      end

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

      #{profile_tag}

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
          assert function_exported?(Rindle.Migration, :up, 1)
          assert function_exported?(Rindle.Migration, :down, 1)
      #{deps_rindle_assertion}
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

        defp write_persistence_lifecycle!(facts) do
          File.mkdir_p!("tmp")

          File.write!(
            "tmp/install_smoke_persistence_lifecycle_report.json",
            Jason.encode!(facts)
          )
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

  def write_fixture!(root, profile_mode) do
    File.mkdir_p!(Path.join(root, "tmp"))
    File.write!(Path.join(root, "tmp/generated-app.png"), @png_1x1)

    if profile_mode in [:video, :tus, :mux] do
      File.cp!(
        ProfileHelpers.video_fixture_path(),
        Path.join(root, "tmp/generated-app-video.webm")
      )
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
    CommandRunner.run!(cwd, argv, env)
  end

  defp run_cmd(cwd, argv, env) do
    CommandRunner.run(cwd, argv, env, timeout_ms: @generated_command_timeout_ms)
  end

  defp shared_env(db_name, profile_mode), do: Workspace.shared_env(db_name, profile_mode)
  defp package_name, do: Workspace.package_name()
  defp install_mode(network_version), do: Workspace.install_mode(network_version)

  def package_root_provenance(mode, generated_app_root, package_root),
    do: Workspace.package_root_provenance(mode, generated_app_root, package_root)

  defp install_source(mode, package_root, network_version),
    do: Workspace.install_source(mode, package_root, network_version)

  defp repo_root, do: Workspace.repo_root()

  def maybe_write_tus_run_hint!(%{profile_mode: :tus} = report) do
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

  def maybe_write_tus_run_hint!(_report), do: :ok

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

  defp fetch_deps!(generated_app_root, shared_env, network_version),
    do: Workspace.fetch_deps!(generated_app_root, shared_env, network_version)

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

          write_persistence_lifecycle!(%{
            "initiated_session_id" => session.id,
            "verified_session_id" => completed.id,
            "asset_id" => asset.id,
            "read_back_asset_id" => asset.id,
            "asset_state" => asset.state
          })

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
                      Path.join([File.cwd!(), "priv", "repo", "migrations"])
                    )
                  end,
                  mode: :temporary
                )

              report =
                Doctor.run_checks(
                  [inspect(VideoProfile)],
                  exit_on_failure?: false,
                  migration_statuses: migration_statuses
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
end
