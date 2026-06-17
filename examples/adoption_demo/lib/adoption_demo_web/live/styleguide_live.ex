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
  # list with two distinct empty-state copy variants. NOT lorem.
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
  attr :error_form, :map, required: true

  defp gallery_sections(assigns) do
    ~H"""
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
