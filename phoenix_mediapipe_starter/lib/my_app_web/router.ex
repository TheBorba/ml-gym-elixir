defmodule MyAppWeb.Router do
  @moduledoc """
  Phoenix router for the web application.

  This router defines all HTTP and WebSocket routes for the application,
  including LiveView pages for webcam and video upload.
  """

  use MyAppWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_secure_browser_headers
  end

  # The video analysis pipeline routes
  scope "/", MyAppWeb do
    pipe_through :browser

    get "/", PageController, :index

    # LiveView pages for the MediaPipe pipeline
    live "/webcam", WebcamLive, :index
    live "/video-upload", VideoUploadLive, :index

    get "/health", HealthController, :index
  end
end



