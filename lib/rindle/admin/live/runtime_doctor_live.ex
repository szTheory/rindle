if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.Admin.Live.RuntimeDoctorLive do
    @moduledoc false

    use Phoenix.LiveView

    import Rindle.Admin.Components

    alias Rindle.Admin.Queries

    @impl true
    def mount(_params, _session, socket) do
      {:ok,
       socket
       |> assign(
         page_title: "Rindle Admin - Runtime/Doctor",
         live_status: "Waiting for lifecycle events",
         model: empty_model(),
         error?: false
       )
       |> load()}
    end

    @impl true
    def handle_info({:rindle_event, _event_type, _payload}, socket) do
      {:noreply, socket |> assign(:live_status, "Updated just now") |> load()}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <.shell active="runtime-doctor" title="Runtime/Doctor" live_status={@live_status}>
        <section>
          <h2>Runtime status</h2>
          <a class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" href="/admin/rindle/runtime-doctor">
            Refresh status
          </a>
          <.metadata_list items={[
            {"Generated at", @model.generated_at},
            {"Assets", count_value(@model, [:runtime_status, :assets, :counts, :total])},
            {"Variants", count_value(@model, [:runtime_status, :variants, :counts, :total])},
            {"Upload sessions", count_value(@model, [:runtime_status, :upload_sessions, :counts, :total])},
            {"Provider assets", count_value(@model, [:runtime_status, :provider_assets, :counts, :total])}
          ]} />
        </section>

        <%= if @error? do %>
          <.error_state surface="Runtime/Doctor" />
        <% else %>
          <section>
            <h2>Doctor checks</h2>
            <table class="rindle-admin-table">
              <thead class="rindle-admin-table__head">
                <tr>
                  <th class="rindle-admin-table__cell" scope="col">Check</th>
                  <th class="rindle-admin-table__cell" scope="col">Status</th>
                  <th class="rindle-admin-table__cell" scope="col">Summary</th>
                  <th class="rindle-admin-table__cell" scope="col">Fix</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={check <- @model.doctor.checks} class="rindle-admin-table__row" data-rindle-admin-row="doctor-check">
                  <td class="rindle-admin-table__cell"><code>{check.id}</code></td>
                  <td class="rindle-admin-table__cell"><.status_chip state={to_string(check.status)} label={to_string(check.status)} /></td>
                  <td class="rindle-admin-table__cell">{check.summary}</td>
                  <td class="rindle-admin-table__cell">{check.fix}</td>
                </tr>
              </tbody>
            </table>
          </section>

          <section>
            <h2>Failed or missing prerequisites</h2>
            <%= if failed_checks(@model) == [] do %>
              <p>No failed prerequisites were reported by Runtime/Doctor.</p>
            <% else %>
              <ul>
                <li :for={check <- failed_checks(@model)}>
                  <strong>{check.id}</strong>
                  <span>{check.summary}</span>
                </li>
              </ul>
            <% end %>
          </section>

          <section>
            <h2>Runtime findings</h2>
            <ul>
              <li :for={finding <- runtime_findings(@model)}>
                <strong>{finding_label(finding)}</strong>
                <span>{finding.count}</span>
              </li>
            </ul>
            <a class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" href="/admin/rindle/variants-jobs">
              Variants/Jobs
            </a>
            <a class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" href="/admin/rindle/actions">
              Actions
            </a>
          </section>
        <% end %>
      </.shell>
      """
    end

    defp load(socket) do
      case Queries.runtime_doctor(
             runtime_opts: [limit: 25, provider_stuck: true],
             doctor_opts: [
               profiles: [],
               probe: fn -> :ok end,
               oban_config: [repo: Rindle.Repo, queues: []]
             ]
           ) do
        {:ok, model} ->
          assign(socket, model: model, error?: false)

        {:error, reason} ->
          assign(socket, model: empty_model(), error?: true, error_reason: reason)
      end
    end

    defp empty_model do
      %{
        generated_at: nil,
        doctor: %{checks: [], failed: 0, success?: false, total: 0},
        runtime_status: %{
          assets: %{counts: %{}},
          variants: %{counts: %{}, findings: []},
          upload_sessions: %{counts: %{}, findings: []},
          provider_assets: %{counts: %{}, findings: []}
        }
      }
    end

    defp count_value(model, path), do: get_in(model, path) || 0

    defp failed_checks(%{doctor: %{checks: checks}}) do
      Enum.filter(checks, &(&1.status == :error))
    end

    defp runtime_findings(%{runtime_status: runtime_status}) do
      runtime_status.variants.findings ++
        runtime_status.upload_sessions.findings ++
        runtime_status.provider_assets.findings ++
        runtime_status.runtime_checks.findings
    end

    defp finding_label(%{class: class}), do: to_string(class)
    defp finding_label(%{state: state}), do: state
  end
end
