defmodule MyApp.Biometrics.Landmark do
  @moduledoc """
  Canonical landmark representation shared by webcam and MP4 pipelines.

  `image_normalized` coordinates are in [0, 1].
  `world_3d` coordinates are MediaPipe estimated world coordinates in meters.
  Never mix the two coordinate systems in one angle calculation.
  """

  @enforce_keys [:name, :x, :y, :coordinate_system]
  defstruct [
    :name, :x, :y, :z, :visibility, :presence,
    :coordinate_system, :timestamp_ms, :model
  ]

  @type coordinate_system :: :image_normalized | :world_3d
end
