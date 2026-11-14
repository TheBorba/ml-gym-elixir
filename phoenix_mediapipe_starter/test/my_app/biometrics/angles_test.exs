defmodule MyApp.Biometrics.AnglesTest do
  use ExUnit.Case, async: true

  alias MyApp.Biometrics.Angles
  alias MyApp.PoseFixtures, as: F

  describe "calculate/3" do
    test "returns 90 for a right angle" do
      a = F.landmark(:a, 1.0, 0.0)
      b = F.landmark(:b, 0.0, 0.0)
      c = F.landmark(:c, 0.0, 1.0)

      assert Angles.calculate(a, b, c) == 90.0
    end

    test "returns 180 for collinear points with B in the middle" do
      a = F.landmark(:a, 0.0, 1.0)
      b = F.landmark(:b, 0.0, 0.0)
      c = F.landmark(:c, 0.0, -1.0)

      assert Angles.calculate(a, b, c) == 180.0
    end

    test "returns 0 for coincident segments" do
      a = F.landmark(:a, 1.0, 1.0)
      b = F.landmark(:b, 0.0, 0.0)
      c = F.landmark(:c, 1.0, 1.0)

      assert Angles.calculate(a, b, c) == 0.0
    end

    test "returns 45 for an isosceles corner" do
      a = F.landmark(:a, 1.0, 0.0)
      b = F.landmark(:b, 0.0, 0.0)
      c = F.landmark(:c, 1.0, 1.0)

      assert Angles.calculate(a, b, c) == 45.0
    end

    test "returns nil when two points coincide" do
      a = F.landmark(:a, 0.5, 0.5)
      b = F.landmark(:b, 0.5, 0.5)
      c = F.landmark(:c, 0.9, 0.9)

      assert Angles.calculate(a, b, c) == nil
    end

    test "returns nil when coordinate systems are mixed" do
      a = F.landmark(:a, 1.0, 0.0, coordinate_system: :world_3d)
      b = F.landmark(:b, 0.0, 0.0, coordinate_system: :world_3d)
      c = F.landmark(:c, 0.0, 1.0, coordinate_system: :image_normalized)

      assert Angles.calculate(a, b, c) == nil
    end

    test "uses the z coordinate for world_3d landmarks" do
      a = F.landmark(:a, 0.0, 0.0, z: 1.0, coordinate_system: :world_3d)
      b = F.landmark(:b, 0.0, 0.0, z: 0.0, coordinate_system: :world_3d)
      c = F.landmark(:c, 1.0, 0.0, z: 0.0, coordinate_system: :world_3d)

      assert Angles.calculate(a, b, c) == 90.0
    end

    test "returns nil for non-landmark input" do
      assert Angles.calculate(nil, nil, nil) == nil
    end
  end
end
