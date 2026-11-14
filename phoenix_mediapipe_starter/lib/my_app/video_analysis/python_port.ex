defmodule MyApp.VideoAnalysis.PythonPort do
  @moduledoc """
  Runs the Python MediaPipe worker as an OS subprocess and collects its
  newline-delimited JSON output.

  ## Interpreter resolution

  The Python worker always runs inside the application container, using the
  virtualenv baked into the image at `priv/python/.venv` (built by
  `priv/python/setup_venv.sh` during `docker build`). The interpreter is
  resolved in this order:

    1. `:python` option passed to `run/3` or `stream/4`
    2. `config :my_app, MyApp.VideoAnalysis.PythonPort, :python_bin`
       (usually derived from the `PYTHON_BIN` environment variable)
    3. `config :my_app, MyApp.VideoAnalysis.PythonPort, :venv_python`,
       resolved relative to the project root — i.e. `priv/python/.venv`
    4. `"python3"` on `PATH`

  All four are container paths; nothing is executed on the host.

  ## Output contract

  The worker writes one JSON object per line. Frames look like:

      {"type":"frame","frame_index":0,"timestamp_ms":0,
       "image_landmarks":[...33 points...],"world_landmarks":[...]}

  A final `{"type":"complete", ...}` record carries source video metadata.
  """

  require Logger

  @default_timeout_ms 30 * 60 * 1000
  @default_buffer 1_000_000

  @doc """
  Runs the worker and collects every JSON record into a list.

  Returns `{:ok, records}` or `{:error, reason}`.
  """
  def run(video_path, model_path, opts \\ []) do
    stream(video_path, model_path, fn record -> :keep end, opts)
    |> case do
      {:ok, _count, records} -> {:ok, records}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Runs the worker and yields each decoded record to `fun`.

  Returns `{:ok, record_count, records}` where `records` is the reversed
  accumulation of the records `fun` returned `:keep` for. This lets callers
  persist in bounded batches without holding an entire long video in memory:

      PythonPort.stream(video, model, fn
        %{"type" => "frame"} = frame -> persist(frame) ; :keep
        _other -> :drop
      end)

  Any return other than `:keep` keeps the record out of the returned list
  (the side effect still happens).
  """
  def stream(video_path, model_path, fun, opts \\ []) when is_function(fun, 1) do
    config = Application.get_env(:my_app, __MODULE__, [])

    with :ok <- ensure_regular(video_path, :video_missing),
         :ok <- ensure_regular(model_path, :model_missing),
         {:ok, executable} <- interpreter(opts),
         {:ok, script} <- script_path(opts) do
      sample_fps = Keyword.get(opts, :sample_fps, config[:sample_fps] || 12)
      buffer = Keyword.get(opts, :port_buffer, config[:port_buffer] || @default_buffer)
      timeout = Keyword.get(opts, :timeout_ms, config[:timeout_ms] || @default_timeout_ms)

      port =
        Port.open({:spawn_executable, executable}, [
          :binary,
          :exit_status,
          :use_stdio,
          :stderr_to_stdout,
          {:line, buffer},
          args: [
            script,
            "--video",
            video_path,
            "--model",
            model_path,
            "--sample-fps",
            to_string(sample_fps)
          ]
        ])

      collect(port, fun, [], 0, nil, timeout)
    end
  catch
    kind, reason ->
      Logger.error("PythonPort failed: #{inspect(kind)} #{inspect(reason)}")
      {:error, {:python_port_exception, reason}}
  end

  @doc """
  Resolves the interpreter that will be used, or `nil`.
  """
  def interpreter(opts \\ []) do
    config = Application.get_env(:my_app, __MODULE__, [])

    candidates =
      [
        Keyword.get(opts, :python),
        config[:python_bin],
        venv_python(config)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    case Enum.find_value(candidates, &System.find_executable/1) do
      nil -> {:error, :python_interpreter_missing}
      executable -> {:ok, executable}
    end
  end

  @doc """
  Resolves the pose worker script path.
  """
  def script_path(opts \\ []) do
    config = Application.get_env(:my_app, __MODULE__, [])
    script = Keyword.get(opts, :script, config[:script] || "priv/python/pose_worker.py")
    expanded = Path.expand(script)

    if File.regular?(expanded), do: {:ok, expanded}, else: {:error, :worker_script_missing}
  end

  defp venv_python(config) do
    case config[:venv_python] do
      nil -> nil
      path -> Path.expand(path)
    end
  end

  defp ensure_regular(path, error) when is_binary(path) do
    if File.regular?(path), do: :ok, else: {:error, error}
  end

  defp ensure_regular(_path, error), do: {:error, error}

  defp collect(port, fun, kept, count, error_msg, timeout) do
    receive do
      {^port, {:data, {:eol, line}}} ->
        {kept, count, error_msg} =
          case Jason.decode(line) do
            {:ok, record} ->
              case fun.(record) do
                :keep -> {[record | kept], count + 1, error_msg}
                _ -> {kept, count + 1, error_msg}
              end

            {:error, _} ->
              error_msg =
                if String.starts_with?(line, "pose_worker_error:") do
                  String.trim_leading(line, "pose_worker_error:") |> String.trim()
                else
                  error_msg
                end

              Logger.debug("PythonPort skipped non-JSON line: #{inspect(line)}")
              {kept, count, error_msg}
          end

        collect(port, fun, kept, count, error_msg, timeout)

      {^port, {:data, {:noeol, partial}}} ->
        Logger.debug("PythonPort partial line: #{inspect(partial)}")
        collect(port, fun, kept, count, error_msg, timeout)

      {^port, {:exit_status, 0}} ->
        {:ok, count, Enum.reverse(kept)}

      {^port, {:exit_status, status}} ->
        {:error, {:python_worker_exit, status, error_msg}}
    after
      timeout ->
        Port.close(port)
        {:error, :worker_timeout}
    end
  end
end
