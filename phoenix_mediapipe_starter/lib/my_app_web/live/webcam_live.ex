defmodule MyAppWeb.WebcamLive do
  @moduledoc """
  LiveView page for the MediaPipe webcam pose estimation.

  This LiveView provides a real-time webcam interface where the user can:
  1. Request camera access via `navigateToCamera/1`
  2. Start the webcam feed with the MediaPipe Pose Landmarker (running in a
     browser Web Worker)
  3. Draw pose overlay on a canvas
  4. See pose landmarks streamed from the browser worker
  5. Stop the webcam feed and clean up resources

  The browser worker handles all MediaPipe inference in the browser, so the
  server never receives raw video frames. Only normalized landmark JSON is sent
  over the wire, keeping bandwidth low and privacy high.

  ## LiveView callbacks

  - `mount/3` initializes the socket and renders the webcam template
  - `handle_event("camera_request", %{"patient_id" => patient_id}, socket)`
    navigates the user to the camera page
  - `handle_event("pose_status", %{"status" => status}, socket)` handles
    real-time status updates from the browser hook
  - `handle_event("pose_update", %{"landmarks" => landmarks}, socket)` handles
    real-time pose landmark updates from the browser hook
  - `handle_event("camera_stop", _params, socket)` stops the webcam feed

  The LiveView expects a custom LiveSocket hook `PoseCamera` to be registered
  in `assets/js/app.js`, configured with the worker URL and push rate.

  ## Templates

  Renders `lib/my_app_web/templates/webcam_live/index.html.heex` which
  contains the video element, canvas overlay, status display, and camera
  control buttons.
  """

  use MyAppWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:patient_id, nil)
      |> assign(:status, "Ready")
      |> assign(:camera_active, false)
      |> assign(:error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("camera_request", %{"patient_id" => patient_id}, socket) do
    {:noreply,
     socket
     |> assign(:patient_id, patient_id)
     |> assign(:status, "Requesting camera access...")
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("pose_status", %{"status" => status}, socket) do
    {:noreply, assign(socket, :status, status)}
  end

  @impl true
  def handle_event("pose_update", %{"timestamp_ms" => _ts, "landmarks" => _landmarks}, socket) do
    # Landmarks are rendered client-side on the canvas.
    {:noreply, socket}
  end

  def handle_event("camera_stop", _params, socket) do
    {:noreply,
     socket
     |> assign(:camera_active, false)
     |> assign(:status, "Ready")
     |> assign(:error, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="pose-camera-root"
      phx-hook="PoseCamera"
      data-worker-url="/assets/pose_worker.js"
      data-push-rate="12"
    >
      <h1 class="text-xl font-semibold mb-2">Live webcam pose estimation</h1>

      <.live_status status={status_bucket(@status)} label={@status} />

      <.live_error error={@error || ""} />

      <div class="relative inline-block">
        <video id="pose-video" class="rounded-lg" autoplay playsinline muted width="640" height="480"></video>
        <canvas id="pose-overlay" class="absolute inset-0 pointer-events-none"></canvas>
      </div>

      <div class="mt-4 flex gap-2">
        <button
          type="button"
          data-camera-start
          phx-click="camera_request"
          phx-value-patient_id={@patient_id || ""}
          class="px-4 py-2 rounded bg-blue-600 text-white font-medium hover:bg-blue-700"
        >
          Start camera
        </button>
        <button
          type="button"
          data-camera-stop
          phx-click="camera_stop"
          class="px-4 py-2 rounded bg-gray-200 text-gray-800 font-medium hover:bg-gray-300"
        >
          Stop camera
        </button>
      </div>
    </div>
    """
  end

  defp status_bucket(status) do
    cond do
      status =~ ~r/error/i -> "error"
      status =~ ~r/active|ready/i -> "ready"
      status =~ ~r/requesting/i -> "processing"
      true -> "idle"
    end
  end
end

