defmodule AdoptionDemoWeb.OpsRuntimeStatusProvider do
  @moduledoc false

  def runtime_status([]) do
    {:error,
     {:unexpected_runtime_failure,
      %{
        sql: "SELECT secret FROM pg_catalog",
        adapter: "Postgrex.Error",
        credential: "credential=demo-password"
      }}}
  end
end

defmodule AdoptionDemoWeb.OpsLiveTest do
  use AdoptionDemoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  setup do
    previous = Application.get_env(:adoption_demo, :ops_runtime_status_provider)

    Application.put_env(
      :adoption_demo,
      :ops_runtime_status_provider,
      AdoptionDemoWeb.OpsRuntimeStatusProvider
    )

    on_exit(fn ->
      if previous do
        Application.put_env(:adoption_demo, :ops_runtime_status_provider, previous)
      else
        Application.delete_env(:adoption_demo, :ops_runtime_status_provider)
      end
    end)
  end

  test "runtime-status click renders bounded refusal guidance without provider sentinels", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/ops")

    html =
      view
      |> element(~s([data-testid="run-runtime-status-button"]))
      |> render_click()

    assert has_element?(view, ~s([data-testid="runtime-status-output"]))
    assert html =~ "Rindle.RuntimeStatus failed: unknown"
    assert html =~ "no report queries ran"
    assert html =~ "mix rindle.doctor"

    refute html =~ "SELECT secret FROM pg_catalog"
    refute html =~ "Postgrex.Error"
    refute html =~ "credential=demo-password"
  end
end
