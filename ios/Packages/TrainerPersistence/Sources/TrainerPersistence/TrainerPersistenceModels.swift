import Foundation
import SwiftData

@Model
final class WorkoutRecord {
    @Attribute(.unique) var id: UUID
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID, schemaVersion: Int, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class WorkoutSessionRecord {
    @Attribute(.unique) var id: UUID
    var workoutID: UUID
    var schemaVersion: Int
    var exerciseIDRaw: String
    var startedAt: Date
    var endedAt: Date?
    var updatedAt: Date

    init(
        id: UUID,
        workoutID: UUID,
        schemaVersion: Int,
        exerciseIDRaw: String,
        startedAt: Date,
        endedAt: Date?,
        updatedAt: Date
    ) {
        self.id = id
        self.workoutID = workoutID
        self.schemaVersion = schemaVersion
        self.exerciseIDRaw = exerciseIDRaw
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.updatedAt = updatedAt
    }
}

@Model
final class PersistedSetRecord {
    @Attribute(.unique) var id: UUID
    var workoutID: UUID
    var sessionID: UUID
    var schemaVersion: Int
    var ordinal: Int
    var exerciseIDRaw: String
    var sessionStartedAt: Date
    var completedAt: Date
    var updatedAt: Date

    var originalLoadValue: Double
    var originalLoadUnitRaw: String
    var correctedLoadValue: Double
    var correctedLoadUnitRaw: String

    var provisionalCountedReps: Int
    var analyzerFinalizedCountedReps: Int
    var finalizedCountedReps: Int

    var analyzerCleanEvidenceRaw: String
    var analyzerCleanReps: Int?
    var cleanEvidenceRaw: String
    var cleanReps: Int?
    var formEvidenceRaw: String
    var primaryFeedbackTakeaway: String?

    var captureConfidenceRaw: String
    var setupEvidenceRaw: String
    var setupDispositionRaw: String?
    var setupDecidedAt: Date?

    var framesObserved: Int
    var framesAnalyzed: Int
    var poseEngineName: String?
    var poseEngineVersion: String?
    var analyzerName: String?
    var analyzerVersion: String?

    var videoAssetID: String?
    var overlayAssetID: String?
    var poseExportAssetID: String?

    init(
        id: UUID,
        workoutID: UUID,
        sessionID: UUID,
        schemaVersion: Int,
        ordinal: Int,
        exerciseIDRaw: String,
        sessionStartedAt: Date,
        completedAt: Date,
        updatedAt: Date,
        originalLoadValue: Double,
        originalLoadUnitRaw: String,
        correctedLoadValue: Double,
        correctedLoadUnitRaw: String,
        provisionalCountedReps: Int,
        analyzerFinalizedCountedReps: Int,
        finalizedCountedReps: Int,
        analyzerCleanEvidenceRaw: String,
        analyzerCleanReps: Int?,
        cleanEvidenceRaw: String,
        cleanReps: Int?,
        formEvidenceRaw: String,
        primaryFeedbackTakeaway: String?,
        captureConfidenceRaw: String,
        setupEvidenceRaw: String,
        setupDispositionRaw: String?,
        setupDecidedAt: Date?,
        framesObserved: Int,
        framesAnalyzed: Int,
        poseEngineName: String?,
        poseEngineVersion: String?,
        analyzerName: String?,
        analyzerVersion: String?,
        videoAssetID: String?,
        overlayAssetID: String?,
        poseExportAssetID: String?
    ) {
        self.id = id
        self.workoutID = workoutID
        self.sessionID = sessionID
        self.schemaVersion = schemaVersion
        self.ordinal = ordinal
        self.exerciseIDRaw = exerciseIDRaw
        self.sessionStartedAt = sessionStartedAt
        self.completedAt = completedAt
        self.updatedAt = updatedAt
        self.originalLoadValue = originalLoadValue
        self.originalLoadUnitRaw = originalLoadUnitRaw
        self.correctedLoadValue = correctedLoadValue
        self.correctedLoadUnitRaw = correctedLoadUnitRaw
        self.provisionalCountedReps = provisionalCountedReps
        self.analyzerFinalizedCountedReps = analyzerFinalizedCountedReps
        self.finalizedCountedReps = finalizedCountedReps
        self.analyzerCleanEvidenceRaw = analyzerCleanEvidenceRaw
        self.analyzerCleanReps = analyzerCleanReps
        self.cleanEvidenceRaw = cleanEvidenceRaw
        self.cleanReps = cleanReps
        self.formEvidenceRaw = formEvidenceRaw
        self.primaryFeedbackTakeaway = primaryFeedbackTakeaway
        self.captureConfidenceRaw = captureConfidenceRaw
        self.setupEvidenceRaw = setupEvidenceRaw
        self.setupDispositionRaw = setupDispositionRaw
        self.setupDecidedAt = setupDecidedAt
        self.framesObserved = framesObserved
        self.framesAnalyzed = framesAnalyzed
        self.poseEngineName = poseEngineName
        self.poseEngineVersion = poseEngineVersion
        self.analyzerName = analyzerName
        self.analyzerVersion = analyzerVersion
        self.videoAssetID = videoAssetID
        self.overlayAssetID = overlayAssetID
        self.poseExportAssetID = poseExportAssetID
    }
}

@Model
final class PersistedRepRecord {
    var id: UUID
    var setID: UUID
    var order: Int
    var repIndex: Int
    var startSeconds: Double
    var bottomSeconds: Double
    var endSeconds: Double
    var countConfidence: Double
    var qualityRaw: String

    init(
        id: UUID = UUID(),
        setID: UUID,
        order: Int,
        repIndex: Int,
        startSeconds: Double,
        bottomSeconds: Double,
        endSeconds: Double,
        countConfidence: Double,
        qualityRaw: String
    ) {
        self.id = id
        self.setID = setID
        self.order = order
        self.repIndex = repIndex
        self.startSeconds = startSeconds
        self.bottomSeconds = bottomSeconds
        self.endSeconds = endSeconds
        self.countConfidence = countConfidence
        self.qualityRaw = qualityRaw
    }
}

@Model
final class PersistedSetupCheckRecord {
    var id: UUID
    var setID: UUID
    var order: Int
    var checkIDRaw: String
    var statusRaw: String

    init(
        id: UUID = UUID(),
        setID: UUID,
        order: Int,
        checkIDRaw: String,
        statusRaw: String
    ) {
        self.id = id
        self.setID = setID
        self.order = order
        self.checkIDRaw = checkIDRaw
        self.statusRaw = statusRaw
    }
}

@Model
final class PersistedCorrectionRecord {
    var id: UUID
    var setID: UUID
    var order: Int
    var createdAt: Date
    var fieldRaw: String
    var reasonRaw: String
    var previousValueKindRaw: String
    var previousNumericValue: Double?
    var previousUnitRaw: String?
    var newValueKindRaw: String
    var newNumericValue: Double?
    var newUnitRaw: String?

    init(
        id: UUID = UUID(),
        setID: UUID,
        order: Int,
        createdAt: Date,
        fieldRaw: String,
        reasonRaw: String,
        previousValueKindRaw: String,
        previousNumericValue: Double?,
        previousUnitRaw: String?,
        newValueKindRaw: String,
        newNumericValue: Double?,
        newUnitRaw: String?
    ) {
        self.id = id
        self.setID = setID
        self.order = order
        self.createdAt = createdAt
        self.fieldRaw = fieldRaw
        self.reasonRaw = reasonRaw
        self.previousValueKindRaw = previousValueKindRaw
        self.previousNumericValue = previousNumericValue
        self.previousUnitRaw = previousUnitRaw
        self.newValueKindRaw = newValueKindRaw
        self.newNumericValue = newNumericValue
        self.newUnitRaw = newUnitRaw
    }
}

@Model
final class PersistedMetadataEntryRecord {
    var id: UUID
    var setID: UUID
    var componentRaw: String
    var key: String
    var value: String

    init(
        id: UUID = UUID(),
        setID: UUID,
        componentRaw: String,
        key: String,
        value: String
    ) {
        self.id = id
        self.setID = setID
        self.componentRaw = componentRaw
        self.key = key
        self.value = value
    }
}

public enum TrainerPersistenceSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)
    public static let models: [any PersistentModel.Type] = [
        WorkoutRecord.self,
        WorkoutSessionRecord.self,
        PersistedSetRecord.self,
        PersistedRepRecord.self,
        PersistedSetupCheckRecord.self,
        PersistedCorrectionRecord.self,
        PersistedMetadataEntryRecord.self
    ]
}

public enum TrainerPersistenceMigrationPlan: SchemaMigrationPlan {
    public static let schemas: [any VersionedSchema.Type] = [
        TrainerPersistenceSchemaV1.self
    ]
    public static let stages: [MigrationStage] = []
}
