if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.Admin.Live.UploadSessionsLive do
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
         page_title: "Rindle Admin - Upload Sessions",
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
      filters = take_filters(params, ~w(state strategy profile))

      {:noreply,
       socket
       |> assign(filters: filters, detail: nil)
       |> load_list()}
    end

    @impl true
    def handle_info(
          {:rindle_event, _event_type, _payload},
          %{assigns: %{detail: %{upload_session: session}}} = socket
        ) do
      {:noreply, socket |> assign(:live_status, "Updated just now") |> load_detail(session.id)}
    end

    def handle_info({:rindle_event, _event_type, _payload}, socket) do
      {:noreply, socket |> assign(:live_status, "Updated just now") |> load_list()}
    end

    @impl true
    def render(%{detail: %{upload_session: session}} = assigns) do
      assigns = assign(assigns, :session, session)

      ~H"""
      <.shell active="upload-sessions" base_path={@admin_base_path} title="Upload Sessions" live_status={@live_status}>
        <section data-rindle-admin-row="upload-session">
          <h2>Strategy/protocol</h2>
          <.status_chip state={@session.state} label={@session.state} />
          <.metadata_list items={[
            {"Session ID", @session.id},
            {"Asset ID", @session.asset_id},
            {"Strategy", @session.upload_strategy},
            {"Protocol", @session.resumable_protocol || "standard"},
            {"Session URI", @session.session_uri || "Redacted by Rindle Admin"}
          ]} />
        </section>

        <section>
          <h2>Expiration</h2>
          <.metadata_list items={[
            {"Expires at", @session.expires_at},
            {"Session URI expires at", @session.session_uri_expires_at},
            {"Last known offset", @session.last_known_offset || 0}
          ]} />
        </section>

        <section>
          <h2>Failure reason</h2>
          <p>{@session.failure_reason || "No failure reason recorded"}</p>
        </section>

        <section>
          <h2>Asset link</h2>
          <a class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" href={admin_path(@admin_base_path, "assets/#{@session.asset_id}")}>
            Inspect asset
          </a>
        </section>

        <section>
          <h2>Cleanup guidance</h2>
          <p>Review Runtime/Doctor for upload residue before scheduling cleanup.</p>
        </section>
      </.shell>
      """
    end

    def render(assigns) do
      ~H"""
      <.shell active="upload-sessions" base_path={@admin_base_path} title="Upload Sessions" live_status={@live_status}>
        <.filters filters={[{"state", @filters["state"]}, {"strategy", @filters["strategy"]}, {"profile", @filters["profile"]}]} />

        <%= if @error? do %>
          <.error_state surface="Upload Sessions" />
        <% else %>
          <%= if Enum.empty?(@model.rows) do %>
            <.empty_state />
          <% else %>
            <table class="rindle-admin-table">
              <thead class="rindle-admin-table__head">
                <tr>
                  <th class="rindle-admin-table__cell" scope="col">Session</th>
                  <th class="rindle-admin-table__cell" scope="col">State</th>
                  <th class="rindle-admin-table__cell" scope="col">Strategy</th>
                  <th class="rindle-admin-table__cell" scope="col">Session URI</th>
                  <th class="rindle-admin-table__cell" scope="col">Action</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={session <- @model.rows} class="rindle-admin-table__row" data-rindle-admin-row="upload-session">
                  <td class="rindle-admin-table__cell"><code>{session.id}</code></td>
                  <td class="rindle-admin-table__cell"><.status_chip state={session.state} label={session.state} /></td>
                  <td class="rindle-admin-table__cell">{session.upload_strategy}</td>
                  <td class="rindle-admin-table__cell"><.redacted_value value={session.session_uri} /></td>
                  <td class="rindle-admin-table__cell">
                    <a class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" href={admin_path(@admin_base_path, "upload-sessions/#{session.id}")}>
                      Review session
                    </a>
                  </td>
                </tr>
              </tbody>
            </table>
          <% end %>
        <% end %>
      </.shell>
      """
    end

    defp load_list(socket) do
      case Queries.upload_sessions(socket.assigns.filters) do
        {:ok, model} -> assign(socket, model: model, error?: false)
        {:error, reason} -> assign(socket, model: %{rows: []}, error?: true, error_reason: reason)
      end
    end

    defp load_detail(socket, id) do
      case Queries.upload_session_detail(id) do
        {:ok, detail} ->
          subscribe_detail(socket, detail)
          assign(socket, detail: detail, error?: false)

        {:error, reason} ->
          assign(socket, detail: nil, error?: true, error_reason: reason)
      end
    end

    defp subscribe_detail(socket, %{upload_session: session}) do
      Support.subscribe(socket, "rindle:upload_session:#{session.id}")
      Support.subscribe(socket, "rindle:asset:#{session.asset_id}")
    end

    defp take_filters(params, keys) do
      params
      |> Map.take(keys)
      |> Map.reject(fn {_key, value} -> value in [nil, ""] end)
    end
  end
end
