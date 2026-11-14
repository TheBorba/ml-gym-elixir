defmodule MyApp.PoseFixtures do
  @moduledoc """
  Synthetic landmark builders for biomechanics tests.

  Coordinates are deliberately simple so expected angles are exact:

    * `straight_knee_landmarks/1` — hip above knee above ankle → 180°
    * `bent_knee_landmarks/1`     — shin horizontal → 90°
  """

  alias MyApp.Biometrics.Landmark

  @doc """
  Builds one `Landmark` struct.
  """
  def landmark(name, x, y, opts \\ []) do
    %Landmark{
      name: Atom.to_string(name),
      x: x,
      y: y,
      z: Keyword.get(opts, :z, 0.0),
      visibility: Keyword.get(opts, :visibility, 0.99),
      presence: Keyword.get(opts, :presence, 0.99),
      coordinate_system: Keyword.get(opts, :coordinate_system, :image_normalized),
      timestamp_ms: Keyword.get(opts, :timestamp_ms, 0),
      model: Keyword.get(opts, :model, "pose_landmarker_lite")
    }
  end

  @doc """
  Fully extended left leg: the knee interior angle is 180°.
  """
  def straight_knee_landmarks(opts \\ []) do
    cs = Keyword.get(opts, :coordinate_system, :image_normalized)
    visibility = Keyword.get(opts, :visibility, 0.99)

    %{
      left_hip: landmark(:left_hip, 0.5, 0.4, coordinate_system: cs, visibility: visibility),
      left_knee: landmark(:left_knee, 0.5, 0.6, coordinate_system: cs, visibility: visibility),
      left_ankle: landmark(:left_ankle, 0.5, 0.8, coordinate_system: cs, visibility: visibility)
    }
  end

  @doc """
  Left knee flexed to 90°: the shin points horizontally from the knee.
  """
  def bent_knee_landmarks(opts \\ []) do
    cs = Keyword.get(opts, :coordinate_system, :image_normalized)

    %{
      left_hip: landmark(:left_hip, 0.5, 0.4, coordinate_system: cs),
      left_knee: landmark(:left_knee, 0.5, 0.6, coordinate_system: cs),
      left_ankle: landmark(:left_ankle, 0.7, 0.6, coordinate_system: cs)
    }
  end

  @doc """
  A MediaPipe-shaped point map (string keys), as emitted by the Python worker.
  """
  def mediapipe_point(x, y, opts \\ []) do
    %{
      "x" => x,
      "y" => y,
      "z" => Keyword.get(opts, :z, 0.0),
      "visibility" => Keyword.get(opts, :visibility, 0.9),
      "presence" => Keyword.get(opts, :presence, 0.9)
    }
  end
end
