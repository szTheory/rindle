defmodule AdoptionDemoWeb.OpsLive do
  use AdoptionDemoWeb, :live_view

  alias AdoptionDemo.{Accounts, Media, RindleProfile}

  @impl true
  def mount(_params, _session, socket) do
    batch_members =
      Accounts.list_members()
      |> Enum.filter(&(&1.role == "student"))
      |> Enum.take(2)

    {:ok,
     assign(socket,
       page_title: "Ops surfaces",
       doctor_output: nil,
       runtime_output: nil,
       batch_preview: nil,
       batch_result: nil,
       batch_members: batch_members
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <h1 class="text-2xl font-semibold">Operator surfaces</h1>
      <p class="text-sm opacity-80">Doctor, runtime status, and batch owner erasure.</p>

      <div class="flex gap-3 mt-4">
        <button id="run-doctor-button" phx-click="run_doctor" class="btn" data-testid="run-doctor-button">
          Run doctor
        </button>
        <button id="run-runtime-status-button" phx-click="run_runtime_status" class="btn" data-testid="run-runtime-status-button">
          Run runtime status
        </button>
      </div>

      <pre :if={@doctor_output} id="doctor-output" class="mt-6 p-3 bg-gray-100 text-xs overflow-x-auto" data-testid="doctor-output">{@doctor_output}</pre>
      <pre :if={@runtime_output} id="runtime-status-output" class="mt-6 p-3 bg-gray-100 text-xs overflow-x-auto" data-testid="runtime-status-output">{@runtime_output}</pre>

      <section id="batch-erasure" class="mt-10 space-y-3" data-testid="batch-erasure-section">
        <h2 class="text-lg font-semibold">Batch owner erasure</h2>
        <p class="text-sm">
          Preview + execute for seeded students:
          <%= for member <- @batch_members do %>
            <span data-testid={"batch-member-#{member.email}"}>{member.name}</span>
          <% end %>
        </p>
        <div class="flex gap-3">
          <button id="preview-batch-button" phx-click="preview_batch" class="btn" data-testid="preview-batch-button">
            Preview batch
          </button>
          <button id="execute-batch-button" phx-click="execute_batch" class="btn" data-testid="execute-batch-button">
            Execute batch
          </button>
        </div>
        <pre :if={@batch_preview} id="batch-preview" class="p-3 bg-gray-100 text-xs" data-testid="batch-preview">{inspect(@batch_preview, pretty: true)}</pre>
        <pre :if={@batch_result} id="batch-result" class="p-3 bg-gray-100 text-xs" data-testid="batch-result">{inspect(@batch_result, pretty: true)}</pre>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("run_doctor", _params, socket) do
    report =
      Mix.Tasks.Rindle.Doctor.run_checks([to_string(RindleProfile)], exit_on_failure?: false)

    output = "doctor_success=#{report.success?}\n" <> inspect(report, pretty: true)
    {:noreply, assign(socket, :doctor_output, output)}
  end

  @impl true
  def handle_event("run_runtime_status", _params, socket) do
    output = runtime_status_output()

    {:noreply, assign(socket, :runtime_output, output)}
  end

  @impl true
  def handle_event("preview_batch", _params, socket) do
    preview = Media.preview_batch_erasure(socket.assigns.batch_members)
    {:noreply, assign(socket, :batch_preview, preview)}
  end

  @impl true
  def handle_event("execute_batch", _params, socket) do
    result = Media.erase_batch!(socket.assigns.batch_members)
    {:noreply, assign(socket, :batch_result, result)}
  end

  defp runtime_status_output do
    case Rindle.runtime_status([]) do
      {:ok, report} ->
        report
        |> Mix.Tasks.Rindle.RuntimeStatus.format_text_report()
        |> Enum.join("\n")

      {:error, reason} ->
        "Rindle.RuntimeStatus failed: #{inspect(reason)}"
    end
  end
end
