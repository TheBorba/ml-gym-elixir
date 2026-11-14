defmodule MyAppWeb.PageController do
  @moduledoc """
  Landing route. Redirects to the live webcam page so `/` is never a 404.
  """

  use MyAppWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: "/webcam")
  end
end
