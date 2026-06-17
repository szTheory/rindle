defmodule AdoptionDemoWeb.CohortComponents do
  @moduledoc """
  Cohort's small in-demo design system — the function components behind the
  launchpad and shared chrome. Pairs with `priv/static/assets/cohort.css`
  (everything is scoped under `.ck-*`). Deliberately separate from the stock
  `core_components.ex`/daisyUI used by the inner app pages.
  """
  use AdoptionDemoWeb, :html

  @doc "Shared sticky header. `active` highlights the current section."
  attr :active, :atom, default: nil

  def cohort_nav(assigns) do
    ~H"""
    <nav class="ck-nav" aria-label="Primary">
      <a href="/" class="ck-nav__brand">
        <img src={~p"/images/logo.svg"} alt="" /> Cohort
        <span class="ck-nav__demo">· Rindle demo</span>
      </a>
      <span class="ck-nav__spacer"></span>
      <div class="ck-nav__links">
        <.link navigate={~p"/"} aria-current={@active == :home && "page"}>Home</.link>
        <.link navigate={~p"/dashboard"} aria-current={@active == :app && "page"}>App</.link>
        <.link navigate={~p"/upload"} aria-current={@active == :upload && "page"}>Upload</.link>
        <.link navigate={~p"/ops"} aria-current={@active == :ops && "page"}>Ops</.link>
        <a href="/admin/rindle">Admin</a>
      </div>
    </nav>
    """
  end

  @doc "Shared footer."
  def cohort_footer(assigns) do
    ~H"""
    <footer class="ck-footer">
      <span>Cohort — a Rindle adoption demo · local preview only</span>
      <span>
        <.link navigate={~p"/dashboard"}>App</.link> · <a href="/admin/rindle">Admin console</a>
      </span>
    </footer>
    """
  end

  @doc "Hero block: eyebrow, headline, lede, and an actions slot."
  attr :eyebrow, :string, required: true
  attr :title, :string, required: true
  attr :lede, :string, required: true
  slot :actions

  def hero(assigns) do
    ~H"""
    <header class="ck-hero ck-reveal">
      <span class="ck-eyebrow">{@eyebrow}</span>
      <h1 class="ck-hero__title">{@title}</h1>
      <p class="ck-hero__lede">{@lede}</p>
      <div :if={@actions != []} class="ck-hero__actions">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc "A primary or quiet pill button. Renders an `<a>` when `:href` is given."
  attr :href, :string, default: nil
  attr :variant, :string, default: "quiet", values: ~w(primary quiet)
  attr :arrow, :boolean, default: false
  attr :rest, :global, include: ~w(target rel)
  slot :inner_block, required: true

  def ck_button(assigns) do
    ~H"""
    <.link
      :if={@href}
      href={@href}
      class={["ck-btn", @variant == "primary" && "ck-btn--primary"]}
      {@rest}
    >
      {render_slot(@inner_block)}
      <span :if={@arrow} class="ck-btn__arrow" aria-hidden="true">→</span>
    </.link>
    """
  end

  @doc "The 'Before you start' access panel. Expects `cred/1` rows in its block."
  slot :inner_block, required: true

  def access_panel(assigns) do
    ~H"""
    <section class="ck-panel ck-reveal" style="--d:.08s" aria-label="Access and credentials">
      <h2 class="ck-panel__title">
        <svg
          viewBox="0 0 24 24"
          width="18"
          height="18"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <path d="M12 2 4 5v6c0 5 3.4 8.6 8 11 4.6-2.4 8-6 8-11V5l-8-3Z" />
        </svg>
        Before you start
      </h2>
      <div class="ck-cred-grid">{render_slot(@inner_block)}</div>
    </section>
    """
  end

  @doc """
  One credential / access row: a label, a mono value (link when `:href` is set),
  and a copy-to-clipboard button (the value copied defaults to `:value`).
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :href, :string, default: nil
  attr :copy, :string, default: nil, doc: "text to copy; defaults to value"

  def cred(assigns) do
    assigns = assign_new(assigns, :copy_text, fn -> assigns.copy || assigns.value end)

    ~H"""
    <div class="ck-cred">
      <span class="ck-cred__label">{@label}</span>
      <div class="ck-cred__row">
        <a :if={@href} href={@href} class="ck-cred__value ck-cred__value--link" title={@value}>
          {@value}
        </a>
        <span :if={!@href} class="ck-cred__value" title={@value}>{@value}</span>
        <button
          type="button"
          class="ck-copy"
          phx-hook="Copy"
          id={"copy-#{:erlang.phash2({@label, @value})}"}
          data-copy={@copy_text}
          aria-label={"Copy #{@label}"}
          title="Copy"
        >
          <svg
            class="ck-copy__icon"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <rect x="9" y="9" width="11" height="11" rx="2" />
            <path d="M5 15V5a2 2 0 0 1 2-2h10" />
          </svg>
          <svg
            class="ck-copy__check"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2.5"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="m20 6-11 11-5-5" />
          </svg>
        </button>
      </div>
    </div>
    """
  end

  @doc "Grid wrapper for task cards."
  slot :inner_block, required: true

  def task_grid(assigns) do
    ~H"""
    <div class="ck-grid">{render_slot(@inner_block)}</div>
    """
  end

  @doc "A single 'what do you want to do?' task card linking to a live flow."
  attr :title, :string, required: true
  attr :desc, :string, required: true
  attr :href, :string, required: true
  attr :path, :string, default: nil, doc: "the route shown in mono under the title"
  attr :icon, :atom, default: :upload
  attr :delay, :string, default: nil
  attr :external, :boolean, default: false, doc: "full page nav (e.g. across a live_session)"

  def task_card(assigns) do
    ~H"""
    <.link
      navigate={!@external && @href}
      href={@external && @href}
      class="ck-card ck-reveal"
      style={@delay && "--d:#{@delay}"}
    >
      <span class="ck-card__icon">{task_icon(%{name: @icon})}</span>
      <h3 class="ck-card__title">{@title}</h3>
      <p class="ck-card__desc">{@desc}</p>
      <div class="ck-card__foot">
        <span :if={@path} class="ck-card__path">{@path}</span>
        <span class="ck-card__arrow" aria-hidden="true">→</span>
      </div>
    </.link>
    """
  end

  @doc "Lifecycle-state badge."
  attr :variant, :string, default: "info", values: ~w(ready processing quarantine info)
  attr :label, :string, required: true

  def badge(assigns) do
    ~H"""
    <span class={["ck-badge", "ck-badge--#{@variant}"]}>{@label}</span>
    """
  end

  @doc """
  Level-1 data table (D-96-15). Uses the `core_components` `:col`/`:rows` model
  extended with per-column `sort_key`/`num`. Sort state is SERVER-owned: pass
  `sort_by`/`sort_dir` (the current LiveView assigns) and a `sort_event`; the
  sortable header is a real `<button>` carrying `aria-sort`. Numeric columns get
  `tabular-nums` for alignment. Renders an empty state and a loading skeleton.
  """
  attr :rows, :list, default: [], doc: "the row data (a list of maps/structs)"
  attr :row_id, :any, default: nil, doc: "optional fn(row) -> dom id"
  attr :sort_by, :string, default: nil, doc: "server-owned: the active sort_key"
  attr :sort_dir, :string, default: "asc", values: ~w(asc desc)
  attr :sort_event, :string, default: nil, doc: "phx-click event emitted by sort headers"
  attr :loading, :boolean, default: false
  attr :skeleton_rows, :integer, default: 3
  attr :empty_title, :string, default: "Nothing here yet"
  attr :empty_body, :string, default: "No records match this view. Adjust filters or seed demo data."
  attr :rest, :global

  slot :col, required: true do
    attr :label, :string, required: true
    attr :sort_key, :string
    attr :num, :boolean
  end

  slot :empty, doc: "optional custom empty-state content"

  def ck_table(assigns) do
    ~H"""
    <div class="ck-table-wrap" {@rest}>
      <table class="ck-table">
        <thead class="ck-table__head">
          <tr>
            <th
              :for={col <- @col}
              scope="col"
              class={["ck-table__cell", "ck-table__cell--head", col[:num] && "ck-table__num"]}
              aria-sort={ck_aria_sort(col[:sort_key], @sort_by, @sort_dir)}
            >
              <button
                :if={col[:sort_key] && @sort_event}
                type="button"
                class="ck-table__sort"
                phx-click={@sort_event}
                phx-value-key={col[:sort_key]}
              >
                {col[:label]}
                <span class="ck-table__sort-mark" aria-hidden="true">
                  {ck_table_sort_glyph(col[:sort_key], @sort_by, @sort_dir)}
                </span>
              </button>
              <span :if={!(col[:sort_key] && @sort_event)}>{col[:label]}</span>
            </th>
          </tr>
        </thead>
        <tbody :if={!@loading && @rows != []} class="ck-table__body">
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class="ck-table__row"
          >
            <td
              :for={col <- @col}
              class={["ck-table__cell", col[:num] && "ck-table__num"]}
            >
              {render_slot(col, row)}
            </td>
          </tr>
        </tbody>
        <tbody :if={@loading} class="ck-table__body" aria-hidden="true">
          <tr :for={_n <- 1..@skeleton_rows} class="ck-table__row ck-table__row--skeleton">
            <td :for={_col <- @col} class="ck-table__cell">
              <span class="ck-skeleton ck-skeleton--line"></span>
            </td>
          </tr>
        </tbody>
      </table>
      <div :if={!@loading && @rows == []} class="ck-table__empty">
        {render_slot(@empty)}
        <div :if={@empty == []} class="ck-empty">
          <p class="ck-empty__title">{@empty_title}</p>
          <p class="ck-empty__body">{@empty_body}</p>
        </div>
      </div>
    </div>
    """
  end

  defp ck_aria_sort(nil, _sort_by, _dir), do: nil
  defp ck_aria_sort(key, key, "asc"), do: "ascending"
  defp ck_aria_sort(key, key, "desc"), do: "descending"
  defp ck_aria_sort(_key, _sort_by, _dir), do: "none"

  defp ck_table_sort_glyph(key, key, "asc"), do: "↑"
  defp ck_table_sort_glyph(key, key, "desc"), do: "↓"
  defp ck_table_sort_glyph(_key, _sort_by, _dir), do: "↕"

  @doc """
  Stat tile (D-96-22). `value` renders with `tabular-nums`; an empty/nil value
  renders an em dash. Optional `delta` and a `status` accent. A loading skeleton
  replaces the value while `loading`.
  """
  attr :label, :string, required: true
  attr :value, :string, default: nil
  attr :delta, :string, default: nil
  attr :delta_dir, :string, default: "neutral", values: ~w(up down neutral)
  attr :status, :string, default: nil, values: [nil | ~w(ready processing quarantine info)]
  attr :loading, :boolean, default: false
  attr :rest, :global

  def ck_stat(assigns) do
    ~H"""
    <div class={["ck-stat", @status && "ck-stat--#{@status}"]} {@rest}>
      <span class="ck-stat__label">{@label}</span>
      <span :if={@loading} class="ck-skeleton ck-skeleton--value" aria-hidden="true"></span>
      <span :if={!@loading} class="ck-stat__value">{@value || "—"}</span>
      <span :if={@delta && !@loading} class={["ck-stat__delta", "ck-stat__delta--#{@delta_dir}"]}>
        <span aria-hidden="true">{ck_delta_glyph(@delta_dir)}</span>
        {@delta}
      </span>
    </div>
    """
  end

  defp ck_delta_glyph("up"), do: "▲"
  defp ck_delta_glyph("down"), do: "▼"
  defp ck_delta_glyph(_), do: "•"

  @doc """
  Detail block (D-96-22): a real `<dl>` of term/description rows. Each `:item`
  slot carries a `term`. Supports an empty state.
  """
  attr :empty_title, :string, default: "Nothing here yet"
  attr :rest, :global

  slot :item, doc: "one term/description row" do
    attr :term, :string, required: true
  end

  def ck_detail(assigns) do
    ~H"""
    <dl class="ck-detail" {@rest}>
      <div :for={item <- @item} class="ck-detail__row">
        <dt class="ck-detail__term">{item.term}</dt>
        <dd class="ck-detail__desc">{render_slot(item)}</dd>
      </div>
      <div :if={@item == []} class="ck-detail__empty ck-empty">
        <p class="ck-empty__title">{@empty_title}</p>
      </div>
    </dl>
    """
  end

  @doc """
  Toolbar (D-96-22): a `role="group"` row of controls. Default content goes in
  the inner block (filters, title); an `:actions` slot is pinned to the trailing
  edge for buttons. Wraps on narrow viewports.
  """
  attr :label, :string, default: "Toolbar", doc: "accessible group label"
  attr :rest, :global

  slot :inner_block
  slot :actions

  def ck_toolbar(assigns) do
    ~H"""
    <div class="ck-toolbar" role="group" aria-label={@label} {@rest}>
      <div :if={@inner_block != []} class="ck-toolbar__group">{render_slot(@inner_block)}</div>
      <div :if={@actions != []} class="ck-toolbar__group ck-toolbar__group--actions">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  # --- inline icon set (no external sprite dependency) ----------------------
  attr :name, :atom, required: true

  defp task_icon(%{name: :upload} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M12 16V4m0 0 4 4m-4-4-4 4" /><path d="M5 20h14" />
    </svg>
    """
  end

  defp task_icon(%{name: :video} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <rect x="3" y="5" width="13" height="14" rx="2" /><path d="m16 10 5-3v10l-5-3z" />
    </svg>
    """
  end

  defp task_icon(%{name: :resume} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M3 12a9 9 0 1 0 3-6.7L3 8" /><path d="M3 3v5h5" />
    </svg>
    """
  end

  defp task_icon(%{name: :liveview} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M13 2 4 14h7l-1 8 9-12h-7l1-8Z" />
    </svg>
    """
  end

  defp task_icon(%{name: :erase} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2m2 0-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" />
    </svg>
    """
  end

  defp task_icon(%{name: :ops} = assigns) do
    ~H"""
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M22 12h-4l-3 9L9 3l-3 9H2" />
    </svg>
    """
  end

  defp task_icon(assigns), do: task_icon(%{assigns | name: :upload})
end
