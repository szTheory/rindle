defmodule AdoptionDemoWeb.CohortTheme do
  @moduledoc """
  Shared route-theme normalization for Cohort LiveViews.

  Route params are untrusted strings. Keep this helper string-only so invalid
  values cannot create atoms or leak into `data-theme`.
  """

  @allowed ~w(light dark)

  def normalize(theme, _default) when theme in @allowed, do: theme
  def normalize(_theme, default), do: default
end
