if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.Admin.Live.ActionsLive do
    @moduledoc false

    use Phoenix.LiveView

    import Rindle.Admin.Components

    alias Rindle.Admin.Queries

    @impl true
    def mount(_params, _session, socket) do
      {:ok,
       socket
       |> assign(
         page_title: "Rindle Admin - Actions",
         live_status: "Waiting for lifecycle events",
         model: %{actions: []},
         error?: false
       )
       |> load()}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <.shell active="actions" title="Actions" live_status={@live_status}>
        <section>
          <h2>Read-only operation directory</h2>
          <p>Phase 89 lists Phase 90 operation categories as read-only metadata.</p>
        </section>

        <%= if @error? do %>
          <.error_state surface="Actions" />
        <% else %>
          <table class="rindle-admin-table">
            <thead class="rindle-admin-table__head">
              <tr>
                <th class="rindle-admin-table__cell" scope="col">Operation</th>
                <th class="rindle-admin-table__cell" scope="col">Summary</th>
                <th class="rindle-admin-table__cell" scope="col">enabled?</th>
                <th class="rindle-admin-table__cell" scope="col">Source</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={action <- @model.actions} class="rindle-admin-table__row" data-rindle-admin-row="action">
                <td class="rindle-admin-table__cell">
                  <strong>{String.downcase(action.label)}</strong>
                  <.status_chip state="info" label="read-only" />
                </td>
                <td class="rindle-admin-table__cell">{action.summary}</td>
                <td class="rindle-admin-table__cell"><code>{to_string(action.enabled?)}</code></td>
                <td class="rindle-admin-table__cell">Phase {action.phase}</td>
              </tr>
            </tbody>
          </table>
        <% end %>
      </.shell>
      """
    end

    defp load(socket) do
      {:ok, model} = Queries.actions_directory()
      assign(socket, model: model, error?: false)
    end
  end
end
