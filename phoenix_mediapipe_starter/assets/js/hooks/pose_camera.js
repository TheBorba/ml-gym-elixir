const PoseCamera = {
  mounted() {
    this.video = this.el.querySelector("#pose-video");
    this.canvas = this.el.querySelector("#pose-overlay");
    this.ctx = this.canvas.getContext("2d");
    this.worker = new Worker(this.el.dataset.workerUrl, { type: "module" });
    this.stream = null;
    this.lastSentAt = 0;
    this.pushInterval = 1000 / Number(this.el.dataset.pushRate || 12);
    this.framePending = false;

    this.onWorkerMessage = ({ data }) => {
      if (data.type === "ready") this.pushEvent("pose_status", { status: "Model ready" });
      if (data.type === "result") {
        this.framePending = false;
        this.drawPose(data.landmarks || []);
        const now = performance.now();
        if (now - this.lastSentAt >= this.pushInterval) {
          this.lastSentAt = now;
          this.pushEvent("pose_update", {
            timestamp_ms: data.timestamp_ms,
            landmarks: data.landmarks
          });
        }
      }
      if (data.type === "error") {
        this.framePending = false;
        this.pushEvent("pose_status", { status: `Error: ${data.message}` });
      }
    };
    this.worker.addEventListener("message", this.onWorkerMessage);

    this.startButton = this.el.querySelector("[data-camera-start]");
    this.stopButton = this.el.querySelector("[data-camera-stop]");
    this.onStart = () => this.start();
    this.onStop = () => this.stop();
    this.startButton?.addEventListener("click", this.onStart);
    this.stopButton?.addEventListener("click", this.onStop);
  },

  async start() {
    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        audio: false,
        video: { facingMode: "user", width: { ideal: 640 }, height: { ideal: 480 } }
      });
      this.video.srcObject = this.stream;
      await this.video.play();
      this.worker.postMessage({ type: "init" });
      this.running = true;
      this.lastVideoTime = -1;
      this.pushEvent("pose_status", { status: "Camera active" });
      this.processFrame();
    } catch (error) {
      this.pushEvent("pose_status", { status: `Camera error: ${error.message}` });
    }
  },

  async processFrame() {
    if (!this.running || this.video.readyState < 2) return;
    if (!this.framePending && this.video.currentTime !== this.lastVideoTime) {
      this.lastVideoTime = this.video.currentTime;
      this.framePending = true;
      const bitmap = await createImageBitmap(this.video);
      this.worker.postMessage({
        type: "frame", bitmap,
        timestamp_ms: Math.round(this.video.currentTime * 1000)
      }, [bitmap]);
    }
    this.raf = requestAnimationFrame(() => this.processFrame());
  },

  stop() {
    this.running = false;
    if (this.raf) cancelAnimationFrame(this.raf);
    this.stream?.getTracks().forEach(track => track.stop());
    this.stream = null;
    if (this.video) this.video.srcObject = null;
    this.ctx?.clearRect(0, 0, this.canvas.width, this.canvas.height);
    this.pushEvent("pose_status", { status: "Camera stopped" });
  },

  drawPose(landmarks) {
    if (!this.video.videoWidth) return;
    const width = this.video.videoWidth, height = this.video.videoHeight;
    this.canvas.width = width;
    this.canvas.height = height;
    this.ctx.clearRect(0, 0, width, height);
    const links = [[11,12],[11,13],[13,15],[12,14],[14,16],[11,23],[12,24],
      [23,24],[23,25],[25,27],[24,26],[26,28],[27,29],[29,31],[28,30],[30,32]];
    this.ctx.lineWidth = 3;
    this.ctx.strokeStyle = "#22c55e";
    for (const [a,b] of links) {
      const p = landmarks[a], q = landmarks[b];
      if (!p || !q || (p.visibility ?? 1) < 0.5 || (q.visibility ?? 1) < 0.5) continue;
      this.ctx.beginPath();
      this.ctx.moveTo(p.x * width, p.y * height);
      this.ctx.lineTo(q.x * width, q.y * height);
      this.ctx.stroke();
    }
    this.ctx.fillStyle = "#f97316";
    landmarks.forEach(p => {
      if ((p.visibility ?? 1) < 0.5) return;
      this.ctx.beginPath();
      this.ctx.arc(p.x * width, p.y * height, 4, 0, Math.PI * 2);
      this.ctx.fill();
    });
  },

  destroyed() {
    this.stop();
    this.worker?.terminate();
    this.startButton?.removeEventListener("click", this.onStart);
    this.stopButton?.removeEventListener("click", this.onStop);
  }
};
export default PoseCamera;
