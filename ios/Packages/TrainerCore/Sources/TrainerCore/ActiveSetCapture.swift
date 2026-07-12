import Foundation

public enum ActiveSetPhase: Equatable, Sendable {
    case idle
    case recording
    case processing
    case processingFailed
    case awaitingReview
    case discarded
}

public enum ActiveSetCaptureError: Error, Equatable, Sendable {
    case invalidPhase
}

/// Camera-backed set capture lifecycle from countdown end until stop or discard.
///
/// Rep counts are supplied by the app's analyzer boundary. This type never invents reps.
public struct ActiveSetCapture: Equatable, Sendable {
    public private(set) var phase: ActiveSetPhase
    public private(set) var provisionalCountedReps: Int
    public private(set) var finalizedCountedReps: Int?
    public private(set) var framesObserved: Int
    public private(set) var discardConfirmationRequired: Bool

    public init() {
        phase = .idle
        provisionalCountedReps = 0
        finalizedCountedReps = nil
        framesObserved = 0
        discardConfirmationRequired = false
    }

    public var isRecording: Bool {
        phase == .recording
    }

    public var showsActiveSetControls: Bool {
        phase == .recording
    }

    public mutating func beginRecording() throws {
        guard phase == .idle || phase == .discarded else {
            throw ActiveSetCaptureError.invalidPhase
        }
        phase = .recording
        provisionalCountedReps = 0
        finalizedCountedReps = nil
        framesObserved = 0
        discardConfirmationRequired = false
    }

    public mutating func observeFrame() {
        guard phase == .recording else {
            return
        }
        framesObserved += 1
    }

    /// Analyzer seam. Production UI should only call this with real provisional counts.
    public mutating func updateProvisionalCountedReps(_ count: Int) {
        guard phase == .recording, count >= 0 else {
            return
        }
        provisionalCountedReps = count
    }

    public mutating func stop() throws {
        guard phase == .recording else {
            throw ActiveSetCaptureError.invalidPhase
        }
        discardConfirmationRequired = false
        phase = .processing
    }

    /// Reconciles the live count after the app runtime drains its ordered Stop boundary.
    public mutating func reconcileProvisionalCountedRepsAfterStop(_ count: Int) {
        guard phase == .processing, count >= 0 else {
            return
        }
        provisionalCountedReps = max(provisionalCountedReps, count)
    }

    public mutating func finishProcessing(finalizedCountedReps: Int) throws {
        guard phase == .processing, finalizedCountedReps >= 0 else {
            throw ActiveSetCaptureError.invalidPhase
        }
        self.finalizedCountedReps = finalizedCountedReps
        phase = .awaitingReview
    }

    public mutating func failProcessing() throws {
        guard phase == .processing else {
            throw ActiveSetCaptureError.invalidPhase
        }
        phase = .processingFailed
    }

    public mutating func retryProcessing() throws {
        guard phase == .processingFailed else {
            throw ActiveSetCaptureError.invalidPhase
        }
        phase = .processing
    }

    public mutating func requestDiscard(
        evidenceMayStillContainReps: Bool = false
    ) throws {
        switch phase {
        case .recording, .processing, .processingFailed, .awaitingReview:
            break
        case .idle, .discarded:
            throw ActiveSetCaptureError.invalidPhase
        }

        if evidenceMayStillContainReps
            || (finalizedCountedReps ?? provisionalCountedReps) > 0 {
            discardConfirmationRequired = true
        } else {
            phase = .discarded
            discardConfirmationRequired = false
        }
    }

    public mutating func confirmDiscard() throws {
        guard discardConfirmationRequired else {
            throw ActiveSetCaptureError.invalidPhase
        }
        guard phase == .recording
            || phase == .processing
            || phase == .processingFailed
            || phase == .awaitingReview else {
            throw ActiveSetCaptureError.invalidPhase
        }
        phase = .discarded
        discardConfirmationRequired = false
    }

    public mutating func cancelDiscardConfirmation() {
        discardConfirmationRequired = false
    }

    public mutating func reset() {
        phase = .idle
        provisionalCountedReps = 0
        finalizedCountedReps = nil
        framesObserved = 0
        discardConfirmationRequired = false
    }
}
