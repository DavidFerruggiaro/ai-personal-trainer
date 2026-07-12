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
    private var posePipeline = TrainerPoseObservationPipeline()
    private var eventTask: Task<Void, Never>?
    private var boundaryContinuations: [
        UUID: CheckedContinuation<ActiveSetPoseSequence, Error>
    ] = [:]
    private var activeSetDeliveryDropBaseline: UInt64 = 0

    init(camera: TrainerLivePoseCamera = TrainerLivePoseCamera()) {
        self.camera = camera
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
        let pendingContinuations = Array(boundaryContinuations.values)
        boundaryContinuations.removeAll()
        for continuation in pendingContinuations {
            continuation.resume(throwing: ActiveSetPoseIngestionError.invalidPhase)
        }
    }

    func resetEvidence() {
        posePipeline.resetSetupEvidence()
        motionMonitor.reset()
        assessment = posePipeline.setupAssessment
        latestPoseFrame = nil
        captureDroppedFrames = 0
        eventDeliveryDroppedFrames = 0
    }

    func beginActiveSetPoseIngestion() throws {
        let deliveryBaseline = camera.activeSetDeliveryBaseline
        try posePipeline.beginActiveSet(
            afterSourceSequence: deliveryBaseline.latestObservationSequence
        )
        activeSetDeliveryDropBaseline = deliveryBaseline.eventDeliveryDropCount
        activeSetPoseStatus = posePipeline.activeSetPoseStatus
        activeSetPoseFailure = nil
    }

    func freezeActiveSetPoseSequence() async throws -> ActiveSetPoseSequence {
        let boundaryID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                boundaryContinuations[boundaryID] = continuation
                camera.enqueueDeliveryBoundary(boundaryID)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelDeliveryBoundary(boundaryID)
            }
        }
    }

    func discardActiveSetPoseIngestion() {
        posePipeline.discardActiveSet()
        activeSetPoseStatus = posePipeline.activeSetPoseStatus
        activeSetPoseFailure = nil
    }

    private func handle(_ event: LivePoseEvent) {
        switch event {
        case let .stateChanged(state):
            streamState = state
        case let .observation(observation):
            do {
                let output = try posePipeline.observe(
                    observation,
                    phoneStable: motionMonitor.isStable
                )
                latestPoseFrame = output.latestPoseFrame
                assessment = output.setupAssessment
                activeSetPoseStatus = output.activeSetPoseStatus
            } catch let error as ActiveSetPoseIngestionError {
                activeSetPoseStatus = posePipeline.activeSetPoseStatus
                activeSetPoseFailure = error
            } catch {
                assertionFailure("Unexpected pose observation pipeline error: \(error)")
            }
        case .captureDropped:
            captureDroppedFrames += 1
        case .inferenceFailed:
            break
        case let .deliveryBoundary(id):
            finishDeliveryBoundary(id)
        }
    }

    private func handleEventDeliveryDrop(_ droppedCount: UInt64) {
        eventDeliveryDroppedFrames = Int(droppedCount)
        let activeSetDeliveryWasAffected = droppedCount > activeSetDeliveryDropBaseline
        if activeSetDeliveryWasAffected,
           posePipeline.activeSetPosePhase == .recording {
            activeSetPoseStatus = posePipeline.invalidateActiveSetForEventDeliveryDrop()
            activeSetPoseFailure = .eventDeliveryDropped
        }

        guard activeSetDeliveryWasAffected else {
            return
        }
        let pendingContinuations = Array(boundaryContinuations.values)
        boundaryContinuations.removeAll()
        for continuation in pendingContinuations {
            continuation.resume(throwing: ActiveSetPoseIngestionError.eventDeliveryDropped)
        }
    }

    private func cancelDeliveryBoundary(_ id: UUID) {
        boundaryContinuations.removeValue(forKey: id)?.resume(
            throwing: CancellationError()
        )
    }

    private func finishDeliveryBoundary(_ id: UUID) {
        guard let continuation = boundaryContinuations.removeValue(forKey: id) else {
            return
        }
        guard camera.eventDeliveryDropCount == activeSetDeliveryDropBaseline else {
            activeSetPoseStatus = posePipeline.invalidateActiveSetForEventDeliveryDrop()
            activeSetPoseFailure = .eventDeliveryDropped
            continuation.resume(throwing: ActiveSetPoseIngestionError.eventDeliveryDropped)
            return
        }
        do {
            let sequence = try posePipeline.stopActiveSet()
            activeSetPoseStatus = posePipeline.activeSetPoseStatus
            continuation.resume(returning: sequence)
        } catch {
            continuation.resume(throwing: error)
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
