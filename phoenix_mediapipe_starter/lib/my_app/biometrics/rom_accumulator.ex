defmodule MyApp.Biometrics.RomAccumulator do
  @moduledoc """
  Running range-of-motion accumulator for a single joint.

  ROM is the angular travel of a joint: `max_angle - min_angle` over a sample
  window. The accumulator is a plain data structure with pure functions so it
  can be used identically from the web worker pipeline, the MP4 worker and
  tests.

  Only samples with a numeric angle are considered; `nil` (failed quality
  gate) is ignored rather than treated as zero.

  ## Example

      acc =
        MyApp.Biometrics.RomAccumulator.new("left_knee", :world_3d)
        |> MyApp.Biometrics.RomAccumulator.add(178.0)
        |> MyApp.Biometrics.RomAccumulator.add(94.5)
        |> MyApp.Biometrics.RomAccumulator.add(120.0)

      MyApp.Biometrics.RomAccumulator.summary(acc)
      #=> %{joint: "left_knee", coordinate_system: :world_3d, sample_count: 3,
      #     min_angle: 94.5, max_angle: 178.0, rom_degrees: 83.5}
  """

  @enforce_keys [:joint, :coordinate_system]
  defstruct joint: nil,
            coordinate_system: nil,
            sample_count: 0,
            min_angle: nil,
            max_angle: nil

  @type t :: %__MODULE__{
          joint: String.t(),
          coordinate_system: :image_normalized | :world_3d,
          sample_count: non_neg_integer(),
          min_angle: float() | nil,
          max_angle: float() | nil
        }

  @doc """
  Creates an empty accumulator for `joint` measured in `coordinate_system`.
  """
  def new(joint, coordinate_system)
      when is_binary(joint) and coordinate_system in [:image_normalized, :world_3d] do
    %__MODULE__{joint: joint, coordinate_system: coordinate_system}
  end

  @doc """
  Adds one angle sample. `nil` and non-numeric values are ignored.
  """
  def add(%__MODULE__{} = acc, angle) when is_number(angle) do
    %__MODULE__{
      acc
      | sample_count: acc.sample_count + 1,
        min_angle: min_or(acc.min_angle, angle * 1.0),
        max_angle: max_or(acc.max_angle, angle * 1.0)
    }
  end

  def add(%__MODULE__{} = acc, _angle), do: acc

  @doc """
  Merges two accumulators for the same joint and coordinate system.
  """
  def merge(%__MODULE__{joint: joint, coordinate_system: cs} = left, %__MODULE__{
        joint: joint,
        coordinate_system: cs
      } = right) do
    %__MODULE__{
      left
      | sample_count: left.sample_count + right.sample_count,
        min_angle: min_or(left.min_angle, right.min_angle),
        max_angle: max_or(left.max_angle, right.max_angle)
    }
  end

  @doc """
  Angular travel in degrees, or `nil` when fewer than two distinct samples
  were observed.
  """
  def rom(%__MODULE__{sample_count: count}) when count < 2, do: nil

  def rom(%__MODULE__{min_angle: min, max_angle: max})
      when is_number(min) and is_number(max) do
    Float.round(max - min, 2)
  end

  def rom(%__MODULE__{}), do: nil

  @doc """
  Converts the accumulator into a plain map, ready to be persisted as a
  `MyApp.RomResult`.
  """
  def summary(%__MODULE__{} = acc) do
    %{
      joint: acc.joint,
      coordinate_system: acc.coordinate_system,
      sample_count: acc.sample_count,
      min_angle: acc.min_angle,
      max_angle: acc.max_angle,
      rom_degrees: rom(acc)
    }
  end

  defp min_or(nil, value), do: value
  defp min_or(current, value), do: min(current, value)

  defp max_or(nil, value), do: value
  defp max_or(current, value), do: max(current, value)
end
