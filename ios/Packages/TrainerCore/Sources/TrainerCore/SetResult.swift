import Foundation

public struct SetResultIdentity: Equatable, Sendable {
    public let setID: UUID
    public let workoutID: UUID
    public let sessionID: UUID
    public let ordinal: Int
    public let exerciseID: ExerciseID

    public init(
        setID: UUID,
        workoutID: UUID,
        sessionID: UUID,
        ordinal: Int,
        exerciseID: ExerciseID
    ) {
        self.setID = setID
        self.workoutID = workoutID
        self.sessionID = sessionID
        self.ordinal = ordinal
        self.exerciseID = exerciseID
    }
}

public struct SetResultTimestamps: Equatable, Sendable {
    public let sessionStartedAt: Date
    public let completedAt: Date

    public init(sessionStartedAt: Date, completedAt: Date) {
        self.sessionStartedAt = sessionStartedAt
        self.completedAt = completedAt
    }
}

public struct SetResultLoadEvidence: Equatable, Sendable {
    public let original: TrainingLoad
    public let corrected: TrainingLoad

    public init(original: TrainingLoad, corrected: TrainingLoad) {
        self.original = original
        self.corrected = corrected
    }
}

public struct SetResultCountedRepEvidence: Equatable, Sendable {
    public let provisional: Int
    public let analyzerFinalized: Int
    public let finalized: Int

    public init(provisional: Int, analyzerFinalized: Int, finalized: Int) {
        self.provisional = provisional
        self.analyzerFinalized = analyzerFinalized
        self.finalized = finalized
    }
}

public enum SetResultCleanEvidence: Equatable, Sendable {
    case analyzerAssessed(cleanReps: Int)
    case userCorrected(cleanReps: Int)
    case unavailable
    case missing
}

public enum SetResultFormEvidence: Equatable, Sendable {
    case assessed(primaryTakeaway: String?)
    case unavailable
    case missing
}

public enum SetResultCaptureConfidence: String, Equatable, Sendable {
    case standard
    case low
    case unavailable
}

public enum SetResultSetupEvidence: Equatable, Sendable {
    case assessed(
        disposition: SetupGateDisposition,
        decidedAt: Date,
        checks: [SetupCheck]
    )
    case missing
}

public struct SetResultCaptureEvidence: Equatable, Sendable {
    public let confidence: SetResultCaptureConfidence
    public let setup: SetResultSetupEvidence

    public init(
        confidence: SetResultCaptureConfidence,
        setup: SetResultSetupEvidence
    ) {
        self.confidence = confidence
        self.setup = setup
    }
}

public struct SetResultModelComponentMetadata: Equatable, Sendable {
    public let name: String
    public let version: String?
    public let configuration: [String: String]

    public init(
        name: String,
        version: String? = nil,
        configuration: [String: String] = [:]
    ) {
        self.name = name
        self.version = version
        self.configuration = configuration
    }
}

public struct SetResultModelMetadata: Equatable, Sendable {
    public let poseEngine: SetResultModelComponentMetadata?
    public let analyzer: SetResultModelComponentMetadata?

    public init(
        poseEngine: SetResultModelComponentMetadata?,
        analyzer: SetResultModelComponentMetadata?
    ) {
        self.poseEngine = poseEngine
        self.analyzer = analyzer
    }

    public static let unavailable = SetResultModelMetadata(
        poseEngine: nil,
        analyzer: nil
    )
}

public enum SetResultCorrectionValue: Equatable, Sendable {
    case load(TrainingLoad)
    case countedReps(Int)
    case cleanReps(Int)
    case unavailable
}

public struct SetResultCorrection: Equatable, Sendable {
    public let order: Int
    public let createdAt: Date
    public let field: SetCorrectionField
    public let previousValue: SetResultCorrectionValue
    public let newValue: SetResultCorrectionValue
    public let reason: SetCorrectionReason

    public init(
        order: Int,
        createdAt: Date,
        field: SetCorrectionField,
        previousValue: SetResultCorrectionValue,
        newValue: SetResultCorrectionValue,
        reason: SetCorrectionReason
    ) {
        self.order = order
        self.createdAt = createdAt
        self.field = field
        self.previousValue = previousValue
        self.newValue = newValue
        self.reason = reason
    }
}

public struct SetResultArtifactReferences: Equatable, Sendable {
    public let videoAssetID: String?
    public let overlayAssetID: String?
    public let poseExportAssetID: String?

    public init(
        videoAssetID: String? = nil,
        overlayAssetID: String? = nil,
        poseExportAssetID: String? = nil
    ) {
        self.videoAssetID = videoAssetID
        self.overlayAssetID = overlayAssetID
        self.poseExportAssetID = poseExportAssetID
    }

    public static let none = SetResultArtifactReferences()
}

public struct SetResultAnalysisEvidence: Equatable, Sendable {
    public let analyzerClean: SetResultCleanEvidence
    public let clean: SetResultCleanEvidence
    public let form: SetResultFormEvidence
    public let reps: [SetRepSummary]
    public let framesObserved: Int
    public let framesAnalyzed: Int
    public let modelMetadata: SetResultModelMetadata

    public init(
        analyzerClean: SetResultCleanEvidence,
        clean: SetResultCleanEvidence,
        form: SetResultFormEvidence,
        reps: [SetRepSummary],
        framesObserved: Int,
        framesAnalyzed: Int,
        modelMetadata: SetResultModelMetadata
    ) {
        self.analyzerClean = analyzerClean
        self.clean = clean
        self.form = form
        self.reps = reps
        self.framesObserved = framesObserved
        self.framesAnalyzed = framesAnalyzed
        self.modelMetadata = modelMetadata
    }
}

public enum SetResultError: Error, Equatable, Sendable {
    case completedSetNotInSession
    case missingFinalizedAnalysis
    case missingCountedRepEvidence
    case missingCleanEvidence
}

/// The canonical structured record at the local persistence boundary.
///
/// Heavy video/image data and per-frame pose streams are deliberately absent.
/// Only optional opaque artifact identifiers may cross this boundary.
public struct SetResult: Equatable, Identifiable, Sendable {
    public static let currentSchemaVersion = 1

    public var id: UUID { identity.setID }

    public let schemaVersion: Int
    public let identity: SetResultIdentity
    public let timestamps: SetResultTimestamps
    public let load: SetResultLoadEvidence
    public let countedReps: SetResultCountedRepEvidence
    public let capture: SetResultCaptureEvidence
    public let analysis: SetResultAnalysisEvidence
    public let corrections: [SetResultCorrection]
    public let artifacts: SetResultArtifactReferences

    public init(
        schemaVersion: Int = SetResult.currentSchemaVersion,
        identity: SetResultIdentity,
        timestamps: SetResultTimestamps,
        load: SetResultLoadEvidence,
        countedReps: SetResultCountedRepEvidence,
        capture: SetResultCaptureEvidence,
        analysis: SetResultAnalysisEvidence,
        corrections: [SetResultCorrection],
        artifacts: SetResultArtifactReferences = .none
    ) {
        self.schemaVersion = schemaVersion
        self.identity = identity
        self.timestamps = timestamps
        self.load = load
        self.countedReps = countedReps
        self.capture = capture
        self.analysis = analysis
        self.corrections = corrections
        self.artifacts = artifacts
    }

    public init(
        session: QuickSession,
        completedSet: CompletedSetSummary,
        artifacts: SetResultArtifactReferences = .none
    ) throws {
        guard session.completedSets.contains(where: { $0.id == completedSet.id }) else {
            throw SetResultError.completedSetNotInSession
        }
        guard let analysis = completedSet.analysis else {
            throw SetResultError.missingFinalizedAnalysis
        }
        guard let finalizedCountedReps = completedSet.countedReps else {
            throw SetResultError.missingCountedRepEvidence
        }
        guard let reviewedCleanResult = completedSet.cleanResult else {
            throw SetResultError.missingCleanEvidence
        }

        let cleanEvidence: SetResultCleanEvidence = switch reviewedCleanResult {
        case let .analyzerAssessed(cleanReps):
            .analyzerAssessed(cleanReps: cleanReps)
        case let .userCorrected(cleanReps):
            .userCorrected(cleanReps: cleanReps)
        case .unavailable:
            .unavailable
        }
        let analyzerCleanEvidence: SetResultCleanEvidence = switch analysis.cleanResult {
        case let .assessed(cleanReps):
            .analyzerAssessed(cleanReps: cleanReps)
        case .unavailable:
            .unavailable
        }

        let setupEvidence: SetResultSetupEvidence
        let captureConfidence: SetResultCaptureConfidence
        if let setup = completedSet.setupGateOutcome {
            setupEvidence = .assessed(
                disposition: setup.disposition,
                decidedAt: setup.decidedAt,
                checks: setup.checks
            )
            captureConfidence = setup.overrideUsed ? .low : .standard
        } else {
            setupEvidence = .missing
            captureConfidence = .unavailable
        }

        self.init(
            identity: SetResultIdentity(
                setID: completedSet.id,
                workoutID: session.id,
                sessionID: session.id,
                ordinal: completedSet.ordinal,
                exerciseID: completedSet.exerciseID
            ),
            timestamps: SetResultTimestamps(
                sessionStartedAt: session.startedAt,
                completedAt: completedSet.completedAt
            ),
            load: SetResultLoadEvidence(
                original: completedSet.originalLoad,
                corrected: completedSet.load
            ),
            countedReps: SetResultCountedRepEvidence(
                provisional: analysis.provisionalCountedReps,
                analyzerFinalized: analysis.finalizedCountedReps,
                finalized: finalizedCountedReps
            ),
            capture: SetResultCaptureEvidence(
                confidence: captureConfidence,
                setup: setupEvidence
            ),
            analysis: SetResultAnalysisEvidence(
                analyzerClean: analyzerCleanEvidence,
                clean: cleanEvidence,
                form: .unavailable,
                reps: analysis.reps,
                framesObserved: analysis.framesObserved,
                framesAnalyzed: analysis.framesAnalyzed,
                modelMetadata: analysis.modelMetadata
            ),
            corrections: completedSet.userCorrections.enumerated().map { index, correction in
                SetResultCorrection(
                    order: index,
                    createdAt: correction.createdAt,
                    field: correction.field,
                    previousValue: Self.persistenceValue(correction.previousValue),
                    newValue: Self.persistenceValue(correction.newValue),
                    reason: correction.reason
                )
            },
            artifacts: artifacts
        )
    }

    private static func persistenceValue(
        _ value: SetCorrectionValue
    ) -> SetResultCorrectionValue {
        switch value {
        case let .load(load):
            .load(load)
        case let .countedReps(count):
            .countedReps(count)
        case let .cleanReps(count):
            .cleanReps(count)
        case .unavailable:
            .unavailable
        }
    }
}
