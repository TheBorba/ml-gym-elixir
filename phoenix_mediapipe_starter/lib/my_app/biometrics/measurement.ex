defmodule MyApp.Biometrics.Measurement do
  @moduledoc """
  Shared biomechanics entry point used by the webcam LiveView, the channel
  and the MP4 `AnalysisWorker`.

  Angles are *interior* angles in degrees between the two segments meeting at
  the joint's vertex landmark:

  | joint            | vertex      | segments                       | extended | flexed |
  |------------------|-------------|--------------------------------|----------|--------|
  | `left_knee`      | left knee   | hip → knee, ankle ← knee       | ~180°    | ~90°   |
  | `left_elbow`     | elbow       | shoulder → elbow, wrist ← elbow| ~180°    | ~40°   |
  | `left_hip`       | hip         | shoulder → hip, knee ← hip     | ~180°    | ~90°   |
  | `left_shoulder`  | shoulder    | elbow → shoulder, hip ← shoulder| ~10°    | ~170°  |
  | `left_ankle`     | ankle       | knee → ankle, foot ← ankle     | ~90°     | ~110°  |

  All three landmarks in a triple must share the same coordinate system;
  `MyApp.Biometrics.Angles.calculate/3` enforces this and returns `nil`
  otherwise.
  """

  alias MyApp.Biometrics.Angles

  @minimum_visibility 0.65

  @joints %{
    "left_elbow" => {:left_shoulder, :left_elbow, :left_wrist},
    "right_elbow" => {:right_shoulder, :right_elbow, :right_wrist},
    "left_shoulder" => {:left_elbow, :left_shoulder, :left_hip},
    "right_shoulder" => {:right_elbow, :right_shoulder, :right_hip},
    "left_hip" => {:left_shoulder, :left_hip, :left_knee},
    "right_hip" => {:right_shoulder, :right_hip, :right_knee},
    "left_knee" => {:left_hip, :left_knee, :left_ankle},
    "right_knee" => {:right_hip, :right_knee, :right_ankle},
    "left_ankle" => {:left_knee, :left_ankle, :left_foot_index},
    "right_ankle" => {:right_knee, :right_ankle, :right_foot_index}
  }

  @doc """
  All supported joint names, e.g. `"left_knee"`.
  """
  def joints, do: Map.keys(@joints)

  @doc """
  Measures a single joint by name.

  Returns `{:ok, map}` with `:joint`, `:angle_degrees`, `:quality` and
  `:coordinate_system`, or `{:error, :insufficient_landmark_quality}`.

      iex> MyApp.Biometrics.Measurement.measure(landmarks, "left_knee")
      {:ok, %{joint: "left_knee", angle_degrees: 174.2, quality: :usable,
              coordinate_system: :world_3d}}
  """
  def measure(landmarks, joint) when is_map(landmarks) and is_binary(joint) do
    case Map.fetch(@joints, joint) do
      {:ok, {a, b, c}} ->
        with [la, lb, lc] <- Enum.map([a, b, c], &Map.get(landmarks, &1)),
             true <- Enum.all?([la, lb, lc], &usable?/1),
             angle when is_number(angle) <- Angles.calculate(la, lb, lc) do
          {:ok,
           %{
             joint: joint,
             angle_degrees: angle,
             quality: :usable,
             coordinate_system: lb.coordinate_system
           }}
        else
          _ -> {:error, :insufficient_landmark_quality}
        end

      :error ->
        {:error, {:unknown_joint, joint}}
    end
  end

  @doc """
  Measures every supported joint that has usable landmarks.

  Returns a list of `{:ok, map}` / `{:error, reason}` tuples in a stable
  joint order.
  """
  def measure_all(landmarks) when is_map(landmarks) do
    landmarks
    |> Map.keys()
    |> Enum.filter(&is_atom/1)
    |> Enum.map(&Atom.to_string/1)
    |> Enum.filter(&Map.has_key?(@joints, &1))
    |> Enum.sort()
    |> Enum.map(&{&1, measure(landmarks, &1)})
  end

  @doc """
  Elbow flexion / extension angle for the given side.
  """
  def elbow_flexion(landmarks, side \\ :left) when side in [:left, :right] do
    legacy_result(landmarks, "#{side}_elbow")
  end

  @doc """
  Knee flexion / extension angle for the given side.
  """
  def knee_flexion(landmarks, side \\ :left) when side in [:left, :right] do
    legacy_result(landmarks, "#{side}_knee")
  end

  @doc """
  Hip flexion angle for the given side.
  """
  def hip_flexion(landmarks, side \\ :left) when side in [:left, :right] do
    legacy_result(landmarks, "#{side}_hip")
  end

  @doc """
  Shoulder angle for the given side.
  """
  def shoulder_angle(landmarks, side \\ :left) when side in [:left, :right] do
    legacy_result(landmarks, "#{side}_shoulder")
  end

  defp legacy_result(landmarks, joint) do
    case measure(landmarks, joint) do
      {:ok, result} ->
        {:ok, %{joint: joint, angle_degrees: result.angle_degrees, quality: result.quality}}

      {:error, _} ->
        {:error, :insufficient_landmark_quality}
    end
  end

  defp usable?(nil), do: false

  defp usable?(landmark) do
    is_nil(landmark.visibility) or landmark.visibility >= @minimum_visibility
  end
end

