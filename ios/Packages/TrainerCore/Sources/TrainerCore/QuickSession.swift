import Foundation

public struct SetDraft: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let ordinal: Int
    public let exerciseID: ExerciseID
    public let load: TrainingLoad?
    public let setupGateOutcome: SetupGateOutcome?

    init(
        id: UUID,
        ordinal: Int,
        exerciseID: ExerciseID,
        load: TrainingLoad? = nil,
        setupGateOutcome: SetupGateOutcome? = nil
    ) {
        precondition(ordinal > 0, "Set ordinals must be positive")
        precondition(
            setupGateOutcome == nil || load != nil,
            "A setup-gate outcome requires a loaded set draft"
        )
        self.id = id
        self.ordinal = ordinal
        self.exerciseID = exerciseID
        self.load = load
        self.setupGateOutcome = setupGateOutcome
    }
}

public struct CompletedSetSummary: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let ordinal: Int
    public let exerciseID: ExerciseID
    public let load: TrainingLoad
    public let setupGateOutcome: SetupGateOutcome?
    public let completedAt: Date

    init(
        draft: SetDraft,
        completedAt: Date
    ) {
        guard let load = draft.load else {
            preconditionFailure("A completed set summary requires load")
        }

        id = draft.id
        ordinal = draft.ordinal
        exerciseID = draft.exerciseID
        self.load = load
        setupGateOutcome = draft.setupGateOutcome
        self.completedAt = completedAt
    }
}

public enum QuickSessionError: Error, Equatable, Sendable {
    case sessionEnded
    case missingLoad
    case missingSetupGateOutcome
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
        guard currentSet.setupGateOutcome != nil else {
            throw QuickSessionError.missingSetupGateOutcome
        }

        return finalizeCurrentSet(
            load: load,
            completedAt: completedAt,
            nextSetID: nextSetID
        )
    }

    @discardableResult
    public mutating func advanceCurrentSetForCameraIndependentTesting(
        at completedAt: Date = Date(),
        nextSetID: UUID = UUID()
    ) throws -> CompletedSetSummary {
        guard isActive else {
            throw QuickSessionError.sessionEnded
        }
        guard let load = currentSet.load else {
            throw QuickSessionError.missingLoad
        }

        return finalizeCurrentSet(
            load: load,
            completedAt: completedAt,
            nextSetID: nextSetID
        )
    }

    private mutating func finalizeCurrentSet(
        load: TrainingLoad,
        completedAt: Date,
        nextSetID: UUID
    ) -> CompletedSetSummary {
        let completedSet = CompletedSetSummary(
            draft: currentSet,
            completedAt: completedAt
        )
        completedSets.append(completedSet)
        currentSet = SetDraft(
            id: nextSetID,
            ordinal: currentSet.ordinal + 1,
            exerciseID: exerciseID,
            load: load,
            setupGateOutcome: nil
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
            load: load,
            setupGateOutcome: currentSet.setupGateOutcome
        )
    }

    public mutating func setCurrentSetSetupGateOutcome(_ outcome: SetupGateOutcome) throws {
        guard isActive else {
            throw QuickSessionError.sessionEnded
        }
        guard let load = currentSet.load else {
            throw QuickSessionError.missingLoad
        }

        currentSet = SetDraft(
            id: currentSet.id,
            ordinal: currentSet.ordinal,
            exerciseID: currentSet.exerciseID,
            load: load,
            setupGateOutcome: outcome
        )
    }

    public mutating func end(at endedAt: Date = Date()) throws {
        guard isActive else {
            throw QuickSessionError.sessionEnded
        }

        self.endedAt = endedAt
    }
}
