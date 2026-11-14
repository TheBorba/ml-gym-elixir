defmodule MyAppWeb.HealthController do
  @moduledoc """
  Health/readiness endpoint used by Docker and deployment probes.

  Returns `200 OK` with a small JSON body when the application is serving
  requests. It intentionally does not touch the database so it stays cheap.
  """

  use MyAppWeb, :controller

  def index(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{status: "ok", service: "my_app"}))
  end
end
