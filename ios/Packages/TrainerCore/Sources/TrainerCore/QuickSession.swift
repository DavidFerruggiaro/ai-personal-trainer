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
    public let originalLoad: TrainingLoad
    public let setupGateOutcome: SetupGateOutcome?
    public let analysis: SetAnalysisSummary?
    public let completedAt: Date
    public private(set) var userCorrections: [SetCorrection]

    public var load: TrainingLoad {
        userCorrections.reduce(originalLoad) { load, correction in
            guard case let .load(correctedLoad) = correction.newValue else {
                return load
            }
            return correctedLoad
        }
    }

    public var countedReps: Int? {
        guard let analysis else {
            return nil
        }
        return userCorrections.reduce(analysis.finalizedCountedReps) { count, correction in
            guard case let .countedReps(correctedCount) = correction.newValue else {
                return count
            }
            return correctedCount
        }
    }

    public var cleanResult: ReviewedSetCleanResult? {
        guard let analysis else {
            return nil
        }
        let originalResult: ReviewedSetCleanResult = switch analysis.cleanResult {
        case let .assessed(cleanReps):
            .analyzerAssessed(cleanReps: cleanReps)
        case .unavailable:
            .unavailable
        }
        return userCorrections.reduce(originalResult) { result, correction in
            guard case let .cleanReps(correctedCount) = correction.newValue else {
                return result
            }
            return .userCorrected(cleanReps: correctedCount)
        }
    }

    init(
        draft: SetDraft,
        analysis: SetAnalysisSummary? = nil,
        completedAt: Date
    ) {
        guard let load = draft.load else {
            preconditionFailure("A completed set summary requires load")
        }

        id = draft.id
        ordinal = draft.ordinal
        exerciseID = draft.exerciseID
        originalLoad = load
        setupGateOutcome = draft.setupGateOutcome
        self.analysis = analysis
        self.completedAt = completedAt
        userCorrections = []
    }

    mutating func append(_ correction: SetCorrection) {
        userCorrections.append(correction)
    }
}

public enum QuickSessionError: Error, Equatable, Sendable {
    case sessionEnded
    case missingLoad
    case missingSetupGateOutcome
    case completedSetNotReviewable
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
        analysis: SetAnalysisSummary,
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
            analysis: analysis,
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
            analysis: nil,
            completedAt: completedAt,
            nextSetID: nextSetID
        )
    }

    private mutating func finalizeCurrentSet(
        load: TrainingLoad,
        analysis: SetAnalysisSummary?,
        completedAt: Date,
        nextSetID: UUID
    ) -> CompletedSetSummary {
        let completedSet = CompletedSetSummary(
            draft: currentSet,
            analysis: analysis,
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

    public mutating func clearCurrentSetSetupGateOutcome() throws {
        guard isActive else {
            throw QuickSessionError.sessionEnded
        }

        currentSet = SetDraft(
            id: currentSet.id,
            ordinal: currentSet.ordinal,
            exerciseID: currentSet.exerciseID,
            load: currentSet.load,
            setupGateOutcome: nil
        )
    }

    public mutating func correctReviewedSetLoad(
        _ completedSetID: UUID,
        to load: TrainingLoad,
        at correctedAt: Date = Date()
    ) throws {
        guard isActive else {
            throw QuickSessionError.sessionEnded
        }
        guard let completedSet = completedSets.last,
              completedSet.id == completedSetID,
              currentSet.ordinal == completedSet.ordinal + 1 else {
            throw QuickSessionError.completedSetNotReviewable
        }

        let correction = SetCorrection(
            createdAt: correctedAt,
            field: .load,
            previousValue: .load(completedSet.load),
            newValue: .load(load),
            reason: .userEdit
        )
        completedSets[completedSets.index(before: completedSets.endIndex)].append(correction)
        currentSet = SetDraft(
            id: currentSet.id,
            ordinal: currentSet.ordinal,
            exerciseID: currentSet.exerciseID,
            load: load,
            setupGateOutcome: currentSet.setupGateOutcome
        )
    }

    public mutating func correctReviewedSetCountedReps(
        _ completedSetID: UUID,
        to countedReps: Int,
        at correctedAt: Date = Date()
    ) throws {
        guard countedReps >= 0 else {
            throw SetCorrectionError.negativeCount(field: .countedReps)
        }
        guard isActive else {
            throw QuickSessionError.sessionEnded
        }
        guard let completedSet = completedSets.last,
              completedSet.id == completedSetID,
              currentSet.ordinal == completedSet.ordinal + 1,
              let previousCountedReps = completedSet.countedReps,
              let cleanResult = completedSet.cleanResult else {
            throw QuickSessionError.completedSetNotReviewable
        }
        let cleanReps: Int? = switch cleanResult {
        case let .analyzerAssessed(cleanReps), let .userCorrected(cleanReps):
            cleanReps
        case .unavailable:
            nil
        }
        if let cleanReps, cleanReps > countedReps {
            throw SetCorrectionError.cleanRepsExceedCounted(
                cleanReps: cleanReps,
                countedReps: countedReps
            )
        }

        let correction = SetCorrection(
            createdAt: correctedAt,
            field: .countedReps,
            previousValue: .countedReps(previousCountedReps),
            newValue: .countedReps(countedReps),
            reason: .userEdit
        )
        completedSets[completedSets.index(before: completedSets.endIndex)].append(correction)
    }

    public mutating func correctReviewedSetCleanReps(
        _ completedSetID: UUID,
        to cleanReps: Int,
        at correctedAt: Date = Date()
    ) throws {
        guard cleanReps >= 0 else {
            throw SetCorrectionError.negativeCount(field: .cleanReps)
        }
        guard isActive else {
            throw QuickSessionError.sessionEnded
        }
        guard let completedSet = completedSets.last,
              completedSet.id == completedSetID,
              currentSet.ordinal == completedSet.ordinal + 1,
              let countedReps = completedSet.countedReps,
              let previousCleanResult = completedSet.cleanResult else {
            throw QuickSessionError.completedSetNotReviewable
        }
        guard cleanReps <= countedReps else {
            throw SetCorrectionError.cleanRepsExceedCounted(
                cleanReps: cleanReps,
                countedReps: countedReps
            )
        }

        let previousValue: SetCorrectionValue = switch previousCleanResult {
        case let .analyzerAssessed(cleanReps), let .userCorrected(cleanReps):
            .cleanReps(cleanReps)
        case .unavailable:
            .unavailable
        }
        let correction = SetCorrection(
            createdAt: correctedAt,
            field: .cleanReps,
            previousValue: previousValue,
            newValue: .cleanReps(cleanReps),
            reason: .userEdit
        )
        completedSets[completedSets.index(before: completedSets.endIndex)].append(correction)
    }

    public mutating func discardCompletedSetFromReview(_ completedSetID: UUID) throws {
        guard isActive else {
            throw QuickSessionError.sessionEnded
        }
        guard let completedSet = completedSets.last,
              completedSet.id == completedSetID,
              currentSet.ordinal == completedSet.ordinal + 1 else {
            throw QuickSessionError.completedSetNotReviewable
        }

        completedSets.removeLast()
        currentSet = SetDraft(
            id: currentSet.id,
            ordinal: completedSet.ordinal,
            exerciseID: exerciseID,
            load: completedSet.load,
            setupGateOutcome: nil
        )
    }

    public mutating func end(at endedAt: Date = Date()) throws {
        guard isActive else {
            throw QuickSessionError.sessionEnded
        }

        self.endedAt = endedAt
    }
}
