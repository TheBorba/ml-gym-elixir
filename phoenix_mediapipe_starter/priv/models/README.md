# MediaPipe model files

`MyApp.MediaPipe` (configured in `config/config.exs`) expects the pose
landmarker bundle at:

    priv/models/pose_landmarker_lite.task

Model files are large binaries and are intentionally **not** committed.

## Download

Pick one bundle from the MediaPipe Pose Landmarker model card:

| bundle | file                              | notes                          |
|--------|-----------------------------------|--------------------------------|
| lite   | `pose_landmarker_lite.task`       | fastest, default in config     |
| full   | `pose_landmarker_full.task`       | better accuracy                |
| heavy  | `pose_landmarker_heavy.task`      | slowest, best accuracy         |

Download the `.task` file and place it here, keeping the configured filename:

```sh
curl -L -o priv/models/pose_landmarker_lite.task \
  https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task
```

To use a different bundle, change `:model_path` under `config :my_app,
MyApp.MediaPipe` (or place the file and update the path for your environment).

## Why a separate directory

The model is passed to the Python worker as `--model <path>` and must exist on
disk before an analysis job is enqueued. The upload LiveView checks for it and
shows a clear error instead of failing deep inside the job.
