defmodule MyAppWeb.VideoUploadLive do
  @moduledoc """
  LiveView page for uploading an MP4 and tracking its analysis.

  ## Flow

    1. `mount/3` sets up a single-file upload (`:video`)
    2. `handle_event("validate", ...)` rejects non-video files early
    3. `handle_event("save", ...)` writes the file to private storage with
       `MyApp.Uploads`, inserts a `MyApp.Analysis` row and enqueues
       `MyApp.VideoAnalysis.AnalysisWorker`
    4. The LiveView subscribes to the analysis PubSub topic and renders the
       ROM summary and recognised exercise when the job completes

  Uploads never reach `priv/static`, so videos are not publicly served.
  """

  use MyAppWeb, :live_view

  alias MyApp.{Analysis, Repo, Uploads}
  alias MyApp.VideoAnalysis.AnalysisWorker

  @max_file_size 200 * 1024 * 1024
  @accept ~w(.mp4 .mov .m4v)

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Video analysis")
      |> assign(:analysis, nil)
      |> assign(:summary, nil)
      |> assign(:error, nil)
      |> assign(:status, nil)
      |> assign(:model_path, model_path())
      |> assign(:model_available?, File.regular?(Path.expand(model_path())))
      |> allow_upload(:video,
        accept: @accept,
        max_entries: 1,
        max_file_size: @max_file_size
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, assign(socket, :error, nil)}
  end

  def handle_event("save", _params, socket) do
    if socket.assigns.model_available? do
      case save_analysis(socket) do
        {:ok, analysis} ->
          if connected?(socket) do
            Phoenix.PubSub.subscribe(MyApp.PubSub, AnalysisWorker.subscribe_topic(analysis.id))
          end

          {:noreply,
           socket
           |> assign(:analysis, analysis)
           |> assign(:status, "queued")
           |> assign(:summary, nil)
           |> assign(:error, nil)}

        {:error, message} ->
          {:noreply, assign(socket, :error, message)}
      end
    else
      {:noreply,
       assign(
         socket,
         :error,
         "MediaPipe model not found at #{socket.assigns.model_path}. See priv/models/README.md."
       )}
    end
  end

  @impl true
  def handle_info({:analysis_completed, summary}, socket) do
    analysis = Repo.get(Analysis, summary.analysis_id)

    {:noreply,
     socket
     |> assign(:analysis, analysis)
     |> assign(:summary, summary)
     |> assign(:status, "completed")}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  defp save_analysis(socket) do
    results =
      consume_uploaded_entries(socket, :video, fn %{path: path}, entry ->
        Uploads.store(%Plug.Upload{path: path, filename: entry.client_name})
      end)

    case results do
      [destination] when is_binary(destination) ->
        attrs = %{
          video_path: destination,
          model_path: Path.expand(socket.assigns.model_path),
          sample_fps: 12.0,
          source: "mp4",
          status: "pending"
        }

        with {:ok, analysis} <- %Analysis{} |> Analysis.changeset(attrs) |> Repo.insert(),
             {:ok, _job} <- enqueue(analysis) do
          {:ok, analysis}
        else
          {:error, %Ecto.Changeset{} = changeset} ->
            {:error, "could not record the analysis: #{inspect(changeset.errors)}"}

          {:error, reason} ->
            {:error, "could not enqueue the analysis: #{inspect(reason)}"}
        end

      [] ->
        {:error, "select an MP4 file first"}
    end
  end

  defp enqueue(analysis) do
    AnalysisWorker.new(%{
      "analysis_id" => analysis.id,
      "video_path" => analysis.video_path,
      "model_path" => analysis.model_path
    })
    |> Oban.insert()
  end

  defp model_path do
    :my_app
    |> Application.get_env(MyApp.MediaPipe, [])
    |> Keyword.get(:model_path, "priv/models/pose_landmarker_lite.task")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-3xl">
      <h1 class="text-xl font-semibold mb-2">MP4 video analysis</h1>

      <.live_status :if={@status} status={status_bucket(@status)} label={@status} />
      <.live_error error={@error || ""} />

      <form id="video-upload-form" phx-change="validate" phx-submit="save" class="mt-4">
        <.live_dropzone
          id="video-dropzone"
          target={@uploads.video.ref}
          label="Drop an MP4 file here, or use the picker below"
        />

        <div class="mt-3">
          <.live_file_input upload={@uploads.video} />
        </div>

        <div :for={entry <- @uploads.video.entries} class="mt-3 text-sm text-gray-600">
          <div class="flex justify-between">
            <span>{entry.client_name}</span>
            <span>{entry.progress}%</span>
          </div>
          <p :for={err <- upload_errors(@uploads.video, entry)} class="text-red-600">
            {Phoenix.Naming.humanize(err)}
          </p>
        </div>

        <p :for={err <- upload_errors(@uploads.video)} class="mt-2 text-red-600 text-sm">
          {Phoenix.Naming.humanize(err)}
        </p>

        <button
          type="submit"
          phx-disable-with="Uploading..."
          disabled={@uploads.video.entries == []}
          class="mt-4 px-4 py-2 rounded bg-blue-600 text-white font-medium hover:bg-blue-700 disabled:opacity-50"
        >
          Analyse video
        </button>
      </form>

      <%= if @summary do %>
        <section class="mt-8">
          <h2 class="text-lg font-semibold mb-2">Results</h2>
          <p class="text-sm text-gray-600">
            Processed <strong>{@summary.processed_frames}</strong> sampled frames.
          </p>

          <h3 class="mt-4 font-medium">Detected exercise</h3>
          <ul class="list-disc list-inside text-sm">
            <li :for={exercise <- @summary.exercises}>
              <span class="font-medium">{exercise.name}</span>
              <span class="text-gray-500">
                ({round(exercise.confidence * 100)}% confidence) — {exercise.description}
              </span>
            </li>
          </ul>

          <h3 class="mt-4 font-medium">Range of motion</h3>
          <table class="text-sm mt-1">
            <thead>
              <tr class="text-left text-gray-500">
                <th class="pr-6">Joint</th>
                <th class="pr-6">ROM</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={{joint, rom} <- Enum.sort(@summary.rom_by_joint)}>
                <td class="pr-6">{joint}</td>
                <td class="pr-6">{rom && "#{rom} deg"}</td>
              </tr>
            </tbody>
          </table>
        </section>
      <% end %>
    </div>
    """
  end

  defp status_bucket(status) do
    cond do
      status =~ ~r/fail|error/i -> "error"
      status == "completed" -> "success"
      status == "processing" -> "processing"
      true -> "ready"
    end
  end
end
