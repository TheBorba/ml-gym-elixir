defmodule MyApp.Biometrics.RepDetector do
  @moduledoc """
  Two-threshold repetition state machine with hysteresis.

  A repetition is counted when the joint travels from the *extended*
  position into the *flexed* position and back out again. Two distinct
  thresholds (instead of one) prevent jitter around a single boundary from
  inflating the count.

  The direction is inferred from the thresholds:

    * `extended > flexed` — flexion *decreases* the angle (knee, elbow, hip)
    * `extended < flexed` — flexion *increases* the angle (shoulder)

  ## Example

      detector =
        MyApp.Biometrics.RepDetector.new(extended: 160.0, flexed: 100.0)

      detector =
        Enum.reduce([178.0, 150.0, 96.0, 120.0, 175.0], detector,
          &MyApp.Biometrics.RepDetector.add(&2, &1))

      detector.count
      #=> 1
  """

  @enforce_keys [:extended, :flexed]
  defstruct extended: nil,
            flexed: nil,
            mode: :decreasing,
            state: :unknown,
            count: 0,
            min_angle: nil,
            max_angle: nil,
            last_angle: nil

  @type state :: :unknown | :extended | :flexed
  @type t :: %__MODULE__{}

  @doc """
  Creates a detector.

  ## Options

    * `:extended` (required) — angle considered fully extended
    * `:flexed` (required) — angle considered fully flexed

  Thresholds must differ; equal values would make the state machine flap.
  """
  def new(opts) do
    extended = Keyword.fetch!(opts, :extended) * 1.0
    flexed = Keyword.fetch!(opts, :flexed) * 1.0

    if extended == flexed do
      raise ArgumentError, ":extended and :flexed thresholds must differ"
    end

    %__MODULE__{
      extended: extended,
      flexed: flexed,
      mode: if(extended > flexed, do: :decreasing, else: :increasing)
    }
  end

  @doc """
  Feeds one angle sample into the state machine.

  `nil` and non-numeric samples are ignored and return the detector unchanged.
  """
  def add(%__MODULE__{} = det, angle) when is_number(angle) do
    angle = angle * 1.0

    det = %__MODULE__{
      det
      | last_angle: angle,
        min_angle: track_min(det.min_angle, angle),
        max_angle: track_max(det.max_angle, angle)
    }

    cond do
      det.state == :unknown and extended?(det, angle) ->
        %__MODULE__{det | state: :extended}

      det.state == :unknown and flexed?(det, angle) ->
        %__MODULE__{det | state: :flexed}

      det.state == :extended and flexed?(det, angle) ->
        %__MODULE__{det | state: :flexed}

      # Completing a repetition: flexed -> extended.
      det.state == :flexed and extended?(det, angle) ->
        %__MODULE__{det | state: :extended, count: det.count + 1}

      true ->
        det
    end
  end

  def add(%__MODULE__{} = det, _angle), do: det

  @doc """
  Number of complete repetitions observed.
  """
  def count(%__MODULE__{count: count}), do: count

  @doc """
  Deepest flexion angle observed (minimum for decreasing joints, maximum for
  increasing joints). `nil` when no samples were added.
  """
  def peak_flexion(%__MODULE__{mode: :decreasing, min_angle: min}), do: min
  def peak_flexion(%__MODULE__{mode: :increasing, max_angle: max}), do: max

  @doc """
  Plain map summary suitable for logging or persistence.
  """
  def summary(%__MODULE__{} = det) do
    %{
      repetitions: det.count,
      peak_flexion: peak_flexion(det),
      min_angle: det.min_angle,
      max_angle: det.max_angle
    }
  end

  defp extended?(%__MODULE__{mode: :decreasing, extended: t}, angle), do: angle >= t
  defp extended?(%__MODULE__{mode: :increasing, extended: t}, angle), do: angle <= t

  defp flexed?(%__MODULE__{mode: :decreasing, flexed: t}, angle), do: angle <= t
  defp flexed?(%__MODULE__{mode: :increasing, flexed: t}, angle), do: angle >= t

  defp track_min(nil, value), do: value
  defp track_min(current, value), do: min(current, value)

  defp track_max(nil, value), do: value
  defp track_max(current, value), do: max(current, value)
end
