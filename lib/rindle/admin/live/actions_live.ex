if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.Admin.Live.ActionsLive do
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
         page_title: "Rindle Admin - Actions",
         live_status: "Waiting for lifecycle events",
         model: %{actions: []},
         error?: false,
         active_action_id: :owner_erasure,
         action_state: :input,
         action_data: %{}
       )
       |> load()}
    end

    @impl true
    def handle_event("select_action", %{"id" => id_str}, socket) do
      id = String.to_existing_atom(id_str)

      {:noreply,
       socket
       |> assign(
         active_action_id: id,
         action_state: :input,
         action_data: %{}
       )}
    end

    @impl true
    def handle_event("change_owner_erasure", _params, %{assigns: %{action_state: :input}} = socket) do
      {:noreply, socket}
    end

    def handle_event("change_owner_erasure", _params, socket) do
      {:noreply, assign(socket, action_state: :input, action_data: %{})}
    end

    @impl true
    def handle_event("preview_owner_erasure", %{"owner_type" => type, "owner_id" => id}, socket) do
      owner = %{__struct__: String.to_atom(type), id: id}

      case Rindle.preview_owner_erasure(owner) do
        {:ok, report} ->
          {:noreply, assign(socket, action_state: :preview, action_data: %{type: type, id: id, report: report})}
        {:error, _} ->
          {:noreply, socket |> put_flash(:error, "Failed to preview erasure")}
      end
    end

    @impl true
    def handle_event("execute_owner_erasure", %{"confirmation" => confirmation}, socket) do
      %{type: type, id: id, report: _report} = socket.assigns.action_data
      expected = "ERASE #{type}:#{id}"

      if confirmation == expected do
        owner = %{__struct__: String.to_atom(type), id: id}
        case Rindle.erase_owner(owner) do
          {:ok, report} ->
            {:noreply, assign(socket, action_state: :receipt, action_data: %{report: report, type: type, id: id})}
          {:error, _} ->
            {:noreply, socket |> put_flash(:error, "Execution failed")}
        end
      else
        {:noreply, socket |> put_flash(:error, "Confirmation does not match.")}
      end
    end

    @impl true
    def handle_event("change_batch_erasure", _params, %{assigns: %{action_state: :input}} = socket) do
      {:noreply, socket}
    end

    def handle_event("change_batch_erasure", _params, socket) do
      {:noreply, assign(socket, action_state: :input, action_data: %{})}
    end

    @impl true
    def handle_event("preview_batch_erasure", %{"owners" => owners_text}, socket) do
      owners = parse_batch_owners(owners_text)

      case Rindle.preview_batch_owner_erasure(owners) do
        {:ok, report} ->
          {:noreply, assign(socket, action_state: :preview, action_data: %{owners_text: owners_text, report: report, count: length(owners)})}
        {:error, _} ->
          {:noreply, socket |> put_flash(:error, "Failed to preview batch erasure")}
      end
    end

    @impl true
    def handle_event("execute_batch_erasure", %{"confirmation" => confirmation}, socket) do
      %{owners_text: owners_text, count: count} = socket.assigns.action_data
      expected = "ERASE #{count} OWNERS"

      if confirmation == expected do
        owners = parse_batch_owners(owners_text)
        case Rindle.erase_batch_owner_erasure(owners) do
          {:ok, report} ->
            {:noreply, assign(socket, action_state: :receipt, action_data: %{report: report})}
          {:error, {:batch_owner_failed, %{owner: failed, reason: reason, partial_report: partial_report}}} ->
            {:noreply, assign(socket, action_state: :partial_receipt, action_data: %{
              report: partial_report,
              failed_owner: inspect(failed),
              reason: inspect(reason)
            })}
          {:error, _} ->
            {:noreply, socket |> put_flash(:error, "Batch execution failed entirely")}
        end
      else
        {:noreply, socket |> put_flash(:error, "Confirmation does not match.")}
      end
    end

    defp parse_batch_owners(text) do
      text
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(fn line ->
        [type, id] = String.split(line, ":", parts: 2)
        %{__struct__: String.to_atom(type), id: id}
      end)
    end

    @impl true
    def render(assigns) do
      ~H"""
      <.shell active="actions" base_path={@admin_base_path} title="Actions" live_status={@live_status}>
        <section class="rindle-admin-actions-directory">
          <h2>Actions Directory</h2>
          <div class="rindle-admin-actions-tabs" style="display: flex; gap: 1rem; margin-bottom: 2rem;">
            <button
              :for={action <- @model.actions}
              class={["rindle-admin-actions-tab", if(@active_action_id == action.id, do: "active", else: "")]}
              phx-click="select_action"
              phx-value-id={action.id}
            >
              {action.label}
            </button>
          </div>
        </section>

        <%= if @error? do %>
          <.error_state surface="Actions" />
        <% else %>
          <div class="rindle-admin-action-panel">
            <%= render_action_panel(assigns, current_action(assigns)) %>
          </div>
        <% end %>
      </.shell>
      """
    end

    defp current_action(assigns) do
      Enum.find(assigns.model.actions, &(&1.id == assigns.active_action_id)) || List.first(assigns.model.actions)
    end

    defp render_action_panel(assigns, %{id: :owner_erasure} = selected_action) do
      assigns = assign(assigns, :action, selected_action)
      ~H"""
      <div>
        <h3>{@action.label}</h3>
        <p>{@action.summary}</p>
        <%= if not @action.enabled? do %>
          <.status_chip state="info" label="coming soon" />
        <% else %>
          <%= render_owner_erasure_state(assigns) %>
        <% end %>
      </div>
      """
    end

    defp render_action_panel(assigns, %{id: :batch_erasure} = selected_action) do
      assigns = assign(assigns, :action, selected_action)
      ~H"""
      <div>
        <h3>{@action.label}</h3>
        <p>{@action.summary}</p>
        <%= if not @action.enabled? do %>
          <.status_chip state="info" label="coming soon" />
        <% else %>
          <%= render_batch_erasure_state(assigns) %>
        <% end %>
      </div>
      """
    end

    defp render_action_panel(assigns, selected_action) do
      assigns = assign(assigns, :action, selected_action)
      ~H"""
      <div>
        <h3>{@action.label}</h3>
        <p>{@action.summary}</p>
        <.status_chip state="info" label="coming soon" />
      </div>
      """
    end

    defp render_owner_erasure_state(%{action_state: :input} = assigns) do
      ~H"""
      <div data-rindle-admin-state="input">
        <form phx-submit="preview_owner_erasure" phx-change="change_owner_erasure">
          <div>
            <label>Owner Type</label>
            <input type="text" name="owner_type" required />
          </div>
          <div>
            <label>Owner ID</label>
            <input type="text" name="owner_id" required />
          </div>
          <button type="submit">Preview owner erasure</button>
        </form>
      </div>
      """
    end

    defp render_owner_erasure_state(%{action_state: :preview} = assigns) do
      ~H"""
      <div data-rindle-admin-state="preview">
        <form phx-change="change_owner_erasure" phx-submit="execute_owner_erasure">
          <div>
            <label>Owner Type</label>
            <input type="text" name="owner_type" value={@action_data.type} required />
          </div>
          <div>
            <label>Owner ID</label>
            <input type="text" name="owner_id" value={@action_data.id} required />
          </div>
          <div>
            <h4>Preview Report</h4>
            <p>Attachments to detach: {@action_data.report.attachments_to_detach.count}</p>
          </div>
          <div>
            <label>Type <pre>ERASE {@action_data.type}:{@action_data.id}</pre> to confirm</label>
            <input type="text" name="confirmation" data-rindle-admin-confirm-input required />
          </div>
          <button type="submit">Erase owner</button>
        </form>
      </div>
      """
    end

    defp render_owner_erasure_state(%{action_state: :receipt} = assigns) do
      ~H"""
      <div data-rindle-admin-state="receipt" data-rindle-admin-receipt="owner_erasure">
        <h4>Owner Erasure Complete</h4>
        <p>Attachments detached: {@action_data.report.attachments_to_detach.count}</p>
        <p>Purge enqueued: {@action_data.report.purge_enqueued}</p>
      </div>
      """
    end

    defp render_batch_erasure_state(%{action_state: :input} = assigns) do
      ~H"""
      <div data-rindle-admin-state="input">
        <form phx-submit="preview_batch_erasure" phx-change="change_batch_erasure">
          <div>
            <label>Owners (one per line as Module:id)</label>
            <textarea name="owners" rows="5" required></textarea>
          </div>
          <button type="submit">Preview batch erasure</button>
        </form>
      </div>
      """
    end

    defp render_batch_erasure_state(%{action_state: :preview} = assigns) do
      ~H"""
      <div data-rindle-admin-state="preview">
        <form phx-change="change_batch_erasure" phx-submit="execute_batch_erasure">
          <div>
            <label>Owners</label>
            <textarea name="owners" rows="5" required>{@action_data.owners_text}</textarea>
          </div>
          <div>
            <h4>Preview Report</h4>
            <p>Owners to process: {@action_data.count}</p>
            <p>Attachments to detach: {@action_data.report.attachments_to_detach.count}</p>
          </div>
          <div>
            <label>Type <pre>ERASE {@action_data.count} OWNERS</pre> to confirm</label>
            <input type="text" name="confirmation" data-rindle-admin-confirm-input required />
          </div>
          <button type="submit">Erase owners</button>
        </form>
      </div>
      """
    end

    defp render_batch_erasure_state(%{action_state: :receipt} = assigns) do
      ~H"""
      <div data-rindle-admin-state="receipt" data-rindle-admin-receipt="batch_erasure">
        <h4>Batch Erasure Complete</h4>
        <p>Attachments detached: {@action_data.report.attachments_to_detach.count}</p>
        <p>Purge enqueued: {Enum.reduce(@action_data.report.owners || [], 0, fn o, acc -> acc + (o.report[:purge_enqueued] || 0) end)}</p>
      </div>
      """
    end

    defp render_batch_erasure_state(%{action_state: :partial_receipt} = assigns) do
      ~H"""
      <div data-rindle-admin-state="receipt" data-rindle-admin-receipt="batch_erasure" data-rindle-admin-error="batch_failed">
        <h4>Batch Erasure Partial Failure</h4>
        <p>Attachments detached: {@action_data.report.attachments_to_detach.count}</p>
        <p>Purge enqueued: {Enum.reduce(@action_data.report.owners || [], 0, fn o, acc -> acc + (o.report[:purge_enqueued] || 0) end)}</p>
        <div>
          <h5>Failed Owner</h5>
          <pre>{@action_data.failed_owner}</pre>
          <p>Reason: {@action_data.reason}</p>
        </div>
      </div>
      """
    end

    defp load(socket) do
      {:ok, model} = Queries.actions_directory()
      assign(socket, model: model, error?: false)
    end
  end
end