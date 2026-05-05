defmodule Rindle.Probe do
  @moduledoc """
  Behaviour contract for content-analysis probes.

  Probes inspect a local file path (already downloaded out of storage) and
  return a normalized result map describing the content's kind, dimensions,
  duration, track presence, and free-form metadata. Storage I/O happens
  outside this callback; probes operate on local paths only.

  This is symmetric with `Rindle.Processor` (see `lib/rindle/processor.ex`)
  and intentionally distinct from `Rindle.AV.Probe`, which is the boot-time
  FFmpeg version probe (D-05). See SYNTHESIS §2.2 for the naming choice.

  See:
    * `Rindle.Probe.Image` — libvips-backed image probe (no FFmpeg required).
    * `Rindle.Probe.AVProbe` — FFprobe-backed video/audio probe.
  """

  @type kind :: :image | :video | :audio
  @type result :: %{
          required(:kind) => kind(),
          optional(:width) => pos_integer(),
          optional(:height) => pos_integer(),
          optional(:duration_ms) => non_neg_integer(),
          optional(:has_video_track) => boolean(),
          optional(:has_audio_track) => boolean(),
          optional(:metadata) => map()
        }

  @callback probe(source :: Path.t()) :: {:ok, result()} | {:error, term()}
  @callback accepts?(content_type :: String.t()) :: boolean()
end
