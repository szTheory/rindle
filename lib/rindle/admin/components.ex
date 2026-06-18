if Code.ensure_loaded?(Phoenix.Component) do
  defmodule Rindle.Admin.Components do
    @moduledoc false

    use Phoenix.Component
    alias Phoenix.LiveView.JS

    # Task-first nav labels/order (UI-SPEC §E, D-98-03): relabel for task-scent,
    # drop slashes, problems-first ordering. Slugs/suffixes are FROZEN behavior
    # contracts (route suffixes + aria-current keys the surfaces pass via
    # `active=`); only the human `name` changes. The relabel drops every legacy
    # slashed/verb-bucket name in favor of the six task-first labels below.
    @surfaces [
      %{name: "Overview", slug: "home-status", suffix: ""},
      %{name: "Assets", slug: "assets", suffix: "assets"},
      %{name: "Upload sessions", slug: "upload-sessions", suffix: "upload-sessions"},
      %{name: "Processing", slug: "variants-jobs", suffix: "variants-jobs"},
      %{name: "Doctor", slug: "runtime-doctor", suffix: "runtime-doctor"},
      %{name: "Maintenance", slug: "actions", suffix: "actions"}
    ]

    attr(:active, :string, required: true)
    attr(:base_path, :string, default: "/admin/rindle")
    attr(:title, :string, required: true)
    attr(:live_status, :string, default: "Waiting for lifecycle events")
    # Server-owned theme (D-98-07): shell learns the current theme at mount
    # (session value / LiveView connect param) and threads it down so
    # `theme_picker` renders `aria-pressed` server-side and the root carries the
    # correct `data-theme` even on a dead-render/reconnect. `JS.set_attribute`
    # (select_theme/1) remains progressive enhancement ONLY.
    attr(:theme, :string, default: "auto", values: ["light", "dark", "auto"])
    # Server-assign-driven dialog state (D-98-11 critical landmine): when a modal
    # is open, `main`+`nav` get `inert` AND `aria-hidden`. Rendering this off an
    # assign (not solely client JS) means a LiveView reconnect/dead-render
    # re-renders the correct state — `main` is NEVER left inert.
    attr(:dialog_open, :boolean, default: false)
    slot(:inner_block, required: true)

    def shell(assigns) do
      assigns = assign(assigns, :surfaces, surface_links(assigns.base_path))

      ~H"""
      <div class="rindle-admin-shell" data-rindle-admin-root data-rindle-admin-surface={@active} data-theme={@theme}>
        <link rel="stylesheet" href={admin_path(@base_path, "assets/rindle-admin.css")} />
        <a class="rindle-admin-skip-link rindle-admin-target-min" href="#rindle-admin-main" data-rindle-admin-skip-link>
          Skip to main content
        </a>
        <nav
          class="rindle-admin-nav"
          aria-label="Rindle Admin surfaces"
          data-rindle-admin-component="nav"
          inert={@dialog_open}
          aria-hidden={if @dialog_open, do: "true", else: nil}
        >
          <p class="rindle-admin-nav__brand">Rindle Admin</p>
          <ul class="rindle-admin-nav__list">
            <li :for={surface <- @surfaces}>
              <a
                class="rindle-admin-nav__item"
                href={surface.path}
                aria-current={if surface.slug == @active, do: "page", else: nil}
                data-rindle-admin-nav-item={surface.slug}
              >
                {surface.name}
              </a>
            </li>
          </ul>
          <.theme_picker theme={@theme} />
        </nav>
        <main
          id="rindle-admin-main"
          class="rindle-admin-shell__main"
          data-rindle-admin-surface={@active}
          tabindex="-1"
          inert={@dialog_open}
          aria-hidden={if @dialog_open, do: "true", else: nil}
        >
          <header data-rindle-admin-page-header>
            <p>Rindle Admin</p>
            <h1>{@title}</h1>
            <.live_indicator copy={@live_status} />
          </header>
          {render_slot(@inner_block)}
        </main>
        <%!-- Persistent ASSERTIVE live region (D-98-07): present at mount, empty
              until an async run-failure / action-error banner is announced into
              it. The POLITE region is `live_indicator`. --%>
        <div
          class="rindle-admin-alert-region"
          role="alert"
          aria-live="assertive"
          aria-atomic="true"
          data-rindle-admin-alert-region
        >
        </div>
        <script defer type="text/javascript" src={admin_path(@base_path, "assets/rindle-admin.js")}>
        </script>
      </div>
      """
    end

    # Server-owned `aria-pressed` (D-98-07): the attribute is rendered from the
    # `@theme` assign threaded from `shell/1` mount, so it is correct in
    # server-rendered (dead) markup and survives reconnect. `select_theme/1`
    # (`JS.set_attribute`) is progressive enhancement only — no longer the source
    # of truth.
    attr(:theme, :string, default: "auto", values: ["light", "dark", "auto"])

    def theme_picker(assigns) do
      ~H"""
      <div class="rindle-admin-theme-picker" data-rindle-admin-component="theme-picker" role="group" aria-label="Theme">
        <button class="rindle-admin-theme-picker__option rindle-admin-target-min" type="button" data-rindle-admin-theme="light" aria-pressed={@theme == "light"} phx-click={select_theme("light")}>Light</button>
        <button class="rindle-admin-theme-picker__option rindle-admin-target-min" type="button" data-rindle-admin-theme="dark" aria-pressed={@theme == "dark"} phx-click={select_theme("dark")}>Dark</button>
        <button class="rindle-admin-theme-picker__option rindle-admin-target-min" type="button" data-rindle-admin-theme="auto" aria-pressed={@theme == "auto"} phx-click={select_theme("auto")}>Auto</button>
      </div>
      """
    end

    attr(:copy, :string, default: "Waiting for lifecycle events")

    # POLITE live region (D-98-07): routine state flips ("Variant ready") are
    # announced here. Dropped the dead `tabindex="0"` (non-interactive <p>) and
    # added role=status + aria-live=polite + aria-atomic. Decorative span keeps
    # aria-hidden.
    def live_indicator(assigns) do
      ~H"""
      <p
        class="rindle-admin-toast rindle-admin-toast--info"
        data-rindle-admin-live-indicator
        role="status"
        aria-live="polite"
        aria-atomic="true"
      >
        <span aria-hidden="true">!</span>
        <span>{@copy}</span>
      </p>
      """
    end

    attr(:state, :string, default: "info")
    attr(:label, :string, default: nil)

    def status_chip(assigns) do
      assigns =
        assigns
        |> assign(:class_state, status_class(assigns.state))
        |> assign(:label, assigns.label || assigns.state || "unknown")

      ~H"""
      <span
        class={"rindle-admin-status-chip rindle-admin-status-chip--#{@class_state}"}
        data-rindle-admin-status-chip
        data-rindle-admin-state={@class_state}
      >
        {@label}
      </span>
      """
    end

    attr(:filters, :list, default: [])

    def filters(assigns) do
      ~H"""
      <form method="get" aria-label="Filter results">
        <fieldset>
          <legend>Filter results</legend>
          <label :for={{name, value} <- @filters} data-rindle-admin-filter={name}>
            {labelize(name)}
            <input class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" name={name} value={value || ""} />
          </label>
        </fieldset>
      </form>
      """
    end

    attr(:heading, :string, default: "No records match this view")

    attr(:body, :string,
      default:
        "Adjust the filters or review Runtime/Doctor to confirm Rindle is receiving lifecycle events."
    )

    def empty_state(assigns) do
      ~H"""
      <section class="rindle-admin-empty-state" data-rindle-admin-empty-state data-rindle-admin-state="empty">
        <h2 class="rindle-admin-empty-state__title">{@heading}</h2>
        <p>{@body}</p>
      </section>
      """
    end

    attr(:surface, :string, default: "surface")

    def error_state(assigns) do
      ~H"""
      <section class="rindle-admin-empty-state" data-rindle-admin-error-state data-rindle-admin-state="error" role="alert">
        <h2 class="rindle-admin-empty-state__title">Rindle Admin could not load this surface</h2>
        <p>Rindle Admin could not load this surface. Review the runtime checks, then retry after the missing source is available.</p>
        <p>Failed surface: {@surface}</p>
        <a class="rindle-admin-button rindle-admin-button--secondary rindle-admin-target-min" href=".">Retry load</a>
      </section>
      """
    end

    attr(:items, :list, default: [])

    def metadata_list(assigns) do
      ~H"""
      <dl data-rindle-admin-metadata-list>
        <div :for={{label, value} <- @items}>
          <dt>{label}</dt>
          <dd>{format_value(value)}</dd>
        </div>
      </dl>
      """
    end

    attr(:value, :any, default: nil)

    def redacted_value(assigns) do
      ~H"""
      <code data-rindle-admin-redacted-value>{format_value(@value || "Redacted by Rindle Admin")}</code>
      """
    end

    def loading_skeleton(assigns) do
      ~H"""
      <div class="rindle-admin-skeleton" data-rindle-admin-loading-state aria-hidden="true"></div>
      """
    end

    def table(assigns) do
      ~H"""
      <table class="rindle-admin-table">
        {render_slot(@inner_block)}
      </table>
      """
    end

    @doc false
    # Shared overlay primitive (D-98-11, UI-SPEC §D overlay focus contract). The
    # ONE modal/dialog grammar the six admin surfaces compose for confirm /
    # destructive flows — it REPLACES the inline confirm panels in actions_live.ex
    # (no trap, no ESC, no return-focus). P2a ships ONLY the primitive; surfaces
    # adopt it in P3.
    #
    # Focus contract:
    #   * `Phoenix.Component.focus_wrap` traps Tab/Shift-Tab (NOT a hand-rolled
    #     keydown trap).
    #   * Open command (`show_modal/2`): `JS.push_focus()` stashes the trigger,
    #     the dialog is shown via `JS.transition` held for the 300ms token
    #     duration, then `JS.focus_first` moves focus into the trap. Reduced-motion
    #     users wait the same 300ms but see no animation (CSS collapses duration —
    #     acceptable, RESEARCH A2).
    #   * Close command (`hide_modal/2`): `JS.pop_focus()` returns focus to the
    #     stashed trigger; the dialog is hidden after the transition.
    #   * ESC closes via `phx-window-keydown` + `phx-key="escape"`.
    #
    # CRITICAL inert/aria-hidden (D-98-11 landmine): `inert` AND `aria-hidden` on
    # `main`+`nav` are SERVER-ASSIGN-DRIVEN via `shell/1`'s `@dialog_open` assign —
    # NOT toggled solely by client JS — so a LiveView dead-render/reconnect
    # re-renders the correct state and `main` is NEVER left inert. The caller's
    # open/close phx events flip `dialog_open`; `show_modal/2`/`hide_modal/2`
    # chain onto that for the focus/visibility progressive enhancement.
    #
    # `modal/1` renders `role="dialog"`; `confirm_dialog/1` renders
    # `role="alertdialog"` (destructive/confirm). Both carry `aria-modal="true"`
    # and `aria-labelledby`->the title element id. The dialog container keeps a
    # permanent visible border (.rindle-admin-confirm-dialog, CSS authored in P1)
    # because a programmatically-focused container may not trigger :focus-visible.
    attr(:id, :string, required: true)
    attr(:show, :boolean, default: false)

    attr(:on_cancel, JS,
      default: %JS{},
      doc: "extra JS chained on close — typically the phx event that flips dialog_open=false"
    )

    slot(:title, required: true)
    slot(:inner_block, required: true)
    slot(:actions)

    def modal(assigns) do
      ~H"""
      <div
        id={@id}
        class="rindle-admin-overlay"
        data-rindle-admin-overlay
        style={unless @show, do: "display: none;"}
        phx-window-keydown={hide_modal(@on_cancel, @id)}
        phx-key="escape"
      >
        <div
          class="rindle-admin-overlay__backdrop"
          data-rindle-admin-overlay-backdrop
          aria-hidden="true"
          phx-click={hide_modal(@on_cancel, @id)}
        >
        </div>
        <.focus_wrap
          id={"#{@id}-content"}
          class="rindle-admin-confirm-dialog"
          data-rindle-admin-dialog
          role="dialog"
          aria-modal="true"
          aria-labelledby={"#{@id}-title"}
          tabindex="-1"
        >
          <h2 id={"#{@id}-title"} class="rindle-admin-confirm-dialog__title" data-rindle-admin-dialog-title>
            {render_slot(@title)}
          </h2>
          <div class="rindle-admin-confirm-dialog__body" data-rindle-admin-dialog-body>
            {render_slot(@inner_block)}
          </div>
          <div :if={@actions != []} class="rindle-admin-confirm-dialog__actions" data-rindle-admin-dialog-actions>
            {render_slot(@actions)}
          </div>
        </.focus_wrap>
      </div>
      """
    end

    @doc false
    # Destructive/confirming overlay (role="alertdialog"). Same focus contract as
    # modal/1. Body/heading copy follows UI-SPEC §F ("{Verb} this {noun}?", plain
    # consequence sentence, no "!") — but per-surface confirm strings are wired in
    # P3 via the slots; the primitive ships slots, not hard-coded surface copy.
    attr(:id, :string, required: true)
    attr(:show, :boolean, default: false)
    attr(:on_cancel, JS, default: %JS{})
    slot(:title, required: true)
    slot(:inner_block, required: true)
    slot(:actions)

    def confirm_dialog(assigns) do
      ~H"""
      <div
        id={@id}
        class="rindle-admin-overlay"
        data-rindle-admin-overlay
        style={unless @show, do: "display: none;"}
        phx-window-keydown={hide_modal(@on_cancel, @id)}
        phx-key="escape"
      >
        <div
          class="rindle-admin-overlay__backdrop"
          data-rindle-admin-overlay-backdrop
          aria-hidden="true"
          phx-click={hide_modal(@on_cancel, @id)}
        >
        </div>
        <.focus_wrap
          id={"#{@id}-content"}
          class="rindle-admin-confirm-dialog"
          data-rindle-admin-dialog
          role="alertdialog"
          aria-modal="true"
          aria-labelledby={"#{@id}-title"}
          tabindex="-1"
        >
          <h2 id={"#{@id}-title"} class="rindle-admin-confirm-dialog__title" data-rindle-admin-dialog-title>
            {render_slot(@title)}
          </h2>
          <div class="rindle-admin-confirm-dialog__body" data-rindle-admin-dialog-body>
            {render_slot(@inner_block)}
          </div>
          <div :if={@actions != []} class="rindle-admin-confirm-dialog__actions" data-rindle-admin-dialog-actions>
            {render_slot(@actions)}
          </div>
        </.focus_wrap>
      </div>
      """
    end

    @doc false
    # Open command (D-98-11). Caller chains the server phx event that flips
    # `dialog_open=true` (assign-driven inert is the source of truth); this helper
    # adds the focus/visibility progressive enhancement: stash the trigger via the
    # framework focus stack, show the overlay over the 300ms token duration, then
    # move focus into the trap with `JS.focus_first`.
    def show_modal(js \\ %JS{}, id) when is_binary(id) do
      js
      |> JS.push_focus()
      |> JS.show(
        to: "##{id}",
        time: 300,
        transition:
          {"transition-all transform ease-out duration-300", "opacity-0", "opacity-100"}
      )
      |> JS.focus_first(to: "##{id}-content")
    end

    @doc false
    # Close command (D-98-11): hide the overlay, return focus to the stashed
    # trigger via the framework focus stack, and chain the caller's `on_cancel`
    # (the server event that flips `dialog_open=false`, restoring main+nav).
    def hide_modal(js \\ %JS{}, id) when is_binary(id) do
      js
      |> JS.hide(
        to: "##{id}",
        time: 300,
        transition:
          {"transition-all transform ease-in duration-300", "opacity-100", "opacity-0"}
      )
      |> JS.pop_focus()
    end

    @doc false
    # Level-3 page composition scaffold (D-98-01, UI-SPEC §A). The single page
    # grammar that makes all six admin surfaces one system and structurally
    # forbids page-local styling: NO grid/measure is declared here — every layout
    # rule lives in the generated CSS (`.rindle-admin-page*` selectors authored in
    # brandbook/src/admin-css-build.mjs, D-98-12). Slots render in canonical DOM
    # order; `:work` is required (compile-time error if omitted). `:state` drives
    # the existing empty/error/loading primitives so surfaces never re-implement
    # them. The scaffold root carries a `data-rindle-admin-*` seam so both the
    # gallery-check and Playwright homes can target it. Ends this plan
    # existing-but-UNUSED (no surface is migrated onto it yet).
    attr(:state, :atom, default: :ok)
    attr(:error_surface, :string, default: "surface")
    slot(:summary)
    slot(:filters)
    slot(:work, required: true)
    slot(:aside)
    slot(:actions)

    def page(assigns) do
      ~H"""
      <div
        class={"rindle-admin-page" <> if(@aside != [], do: " rindle-admin-page--two-pane", else: "")}
        data-rindle-admin-root
        data-rindle-admin-page
        data-rindle-admin-state={@state}
      >
        <div :if={@summary != []} class="rindle-admin-page__summary" data-rindle-admin-page-summary>
          {render_slot(@summary)}
        </div>

        <div :if={@filters != []} class="rindle-admin-page__filters" data-rindle-admin-page-filters>
          {render_slot(@filters)}
        </div>

        <div class="rindle-admin-page__panes" data-rindle-admin-page-panes>
          <div class="rindle-admin-page__work" data-rindle-admin-page-work>
            <%= case @state do %>
              <% :empty -> %>
                <.empty_state />
              <% :error -> %>
                <.error_state surface={@error_surface} />
              <% :loading -> %>
                <.loading_skeleton />
              <% _ -> %>
                {render_slot(@work)}
            <% end %>
          </div>

          <aside :if={@aside != []} class="rindle-admin-page__aside" data-rindle-admin-page-aside>
            {render_slot(@aside)}
          </aside>
        </div>

        <footer :if={@actions != []} class="rindle-admin-page__actions" data-rindle-admin-page-actions>
          {render_slot(@actions)}
        </footer>
      </div>
      """
    end

    def format_value(nil), do: "not set"
    def format_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
    def format_value(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
    def format_value(value) when is_binary(value), do: value
    def format_value(value), do: to_string(value)

    def admin_path(base_path, suffix \\ "")

    def admin_path(base_path, suffix) when suffix in [nil, ""] do
      normalize_base_path(base_path)
    end

    def admin_path(base_path, suffix) when is_binary(suffix) do
      Path.join(normalize_base_path(base_path), suffix)
    end

    defp labelize(value) do
      value
      |> to_string()
      |> String.replace("_", " ")
      |> String.capitalize()
    end

    defp surface_links(base_path) do
      Enum.map(@surfaces, fn surface ->
        Map.put(surface, :path, admin_path(base_path, surface.suffix))
      end)
    end

    defp select_theme(theme) when theme in ["light", "dark", "auto"] do
      JS.set_attribute({"data-theme", theme}, to: "[data-rindle-admin-root]")
      |> JS.set_attribute({"aria-pressed", "false"}, to: "[data-rindle-admin-theme]")
      |> JS.set_attribute({"aria-pressed", "true"}, to: ~s([data-rindle-admin-theme="#{theme}"]))
    end

    defp normalize_base_path(path) when is_binary(path) and path != "" do
      if String.starts_with?(path, "/"), do: path, else: "/" <> path
    end

    defp normalize_base_path(_path), do: "/admin/rindle"

    defp status_class(state) when state in ["ready", "available", "completed", "succeeded"],
      do: "ready"

    defp status_class(state) when state in ["processing", "queued", "signed", "initialized"],
      do: "processing"

    defp status_class(state) when state in ["failed", "errored", "error"], do: "danger"
    defp status_class("quarantined"), do: "quarantine"
    defp status_class("expired"), do: "warning"
    defp status_class(_state), do: "info"
  end
end
