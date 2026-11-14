# This configuration is used for testing and local development.
# In production, use config/prod.exs with environment-specific settings.
import Config

# Repositories managed by this application. Ecto mix tasks read this from the
# application environment, not from `mix.exs`.
config :my_app, ecto_repos: [MyApp.Repo]

# Apple's .m4v is not in the built-in MIME table, but it is a valid MP4
# container that users upload from iPhones and iTunes. Register it so the
# `allow_upload` accept filter in VideoUploadLive accepts it.
config :mime, :types, %{"video/x-m4v" => ["m4v"]}

# Configure your database
config :my_app, MyApp.Repo,
  url: System.get_env("DATABASE_URL") || "ecto://my_app:change-me@localhost/my_app_dev",
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

# Configure Oban for background job processing (video analysis via Python Port)
config :my_app, Oban,
  repo: MyApp.Repo,
  queues: [video_analysis: 1],
  plugins: [],
  log: false

# Configure the Python worker port adapter.
#
# Python runs from the virtualenv baked into the container image at
# /app/priv/python/.venv (built by priv/python/setup_venv.sh from
# priv/python/requirements.txt). Nothing is installed on the host.
#
# PYTHON_BIN points at that interpreter; `PythonPort` resolves it via
# `System.find_executable/1` and falls back to the repo-local venv path.
config :my_app, MyApp.VideoAnalysis.PythonPort,
  python_bin: System.get_env("PYTHON_BIN", "python3"),
  venv_python: "priv/python/.venv/bin/python3",
  script: "priv/python/pose_worker.py",
  sample_fps: 12,
  batch_size: 200,
  port_buffer: 1_000_000,
  timeout_ms: 30 * 60 * 1000

# Where uploaded MP4s are written. Kept outside priv/static so files are
# never served publicly.
config :my_app, MyApp.Uploads,
  dir: System.get_env("UPLOAD_DIR") || "priv/uploads"

# Configure MediaPipe model path
config :my_app, MyApp.MediaPipe,
  model_path: "priv/models/pose_landmarker_lite.task"

# Configures the endpoint
config :my_app, MyAppWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST", "localhost"), port: 4000],
  secret_key_base:
    System.get_env("SECRET_KEY_BASE") ||
      "dev_only_secret_key_base_replace_me_in_production_0123456789abcdef",
  render_errors: [
    formats: [html: MyAppWeb.ErrorHTML, json: MyAppWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: MyApp.PubSub,
  live_view: [signing_salt: System.get_env("PHX_SIGNING_SALT", "dev_live_view_signing_salt")],
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/my_app_web/(live|controllers|components)/.*(ex)$",
      ~r"lib/my_app_web/.*(ex)$"
    ]
  ]

# Import environment-specific config. Must stay at the bottom so it can
# override the defaults above.
import_config "#{config_env()}.exs"

