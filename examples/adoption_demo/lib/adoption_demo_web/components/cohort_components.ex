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

  @doc """
  Page scaffold — the Cohort analog of Phase 98's `page/1` (D-98-01). Renders the
  per-page `.ck` shell that all migrated inner pages share: the `.ck` div carrying
  `data-ck-root` (the polish-gate / theme root — on this div, NEVER on `<body>`,
  D-96-05) and a SERVER-owned `data-theme`. The theme is tri-state: `"light"`/`"dark"`
  render an explicit `data-theme` (deterministic for e2e), while `"auto"` (the default)
  OMITS the attribute so the page follows `prefers-color-scheme` like the home page —
  keeping every Cohort surface consistent with the OS by default while still allowing a
  pinned theme via `?theme=` or a toggle. `data-ck-root` is always present (gate root).
  `.ck__wrap` content column, and a canonical `.ck-hero` header (required `:title`,
  optional `:eyebrow`/`:lede`). The page body goes in `:inner_block`. Page chrome
  (`cohort_nav`/`cohort_footer`) stays in `Layouts.app` — NOT here. Uses only HEEx
  `{...}` interpolation (auto-escaped); introduces no `raw/1`.
  """
  attr :title, :string, required: true
  attr :eyebrow, :string, default: nil
  attr :lede, :string, default: nil
  attr :theme, :string, default: "auto", values: ~w(auto light dark)
  attr :rest, :global
  slot :inner_block, required: true

  def ck_page(assigns) do
    ~H"""
    <div class="ck" data-ck-root data-theme={@theme != "auto" && @theme} {@rest}>
      <div class="ck__wrap">
        <header class="ck-hero">
          <span :if={@eyebrow} class="ck-eyebrow">{@eyebrow}</span>
          <h1 class="ck-hero__title">{@title}</h1>
          <p :if={@lede} class="ck-hero__lede">{@lede}</p>
        </header>
        {render_slot(@inner_block)}
      </div>
    </div>
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
  Lifecycle-state badge — maps a media asset / variant / upload-session state string
  to a `.ck-badge` variant so state is always shown as colour + label (never colour
  alone). The raw state text is the label (the `.ck-badge` rule uppercases it).
  """
  attr :state, :any, required: true
  attr :rest, :global

  def state_badge(assigns) do
    state = to_string(assigns.state)
    assigns = assign(assigns, state: state, variant: state_variant(state))

    ~H"""
    <span class={["ck-badge", "ck-badge--#{@variant}"]} data-state={@state} {@rest}>{@state}</span>
    """
  end

  defp state_variant(s)
       when s in ~w(ready available completed attached signed),
       do: "ready"

  defp state_variant(s)
       when s in ~w(queued processing promoting validating analyzing planned uploading verifying initialized staged),
       do: "processing"

  defp state_variant(s)
       when s in ~w(stale degraded missing aborted expired),
       do: "processing"

  defp state_variant(s)
       when s in ~w(quarantined rejected failed purging purged deleted detached),
       do: "quarantine"

  defp state_variant(_), do: "info"

  @doc """
  Upload dropzone — a branded `<label>` wrapping a (caller-owned, frozen) native
  `<input type=file>` or `<.live_file_input>` passed in `:inner_block`. The label
  proxies clicks to the input and the `Dropzone` JS hook adds drag-over highlight,
  filename echo, and drop-to-populate. The hook owns presentation only; the upload
  contract (id / phx-hook / accept / data-testid on the input) stays in the caller.
  """
  attr :input_id, :string, required: true, doc: "id stem for the dropzone label/hook"
  attr :lead, :string, required: true
  attr :hint, :string, required: true
  slot :inner_block, required: true

  def dropzone(assigns) do
    ~H"""
    <label id={"#{@input_id}-dropzone"} class="ck-dropzone" phx-hook="Dropzone">
      <span class="ck-dropzone__icon" aria-hidden="true">
        <svg
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
        >
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
          <path d="M7 10l5-5 5 5" /><path d="M12 5v12" />
        </svg>
      </span>
      <span class="ck-dropzone__text">
        <strong class="ck-dropzone__lead">{@lead}</strong>
        <span class="ck-dropzone__hint">{@hint}</span>
      </span>
      {render_slot(@inner_block)}
    </label>
    """
  end

  @doc """
  Upload status row — a lifecycle badge + an operator-voice note, wrapping the
  caller's preserved status `id`/`data-testid` node. The raw status token is kept
  verbatim in `.ck-statusbar__token` (the behavior e2e asserts its text) while the
  badge conveys state by colour + icon-dot + label (never colour alone).
  """
  attr :id, :string, required: true
  attr :testid, :string, required: true
  attr :status, :string, required: true

  def status_bar(assigns) do
    assigns = assign(assigns, :meta, status_meta(assigns.status))

    ~H"""
    <p id={@id} data-testid={@testid} class="ck-statusbar" data-state={@meta.state}>
      <.badge variant={@meta.badge} label={@meta.label} />
      <span :if={@meta.note != ""} class="ck-statusbar__note">{@meta.note}</span>
      <span class="ck-statusbar__token">{@status}</span>
    </p>
    """
  end

  # Maps the demo's raw status strings to the brandbook's upload-session vocabulary,
  # a badge variant, and a "what happened" note. Presentation only — no flow change.
  defp status_meta("ready"),
    do: %{
      state: "ready",
      badge: "ready",
      label: "Completed",
      note: "Uploaded, verified, attached."
    }

  defp status_meta("uploading"),
    do: %{
      state: "uploading",
      badge: "processing",
      label: "Uploading",
      note: "Transfer in flight to MinIO."
    }

  defp status_meta("presigning"),
    do: %{state: "uploading", badge: "processing", label: "Signed", note: "Presigned URL issued."}

  defp status_meta("initiating"),
    do: %{
      state: "uploading",
      badge: "processing",
      label: "Starting",
      note: "Initiating multipart upload."
    }

  defp status_meta("verifying"),
    do: %{
      state: "uploading",
      badge: "processing",
      label: "Verifying",
      note: "Confirming the object landed."
    }

  defp status_meta("idle"),
    do: %{state: "idle", badge: "info", label: "Ready", note: "Pick a file to begin."}

  defp status_meta("error" <> _),
    do: %{state: "error", badge: "quarantine", label: "Failed", note: "See the detail below."}

  defp status_meta(_), do: %{state: "info", badge: "info", label: "Status", note: ""}

  @doc """
  Level-1 data table (D-96-15). Uses the `core_components` `:col`/`:rows` model
  extended with per-column `sort_key`/`num`. Sort state is SERVER-owned: pass
  `sort_by`/`sort_dir` (the current LiveView assigns) and a `sort_event`; the
  sortable header is a real `<button>` carrying `aria-sort`. Numeric columns get
  `tabular-nums` for alignment. Renders an empty state and a loading skeleton.
  """
  attr :rows, :list, default: [], doc: "the row data (a list of maps/structs)"
  attr :row_id, :any, default: nil, doc: "optional fn(row) -> dom id"

  attr :row_attrs, :any,
    default: nil,
    doc: "optional fn(row) -> map of extra <tr> attributes (e.g. data-testid)"

  attr :sort_by, :string, default: nil, doc: "server-owned: the active sort_key"
  attr :sort_dir, :string, default: "asc", values: ~w(asc desc)
  attr :sort_event, :string, default: nil, doc: "phx-click event emitted by sort headers"
  attr :loading, :boolean, default: false
  attr :skeleton_rows, :integer, default: 3
  attr :empty_title, :string, default: "Nothing here yet"

  attr :empty_body, :string,
    default: "No records match this view. Adjust filters or seed demo data."

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
            {(@row_attrs && @row_attrs.(row)) || %{}}
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

  @doc """
  Form field wrapper (D-96-15). Derives `id`/`name`/`errors` from a
  `Phoenix.HTML.FormField`, renders a `.ck-label`, the control (an `:inner_block`
  control such as `ck_input`/`ck_select`, or a raw control), optional `.ck-help`,
  and a conditional non-color `.ck-error` (warning icon + message). Wires
  `aria-describedby` (help + error ids) on the nested control via `field_meta/2`.
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :label, :string, required: true
  attr :help, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  def ck_field(assigns) do
    errors = if Phoenix.Component.used_input?(assigns.field), do: assigns.field.errors, else: []

    assigns =
      assigns
      |> assign(:errors, Enum.map(errors, &translate_ck_error/1))
      |> assign(:help_id, "#{assigns.field.id}-help")
      |> assign(:error_id, "#{assigns.field.id}-error")

    ~H"""
    <div class="ck-field" {@rest}>
      <label class="ck-label" for={@field.id}>{@label}</label>
      {render_slot(@inner_block)}
      <p :if={@help} class="ck-help" id={@help_id}>{@help}</p>
      <p :if={@errors != []} class="ck-error" id={@error_id} role="alert">
        {ck_icon(%{name: :warning})}
        <span>{Enum.join(@errors, " ")}</span>
      </p>
    </div>
    """
  end

  @doc """
  Text input bound to a `Phoenix.HTML.FormField` (D-96-15). Wires
  `aria-describedby` (help + error) and `aria-invalid` from the field errors;
  supports `disabled` (→ `aria-disabled` + sunken styling). Render inside
  `ck_field` so the label/help/error ids line up.
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :type, :string, default: "text"
  attr :disabled, :boolean, default: false
  attr :rest, :global, include: ~w(placeholder inputmode autocomplete min max step)

  def ck_input(assigns) do
    assigns = assign(assigns, :meta, field_meta(assigns.field, assigns.disabled))

    ~H"""
    <input
      type={@type}
      id={@field.id}
      name={@field.name}
      value={Phoenix.HTML.Form.normalize_value(@type, @field.value)}
      class="ck-input"
      disabled={@disabled}
      aria-disabled={@disabled && "true"}
      aria-invalid={@meta.invalid}
      aria-describedby={@meta.describedby}
      {@rest}
    />
    """
  end

  @doc """
  Select bound to a `Phoenix.HTML.FormField` (D-96-15). Same aria wiring as
  `ck_input`. Pass `options` in the `Phoenix.HTML.Form.options_for_select/2`
  shape; render inside `ck_field`.
  """
  attr :field, Phoenix.HTML.FormField, required: true
  attr :options, :list, default: []
  attr :prompt, :string, default: nil
  attr :disabled, :boolean, default: false
  attr :rest, :global

  def ck_select(assigns) do
    assigns = assign(assigns, :meta, field_meta(assigns.field, assigns.disabled))

    ~H"""
    <select
      id={@field.id}
      name={@field.name}
      class="ck-select"
      disabled={@disabled}
      aria-disabled={@disabled && "true"}
      aria-invalid={@meta.invalid}
      aria-describedby={@meta.describedby}
      {@rest}
    >
      <option :if={@prompt} value="">{@prompt}</option>
      {Phoenix.HTML.Form.options_for_select(@options, @field.value)}
    </select>
    """
  end

  # Shared aria contract for the form controls (D-96-15): aria-invalid from the
  # field errors, aria-describedby pointing at the help + error element ids.
  defp field_meta(%Phoenix.HTML.FormField{} = field, _disabled) do
    invalid? = Phoenix.Component.used_input?(field) and field.errors != []

    %{
      invalid: invalid? && "true",
      describedby: "#{field.id}-help #{field.id}-error"
    }
  end

  defp translate_ck_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  defp translate_ck_error(msg) when is_binary(msg), do: msg

  @doc """
  WAI-ARIA APG tabs (D-96-17). Renders the full `role=tablist/tab/tabpanel`
  structure with `aria-selected`, `aria-controls`, roving `tabindex` (0 on the
  selected tab, -1 on others), the selected cue as `aria-selected` + underline +
  weight (non-color). Click is server-owned via `phx-click`; KEYBOARD
  (Arrow/Home/End) is owned by the `phx-hook="Tabs"` handler in app.js. Pass the
  server-owned `selected` tab id and a `select_event`.
  """
  attr :id, :string, required: true, doc: "stable id; tab/panel ids derive from it"
  attr :selected, :string, required: true, doc: "server-owned: the selected tab id"
  attr :select_event, :string, default: nil, doc: "phx-click event emitted on tab click"
  attr :label, :string, default: "Tabs", doc: "accessible tablist label"
  attr :rest, :global

  slot :tab, required: true do
    attr :id, :string, required: true
    attr :label, :string, required: true
    attr :disabled?, :boolean
  end

  def ck_tabs(assigns) do
    ~H"""
    <div class="ck-tabs" {@rest}>
      <div
        class="ck-tabs__list"
        role="tablist"
        aria-label={@label}
        id={"#{@id}-tablist"}
        phx-hook="Tabs"
      >
        <button
          :for={tab <- @tab}
          type="button"
          role="tab"
          class={["ck-tabs__tab", "ck-tab"]}
          id={"#{@id}-tab-#{tab.id}"}
          aria-controls={"#{@id}-panel-#{tab.id}"}
          aria-selected={(@selected == tab.id && "true") || "false"}
          aria-disabled={tab[:disabled?] && "true"}
          tabindex={(@selected == tab.id && "0") || "-1"}
          disabled={tab[:disabled?]}
          phx-click={@select_event}
          phx-value-tab={tab.id}
        >
          {tab.label}
        </button>
      </div>
      <div
        :for={tab <- @tab}
        role="tabpanel"
        class="ck-tabs__panel"
        id={"#{@id}-panel-#{tab.id}"}
        aria-labelledby={"#{@id}-tab-#{tab.id}"}
        tabindex="0"
        hidden={@selected != tab.id}
      >
        {render_slot(tab)}
      </div>
    </div>
    """
  end

  # --- inline icon set (no external sprite dependency) ----------------------

  # General-purpose icons used by the L1 primitives (currentColor stroke so the
  # color is inherited from the surrounding state, never color-only on its own).
  attr :name, :atom, required: true

  defp ck_icon(%{name: :warning} = assigns) do
    ~H"""
    <svg
      class="ck-icon"
      viewBox="0 0 24 24"
      width="16"
      height="16"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M10.3 3.7 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.7a2 2 0 0 0-3.4 0Z" />
      <path d="M12 9v4" /><path d="M12 17h.01" />
    </svg>
    """
  end

  defp ck_icon(assigns), do: ck_icon(%{assigns | name: :warning})

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
