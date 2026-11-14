defmodule MyApp.Biometrics.NormalizerTest do
  use ExUnit.Case, async: true

  alias MyApp.Biometrics.{Landmark, Normalizer}
  alias MyApp.PoseFixtures, as: F

  test "maps the first 33 MediaPipe indices to canonical names" do
    points = for i <- 0..32, do: F.mediapipe_point(i / 100, i / 100)

    landmarks = Normalizer.from_mediapipe(points, :image_normalized, 250, "lite")

    assert map_size(landmarks) == 33
    assert Map.has_key?(landmarks, :nose)
    assert Map.has_key?(landmarks, :left_shoulder)
    assert Map.has_key?(landmarks, :right_foot_index)
  end

  test "populates struct fields from the point map" do
    points = [F.mediapipe_point(0.1, 0.2, z: 0.3, visibility: 0.8, presence: 0.7)]

    assert %{nose: %Landmark{} = nose} =
             Normalizer.from_mediapipe(points, :world_3d, 42, "pose_landmarker_full")

    assert nose.name == "nose"
    assert nose.x == 0.1
    assert nose.y == 0.2
    assert nose.z == 0.3
    assert nose.visibility == 0.8
    assert nose.presence == 0.7
    assert nose.coordinate_system == :world_3d
    assert nose.timestamp_ms == 42
    assert nose.model == "pose_landmarker_full"
  end

  test "drops points without numeric x or y" do
    points = [
      F.mediapipe_point(0.1, 0.2),
      %{"x" => nil, "y" => 0.3},
      %{"x" => 0.4}
    ]

    landmarks = Normalizer.from_mediapipe(points, :image_normalized, 0, "lite")

    assert Map.keys(landmarks) == [:nose]
  end

  test "ignores points beyond index 32" do
    points = for _i <- 0..40, do: F.mediapipe_point(0.5, 0.5)

    landmarks = Normalizer.from_mediapipe(points, :image_normalized, 0, "lite")

    assert map_size(landmarks) == 33
  end

  test "handles an empty list" do
    assert Normalizer.from_mediapipe([], :image_normalized, 0, "lite") == %{}
  end
end
