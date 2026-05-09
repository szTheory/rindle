defmodule Rindle.Profile.Presets.MuxWeb do
  alias Rindle.Profile.Presets.Web

  @moduledoc """
  Mux streaming preset — the canonical AV web preset PLUS streaming opt-in.

  Inherits the `web_720p` + `poster` variant set verbatim from
  `Web` and adds a locked `:streaming` delivery block
  (provider Mux, signed playback, server-push ingest, web_720p source).

  Adopters who want AV-only without streaming should keep using
  `Web`. There is no `__using__/1` opt-out for the
  streaming block — `MuxWeb` is streaming-on by definition.

  The preset compiles even when the optional `:mux` dep is absent: the DSL
  stores only the provider-module atom, and runtime resolution happens via
  `Code.ensure_loaded?` in `Rindle.Delivery.streaming_url/3`.

  Adopter-supplied `:delivery` keys other than `:streaming` (e.g. `:public`,
  `:signed_url_ttl_seconds`) are preserved; the locked streaming block always
  wins on the `:streaming` key.

  ## Example

      defmodule MyApp.Streaming do
        use Rindle.Profile.Presets.MuxWeb,
          storage: Rindle.Storage.S3,
          allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
          max_bytes: 524_288_000
      end

  See [`guides/streaming_providers.md`](streaming_providers.html) for full
  setup (Mux dashboard, webhook plug, doctor smoke, secret rotation).
  """

  @type option :: Web.option()

  @doc false
  defmacro __using__(opts) do
    opts = Macro.expand_literals(opts, __CALLER__)
    scrub_strip? = Keyword.get(opts, :scrub_strip, false)

    # Adopter-supplied :delivery block (if any) wins for keys other than
    # :streaming. The streaming block is locked — adopters cannot override
    # it; that would defeat the preset's purpose.
    adopter_delivery = Keyword.get(opts, :delivery, [])

    # Use a keyword list (not a map) so Macro.escape produces a literal-list
    # AST that the receiving `use Rindle.Profile` macro can statically inspect
    # via `Macro.expand_literals/2`. The validator's @delivery_schema accepts
    # `{:or, [:keyword_list, {:map, :atom, :any}]}` for the :streaming key —
    # both shapes pass validation and normalize to a map in delivery_policy/0.
    locked_streaming = [
      streaming: [
        provider: Rindle.Streaming.Provider.Mux,
        playback_policy: :signed,
        ingest_mode: :server_push,
        source_variant: :web_720p
      ]
    ]

    # Keyword.merge/2: second arg's keys win on conflict — streaming is
    # always the locked map; other delivery keys (public, signed_url_ttl_seconds, ...)
    # come from the adopter.
    delivery = Keyword.merge(adopter_delivery, locked_streaming)

    profile_opts =
      opts
      |> Keyword.delete(:scrub_strip)
      |> Keyword.delete(:delivery)
      |> Keyword.put(
        :variants,
        Web.variants(scrub_strip: scrub_strip?)
      )
      |> Keyword.put(:delivery, delivery)

    quote do
      use Rindle.Profile, unquote(Macro.escape(profile_opts))
    end
  end
end
