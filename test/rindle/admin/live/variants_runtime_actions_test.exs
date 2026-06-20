if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.Admin.Live.VariantsRuntimeActionsTest do
    use Rindle.DataCase, async: false
    use Oban.Testing, repo: Rindle.Repo

    require Phoenix.LiveViewTest

    import Mox

    alias Phoenix.PubSub

    alias Rindle.Domain.{
      MediaAsset,
      MediaProviderAsset,
      MediaVariant
    }

    alias Rindle.Workers.ProcessVariant

    @endpoint __MODULE__.Endpoint
    @raw_provider_id "provider-secret-variant-id"
    # Task-first nav labels (UI-SPEC §E, D-98-03): relabeled for task-scent.
    @surfaces [
      "Overview",
      "Assets",
      "Upload sessions",
      "Processing",
      "Doctor",
      "Maintenance"
    ]

    defmodule Router do
      use Phoenix.Router, helpers: false

      import Rindle.Admin.Router

      pipeline :browser do
        plug(:accepts, ["html"])
        plug(:fetch_session)
      end

      scope "/admin" do
        pipe_through(:browser)

        rindle_admin("/rindle", auth_guarded?: true)
      end
    end

    defmodule Endpoint do
      use Phoenix.Endpoint, otp_app: :rindle

      socket("/live", Phoenix.LiveView.Socket)

      plug(Plug.Session,
        store: :cookie,
        key: "_rindle_admin_variants_runtime_actions_test",
        signing_salt: "rindle-admin-test"
      )

      plug(Rindle.Admin.Live.VariantsRuntimeActionsTest.Router)
    end

    import Phoenix.ConnTest

    defmodule ImageProfile do
      use Rindle.Profile,
        storage: Rindle.StorageMock,
        variants: [thumb: [mode: :fit, width: 64, height: 64]],
        allow_mime: ["image/png"],
        max_bytes: 10_485_760
    end

    setup_all do
      Application.put_env(:rindle, Endpoint,
        url: [host: "localhost"],
        debug_errors: true,
        secret_key_base: String.duplicate("b", 64),
        live_view: [signing_salt: "rindle-admin-live"]
      )

      start_supervised!(Endpoint)
      :ok
    end

    setup do
      set_mox_global()
      stub(Rindle.StorageMock, :capabilities, fn -> [:signed_url] end)
      ensure_pubsub_started!()
      {:ok, conn: Phoenix.ConnTest.build_conn()}
    end

    setup :verify_on_exit!

    test "Variants/Jobs renders variant buckets, job correlation, redaction, and repair guidance",
         %{conn: conn} do
      seeded = seed_variant_matrix()

      {:ok, _view, html} =
        Phoenix.LiveViewTest.live(
          conn,
          "/admin/rindle/variants-jobs?profile=#{URI.encode_www_form(to_string(ImageProfile))}&provider_stuck=true"
        )

      assert_shell(html, "variants-jobs")
      assert html =~ "Variants/Jobs"
      assert html =~ "Refresh status"
      assert html =~ "View details"
      assert html =~ "failed"
      assert html =~ "cancelled"
      assert html =~ "stale"
      assert html =~ "missing"
      assert html =~ "processing"
      assert html =~ "queued"
      assert html =~ "queue-starved"
      assert html =~ "Repair recommendation"
      assert html =~ "Provider identifier redacted"
      refute html =~ @raw_provider_id

      for variant <- seeded.finding_variants do
        assert html =~ variant.id
      end
    end

    # CR-01 regression: the Processing summary counters read variant-state buckets
    # from `RuntimeStatus.count_map/1`, which is ATOM-keyed. The original code read
    # them with STRING keys (`count_value(@model, "failed")`, ...) so every counter
    # except the atom-keyed `:total` always rendered 0. This asserts the per-state
    # counters reflect REAL counts. Fails against the string-key code (failed counter
    # reads 0 despite three failed variants).
    test "Processing summary counters reflect real atom-keyed counts (CR-01 regression)", %{
      conn: conn
    } do
      asset = insert_asset(%{profile: to_string(ImageProfile)})
      _f1 = insert_variant(asset, %{name: "thumb", state: "failed", error_reason: "boom"})

      asset2 = insert_asset(%{profile: to_string(ImageProfile), filename: "two.png"})
      _f2 = insert_variant(asset2, %{name: "thumb", state: "failed", error_reason: "boom"})

      asset3 = insert_asset(%{profile: to_string(ImageProfile), filename: "three.png"})
      _f3 = insert_variant(asset3, %{name: "thumb", state: "failed", error_reason: "boom"})

      {:ok, _view, html} = Phoenix.LiveViewTest.live(conn, "/admin/rindle/variants-jobs")

      # The "failed" counter in the summary metadata list must read the real
      # bucket count (3), not the 0 fallback the string-key bug produced. The
      # metadata_list renders each row as `<dt>failed</dt> <dd>3</dd>` — assert the
      # failed dt is immediately followed by a dd of 3 (and NOT 0).
      failed_dt_dd =
        Regex.run(
          ~r{<dt>\s*failed\s*</dt>\s*<dd>\s*(\d+)\s*</dd>},
          html
        )

      assert failed_dt_dd, "expected a 'failed' counter row in the Processing summary"
      assert List.last(failed_dt_dd) == "3"
    end

    test "Processing hosts the distributed Regenerate variants confirm dialog (UI-SPEC §E)", %{
      conn: conn
    } do
      {:ok, view, html} = Phoenix.LiveViewTest.live(conn, "/admin/rindle/variants-jobs")

      # The regenerate verb was distributed off Maintenance onto Processing and
      # confirms through the shared confirm_dialog/1 primitive (D-98-10/11).
      assert html =~ ~s(data-rindle-admin-action="variant_regeneration")
      assert html =~ "Regenerate variants"
      assert html =~ "Regenerate stale variants?"

      assert Phoenix.LiveViewTest.has_element?(
               view,
               "[data-rindle-admin-dialog][role=\"alertdialog\"]"
             )

      assert Phoenix.LiveViewTest.has_element?(
               view,
               "[data-rindle-admin-submit=\"confirm_regenerate\"]"
             )

      Phoenix.LiveViewTest.render_hook(view, "confirm_regenerate", %{})

      assert Phoenix.LiveViewTest.has_element?(
               view,
               "[data-rindle-admin-receipt=\"variant_regeneration\"]"
             )

      assert Phoenix.LiveViewTest.render(view) =~ "Variant regeneration queued."
    end

    # CR-02 regression: opening the regenerate dialog sets `dialog_open=true`, which
    # inerts `<main>` (inert + aria-hidden). The dialog MUST be a sibling of (and
    # rendered after) `<main>` — via the shell `:overlay` slot — not a descendant of
    # it, or `inert` would disable the dialog and its buttons the instant it opens.
    # Fails against the prior markup (dialog nested in the `:summary` slot inside main).
    test "open regenerate dialog renders OUTSIDE the inerted <main> (CR-02 regression)", %{
      conn: conn
    } do
      {:ok, view, _html} = Phoenix.LiveViewTest.live(conn, "/admin/rindle/variants-jobs")

      # Open the dialog so dialog_open=true and <main> becomes inert.
      html = Phoenix.LiveViewTest.render_hook(view, "open_regenerate", %{})

      # <main> carries inert/aria-hidden while the dialog is open.
      assert_main_inerted(html)

      # The dialog + its confirm button must live in the overlay host that is a
      # SIBLING of <main> (i.e. after </main>), never inside the inerted subtree.
      assert_outside_inert_main(html, ~s(data-rindle-admin-overlay-host))
      assert_outside_inert_main(html, ~s(data-rindle-admin-submit="confirm_regenerate"))
      assert_outside_inert_main(html, ~s(id="regenerate-variants-content"))
    end

    test "Variants/Jobs refreshes visible variant rows through queries after PubSub events", %{
      conn: conn
    } do
      asset = insert_asset(%{profile: to_string(ImageProfile)})
      variant = insert_variant(asset, %{state: "failed", error_reason: "codec exploded"})

      {:ok, view, html} = Phoenix.LiveViewTest.live(conn, "/admin/rindle/variants-jobs")

      assert html =~ "failed"
      assert html =~ "codec exploded"

      update_variant_state!(variant.id, "ready", nil)

      PubSub.broadcast(
        Rindle.PubSub,
        "rindle:variant:#{variant.id}",
        {:rindle_event, :variant_ready,
         %{variant_id: variant.id, provider_asset_id: @raw_provider_id}}
      )

      refreshed = Phoenix.LiveViewTest.render(view)
      assert refreshed =~ "Updated just now"
      refute refreshed =~ "codec exploded"
      refute refreshed =~ @raw_provider_id
    end

    test "Variants/Jobs empty and error affordance copy remains stable", %{conn: conn} do
      {:ok, _view, html} =
        Phoenix.LiveViewTest.live(conn, "/admin/rindle/variants-jobs?state=not-a-state")

      assert_shell(html, "variants-jobs")
      assert html =~ "No records match this view"
      refute html =~ "Rindle Admin could not load this surface"
      refute html =~ ~s(data-rindle-admin-error-state)
      assert html =~ "Waiting for lifecycle events"
    end

    test "Runtime/Doctor renders doctor rows, runtime status, failed prerequisites, and links",
         %{conn: conn} do
      _asset =
        insert_asset(%{
          state: "ready",
          profile: to_string(ImageProfile),
          kind: "image",
          content_type: "video/mp4"
        })

      {:ok, _view, html} = Phoenix.LiveViewTest.live(conn, "/admin/rindle/runtime-doctor")

      assert_shell(html, "runtime-doctor")
      assert html =~ "Runtime/Doctor"
      assert html =~ "Doctor checks"
      assert html =~ "Runtime status"
      assert html =~ "Failed or missing prerequisites"
      assert html =~ "probe_drift"
      assert html =~ "Processing"
      assert html =~ "Maintenance"
      assert html =~ "Reconcile"
      assert html =~ "Verify storage"
      assert html =~ "Refresh status"
      assert html =~ "Waiting for lifecycle events"
    end

    test "Maintenance keeps only contextless cross-cutting ops (erasure)", %{conn: conn} do
      {:ok, _view, html} = Phoenix.LiveViewTest.live(conn, "/admin/rindle/actions")

      assert_shell(html, "actions")
      assert html =~ "Maintenance"
      # Contextless cross-cutting ops stay on Maintenance (UI-SPEC §E).
      assert html =~ "Owner erasure"
      assert html =~ "Batch erasure"
      assert html =~ "Actions Directory"
      assert html =~ "Preview and erase one owner"
      assert html =~ "Preview owner erasure"
      assert html =~ "Waiting for lifecycle events"

      assert html =~ ~s(data-rindle-admin-action="owner_erasure")
      assert html =~ ~s(data-rindle-admin-action="batch_erasure")
      assert html =~ ~s(data-rindle-admin-action-panel="owner_erasure")
      assert html =~ ~s(data-rindle-admin-form="owner_erasure_preview")
      assert html =~ ~s(data-rindle-admin-submit="preview_owner_erasure")

      # The verb-bucket actions were DISTRIBUTED to their contextual surfaces
      # (regenerate → Processing, quarantine → Assets, reconcile → Doctor); they
      # no longer live in the Maintenance directory (D-98-10).
      refute html =~ ~s(data-rindle-admin-action="variant_regeneration")
      refute html =~ ~s(data-rindle-admin-action="quarantine_review")
      refute html =~ ~s(data-rindle-admin-action="lifecycle_repair")

      refute html =~ "LifecycleRepair"
      refute html =~ "VariantMaintenance"
    end

    # CR-02 helpers: the inerted <main> is the destructive-focus boundary. A live
    # dialog must NOT be a descendant of it (inert disables descendants), so we assert
    # the dialog markers appear AFTER the </main> close tag — i.e. in the sibling
    # overlay host — and that <main> actually carries inert/aria-hidden when open.
    defp assert_main_inerted(html) do
      main_open = Regex.run(~r/<main[^>]*>/, html)
      assert main_open, "expected a <main> element in the rendered shell"
      assert hd(main_open) =~ "inert", "expected <main> to carry inert while a dialog is open"

      assert hd(main_open) =~ ~s(aria-hidden="true"),
             "expected <main> to carry aria-hidden=\"true\" while a dialog is open"
    end

    defp assert_outside_inert_main(html, marker) do
      main_close = :binary.match(html, "</main>")
      assert main_close != :nomatch, "expected a </main> close tag"
      {main_close_at, _} = main_close
      marker_at = :binary.match(html, marker)
      assert marker_at != :nomatch, "expected marker #{inspect(marker)} in the rendered html"
      {marker_pos, _} = marker_at

      assert marker_pos > main_close_at,
             "#{inspect(marker)} must render AFTER </main> (sibling overlay), not inside the inerted <main>"
    end

    defp assert_shell(html, surface) do
      assert html =~ ~s(data-rindle-admin-root)
      assert html =~ ~s(data-rindle-admin-surface="#{surface}")
      assert html =~ ~s(data-rindle-admin-nav-item)
      assert html =~ ~s(data-rindle-admin-live-indicator)
      assert html =~ ~s(data-theme="auto")
      assert html =~ ~s(data-rindle-admin-theme="light")
      assert html =~ ~s(data-rindle-admin-theme="dark")
      assert html =~ ~s(data-rindle-admin-theme="auto")
      assert html =~ ~s(aria-label="Theme")
      assert html =~ "rindle-admin-target-min"

      for surface_name <- @surfaces do
        assert html =~ surface_name
      end
    end

    defp seed_variant_matrix do
      failed_asset = insert_asset(%{profile: to_string(ImageProfile), filename: "failed.png"})

      cancelled_asset =
        insert_asset(%{profile: to_string(ImageProfile), filename: "cancelled.png"})

      stale_asset = insert_asset(%{profile: to_string(ImageProfile), filename: "stale.png"})
      missing_asset = insert_asset(%{profile: to_string(ImageProfile), filename: "missing.png"})
      queued_asset = insert_asset(%{profile: to_string(ImageProfile), filename: "queued.png"})

      processing_asset =
        insert_asset(%{profile: to_string(ImageProfile), filename: "processing.png"})

      finding_variants = [
        insert_variant(failed_asset, %{
          state: "failed",
          error_reason: "processor failed",
          updated_at: age_ago(600)
        }),
        insert_variant(cancelled_asset, %{state: "cancelled", updated_at: age_ago(600)}),
        insert_variant(stale_asset, %{state: "stale", updated_at: age_ago(600)}),
        insert_variant(missing_asset, %{state: "missing", updated_at: age_ago(600)}),
        insert_variant(queued_asset, %{state: "queued", updated_at: age_ago(601)})
      ]

      _processing =
        insert_variant(processing_asset, %{state: "processing", updated_at: age_ago(60)})

      _active_job =
        ProcessVariant.new(%{
          "asset_id" => processing_asset.id,
          "variant_name" => "thumb"
        })
        |> Oban.insert!()

      _provider =
        insert_provider_asset(processing_asset, %{
          provider_asset_id: @raw_provider_id,
          state: "processing",
          updated_at: age_ago(8_000)
        })

      %{finding_variants: finding_variants}
    end

    defp insert_asset(attrs) do
      params =
        %{
          state: "available",
          profile: to_string(ImageProfile),
          storage_key: "assets/#{System.unique_integer([:positive])}.bin",
          kind: "image",
          content_type: "image/png",
          byte_size: 1234,
          filename: "sample.png"
        }
        |> Map.merge(attrs)

      %MediaAsset{}
      |> MediaAsset.changeset(params)
      |> Rindle.Repo.insert!()
    end

    defp insert_variant(asset, attrs) do
      variant_name = Map.get(attrs, :name, "thumb")

      params =
        %{
          asset_id: asset.id,
          name: variant_name,
          state: "ready",
          recipe_digest: ImageProfile.recipe_digest(String.to_existing_atom(variant_name)),
          storage_key: "variants/#{System.unique_integer([:positive])}.bin",
          output_kind: "image"
        }
        |> Map.merge(Map.drop(attrs, [:updated_at]))

      variant =
        %MediaVariant{}
        |> MediaVariant.changeset(params)
        |> Rindle.Repo.insert!()

      maybe_backdate(MediaVariant, variant.id, attrs[:updated_at])
      Rindle.Repo.get!(MediaVariant, variant.id)
    end

    defp insert_provider_asset(asset, attrs) do
      params =
        %{
          asset_id: asset.id,
          profile: asset.profile,
          provider_name: "mux",
          provider_asset_id: Map.get(attrs, :provider_asset_id, @raw_provider_id),
          state: Map.get(attrs, :state, "processing")
        }
        |> Map.merge(Map.drop(attrs, [:provider_asset_id, :state, :updated_at]))

      provider =
        %MediaProviderAsset{}
        |> MediaProviderAsset.changeset(params)
        |> Rindle.Repo.insert!()

      maybe_backdate(MediaProviderAsset, provider.id, attrs[:updated_at])
      Rindle.Repo.get!(MediaProviderAsset, provider.id)
    end

    defp update_variant_state!(variant_id, state, error_reason) do
      variant = Rindle.Repo.get!(MediaVariant, variant_id)

      variant
      |> MediaVariant.changeset(%{state: state, error_reason: error_reason})
      |> Rindle.Repo.update!()
    end

    defp age_ago(seconds) do
      DateTime.utc_now()
      |> DateTime.add(-seconds, :second)
      |> DateTime.to_naive()
    end

    defp maybe_backdate(_schema, _id, nil), do: :ok

    defp maybe_backdate(schema, id, %NaiveDateTime{} = updated_at) do
      import Ecto.Query

      from(record in schema, where: record.id == ^id)
      |> Rindle.Repo.update_all(set: [updated_at: updated_at])

      :ok
    end

    defp ensure_pubsub_started! do
      case Process.whereis(Rindle.PubSub) do
        nil -> start_supervised!({Phoenix.PubSub, name: Rindle.PubSub})
        _pid -> :ok
      end
    end
  end
end
