if Code.ensure_loaded?(Phoenix.Component) do
  defmodule Rindle.Admin.Components do
    @moduledoc false

    use Phoenix.Component
    alias Phoenix.LiveView.JS

    @surfaces [
      %{name: "Home/Status", slug: "home-status", suffix: ""},
      %{name: "Assets", slug: "assets", suffix: "assets"},
      %{name: "Upload Sessions", slug: "upload-sessions", suffix: "upload-sessions"},
      %{name: "Variants/Jobs", slug: "variants-jobs", suffix: "variants-jobs"},
      %{name: "Runtime/Doctor", slug: "runtime-doctor", suffix: "runtime-doctor"},
      %{name: "Actions", slug: "actions", suffix: "actions"}
    ]

    attr(:active, :string, required: true)
    attr(:base_path, :string, default: "/admin/rindle")
    attr(:title, :string, required: true)
    attr(:live_status, :string, default: "Waiting for lifecycle events")
    slot(:inner_block, required: true)

    def shell(assigns) do
      assigns = assign(assigns, :surfaces, surface_links(assigns.base_path))

      ~H"""
      <div class="rindle-admin-shell" data-rindle-admin-root data-rindle-admin-surface={@active} data-theme="auto">
        <link rel="stylesheet" href={admin_path(@base_path, "assets/rindle-admin.css")} />
        <nav class="rindle-admin-nav" aria-label="Rindle Admin surfaces" data-rindle-admin-component="nav">
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
          <.theme_picker />
        </nav>
        <main class="rindle-admin-shell__main" data-rindle-admin-surface={@active}>
          <header data-rindle-admin-page-header>
            <p>Rindle Admin</p>
            <h1>{@title}</h1>
            <.live_indicator copy={@live_status} />
          </header>
          {render_slot(@inner_block)}
        </main>
        <script defer type="text/javascript" src={admin_path(@base_path, "assets/rindle-admin.js")}>
        </script>
      </div>
      """
    end

    def theme_picker(assigns) do
      ~H"""
      <div class="rindle-admin-theme-picker" data-rindle-admin-component="theme-picker" role="group" aria-label="Theme">
        <button class="rindle-admin-theme-picker__option rindle-admin-target-min" type="button" data-rindle-admin-theme="light" aria-pressed="false" phx-click={select_theme("light")}>Light</button>
        <button class="rindle-admin-theme-picker__option rindle-admin-target-min" type="button" data-rindle-admin-theme="dark" aria-pressed="false" phx-click={select_theme("dark")}>Dark</button>
        <button class="rindle-admin-theme-picker__option rindle-admin-target-min" type="button" data-rindle-admin-theme="auto" aria-pressed="true" phx-click={select_theme("auto")}>Auto</button>
      </div>
      """
    end

    attr(:copy, :string, default: "Waiting for lifecycle events")

    def live_indicator(assigns) do
      ~H"""
      <p class="rindle-admin-toast rindle-admin-toast--info" data-rindle-admin-live-indicator tabindex="0">
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
      <section class="rindle-admin-empty-state" data-rindle-admin-error-state data-rindle-admin-state="error">
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
