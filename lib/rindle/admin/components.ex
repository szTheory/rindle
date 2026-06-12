if Code.ensure_loaded?(Phoenix.Component) do
  defmodule Rindle.Admin.Components do
    @moduledoc false

    use Phoenix.Component

    @surfaces [
      %{name: "Home/Status", slug: "home-status", path: "/admin/rindle"},
      %{name: "Assets", slug: "assets", path: "/admin/rindle/assets"},
      %{name: "Upload Sessions", slug: "upload-sessions", path: "/admin/rindle/upload-sessions"},
      %{name: "Variants/Jobs", slug: "variants-jobs", path: "/admin/rindle/variants-jobs"},
      %{name: "Runtime/Doctor", slug: "runtime-doctor", path: "/admin/rindle/runtime-doctor"},
      %{name: "Actions", slug: "actions", path: "/admin/rindle/actions"}
    ]

    attr(:active, :string, required: true)
    attr(:title, :string, required: true)
    attr(:live_status, :string, default: "Waiting for lifecycle events")
    slot(:inner_block, required: true)

    def shell(assigns) do
      assigns = assign(assigns, :surfaces, @surfaces)

      ~H"""
      <div class="rindle-admin-shell" data-rindle-admin-root data-rindle-admin-surface={@active} data-theme="auto">
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
      </div>
      """
    end

    def theme_picker(assigns) do
      ~H"""
      <div class="rindle-admin-theme-picker" data-rindle-admin-component="theme-picker" role="group" aria-label="Theme">
        <button class="rindle-admin-theme-picker__option rindle-admin-target-min" type="button" data-rindle-admin-theme="light" aria-pressed="false">Light</button>
        <button class="rindle-admin-theme-picker__option rindle-admin-target-min" type="button" data-rindle-admin-theme="dark" aria-pressed="false">Dark</button>
        <button class="rindle-admin-theme-picker__option rindle-admin-target-min" type="button" data-rindle-admin-theme="auto" aria-pressed="true">Auto</button>
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

    def format_value(nil), do: "not set"
    def format_value(%DateTime{} = value), do: DateTime.to_iso8601(value)
    def format_value(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
    def format_value(value) when is_binary(value), do: value
    def format_value(value), do: to_string(value)

    defp labelize(value) do
      value
      |> to_string()
      |> String.replace("_", " ")
      |> String.capitalize()
    end

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
