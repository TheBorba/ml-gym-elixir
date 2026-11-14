defmodule MyApp.VideoAnalysis.AnalysisWorker do
  @moduledoc """
  Oban job that turns an uploaded MP4 into persisted landmarks, per-frame
  joint angles, ROM summaries and a recognised exercise.

  ## Pipeline

    1. Mark the `MyApp.Analysis` row `processing`
    2. Stream newline-delimited JSON from the Python worker via
       `MyApp.VideoAnalysis.PythonPort` (which runs the MediaPipe venv baked
       into the application container)
    3. Convert each frame's landmarks into canonical `Landmark` structs for
       both coordinate systems (`image_normalized` and `world_3d`) — the two
       are always kept separate
    4. Measure every supported joint and feed the angles into a
       `RomAccumulator` and a `RepDetector` per `{joint, coordinate_system}`
    5. Flush frames and measurements to Postgres in bounded batches so a long
       video never has to fit in memory
    6. Write `RomResult` rows, classify the exercise and mark the analysis
       `completed`

  ## Caveat

  These angles are heuristic estimates from a single monocular camera. They
  must be validated against a calibrated reference instrument before any
  clinical use.
  """

  use Oban.Worker, queue: :video_analysis, max_attempts: 2

  require Logger

  alias MyApp.Biometrics.{Exercise, Normalizer, RepDetector, RomAccumulator}
  alias MyApp.Biometrics.Measurement, as: Joint
  alias MyApp.{Analysis, Frame, Repo, RomResult}
  alias MyApp.Measurement, as: MeasurementRecord
  alias MyApp.VideoAnalysis.PythonPort

  @image :image_normalized
  @world :world_3d

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    case fetch_analysis(args) do
      {:ok, analysis} ->
        analysis
        |> Analysis.status_changeset("processing", started_at: now())
        |> Repo.update!()

        run(analysis, worker_opts(analysis))

      {:error, reason} ->
        {:cancel, reason}
    end
  end

  defp fetch_analysis(args) do
    case Map.get(args, "analysis_id") do
      nil ->
        {:error, :missing_analysis_id}

      id ->
        case Repo.get(Analysis, id) do
          nil -> {:error, :analysis_not_found}
          analysis -> {:ok, analysis}
        end
    end
  end

  defp worker_opts(analysis) do
    config = Application.get_env(:my_app, PythonPort, [])

    [
      sample_fps: analysis.sample_fps || config[:sample_fps] || 12,
      batch_size: config[:batch_size] || 200
    ]
  end

  defp run(analysis, opts) do
    do_run(analysis, opts)
  rescue
    error ->
      fail(analysis, Exception.format(:error, error, __STACKTRACE__))
  catch
    kind, reason ->
      fail(analysis, "worker crashed: #{inspect({kind, reason})}")
  end

  defp do_run(analysis, opts) do
    {:ok, agent} = Agent.start_link(fn -> empty_state() end)

    try do
      callback = fn record ->
        consume(agent, analysis, record, Keyword.fetch!(opts, :batch_size))
        :drop
      end

      case PythonPort.stream(analysis.video_path, analysis.model_path, callback, opts) do
        {:ok, _record_count, _kept} ->
          state = agent |> Agent.get(& &1) |> flush(analysis)
          {:ok, finalize(analysis, state)}

        {:error, reason} ->
          fail(analysis, "python worker failed: #{inspect(reason)}")
      end
    after
      Agent.stop(agent)
    end
  end

  # ------------------------------------------------------------------
  # Streaming state
  # ------------------------------------------------------------------

  defp empty_state do
    %{buffer: [], rom: %{}, reps: %{}, meta: %{}, persisted: 0}
  end

  defp consume(agent, analysis, %{"type" => "frame"} = record, batch_size) do
    Agent.update(agent, fn state ->
      state = buffer_frame(state, record)

      if length(state.buffer) >= batch_size do
        flush(state, analysis)
      else
        state
      end
    end)
  end

  defp consume(agent, _analysis, %{"type" => "complete"} = record, _batch_size) do
    Agent.update(agent, &%{&1 | meta: record})
  end

  defp consume(_agent, _analysis, _record, _batch_size), do: :ok

  defp buffer_frame(state, record) do
    timestamp_ms = record["timestamp_ms"] || 0
    image_points = record["image_landmarks"] || []
    world_points = record["world_landmarks"] || []

    image = Normalizer.from_mediapipe(image_points, @image, timestamp_ms, "mp4")
    world = Normalizer.from_mediapipe(world_points, @world, timestamp_ms, "mp4")

    measurements =
      measurements_for(image, timestamp_ms) ++ measurements_for(world, timestamp_ms)

    {rom, reps} =
      Enum.reduce(measurements, {state.rom, state.reps}, fn measurement, {rom, reps} ->
        key = {measurement.joint, measurement.coordinate_system}
        rom = accumulate_rom(rom, key, measurement.angle_degrees)
        {rom, accumulate_reps(reps, key, measurement.joint, measurement.angle_degrees)}
      end)

    entry = %{
      frame: %{
        frame_index: record["frame_index"],
        timestamp_ms: timestamp_ms,
        image_landmarks: image_points,
        world_landmarks: world_points
      },
      measurements: measurements
    }

    %{state | buffer: [entry | state.buffer], rom: rom, reps: reps}
  end

  defp measurements_for(landmarks, _timestamp_ms) when map_size(landmarks) == 0, do: []

  defp measurements_for(landmarks, timestamp_ms) do
    Enum.flat_map(Joint.joints(), fn joint ->
      case Joint.measure(landmarks, joint) do
        {:ok, %{angle_degrees: angle, coordinate_system: coordinate_system}} ->
          [
            %{
              joint: joint,
              angle_degrees: angle,
              coordinate_system: coordinate_system,
              quality: "usable",
              timestamp_ms: timestamp_ms
            }
          ]

        {:error, _reason} ->
          []
      end
    end)
  end

  defp accumulate_rom(rom, {joint, coordinate_system} = key, angle) do
    accumulator = Map.get_lazy(rom, key, fn -> RomAccumulator.new(joint, coordinate_system) end)
    Map.put(rom, key, RomAccumulator.add(accumulator, angle))
  end

  defp accumulate_reps(reps, key, joint, angle) do
    detector =
      case Map.get(reps, key) do
        nil -> build_detector(joint)
        detector -> detector
      end

    case detector do
      nil -> reps
      detector -> Map.put(reps, key, RepDetector.add(detector, angle))
    end
  end

  defp build_detector(joint) do
    case Exercise.default_rep_thresholds(joint) do
      {extended, flexed} -> RepDetector.new(extended: extended, flexed: flexed)
      nil -> nil
    end
  end

  # ------------------------------------------------------------------
  # Persistence
  # ------------------------------------------------------------------

  defp flush(%{buffer: []} = state, _analysis), do: state

  defp flush(state, analysis) do
    timestamp = now()
    entries = Enum.reverse(state.buffer)

    frame_rows =
      Enum.map(entries, fn %{frame: frame} ->
        Map.merge(frame, %{analysis_id: analysis.id, inserted_at: timestamp})
      end)

    # `insert_all/3` returns `{count, rows}` — the returned rows carry the
    # generated ids we need to link measurements to their frame.
    {_count, inserted} =
      Repo.insert_all(Frame, frame_rows,
        on_conflict: :nothing,
        conflict_target: [:analysis_id, :frame_index],
        returning: [:id, :frame_index]
      )

    frame_id_by_index = Map.new(inserted, fn row -> {row.frame_index, row.id} end)

    measurement_rows =
      for entry <- entries,
          measurement <- entry.measurements,
          frame_id = Map.get(frame_id_by_index, entry.frame.frame_index),
          not is_nil(frame_id) do
        %{
          analysis_id: analysis.id,
          frame_id: frame_id,
          joint: measurement.joint,
          coordinate_system: Atom.to_string(measurement.coordinate_system),
          quality: measurement.quality,
          angle_degrees: measurement.angle_degrees,
          timestamp_ms: measurement.timestamp_ms,
          inserted_at: timestamp
        }
      end

    if measurement_rows != [] do
      Repo.insert_all(MeasurementRecord, measurement_rows)
    end

    %{state | buffer: [], persisted: state.persisted + length(entries)}
  end

  defp finalize(analysis, state) do
    timestamp = now()
    rom_rows = rom_rows(analysis, state)

    if rom_rows != [] do
      Repo.insert_all(RomResult, rom_rows,
        on_conflict: :replace_all,
        conflict_target: [:analysis_id, :joint, :coordinate_system]
      )
    end

    rom_by_joint = rom_by_joint(state)
    exercises = Exercise.classify(rom_by_joint)

    analysis
    |> Analysis.status_changeset("completed",
      processed_frames: state.persisted,
      source_fps: number(state.meta["source_fps"]),
      source_frames: integer(state.meta["source_frames"]),
      finished_at: timestamp
    )
    |> Repo.update!()

    summary = %{
      analysis_id: analysis.id,
      processed_frames: state.persisted,
      rom_by_joint: rom_by_joint,
      exercises: exercises
    }

    Phoenix.PubSub.broadcast(MyApp.PubSub, topic(analysis.id), {:analysis_completed, summary})

    Logger.info(
      "analysis #{analysis.id} completed: #{state.persisted} frames, " <>
        "exercises=#{inspect(Enum.map(exercises, & &1.name))}"
    )

    summary
  end

  defp rom_rows(analysis, state) do
    timestamp = now()

    for {{joint, coordinate_system}, accumulator} <- state.rom do
      summary = RomAccumulator.summary(accumulator)
      detector = Map.get(state.reps, {joint, coordinate_system})

      %{
        analysis_id: analysis.id,
        joint: joint,
        coordinate_system: Atom.to_string(coordinate_system),
        sample_count: summary.sample_count,
        min_angle: summary.min_angle,
        max_angle: summary.max_angle,
        rom_degrees: summary.rom_degrees,
        repetitions: if(detector, do: RepDetector.count(detector), else: 0),
        inserted_at: timestamp,
        updated_at: timestamp
      }
    end
  end

  # World coordinates describe the movement in meters and are preferred for
  # ROM. Fall back to image coordinates when MediaPipe produced no world
  # landmarks for this video.
  defp rom_by_joint(state) do
    case rom_map(state, @world) do
      map when map_size(map) == 0 -> rom_map(state, @image)
      map -> map
    end
  end

  defp rom_map(state, coordinate_system) do
    for {{joint, system}, accumulator} <- state.rom, system == coordinate_system, into: %{} do
      {joint, RomAccumulator.rom(accumulator)}
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  @doc """
  PubSub topic a LiveView should subscribe to in order to receive
  `{:analysis_completed, summary}` for the given analysis.
  """
  def subscribe_topic(analysis_id), do: topic(analysis_id)

  defp topic(analysis_id), do: "analysis:#{analysis_id}"

  defp number(nil), do: nil
  defp number(value) when is_number(value), do: value * 1.0
  defp number(_value), do: nil

  defp integer(nil), do: nil
  defp integer(value) when is_integer(value), do: value
  defp integer(value) when is_float(value), do: trunc(value)
  defp integer(_value), do: nil

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)

  defp fail(analysis, message) do
    Logger.error("analysis #{analysis.id} failed: #{message}")

    analysis
    |> Analysis.status_changeset("failed",
      error: message |> to_string() |> String.slice(0, 5_000),
      finished_at: now()
    )
    |> Repo.update()

    {:error, message}
  end
end
