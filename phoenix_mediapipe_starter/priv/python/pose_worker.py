#!/usr/bin/env python3
"""Line-oriented MediaPipe Pose Landmarker worker for MP4 files."""
import argparse
import json
import sys
from pathlib import Path

import cv2
import mediapipe as mp


def emit(payload):
    sys.stdout.write(json.dumps(payload, separators=(",", ":")) + "\n")
    sys.stdout.flush()


def point_dict(point):
    return {
        "x": float(point.x), "y": float(point.y), "z": float(point.z),
        "visibility": float(point.visibility) if point.visibility is not None else None,
        "presence": float(point.presence) if point.presence is not None else None,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--video", required=True)
    parser.add_argument("--model", required=True)
    parser.add_argument("--sample-fps", type=float, default=12.0)
    args = parser.parse_args()

    if not Path(args.video).is_file() or not Path(args.model).is_file():
        raise FileNotFoundError("Video or MediaPipe model file not found")
    if args.sample_fps <= 0:
        raise ValueError("--sample-fps must be positive")

    cap = cv2.VideoCapture(args.video)
    if not cap.isOpened():
        raise RuntimeError("OpenCV could not open the uploaded video")

    source_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    frame_count = cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0
    sample_every = max(1, round(source_fps / args.sample_fps))
    sampled = 0
    frame_index = 0

    options = mp.tasks.vision.PoseLandmarkerOptions(
        base_options=mp.tasks.BaseOptions(model_asset_path=args.model),
        running_mode=mp.tasks.vision.RunningMode.VIDEO,
        num_poses=1,
        min_pose_detection_confidence=0.6,
        min_pose_presence_confidence=0.6,
        min_tracking_confidence=0.6,
        output_segmentation_masks=False,
    )

    try:
        with mp.tasks.vision.PoseLandmarker.create_from_options(options) as landmarker:
            while True:
                ok, bgr = cap.read()
                if not ok:
                    break
                if frame_index % sample_every == 0:
                    timestamp_ms = int(round(frame_index * 1000.0 / source_fps))
                    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
                    image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
                    result = landmarker.detect_for_video(image, timestamp_ms)
                    image_points = [point_dict(p) for p in result.pose_landmarks[0]] if result.pose_landmarks else []
                    world_points = [point_dict(p) for p in result.pose_world_landmarks[0]] if result.pose_world_landmarks else []
                    emit({
                        "type": "frame", "frame_index": frame_index,
                        "timestamp_ms": timestamp_ms,
                        "image_landmarks": image_points,
                        "world_landmarks": world_points,
                    })
                    sampled += 1
                frame_index += 1

        emit({
            "type": "complete", "source_fps": source_fps,
            "source_frames": int(frame_count), "processed_frames": sampled,
            "sample_fps_requested": args.sample_fps,
        })
    finally:
        cap.release()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"pose_worker_error: {exc}", file=sys.stderr)
        sys.exit(1)
