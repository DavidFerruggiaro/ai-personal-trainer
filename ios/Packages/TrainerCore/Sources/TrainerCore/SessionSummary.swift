import Foundation

public enum SessionSetCaptureConfidence: Equatable, Sendable {
    case standard
    case low
    case unavailable
}

public struct SessionSetSummary: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let ordinal: Int
    public let exerciseID: ExerciseID
    public let completedAt: Date
    public let load: TrainingLoad
    public let countedReps: Int?
    public let cleanResult: ReviewedSetCleanResult?
    public let captureConfidence: SessionSetCaptureConfidence

    init(completedSet: CompletedSetSummary) {
        id = completedSet.id
        ordinal = completedSet.ordinal
        exerciseID = completedSet.exerciseID
        completedAt = completedSet.completedAt
        load = completedSet.load
        countedReps = completedSet.countedReps
        cleanResult = completedSet.cleanResult
        captureConfidence = switch completedSet.setupGateOutcome?.disposition {
        case .passed:
            .standard
        case .overridden:
            .low
        case .none:
            .unavailable
        }
    }
}

public struct QuickSessionSummary: Equatable, Sendable {
    public let sessionID: UUID
    public let exerciseID: ExerciseID
    public let startedAt: Date
    public let endedAt: Date
    public let sets: [SessionSetSummary]

    public var totalCountedReps: Int? {
        let counts = sets.compactMap(\.countedReps)
        guard counts.count == sets.count else {
            return nil
        }
        return counts.reduce(0, +)
    }

    public var lowConfidenceCaptureCount: Int {
        sets.lazy.filter { $0.captureConfidence == .low }.count
    }

    init(session: QuickSession, endedAt: Date) {
        sessionID = session.id
        exerciseID = session.exerciseID
        startedAt = session.startedAt
        self.endedAt = endedAt
        sets = session.completedSets.map(SessionSetSummary.init)
    }
}
