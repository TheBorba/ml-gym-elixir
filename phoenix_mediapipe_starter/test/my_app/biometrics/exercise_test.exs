defmodule MyApp.Biometrics.ExerciseTest do
  use ExUnit.Case, async: true

  alias MyApp.Biometrics.Exercise

  # Knee + hip dominant flexion with quiet arms: a squat.
  @squat_rom %{
    "left_knee" => 92.0,
    "right_knee" => 88.0,
    "left_hip" => 61.0,
    "right_hip" => 58.0,
    "left_elbow" => 8.0
  }

  describe "names/0 and profile/1" do
    test "exposes every known exercise" do
      names = Exercise.names()

      assert length(names) == 8
      assert "squat" in names
      assert "deadlift" in names
      assert "bicep_curl" in names
    end

    test "returns metadata for a known exercise" do
      assert %{name: "squat", description: description} = Exercise.profile("squat")
      assert is_binary(description)
    end

    test "returns nil for an unknown exercise" do
      assert Exercise.profile("burpee") == nil
    end
  end

  describe "group/1" do
    test "collapses sides into a side-agnostic group" do
      grouped = Exercise.group(%{"left_knee" => 92, "right_knee" => 88})

      assert Map.keys(grouped) == ["knee"]
      assert Enum.sort(grouped["knee"]) == [88.0, 92.0]
    end

    test "drops joints outside the supported groups and nil ROM" do
      grouped = Exercise.group(%{"nose" => 10.0, "left_knee" => nil, "left_hip" => 40.0})

      assert grouped == %{"hip" => [40.0]}
    end
  end

  describe "joint_group/1" do
    test "strips the side prefix" do
      assert Exercise.joint_group("left_knee") == "knee"
      assert Exercise.joint_group("right_shoulder") == "shoulder"
    end

    test "returns nil for unsupported joints" do
      assert Exercise.joint_group("nose") == nil
      assert Exercise.joint_group("left_toes") == nil
    end
  end

  describe "classify/2" do
    test "recognises a squat from knee and hip ROM" do
      assert [%{name: "squat", confidence: 1.0} | _rest] = Exercise.classify(@squat_rom)
    end

    test "ranks an elbow-dominant movement as a curl or row" do
      rom = %{"left_elbow" => 95.0, "left_knee" => 5.0, "left_hip" => 5.0}

      [best | _rest] = Exercise.classify(rom)

      assert best.confidence == 1.0
      assert best.name in ["bicep_curl", "row"]
    end

    test "returns an empty list when no ROM data matches" do
      assert Exercise.classify(%{}) == []
      assert Exercise.classify(%{"left_knee" => nil}) == []
    end

    test "honours :limit" do
      assert length(Exercise.classify(@squat_rom, limit: 1)) == 1
    end

    test "honours :min_confidence" do
      assert Exercise.classify(@squat_rom, min_confidence: 1.01) == []
    end

    test "reports which rules matched" do
      [squat | _rest] = Exercise.classify(@squat_rom)

      assert "knee" in squat.matched
      assert "hip" in squat.matched
      assert squat.missing == []
    end
  end

  describe "rep thresholds" do
    test "default_rep_thresholds/1 is exercise agnostic" do
      assert Exercise.default_rep_thresholds("left_knee") == {160.0, 100.0}
      assert Exercise.default_rep_thresholds("right_shoulder") == {40.0, 150.0}
      assert Exercise.default_rep_thresholds("nose") == nil
    end

    test "rep_thresholds/2 follows the exercise profile" do
      assert Exercise.rep_thresholds("squat", "left_knee") == {160.0, 100.0}
      assert Exercise.rep_thresholds("squat", "left_ankle") == nil
      assert Exercise.rep_thresholds("burpee", "left_knee") == nil
    end
  end
end
