if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.Admin.Live.RuntimeDoctorLive do
    @moduledoc false

    use Phoenix.LiveView

    import Rindle.Admin.Components

    alias Rindle.Admin.Queries
    alias Rindle.Admin.Live.Support

    @runtime_opts [limit: 25, provider_stuck: true]

    @impl true
    def mount(_params, session, socket) do
      {:ok,
       socket
       |> Support.assign_admin_context(session)
       |> assign(
         page_title: "Rindle Admin - Runtime/Doctor",
         live_status: "Waiting for lifecycle events",
         model: empty_model(),
         error?: false
       )
       |> tap(&Support.subscribe_admin_lifecycle/1)
       |> load()}
    end

    @impl true
    def handle_info({:rindle_event, _event_type, _payload}, socket) do
      {:noreply, socket |> assign(:live_status, "Updated just now") |> load()}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <.shell active="runtime-doctor" base_path={@admin_base_path} title="Runtime/Doctor" live_status={@live_status}>
        <.page state={if(@error?, do: :error, else: :ok)} error_surface="Runtime/Doctor">
          <:summary>
            <section>
              <h2>Runtime status</h2>
              <a class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" href={admin_path(@admin_base_path, "runtime-doctor")}>
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
          </:summary>
          <:work>
            <section>
              <h2>Doctor checks</h2>
              <table class="rindle-admin-table">
                <caption class="rindle-admin-visually-hidden">Runtime/Doctor checks</caption>
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
                    <td class="rindle-admin-table__cell" scope="row" data-label="Check"><code>{check.id}</code></td>
                    <td class="rindle-admin-table__cell" data-label="Status"><.status_chip state={to_string(check.status)} label={to_string(check.status)} /></td>
                    <td class="rindle-admin-table__cell" data-label="Summary">{check.summary}</td>
                    <td class="rindle-admin-table__cell" data-label="Fix">{check.fix}</td>
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
              <a class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" href={admin_path(@admin_base_path, "variants-jobs")}>
                Processing
              </a>
              <a class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" href={admin_path(@admin_base_path, "actions")}>
                Maintenance
              </a>
            </section>

            <%!-- Distributed reconcile action (UI-SPEC §E, D-98-10): the
                  reconcile/verify-storage verb moved off the Maintenance
                  junk-drawer onto Doctor, where the operator diagnoses. --%>
            <section data-rindle-admin-section="reconcile">
              <h2>Reconcile</h2>
              <p>Run a fresh Doctor pass to reconcile storage reachability and recorded runtime state.</p>
              <a
                class="rindle-admin-button rindle-admin-button--primary rindle-admin-target-min"
                href={admin_path(@admin_base_path, "runtime-doctor")}
                data-rindle-admin-action="verify_storage"
              >
                Verify storage
              </a>
            </section>
          </:work>
        </.page>
      </.shell>
      """
    end

    defp load(socket) do
      case Queries.runtime_doctor(runtime_opts: @runtime_opts) do
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
          runtime_checks: %{counts: %{}, findings: []},
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
