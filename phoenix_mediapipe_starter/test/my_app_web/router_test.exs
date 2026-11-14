defmodule MyAppWeb.RouterTest do
  use MyAppWeb.ConnCase, async: true

  describe "health check" do
    test "GET /health reports the service as up", %{conn: conn} do
      conn = get(conn, "/health")

      assert json_response(conn, 200) == %{"status" => "ok", "service" => "my_app"}
    end
  end

  describe "HTML routes" do
    test "GET / redirects to the live webcam page", %{conn: conn} do
      conn = get(conn, "/")

      assert redirected_to(conn) == "/webcam"
    end

    test "GET /webcam renders the pose camera hook", %{conn: conn} do
      conn = get(conn, "/webcam")

      assert html_response(conn, 200) =~ "pose-camera-root"
    end

    test "GET /video-upload renders the upload form", %{conn: conn} do
      conn = get(conn, "/video-upload")

      assert html_response(conn, 200) =~ "video-dropzone"
    end
  end

  describe "unknown routes" do
    test "return 404", %{conn: conn} do
      conn = get(conn, "/definitely-not-a-route")

      assert conn.status == 404
    end
  end
end
