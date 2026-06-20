defmodule AdoptionDemoWeb.OpsLive do
  use AdoptionDemoWeb, :live_view

  import AdoptionDemoWeb.CohortComponents

  alias AdoptionDemo.{Accounts, Media, RindleProfile}
  alias AdoptionDemoWeb.CohortTheme

  @impl true
  def mount(params, _session, socket) do
    theme = CohortTheme.normalize(params["theme"], "auto")

    batch_members =
      Accounts.list_members()
      |> Enum.filter(&(&1.role == "student"))
      |> Enum.take(2)

    {:ok,
     assign(socket,
       page_title: "Ops surfaces",
       theme: theme,
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
      <.ck_page
        eyebrow="Operator surfaces"
        title="Run Rindle's day-2 operations."
        lede="The maintenance commands an operator reaches for — health checks, runtime status, and GDPR owner erasure — wired to this demo's real data."
        theme={@theme}
      >
        <section class="ck-section ck-reveal" style="--d:.06s" aria-label="Diagnostics">
          <div class="ck-section__head">
            <h2 class="ck-section__title">Diagnostics</h2>
            <span class="ck-section__hint">Inspect the install and the running system.</span>
          </div>
          <div class="ck-toolbar" role="group" aria-label="Diagnostic checks">
            <button
              id="run-doctor-button"
              phx-click="run_doctor"
              class="ck-btn ck-btn--primary"
              data-testid="run-doctor-button"
            >
              Run health check
            </button>
            <button
              id="run-runtime-status-button"
              phx-click="run_runtime_status"
              class="ck-btn"
              data-testid="run-runtime-status-button"
            >
              Check runtime status
            </button>
          </div>

          <div :if={@doctor_output} class="ck-detail__term">Doctor report</div>
          <pre :if={@doctor_output} id="doctor-output" class="ck-output" data-testid="doctor-output">{@doctor_output}</pre>
          <div :if={@runtime_output} class="ck-detail__term">Runtime status</div>
          <pre
            :if={@runtime_output}
            id="runtime-status-output"
            class="ck-output"
            data-testid="runtime-status-output"
          >{@runtime_output}</pre>
        </section>

        <section
          id="batch-erasure"
          class="ck-section ck-reveal"
          data-testid="batch-erasure-section"
          style="--d:.12s"
        >
          <div class="ck-section__head">
            <h2 class="ck-section__title">Batch owner erasure</h2>
            <span class="ck-section__hint">
              Right-to-be-forgotten across multiple owners at once.
            </span>
          </div>
          <p class="ck-help">
            Audit, then erase, these seeded students:
            <span
              :for={member <- @batch_members}
              class="ck-badge ck-badge--info"
              data-testid={"batch-member-#{member.email}"}
            >
              {member.name}
            </span>
          </p>
          <div class="ck-toolbar" role="group" aria-label="Batch erasure">
            <button
              id="preview-batch-button"
              phx-click="preview_batch"
              class="ck-btn"
              data-testid="preview-batch-button"
            >
              Preview erasure
            </button>
            <button
              id="execute-batch-button"
              phx-click="execute_batch"
              class="ck-btn ck-btn--primary"
              data-testid="execute-batch-button"
            >
              Erase members
            </button>
          </div>
          <div :if={@batch_preview} class="ck-detail__term">Erasure preview</div>
          <pre :if={@batch_preview} id="batch-preview" class="ck-output" data-testid="batch-preview">{inspect(@batch_preview, pretty: true)}</pre>
          <div :if={@batch_result} class="ck-detail__term">Erasure result</div>
          <pre :if={@batch_result} id="batch-result" class="ck-output" data-testid="batch-result">{inspect(@batch_result, pretty: true)}</pre>
        </section>
      </.ck_page>
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
