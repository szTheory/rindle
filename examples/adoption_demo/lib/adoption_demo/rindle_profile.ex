defmodule AdoptionDemo.RindleProfile do
  @moduledoc false

  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [thumb: [mode: :fit, width: 64, height: 64]],
    allow_mime: ["image/png", "image/jpeg"],
    max_bytes: 10_485_760
end

defmodule AdoptionDemo.VideoProfile do
  @moduledoc false

  use Rindle.Profile.Presets.Web,
    storage: Rindle.Storage.S3,
    allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
    max_bytes: 524_288_000
end

defmodule AdoptionDemo.MuxProfile do
  @moduledoc false

  use Rindle.Profile.Presets.MuxWeb,
    storage: Rindle.Storage.S3,
    allow_mime: ["video/mp4", "video/quicktime", "video/webm"],
    max_bytes: 524_288_000
end

defmodule AdoptionDemo.AudioProfile do
  @moduledoc false

  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [],
    allow_mime: ["audio/mpeg", "audio/ogg", "audio/wav"],
    max_bytes: 52_428_800
end

defmodule AdoptionDemo.DocumentProfile do
  @moduledoc false

  use Rindle.Profile,
    storage: Rindle.Storage.S3,
    variants: [],
    allow_mime: ["application/pdf", "text/plain"],
    max_bytes: 20_971_520
end
