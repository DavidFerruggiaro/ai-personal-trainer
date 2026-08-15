import AVFoundation
import MediaPipeTasksVision
import PoseCore
import UIKit

final class TrainerLivePoseCamera: NSObject, ObservableObject, LivePoseStreaming, LivePoseEventDelivering {
    let captureSession = AVCaptureSession()
    let engine = PoseEngineInfo(
        name: "mediapipe_pose_landmarker",
        version: "MediaPipeTasksVision",
        config: [
            "source": "trainer_live_camera",
            "running_mode": "video",
            "camera_preset": "hd1280x720",
            "camera_target_fps": "30",
            "sample_buffer_orientation": "portrait",
            "mp_image_orientation": "up",
            "model": "pose_landmarker_full.task"
        ]
    )

    @Published private(set) var state: LivePoseStreamState = .idle

    private let eventChannel: LivePoseEventChannel
    private let sessionQueue = DispatchQueue(label: "SquatTrainer.livePose.session")
    private let captureQueue: DispatchQueue
    private let lifecycleLock = NSLock()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var isConfigured = false
    private var stopQueued = false
    private var landmarker: PoseLandmarker?
    private var startedAtUptime: TimeInterval?

    override init() {
        let captureQueue = DispatchQueue(label: "SquatTrainer.livePose.capture")
        self.captureQueue = captureQueue
        self.eventChannel = LivePoseEventChannel(
            bufferingNewest: 120,
            deliveryQueue: captureQueue
        )
        super.init()
    }

    var events: AsyncStream<LivePoseEvent> {
        eventChannel.events
    }

    var deliveryBaseline: LivePoseDeliveryBaseline {
        eventChannel.deliveryBaseline
    }

    var eventDeliveryDropCount: UInt64 {
        eventChannel.eventDeliveryDropCount
    }

    func setEventDeliveryDropHandler(
        _ handler: @escaping @Sendable (UInt64) -> Void
    ) {
        eventChannel.setEventDeliveryDropHandler(handler)
    }

    func completeEventDeliveryDropNotification(through deliveredCount: UInt64) {
        eventChannel.completeEventDeliveryDropNotification(through: deliveredCount)
    }

    func enqueueDeliveryBoundary(_ id: UUID) {
        eventChannel.enqueueDeliveryBoundary(id)
    }

    func start() {
        lifecycleLock.lock()
        let willRestartAfterQueuedStop = stopQueued
        lifecycleLock.unlock()

        guard willRestartAfterQueuedStop || (state != .starting && state != .running) else {
            return
        }
        publish(.starting)

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureAndStart()
                    } else {
                        self?.publish(.failed("Camera permission denied."))
                    }
                }
            }
        case .denied, .restricted:
            publish(.failed("Camera permission is unavailable."))
        @unknown default:
            publish(.failed("Unknown camera permission state."))
        }
    }

    func stop() {
        lifecycleLock.lock()
        guard !stopQueued else {
            lifecycleLock.unlock()
            return
        }
        stopQueued = true
        lifecycleLock.unlock()

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
            self.landmarker = nil
            self.startedAtUptime = nil
            self.lifecycleLock.lock()
            self.stopQueued = false
            self.lifecycleLock.unlock()
            self.publish(.stopped)
        }
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configureIfNeeded()
                self.landmarker = try self.makeLandmarker()
                self.startedAtUptime = ProcessInfo.processInfo.systemUptime
                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }
                self.publish(.running)
            } catch {
                self.publish(.failed(error.localizedDescription))
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
        do {
            try configureFrameRate(for: device)
        } catch {
            captureSession.removeInput(input)
            captureSession.commitConfiguration()
            throw error
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)

        guard captureSession.canAddOutput(videoOutput) else {
            captureSession.removeInput(input)
            captureSession.commitConfiguration()
            throw PoseEstimatorError.engineUnavailable("Cannot add rear camera output.")
        }
        captureSession.addOutput(videoOutput)

        guard let connection = videoOutput.connection(with: .video),
              connection.isVideoRotationAngleSupported(90) else {
            captureSession.removeOutput(videoOutput)
            captureSession.removeInput(input)
            captureSession.commitConfiguration()
            throw PoseEstimatorError.engineUnavailable("Rear camera output cannot rotate to portrait.")
        }
        connection.videoRotationAngle = 90

        captureSession.commitConfiguration()
        isConfigured = true
    }

    private func configureFrameRate(for device: AVCaptureDevice) throws {
        let targetFPS = 30.0
        guard device.activeFormat.videoSupportedFrameRateRanges.contains(where: {
            $0.minFrameRate <= targetFPS && targetFPS <= $0.maxFrameRate
        }) else {
            throw PoseEstimatorError.engineUnavailable("Rear camera format does not support 30 FPS.")
        }

        try device.lockForConfiguration()
        let duration = CMTime(value: 1, timescale: 30)
        device.activeVideoMinFrameDuration = duration
        device.activeVideoMaxFrameDuration = duration
        device.unlockForConfiguration()
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

    private func publish(_ newState: LivePoseStreamState) {
        eventChannel.emit(.stateChanged(newState))
        DispatchQueue.main.async {
            self.state = newState
        }
    }
}

extension TrainerLivePoseCamera: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let landmarker, let startedAtUptime else {
            return
        }

        let now = ProcessInfo.processInfo.systemUptime
        let timestampMilliseconds = Int(((now - startedAtUptime) * 1_000).rounded())
        let startedProcessing = ProcessInfo.processInfo.systemUptime

        do {
            let image = try MPImage(sampleBuffer: sampleBuffer, orientation: .up)
            let result = try landmarker.detect(
                videoFrame: image,
                timestampInMilliseconds: timestampMilliseconds
            )
            let latency = (ProcessInfo.processInfo.systemUptime - startedProcessing) * 1_000
            let frame = MediaPipePoseMapper.mapResult(
                result,
                timestampSeconds: Double(timestampMilliseconds) / 1_000
            )
            emitObservation(frame: frame, latency: latency)
        } catch {
            eventChannel.emit(.inferenceFailed(error.localizedDescription))
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        eventChannel.emit(.captureDropped)
    }

    private func emitObservation(frame: PoseFrame, latency: Double) {
        eventChannel.emit(.observation(LivePoseObservation(
            frame: frame,
            inferenceLatencyMilliseconds: latency,
            sourceSequenceNumber: eventChannel.nextSourceSequence()
        )))
    }
}
