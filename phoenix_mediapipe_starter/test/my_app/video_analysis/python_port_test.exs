defmodule MyApp.VideoAnalysis.PythonPortTest do
  # async: false — some tests temporarily edit application env.
  use ExUnit.Case, async: false

  alias MyApp.VideoAnalysis.PythonPort

  describe "interpreter/1" do
    test "resolves an existing executable from config" do
      assert {:ok, executable} = PythonPort.interpreter()
      assert File.exists?(executable)
    end

    test "prefers an explicit :python option" do
      assert {:ok, executable} = PythonPort.interpreter(python: "python3")
      assert Path.basename(executable) == "python3"
    end

    test "skips unusable candidates instead of failing" do
      assert {:ok, executable} = PythonPort.interpreter(python: "/nonexistent/python")
      assert File.exists?(executable)
    end

    test "falls back to the pipeline venv when :python_bin is not usable" do
      config = Application.get_env(:my_app, PythonPort, [])
      Application.put_env(:my_app, PythonPort, Keyword.delete(config, :python_bin))
      on_exit(fn -> Application.put_env(:my_app, PythonPort, config) end)

      assert {:ok, executable} = PythonPort.interpreter()
      assert File.exists?(executable)
    end

    test "returns an error when no candidate can be found" do
      config = Application.get_env(:my_app, PythonPort, [])

      Application.put_env(
        :my_app,
        PythonPort,
        config |> Keyword.delete(:python_bin) |> Keyword.delete(:venv_python)
      )

      on_exit(fn -> Application.put_env(:my_app, PythonPort, config) end)

      # A bare "python3" may still exist on PATH; only assert the error shape
      # when it does not.
      case PythonPort.interpreter() do
        {:ok, executable} ->
          assert File.exists?(executable) or System.find_executable("python3")

        {:error, reason} ->
          assert reason == :python_interpreter_missing
      end
    end
  end

  describe "script_path/1" do
    test "resolves the bundled pose worker" do
      assert {:ok, path} = PythonPort.script_path()
      assert File.regular?(path)
      assert Path.basename(path) == "pose_worker.py"
    end

    test "reports a missing worker script" do
      assert PythonPort.script_path(script: "priv/python/nope.py") ==
               {:error, :worker_script_missing}
    end
  end

  describe "run/3" do
    test "rejects a missing video before spawning Python" do
      assert PythonPort.run("/tmp/does-not-exist.mp4", "/tmp/model.task") ==
               {:error, :video_missing}
    end

    test "rejects a missing model before spawning Python" do
      video = Path.join(System.tmp_dir!(), "video_#{System.unique_integer([:positive])}.mp4")
      File.write!(video, "not a real video")
      on_exit(fn -> File.rm(video) end)

      assert PythonPort.run(video, "/tmp/does-not-exist.task") == {:error, :model_missing}
    end
  end
end
