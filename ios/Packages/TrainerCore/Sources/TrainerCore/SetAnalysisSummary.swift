import Foundation

public enum SetCleanResult: Equatable, Sendable {
    case assessed(cleanReps: Int)
    case unavailable
}

public enum SetRepQuality: Equatable, Sendable {
    case clean
    case notClean
    case unavailable
}

public struct SetRepSummary: Equatable, Identifiable, Sendable {
    public var id: Int { index }

    public let index: Int
    public let startSeconds: Double
    public let bottomSeconds: Double
    public let endSeconds: Double
    public let countConfidence: Double
    public let quality: SetRepQuality

    public init(
        index: Int,
        startSeconds: Double,
        bottomSeconds: Double,
        endSeconds: Double,
        countConfidence: Double,
        quality: SetRepQuality
    ) {
        precondition(index > 0, "Rep indices must be positive")
        self.index = index
        self.startSeconds = startSeconds
        self.bottomSeconds = bottomSeconds
        self.endSeconds = endSeconds
        self.countConfidence = countConfidence
        self.quality = quality
    }
}

public struct SetAnalysisSummary: Equatable, Sendable {
    public let provisionalCountedReps: Int
    public let finalizedCountedReps: Int
    public let cleanResult: SetCleanResult
    public let reps: [SetRepSummary]
    public let framesObserved: Int
    public let framesAnalyzed: Int

    public init(
        provisionalCountedReps: Int,
        finalizedCountedReps: Int,
        cleanResult: SetCleanResult,
        reps: [SetRepSummary],
        framesObserved: Int,
        framesAnalyzed: Int
    ) {
        precondition(provisionalCountedReps >= 0, "Provisional rep count cannot be negative")
        precondition(finalizedCountedReps >= 0, "Finalized rep count cannot be negative")
        precondition(framesObserved >= 0, "Observed frame count cannot be negative")
        precondition(framesAnalyzed >= 0, "Analyzed frame count cannot be negative")
        self.provisionalCountedReps = provisionalCountedReps
        self.finalizedCountedReps = finalizedCountedReps
        self.cleanResult = cleanResult
        self.reps = reps
        self.framesObserved = framesObserved
        self.framesAnalyzed = framesAnalyzed
    }
}
