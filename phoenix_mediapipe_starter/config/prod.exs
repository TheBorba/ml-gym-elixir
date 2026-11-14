# For production, `Mix.env()` is set to `:prod`. Instead of a file, we rely on
# environment variables for all configuration. See `config/config.exs` for the
# full set of configuration keys and their defaults.
import Config

# Configure the endpoint for production
config :my_app, MyAppWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST", "example.com"), port: String.to_integer(System.get_env("PHX_PORT", "4000"))],
  http: [
    ip: {0, 0, 0, 0, 0, 0, 0, 0},
    port: String.to_integer(System.get_env("PHX_PORT", "4000"))
  ],
  secret_key_base: System.get_env("SECRET_KEY_BASE"),
  pubsub_server: MyApp.PubSub,
  live_view: [signing_salt: System.get_env("PHX_SIGNING_SALT")]

# Configure the database for production (use DATABASE_URL or explicit values)
config :my_app, MyApp.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

# Configure Oban
config :my_app, Oban,
  repo: MyApp.Repo,
  queues: [video_analysis: 1],
  plugins: [],
  clock_tick: 10_000,
  log: false

# Configure the Python worker port adapter
config :my_app, MyApp.VideoAnalysis.PythonPort,
  python_bin: System.get_env("PYTHON_BIN", "python3"),
  script: "priv/python/pose_worker.py",
  sample_fps: 12,
  port_buffer: 1_000_000,
  timeout_ms: 30 * 60 * 1000

# Configure MediaPipe model path
config :my_app, MyApp.MediaPipe,
  model_path: "priv/models/pose_landmarker_lite.task"
