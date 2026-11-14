defmodule MyApp.Biometrics.RepDetectorTest do
  use ExUnit.Case, async: true

  alias MyApp.Biometrics.RepDetector

  defp feed(detector, angles) do
    Enum.reduce(angles, detector, fn angle, acc -> RepDetector.add(acc, angle) end)
  end

  describe "decreasing joints (knee, elbow, hip)" do
    test "counts one repetition for a full down-and-up cycle" do
      detector =
        RepDetector.new(extended: 160.0, flexed: 100.0)
        |> feed([178.0, 150.0, 96.0, 120.0, 175.0])

      assert RepDetector.count(detector) == 1
    end

    test "counts two repetitions" do
      detector =
        RepDetector.new(extended: 160.0, flexed: 100.0)
        |> feed([175.0, 95.0, 175.0, 95.0, 175.0])

      assert RepDetector.count(detector) == 2
    end

    test "does not count an incomplete repetition" do
      detector =
        RepDetector.new(extended: 160.0, flexed: 100.0)
        |> feed([175.0, 120.0, 130.0, 125.0])

      assert RepDetector.count(detector) == 0
    end

    test "hysteresis prevents jitter around a single threshold from inflating the count" do
      detector =
        RepDetector.new(extended: 160.0, flexed: 100.0)
        |> feed([175.0, 158.0, 162.0, 155.0, 161.0, 159.0, 175.0])

      assert RepDetector.count(detector) == 0
    end

    test "ignores nil samples" do
      detector =
        RepDetector.new(extended: 160.0, flexed: 100.0)
        |> feed([175.0, nil, 95.0, nil, 175.0])

      assert RepDetector.count(detector) == 1
    end
  end

  describe "increasing joints (shoulder)" do
    test "counts one repetition when the angle grows past flexed" do
      detector =
        RepDetector.new(extended: 40.0, flexed: 150.0)
        |> feed([20.0, 80.0, 160.0, 90.0, 25.0])

      assert RepDetector.count(detector) == 1
      assert RepDetector.peak_flexion(detector) == 160.0
    end
  end

  describe "peak_flexion/1" do
    test "is the minimum angle for decreasing joints" do
      detector =
        RepDetector.new(extended: 160.0, flexed: 100.0)
        |> feed([178.0, 88.0, 175.0])

      assert RepDetector.peak_flexion(detector) == 88.0
    end

    test "is nil when no samples were added" do
      assert RepDetector.peak_flexion(RepDetector.new(extended: 160.0, flexed: 100.0)) == nil
    end
  end

  describe "new/1" do
    test "raises when thresholds are equal" do
      assert_raise ArgumentError, fn -> RepDetector.new(extended: 120.0, flexed: 120.0) end
    end

    test "raises when a threshold is missing" do
      assert_raise KeyError, fn -> RepDetector.new(extended: 120.0) end
    end
  end

  describe "summary/1" do
    test "reports repetitions and the angle envelope" do
      detector =
        RepDetector.new(extended: 160.0, flexed: 100.0)
        |> feed([178.0, 96.0, 175.0])

      summary = RepDetector.summary(detector)

      assert summary.repetitions == 1
      assert summary.peak_flexion == 96.0
      assert summary.min_angle == 96.0
      assert summary.max_angle == 178.0
    end
  end
end
