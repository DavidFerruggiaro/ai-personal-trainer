import Foundation
import PoseCore
import TrainerCore

public enum TrainerLivePoseConsumptionEffect: Equatable, Sendable {
    case none
    case observed
    case deliveryBoundaryCompleted
    case deliveryDropMismatch
    case deliveryBoundaryIgnored
}

@MainActor
public final class TrainerActiveSetDeliveryCoordinator {
    private let source: any LivePoseEventDelivering
    private var pipeline: TrainerPoseObservationPipeline
    private var boundaryContinuations: [
        UUID: CheckedContinuation<ActiveSetPoseSequence, Error>
    ] = [:]
    private var activeSetDeliveryDropBaseline: UInt64 = 0

    public init(
        source: any LivePoseEventDelivering,
        pipeline: TrainerPoseObservationPipeline = TrainerPoseObservationPipeline()
    ) {
        self.source = source
        self.pipeline = pipeline
    }

    public var setupAssessment: SetupGateAssessment {
        pipeline.setupAssessment
    }

    public var activeSetPoseStatus: ActiveSetPoseIngestionStatus {
        pipeline.activeSetPoseStatus
    }

    public var activeSetPosePhase: ActiveSetPoseIngestionPhase {
        pipeline.activeSetPosePhase
    }

    public func resetSetupEvidence() {
        pipeline.resetSetupEvidence()
    }

    public func begin(baseline: LivePoseDeliveryBaseline) throws {
        try pipeline.beginActiveSet(
            afterSourceSequence: baseline.latestObservationSequence
        )
        activeSetDeliveryDropBaseline = baseline.eventDeliveryDropCount
    }

    public func observe(
        _ observation: LivePoseObservation,
        phoneStable: Bool?
    ) throws -> TrainerPoseObservationOutput {
        try pipeline.observe(observation, phoneStable: phoneStable)
    }

    public func consume(
        _ event: LivePoseEvent,
        phoneStable: Bool?
    ) throws -> TrainerLivePoseConsumptionEffect {
        switch event {
        case let .observation(observation):
            _ = try observe(observation, phoneStable: phoneStable)
            return .observed
        case let .deliveryBoundary(id):
            return finishDeliveryBoundary(id)
        case .stateChanged, .captureDropped, .inferenceFailed:
            return .none
        }
    }

    public func freezeActiveSetPoseSequence() async throws -> ActiveSetPoseSequence {
        let boundaryID = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                boundaryContinuations[boundaryID] = continuation
                source.enqueueDeliveryBoundary(boundaryID)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelDeliveryBoundary(boundaryID)
            }
        }
    }

    public func discard() {
        pipeline.discardActiveSet()
    }

    public func shutdown() {
        let pendingContinuations = Array(boundaryContinuations.values)
        boundaryContinuations.removeAll()
        for continuation in pendingContinuations {
            continuation.resume(throwing: ActiveSetPoseIngestionError.invalidPhase)
        }
    }

    public func handleEventDeliveryDrop(_ droppedCount: UInt64) -> Bool {
        let activeSetDeliveryWasAffected = droppedCount > activeSetDeliveryDropBaseline
        var didInvalidate = false
        if activeSetDeliveryWasAffected,
           pipeline.activeSetPosePhase == .recording {
            _ = pipeline.invalidateActiveSetForEventDeliveryDrop()
            didInvalidate = true
        }

        guard activeSetDeliveryWasAffected else {
            return didInvalidate
        }
        let pendingContinuations = Array(boundaryContinuations.values)
        boundaryContinuations.removeAll()
        for continuation in pendingContinuations {
            continuation.resume(throwing: ActiveSetPoseIngestionError.eventDeliveryDropped)
        }
        return didInvalidate
    }

    func cancelDeliveryBoundary(_ id: UUID) {
        boundaryContinuations.removeValue(forKey: id)?.resume(
            throwing: CancellationError()
        )
    }

    @discardableResult
    public func finishDeliveryBoundary(_ id: UUID) -> TrainerLivePoseConsumptionEffect {
        guard let continuation = boundaryContinuations.removeValue(forKey: id) else {
            return .deliveryBoundaryIgnored
        }
        guard source.eventDeliveryDropCount == activeSetDeliveryDropBaseline else {
            _ = pipeline.invalidateActiveSetForEventDeliveryDrop()
            continuation.resume(throwing: ActiveSetPoseIngestionError.eventDeliveryDropped)
            return .deliveryDropMismatch
        }
        do {
            let sequence = try pipeline.stopActiveSet()
            continuation.resume(returning: sequence)
            return .deliveryBoundaryCompleted
        } catch {
            continuation.resume(throwing: error)
            return .deliveryBoundaryIgnored
        }
    }
}
