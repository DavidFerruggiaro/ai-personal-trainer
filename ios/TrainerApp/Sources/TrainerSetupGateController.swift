import CoreMotion
import PoseCore
import TrainerCore

@MainActor
final class TrainerSetupGateController: ObservableObject {
    let camera = TrainerLivePoseCamera()

    @Published private(set) var assessment = SetupGateAssessment.pending
    @Published private(set) var latestPoseFrame: PoseFrame?
    @Published private(set) var streamState: LivePoseStreamState = .idle
    @Published private(set) var captureDroppedFrames = 0

    private let evidenceExtractor = PoseSetupEvidenceExtractor()
    private let motionMonitor = PhoneStabilityMonitor()
    private var signalWindow = SetupGateSignalWindow()
    private var eventTask: Task<Void, Never>?

    var statusText: String {
        switch streamState {
        case .idle:
            "Camera idle"
        case .starting:
            "Starting rear camera…"
        case .running:
            assessment.isReady ? "Setup ready" : "Checking setup…"
        case .stopped:
            "Camera stopped"
        case let .failed(message):
            message
        }
    }

    func start() {
        guard eventTask == nil else {
            camera.start()
            return
        }
        motionMonitor.start()
        eventTask = Task { [weak self] in
            guard let self else { return }
            for await event in camera.events {
                guard !Task.isCancelled else { break }
                handle(event)
            }
        }
        camera.start()
    }

    func stop() {
        camera.stop()
        motionMonitor.stop()
        eventTask?.cancel()
        eventTask = nil
    }

    func resetEvidence() {
        signalWindow.reset()
        motionMonitor.reset()
        assessment = .pending
        latestPoseFrame = nil
        captureDroppedFrames = 0
    }

    private func handle(_ event: LivePoseEvent) {
        switch event {
        case let .stateChanged(state):
            streamState = state
        case let .observation(observation):
            latestPoseFrame = observation.frame
            let evidence = evidenceExtractor.evidence(from: observation.frame)
            signalWindow.observe(SetupGateSignalSample(
                fullBodyVisible: evidence.fullBodyVisible,
                sideViewLikely: evidence.sideViewLikely ?? false,
                phoneStable: motionMonitor.isStable,
                poseConfidenceOK: evidence.poseConfidenceOK
            ))
            assessment = signalWindow.assessment
        case .captureDropped:
            captureDroppedFrames += 1
        case .inferenceFailed:
            break
        }
    }
}

@MainActor
private final class PhoneStabilityMonitor {
    private let motionManager = CMMotionManager()
    private var recentSamples: [Bool] = []
    private let capacity = 30
    private let minimumSamples = 15

    private(set) var isStable: Bool?

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            isStable = false
            return
        }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let rotation = motion.rotationRate
            let acceleration = motion.userAcceleration
            let rotationMagnitude = sqrt(
                rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z
            )
            let accelerationMagnitude = sqrt(
                acceleration.x * acceleration.x
                    + acceleration.y * acceleration.y
                    + acceleration.z * acceleration.z
            )
            observe(rotationMagnitude < 0.10 && accelerationMagnitude < 0.06)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    func reset() {
        recentSamples.removeAll(keepingCapacity: true)
        isStable = nil
    }

    private func observe(_ stable: Bool) {
        recentSamples.append(stable)
        if recentSamples.count > capacity {
            recentSamples.removeFirst(recentSamples.count - capacity)
        }
        guard recentSamples.count >= minimumSamples else {
            isStable = nil
            return
        }
        let stableRatio = Double(recentSamples.lazy.filter { $0 }.count)
            / Double(recentSamples.count)
        isStable = stableRatio >= 0.80
    }
}
