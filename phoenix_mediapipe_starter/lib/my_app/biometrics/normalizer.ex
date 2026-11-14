defmodule MyApp.Biometrics.Normalizer do
  @moduledoc "Maps MediaPipe's BlazePose 33-index order to canonical landmark names."
  alias MyApp.Biometrics.Landmark

  @names ~w(
    nose left_eye_inner left_eye left_eye_outer right_eye_inner right_eye
    right_eye_outer left_ear right_ear mouth_left mouth_right
    left_shoulder right_shoulder left_elbow right_elbow left_wrist right_wrist
    left_pinky right_pinky left_index right_index left_thumb right_thumb
    left_hip right_hip left_knee right_knee left_ankle right_ankle
    left_heel right_heel left_foot_index right_foot_index
  )

  def from_mediapipe(indexed, coordinate_system, timestamp_ms, model)
      when is_list(indexed) and coordinate_system in [:image_normalized, :world_3d] do
    indexed
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {point, index}, acc ->
      case Enum.at(@names, index) do
        nil -> acc
        name ->
          landmark = %Landmark{
            name: name,
            x: number(point, "x"),
            y: number(point, "y"),
            z: number(point, "z"),
            visibility: number(point, "visibility"),
            presence: number(point, "presence"),
            coordinate_system: coordinate_system,
            timestamp_ms: timestamp_ms,
            model: model
          }

          if is_number(landmark.x) and is_number(landmark.y),
            do: Map.put(acc, String.to_atom(name), landmark),
            else: acc
      end
    end)
  end

  defp number(map, key) when is_map(map), do: Map.get(map, key)
  defp number(_, _), do: nil
end
