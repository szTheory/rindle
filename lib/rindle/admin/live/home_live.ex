if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.Admin.Live.HomeLive do
    @moduledoc false

    use Phoenix.LiveView

    import Rindle.Admin.Components

    alias Rindle.Admin.Queries

    @impl true
    def mount(_params, _session, socket) do
      {:ok,
       socket
       |> assign(:page_title, "Rindle Admin - Home/Status")
       |> assign(:live_status, "Waiting for lifecycle events")
       |> refresh()}
    end

    @impl true
    def handle_info({:rindle_event, _event_type, _payload}, socket) do
      {:noreply, socket |> assign(:live_status, "Updated just now") |> refresh()}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <.shell active="home-status" title="Home/Status" live_status={@live_status}>
        <section>
          <h2>Runtime summary</h2>
          <.status_chip state="info" label="Runtime summary" />
          <.metadata_list items={[
            {"Assets", count_value(@model, [:counts, :assets, :total])},
            {"Upload sessions", count_value(@model, [:counts, :upload_sessions, :total])},
            {"Variants/jobs", count_value(@model, [:counts, :variants, :total])}
          ]} />
        </section>

        <section>
          <h2>Doctor summary</h2>
          <.metadata_list items={[
            {"Total checks", get_in(@model, [:doctor, :total]) || 0},
            {"Passed", get_in(@model, [:doctor, :passed]) || 0},
            {"Failed", get_in(@model, [:doctor, :failed]) || 0}
          ]} />
        </section>

        <section>
          <h2>Recommendations</h2>
          <ul>
            <li :for={recommendation <- recommendations(@model)}>{inspect(recommendation)}</li>
          </ul>
          <a class="rindle-admin-button rindle-admin-button--primary rindle-admin-target-min" href="/admin/rindle/assets">
            Inspect assets
          </a>
        </section>
      </.shell>
      """
    end

    defp refresh(socket) do
      case Queries.home_status(
             runtime_opts: [limit: 5],
             doctor_opts: [
               profiles: [],
               probe: fn -> :ok end,
               oban_config: [repo: Rindle.Repo, queues: []]
             ]
           ) do
        {:ok, model} ->
          assign(socket, model: model, error?: false)

        {:error, reason} ->
          assign(socket, model: %{}, error?: true, error_reason: reason)
      end
    end

    defp count_value(model, path), do: get_in(model, path) || 0

    defp recommendations(%{recommendations: recommendations}) when is_list(recommendations),
      do: recommendations

    defp recommendations(_model), do: []
  end
end
