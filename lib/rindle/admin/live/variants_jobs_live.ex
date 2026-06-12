if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.Admin.Live.VariantsJobsLive do
    @moduledoc false

    use Phoenix.LiveView

    import Rindle.Admin.Components

    alias Phoenix.PubSub
    alias Rindle.Admin.Queries

    @impl true
    def mount(_params, _session, socket) do
      {:ok,
       assign(socket,
         page_title: "Rindle Admin - Variants/Jobs",
         live_status: "Waiting for lifecycle events",
         filters: %{},
         model: %{rows: [], findings: [], recommendations: [], counts: %{}},
         error?: false
       )}
    end

    @impl true
    def handle_params(params, _uri, socket) do
      filters = take_filters(params, ~w(state profile class older_than provider_stuck))

      {:noreply,
       socket
       |> assign(filters: filters)
       |> load()}
    end

    @impl true
    def handle_info({:rindle_event, _event_type, _payload}, socket) do
      {:noreply, socket |> assign(:live_status, "Updated just now") |> load()}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <.shell active="variants-jobs" title="Variants/Jobs" live_status={@live_status}>
        <section>
          <h2>Variant state</h2>
          <a class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" href="/admin/rindle/variants-jobs">
            Refresh status
          </a>
          <.filters filters={[
            {"state", @filters["state"]},
            {"profile", @filters["profile"]},
            {"class", @filters["class"]},
            {"provider_stuck", @filters["provider_stuck"]}
          ]} />
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

        <%= if @error? do %>
          <.error_state surface="Variants/Jobs" />
        <% else %>
          <%= if Enum.empty?(@model.findings) do %>
            <.empty_state />
            <.error_state surface="Variants/Jobs" />
          <% else %>
            <section>
              <h2>Variant/job buckets</h2>
              <table class="rindle-admin-table">
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
                    <td class="rindle-admin-table__cell">
                      <.status_chip state={bucket_state(finding)} label={bucket_label(finding)} />
                    </td>
                    <td class="rindle-admin-table__cell">{finding.count}</td>
                    <td class="rindle-admin-table__cell">
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
                    <td class="rindle-admin-table__cell">
                      <a
                        :if={sample_asset_id(finding)}
                        class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min"
                        href={"/admin/rindle/assets/#{sample_asset_id(finding)}"}
                      >
                        View details
                      </a>
                    </td>
                  </tr>
                </tbody>
              </table>
            </section>
          <% end %>
        <% end %>

        <section>
          <h2>Repair recommendation</h2>
          <p>Recommended repair lane text is diagnostic only on this surface; no repair is executed here.</p>
          <p>Provider identifier redacted</p>
          <ul>
            <li :for={recommendation <- @model.recommendations}>
              <strong>{format_class(recommendation.class)}</strong>
              <span>{recommendation.summary}</span>
              <code>{recommendation.surface}</code>
            </li>
          </ul>
        </section>
      </.shell>
      """
    end

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
      if connected?(socket) do
        model.findings
        |> Enum.flat_map(& &1.samples)
        |> Enum.each(fn sample ->
          subscribe_if(sample_value(sample, :asset_id), "rindle:asset:")
          subscribe_if(sample_value(sample, :variant_id), "rindle:variant:")
        end)
      end
    end

    defp subscribe_if(nil, _prefix), do: :ok
    defp subscribe_if(value, prefix), do: PubSub.subscribe(Rindle.PubSub, prefix <> value)

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
