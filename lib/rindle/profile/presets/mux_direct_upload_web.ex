defmodule Rindle.Profile.Presets.MuxDirectUploadWeb do
  alias Rindle.Profile.Presets.Web

  @moduledoc """
  Mux direct-upload preset.

  Mirrors `Rindle.Profile.Presets.MuxWeb` but locks
  `delivery.streaming.ingest_mode` to `:direct_creator_upload`.
  """

  @type option :: Web.option()

  @doc false
  defmacro __using__(opts) do
    opts = Macro.expand_literals(opts, __CALLER__)
    scrub_strip? = Keyword.get(opts, :scrub_strip, false)
    adopter_delivery = Keyword.get(opts, :delivery, [])

    locked_streaming = [
      streaming: [
        provider: Rindle.Streaming.Provider.Mux,
        playback_policy: :signed,
        ingest_mode: :direct_creator_upload,
        source_variant: :web_720p
      ]
    ]

    delivery = Keyword.merge(adopter_delivery, locked_streaming)

    profile_opts =
      opts
      |> Keyword.delete(:scrub_strip)
      |> Keyword.delete(:delivery)
      |> Keyword.put(:variants, Web.variants(scrub_strip: scrub_strip?))
      |> Keyword.put(:delivery, delivery)

    quote do
      use Rindle.Profile, unquote(Macro.escape(profile_opts))
    end
  end
end
