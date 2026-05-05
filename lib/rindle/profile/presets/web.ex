defmodule Rindle.Profile.Presets.Web do
  @moduledoc """
  Stock AV preset helpers for the canonical web onboarding story.

  The default surface is explicit and small:

  - `:web_720p` video output
  - `:poster` image output
  - optional `:scrub_strip` only when requested

  This keeps the public preset posture teachable without widening the profile
  DSL into raw FFmpeg policy.
  """

  @type option :: {:scrub_strip, boolean()}

  @doc false
  defmacro __using__(opts) do
    opts = Macro.expand_literals(opts, __CALLER__)
    scrub_strip? = Keyword.get(opts, :scrub_strip, false)

    profile_opts =
      opts
      |> Keyword.delete(:scrub_strip)
      |> Keyword.put(:variants, variants(scrub_strip: scrub_strip?))

    quote do
      use Rindle.Profile, unquote(Macro.escape(profile_opts))
    end
  end

  @doc """
  Returns the stock AV variant declarations for the onboarding story.
  """
  @spec variants([option()]) :: keyword(keyword())
  def variants(opts \\ []) do
    scrub_strip? = Keyword.get(opts, :scrub_strip, false)

    [
      web_720p: [kind: :video, preset: :web_720p],
      poster: [kind: :image, preset: :video_poster_scene]
    ] ++ maybe_scrub_strip(scrub_strip?)
  end

  defp maybe_scrub_strip(true), do: [scrub_strip: [kind: :image, preset: :video_thumbnail_strip]]
  defp maybe_scrub_strip(false), do: []
end
