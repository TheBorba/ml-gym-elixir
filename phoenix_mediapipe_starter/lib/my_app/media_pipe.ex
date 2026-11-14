defmodule MyApp.MediaPipe do
  @moduledoc """
  Configuration namespace for the MediaPipe Pose Landmarker model path.

  Configured via `config :my_app, MyApp.MediaPipe, model_path: "..."`.
  See `priv/models/README.md` for download instructions.
  """

  @doc """
  Returns the configured MediaPipe model path, or the default.
  """
  def model_path do
    Application.get_env(:my_app, __MODULE__, [])
    |> Keyword.get(:model_path, "priv/models/pose_landmarker_lite.task")
  end
end
