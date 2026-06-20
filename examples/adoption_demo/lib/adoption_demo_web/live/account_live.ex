defmodule AdoptionDemoWeb.AccountLive do
  use AdoptionDemoWeb, :live_view

  import AdoptionDemoWeb.CohortComponents

  alias AdoptionDemo.{Accounts, Media}
  alias AdoptionDemoWeb.CohortTheme

  @impl true
  def mount(params, _session, socket) do
    id = params["member_id"] || params["user_id"]
    member = Accounts.get_member!(id)
    theme = CohortTheme.normalize(params["theme"], "auto")

    {:ok,
     assign(socket,
       page_title: "Account deletion",
       theme: theme,
       member: member,
       preview: nil,
       result: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <.ck_page
        eyebrow="Owner erasure"
        title="Erase a member's media, end to end."
        lede="Right-to-be-forgotten for a single owner — preview exactly what Rindle will purge versus retain, then execute."
        theme={@theme}
      >
        <p class="ck-help" data-testid="erasure-member-name">
          Acting on <strong>{@member.name}</strong> ({@member.email}).
        </p>

        <div class="ck-toolbar ck-reveal" role="group" aria-label="Owner erasure" style="--d:.06s">
          <button
            id="preview-erasure-button"
            phx-click="preview"
            class="ck-btn"
            data-testid="preview-erasure-button"
          >
            Preview erasure
          </button>
          <button
            id="execute-erasure-button"
            phx-click="execute"
            class="ck-btn ck-btn--primary"
            data-testid="execute-erasure-button"
          >
            Erase member
          </button>
        </div>

        <div :if={@preview} class="ck-detail__term">Erasure preview</div>
        <pre :if={@preview} id="erasure-preview" class="ck-output" data-testid="erasure-preview">{inspect(@preview, pretty: true)}</pre>
        <div :if={@result} class="ck-detail__term">Erasure result</div>
        <pre :if={@result} id="erasure-result" class="ck-output" data-testid="erasure-result">{inspect(@result, pretty: true)}</pre>
      </.ck_page>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("preview", _params, socket) do
    preview = Media.preview_owner_erasure(socket.assigns.member)
    {:noreply, assign(socket, :preview, preview)}
  end

  @impl true
  def handle_event("execute", _params, socket) do
    result = Media.erase_owner!(socket.assigns.member)
    {:noreply, assign(socket, :result, result)}
  end
end
