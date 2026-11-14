defmodule MyAppWeb.Endpoint do
  @moduledoc """
  Phoenix endpoint for the web application.

  This endpoint serves the Phoenix router and handles HTTP and WebSocket
  connections. It is configured in `config/config.exs` and `config/prod.exs`.

  The endpoint mounts the LiveView and Channel routes, and serves static assets
  from the `priv/static` directory.
  """

  use Phoenix.Endpoint, otp_app: :my_app

  # The session will be stored in the cookie and signed.
  @session_options [
    store: :cookie,
    key: "_my_app_key",
    signing_salt: System.get_env("PHX_SIGNING_SALT", "default_salt"),
    same_site: "Lax"
  ]

  # LiveView connects over a WebSocket at /live.
  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpolling: [connect_info: [session: @session_options]]

  plug Plug.RequestId

  plug Plug.Static,
    at: "/assets",
    from: "priv/static/assets",
    gzip: false,
    only: ~w(pose_worker.js app.js app.css)

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug MyAppWeb.Router
end
