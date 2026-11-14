import Config

# Bind to 0.0.0.0 so the port published by docker compose reaches the container.
config :my_app, MyAppWeb.Endpoint,
  http: [
    ip: {0, 0, 0, 0},
    port: String.to_integer(System.get_env("PHX_PORT", "4000"))
  ],
  check_origin: false,
  debug_errors: true,
  code_reloader: false,
  live_reload: []

config :logger, level: :info
