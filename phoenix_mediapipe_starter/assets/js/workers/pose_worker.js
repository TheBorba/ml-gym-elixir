import { FilesetResolver, PoseLandmarker } from "@mediapipe/tasks-vision";

const WASM_ROOT = "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision/wasm";
const MODEL_URL =
  "https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/1/pose_landmarker_lite.task";

let landmarker;
let initializing = false;

async function initialize() {
  if (landmarker || initializing) return;
  initializing = true;
  try {
    const vision = await FilesetResolver.forVisionTasks(WASM_ROOT);
    landmarker = await PoseLandmarker.createFromOptions(vision, {
      baseOptions: { modelAssetPath: MODEL_URL },
      runningMode: "VIDEO",
      numPoses: 1,
      minPoseDetectionConfidence: 0.6,
      minPosePresenceConfidence: 0.6,
      minTrackingConfidence: 0.6,
      outputSegmentationMasks: false
    });
    postMessage({ type: "ready" });
  } catch (error) {
    postMessage({ type: "error", message: error.message });
  } finally {
    initializing = false;
  }
}

self.onmessage = async ({ data }) => {
  if (data.type === "init") {
    await initialize();
    return;
  }
  if (data.type === "frame") {
    if (!landmarker) {
      data.bitmap.close();
      await initialize();
      return;
    }
    try {
      const result = landmarker.detectForVideo(data.bitmap, data.timestamp_ms);
      const image = result.landmarks?.[0] || [];
      const world = result.worldLandmarks?.[0] || [];
      postMessage({
        type: "result",
        timestamp_ms: data.timestamp_ms,
        landmarks: image.map((p, index) => ({
          index, x: p.x, y: p.y, z: p.z,
          visibility: p.visibility ?? null,
          presence: p.presence ?? null,
          world: world[index]
            ? { x: world[index].x, y: world[index].y, z: world[index].z }
            : null
        }))
      });
    } catch (error) {
      postMessage({ type: "error", message: error.message });
    } finally {
      data.bitmap.close();
    }
  }
};
