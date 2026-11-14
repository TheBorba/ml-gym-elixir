defmodule MyApp.Biometrics.MeasurementTest do
  use ExUnit.Case, async: true

  alias MyApp.Biometrics.Measurement
  alias MyApp.PoseFixtures, as: F

  describe "joints/0" do
    test "lists the supported joints" do
      joints = Measurement.joints()

      assert length(joints) == 10
      assert "left_knee" in joints
      assert "right_shoulder" in joints
    end
  end

  describe "measure/2" do
    test "measures an extended knee at 180 degrees" do
      assert {:ok, result} = Measurement.measure(F.straight_knee_landmarks(), "left_knee")

      assert result.joint == "left_knee"
      assert result.angle_degrees == 180.0
      assert result.quality == :usable
      assert result.coordinate_system == :image_normalized
    end

    test "measures a flexed knee at 90 degrees" do
      assert {:ok, result} = Measurement.measure(F.bent_knee_landmarks(), "left_knee")

      assert result.angle_degrees == 90.0
    end

    test "works with world_3d landmarks" do
      landmarks = F.straight_knee_landmarks(coordinate_system: :world_3d)

      assert {:ok, result} = Measurement.measure(landmarks, "left_knee")
      assert result.coordinate_system == :world_3d
    end

    test "rejects landmarks below the visibility gate" do
      landmarks = F.straight_knee_landmarks(visibility: 0.3)

      assert Measurement.measure(landmarks, "left_knee") ==
               {:error, :insufficient_landmark_quality}
    end

    test "accepts landmarks with unknown visibility" do
      landmarks = F.straight_knee_landmarks(visibility: nil)

      assert {:ok, _result} = Measurement.measure(landmarks, "left_knee")
    end

    test "rejects missing landmarks" do
      landmarks = Map.delete(F.straight_knee_landmarks(), :left_ankle)

      assert Measurement.measure(landmarks, "left_knee") ==
               {:error, :insufficient_landmark_quality}
    end

    test "rejects mixed coordinate systems" do
      landmarks = %{
        left_hip: F.landmark(:left_hip, 0.5, 0.4),
        left_knee: F.landmark(:left_knee, 0.5, 0.6),
        left_ankle: F.landmark(:left_ankle, 0.5, 0.8, coordinate_system: :world_3d)
      }

      assert Measurement.measure(landmarks, "left_knee") ==
               {:error, :insufficient_landmark_quality}
    end

    test "reports unknown joints" do
      assert Measurement.measure(F.straight_knee_landmarks(), "left_tail") ==
               {:error, {:unknown_joint, "left_tail"}}
    end
  end

  describe "measure_all/1" do
    test "measures only the joints whose landmarks are present" do
      results = Measurement.measure_all(F.straight_knee_landmarks())

      assert Enum.map(results, &elem(&1, 0)) == ["left_ankle", "left_hip", "left_knee"]

      ok_joints = for {joint, {:ok, _result}} <- results, do: joint

      assert ok_joints == ["left_knee"]
      assert {"left_knee", {:ok, %{angle_degrees: 180.0}}} = List.keyfind(results, "left_knee", 0)
    end

    test "returns tuples in a stable joint order" do
      landmarks =
        Map.merge(F.straight_knee_landmarks(), %{
          left_elbow: F.landmark(:left_elbow, 0.3, 0.3),
          left_shoulder: F.landmark(:left_shoulder, 0.3, 0.2),
          left_wrist: F.landmark(:left_wrist, 0.3, 0.4)
        })

      names = landmarks |> Measurement.measure_all() |> Enum.map(&elem(&1, 0))

      assert names == Enum.sort(names)
      assert "left_elbow" in names
      assert "left_knee" in names
    end
  end

  describe "legacy joint helpers" do
    test "knee_flexion/2 returns a trimmed result map" do
      assert {:ok, result} = Measurement.knee_flexion(F.straight_knee_landmarks(), :left)

      assert result == %{joint: "left_knee", angle_degrees: 180.0, quality: :usable}
    end

    test "knee_flexion/2 fails cleanly for a side with no landmarks" do
      assert Measurement.knee_flexion(F.straight_knee_landmarks(), :right) ==
               {:error, :insufficient_landmark_quality}
    end
  end
end
