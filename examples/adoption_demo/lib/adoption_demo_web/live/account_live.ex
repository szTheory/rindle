defmodule AdoptionDemoWeb.AccountLive do
  use AdoptionDemoWeb, :live_view

  alias AdoptionDemo.{Accounts, Media}

  @impl true
  def mount(params, _session, socket) do
    id = params["member_id"] || params["user_id"]
    member = Accounts.get_member!(id)

    {:ok,
     assign(socket,
       page_title: "Account deletion",
       member: member,
       preview: nil,
       result: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <h1 class="text-2xl font-semibold">Owner erasure demo</h1>
      <p class="text-sm" data-testid="erasure-member-name">
        Member: {@member.name} ({@member.email})
      </p>

      <div class="flex gap-3 mt-4">
        <button id="preview-erasure-button" phx-click="preview" class="btn" data-testid="preview-erasure-button">
          Preview erasure
        </button>
        <button id="execute-erasure-button" phx-click="execute" class="btn" data-testid="execute-erasure-button">
          Execute erasure
        </button>
      </div>

      <pre :if={@preview} id="erasure-preview" class="mt-6 p-3 bg-gray-100 text-xs" data-testid="erasure-preview">{inspect(@preview, pretty: true)}</pre>
      <pre :if={@result} id="erasure-result" class="mt-6 p-3 bg-gray-100 text-xs" data-testid="erasure-result">{inspect(@result, pretty: true)}</pre>
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
