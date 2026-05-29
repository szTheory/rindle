defmodule AdoptionDemoWeb.AccountLive do
  use AdoptionDemoWeb, :live_view

  alias AdoptionDemo.{Accounts, Media}

  @impl true
  def mount(%{"user_id" => user_id}, _session, socket) do
    user = Accounts.get_user!(user_id)

    {:ok,
     assign(socket,
       page_title: "Account deletion",
       user: user,
       preview: nil,
       result: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} page_title={@page_title}>
      <h1 class="text-2xl font-semibold">Owner erasure demo</h1>
      <p class="text-sm">User: { @user.name} ({@user.email})</p>

      <div class="flex gap-3 mt-4">
        <button id="preview-erasure-button" phx-click="preview" class="btn">Preview erasure</button>
        <button id="execute-erasure-button" phx-click="execute" class="btn">Execute erasure</button>
      </div>

      <pre :if={@preview} id="erasure-preview" class="mt-6 p-3 bg-gray-100 text-xs">{inspect(@preview, pretty: true)}</pre>
      <pre :if={@result} id="erasure-result" class="mt-6 p-3 bg-gray-100 text-xs">{inspect(@result, pretty: true)}</pre>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("preview", _params, socket) do
    preview = Media.preview_owner_erasure(socket.assigns.user)
    {:noreply, assign(socket, :preview, preview)}
  end

  @impl true
  def handle_event("execute", _params, socket) do
    result = Media.erase_owner!(socket.assigns.user)
    {:noreply, assign(socket, :result, result)}
  end
end
