import Foundation

public struct ExerciseID: Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        precondition(!rawValue.isEmpty, "Exercise IDs must not be empty")
        self.rawValue = rawValue
    }

    public static let backSquat = ExerciseID(rawValue: "back_squat")
}

public struct SetDraft: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let ordinal: Int
    public let exerciseID: ExerciseID

    public init(id: UUID, ordinal: Int, exerciseID: ExerciseID) {
        precondition(ordinal > 0, "Set ordinals must be positive")
        self.id = id
        self.ordinal = ordinal
        self.exerciseID = exerciseID
    }
}

public struct CompletedSetSummary: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let ordinal: Int
    public let exerciseID: ExerciseID
    public let completedAt: Date

    public init(draft: SetDraft, completedAt: Date) {
        id = draft.id
        ordinal = draft.ordinal
        exerciseID = draft.exerciseID
        self.completedAt = completedAt
    }
}

public enum QuickSessionError: Error, Equatable, Sendable {
    case sessionEnded
}

public struct QuickSession: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let startedAt: Date
    public let exerciseID: ExerciseID
    public private(set) var endedAt: Date?
    public private(set) var currentSet: SetDraft
    public private(set) var completedSets: [CompletedSetSummary]

    public var isActive: Bool {
        endedAt == nil
    }

    public init(
        id: UUID = UUID(),
        exerciseID: ExerciseID,
        startedAt: Date = Date(),
        initialSetID: UUID = UUID()
    ) {
        self.id = id
        self.startedAt = startedAt
        self.exerciseID = exerciseID
        endedAt = nil
        currentSet = SetDraft(id: initialSetID, ordinal: 1, exerciseID: exerciseID)
        completedSets = []
    }

    @discardableResult
    public mutating func completeCurrentSet(
        at completedAt: Date = Date(),
        nextSetID: UUID = UUID()
    ) throws -> CompletedSetSummary {
        guard isActive else {
            throw QuickSessionError.sessionEnded
        }

        let completedSet = CompletedSetSummary(draft: currentSet, completedAt: completedAt)
        completedSets.append(completedSet)
        currentSet = SetDraft(
            id: nextSetID,
            ordinal: currentSet.ordinal + 1,
            exerciseID: exerciseID
        )
        return completedSet
    }

    public mutating func end(at endedAt: Date = Date()) throws {
        guard isActive else {
            throw QuickSessionError.sessionEnded
        }

        self.endedAt = endedAt
    }
}
