if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.Admin.Live.AssetsLive do
    @moduledoc false

    use Phoenix.LiveView

    import Rindle.Admin.Components

    alias Rindle.Admin.Queries
    alias Rindle.Admin.Live.Support

    @impl true
    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Support.assign_admin_context(session)
       |> assign(
         page_title: "Rindle Admin - Assets",
         live_status: "Waiting for lifecycle events",
         filters: %{},
         model: nil,
         detail: nil,
         error?: false
       )
       |> tap(&Support.subscribe_admin_lifecycle/1)}
    end

    @impl true
    def handle_params(%{"id" => id}, _uri, socket) do
      {:noreply, load_detail(socket, id)}
    end

    def handle_params(params, _uri, socket) do
      filters = take_filters(params, ~w(state profile kind))

      {:noreply,
       socket
       |> assign(filters: filters, detail: nil)
       |> load_list()}
    end

    @impl true
    def handle_info(
          {:rindle_event, _event_type, _payload},
          %{assigns: %{detail: %{asset: asset}}} = socket
        ) do
      {:noreply, socket |> assign(:live_status, "Updated just now") |> load_detail(asset.id)}
    end

    def handle_info({:rindle_event, _event_type, _payload}, socket) do
      {:noreply, socket |> assign(:live_status, "Updated just now") |> load_list()}
    end

    @impl true
    def render(%{detail: %{asset: _asset}} = assigns) do
      ~H"""
      <.shell active="assets" base_path={@admin_base_path} title="Assets" live_status={@live_status}>
        <section data-rindle-admin-row="asset">
          <h2>State context</h2>
          <.status_chip state={@detail.asset.state} label={@detail.asset.state} />
          <.metadata_list items={[
            {"Asset ID", @detail.asset.id},
            {"Profile", @detail.asset.profile},
            {"Kind", @detail.asset.kind},
            {"Filename", @detail.asset.filename},
            {"Storage key", @detail.asset.storage_key}
          ]} />
        </section>

        <section>
          <h2>Attachment context</h2>
          <.detail_table rows={@detail.attachments} columns={[:slot, :owner_type, :owner_id]} />
        </section>

        <section>
          <h2>Variants</h2>
          <.detail_table rows={@detail.variants} columns={[:name, :state, :output_kind, :error_reason]} />
        </section>

        <section>
          <h2>Upload sessions</h2>
          <.detail_table rows={@detail.upload_sessions} columns={[:id, :state, :upload_strategy, :session_uri]} />
        </section>

        <section>
          <h2>Processing runs</h2>
          <.detail_table rows={@detail.processing_runs} columns={[:variant_name, :worker, :state, :attempt]} />
        </section>

        <section>
          <h2>Provider assets</h2>
          <.detail_table rows={@detail.provider_assets} columns={[:provider_name, :provider_asset_id, :state]} />
        </section>
      </.shell>
      """
    end

    def render(assigns) do
      ~H"""
      <.shell active="assets" base_path={@admin_base_path} title="Assets" live_status={@live_status}>
        <.page state={list_state(assigns)} error_surface="Assets">
          <:filters>
            <.filters filters={[{"state", @filters["state"]}, {"profile", @filters["profile"]}, {"kind", @filters["kind"]}]} />
          </:filters>
          <:work>
            <table class="rindle-admin-table">
              <caption class="rindle-admin-visually-hidden">Media assets</caption>
              <thead class="rindle-admin-table__head">
                <tr>
                  <th class="rindle-admin-table__cell" scope="col">Asset</th>
                  <th class="rindle-admin-table__cell" scope="col">State</th>
                  <th class="rindle-admin-table__cell" scope="col">Profile</th>
                  <th class="rindle-admin-table__cell" scope="col">Kind</th>
                  <th class="rindle-admin-table__cell" scope="col">Action</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={asset <- @model.rows} class="rindle-admin-table__row" data-rindle-admin-row="asset">
                  <td class="rindle-admin-table__cell" scope="row" data-label="Asset"><code>{asset.filename || asset.id}</code></td>
                  <td class="rindle-admin-table__cell" data-label="State"><.status_chip state={asset.state} label={asset.state} /></td>
                  <td class="rindle-admin-table__cell" data-label="Profile">{asset.profile}</td>
                  <td class="rindle-admin-table__cell" data-label="Kind">{asset.kind}</td>
                  <td class="rindle-admin-table__cell" data-label="Action">
                    <a
                      class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min"
                      href={admin_path(@admin_base_path, "assets/#{asset.id}")}
                      data-rindle-admin-detail-link="asset"
                    >
                      Inspect asset
                    </a>
                  </td>
                </tr>
              </tbody>
            </table>
          </:work>
        </.page>
      </.shell>
      """
    end

    defp list_state(%{error?: true}), do: :error
    defp list_state(%{model: %{rows: []}}), do: :empty
    defp list_state(_assigns), do: :ok

    attr(:rows, :list, required: true)
    attr(:columns, :list, required: true)

    def detail_table(assigns) do
      ~H"""
      <%= if Enum.empty?(@rows) do %>
        <.empty_state />
      <% else %>
        <table class="rindle-admin-table">
          <thead class="rindle-admin-table__head">
            <tr>
              <th :for={column <- @columns} class="rindle-admin-table__cell" scope="col">{label(column)}</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={row <- @rows} class="rindle-admin-table__row">
              <td :for={column <- @columns} class="rindle-admin-table__cell">{format_value(Map.get(row, column))}</td>
            </tr>
          </tbody>
        </table>
      <% end %>
      """
    end

    defp load_list(socket) do
      case Queries.assets(socket.assigns.filters) do
        {:ok, model} -> assign(socket, model: model, error?: false)
        {:error, reason} -> assign(socket, model: %{rows: []}, error?: true, error_reason: reason)
      end
    end

    defp load_detail(socket, id) do
      case Queries.asset_detail(id) do
        {:ok, detail} ->
          subscribe_detail(socket, detail)
          assign(socket, detail: detail, error?: false)

        {:error, reason} ->
          assign(socket, detail: nil, error?: true, error_reason: reason)
      end
    end

    defp subscribe_detail(socket, detail) do
      Support.subscribe(socket, "rindle:asset:#{detail.asset.id}")

      Enum.each(detail.variants, &Support.subscribe(socket, "rindle:variant:#{&1.id}"))

      Enum.each(
        detail.upload_sessions,
        &Support.subscribe(socket, "rindle:upload_session:#{&1.id}")
      )
    end

    defp take_filters(params, keys) do
      params
      |> Map.take(keys)
      |> Map.reject(fn {_key, value} -> value in [nil, ""] end)
    end

    defp label(column) do
      column
      |> to_string()
      |> String.replace("_", " ")
      |> String.capitalize()
    end
  end
end
