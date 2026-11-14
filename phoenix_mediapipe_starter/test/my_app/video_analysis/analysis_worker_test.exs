defmodule MyApp.VideoAnalysis.AnalysisWorkerTest do
  # async: false — the test swaps the PythonPort application env.
  use MyApp.DataCase, async: false

  alias MyApp.{Analysis, Frame, Repo, RomResult}
  alias MyApp.VideoAnalysis.{AnalysisWorker, PythonPort}

  @frame_count 5

  setup do
    tmp =
      Path.join(System.tmp_dir!(), "analysis_worker_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp)

    video = Path.join(tmp, "clip.mp4")
    model = Path.join(tmp, "pose_landmarker_lite.task")
    data = Path.join(tmp, "frames.jsonl")
    fake_python = Path.join(tmp, "fake_python.sh")

    File.write!(video, "not really a video")
    File.write!(model, "not really a model")
    File.write!(data, Enum.map_join(frames(), "", &(Jason.encode!(&1) <> "\n")))

    # Stand-in for `priv/python/.venv/bin/python3`: any executable that prints
    # the worker's newline-delimited JSON works, so the Elixir side of the
    # pipeline can be tested without OpenCV or a real MP4.
    File.write!(fake_python, "#!/bin/sh\ncat #{data}\n")
    File.chmod!(fake_python, 0o755)

    previous = Application.get_env(:my_app, PythonPort, [])

    Application.put_env(:my_app, PythonPort,
      python_bin: fake_python,
      venv_python: nil,
      script: fake_python,
      sample_fps: 12,
      batch_size: 2,
      timeout_ms: 10_000
    )

    on_exit(fn ->
      Application.put_env(:my_app, PythonPort, previous)
      File.rm_rf!(tmp)
    end)

    {:ok, video: video, model: model}
  end

  test "turns worker output into frames, measurements, ROM and an exercise", %{
    video: video,
    model: model
  } do
    analysis = insert_analysis!(video, model)

    job = %Oban.Job{
      args: %{"analysis_id" => analysis.id, "video_path" => video, "model_path" => model}
    }

    assert {:ok, summary} = AnalysisWorker.perform(job)

    assert summary.processed_frames == @frame_count
    assert summary.rom_by_joint["left_knee"] == 90.0
    assert Enum.any?(summary.exercises, &(&1.name == "squat"))

    stored = Repo.get!(Analysis, analysis.id)
    assert stored.status == "completed"
    assert stored.processed_frames == @frame_count
    assert stored.source_fps == 30.0
    assert stored.error == nil

    assert Repo.aggregate(Frame, :count) == @frame_count
    assert Repo.aggregate(MyApp.Measurement, :count) > 0

    rom =
      Repo.get_by!(RomResult,
        analysis_id: analysis.id,
        joint: "left_knee",
        coordinate_system: "image_normalized"
      )

    assert rom.rom_degrees == 90.0
    assert rom.min_angle == 90.0
    assert rom.max_angle == 180.0
    assert rom.repetitions == 2
  end

  test "marks the analysis failed when the worker cannot start", %{video: video, model: model} do
    analysis = insert_analysis!(video, model)

    Application.put_env(:my_app, PythonPort,
      python_bin: nil,
      venv_python: nil,
      script: "missing.py"
    )

    job = %Oban.Job{
      args: %{"analysis_id" => analysis.id, "video_path" => video, "model_path" => model}
    }

    assert {:error, message} = AnalysisWorker.perform(job)
    assert message =~ "python worker failed"

    stored = Repo.get!(Analysis, analysis.id)
    assert stored.status == "failed"
    assert stored.error =~ "python_interpreter_missing"
    assert stored.finished_at
  end

  test "cancels the job when the analysis row is gone" do
    assert {:cancel, :analysis_not_found} =
             AnalysisWorker.perform(%Oban.Job{args: %{"analysis_id" => 0}})

    assert {:cancel, :missing_analysis_id} = AnalysisWorker.perform(%Oban.Job{args: %{}})
  end

  defp insert_analysis!(video, model) do
    %Analysis{}
    |> Analysis.changeset(%{
      video_path: video,
      model_path: model,
      sample_fps: 12.0,
      source: "mp4",
      status: "pending"
    })
    |> Repo.insert!()
  end

  # Five sampled frames: the left knee alternates between fully extended (180°)
  # and 90° of flexion, which is two complete repetitions.
  defp frames do
    ankles = [
      %{"x" => 0.5, "y" => 0.75},
      %{"x" => 0.65, "y" => 0.6},
      %{"x" => 0.5, "y" => 0.75},
      %{"x" => 0.65, "y" => 0.6},
      %{"x" => 0.5, "y" => 0.75}
    ]

    frame_records =
      ankles
      |> Enum.with_index()
      |> Enum.map(fn {ankle, index} ->
        %{
          "type" => "frame",
          "frame_index" => index,
          "timestamp_ms" => index * 83,
          "image_landmarks" => landmarks(ankle),
          "world_landmarks" => []
        }
      end)

    frame_records ++
      [
        %{
          "type" => "complete",
          "source_fps" => 30.0,
          "source_frames" => 150,
          "processed_frames" => @frame_count,
          "sample_fps_requested" => 12.0
        }
      ]
  end

  defp landmarks(ankle) do
    base = %{"x" => 0.5, "y" => 0.5, "z" => 0.0, "visibility" => 0.9, "presence" => 0.9}

    overrides = %{
      # left shoulder, elbow, wrist — a straight arm
      11 => %{"x" => 0.5, "y" => 0.3},
      13 => %{"x" => 0.5, "y" => 0.45},
      15 => %{"x" => 0.5, "y" => 0.6},
      # left hip, knee, ankle — the moving leg
      23 => %{"x" => 0.5, "y" => 0.45},
      25 => %{"x" => 0.5, "y" => 0.6},
      27 => ankle
    }

    for index <- 0..32 do
      Map.merge(base, Map.get(overrides, index, %{}))
    end
  end
end
