if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.Admin.Live.HomeLive do
    @moduledoc false

    use Phoenix.LiveView

    import Rindle.Admin.Components

    alias Rindle.Admin.Queries
    alias Rindle.Admin.Live.Support

    @runtime_opts [limit: 5]

    @impl true
    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Support.assign_admin_context(session)
       |> assign(:page_title, "Rindle Admin - Overview")
       |> assign(:live_status, "Waiting for lifecycle events")
       |> tap(&Support.subscribe_admin_lifecycle/1)
       |> refresh()}
    end

    @impl true
    def handle_info({:rindle_event, _event_type, _payload}, socket) do
      {:noreply, socket |> assign(:live_status, "Updated just now") |> refresh()}
    end

    @impl true
    def render(assigns) do
      assigns =
        assigns
        |> assign(:problems, needs_attention(assigns.model, assigns.admin_base_path))
        |> assign(:activity, recent_activity(assigns.model))

      ~H"""
      <.shell active="home-status" base_path={@admin_base_path} title="Overview" live_status={@live_status}>
        <.page state={if(@error?, do: :error, else: :ok)} error_surface="Overview">
          <:work>
            <%!-- (1) Needs attention — problems FIRST (GDS task-list, §E / D-98-10).
                  Only non-zero problem counts; each entry deep-links to an
                  ALREADY-PARSED handle_params filter (pure <a>, no new routes). --%>
            <section data-rindle-admin-section="needs-attention">
              <h2>Needs attention</h2>
              <ul :if={@problems != []} data-rindle-admin-needs-attention>
                <li :for={problem <- @problems}>
                  <a class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" href={problem.href}>
                    {problem.label} →
                  </a>
                </li>
              </ul>
              <p :if={@problems == []} data-rindle-admin-all-clear>
                Nothing needs attention. Lifecycle events are flowing and all Doctor checks pass.
              </p>
            </section>

            <%!-- (2) System health — three chips. --%>
            <section data-rindle-admin-section="system-health">
              <h2>System health</h2>
              <.status_chip state={lifecycle_state(@model)} label={lifecycle_label(@model)} />
              <.status_chip state={doctor_state(@model)} label={doctor_label(@model)} />
              <.status_chip state={storage_state(@model)} label={storage_label(@model)} />
            </section>

            <%!-- (3) Recent lifecycle activity — last 5. --%>
            <section data-rindle-admin-section="recent-activity">
              <h2>Recent activity</h2>
              <ul :if={@activity != []}>
                <li :for={item <- @activity}>
                  <strong>{item.title}</strong>
                  <span>{item.summary}</span>
                </li>
              </ul>
              <p :if={@activity == []}>No recent lifecycle activity recorded.</p>
            </section>

            <%!-- (4) Vanity totals — LAST, below the fold (§E). --%>
            <section data-rindle-admin-section="totals">
              <h2>Totals</h2>
              <.metadata_list items={[
                {"Assets", count_value(@model, [:counts, :assets, :total])},
                {"Upload sessions", count_value(@model, [:counts, :upload_sessions, :total])},
                {"Variants", count_value(@model, [:counts, :variants, :total])}
              ]} />
            </section>
          </:work>
        </.page>
      </.shell>
      """
    end

    defp refresh(socket) do
      case Queries.home_status(runtime_opts: @runtime_opts) do
        {:ok, model} ->
          assign(socket, model: model, error?: false)

        {:error, reason} ->
          assign(socket, model: %{}, error?: true, error_reason: reason)
      end
    end

    defp count_value(model, path), do: get_in(model, path) || 0

    # Build the needs-attention task-list: ONLY non-zero problem counts, each a
    # deep-link to an already-parsed filter (D-98-10, no new routes).
    defp needs_attention(model, base_path) do
      # CR-01: `RuntimeStatus.count_map/1` keys every state-count map with ATOMS
      # (`String.to_atom(state)`), so these buckets MUST be read with atom keys —
      # `:failed`/`:stale`/`:quarantined`/`:expired` are real state-enum values.
      # `:orphaned` is NOT a provider_asset state; orphans come from the Doctor
      # findings counts (see orphan_count/1), so there is no `[:counts, :provider_assets, :orphaned]` read.
      [
        problem(
          count_value(model, [:counts, :variants, :failed]),
          "failed processing runs",
          admin_path(base_path, "variants-jobs?state=failed")
        ),
        problem(
          count_value(model, [:counts, :variants, :stale]),
          "stale variants",
          admin_path(base_path, "variants-jobs?class=stale")
        ),
        problem(
          count_value(model, [:counts, :assets, :quarantined]),
          "quarantined assets",
          admin_path(base_path, "assets?state=quarantined")
        ),
        problem(
          count_value(model, [:counts, :upload_sessions, :expired]),
          "expired upload sessions",
          admin_path(base_path, "upload-sessions?state=expired")
        ),
        problem(
          orphan_count(model),
          "orphaned objects",
          admin_path(base_path, "runtime-doctor")
        )
      ]
      |> Enum.reject(&is_nil/1)
    end

    defp problem(count, _noun, _href) when count in [nil, 0], do: nil

    defp problem(count, noun, href) do
      %{count: count, href: href, label: "#{count} #{noun}"}
    end

    # CR-01: there is no `:orphaned` provider_asset state — orphan signal is the
    # Doctor's `:orphan_suspect` finding count (finding_counts/1 is atom-keyed by
    # finding class). Reading a non-existent `[:counts, :provider_assets, :orphaned]`
    # bucket would always be 0, so it is dropped entirely.
    defp orphan_count(model) do
      count_value(model, [:runtime_status, :runtime_checks, :counts, :orphan_suspect])
    end

    # Recent lifecycle activity (last 5) — rendered as readable rows, NEVER inspect/1.
    defp recent_activity(%{recommendations: recommendations}) when is_list(recommendations) do
      recommendations
      |> Enum.take(5)
      |> Enum.map(fn recommendation ->
        %{
          title: humanize_class(Map.get(recommendation, :class)),
          summary: Map.get(recommendation, :summary) || ""
        }
      end)
    end

    defp recent_activity(_model), do: []

    defp humanize_class(nil), do: "Lifecycle event"

    defp humanize_class(class) do
      class
      |> to_string()
      |> String.replace("_", " ")
      |> String.capitalize()
    end

    # System-health chips.
    defp lifecycle_state(model) do
      if count_value(model, [:counts, :variants, :total]) > 0 or
           count_value(model, [:counts, :upload_sessions, :total]) > 0,
         do: "ready",
         else: "info"
    end

    defp lifecycle_label(_model), do: "Lifecycle events flowing"

    defp doctor_state(model) do
      if (get_in(model, [:doctor, :failed]) || 0) > 0, do: "failed", else: "ready"
    end

    defp doctor_label(model) do
      failed = get_in(model, [:doctor, :failed]) || 0
      total = get_in(model, [:doctor, :total]) || 0

      if failed > 0 do
        "Doctor: #{failed} of #{total} failing"
      else
        "Doctor checks pass"
      end
    end

    defp storage_state(model) do
      if (get_in(model, [:doctor, :failed]) || 0) > 0, do: "warning", else: "ready"
    end

    defp storage_label(_model), do: "Storage reachable"
  end
end
