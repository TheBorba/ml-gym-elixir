# Asset wiring

Register the hook in the Phoenix LiveSocket setup:

```javascript
import PoseCamera from "./hooks/pose_camera";

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { PoseCamera },
  params: { _csrf_token: csrfToken }
});
```

Configure your bundler to emit `assets/js/workers/pose_worker.js` as `/assets/pose_worker.js`. The worker imports `@mediapipe/tasks-vision`, so it must be bundled as an ES module with its package dependency resolvable.

The camera requires HTTPS outside localhost. Video frames remain in the browser; only landmark values are sent to LiveView.
