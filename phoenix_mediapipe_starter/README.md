# Phoenix + MediaPipe starter

Hybrid starter for a Phoenix LiveView physiotherapy / gym application.

- Live webcam: MediaPipe Tasks Vision in a browser Web Worker; only landmark JSON is sent to Phoenix.
- MP4: Oban job launches a Python MediaPipe worker through an Elixir Port.
- Shared domain: normalized landmarks and native Elixir angle calculations.

This is an integration starter, not a complete generated Phoenix application. Copy the files into an existing Phoenix project and adapt module names, routes, upload policy, authentication, database schemas, and Oban configuration.

## Requirements

- Elixir / OTP and Phoenix LiveView
- PostgreSQL and Oban
- Node asset bundling that emits ES module workers (Vite is the simplest option)
- Python 3.10 or 3.11 in a separate worker environment
- FFmpeg and OpenCV
- MediaPipe Pose Landmarker task model

## Add dependencies

In `mix.exs`, add Oban, for example:

```elixir
{:oban, "~> 2.19"}
```

In the JS package manifest, add `@mediapipe/tasks-vision` at a pinned, tested version. Do not deploy `@latest`.

Configure your bundler to emit `assets/js/workers/pose_worker.js` as `/assets/pose_worker.js`. The sample hook expects that URL.

No bundler is wired into this project on purpose: `assets/js/` holds the sources and `priv/static/assets/` is where the built files belong (the endpoint serves `/assets` with `only: ~w(pose_worker.js app.js app.css)`). The `esbuild` and `tailwind` packages are not dependencies, so add them back together with an `assets.deploy` alias if you want `mix phx.server` to build the bundle.

## Download the model

```bash
mkdir -p priv/models
curl -L \
  https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task \
  -o priv/models/pose_landmarker_lite.task
```

Keep the model asset versioned/deployed explicitly and record its checksum.

## Python environment

The image builds the virtualenv itself at `/app/priv/python/.venv` (see
`priv/python/setup_venv.sh`), so nothing has to be installed on the host:

```bash
docker compose build app
```

`priv/python/requirements.txt` pins the exact versions resolved in that image
(Python 3.13.5), so rebuilds install a known-good stack. To re-pin after an
upgrade:

```bash
docker run --rm <image> /app/priv/python/.venv/bin/python3 -m pip freeze
```

For a host-only venv instead:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r priv/python/requirements.txt
```

Install FFmpeg at the OS level.

Because the sample Elixir Port launches `python3` directly, Python, MediaPipe,
OpenCV and the model asset must be available in the same runtime/container as
the Oban worker. In production, run Oban in a dedicated Phoenix release image
with those dependencies installed, or replace the Port adapter with a secured
RPC/job interface to a separately deployed Python service. Do not run the
standalone Python Dockerfile as an idle daemon; it is a command-line worker.

## Oban

Configure a conservative CPU queue:

```elixir
config :my_app, Oban,
  repo: MyApp.Repo,
  queues: [video_analysis: 1],
  plugins: []
```

Add `{Oban, Application.fetch_env!(:my_app, Oban)}` to your supervision tree. Increase concurrency only after measuring CPU and memory use.

## Important production work

- Authenticate and authorize every patient/session before webcam events or uploads.
- Enforce upload size, duration, codec and content-type limits.
- Store uploaded videos outside the public static directory.
- Use durable private storage; LiveView temporary upload paths do not survive restarts.
- Persist an analysis record before enqueueing the job.
- Stream worker output into bounded batches rather than retaining all frames in memory.
- Add cleanup, retries, worker health checks, and retention policies.

## Coordinate and clinical safety

- `image_landmarks` are normalized image coordinates.
- `world_landmarks` are MediaPipe's estimated world coordinates in meters.
- Never mix coordinate systems in one angle calculation.
- Estimated world coordinates are not calibrated goniometry.
- Define camera placement, anatomical plane and coordinate frame per assessment.
- Filter low-confidence/occluded landmarks and expose measurement quality.
- Validate ROM against an appropriate reference instrument before clinical use.
- This starter is not a medical device or diagnostic system.

## Running the test suite

`lib/` and `test/` ship with the image, so the suite runs in the container
without bind mounts:

```bash
docker compose run --rm \
  -e TEST_DATABASE_URL=ecto://my_app:change-me@postgres/my_app_test \
  app mix test
```

`config/test.exs` deliberately ignores `DATABASE_URL`, so the test run never
migrates or truncates the development database.

## First verification

1. Run webcam page on localhost and confirm video stays in browser.
2. Confirm landmark updates arrive at configured rate.
3. Upload a short MP4 and confirm Oban receives monotonic timestamps.
4. Compare browser and Python outputs on the same recorded frames.
5. Validate angles with synthetic points and a reference dataset.
