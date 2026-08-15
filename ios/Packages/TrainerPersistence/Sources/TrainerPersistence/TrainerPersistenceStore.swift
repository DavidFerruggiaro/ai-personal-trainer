import Foundation
import SwiftData
import TrainerCore

public enum TrainerPersistenceValidationFailure: Equatable, Sendable {
    case schemaVersion
    case identifier
    case ordinal
    case timestamp
    case load
    case countedReps
    case cleanEvidence
    case formEvidence
    case setupEvidence
    case repEvidence
    case correctionEvidence
    case modelMetadata
    case artifactReference
}

public enum TrainerPersistenceError: Error, Equatable, Sendable {
    case invalidSetResult(TrainerPersistenceValidationFailure)
    case corruptStoredRecord
    case duplicateStableIdentifier
}

@MainActor
public final class TrainerPersistenceStore {
    private let context: ModelContext

    public init(modelContainer: ModelContainer) {
        context = ModelContext(modelContainer)
        context.autosaveEnabled = false
    }

    public init(modelContext: ModelContext) {
        context = modelContext
    }

    /// Inserts or replaces one completed set by its stable set identifier.
    /// Parent and child mutations are committed in one SwiftData transaction.
    public func upsert(_ result: SetResult) throws {
        try validate(result)
        let updatedAt = result.corrections.last?.createdAt
            ?? result.timestamps.completedAt

        do {
            try context.transaction {
                let workout = try fetchWorkout(id: result.identity.workoutID)
                    ?? WorkoutRecord(
                        id: result.identity.workoutID,
                        schemaVersion: result.schemaVersion,
                        createdAt: result.timestamps.sessionStartedAt,
                        updatedAt: updatedAt
                    )
                workout.schemaVersion = result.schemaVersion
                workout.createdAt = min(workout.createdAt, result.timestamps.sessionStartedAt)
                workout.updatedAt = updatedAt
                if workout.modelContext == nil {
                    context.insert(workout)
                }

                let session = try fetchSession(id: result.identity.sessionID)
                    ?? WorkoutSessionRecord(
                        id: result.identity.sessionID,
                        workoutID: result.identity.workoutID,
                        schemaVersion: result.schemaVersion,
                        exerciseIDRaw: result.identity.exerciseID.rawValue,
                        startedAt: result.timestamps.sessionStartedAt,
                        endedAt: nil,
                        updatedAt: updatedAt
                    )
                session.workoutID = result.identity.workoutID
                session.schemaVersion = result.schemaVersion
                session.exerciseIDRaw = result.identity.exerciseID.rawValue
                session.startedAt = result.timestamps.sessionStartedAt
                session.updatedAt = updatedAt
                if session.modelContext == nil {
                    context.insert(session)
                }

                let setRecord = try fetchSetRecord(id: result.id)
                    ?? makeSetRecord(from: result)
                apply(result, updatedAt: updatedAt, to: setRecord)
                if setRecord.modelContext == nil {
                    context.insert(setRecord)
                }

                try deleteChildRecords(setID: result.id)
                insertChildRecords(from: result)
                try context.save()
            }
        } catch {
            context.rollback()
            throw error
        }
    }

    public func fetchSetResult(id: UUID) throws -> SetResult? {
        guard let record = try fetchSetRecord(id: id) else {
            return nil
        }

        do {
            guard let workout = try fetchWorkout(id: record.workoutID),
                  let session = try fetchSession(id: record.sessionID),
                  workout.schemaVersion == record.schemaVersion,
                  session.schemaVersion == record.schemaVersion,
                  session.workoutID == record.workoutID,
                  session.exerciseIDRaw == record.exerciseIDRaw,
                  session.startedAt == record.sessionStartedAt else {
                throw TrainerPersistenceError.corruptStoredRecord
            }
            let reps = try fetchRepRecords(setID: id).map(restoreRep)
            let setupChecks = try fetchSetupCheckRecords(setID: id).map(restoreSetupCheck)
            let corrections = try fetchCorrectionRecords(setID: id).map(restoreCorrection)
            let metadataEntries = try fetchMetadataRecords(setID: id)
            let result = try restoreSetResult(
                record,
                reps: reps,
                setupChecks: setupChecks,
                corrections: corrections,
                metadataEntries: metadataEntries
            )
            try validate(result)
            return result
        } catch let error as TrainerPersistenceError {
            throw error
        } catch {
            throw TrainerPersistenceError.corruptStoredRecord
        }
    }

    public func fetchSetResults(sessionID: UUID) throws -> [SetResult] {
        let targetID = sessionID
        let descriptor = FetchDescriptor<PersistedSetRecord>(
            predicate: #Predicate { $0.sessionID == targetID },
            sortBy: [SortDescriptor(\.ordinal)]
        )
        return try context.fetch(descriptor).map { record in
            guard let result = try fetchSetResult(id: record.id) else {
                throw TrainerPersistenceError.corruptStoredRecord
            }
            return result
        }
    }

    /// Deleting an unknown ID is an idempotent no-op.
    @discardableResult
    public func deleteSetResult(id: UUID) throws -> Bool {
        guard let record = try fetchSetRecord(id: id) else {
            return false
        }

        do {
            try context.transaction {
                let sessionID = record.sessionID
                let workoutID = record.workoutID
                let remainingSessionSetCount = try countSetRecords(
                    sessionID: sessionID,
                    excludingSetID: id
                )

                try deleteChildRecords(setID: id)
                context.delete(record)

                if remainingSessionSetCount == 0 {
                    if let session = try fetchSession(id: sessionID) {
                        context.delete(session)
                    }
                    if try countSetRecords(workoutID: workoutID, excludingSetID: id) == 0,
                       let workout = try fetchWorkout(id: workoutID) {
                        context.delete(workout)
                    }
                }
                try context.save()
            }
            return true
        } catch {
            context.rollback()
            throw error
        }
    }

    public func markSessionEnded(
        sessionID: UUID,
        workoutID: UUID,
        endedAt: Date
    ) throws {
        guard let session = try fetchSession(id: sessionID),
              let workout = try fetchWorkout(id: workoutID) else {
            return
        }

        do {
            try context.transaction {
                session.endedAt = endedAt
                session.updatedAt = endedAt
                workout.updatedAt = endedAt
                try context.save()
            }
        } catch {
            context.rollback()
            throw error
        }
    }

    public func setRecordCount() throws -> Int {
        try context.fetchCount(FetchDescriptor<PersistedSetRecord>())
    }

    private func validate(_ result: SetResult) throws {
        guard result.schemaVersion == SetResult.currentSchemaVersion else {
            throw TrainerPersistenceError.invalidSetResult(.schemaVersion)
        }
        guard !result.identity.exerciseID.rawValue.isEmpty else {
            throw TrainerPersistenceError.invalidSetResult(.identifier)
        }
        guard result.identity.ordinal > 0 else {
            throw TrainerPersistenceError.invalidSetResult(.ordinal)
        }
        guard result.timestamps.completedAt >= result.timestamps.sessionStartedAt else {
            throw TrainerPersistenceError.invalidSetResult(.timestamp)
        }
        guard result.load.original.value.isFinite,
              result.load.corrected.value.isFinite,
              result.load.original.value >= 0,
              result.load.corrected.value >= 0 else {
            throw TrainerPersistenceError.invalidSetResult(.load)
        }
        guard result.countedReps.provisional >= 0,
              result.countedReps.analyzerFinalized >= 0,
              result.countedReps.finalized >= 0 else {
            throw TrainerPersistenceError.invalidSetResult(.countedReps)
        }
        try validateCleanEvidence(
            result.analysis.analyzerClean,
            countedReps: result.countedReps.analyzerFinalized,
            allowUserCorrection: false
        )
        try validateCleanEvidence(
            result.analysis.clean,
            countedReps: result.countedReps.finalized,
            allowUserCorrection: true
        )
        switch result.analysis.form {
        case let .assessed(primaryTakeaway):
            if let primaryTakeaway,
               primaryTakeaway.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw TrainerPersistenceError.invalidSetResult(.formEvidence)
            }
        case .unavailable, .missing:
            break
        }
        try validateCapture(result.capture)
        guard result.analysis.framesObserved >= 0,
              result.analysis.framesAnalyzed >= 0,
              result.analysis.framesAnalyzed <= result.analysis.framesObserved,
              result.analysis.reps.count == result.countedReps.analyzerFinalized else {
            throw TrainerPersistenceError.invalidSetResult(.repEvidence)
        }
        for (order, rep) in result.analysis.reps.enumerated() {
            guard rep.index > 0,
                  rep.startSeconds.isFinite,
                  rep.bottomSeconds.isFinite,
                  rep.endSeconds.isFinite,
                  rep.startSeconds >= 0,
                  rep.startSeconds <= rep.bottomSeconds,
                  rep.bottomSeconds <= rep.endSeconds,
                  rep.countConfidence.isFinite,
                  (0...1).contains(rep.countConfidence),
                  !result.analysis.reps[..<order].contains(where: { $0.index == rep.index }) else {
                throw TrainerPersistenceError.invalidSetResult(.repEvidence)
            }
        }
        try validateMetadata(result.analysis.modelMetadata)
        try validateCorrections(result)
        for reference in [
            result.artifacts.videoAssetID,
            result.artifacts.overlayAssetID,
            result.artifacts.poseExportAssetID
        ].compactMap({ $0 }) where reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TrainerPersistenceError.invalidSetResult(.artifactReference)
        }
    }

    private func validateCleanEvidence(
        _ evidence: SetResultCleanEvidence,
        countedReps: Int,
        allowUserCorrection: Bool
    ) throws {
        switch evidence {
        case let .analyzerAssessed(cleanReps):
            guard cleanReps >= 0, cleanReps <= countedReps else {
                throw TrainerPersistenceError.invalidSetResult(.cleanEvidence)
            }
        case let .userCorrected(cleanReps):
            guard allowUserCorrection, cleanReps >= 0, cleanReps <= countedReps else {
                throw TrainerPersistenceError.invalidSetResult(.cleanEvidence)
            }
        case .unavailable, .missing:
            break
        }
    }

    private func validateCapture(_ capture: SetResultCaptureEvidence) throws {
        switch capture.setup {
        case let .assessed(disposition, _, checks):
            guard checks.count == SetupCheckID.allCases.count,
                  Set(checks.map(\.id)) == Set(SetupCheckID.allCases) else {
                throw TrainerPersistenceError.invalidSetResult(.setupEvidence)
            }
            switch (disposition, capture.confidence) {
            case (.passed, .standard), (.overridden, .low):
                break
            default:
                throw TrainerPersistenceError.invalidSetResult(.setupEvidence)
            }
        case .missing:
            guard capture.confidence == .unavailable else {
                throw TrainerPersistenceError.invalidSetResult(.setupEvidence)
            }
        }
    }

    private func validateMetadata(_ metadata: SetResultModelMetadata) throws {
        guard let poseEngine = metadata.poseEngine,
              let analyzer = metadata.analyzer,
              !poseEngine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !analyzer.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              poseEngine.configuration.allSatisfy({ !$0.key.isEmpty }) else {
            throw TrainerPersistenceError.invalidSetResult(.modelMetadata)
        }
    }

    private func validateCorrections(_ result: SetResult) throws {
        var replayedLoad = result.load.original
        var replayedCountedReps = result.countedReps.analyzerFinalized
        var replayedClean = result.analysis.analyzerClean
        var previousCreatedAt: Date?

        for (expectedOrder, correction) in result.corrections.enumerated() {
            guard correction.order == expectedOrder,
                  previousCreatedAt.map({ correction.createdAt >= $0 }) ?? true,
                  correction.reason == .userEdit else {
                throw TrainerPersistenceError.invalidSetResult(.correctionEvidence)
            }
            previousCreatedAt = correction.createdAt

            switch (correction.field, correction.previousValue, correction.newValue) {
            case let (.load, .load(previous), .load(new)):
                guard previous == replayedLoad else {
                    throw TrainerPersistenceError.invalidSetResult(.correctionEvidence)
                }
                replayedLoad = new
            case let (.countedReps, .countedReps(previous), .countedReps(new)):
                guard previous == replayedCountedReps, new >= 0 else {
                    throw TrainerPersistenceError.invalidSetResult(.correctionEvidence)
                }
                replayedCountedReps = new
            case let (.cleanReps, previous, .cleanReps(new)):
                guard previous == correctionValue(for: replayedClean), new >= 0 else {
                    throw TrainerPersistenceError.invalidSetResult(.correctionEvidence)
                }
                replayedClean = .userCorrected(cleanReps: new)
            default:
                throw TrainerPersistenceError.invalidSetResult(.correctionEvidence)
            }
        }

        guard replayedLoad == result.load.corrected,
              replayedCountedReps == result.countedReps.finalized,
              replayedClean == result.analysis.clean else {
            throw TrainerPersistenceError.invalidSetResult(.correctionEvidence)
        }
        try validateCleanEvidence(
            replayedClean,
            countedReps: replayedCountedReps,
            allowUserCorrection: true
        )
    }

    private func correctionValue(
        for evidence: SetResultCleanEvidence
    ) -> SetResultCorrectionValue {
        switch evidence {
        case let .analyzerAssessed(cleanReps), let .userCorrected(cleanReps):
            .cleanReps(cleanReps)
        case .unavailable, .missing:
            .unavailable
        }
    }

    private func fetchWorkout(id: UUID) throws -> WorkoutRecord? {
        let targetID = id
        var descriptor = FetchDescriptor<WorkoutRecord>(
            predicate: #Predicate { $0.id == targetID }
        )
        descriptor.fetchLimit = 2
        let records = try context.fetch(descriptor)
        guard records.count <= 1 else {
            throw TrainerPersistenceError.duplicateStableIdentifier
        }
        return records.first
    }

    private func fetchSession(id: UUID) throws -> WorkoutSessionRecord? {
        let targetID = id
        var descriptor = FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { $0.id == targetID }
        )
        descriptor.fetchLimit = 2
        let records = try context.fetch(descriptor)
        guard records.count <= 1 else {
            throw TrainerPersistenceError.duplicateStableIdentifier
        }
        return records.first
    }

    private func fetchSetRecord(id: UUID) throws -> PersistedSetRecord? {
        let targetID = id
        var descriptor = FetchDescriptor<PersistedSetRecord>(
            predicate: #Predicate { $0.id == targetID }
        )
        descriptor.fetchLimit = 2
        let records = try context.fetch(descriptor)
        guard records.count <= 1 else {
            throw TrainerPersistenceError.duplicateStableIdentifier
        }
        return records.first
    }

    private func countSetRecords(sessionID: UUID, excludingSetID: UUID) throws -> Int {
        let targetSessionID = sessionID
        let excludedID = excludingSetID
        return try context.fetchCount(FetchDescriptor<PersistedSetRecord>(
            predicate: #Predicate {
                $0.sessionID == targetSessionID && $0.id != excludedID
            }
        ))
    }

    private func countSetRecords(workoutID: UUID, excludingSetID: UUID) throws -> Int {
        let targetWorkoutID = workoutID
        let excludedID = excludingSetID
        return try context.fetchCount(FetchDescriptor<PersistedSetRecord>(
            predicate: #Predicate {
                $0.workoutID == targetWorkoutID && $0.id != excludedID
            }
        ))
    }

    private func fetchRepRecords(setID: UUID) throws -> [PersistedRepRecord] {
        let targetID = setID
        return try context.fetch(FetchDescriptor<PersistedRepRecord>(
            predicate: #Predicate { $0.setID == targetID },
            sortBy: [SortDescriptor(\.order)]
        ))
    }

    private func fetchSetupCheckRecords(setID: UUID) throws -> [PersistedSetupCheckRecord] {
        let targetID = setID
        return try context.fetch(FetchDescriptor<PersistedSetupCheckRecord>(
            predicate: #Predicate { $0.setID == targetID },
            sortBy: [SortDescriptor(\.order)]
        ))
    }

    private func fetchCorrectionRecords(setID: UUID) throws -> [PersistedCorrectionRecord] {
        let targetID = setID
        return try context.fetch(FetchDescriptor<PersistedCorrectionRecord>(
            predicate: #Predicate { $0.setID == targetID },
            sortBy: [SortDescriptor(\.order)]
        ))
    }

    private func fetchMetadataRecords(setID: UUID) throws -> [PersistedMetadataEntryRecord] {
        let targetID = setID
        return try context.fetch(FetchDescriptor<PersistedMetadataEntryRecord>(
            predicate: #Predicate { $0.setID == targetID },
            sortBy: [
                SortDescriptor(\.componentRaw),
                SortDescriptor(\.key)
            ]
        ))
    }

    private func deleteChildRecords(setID: UUID) throws {
        for record in try fetchRepRecords(setID: setID) {
            context.delete(record)
        }
        for record in try fetchSetupCheckRecords(setID: setID) {
            context.delete(record)
        }
        for record in try fetchCorrectionRecords(setID: setID) {
            context.delete(record)
        }
        for record in try fetchMetadataRecords(setID: setID) {
            context.delete(record)
        }
    }

    private func makeSetRecord(from result: SetResult) -> PersistedSetRecord {
        let analyzerClean = cleanStorage(result.analysis.analyzerClean)
        let currentClean = cleanStorage(result.analysis.clean)
        let form = formStorage(result.analysis.form)
        let setup = setupStorage(result.capture.setup)
        return PersistedSetRecord(
            id: result.id,
            workoutID: result.identity.workoutID,
            sessionID: result.identity.sessionID,
            schemaVersion: result.schemaVersion,
            ordinal: result.identity.ordinal,
            exerciseIDRaw: result.identity.exerciseID.rawValue,
            sessionStartedAt: result.timestamps.sessionStartedAt,
            completedAt: result.timestamps.completedAt,
            updatedAt: result.timestamps.completedAt,
            originalLoadValue: result.load.original.value,
            originalLoadUnitRaw: result.load.original.unit.rawValue,
            correctedLoadValue: result.load.corrected.value,
            correctedLoadUnitRaw: result.load.corrected.unit.rawValue,
            provisionalCountedReps: result.countedReps.provisional,
            analyzerFinalizedCountedReps: result.countedReps.analyzerFinalized,
            finalizedCountedReps: result.countedReps.finalized,
            analyzerCleanEvidenceRaw: analyzerClean.kind,
            analyzerCleanReps: analyzerClean.count,
            cleanEvidenceRaw: currentClean.kind,
            cleanReps: currentClean.count,
            formEvidenceRaw: form.kind,
            primaryFeedbackTakeaway: form.primaryTakeaway,
            captureConfidenceRaw: result.capture.confidence.rawValue,
            setupEvidenceRaw: setup.kind,
            setupDispositionRaw: setup.disposition,
            setupDecidedAt: setup.decidedAt,
            framesObserved: result.analysis.framesObserved,
            framesAnalyzed: result.analysis.framesAnalyzed,
            poseEngineName: result.analysis.modelMetadata.poseEngine?.name,
            poseEngineVersion: result.analysis.modelMetadata.poseEngine?.version,
            analyzerName: result.analysis.modelMetadata.analyzer?.name,
            analyzerVersion: result.analysis.modelMetadata.analyzer?.version,
            videoAssetID: result.artifacts.videoAssetID,
            overlayAssetID: result.artifacts.overlayAssetID,
            poseExportAssetID: result.artifacts.poseExportAssetID
        )
    }

    private func apply(
        _ result: SetResult,
        updatedAt: Date,
        to record: PersistedSetRecord
    ) {
        let analyzerClean = cleanStorage(result.analysis.analyzerClean)
        let currentClean = cleanStorage(result.analysis.clean)
        let form = formStorage(result.analysis.form)
        let setup = setupStorage(result.capture.setup)
        record.workoutID = result.identity.workoutID
        record.sessionID = result.identity.sessionID
        record.schemaVersion = result.schemaVersion
        record.ordinal = result.identity.ordinal
        record.exerciseIDRaw = result.identity.exerciseID.rawValue
        record.sessionStartedAt = result.timestamps.sessionStartedAt
        record.completedAt = result.timestamps.completedAt
        record.updatedAt = updatedAt
        record.originalLoadValue = result.load.original.value
        record.originalLoadUnitRaw = result.load.original.unit.rawValue
        record.correctedLoadValue = result.load.corrected.value
        record.correctedLoadUnitRaw = result.load.corrected.unit.rawValue
        record.provisionalCountedReps = result.countedReps.provisional
        record.analyzerFinalizedCountedReps = result.countedReps.analyzerFinalized
        record.finalizedCountedReps = result.countedReps.finalized
        record.analyzerCleanEvidenceRaw = analyzerClean.kind
        record.analyzerCleanReps = analyzerClean.count
        record.cleanEvidenceRaw = currentClean.kind
        record.cleanReps = currentClean.count
        record.formEvidenceRaw = form.kind
        record.primaryFeedbackTakeaway = form.primaryTakeaway
        record.captureConfidenceRaw = result.capture.confidence.rawValue
        record.setupEvidenceRaw = setup.kind
        record.setupDispositionRaw = setup.disposition
        record.setupDecidedAt = setup.decidedAt
        record.framesObserved = result.analysis.framesObserved
        record.framesAnalyzed = result.analysis.framesAnalyzed
        record.poseEngineName = result.analysis.modelMetadata.poseEngine?.name
        record.poseEngineVersion = result.analysis.modelMetadata.poseEngine?.version
        record.analyzerName = result.analysis.modelMetadata.analyzer?.name
        record.analyzerVersion = result.analysis.modelMetadata.analyzer?.version
        record.videoAssetID = result.artifacts.videoAssetID
        record.overlayAssetID = result.artifacts.overlayAssetID
        record.poseExportAssetID = result.artifacts.poseExportAssetID
    }

    private func insertChildRecords(from result: SetResult) {
        for (order, rep) in result.analysis.reps.enumerated() {
            context.insert(PersistedRepRecord(
                setID: result.id,
                order: order,
                repIndex: rep.index,
                startSeconds: rep.startSeconds,
                bottomSeconds: rep.bottomSeconds,
                endSeconds: rep.endSeconds,
                countConfidence: rep.countConfidence,
                qualityRaw: repQualityRaw(rep.quality)
            ))
        }

        if case let .assessed(_, _, checks) = result.capture.setup {
            for (order, check) in checks.enumerated() {
                context.insert(PersistedSetupCheckRecord(
                    setID: result.id,
                    order: order,
                    checkIDRaw: check.id.rawValue,
                    statusRaw: check.status.rawValue
                ))
            }
        }

        for correction in result.corrections {
            let previous = correctionStorage(correction.previousValue)
            let new = correctionStorage(correction.newValue)
            context.insert(PersistedCorrectionRecord(
                setID: result.id,
                order: correction.order,
                createdAt: correction.createdAt,
                fieldRaw: correction.field.rawValue,
                reasonRaw: correction.reason.rawValue,
                previousValueKindRaw: previous.kind,
                previousNumericValue: previous.numericValue,
                previousUnitRaw: previous.unit,
                newValueKindRaw: new.kind,
                newNumericValue: new.numericValue,
                newUnitRaw: new.unit
            ))
        }

        insertMetadata(
            result.analysis.modelMetadata.poseEngine,
            component: "pose_engine",
            setID: result.id
        )
        insertMetadata(
            result.analysis.modelMetadata.analyzer,
            component: "analyzer",
            setID: result.id
        )
    }

    private func insertMetadata(
        _ metadata: SetResultModelComponentMetadata?,
        component: String,
        setID: UUID
    ) {
        guard let metadata else { return }
        for (key, value) in metadata.configuration.sorted(by: { $0.key < $1.key }) {
            context.insert(PersistedMetadataEntryRecord(
                setID: setID,
                componentRaw: component,
                key: key,
                value: value
            ))
        }
    }

    private func restoreSetResult(
        _ record: PersistedSetRecord,
        reps: [SetRepSummary],
        setupChecks: [SetupCheck],
        corrections: [SetResultCorrection],
        metadataEntries: [PersistedMetadataEntryRecord]
    ) throws -> SetResult {
        guard record.schemaVersion == SetResult.currentSchemaVersion,
              record.ordinal > 0,
              !record.exerciseIDRaw.isEmpty,
              let originalUnit = LoadUnit(rawValue: record.originalLoadUnitRaw),
              let correctedUnit = LoadUnit(rawValue: record.correctedLoadUnitRaw),
              let captureConfidence = SetResultCaptureConfidence(
                rawValue: record.captureConfidenceRaw
              ) else {
            throw TrainerPersistenceError.corruptStoredRecord
        }
        let originalLoad = try TrainingLoad(
            value: record.originalLoadValue,
            unit: originalUnit
        )
        let correctedLoad = try TrainingLoad(
            value: record.correctedLoadValue,
            unit: correctedUnit
        )
        let analyzerClean = try restoreCleanEvidence(
            kind: record.analyzerCleanEvidenceRaw,
            count: record.analyzerCleanReps
        )
        let currentClean = try restoreCleanEvidence(
            kind: record.cleanEvidenceRaw,
            count: record.cleanReps
        )
        let form = try restoreFormEvidence(
            kind: record.formEvidenceRaw,
            primaryTakeaway: record.primaryFeedbackTakeaway
        )
        let setup = try restoreSetupEvidence(
            kind: record.setupEvidenceRaw,
            disposition: record.setupDispositionRaw,
            decidedAt: record.setupDecidedAt,
            checks: setupChecks
        )
        let metadata = try restoreMetadata(record, entries: metadataEntries)

        return SetResult(
            schemaVersion: record.schemaVersion,
            identity: SetResultIdentity(
                setID: record.id,
                workoutID: record.workoutID,
                sessionID: record.sessionID,
                ordinal: record.ordinal,
                exerciseID: ExerciseID(rawValue: record.exerciseIDRaw)
            ),
            timestamps: SetResultTimestamps(
                sessionStartedAt: record.sessionStartedAt,
                completedAt: record.completedAt
            ),
            load: SetResultLoadEvidence(
                original: originalLoad,
                corrected: correctedLoad
            ),
            countedReps: SetResultCountedRepEvidence(
                provisional: record.provisionalCountedReps,
                analyzerFinalized: record.analyzerFinalizedCountedReps,
                finalized: record.finalizedCountedReps
            ),
            capture: SetResultCaptureEvidence(
                confidence: captureConfidence,
                setup: setup
            ),
            analysis: SetResultAnalysisEvidence(
                analyzerClean: analyzerClean,
                clean: currentClean,
                form: form,
                reps: reps,
                framesObserved: record.framesObserved,
                framesAnalyzed: record.framesAnalyzed,
                modelMetadata: metadata
            ),
            corrections: corrections,
            artifacts: SetResultArtifactReferences(
                videoAssetID: record.videoAssetID,
                overlayAssetID: record.overlayAssetID,
                poseExportAssetID: record.poseExportAssetID
            )
        )
    }

    private func restoreRep(_ record: PersistedRepRecord) throws -> SetRepSummary {
        guard let quality = repQuality(raw: record.qualityRaw) else {
            throw TrainerPersistenceError.corruptStoredRecord
        }
        return SetRepSummary(
            index: record.repIndex,
            startSeconds: record.startSeconds,
            bottomSeconds: record.bottomSeconds,
            endSeconds: record.endSeconds,
            countConfidence: record.countConfidence,
            quality: quality
        )
    }

    private func restoreSetupCheck(_ record: PersistedSetupCheckRecord) throws -> SetupCheck {
        guard let id = SetupCheckID(rawValue: record.checkIDRaw),
              let status = SetupCheckStatus(rawValue: record.statusRaw) else {
            throw TrainerPersistenceError.corruptStoredRecord
        }
        return SetupCheck(id: id, status: status)
    }

    private func restoreCorrection(
        _ record: PersistedCorrectionRecord
    ) throws -> SetResultCorrection {
        guard let field = SetCorrectionField(rawValue: record.fieldRaw),
              let reason = SetCorrectionReason(rawValue: record.reasonRaw) else {
            throw TrainerPersistenceError.corruptStoredRecord
        }
        return SetResultCorrection(
            order: record.order,
            createdAt: record.createdAt,
            field: field,
            previousValue: try restoreCorrectionValue(
                kind: record.previousValueKindRaw,
                numericValue: record.previousNumericValue,
                unit: record.previousUnitRaw
            ),
            newValue: try restoreCorrectionValue(
                kind: record.newValueKindRaw,
                numericValue: record.newNumericValue,
                unit: record.newUnitRaw
            ),
            reason: reason
        )
    }

    private func restoreMetadata(
        _ record: PersistedSetRecord,
        entries: [PersistedMetadataEntryRecord]
    ) throws -> SetResultModelMetadata {
        let knownComponents = Set(["pose_engine", "analyzer"])
        guard entries.allSatisfy({
            knownComponents.contains($0.componentRaw) && !$0.key.isEmpty
        }) else {
            throw TrainerPersistenceError.corruptStoredRecord
        }
        func component(
            name: String?,
            version: String?,
            raw: String
        ) throws -> SetResultModelComponentMetadata? {
            let componentEntries = entries.filter { $0.componentRaw == raw }
            guard let name else {
                guard componentEntries.isEmpty, version == nil else {
                    throw TrainerPersistenceError.corruptStoredRecord
                }
                return nil
            }
            let grouped = Dictionary(grouping: componentEntries, by: \.key)
            guard grouped.values.allSatisfy({ $0.count == 1 }) else {
                throw TrainerPersistenceError.corruptStoredRecord
            }
            return SetResultModelComponentMetadata(
                name: name,
                version: version,
                configuration: Dictionary(
                    uniqueKeysWithValues: componentEntries.map { ($0.key, $0.value) }
                )
            )
        }
        return SetResultModelMetadata(
            poseEngine: try component(
                name: record.poseEngineName,
                version: record.poseEngineVersion,
                raw: "pose_engine"
            ),
            analyzer: try component(
                name: record.analyzerName,
                version: record.analyzerVersion,
                raw: "analyzer"
            )
        )
    }

    private func cleanStorage(
        _ evidence: SetResultCleanEvidence
    ) -> (kind: String, count: Int?) {
        switch evidence {
        case let .analyzerAssessed(cleanReps):
            ("analyzer_assessed", cleanReps)
        case let .userCorrected(cleanReps):
            ("user_corrected", cleanReps)
        case .unavailable:
            ("unavailable", nil)
        case .missing:
            ("missing", nil)
        }
    }

    private func restoreCleanEvidence(
        kind: String,
        count: Int?
    ) throws -> SetResultCleanEvidence {
        switch (kind, count) {
        case let ("analyzer_assessed", .some(cleanReps)):
            .analyzerAssessed(cleanReps: cleanReps)
        case let ("user_corrected", .some(cleanReps)):
            .userCorrected(cleanReps: cleanReps)
        case ("unavailable", .none):
            .unavailable
        case ("missing", .none):
            .missing
        default:
            throw TrainerPersistenceError.corruptStoredRecord
        }
    }

    private func formStorage(
        _ evidence: SetResultFormEvidence
    ) -> (kind: String, primaryTakeaway: String?) {
        switch evidence {
        case let .assessed(primaryTakeaway):
            ("assessed", primaryTakeaway)
        case .unavailable:
            ("unavailable", nil)
        case .missing:
            ("missing", nil)
        }
    }

    private func restoreFormEvidence(
        kind: String,
        primaryTakeaway: String?
    ) throws -> SetResultFormEvidence {
        switch kind {
        case "assessed":
            return .assessed(primaryTakeaway: primaryTakeaway)
        case "unavailable" where primaryTakeaway == nil:
            return .unavailable
        case "missing" where primaryTakeaway == nil:
            return .missing
        default:
            throw TrainerPersistenceError.corruptStoredRecord
        }
    }

    private func setupStorage(
        _ evidence: SetResultSetupEvidence
    ) -> (kind: String, disposition: String?, decidedAt: Date?) {
        switch evidence {
        case let .assessed(disposition, decidedAt, _):
            ("assessed", disposition.rawValue, decidedAt)
        case .missing:
            ("missing", nil, nil)
        }
    }

    private func restoreSetupEvidence(
        kind: String,
        disposition: String?,
        decidedAt: Date?,
        checks: [SetupCheck]
    ) throws -> SetResultSetupEvidence {
        switch kind {
        case "assessed":
            guard let disposition,
                  let disposition = SetupGateDisposition(rawValue: disposition),
                  let decidedAt else {
                throw TrainerPersistenceError.corruptStoredRecord
            }
            return .assessed(
                disposition: disposition,
                decidedAt: decidedAt,
                checks: checks
            )
        case "missing" where disposition == nil && decidedAt == nil && checks.isEmpty:
            return .missing
        default:
            throw TrainerPersistenceError.corruptStoredRecord
        }
    }

    private func repQualityRaw(_ quality: SetRepQuality) -> String {
        switch quality {
        case .clean: "clean"
        case .notClean: "not_clean"
        case .unavailable: "unavailable"
        }
    }

    private func repQuality(raw: String) -> SetRepQuality? {
        switch raw {
        case "clean": .clean
        case "not_clean": .notClean
        case "unavailable": .unavailable
        default: nil
        }
    }

    private func correctionStorage(
        _ value: SetResultCorrectionValue
    ) -> (kind: String, numericValue: Double?, unit: String?) {
        switch value {
        case let .load(load):
            ("load", load.value, load.unit.rawValue)
        case let .countedReps(count):
            ("counted_reps", Double(count), nil)
        case let .cleanReps(count):
            ("clean_reps", Double(count), nil)
        case .unavailable:
            ("unavailable", nil, nil)
        }
    }

    private func restoreCorrectionValue(
        kind: String,
        numericValue: Double?,
        unit: String?
    ) throws -> SetResultCorrectionValue {
        switch kind {
        case "load":
            guard let numericValue,
                  let unit,
                  let loadUnit = LoadUnit(rawValue: unit) else {
                throw TrainerPersistenceError.corruptStoredRecord
            }
            return .load(try TrainingLoad(value: numericValue, unit: loadUnit))
        case "counted_reps":
            guard unit == nil,
                  let numericValue,
                  let count = exactInt(numericValue) else {
                throw TrainerPersistenceError.corruptStoredRecord
            }
            return .countedReps(count)
        case "clean_reps":
            guard unit == nil,
                  let numericValue,
                  let count = exactInt(numericValue) else {
                throw TrainerPersistenceError.corruptStoredRecord
            }
            return .cleanReps(count)
        case "unavailable" where numericValue == nil && unit == nil:
            return .unavailable
        default:
            throw TrainerPersistenceError.corruptStoredRecord
        }
    }

    private func exactInt(_ value: Double) -> Int? {
        guard value.isFinite,
              value.rounded(.towardZero) == value,
              value >= Double(Int.min),
              value <= Double(Int.max) else {
            return nil
        }
        return Int(value)
    }
}
