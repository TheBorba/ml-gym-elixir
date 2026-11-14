defmodule MyAppWeb.VideoUploadLiveTest do
  # async: false so the Ecto sandbox owner is shared with the LiveView process
  # and application env overrides cannot leak between tests.
  use MyAppWeb.ConnCase, async: false
  use Oban.Testing, repo: MyApp.Repo

  setup do
    previous = Application.get_env(:my_app, MyApp.MediaPipe, [])

    on_exit(fn ->
      Application.put_env(:my_app, MyApp.MediaPipe, previous)
    end)

    :ok
  end

  describe "mount/3" do
    test "renders the upload form", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/video-upload")

      assert html =~ "MP4 video analysis"
      assert html =~ "video-dropzone"
      assert html =~ "Analyse video"
      assert html =~ "Accepts:"
    end

    test "renders no results section before an analysis exists", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/video-upload")

      refute html =~ "Detected exercise"
    end
  end

  describe "save event" do
    test "stores the upload, inserts an analysis and enqueues the worker", %{conn: conn} do
      tmp =
        Path.join(System.tmp_dir!(), "my_app_upload_test_#{System.unique_integer([:positive])}")

      File.mkdir_p!(tmp)
      model = Path.join(tmp, "pose_landmarker_lite.task")
      File.write!(model, "placeholder model bundle")

      previous_uploads = Application.get_env(:my_app, MyApp.Uploads, [])

      Application.put_env(:my_app, MyApp.Uploads, Keyword.put(previous_uploads, :dir, tmp))
      Application.put_env(:my_app, MyApp.MediaPipe, model_path: model)

      on_exit(fn ->
        Application.put_env(:my_app, MyApp.Uploads, previous_uploads)
        File.rm_rf!(tmp)
      end)

      {:ok, view, _html} = live(conn, "/video-upload")

      upload =
        file_input(view, "#video-upload-form", :video, [
          %{name: "squat.mp4", content: "not really an mp4", type: "video/mp4"}
        ])

      assert render_upload(upload, "squat.mp4") =~ "squat.mp4"

      html = render_submit(view, "save", %{})

      assert html =~ "queued"

      assert [analysis] = MyApp.Repo.all(MyApp.Analysis)
      assert analysis.status == "pending"
      assert analysis.video_path =~ tmp
      assert File.regular?(analysis.video_path)

      assert [job] = all_enqueued(worker: MyApp.VideoAnalysis.AnalysisWorker)
      assert job.args["analysis_id"] == analysis.id
      assert job.args["video_path"] == analysis.video_path
      assert job.args["model_path"] == model
    end

    test "explains how to install the model when it is missing", %{conn: conn} do
      Application.put_env(:my_app, MyApp.MediaPipe, model_path: "/nonexistent/pose.task")

      {:ok, view, _html} = live(conn, "/video-upload")

      html = render_submit(view, "save")

      assert html =~ "MediaPipe model not found"
      assert html =~ "priv/models/README.md"
    end
  end

  describe "validate event" do
    test "clears any previous error", %{conn: conn} do
      Application.put_env(:my_app, MyApp.MediaPipe, model_path: "/nonexistent/pose.task")

      {:ok, view, _html} = live(conn, "/video-upload")

      assert render_submit(view, "save") =~ "MediaPipe model not found"

      # Re-validating the form (picking a different file) must clear the error.
      refute render_change(view, "validate", %{}) =~ "MediaPipe model not found"
    end
  end
end
