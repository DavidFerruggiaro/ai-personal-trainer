import AVFoundation
import MediaPipeTasksVision
import PoseCore
import SwiftUI
import UIKit

struct LiveCameraViabilityView: View {
    @StateObject private var model = LiveMediaPipeCameraModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Camera Viability")
                .font(.headline)

            Text("Internal M1.11 check: run MediaPipe on live camera frames and inspect FPS, latency, confidence, and dropped frames.")
                .font(.callout)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                CameraPreviewView(session: model.captureSession)
                    .aspectRatio(9 / 16, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.25))
                    }

                if let latestPoseFrame = model.latestPoseFrame {
                    PoseOverlayView(frame: latestPoseFrame)
                        .allowsHitTesting(false)
                        .aspectRatio(9 / 16, contentMode: .fit)
                }

                Text(model.statusMessage)
                    .font(.caption.monospaced())
                    .padding(8)
                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.white)
                    .padding(8)
            }

            HStack {
                Button {
                    model.start()
                } label: {
                    Label("Start Live MediaPipe", systemImage: "camera")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isRunning)

                Button {
                    model.stop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .disabled(!model.isRunning)

                Button {
                    model.resetMetrics()
                } label: {
                    Label("Reset Metrics", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Button {
                    model.exportMetrics()
                } label: {
                    Label("Export Metrics JSON", systemImage: "doc.badge.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(model.metrics.processedFrames == 0)

                if let metricsExportURL = model.metricsExportURL {
                    ShareLink(item: metricsExportURL) {
                        Label("Share Live Metrics", systemImage: "square.and.arrow.up")
                    }
                }
            }

            metricsGrid

            Text("Manual notes still required after a device run: device model, lighting/framing, heat, battery, and whether landmarks visibly track a side-view squat.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var metricsGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 6) {
            metricRow("Elapsed", model.metrics.elapsedSeconds.map { String(format: "%.1fs", $0) } ?? "-")
            metricRow("Processed", "\(model.metrics.processedFrames)")
            metricRow("With pose", "\(model.metrics.framesWithPose)")
            metricRow("Dropped/skipped", "\(model.metrics.droppedFrames)")
            metricRow("Failed", "\(model.metrics.failedFrames)")
            metricRow("Effective FPS", model.metrics.effectiveFPS.map { String(format: "%.1f", $0) } ?? "-")
            metricRow("Avg latency", model.metrics.averageLatencyMilliseconds.map { String(format: "%.1f ms", $0) } ?? "-")
            metricRow("Last latency", model.metrics.latestLatencyMilliseconds.map { String(format: "%.1f ms", $0) } ?? "-")
            metricRow("Avg confidence", model.metrics.averageFrameConfidence.map { String(format: "%.3f", $0) } ?? "-")
            metricRow("Last confidence", model.metrics.latestFrameConfidence.map { String(format: "%.3f", $0) } ?? "-")
        }
        .font(.caption.monospaced())
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
        }
    }
}

private struct LiveCameraMetrics: Equatable {
    var startedAt: Date?
    var elapsedSeconds: Double?
    var processedFrames = 0
    var framesWithPose = 0
    var droppedFrames = 0
    var failedFrames = 0
    var totalLatencyMilliseconds = 0.0
    var latestLatencyMilliseconds: Double?
    var totalFrameConfidence = 0.0
    var latestFrameConfidence: Double?

    var effectiveFPS: Double? {
        guard let elapsedSeconds, elapsedSeconds > 0 else {
            return nil
        }
        return Double(processedFrames) / elapsedSeconds
    }

    var averageLatencyMilliseconds: Double? {
        guard processedFrames > 0 else {
            return nil
        }
        return totalLatencyMilliseconds / Double(processedFrames)
    }

    var averageFrameConfidence: Double? {
        guard framesWithPose > 0 else {
            return nil
        }
        return totalFrameConfidence / Double(framesWithPose)
    }
}

private final class LiveMediaPipeCameraModel: NSObject, ObservableObject {
    let captureSession = AVCaptureSession()

    @Published private(set) var metrics = LiveCameraMetrics()
    @Published private(set) var statusMessage = "Idle"
    @Published private(set) var latestPoseFrame: PoseFrame?
    @Published private(set) var isRunning = false
    @Published private(set) var metricsExportURL: URL?

    private let sessionQueue = DispatchQueue(label: "PoseBakeoff.liveCamera.session")
    private let captureQueue = DispatchQueue(label: "PoseBakeoff.liveCamera.capture")
    private let videoOutput = AVCaptureVideoDataOutput()
    private var isConfigured = false
    private var landmarker: PoseLandmarker?
    private var startedAtUptime: TimeInterval?
    private var lastSubmittedUptime: TimeInterval?
    private let targetFrameIntervalSeconds = 1.0 / 15.0

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureAndStart()
                    } else {
                        self?.statusMessage = "Camera permission denied."
                    }
                }
            }
        case .denied, .restricted:
            statusMessage = "Camera permission is unavailable."
        @unknown default:
            statusMessage = "Unknown camera permission state."
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            DispatchQueue.main.async {
                self.isRunning = false
                self.statusMessage = "Stopped"
            }
        }
    }

    func resetMetrics() {
        DispatchQueue.main.async {
            self.metrics = LiveCameraMetrics(startedAt: self.isRunning ? Date() : nil)
            self.latestPoseFrame = nil
            self.metricsExportURL = nil
            self.startedAtUptime = self.isRunning ? ProcessInfo.processInfo.systemUptime : nil
            self.lastSubmittedUptime = nil
        }
    }

    func exportMetrics() {
        do {
            let export = LiveCameraMetricsExport(
                createdAt: Date(),
                engine: PoseEngineInfo(
                    name: "mediapipe_pose_landmarker",
                    version: "MediaPipeTasksVision",
                    config: [
                        "source": "live_camera",
                        "running_mode": "video",
                        "camera_preset": "hd1280x720",
                        "target_frame_interval_s": String(format: "%.3f", targetFrameIntervalSeconds),
                        "model": "pose_landmarker_full.task"
                    ]
                ),
                metrics: metrics
            )
            let outputURL = try writeMetricsExport(export)
            metricsExportURL = outputURL
            statusMessage = "Live metrics export ready."
        } catch {
            statusMessage = "Metrics export failed: \(error.localizedDescription)"
        }
    }

    private func configureAndStart() {
        statusMessage = "Starting camera..."

        sessionQueue.async { [weak self] in
            guard let self else { return }

            do {
                try self.configureIfNeeded()
                self.landmarker = try self.makeLandmarker()
                let startDate = Date()
                let startUptime = ProcessInfo.processInfo.systemUptime
                self.startedAtUptime = startUptime
                self.lastSubmittedUptime = nil

                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }

                DispatchQueue.main.async {
                    self.metrics = LiveCameraMetrics(startedAt: startDate)
                    self.latestPoseFrame = nil
                    self.isRunning = true
                    self.statusMessage = "Running live MediaPipe"
                }
            } catch {
                DispatchQueue.main.async {
                    self.isRunning = false
                    self.statusMessage = "Live camera failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func configureIfNeeded() throws {
        guard !isConfigured else {
            return
        }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) else {
            throw PoseEstimatorError.engineUnavailable("No rear camera available.")
        }

        let input = try AVCaptureDeviceInput(device: device)

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .hd1280x720

        guard captureSession.canAddInput(input) else {
            captureSession.commitConfiguration()
            throw PoseEstimatorError.engineUnavailable("Cannot add rear camera input.")
        }
        captureSession.addInput(input)

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            captureSession.commitConfiguration()
            throw PoseEstimatorError.engineUnavailable("Cannot add video data output.")
        }
        captureSession.addOutput(videoOutput)
        captureSession.commitConfiguration()
        isConfigured = true
    }

    private func makeLandmarker() throws -> PoseLandmarker {
        guard let modelPath = Bundle.main.path(
            forResource: "pose_landmarker_full",
            ofType: "task"
        ) else {
            throw PoseEstimatorError.engineUnavailable("Missing pose_landmarker_full.task in app bundle.")
        }

        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .video
        options.numPoses = 1
        options.minPoseDetectionConfidence = 0.30
        options.minPosePresenceConfidence = 0.30
        options.minTrackingConfidence = 0.30

        return try PoseLandmarker(options: options)
    }

    private func writeMetricsExport(_ export: LiveCameraMetricsExport) throws -> URL {
        let outputDirectory = try exportDirectory()
        let timestamp = Int(export.createdAt.timeIntervalSince1970)
        let outputURL = outputDirectory.appendingPathComponent(
            "live_mediapipe_metrics_\(timestamp).json"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(export)
        try data.write(to: outputURL, options: [.atomic])
        return outputURL
    }

    private func exportDirectory() throws -> URL {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        let outputDirectory = documentsDirectory.appendingPathComponent(
            "PoseBakeoffExports",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        return outputDirectory
    }
}

extension LiveMediaPipeCameraModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let landmarker, let startedAtUptime else {
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        if let lastSubmittedUptime, now - lastSubmittedUptime < targetFrameIntervalSeconds {
            DispatchQueue.main.async {
                self.metrics.droppedFrames += 1
            }
            return
        }
        lastSubmittedUptime = now

        let timestampMilliseconds = Int(((now - startedAtUptime) * 1000).rounded())
        let timestampSeconds = Double(timestampMilliseconds) / 1000
        let startedProcessing = ProcessInfo.processInfo.systemUptime

        do {
            let image = try MPImage(sampleBuffer: sampleBuffer, orientation: .right)
            let result = try landmarker.detect(
                videoFrame: image,
                timestampInMilliseconds: timestampMilliseconds
            )
            let latencyMilliseconds = (ProcessInfo.processInfo.systemUptime - startedProcessing) * 1000
            let poseFrame = MediaPipePoseEstimator.mapResult(
                result,
                timestampSeconds: timestampSeconds
            )
            let frameConfidence = poseFrame.frameConfidence
            let hasPose = !poseFrame.landmarks.isEmpty

            DispatchQueue.main.async {
                self.latestPoseFrame = poseFrame
                self.metrics.elapsedSeconds = self.metrics.startedAt.map { Date().timeIntervalSince($0) }
                self.metrics.processedFrames += 1
                self.metrics.framesWithPose += hasPose ? 1 : 0
                self.metrics.totalLatencyMilliseconds += latencyMilliseconds
                self.metrics.latestLatencyMilliseconds = latencyMilliseconds

                if let frameConfidence {
                    self.metrics.totalFrameConfidence += frameConfidence
                    self.metrics.latestFrameConfidence = frameConfidence
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.metrics.failedFrames += 1
                self.metrics.elapsedSeconds = self.metrics.startedAt.map { Date().timeIntervalSince($0) }
                self.statusMessage = "Live frame failed: \(error.localizedDescription)"
            }
        }
    }
}

private struct LiveCameraMetricsExport: Codable {
    var createdAt: Date
    var appVersion = "PoseBakeoff 0.1"
    var engine: PoseEngineInfo
    var device: DeviceInfo
    var metrics: Metrics
    var manualNotesRequired: [String]

    private enum CodingKeys: String, CodingKey {
        case createdAt = "created_at"
        case appVersion = "app_version"
        case engine
        case device
        case metrics
        case manualNotesRequired = "manual_notes_required"
    }

    init(createdAt: Date, engine: PoseEngineInfo, metrics: LiveCameraMetrics) {
        self.createdAt = createdAt
        self.engine = engine
        self.device = DeviceInfo.current
        self.metrics = Metrics(metrics)
        self.manualNotesRequired = [
            "physical_device_model",
            "lighting",
            "camera_distance_and_angle",
            "heat_after_run",
            "battery_change",
            "visual_overlay_alignment",
            "landmark_stability_during_side_view_squat"
        ]
    }

    struct DeviceInfo: Codable {
        var model: String
        var systemName: String
        var systemVersion: String

        private enum CodingKeys: String, CodingKey {
            case model
            case systemName = "system_name"
            case systemVersion = "system_version"
        }

        static var current: DeviceInfo {
            DeviceInfo(
                model: UIDevice.current.model,
                systemName: UIDevice.current.systemName,
                systemVersion: UIDevice.current.systemVersion
            )
        }
    }

    struct Metrics: Codable {
        var elapsedSeconds: Double?
        var processedFrames: Int
        var framesWithPose: Int
        var droppedFrames: Int
        var failedFrames: Int
        var effectiveFPS: Double?
        var averageLatencyMilliseconds: Double?
        var latestLatencyMilliseconds: Double?
        var averageFrameConfidence: Double?
        var latestFrameConfidence: Double?

        private enum CodingKeys: String, CodingKey {
            case elapsedSeconds = "elapsed_s"
            case processedFrames = "processed_frames"
            case framesWithPose = "frames_with_pose"
            case droppedFrames = "dropped_frames"
            case failedFrames = "failed_frames"
            case effectiveFPS = "effective_fps"
            case averageLatencyMilliseconds = "average_latency_ms"
            case latestLatencyMilliseconds = "latest_latency_ms"
            case averageFrameConfidence = "average_frame_confidence"
            case latestFrameConfidence = "latest_frame_confidence"
        }

        init(_ metrics: LiveCameraMetrics) {
            self.elapsedSeconds = metrics.elapsedSeconds
            self.processedFrames = metrics.processedFrames
            self.framesWithPose = metrics.framesWithPose
            self.droppedFrames = metrics.droppedFrames
            self.failedFrames = metrics.failedFrames
            self.effectiveFPS = metrics.effectiveFPS
            self.averageLatencyMilliseconds = metrics.averageLatencyMilliseconds
            self.latestLatencyMilliseconds = metrics.latestLatencyMilliseconds
            self.averageFrameConfidence = metrics.averageFrameConfidence
            self.latestFrameConfidence = metrics.latestFrameConfidence
        }
    }
}

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
