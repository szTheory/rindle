defmodule AdoptionDemoWeb.OpsLive do
  use AdoptionDemoWeb, :live_view

  alias AdoptionDemo.RindleProfile

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Ops surfaces",
       doctor_output: nil,
       runtime_output: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <h1 class="text-2xl font-semibold">Operator surfaces</h1>
      <p class="text-sm opacity-80">Read-only demo of doctor and runtime status Mix tasks.</p>

      <div class="flex gap-3 mt-4">
        <button id="run-doctor-button" phx-click="run_doctor" class="btn">Run doctor</button>
        <button id="run-runtime-status-button" phx-click="run_runtime_status" class="btn">
          Run runtime status
        </button>
      </div>

      <pre :if={@doctor_output} id="doctor-output" class="mt-6 p-3 bg-gray-100 text-xs overflow-x-auto">{@doctor_output}</pre>
      <pre :if={@runtime_output} id="runtime-status-output" class="mt-6 p-3 bg-gray-100 text-xs overflow-x-auto">{@runtime_output}</pre>
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
    output =
      capture_io(fn ->
        Mix.Task.run("rindle.runtime_status", [])
      end)

    {:noreply, assign(socket, :runtime_output, output)}
  end

  defp capture_io(fun) do
    ExUnit.CaptureIO.capture_io(fun)
  end
end
