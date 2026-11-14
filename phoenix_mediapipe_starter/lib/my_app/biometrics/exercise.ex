defmodule MyApp.Biometrics.Exercise do
  @moduledoc """
  Rule-based gym / physio exercise recognition from joint range of motion.

  The classifier is deliberately transparent: each exercise has a ROM
  profile expressed as `{joint_group, min_degrees, max_degrees}` rules.
  Videos are scored against every profile and the ranked matches are
  returned with a confidence in `[0.0, 1.0]`.

  This is a *heuristic* recogniser, not a trained model. It is meant to
  pre-select candidate exercises for a clinician to confirm, and to give the
  LiveView something useful to display before any ML classifier exists.

  ## Example

      rom = %{"left_knee" => 92.0, "right_knee" => 88.0,
              "left_hip" => 61.0, "right_hip" => 58.0,
              "left_elbow" => 8.0}

      MyApp.Biometrics.Exercise.classify(rom)
      #=> [%{name: "squat", confidence: 1.0, ...}, ...]
  """

  @groups ~w(knee hip elbow shoulder ankle)

  # Out-of-range slack: each degree outside the window costs a little credit
  # until this many degrees away, after which the rule scores 0.
  @slack_degrees 30.0

  @profiles [
    %{
      name: "squat",
      description: "Bilateral knee and hip flexion in a closed chain.",
      rules: [{"knee", 35.0, 180.0}, {"hip", 20.0, 180.0}, {"elbow", 0.0, 45.0}],
      rep_thresholds: %{"knee" => {160.0, 100.0}, "hip" => {165.0, 110.0}}
    },
    %{
      name: "deadlift",
      description: "Hip-dominant hinge with a relatively stable knee.",
      rules: [{"hip", 40.0, 180.0}, {"knee", 10.0, 90.0}, {"elbow", 0.0, 30.0}],
      rep_thresholds: %{"hip" => {165.0, 100.0}, "knee" => {175.0, 140.0}}
    },
    %{
      name: "lunge",
      description: "Asymmetric split stance with one knee travelling further.",
      rules: [{:asymmetry, "knee", 12.0}, {"knee", 30.0, 180.0}, {"hip", 20.0, 180.0}],
      rep_thresholds: %{"knee" => {160.0, 95.0}}
    },
    %{
      name: "bicep_curl",
      description: "Isolated elbow flexion with a quiet lower body.",
      rules: [{"elbow", 50.0, 180.0}, {"knee", 0.0, 25.0}, {"hip", 0.0, 25.0}],
      rep_thresholds: %{"elbow" => {160.0, 50.0}}
    },
    %{
      name: "row",
      description: "Horizontal pull: elbow flexion from a hinged torso.",
      rules: [{"elbow", 40.0, 180.0}, {"hip", 0.0, 45.0}, {"knee", 0.0, 40.0}],
      rep_thresholds: %{"elbow" => {165.0, 60.0}}
    },
    %{
      name: "shoulder_press",
      description: "Overhead press: large shoulder range with elbow extension.",
      rules: [{"shoulder", 50.0, 180.0}, {"elbow", 30.0, 180.0}, {"knee", 0.0, 20.0}],
      rep_thresholds: %{"shoulder" => {40.0, 150.0}, "elbow" => {165.0, 60.0}}
    },
    %{
      name: "knee_extension",
      description: "Open-chain knee extension, typically seated.",
      rules: [{"knee", 30.0, 180.0}, {"hip", 0.0, 20.0}, {"elbow", 0.0, 25.0}],
      rep_thresholds: %{"knee" => {170.0, 110.0}}
    },
    %{
      name: "ankle_plantarflexion",
      description: "Calf raise / ankle pump with a quiet knee and hip.",
      rules: [{"ankle", 15.0, 180.0}, {"knee", 0.0, 25.0}, {"hip", 0.0, 20.0}],
      rep_thresholds: %{"ankle" => {95.0, 130.0}}
    }
  ]

  @doc """
  All exercise names known to the classifier.
  """
  def names, do: Enum.map(@profiles, & &1.name)

  @doc """
  Metadata for one exercise profile.
  """
  def profile(name) when is_binary(name) do
    Enum.find(@profiles, &(&1.name == name))
  end

  @doc """
  `{extended, flexed}` angle thresholds for `joint` within `exercise`, or
  `nil` when the exercise does not track that joint.

  Intended to build a `MyApp.Biometrics.RepDetector`:

      {ext, flex} = MyApp.Biometrics.Exercise.rep_thresholds("squat", "left_knee")
      MyApp.Biometrics.RepDetector.new(extended: ext, flexed: flex)
  """
  def rep_thresholds(exercise_name, joint) when is_binary(exercise_name) and is_binary(joint) do
    with %{rep_thresholds: thresholds} <- profile(exercise_name),
         group when is_binary(group) <- joint_group(joint),
         {extended, flexed} <- Map.get(thresholds, group) do
      {extended, flexed}
    else
      _ -> nil
    end
  end

  @default_rep_thresholds %{
    "knee" => {160.0, 100.0},
    "hip" => {165.0, 110.0},
    "elbow" => {160.0, 50.0},
    "shoulder" => {40.0, 150.0},
    "ankle" => {95.0, 130.0}
  }

  @doc """
  Exercise-agnostic `{extended, flexed}` thresholds for `joint`.

  Used by the analysis pipeline, which must count repetitions before the
  exercise itself has been recognised. Returns `nil` for unknown joints.
  """
  def default_rep_thresholds(joint) when is_binary(joint) do
    with group when is_binary(group) <- joint_group(joint),
         {extended, flexed} <- Map.get(@default_rep_thresholds, group) do
      {extended, flexed}
    else
      _ -> nil
    end
  end

  @doc """
  Classifies a movement from per-joint ROM.

  ## Arguments

    * `rom_by_joint` — map of joint name to ROM in degrees, e.g.
      `%{"left_knee" => 92.0, "right_knee" => 88.0}`. Joints with `nil` ROM
      are ignored.

  ## Options

    * `:min_confidence` — drop results below this score (default `0.5`)
    * `:limit` — maximum number of results (default `3`)

  Returns a list of maps sorted by descending confidence that include the
  exercise `:name`, its `:description`, the `:confidence` score, plus which
  rules `:matched` and which fell short in `:missing`.
  """
  def classify(rom_by_joint, opts \\ []) when is_map(rom_by_joint) do
    min_confidence = Keyword.get(opts, :min_confidence, 0.5)
    limit = Keyword.get(opts, :limit, 3)

    grouped = group(rom_by_joint)

    @profiles
    |> Enum.map(&score_profile(&1, grouped))
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&(&1.confidence >= min_confidence))
    |> Enum.sort_by(& &1.confidence, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Groups side-specific joints into side-agnostic groups, keeping every
  observed value: `%{"left_knee" => 92, "right_knee" => 88}` becomes
  `%{"knee" => [92.0, 88.0]}`.
  """
  def group(rom_by_joint) do
    Enum.reduce(rom_by_joint, %{}, fn
      {joint, rom}, acc when is_binary(joint) and is_number(rom) ->
        case joint_group(joint) do
          nil -> acc
          group -> Map.update(acc, group, [rom * 1.0], &[rom * 1.0 | &1])
        end

      _other, acc ->
        acc
    end)
  end

  @doc """
  Maps `"left_knee"` to `"knee"`. Returns `nil` for unknown joints.
  """
  def joint_group(joint) when is_binary(joint) do
    group = joint |> String.replace_prefix("left_", "") |> String.replace_prefix("right_", "")

    if group in @groups, do: group, else: nil
  end

  defp score_profile(profile, grouped) do
    evaluations =
      profile.rules
      |> Enum.map(fn rule ->
        case rule_credit(rule, grouped) do
          :missing -> nil
          {credit, subject} -> {credit, subject}
        end
      end)
      |> Enum.reject(&is_nil/1)

    case evaluations do
      [] ->
        nil

      hits ->
        confidence =
          hits
          |> Enum.map(fn {credit, _subject} -> credit end)
          |> mean()
          |> Float.round(2)

        %{
          name: profile.name,
          description: profile.description,
          confidence: confidence,
          matched: for({credit, subject} <- hits, credit >= 0.75, do: subject),
          missing: for({credit, subject} <- hits, credit < 0.75, do: subject)
        }
    end
  end

  defp rule_credit({:asymmetry, group, min_delta}, grouped) do
    case Map.get(grouped, group) do
      [_, _ | _] = values ->
        delta = Enum.max(values) - Enum.min(values)
        {credit_for(delta, min_delta, 180.0), "#{group}_asymmetry"}

      _ ->
        :missing
    end
  end

  defp rule_credit({group, min, max}, grouped) do
    case Map.get(grouped, group) do
      nil ->
        :missing

      values ->
        # Either side demonstrating the pattern is enough; a bilateral
        # movement shows the same range on both sides anyway.
        best = Enum.max(values)
        {credit_for(best, min, max), group}
    end
  end

  defp credit_for(value, min, max) do
    cond do
      value >= min and value <= max -> 1.0
      value < min -> max(0.0, 1.0 - (min - value) / @slack_degrees)
      true -> max(0.0, 1.0 - (value - max) / @slack_degrees)
    end
  end

  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)
end
