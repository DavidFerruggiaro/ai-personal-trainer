import Foundation

public struct SetDraft: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let ordinal: Int
    public let exerciseID: ExerciseID
    public let load: TrainingLoad?

    public init(
        id: UUID,
        ordinal: Int,
        exerciseID: ExerciseID,
        load: TrainingLoad? = nil
    ) {
        precondition(ordinal > 0, "Set ordinals must be positive")
        self.id = id
        self.ordinal = ordinal
        self.exerciseID = exerciseID
        self.load = load
    }
}

public struct CompletedSetSummary: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let ordinal: Int
    public let exerciseID: ExerciseID
    public let load: TrainingLoad
    public let completedAt: Date

    public init(draft: SetDraft, load: TrainingLoad, completedAt: Date) {
        id = draft.id
        ordinal = draft.ordinal
        exerciseID = draft.exerciseID
        self.load = load
        self.completedAt = completedAt
    }
}

public enum QuickSessionError: Error, Equatable, Sendable {
    case sessionEnded
    case missingLoad
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

        guard let load = currentSet.load else {
            throw QuickSessionError.missingLoad
        }

        let completedSet = CompletedSetSummary(
            draft: currentSet,
            load: load,
            completedAt: completedAt
        )
        completedSets.append(completedSet)
        currentSet = SetDraft(
            id: nextSetID,
            ordinal: currentSet.ordinal + 1,
            exerciseID: exerciseID,
            load: load
        )
        return completedSet
    }

    public mutating func setCurrentSetLoad(_ load: TrainingLoad) throws {
        guard isActive else {
            throw QuickSessionError.sessionEnded
        }

        currentSet = SetDraft(
            id: currentSet.id,
            ordinal: currentSet.ordinal,
            exerciseID: currentSet.exerciseID,
            load: load
        )
    }

    public mutating func end(at endedAt: Date = Date()) throws {
        guard isActive else {
            throw QuickSessionError.sessionEnded
        }

        self.endedAt = endedAt
    }
}
