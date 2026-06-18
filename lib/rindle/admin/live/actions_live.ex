if Code.ensure_loaded?(Phoenix.LiveView) do
  defmodule Rindle.Admin.Live.ActionsLive do
    @moduledoc false

    use Phoenix.LiveView

    import Rindle.Admin.Components

    alias Phoenix.LiveView.JS
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
         action_error: nil,
         action_data: %{}
       )
       |> load()}
    end

    @impl true
    def handle_event("select_action", %{"id" => id_str}, socket) do
      case find_action(socket.assigns.model.actions, id_str) do
        %{id: id} ->
          {:noreply,
           socket
           |> assign(
             active_action_id: id,
             action_state: :input,
             action_error: nil,
             action_data: %{}
           )}

        nil ->
          {:noreply, assign(socket, action_error: "Unknown admin action.")}
      end
    end

    @impl true
    def handle_event(
          "change_owner_erasure",
          _params,
          %{assigns: %{action_state: :input}} = socket
        ) do
      {:noreply, assign(socket, action_error: nil)}
    end

    def handle_event(
          "change_owner_erasure",
          %{"owner_type" => type, "owner_id" => id},
          %{assigns: %{action_data: %{type: current_type, id: current_id}}} = socket
        )
        when type == current_type and id == current_id do
      {:noreply, socket}
    end

    def handle_event("change_owner_erasure", _params, socket) do
      {:noreply, assign(socket, action_state: :input, action_error: nil, action_data: %{})}
    end

    @impl true
    def handle_event("preview_owner_erasure", %{"owner_type" => type, "owner_id" => id}, socket) do
      with {:ok, owner} <- parse_owner(type, id),
           {:ok, report} <- Rindle.preview_owner_erasure(owner) do
        {:noreply,
         assign(socket,
           action_state: :preview,
           action_error: nil,
           action_data: %{type: type, id: id, report: report}
         )}
      else
        {:error, message} when is_binary(message) ->
          {:noreply, assign(socket, action_error: message)}

        {:error, _} ->
          {:noreply, assign(socket, action_error: "Failed to preview erasure")}
      end
    end

    @impl true
    def handle_event(
          "execute_owner_erasure",
          %{"confirmation" => confirmation},
          %{
            assigns: %{
              action_state: :preview,
              action_data: %{type: type, id: id, report: _report}
            }
          } = socket
        ) do
      expected = "ERASE #{type}:#{id}"

      if confirmation == expected do
        case parse_owner(type, id) do
          {:ok, owner} ->
            execute_owner_erasure(socket, owner, type, id)

          {:error, message} ->
            {:noreply, assign(socket, action_error: message)}
        end
      else
        {:noreply, assign(socket, action_error: "Confirmation does not match.")}
      end
    end

    def handle_event("execute_owner_erasure", _params, socket) do
      {:noreply,
       assign(socket,
         action_state: :input,
         action_error: "Preview this action before executing.",
         action_data: %{}
       )}
    end

    @impl true
    def handle_event(
          "change_batch_erasure",
          _params,
          %{assigns: %{action_state: :input}} = socket
        ) do
      {:noreply, assign(socket, action_error: nil)}
    end

    def handle_event(
          "change_batch_erasure",
          %{"owners" => owners_text},
          %{assigns: %{action_data: %{owners_text: current_owners_text}}} = socket
        )
        when owners_text == current_owners_text do
      {:noreply, socket}
    end

    def handle_event("change_batch_erasure", _params, socket) do
      {:noreply, assign(socket, action_state: :input, action_error: nil, action_data: %{})}
    end

    @impl true
    def handle_event("preview_batch_erasure", %{"owners" => owners_text}, socket) do
      with {:ok, owners} <- parse_batch_owners(owners_text),
           {:ok, report} <- Rindle.preview_batch_owner_erasure(owners) do
        {:noreply,
         assign(socket,
           action_state: :preview,
           action_error: nil,
           action_data: %{owners_text: owners_text, report: report, count: length(owners)}
         )}
      else
        {:error, message} when is_binary(message) ->
          {:noreply, assign(socket, action_error: message)}

        {:error, _} ->
          {:noreply, assign(socket, action_error: "Failed to preview batch erasure")}
      end
    end

    @impl true
    def handle_event(
          "execute_batch_erasure",
          %{"confirmation" => confirmation},
          %{
            assigns: %{
              action_state: :preview,
              action_data: %{owners_text: owners_text, count: count}
            }
          } = socket
        ) do
      expected = "ERASE #{count} OWNERS"

      if confirmation == expected do
        case parse_batch_owners(owners_text) do
          {:ok, owners} ->
            execute_batch_erasure(socket, owners)

          {:error, message} ->
            {:noreply, assign(socket, action_error: message)}
        end
      else
        {:noreply, assign(socket, action_error: "Confirmation does not match.")}
      end
    end

    def handle_event("execute_batch_erasure", _params, socket) do
      {:noreply,
       assign(socket,
         action_state: :input,
         action_error: "Preview this action before executing.",
         action_data: %{}
       )}
    end

    # NOTE (UI-SPEC §E, D-98-10): the lifecycle-repair (reconcile) and
    # variant-regeneration verbs were DISTRIBUTED off this Maintenance
    # junk-drawer to their contextual surfaces — regenerate now confirms through
    # confirm_dialog/1 on Processing (variants_jobs_live.ex), reconcile/verify
    # storage lives on Doctor (runtime_doctor_live.ex). Their handlers/forms were
    # removed here; Maintenance keeps only the contextless GDPR-driven erasure ops.

    defp execute_owner_erasure(socket, owner, type, id) do
      case Rindle.erase_owner(owner) do
        {:ok, report} ->
          {:noreply,
           assign(socket,
             action_state: :receipt,
             action_error: nil,
             action_data: %{type: type, id: id, report: report}
           )}

        {:error, _} ->
          {:noreply, assign(socket, action_error: "Execution failed")}
      end
    end

    defp execute_batch_erasure(socket, owners) do
      case Rindle.erase_batch_owner_erasure(owners) do
        {:ok, report} ->
          {:noreply,
           assign(socket,
             action_state: :receipt,
             action_error: nil,
             action_data: %{report: report}
           )}

        {:error,
         {:batch_owner_failed, %{owner: failed, reason: reason, partial_report: partial_report}}} ->
          {:noreply,
           assign(socket,
             action_state: :partial_receipt,
             action_error: nil,
             action_data: %{
               report: partial_report,
               failed_owner: inspect(failed),
               reason: inspect(reason)
             }
           )}

        {:error, _} ->
          {:noreply, assign(socket, action_error: "Batch execution failed entirely")}
      end
    end

    defp parse_batch_owners(text) do
      owners =
        text
        |> String.split("\n", trim: true)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      case owners do
        [] -> {:error, "Enter at least one owner."}
        _ -> parse_batch_owner_lines(owners)
      end
    end

    defp parse_batch_owner_lines(lines) do
      lines
      |> Enum.reduce_while({:ok, []}, fn line, {:ok, owners} ->
        case String.split(line, ":", parts: 2) do
          [type, id] when type != "" and id != "" ->
            case parse_owner(type, id) do
              {:ok, owner} -> {:cont, {:ok, [owner | owners]}}
              {:error, message} -> {:halt, {:error, message}}
            end

          _ ->
            {:halt, {:error, "Owners must be formatted as Module:id, one per line."}}
        end
      end)
      |> case do
        {:ok, owners} -> {:ok, Enum.reverse(owners)}
        {:error, _} = error -> error
      end
    end

    defp parse_owner(type, id) when is_binary(type) and is_binary(id) do
      type = String.trim(type)
      id = String.trim(id)

      with {:ok, module} <- resolve_owner_module(type),
           true <- id != "" do
        {:ok, %{__struct__: module, id: id}}
      else
        false -> {:error, "Owner ID is required."}
        {:error, _} -> {:error, "Unsupported owner type."}
      end
    end

    defp resolve_owner_module(type) do
      type
      |> owner_module_candidates()
      |> Enum.find_value(fn candidate ->
        case existing_loaded_module(candidate) do
          {:ok, module} -> module
          :error -> nil
        end
      end)
      |> case do
        nil -> {:error, :unsupported_owner_type}
        module -> {:ok, module}
      end
    end

    defp owner_module_candidates(""), do: []

    defp owner_module_candidates("Elixir." <> _ = type), do: [type]

    defp owner_module_candidates(type), do: [type, "Elixir." <> type]

    defp existing_loaded_module(candidate) do
      module = String.to_existing_atom(candidate)

      if Code.ensure_loaded?(module) do
        {:ok, module}
      else
        :error
      end
    rescue
      ArgumentError -> :error
    end

    @impl true
    def render(assigns) do
      ~H"""
      <.shell active="actions" base_path={@admin_base_path} title="Maintenance" live_status={@live_status} dialog_open={@action_state == :preview}>
        <.page state={if(@error?, do: :error, else: :ok)} error_surface="Actions">
          <:summary>
            <section class="rindle-admin-actions-directory">
              <h2>Actions Directory</h2>
              <div class="rindle-admin-actions-tabs">
                <button
                  :for={action <- @model.actions}
                  class={["rindle-admin-actions-tab", if(@active_action_id == action.id, do: "active", else: "")]}
                  phx-click="select_action"
                  phx-value-id={action.id}
                  data-rindle-admin-action={action.id}
                >
                  {action.label}
                </button>
              </div>
            </section>
          </:summary>
          <:work>
            <div class="rindle-admin-action-panel" data-rindle-admin-action-panel={@active_action_id}>
              <%= render_action_panel(assigns, current_action(assigns)) %>
            </div>
          </:work>
        </.page>
        <%!-- CR-02/CR-03: the destructive-confirmation dialog renders into the shell
              `:overlay` slot — a SIBLING of the inerted `<main>` — so when the
              `:preview` state inerts `<main>` the confirmation form (and its typed
              confirmation gate) stays interactive. Both owner AND batch erasure go
              through the same confirm_dialog primitive, so `dialog_open` is never
              driven from a state with no overlay to host it. --%>
        <:overlay>
          <%= render_action_overlay(assigns, current_action(assigns)) %>
        </:overlay>
      </.shell>
      """
    end

    defp current_action(assigns) do
      Enum.find(assigns.model.actions, &(&1.id == assigns.active_action_id)) ||
        List.first(assigns.model.actions)
    end

    defp find_action(actions, id_str) do
      Enum.find(actions, &(Atom.to_string(&1.id) == id_str))
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
          <.destructive_warning />
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
          <.destructive_warning />
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

    # CR-02/CR-03: destructive-confirmation dialogs rendered into the shell `:overlay`
    # slot (sibling of the inerted `<main>`). Only the active erasure action in the
    # `:preview` state renders a dialog; every other state renders nothing so the
    # overlay host stays empty (and `<main>` is never inerted without a live dialog).
    defp render_action_overlay(%{action_state: :preview} = assigns, %{id: :owner_erasure}) do
      ~H"""
      <.confirm_dialog id="owner-erasure-confirm" show={true} on_cancel={JS.push("change_owner_erasure")}>
        <:title>Erase this owner?</:title>
        <form phx-change="change_owner_erasure" phx-submit="execute_owner_erasure" data-rindle-admin-form="owner_erasure_execute">
          <p>
            This permanently erases owner data and enqueues purge of the associated assets. This action cannot be undone.
          </p>
          <div>
            <label>Owner Type</label>
            <input type="text" name="owner_type" value={@action_data.type} data-rindle-admin-input="owner_type" required />
          </div>
          <div>
            <label>Owner ID</label>
            <input type="text" name="owner_id" value={@action_data.id} data-rindle-admin-input="owner_id" required />
          </div>
          <div>
            <label>Type <pre>ERASE {@action_data.type}:{@action_data.id}</pre> to confirm</label>
            <input type="text" name="confirmation" data-rindle-admin-confirm-input data-rindle-admin-input="confirmation" required />
          </div>
          <%= if @action_error do %>
            <p class="rindle-admin-toast rindle-admin-toast--danger" data-rindle-admin-action-error>{@action_error}</p>
          <% end %>
          <button type="submit" class="rindle-admin-button rindle-admin-button--destructive rindle-admin-target-min" data-rindle-admin-submit="execute_owner_erasure">Erase owner</button>
        </form>
      </.confirm_dialog>
      """
    end

    defp render_action_overlay(%{action_state: :preview} = assigns, %{id: :batch_erasure}) do
      ~H"""
      <.confirm_dialog id="batch-erasure-confirm" show={true} on_cancel={JS.push("change_batch_erasure")}>
        <:title>Erase these owners?</:title>
        <form phx-change="change_batch_erasure" phx-submit="execute_batch_erasure" data-rindle-admin-form="batch_erasure_execute">
          <p>
            This permanently erases owner data and enqueues purge of the associated assets. This action cannot be undone.
          </p>
          <div>
            <label>Owners</label>
            <textarea name="owners" rows="5" data-rindle-admin-input="batch_owners" required>{@action_data.owners_text}</textarea>
          </div>
          <div>
            <label>Type <pre>ERASE {@action_data.count} OWNERS</pre> to confirm</label>
            <input type="text" name="confirmation" data-rindle-admin-confirm-input data-rindle-admin-input="confirmation" required />
          </div>
          <%= if @action_error do %>
            <p class="rindle-admin-toast rindle-admin-toast--danger" data-rindle-admin-action-error>{@action_error}</p>
          <% end %>
          <button type="submit" class="rindle-admin-button rindle-admin-button--destructive rindle-admin-target-min" data-rindle-admin-submit="execute_batch_erasure">Erase owners</button>
        </form>
      </.confirm_dialog>
      """
    end

    defp render_action_overlay(assigns, _action) do
      ~H""
    end

    # Standing destructive affordance rendered on every erasure panel, independent of the
    # transient confirmation-error toast. Makes "this is destructive" a deterministic,
    # design-system-enforced contract (asserted in tests) rather than a subjective judgment.
    defp destructive_warning(assigns) do
      ~H"""
      <p
        class="rindle-admin-toast rindle-admin-toast--danger"
        data-rindle-admin-destructive-warning
        role="alert"
      >
        This permanently erases owner data and enqueues purge of the associated assets. This action cannot be undone.
      </p>
      """
    end

    defp render_owner_erasure_state(%{action_state: :input} = assigns) do
      ~H"""
      <div data-rindle-admin-state="input">
        <form phx-submit="preview_owner_erasure" phx-change="change_owner_erasure" data-rindle-admin-form="owner_erasure_preview">
          <div>
            <label>Owner Type</label>
            <input type="text" name="owner_type" data-rindle-admin-input="owner_type" required />
          </div>
          <div>
            <label>Owner ID</label>
            <input type="text" name="owner_id" data-rindle-admin-input="owner_id" required />
          </div>
          <%= if @action_error do %>
            <p class="rindle-admin-toast rindle-admin-toast--danger" data-rindle-admin-action-error>{@action_error}</p>
          <% end %>
          <button type="submit" class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" data-rindle-admin-submit="preview_owner_erasure">Preview owner erasure</button>
        </form>
      </div>
      """
    end

    defp render_owner_erasure_state(%{action_state: :preview} = assigns) do
      ~H"""
      <div data-rindle-admin-state="preview">
        <div data-rindle-admin-preview="owner_erasure">
          <h4>Preview Report</h4>
          <p>Attachments to detach: {@action_data.report.attachments_to_detach.count}</p>
        </div>
        <%!-- CR-02: the confirmation form lives in the shell `:overlay` slot
              (render_action_overlay/2), NOT here — rendering it inside `:work` would
              nest it under the inerted `<main>` and disable the confirmation gate. --%>
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
        <form phx-submit="preview_batch_erasure" phx-change="change_batch_erasure" data-rindle-admin-form="batch_erasure_preview">
          <div>
            <label>Owners (one per line as Module:id)</label>
            <textarea name="owners" rows="5" data-rindle-admin-input="batch_owners" required></textarea>
          </div>
          <%= if @action_error do %>
            <p class="rindle-admin-toast rindle-admin-toast--danger" data-rindle-admin-action-error>{@action_error}</p>
          <% end %>
          <button type="submit" class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" data-rindle-admin-submit="preview_batch_erasure">Preview batch erasure</button>
        </form>
      </div>
      """
    end

    defp render_batch_erasure_state(%{action_state: :preview} = assigns) do
      ~H"""
      <div data-rindle-admin-state="preview">
        <div data-rindle-admin-preview="batch_erasure">
          <h4>Preview Report</h4>
          <p>Owners to process: {@action_data.count}</p>
          <p>Attachments to detach: {@action_data.report.attachments_to_detach.count}</p>
        </div>
        <%!-- CR-03: batch-erasure confirmation now routes through the shared
              confirm_dialog primitive in the shell `:overlay` slot
              (render_action_overlay/2). Previously this was a plain inline `<form>`
              with no overlay, so when `dialog_open` (action_state == :preview) inerted
              `<main>` the batch confirmation form was disabled with nothing to host it. --%>
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
