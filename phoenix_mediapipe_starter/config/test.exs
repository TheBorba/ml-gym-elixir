# This configuration is used for tests.
import Config

# Configure your database for tests.
#
# Deliberately does NOT reuse DATABASE_URL: that variable points at the
# development database inside docker compose, and tests must never migrate or
# truncate it. Override with TEST_DATABASE_URL when running outside compose.
config :my_app, MyApp.Repo,
  url:
    System.get_env("TEST_DATABASE_URL") ||
      "ecto://my_app:change-me@postgres/my_app_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# Configure Oban for tests: manual execution keeps jobs from running
# asynchronously inside the Ecto SQL sandbox.
config :my_app, Oban,
  repo: MyApp.Repo,
  queues: [video_analysis: 1],
  plugins: [],
  testing: :manual,
  log: false

# Configure the Python worker port adapter for tests
config :my_app, MyApp.VideoAnalysis.PythonPort,
  python_bin: System.get_env("PYTHON_BIN", "python3"),
  venv_python: "priv/python/.venv/bin/python3",
  script: "priv/python/pose_worker.py",
  sample_fps: 12,
  batch_size: 200,
  port_buffer: 1_000_000,
  timeout_ms: 30 * 1000
