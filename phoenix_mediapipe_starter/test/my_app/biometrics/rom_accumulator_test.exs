defmodule MyApp.Biometrics.RomAccumulatorTest do
  use ExUnit.Case, async: true

  alias MyApp.Biometrics.RomAccumulator

  describe "new/2" do
    test "starts empty" do
      acc = RomAccumulator.new("left_knee", :world_3d)

      assert acc.joint == "left_knee"
      assert acc.coordinate_system == :world_3d
      assert acc.sample_count == 0
      assert acc.min_angle == nil
      assert acc.max_angle == nil
    end
  end

  describe "add/2" do
    test "tracks the running min and max" do
      acc =
        RomAccumulator.new("left_knee", :world_3d)
        |> RomAccumulator.add(120.0)
        |> RomAccumulator.add(94.5)
        |> RomAccumulator.add(178.0)

      assert acc.sample_count == 3
      assert acc.min_angle == 94.5
      assert acc.max_angle == 178.0
    end

    test "ignores nil and non-numeric samples" do
      acc =
        RomAccumulator.new("left_knee", :world_3d)
        |> RomAccumulator.add(nil)
        |> RomAccumulator.add(:nope)

      assert acc.sample_count == 0
      assert RomAccumulator.rom(acc) == nil
    end

    test "accepts integer angles" do
      acc = RomAccumulator.new("left_knee", :world_3d) |> RomAccumulator.add(90)

      assert acc.min_angle == 90.0
      assert acc.max_angle == 90.0
    end
  end

  describe "rom/1" do
    test "is nil with fewer than two samples" do
      acc = RomAccumulator.new("left_knee", :world_3d) |> RomAccumulator.add(150.0)

      assert RomAccumulator.rom(acc) == nil
    end

    test "is max minus min, rounded to two decimals" do
      acc =
        RomAccumulator.new("left_knee", :world_3d)
        |> RomAccumulator.add(178.0)
        |> RomAccumulator.add(94.5)
        |> RomAccumulator.add(120.0)

      assert RomAccumulator.rom(acc) == 83.5
    end
  end

  describe "merge/2" do
    test "combines two windows of the same joint" do
      first = RomAccumulator.new("left_knee", :world_3d) |> RomAccumulator.add(170.0)
      second = RomAccumulator.new("left_knee", :world_3d) |> RomAccumulator.add(95.0)

      merged = RomAccumulator.merge(first, second)

      assert merged.sample_count == 2
      assert RomAccumulator.rom(merged) == 75.0
    end

    test "returns {:error, :mismatched_joint_or_coordinate_system} on mismatch" do
      knee = RomAccumulator.new("left_knee", :world_3d)
      hip = RomAccumulator.new("left_hip", :world_3d)
      image = RomAccumulator.new("left_knee", :image_normalized)

      assert RomAccumulator.merge(knee, hip) == {:error, :mismatched_joint_or_coordinate_system}
      assert RomAccumulator.merge(knee, image) == {:error, :mismatched_joint_or_coordinate_system}
    end
  end

  describe "summary/1" do
    test "returns a persistable map" do
      summary =
        RomAccumulator.new("left_knee", :world_3d)
        |> RomAccumulator.add(178.0)
        |> RomAccumulator.add(94.5)
        |> RomAccumulator.summary()

      assert summary == %{
               joint: "left_knee",
               coordinate_system: :world_3d,
               sample_count: 2,
               min_angle: 94.5,
               max_angle: 178.0,
               rom_degrees: 83.5
             }
    end
  end
end
