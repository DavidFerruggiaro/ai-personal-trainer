import CoreMotion
import PoseCore
import TrainerCore
import TrainerRuntime

@MainActor
final class TrainerSetupGateController: ObservableObject {
    let camera: TrainerLivePoseCamera

    @Published private(set) var assessment = SetupGateAssessment.pending
    @Published private(set) var latestPoseFrame: PoseFrame?
    @Published private(set) var streamState: LivePoseStreamState = .idle
    @Published private(set) var captureDroppedFrames = 0
    @Published private(set) var eventDeliveryDroppedFrames = 0
    @Published private(set) var activeSetPoseStatus = ActiveSetPoseIngestion().status
    @Published private(set) var activeSetPoseFailure: ActiveSetPoseIngestionError?

    private let motionMonitor = PhoneStabilityMonitor()
    private let coordinator: TrainerActiveSetDeliveryCoordinator
    private var eventTask: Task<Void, Never>?

    init(camera: TrainerLivePoseCamera = TrainerLivePoseCamera()) {
        self.camera = camera
        self.coordinator = TrainerActiveSetDeliveryCoordinator(source: camera)
        camera.setEventDeliveryDropHandler { [weak self] droppedCount in
            Task { @MainActor in
                guard let self else { return }
                self.handleEventDeliveryDrop(droppedCount)
                self.camera.completeEventDeliveryDropNotification(
                    through: droppedCount
                )
            }
        }
    }

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
        motionMonitor.start()
        if eventTask == nil {
            eventTask = Task { [weak self] in
                guard let self else { return }
                for await event in camera.events {
                    guard !Task.isCancelled else { break }
                    handle(event)
                }
            }
        }
        camera.start()
    }

    func stop() {
        camera.stop()
        motionMonitor.stop()
    }

    func shutdown() {
        stop()
        eventTask?.cancel()
        eventTask = nil
        coordinator.shutdown()
    }

    func resetEvidence() {
        coordinator.resetSetupEvidence()
        motionMonitor.reset()
        assessment = coordinator.setupAssessment
        latestPoseFrame = nil
        captureDroppedFrames = 0
        eventDeliveryDroppedFrames = 0
    }

    func beginActiveSetPoseIngestion() throws {
        try coordinator.begin(baseline: camera.deliveryBaseline)
        activeSetPoseStatus = coordinator.activeSetPoseStatus
        activeSetPoseFailure = nil
    }

    func freezeActiveSetPoseSequence() async throws -> ActiveSetPoseSequence {
        do {
            let sequence = try await coordinator.freezeActiveSetPoseSequence()
            activeSetPoseStatus = coordinator.activeSetPoseStatus
            return sequence
        } catch {
            activeSetPoseStatus = coordinator.activeSetPoseStatus
            throw error
        }
    }

    func discardActiveSetPoseIngestion() {
        coordinator.discard()
        activeSetPoseStatus = coordinator.activeSetPoseStatus
        activeSetPoseFailure = nil
    }

    private func handle(_ event: LivePoseEvent) {
        switch event {
        case let .stateChanged(state):
            streamState = state
        case let .observation(observation):
            do {
                let output = try coordinator.observe(
                    observation,
                    phoneStable: motionMonitor.isStable
                )
                latestPoseFrame = output.latestPoseFrame
                assessment = output.setupAssessment
                activeSetPoseStatus = output.activeSetPoseStatus
            } catch let error as ActiveSetPoseIngestionError {
                activeSetPoseStatus = coordinator.activeSetPoseStatus
                activeSetPoseFailure = error
            } catch {
                assertionFailure("Unexpected pose observation pipeline error: \(error)")
            }
        case .captureDropped:
            captureDroppedFrames += 1
        case .inferenceFailed:
            break
        case let .deliveryBoundary(id):
            let effect = coordinator.finishDeliveryBoundary(id)
            activeSetPoseStatus = coordinator.activeSetPoseStatus
            if effect == .deliveryDropMismatch {
                activeSetPoseFailure = .eventDeliveryDropped
            }
        }
    }

    private func handleEventDeliveryDrop(_ droppedCount: UInt64) {
        eventDeliveryDroppedFrames = Int(droppedCount)
        let didInvalidate = coordinator.handleEventDeliveryDrop(droppedCount)
        activeSetPoseStatus = coordinator.activeSetPoseStatus
        if didInvalidate {
            activeSetPoseFailure = .eventDeliveryDropped
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
