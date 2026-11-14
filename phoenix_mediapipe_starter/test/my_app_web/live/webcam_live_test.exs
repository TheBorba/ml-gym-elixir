defmodule MyAppWeb.WebcamLiveTest do
  # async: false so the Ecto sandbox owner is shared with the LiveView process.
  use MyAppWeb.ConnCase, async: false

  describe "mount/3" do
    test "renders the camera shell in the ready state", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/webcam")

      assert html =~ "pose-camera-root"
      assert html =~ ~s(phx-hook="PoseCamera")
      assert html =~ "Ready"
      assert html =~ "Start camera"
      assert html =~ "Stop camera"
    end
  end

  describe "camera lifecycle events" do
    test "\"camera_request\" switches to the requesting state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webcam")

      html = render_click(view, "camera_request", %{"patient_id" => "patient-1"})

      assert html =~ "Requesting camera access..."
    end

    test "\"pose_status\" surfaces worker status updates", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webcam")

      assert render_click(view, "pose_status", %{"status" => "Camera active"}) =~
               "Camera active"
    end

    test "\"camera_stop\" returns to the ready state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webcam")

      render_click(view, "camera_request", %{"patient_id" => "patient-1"})

      assert render_click(view, "camera_stop") =~ "Ready"
    end

    test "\"pose_update\" is accepted without changing the rendered status", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/webcam")

      html =
        render_click(view, "pose_update", %{
          "timestamp_ms" => 1_000,
          "landmarks" => [%{"x" => 0.5, "y" => 0.5, "z" => 0.0, "visibility" => 0.9}]
        })

      assert html =~ "Ready"
    end
  end
end
