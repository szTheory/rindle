defmodule Rindle.AV.Capability do
  @moduledoc """
  Domain vocabulary for processing capabilities.
  """
  
  @type t :: :video_transcode | :audio_normalize

  @capabilities [
    :video_transcode,
    :audio_normalize
  ]

  @doc """
  Returns a list of all supported processing capabilities.
  """
  def all, do: @capabilities

  @doc """
  Checks if a given capability is supported.
  """
  def valid?(capability) when capability in @capabilities, do: true
  def valid?(_), do: false
end
