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
    def handle_event("execute_owner_erasure", %{"confirmation" => confirmation}, socket) do
      %{type: type, id: id, report: _report} = socket.assigns.action_data
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
    def handle_event("execute_batch_erasure", %{"confirmation" => confirmation}, socket) do
      %{owners_text: owners_text, count: count} = socket.assigns.action_data
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

    @impl true
    def handle_event(
          "change_lifecycle_repair",
          _params,
          %{assigns: %{action_state: :input}} = socket
        ) do
      {:noreply, socket}
    end

    def handle_event("change_lifecycle_repair", _params, socket) do
      {:noreply, assign(socket, action_state: :input, action_error: nil, action_data: %{})}
    end

    @impl true
    def handle_event(
          "execute_lifecycle_repair",
          %{"asset_id" => id, "repair_action" => action},
          socket
        ) do
      case action do
        "reprobe" ->
          case run_lifecycle_action(fn -> Rindle.reprobe(id) end) do
            {:ok, report} ->
              {:noreply,
               assign(socket,
                 action_state: :receipt,
                 action_error: nil,
                 action_data: %{action: "reprobe", success: true, report: report}
               )}

            {:error, _} ->
              {:noreply,
               assign(socket,
                 action_state: :receipt,
                 action_error: nil,
                 action_data: %{action: "reprobe", success: false, error: "Reprobe failed"}
               )}
          end

        "requeue" ->
          case run_lifecycle_action(fn -> Rindle.requeue_variants(id) end) do
            {:ok, report} ->
              {:noreply,
               assign(socket,
                 action_state: :receipt,
                 action_error: nil,
                 action_data: %{action: "requeue", success: true, report: report}
               )}

            {:error, _} ->
              {:noreply,
               assign(socket,
                 action_state: :receipt,
                 action_error: nil,
                 action_data: %{action: "requeue", success: false, error: "Requeue failed"}
               )}
          end

        _ ->
          {:noreply, assign(socket, action_error: "Unsupported lifecycle repair action.")}
      end
    end

    @impl true
    def handle_event(
          "change_variant_regeneration",
          _params,
          %{assigns: %{action_state: :input}} = socket
        ) do
      {:noreply, assign(socket, action_error: nil)}
    end

    def handle_event("change_variant_regeneration", _params, socket) do
      {:noreply, assign(socket, action_state: :input, action_error: nil, action_data: %{})}
    end

    @impl true
    def handle_event(
          "execute_variant_regeneration",
          %{"profile" => p, "variant_name" => v, "confirm" => "true"},
          socket
        ) do
      opts = %{}
      opts = if p != "", do: Map.put(opts, :profile, p), else: opts
      opts = if v != "", do: Map.put(opts, :variant_name, v), else: opts

      case Rindle.Ops.VariantMaintenance.regenerate_variants(opts) do
        {:ok, report} ->
          {:noreply,
           assign(socket,
             action_state: :receipt,
             action_error: nil,
             action_data: %{report: report}
           )}

        {:error, _} ->
          {:noreply,
           assign(socket,
             action_state: :receipt,
             action_error: nil,
             action_data: %{report: %{enqueued: 0, skipped: 0, errors: 1}}
           )}
      end
    end

    def handle_event("execute_variant_regeneration", _params, socket) do
      {:noreply, assign(socket, action_error: "You must confirm this action")}
    end

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

    defp run_lifecycle_action(fun) do
      fun.()
    rescue
      exception -> {:error, {exception.__struct__, Exception.message(exception)}}
    catch
      kind, reason -> {:error, {kind, reason}}
    end

    @impl true
    def render(assigns) do
      ~H"""
      <.shell active="actions" base_path={@admin_base_path} title="Actions" live_status={@live_status}>
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

        <%= if @error? do %>
          <.error_state surface="Actions" />
        <% else %>
          <div class="rindle-admin-action-panel" data-rindle-admin-action-panel={@active_action_id}>
            <%= render_action_panel(assigns, current_action(assigns)) %>
          </div>
        <% end %>
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

    defp render_action_panel(assigns, %{id: :lifecycle_repair} = selected_action) do
      assigns = assign(assigns, :action, selected_action)

      ~H"""
      <div>
        <h3>{@action.label}</h3>
        <p>{@action.summary}</p>
        <%= if not @action.enabled? do %>
          <.status_chip state="info" label="coming soon" />
        <% else %>
          <%= render_lifecycle_repair_state(assigns) %>
        <% end %>
      </div>
      """
    end

    defp render_action_panel(assigns, %{id: :variant_regeneration} = selected_action) do
      assigns = assign(assigns, :action, selected_action)

      ~H"""
      <div>
        <h3>{@action.label}</h3>
        <p>{@action.summary}</p>
        <%= if not @action.enabled? do %>
          <.status_chip state="info" label="coming soon" />
        <% else %>
          <%= render_variant_regeneration_state(assigns) %>
        <% end %>
      </div>
      """
    end

    defp render_action_panel(assigns, %{id: :quarantine_review} = selected_action) do
      assigns = assign(assigns, :action, selected_action)

      ~H"""
      <div>
        <h3>{@action.label}</h3>
        <p>{@action.summary}</p>
        <%= if not @action.enabled? do %>
          <.status_chip state="info" label="coming soon" />
        <% else %>
          <div data-rindle-admin-panel="quarantine_review" class="rindle-admin-quarantine-panel">
            <p><strong>Read-Only Triage</strong></p>
            <p>Rindle Admin does not release assets from quarantine. They are permanently blocked from delivery.</p>
            <p>To view quarantined assets, filter the Asset List by <code>state=quarantined</code>.</p>
            <p>Removal requires standard owner erasure via the Owner Erasure panel.</p>
          </div>
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
          <button type="submit" data-rindle-admin-submit="preview_owner_erasure">Preview owner erasure</button>
        </form>
      </div>
      """
    end

    defp render_owner_erasure_state(%{action_state: :preview} = assigns) do
      ~H"""
      <div data-rindle-admin-state="preview">
        <form phx-change="change_owner_erasure" phx-submit="execute_owner_erasure" data-rindle-admin-form="owner_erasure_execute">
          <div>
            <label>Owner Type</label>
            <input type="text" name="owner_type" value={@action_data.type} data-rindle-admin-input="owner_type" required />
          </div>
          <div>
            <label>Owner ID</label>
            <input type="text" name="owner_id" value={@action_data.id} data-rindle-admin-input="owner_id" required />
          </div>
          <div data-rindle-admin-preview="owner_erasure">
            <h4>Preview Report</h4>
            <p>Attachments to detach: {@action_data.report.attachments_to_detach.count}</p>
          </div>
          <div>
            <label>Type <pre>ERASE {@action_data.type}:{@action_data.id}</pre> to confirm</label>
            <input type="text" name="confirmation" data-rindle-admin-confirm-input data-rindle-admin-input="confirmation" required />
          </div>
          <%= if @action_error do %>
            <p class="rindle-admin-toast rindle-admin-toast--danger" data-rindle-admin-action-error>{@action_error}</p>
          <% end %>
          <button type="submit" data-rindle-admin-submit="execute_owner_erasure">Erase owner</button>
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
        <form phx-submit="preview_batch_erasure" phx-change="change_batch_erasure" data-rindle-admin-form="batch_erasure_preview">
          <div>
            <label>Owners (one per line as Module:id)</label>
            <textarea name="owners" rows="5" data-rindle-admin-input="batch_owners" required></textarea>
          </div>
          <%= if @action_error do %>
            <p class="rindle-admin-toast rindle-admin-toast--danger" data-rindle-admin-action-error>{@action_error}</p>
          <% end %>
          <button type="submit" data-rindle-admin-submit="preview_batch_erasure">Preview batch erasure</button>
        </form>
      </div>
      """
    end

    defp render_batch_erasure_state(%{action_state: :preview} = assigns) do
      ~H"""
      <div data-rindle-admin-state="preview">
        <form phx-change="change_batch_erasure" phx-submit="execute_batch_erasure" data-rindle-admin-form="batch_erasure_execute">
          <div>
            <label>Owners</label>
            <textarea name="owners" rows="5" data-rindle-admin-input="batch_owners" required>{@action_data.owners_text}</textarea>
          </div>
          <div data-rindle-admin-preview="batch_erasure">
            <h4>Preview Report</h4>
            <p>Owners to process: {@action_data.count}</p>
            <p>Attachments to detach: {@action_data.report.attachments_to_detach.count}</p>
          </div>
          <div>
            <label>Type <pre>ERASE {@action_data.count} OWNERS</pre> to confirm</label>
            <input type="text" name="confirmation" data-rindle-admin-confirm-input data-rindle-admin-input="confirmation" required />
          </div>
          <%= if @action_error do %>
            <p class="rindle-admin-toast rindle-admin-toast--danger" data-rindle-admin-action-error>{@action_error}</p>
          <% end %>
          <button type="submit" data-rindle-admin-submit="execute_batch_erasure">Erase owners</button>
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

    defp render_lifecycle_repair_state(%{action_state: :input} = assigns) do
      ~H"""
      <div data-rindle-admin-state="input">
        <form phx-submit="execute_lifecycle_repair" phx-change="change_lifecycle_repair" data-rindle-admin-form="lifecycle_repair">
          <div>
            <label>Asset ID</label>
            <input type="text" name="asset_id" data-rindle-admin-input="asset_id" required />
          </div>
          <div>
            <label>Action</label>
            <select name="repair_action" data-rindle-admin-input="repair_action" required>
              <option value="reprobe">Reprobe</option>
              <option value="requeue">Requeue Variants</option>
            </select>
          </div>
          <%= if @action_error do %>
            <p class="rindle-admin-toast rindle-admin-toast--danger" data-rindle-admin-action-error>{@action_error}</p>
          <% end %>
          <button type="submit" data-rindle-admin-submit="execute_lifecycle_repair">Execute Repair</button>
        </form>
      </div>
      """
    end

    defp render_lifecycle_repair_state(%{action_state: :receipt} = assigns) do
      ~H"""
      <div data-rindle-admin-state="receipt" data-rindle-admin-receipt="lifecycle_repair">
        <h4>Lifecycle Repair Complete</h4>
        <p>Action taken: {@action_data.action}</p>
        <p>Success: {if @action_data.success, do: "Yes", else: "No"}</p>
      </div>
      """
    end

    defp render_variant_regeneration_state(%{action_state: :input} = assigns) do
      ~H"""
      <div data-rindle-admin-state="input">
        <form phx-submit="execute_variant_regeneration" data-rindle-admin-form="variant_regeneration">
          <div>
            <label>Profile (optional)</label>
            <input type="text" name="profile" data-rindle-admin-input="profile" />
          </div>
          <div>
            <label>Variant Name (optional)</label>
            <input type="text" name="variant_name" data-rindle-admin-input="variant_name" />
          </div>
          <div>
            <label>
              <input type="checkbox" name="confirm" value="true" data-rindle-admin-input="confirm" />
              Confirm broad regeneration
            </label>
          </div>
          <%= if @action_error do %>
            <p class="rindle-admin-toast rindle-admin-toast--danger" data-rindle-admin-action-error>{@action_error}</p>
          <% end %>
          <button type="submit" data-rindle-admin-submit="execute_variant_regeneration">Regenerate Variants</button>
        </form>
      </div>
      """
    end

    defp render_variant_regeneration_state(%{action_state: :receipt} = assigns) do
      ~H"""
      <div data-rindle-admin-state="receipt" data-rindle-admin-receipt="variant_regeneration">
        <h4>Variant Regeneration Enqueued</h4>
        <p>Work continues asynchronously via Oban.</p>
        <p>Enqueued: {@action_data.report.enqueued}</p>
        <p>Skipped: {@action_data.report.skipped}</p>
        <p>Errors: {@action_data.report.errors}</p>
      </div>
      """
    end

    defp load(socket) do
      {:ok, model} = Queries.actions_directory()
      assign(socket, model: model, error?: false)
    end
  end
end
