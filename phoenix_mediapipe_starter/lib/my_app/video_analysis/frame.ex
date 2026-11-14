defmodule MyApp.Frame do
  @moduledoc """
  A sampled landmark frame from an MP4 analysis.

  Landmarks are stored exactly as MediaPipe emitted them, split by coordinate
  system. Use `MyApp.Biometrics.Normalizer.from_mediapipe/4` to turn a stored
  list into `%MyApp.Biometrics.Landmark{}` maps.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias MyApp.Analysis

  @type t :: %__MODULE__{}

  schema "frames" do
    field(:frame_index, :integer)
    field(:timestamp_ms, :integer)
    field(:image_landmarks, {:array, :map})
    field(:world_landmarks, {:array, :map})

    belongs_to(:analysis, Analysis)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @required ~w(analysis_id frame_index timestamp_ms)a

  @doc false
  def changeset(frame, attrs) do
    frame
    |> cast(attrs, @required ++ [:image_landmarks, :world_landmarks])
    |> validate_required(@required)
    |> unique_constraint([:analysis_id, :frame_index])
    |> foreign_key_constraint(:analysis_id)
  end
end
