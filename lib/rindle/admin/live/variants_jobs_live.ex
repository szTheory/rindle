if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.Admin.Live.VariantsJobsLive do
    @moduledoc false

    use Phoenix.LiveView

    import Rindle.Admin.Components

    alias Phoenix.LiveView.JS
    alias Rindle.Admin.Queries
    alias Rindle.Admin.Live.Support

    @impl true
    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Support.assign_admin_context(session)
       |> assign(
         page_title: "Rindle Admin - Variants/Jobs",
         live_status: "Waiting for lifecycle events",
         filters: %{},
         model: %{rows: [], findings: [], recommendations: [], counts: %{}},
         detail: nil,
         dialog_open: false,
         regenerate_receipt: nil,
         error?: false
       )
       |> tap(&Support.subscribe_admin_lifecycle/1)}
    end

    # Distributed "Regenerate variants" action (UI-SPEC §E, D-98-10/11): the
    # regenerate verb moved off the Maintenance junk-drawer onto Processing and
    # confirms through the shared confirm_dialog/1 primitive. `dialog_open` is the
    # server-assign source of truth for the shell inert/aria-hidden contract.
    @impl true
    def handle_event("open_regenerate", _params, socket) do
      {:noreply, assign(socket, dialog_open: true, regenerate_receipt: nil)}
    end

    def handle_event("close_regenerate", _params, socket) do
      {:noreply, assign(socket, dialog_open: false)}
    end

    def handle_event("confirm_regenerate", _params, socket) do
      receipt =
        case Rindle.Ops.VariantMaintenance.regenerate_variants(%{}) do
          {:ok, report} -> report
          {:error, _} -> %{enqueued: 0, skipped: 0, errors: 1}
        end

      {:noreply,
       socket
       |> assign(dialog_open: false, regenerate_receipt: receipt, live_status: "Variant regeneration queued.")
       |> load()}
    end

    @impl true
    def handle_params(%{"id" => id}, _uri, socket) do
      {:noreply, load_detail(socket, id)}
    end

    def handle_params(params, _uri, socket) do
      filters = take_filters(params, ~w(state profile class older_than provider_stuck))

      {:noreply,
       socket
       |> assign(filters: filters, detail: nil)
       |> load()}
    end

    @impl true
    def handle_info(
          {:rindle_event, _event_type, _payload},
          %{assigns: %{detail: %{run: run}}} = socket
        ) do
      {:noreply, socket |> assign(:live_status, "Updated just now") |> load_detail(run.id)}
    end

    def handle_info({:rindle_event, _event_type, _payload}, socket) do
      {:noreply, socket |> assign(:live_status, "Updated just now") |> load()}
    end

    @impl true
    def render(%{detail: %{run: _run}} = assigns) do
      ~H"""
      <.shell active="variants-jobs" base_path={@admin_base_path} title="Variants/Jobs" live_status={@live_status}>
        <section data-rindle-admin-row="processing-run">
          <h2>Processing run</h2>
          <.status_chip state={@detail.run.state} label={@detail.run.state} />
          <.metadata_list items={[
            {"Run ID", @detail.run.id},
            {"Variant", @detail.run.variant_name},
            {"Worker", @detail.run.worker},
            {"Attempt", @detail.run.attempt},
            {"Started at", @detail.run.started_at},
            {"Finished at", @detail.run.finished_at}
          ]} />
        </section>

        <section>
          <h2>Error reason</h2>
          <p>{@detail.run.error_reason || "No error reason recorded"}</p>
        </section>

        <section :if={@detail.asset}>
          <h2>Asset link</h2>
          <a
            class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min"
            href={admin_path(@admin_base_path, "assets/#{@detail.asset.id}")}
            data-rindle-admin-detail-link="asset"
          >
            Inspect asset
          </a>
        </section>
      </.shell>
      """
    end

    def render(assigns) do
      ~H"""
      <.shell active="variants-jobs" base_path={@admin_base_path} title="Variants/Jobs" live_status={@live_status} dialog_open={@dialog_open}>
        <.page state={list_state(assigns)} error_surface="Variants/Jobs">
          <:summary>
            <section>
              <h2>Variant state</h2>
              <a class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" href={admin_path(@admin_base_path, "variants-jobs")}>
                Refresh status
              </a>
              <button
                type="button"
                class="rindle-admin-button rindle-admin-button--primary rindle-admin-target-min"
                data-rindle-admin-action="variant_regeneration"
                phx-click={show_modal("regenerate-variants") |> JS.push("open_regenerate")}
              >
                Regenerate variants
              </button>
              <p :if={@regenerate_receipt} data-rindle-admin-receipt="variant_regeneration">
                Variant regeneration queued. Enqueued: {@regenerate_receipt.enqueued} · Skipped: {@regenerate_receipt.skipped} · Errors: {@regenerate_receipt.errors}
              </p>
              <.metadata_list items={[
                {"Total", count_value(@model, :total)},
                {"failed", count_value(@model, "failed")},
                {"cancelled", count_value(@model, "cancelled")},
                {"stale", count_value(@model, "stale")},
                {"missing", count_value(@model, "missing")},
                {"queued", count_value(@model, "queued")},
                {"processing", count_value(@model, "processing")}
              ]} />
            </section>
            <.confirm_dialog
              id="regenerate-variants"
              show={@dialog_open}
              on_cancel={JS.push("close_regenerate")}
            >
              <:title>Regenerate stale variants?</:title>
              Rindle will enqueue jobs for variants whose recipe digest no longer matches the current profile.
              <:actions>
                <button
                  type="button"
                  class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min"
                  phx-click={hide_modal("regenerate-variants") |> JS.push("close_regenerate")}
                >
                  Cancel
                </button>
                <button
                  type="button"
                  class="rindle-admin-button rindle-admin-button--primary rindle-admin-target-min"
                  phx-click={hide_modal("regenerate-variants") |> JS.push("confirm_regenerate")}
                  data-rindle-admin-submit="confirm_regenerate"
                >
                  Regenerate variants
                </button>
              </:actions>
            </.confirm_dialog>
          </:summary>
          <:filters>
            <.filters filters={[
              {"state", @filters["state"]},
              {"profile", @filters["profile"]},
              {"class", @filters["class"]},
              {"provider_stuck", @filters["provider_stuck"]}
            ]} />
          </:filters>
          <:work>
            <section>
              <h2>Variant/job buckets</h2>
              <table class="rindle-admin-table">
                <caption class="rindle-admin-visually-hidden">Variant and job buckets</caption>
                <thead class="rindle-admin-table__head">
                  <tr>
                    <th class="rindle-admin-table__cell" scope="col">Bucket</th>
                    <th class="rindle-admin-table__cell" scope="col">Count</th>
                    <th class="rindle-admin-table__cell" scope="col">Samples</th>
                    <th class="rindle-admin-table__cell" scope="col">Action</th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={finding <- @model.findings} class="rindle-admin-table__row" data-rindle-admin-row="variant-finding">
                    <td class="rindle-admin-table__cell" scope="row" data-label="Bucket">
                      <.status_chip state={bucket_state(finding)} label={bucket_label(finding)} />
                    </td>
                    <td class="rindle-admin-table__cell" data-label="Count">{finding.count}</td>
                    <td class="rindle-admin-table__cell" data-label="Samples">
                      <ul>
                        <li :for={sample <- finding.samples}>
                          <code>{sample_value(sample, :variant_id) || sample_value(sample, :asset_id)}</code>
                          <span>{sample_value(sample, :variant_name) || sample_value(sample, :provider) || "provider"}</span>
                          <span>{sample_value(sample, :state)}</span>
                          <span>{safe_reason(sample)}</span>
                          <span :if={sample_value(sample, :error_reason)}>{sample_value(sample, :error_reason)}</span>
                          <span :if={sample_value(sample, :provider_asset_id)}>Provider identifier redacted</span>
                        </li>
                      </ul>
                    </td>
                    <td class="rindle-admin-table__cell" data-label="Action">
                      <a
                        :if={sample_asset_id(finding)}
                        class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min"
                        href={admin_path(@admin_base_path, "variants-jobs/#{sample_asset_id(finding)}")}
                        data-rindle-admin-detail-link="processing-run"
                      >
                        View details
                      </a>
                    </td>
                  </tr>
                </tbody>
              </table>
            </section>

            <section>
              <h2>Repair recommendation</h2>
              <p>This is a diagnostic recommendation. No repair runs on this surface.</p>
              <p>Provider identifier redacted</p>
              <ul>
                <li :for={recommendation <- @model.recommendations}>
                  <strong>{format_class(recommendation.class)}</strong>
                  <span>{recommendation.summary}</span>
                  <code>{recommendation.surface}</code>
                </li>
              </ul>
            </section>
          </:work>
        </.page>
      </.shell>
      """
    end

    defp list_state(%{error?: true}), do: :error
    defp list_state(%{model: %{findings: []}}), do: :empty
    defp list_state(_assigns), do: :ok

    defp load_detail(socket, id) do
      case Queries.variant_run_detail(id) do
        {:ok, detail} ->
          subscribe_detail(socket, detail)
          assign(socket, detail: detail, error?: false)

        {:error, reason} ->
          assign(socket, detail: nil, error?: true, error_reason: reason)
      end
    end

    defp subscribe_detail(socket, %{asset: %{id: asset_id}}) when is_binary(asset_id) do
      Support.subscribe(socket, "rindle:asset:#{asset_id}")
    end

    defp subscribe_detail(_socket, _detail), do: :ok

    defp load(socket) do
      opts =
        socket.assigns.filters
        |> normalize_query_filters()
        |> Keyword.put_new(:limit, 25)

      case Queries.variants_jobs(opts) do
        {:ok, model} ->
          subscribe_visible(socket, model)
          assign(socket, model: model, error?: false)

        {:error, reason} ->
          assign(socket,
            model: %{findings: [], recommendations: [], counts: %{}},
            error?: true,
            error_reason: reason
          )
      end
    end

    defp subscribe_visible(socket, model) do
      model.findings
      |> Enum.flat_map(& &1.samples)
      |> Enum.each(fn sample ->
        subscribe_if(socket, sample_value(sample, :asset_id), "rindle:asset:")
        subscribe_if(socket, sample_value(sample, :variant_id), "rindle:variant:")
      end)
    end

    defp subscribe_if(_socket, nil, _prefix), do: :ok
    defp subscribe_if(socket, value, prefix), do: Support.subscribe(socket, prefix <> value)

    defp normalize_query_filters(filters) do
      filters
      |> Enum.map(fn
        {"class", value} -> {:class, normalize_class(value)}
        {"provider_stuck", value} -> {:provider_stuck, value in ["true", "1", "yes"]}
        {"older_than", value} -> {:older_than, parse_integer(value)}
        {key, value} -> {String.to_existing_atom(key), value}
      end)
      |> Enum.reject(fn {_key, value} -> value in [nil, ""] end)
    end

    defp normalize_class(nil), do: nil

    defp normalize_class(value) when is_binary(value) do
      value
      |> String.replace("-", "_")
      |> String.to_existing_atom()
    rescue
      ArgumentError -> value
    end

    defp parse_integer(value) when is_binary(value) do
      case Integer.parse(value) do
        {integer, ""} -> integer
        _other -> value
      end
    end

    defp take_filters(params, keys) do
      params
      |> Map.take(keys)
      |> Map.reject(fn {_key, value} -> value in [nil, ""] end)
    end

    defp count_value(%{counts: counts}, key), do: Map.get(counts, key, 0)
    defp count_value(_model, _key), do: 0

    defp bucket_state(%{class: class}) when class in [:failed_work, :cancelled_work],
      do: "failed"

    defp bucket_state(%{class: class}) when class in [:recipe_drift, :storage_drift],
      do: "warning"

    defp bucket_state(%{class: :queue_starved}), do: "processing"
    defp bucket_state(%{class: :provider_stuck}), do: "warning"
    defp bucket_state(%{class: :orphan_suspect}), do: "processing"
    defp bucket_state(_finding), do: "info"

    defp bucket_label(%{class: :queue_starved}), do: "queue-starved"
    defp bucket_label(%{class: class}), do: format_class(class)
    defp bucket_label(%{state: state}), do: state

    defp format_class(class) do
      class
      |> to_string()
      |> String.replace("_", "-")
    end

    defp sample_value(sample, key),
      do: Map.get(sample, key) || Map.get(sample, Atom.to_string(key))

    defp safe_reason(sample),
      do: sample_value(sample, :reason) || sample_value(sample, :error_reason)

    defp sample_asset_id(%{samples: [sample | _]}), do: sample_value(sample, :asset_id)
    defp sample_asset_id(_finding), do: nil
  end
end
