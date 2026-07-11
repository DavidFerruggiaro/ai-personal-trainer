import Foundation

public enum SetCorrectionField: String, Equatable, Sendable {
    case load
    case countedReps = "counted_reps"
    case cleanReps = "clean_reps"
}

public enum SetCorrectionValue: Equatable, Sendable {
    case load(TrainingLoad)
    case countedReps(Int)
    case cleanReps(Int)
    case unavailable
}

public enum SetCorrectionReason: String, Equatable, Sendable {
    case userEdit = "user_edit"
}

public enum SetCorrectionError: Error, Equatable, Sendable {
    case negativeCount(field: SetCorrectionField)
    case cleanRepsExceedCounted(cleanReps: Int, countedReps: Int)
}

public enum ReviewedSetCleanResult: Equatable, Sendable {
    case analyzerAssessed(cleanReps: Int)
    case userCorrected(cleanReps: Int)
    case unavailable
}

public struct SetCorrection: Equatable, Sendable {
    public let createdAt: Date
    public let field: SetCorrectionField
    public let previousValue: SetCorrectionValue
    public let newValue: SetCorrectionValue
    public let reason: SetCorrectionReason

    init(
        createdAt: Date,
        field: SetCorrectionField,
        previousValue: SetCorrectionValue,
        newValue: SetCorrectionValue,
        reason: SetCorrectionReason
    ) {
        self.createdAt = createdAt
        self.field = field
        self.previousValue = previousValue
        self.newValue = newValue
        self.reason = reason
    }
}
