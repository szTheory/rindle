defmodule AdoptionDemoWeb.StyleguideLive do
  @moduledoc """
  Developer-facing `/styleguide` gallery (COHORT-06). Renders every Cohort
  Level-1 `.ck-*` primitive and the four Level-2 compositions across light and
  dark, on a per-LiveView `.ck` shell carrying the `data-ck-root` /
  `data-theme` polish seam (D-96-05 — on the `.ck` div, never on `<body>`).

  Theme is SERVER state (`assign(:theme)` + `phx-click`), no client-side
  storage, so the Plan 05 Playwright spec drives themes deterministically
  (D-96-07/16). Sort
  state is likewise SERVER-owned (D-96-15). Stable `data-ck-section` /
  `data-ck-state` markers are emitted SEPARATE from the BEM styling classes
  (D-96-16) — the spec asserts on those, never on `.ck-*` styling classes.

  This is the VIS-04 audit reference and the route the Plan 05 spec + the Plan
  04 component-existence loop drive; it composes only from the Plan 02
  primitives (`AdoptionDemoWeb.CohortComponents`).
  """
  use AdoptionDemoWeb, :live_view

  import AdoptionDemoWeb.CohortComponents

  # Known sortable column set — `set_sort` validates `key` against this so an
  # invalid/forged param is ignored, not reflected (T-96-06 mitigation).
  @sort_keys ~w(lesson status duration)

  # Real Cohort fiction seeded into the gallery (D-96-22): a lesson-video row
  # going `processing`, a quarantined upload, and (separately) an empty member
  # list with two distinct empty-state copy variants. Real domain rows, not
  # placeholder filler text.
  @lesson_rows [
    %{lesson: "Welcome to the cohort", status: "ready", duration: "4:12", duration_s: 252},
    %{lesson: "Module 1 — Foundations", status: "ready", duration: "18:30", duration_s: 1110},
    %{lesson: "Module 2 — Live workshop", status: "processing", duration: "—", duration_s: 0},
    %{lesson: "Office hours (raw upload)", status: "quarantine", duration: "—", duration_s: 0}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Cohort styleguide",
       theme: "light",
       sort_by: "lesson",
       sort_dir: "asc",
       selected_tab: "members",
       lesson_rows: @lesson_rows,
       form: to_form(%{"email" => "", "role" => ""}, as: :member),
       disabled_form: to_form(%{"email" => ""}, as: :member_disabled),
       error_form:
         to_form(%{"email" => ""}, as: :invite)
         |> then(fn f -> %{f | errors: [email: {"%{field} is required.", [field: "Email"]}]} end)
     )}
  end

  @impl true
  def handle_event("set_theme", %{"theme" => theme}, socket) when theme in ~w(light dark) do
    {:noreply, assign(socket, theme: theme)}
  end

  def handle_event("set_sort", %{"key" => key}, socket) when key in @sort_keys do
    dir =
      if socket.assigns.sort_by == key and socket.assigns.sort_dir == "asc",
        do: "desc",
        else: "asc"

    rows = sort_rows(socket.assigns.lesson_rows, key, dir)
    {:noreply, assign(socket, sort_by: key, sort_dir: dir, lesson_rows: rows)}
  end

  def handle_event("set_sort", _params, socket), do: {:noreply, socket}

  def handle_event("set_tab", %{"tab" => tab}, socket) when tab in ~w(members lessons) do
    {:noreply, assign(socket, selected_tab: tab)}
  end

  def handle_event("set_tab", _params, socket), do: {:noreply, socket}

  # The styleguide form is a static demo surface — change/submit are no-ops
  # (no data mutation; T-96-05 accept). It exists to demo FormField semantics.
  def handle_event("noop", _params, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="ck" data-ck-root data-theme={@theme}>
      <.cohort_nav active={nil} />

      <main class="ck__wrap">
        <.hero
          eyebrow="Cohort design system"
          title="Styleguide — every .ck-* primitive, light and dark."
          lede="The developer reference gallery for Cohort's hand-authored component layer. Toggle the theme to inspect both token sets; every section carries stable data-ck-section / data-ck-state markers for the audit and e2e gates."
        >
          <:actions>
            <div class="ck-toolbar" role="group" aria-label="Theme">
              <button
                type="button"
                class={["ck-btn", @theme == "light" && "ck-btn--primary"]}
                phx-click="set_theme"
                phx-value-theme="light"
                aria-pressed={@theme == "light"}
                data-ck-theme="light"
              >
                Light
              </button>
              <button
                type="button"
                class={["ck-btn", @theme == "dark" && "ck-btn--primary"]}
                phx-click="set_theme"
                phx-value-theme="dark"
                aria-pressed={@theme == "dark"}
                data-ck-theme="dark"
              >
                Dark
              </button>
            </div>
          </:actions>
        </.hero>

        <.gallery_sections
          lesson_rows={@lesson_rows}
          sort_by={@sort_by}
          sort_dir={@sort_dir}
          selected_tab={@selected_tab}
          form={@form}
          disabled_form={@disabled_form}
          error_form={@error_form}
        />

        <.cohort_footer />
      </main>
    </div>
    """
  end

  # The primitive + Level-2 gallery sections are filled in Task 2.
  attr :lesson_rows, :list, required: true
  attr :sort_by, :string, required: true
  attr :sort_dir, :string, required: true
  attr :selected_tab, :string, required: true
  attr :form, :map, required: true
  attr :disabled_form, :map, required: true
  attr :error_form, :map, required: true

  defp gallery_sections(assigns) do
    ~H"""
    <!-- ============================ LEVEL 1 ============================ -->
    <section class="ck-section" data-ck-section="table" data-ck-state="default">
      <div class="ck-section__head">
        <h2 class="ck-section__title">Table</h2>
        <span class="ck-section__hint">Sortable header (server-owned), zebra rows, status badges, empty + loading.</span>
      </div>

      <div data-ck-state="sortable">
        <.ck_table
          rows={@lesson_rows}
          sort_by={@sort_by}
          sort_dir={@sort_dir}
          sort_event="set_sort"
          row_id={fn row -> "lesson-#{:erlang.phash2(row.lesson)}" end}
        >
          <:col :let={row} label="Lesson" sort_key="lesson">{row.lesson}</:col>
          <:col :let={row} label="Status" sort_key="status">
            <.badge variant={row.status} label={String.capitalize(row.status)} />
          </:col>
          <:col :let={row} label="Duration" sort_key="duration" num>{row.duration}</:col>
        </.ck_table>
      </div>

      <div data-ck-state="empty-never-populated">
        <.ck_table
          rows={[]}
          empty_title="Nothing here yet"
          empty_body="No members have joined this cohort. Invite someone or seed demo data."
        >
          <:col label="Member">—</:col>
          <:col label="Status">—</:col>
        </.ck_table>
      </div>

      <div data-ck-state="empty-filtered">
        <.ck_table
          rows={[]}
          empty_title="Nothing here yet"
          empty_body="No records match this view. Adjust filters or seed demo data."
        >
          <:col label="Member">—</:col>
          <:col label="Status">—</:col>
        </.ck_table>
      </div>

      <div data-ck-state="loading">
        <.ck_table loading rows={[]}>
          <:col label="Lesson">—</:col>
          <:col label="Status">—</:col>
          <:col label="Duration" num>—</:col>
        </.ck_table>
      </div>
    </section>

    <section class="ck-section" data-ck-section="stat" data-ck-state="default">
      <div class="ck-section__head">
        <h2 class="ck-section__title">Stat tile</h2>
        <span class="ck-section__hint">tabular-nums value, status accent, em-dash empty, loading skeleton.</span>
      </div>
      <div class="ck-grid">
        <.ck_stat label="Lessons ready" value="38" delta="+4" delta_dir="up" />
        <div data-ck-state="status"><.ck_stat label="Processing" value="2" status="processing" /></div>
        <div data-ck-state="empty"><.ck_stat label="Quarantined" status="quarantine" /></div>
        <div data-ck-state="loading"><.ck_stat label="Members" loading /></div>
      </div>
    </section>

    <section class="ck-section" data-ck-section="form" data-ck-state="default">
      <div class="ck-section__head">
        <h2 class="ck-section__title">Form</h2>
        <span class="ck-section__hint">FormField semantics, focus-visible, disabled, non-color error.</span>
      </div>
      <.form for={@form} phx-change="noop" phx-submit="noop">
        <.ck_field field={@form[:email]} label="Email" help="We never share this.">
          <.ck_input field={@form[:email]} type="email" placeholder="maya@cohort.dev" />
        </.ck_field>
        <.ck_field field={@form[:role]} label="Role">
          <.ck_select
            field={@form[:role]}
            prompt="Choose a role"
            options={[{"Instructor", "instructor"}, {"Student", "student"}, {"Operator", "operator"}]}
          />
        </.ck_field>
        <div data-ck-state="disabled">
          <.ck_field field={@disabled_form[:email]} label="Email (disabled)">
            <.ck_input field={@disabled_form[:email]} type="email" disabled />
          </.ck_field>
        </div>
        <div data-ck-state="error">
          <.ck_field field={@error_form[:email]} label="Email">
            <.ck_input field={@error_form[:email]} type="email" />
          </.ck_field>
        </div>
        <.ck_button>Save changes</.ck_button>
      </.form>
    </section>

    <section class="ck-section" data-ck-section="tabs" data-ck-state="default">
      <div class="ck-section__head">
        <h2 class="ck-section__title">Tabs</h2>
        <span class="ck-section__hint">WAI-ARIA APG, server-owned selection, keyboard via the Tabs hook, one disabled tab.</span>
      </div>
      <.ck_tabs id="sg-tabs" selected={@selected_tab} select_event="set_tab" label="Styleguide demo tabs">
        <:tab id="members" label="Members">
          <p>The seeded member roster lives here.</p>
        </:tab>
        <:tab id="lessons" label="Lessons">
          <p>The lesson catalogue lives here.</p>
        </:tab>
        <:tab id="archived" label="Archived" disabled?>
          <p>Disabled tab panel.</p>
        </:tab>
      </.ck_tabs>
    </section>

    <section class="ck-section" data-ck-section="detail" data-ck-state="default">
      <div class="ck-section__head">
        <h2 class="ck-section__title">Detail block</h2>
        <span class="ck-section__hint">A real dl term/desc, multi-row, with an empty state.</span>
      </div>
      <div data-ck-state="multi-row">
        <.ck_detail>
          <:item term="Lesson">Module 2 — Live workshop</:item>
          <:item term="Status">processing</:item>
          <:item term="Uploaded by">Maya Rivera</:item>
        </.ck_detail>
      </div>
      <div data-ck-state="empty">
        <.ck_detail empty_title="Nothing here yet" />
      </div>
    </section>

    <section class="ck-section" data-ck-section="toolbar" data-ck-state="default">
      <div class="ck-section__head">
        <h2 class="ck-section__title">Toolbar</h2>
        <span class="ck-section__hint">Group label, wraps on narrow viewports, primary + quiet actions.</span>
      </div>
      <div data-ck-state="primary-quiet">
        <.ck_toolbar label="Lessons toolbar">
          <strong>Lessons</strong>
          <:actions>
            <.ck_button>Apply filters</.ck_button>
            <.ck_button variant="primary">Save changes</.ck_button>
          </:actions>
        </.ck_toolbar>
      </div>
    </section>

    <!-- ============================ LEVEL 2 ============================ -->
    <section class="ck-section" data-ck-section="data-table-block" data-ck-state="default">
      <div class="ck-section__head">
        <h2 class="ck-section__title">Data-table block</h2>
        <span class="ck-section__hint">Toolbar + table + status badges (the dashboard/lesson list shape).</span>
      </div>
      <.ck_toolbar label="Lesson library">
        <strong>Lesson library</strong>
        <:actions>
          <.ck_button>Apply filters</.ck_button>
          <.ck_button variant="primary">Save changes</.ck_button>
        </:actions>
      </.ck_toolbar>
      <.ck_table
        rows={@lesson_rows}
        sort_by={@sort_by}
        sort_dir={@sort_dir}
        sort_event="set_sort"
      >
        <:col :let={row} label="Lesson" sort_key="lesson">{row.lesson}</:col>
        <:col :let={row} label="Status" sort_key="status">
          <.badge variant={row.status} label={String.capitalize(row.status)} />
        </:col>
        <:col :let={row} label="Duration" sort_key="duration" num>{row.duration}</:col>
      </.ck_table>
    </section>

    <section class="ck-section" data-ck-section="stat-row" data-ck-state="default">
      <div class="ck-section__head">
        <h2 class="ck-section__title">Stat row</h2>
        <span class="ck-section__hint">Responsive grid of stat tiles.</span>
      </div>
      <div class="ck-grid">
        <.ck_stat label="Lessons" value="40" />
        <.ck_stat label="Processing" value="2" status="processing" />
        <.ck_stat label="Quarantined" value="1" status="quarantine" />
        <.ck_stat label="Members" value="128" delta="+12" delta_dir="up" />
      </div>
    </section>

    <section class="ck-section" data-ck-section="detail-panel" data-ck-state="default">
      <div class="ck-section__head">
        <h2 class="ck-section__title">Detail panel</h2>
        <span class="ck-section__hint">Panel + detail block + badge (record drill-down shape).</span>
      </div>
      <section class="ck-panel">
        <h3 class="ck-panel__title">Module 2 — Live workshop</h3>
        <.ck_detail>
          <:item term="Status">
            <.badge variant="processing" label="Processing" />
          </:item>
          <:item term="Duration">—</:item>
          <:item term="Uploaded by">Maya Rivera</:item>
        </.ck_detail>
      </section>
    </section>

    <section class="ck-section" data-ck-section="tabbed-section" data-ck-state="default">
      <div class="ck-section__head">
        <h2 class="ck-section__title">Tabbed section</h2>
        <span class="ck-section__hint">Tabs containing a per-panel table / detail (the /upload shape).</span>
      </div>
      <.ck_tabs id="sg-tabbed" selected={@selected_tab} select_event="set_tab" label="Tabbed section demo">
        <:tab id="members" label="Roster">
          <.ck_table
            rows={[]}
            empty_title="Nothing here yet"
            empty_body="No records match this view. Adjust filters or seed demo data."
          >
            <:col label="Member">—</:col>
            <:col label="Role">—</:col>
          </.ck_table>
          <p data-ck-state="empty-filtered" class="ck-empty__body">
            No records match this view. Adjust filters or seed demo data.
          </p>
        </:tab>
        <:tab id="lessons" label="Lessons">
          <.ck_table
            rows={@lesson_rows}
            sort_by={@sort_by}
            sort_dir={@sort_dir}
            sort_event="set_sort"
          >
            <:col :let={row} label="Lesson" sort_key="lesson">{row.lesson}</:col>
            <:col :let={row} label="Duration" sort_key="duration" num>{row.duration}</:col>
          </.ck_table>
        </:tab>
      </.ck_tabs>
    </section>
    """
  end

  # Server-owned sort (D-96-15). Numeric column sorts on the backing seconds.
  defp sort_rows(rows, "duration", dir) do
    sorted = Enum.sort_by(rows, & &1.duration_s)
    if dir == "desc", do: Enum.reverse(sorted), else: sorted
  end

  defp sort_rows(rows, key, dir) do
    field = String.to_existing_atom(key)
    sorted = Enum.sort_by(rows, &Map.fetch!(&1, field))
    if dir == "desc", do: Enum.reverse(sorted), else: sorted
  end
end
