import Foundation
import SwiftData
import Testing
import TrainerCore
@testable import TrainerPersistence

@Suite(.serialized)
struct TrainerPersistenceTests {
    @Test @MainActor
    func requiredSetResultFieldsRoundTrip() throws {
        let container = try TrainerPersistenceContainer.makeInMemory()
        let store = TrainerPersistenceStore(modelContainer: container)
        let session = try makeSession(overriddenSetup: true)
        let completedSet = try #require(session.completedSets.last)
        let expected = try SetResult(
            session: session,
            completedSet: completedSet,
            artifacts: SetResultArtifactReferences(
                videoAssetID: "video-asset-1",
                overlayAssetID: "overlay-asset-1",
                poseExportAssetID: "pose-export-asset-1"
            )
        )

        try store.upsert(expected)

        let restored = try #require(try store.fetchSetResult(id: expected.id))
        #expect(restored == expected)
        #expect(restored.identity.workoutID == session.id)
        #expect(restored.identity.sessionID == session.id)
        #expect(restored.capture.confidence == .low)
        guard case let .assessed(disposition, _, checks) = restored.capture.setup else {
            Issue.record("Expected assessed setup evidence")
            return
        }
        #expect(disposition == .overridden)
        #expect(checks.first(where: { $0.id == .phoneStable })?.status == .failing)
        #expect(restored.analysis.modelMetadata.poseEngine?.name == "mediapipe_pose_landmarker")
        #expect(restored.analysis.modelMetadata.analyzer?.name == "SquatAnalyzer")
    }

    @Test @MainActor
    func unavailableAndMissingCleanEvidenceRemainDistinctFromZero() throws {
        let container = try TrainerPersistenceContainer.makeInMemory()
        let store = TrainerPersistenceStore(modelContainer: container)
        let session = try makeSession()
        let completedSet = try #require(session.completedSets.last)
        let unavailable = try SetResult(session: session, completedSet: completedSet)

        try store.upsert(unavailable)

        let restoredUnavailable = try #require(try store.fetchSetResult(id: unavailable.id))
        #expect(restoredUnavailable.analysis.analyzerClean == .unavailable)
        #expect(restoredUnavailable.analysis.clean == .unavailable)

        let missingID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
        let missing = replacingCleanEvidence(
            in: unavailable,
            setID: missingID,
            analyzerClean: .missing,
            currentClean: .missing
        )
        try store.upsert(missing)

        let restoredMissing = try #require(try store.fetchSetResult(id: missingID))
        #expect(restoredMissing.analysis.analyzerClean == .missing)
        #expect(restoredMissing.analysis.clean == .missing)

        let context = ModelContext(container)
        let targetIDs = [unavailable.id, missingID]
        let records = try context.fetch(FetchDescriptor<PersistedSetRecord>(
            predicate: #Predicate { targetIDs.contains($0.id) }
        ))
        #expect(records.allSatisfy { $0.cleanReps == nil })
    }

    @Test @MainActor
    func userCorrectedCleanEvidenceRetainsOrderedProvenance() throws {
        let container = try TrainerPersistenceContainer.makeInMemory()
        let store = TrainerPersistenceStore(modelContainer: container)
        var session = try makeSession()
        let setID = try #require(session.completedSets.last?.id)
        try session.correctReviewedSetCleanReps(
            setID,
            to: 1,
            at: date(40)
        )
        let corrected = try #require(session.completedSets.last)
        let expected = try SetResult(session: session, completedSet: corrected)

        try store.upsert(expected)

        let restored = try #require(try store.fetchSetResult(id: setID))
        #expect(restored.analysis.analyzerClean == .unavailable)
        #expect(restored.analysis.clean == .userCorrected(cleanReps: 1))
        #expect(restored.corrections.count == 1)
        #expect(restored.corrections[0].order == 0)
        #expect(restored.corrections[0].field == .cleanReps)
        #expect(restored.corrections[0].previousValue == .unavailable)
        #expect(restored.corrections[0].newValue == .cleanReps(1))
        #expect(restored.corrections[0].reason == .userEdit)
    }

    @Test @MainActor
    func correctionUpsertUpdatesTheStableRecordWithoutDuplicates() throws {
        let container = try TrainerPersistenceContainer.makeInMemory()
        let store = TrainerPersistenceStore(modelContainer: container)
        var session = try makeSession()
        let setID = try #require(session.completedSets.last?.id)
        let initial = try SetResult(
            session: session,
            completedSet: #require(session.completedSets.last)
        )
        try store.upsert(initial)

        try session.correctReviewedSetCleanReps(setID, to: 1, at: date(40))
        try session.correctReviewedSetLoad(
            setID,
            to: TrainingLoad(value: 205, unit: .pounds),
            at: date(41)
        )
        let correctedSet = try #require(session.completedSets.last)
        let corrected = try SetResult(session: session, completedSet: correctedSet)
        try store.upsert(corrected)
        try store.upsert(corrected)

        #expect(try store.setRecordCount() == 1)
        let restored = try #require(try store.fetchSetResult(id: setID))
        #expect(restored == corrected)
        #expect(restored.corrections.count == 2)

        let context = ModelContext(container)
        let targetID = setID
        #expect(try context.fetchCount(FetchDescriptor<PersistedCorrectionRecord>(
            predicate: #Predicate { $0.setID == targetID }
        )) == 2)
    }

    @Test @MainActor
    func discardDeletesSetChildrenAndEmptyParents() throws {
        let container = try TrainerPersistenceContainer.makeInMemory()
        let store = TrainerPersistenceStore(modelContainer: container)
        let session = try makeSession()
        let result = try SetResult(
            session: session,
            completedSet: #require(session.completedSets.last)
        )
        try store.upsert(result)

        #expect(try store.deleteSetResult(id: result.id))
        #expect(try !store.deleteSetResult(id: result.id))
        #expect(try store.fetchSetResult(id: result.id) == nil)
        #expect(try store.setRecordCount() == 0)

        let context = ModelContext(container)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutRecord>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<WorkoutSessionRecord>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PersistedRepRecord>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PersistedSetupCheckRecord>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PersistedCorrectionRecord>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PersistedMetadataEntryRecord>()) == 0)
    }

    @Test
    func schemaContainsNoBinaryOrPerFramePayloadFields() {
        let prohibitedNames: Set<String> = [
            "videoData",
            "imageData",
            "poseFrames",
            "poseStream",
            "framePayload"
        ]
        for entity in TrainerPersistenceContainer.schema.entities {
            for property in entity.properties {
                #expect(!prohibitedNames.contains(property.name))
                #expect(String(reflecting: property.valueType) != "Foundation.Data")
            }
        }
    }

    @Test @MainActor
    func malformedCleanDiscriminatorAndMissingParentFailClosed() throws {
        let container = try TrainerPersistenceContainer.makeInMemory()
        let store = TrainerPersistenceStore(modelContainer: container)
        let session = try makeSession()
        let result = try SetResult(
            session: session,
            completedSet: #require(session.completedSets.last)
        )
        try store.upsert(result)

        let context = ModelContext(container)
        let targetID = result.id
        let record = try #require(context.fetch(FetchDescriptor<PersistedSetRecord>(
            predicate: #Predicate { $0.id == targetID }
        )).first)
        record.cleanEvidenceRaw = "unavailable"
        record.cleanReps = 0
        try context.save()

        #expect(throws: TrainerPersistenceError.corruptStoredRecord) {
            try store.fetchSetResult(id: result.id)
        }

        record.cleanReps = nil
        let sessionID = result.identity.sessionID
        let sessionRecord = try #require(context.fetch(FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { $0.id == sessionID }
        )).first)
        context.delete(sessionRecord)
        try context.save()

        #expect(throws: TrainerPersistenceError.corruptStoredRecord) {
            try store.fetchSetResult(id: result.id)
        }
    }

    @Test @MainActor
    func partialCompletedSetCannotCrossThePersistenceBoundary() throws {
        var session = QuickSession(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            exerciseID: .backSquat,
            startedAt: date(0),
            initialSetID: UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
        )
        try session.setCurrentSetLoad(TrainingLoad(value: 45, unit: .pounds))
        let partial = try session.advanceCurrentSetForCameraIndependentTesting(at: date(5))

        #expect(throws: SetResultError.missingFinalizedAnalysis) {
            try SetResult(session: session, completedSet: partial)
        }
    }

    @Test @MainActor
    func schemaAndInMemoryContainerInitializeRepeatedly() throws {
        for _ in 0..<6 {
            let container = try TrainerPersistenceContainer.makeInMemory()
            let store = TrainerPersistenceStore(modelContainer: container)
            #expect(try store.setRecordCount() == 0)
        }
    }

    @Test @MainActor
    func fileBackedRecordReopensFromANewContainer() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrainerPersistenceTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("trainer.store")
        let session = try makeSession()
        let expected = try SetResult(
            session: session,
            completedSet: #require(session.completedSets.last)
        )

        do {
            let firstContainer = try TrainerPersistenceContainer.make(at: storeURL)
            let firstStore = TrainerPersistenceStore(modelContainer: firstContainer)
            try firstStore.upsert(expected)
        }

        let reopenedContainer = try TrainerPersistenceContainer.make(at: storeURL)
        let reopenedStore = TrainerPersistenceStore(modelContainer: reopenedContainer)
        #expect(try reopenedStore.fetchSetResult(id: expected.id) == expected)
    }

    @MainActor
    private func makeSession(overriddenSetup: Bool = false) throws -> QuickSession {
        var session = QuickSession(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            exerciseID: .backSquat,
            startedAt: date(0),
            initialSetID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        )
        try session.setCurrentSetLoad(TrainingLoad(value: 185, unit: .pounds))
        var statuses = Dictionary(
            uniqueKeysWithValues: SetupCheckID.allCases.map { ($0, SetupCheckStatus.passing) }
        )
        if overriddenSetup {
            statuses[.phoneStable] = .failing
        }
        let assessment = SetupGateAssessment(statuses: statuses)
        let outcome = overriddenSetup
            ? try assessment.overrideFailures(at: date(10))
            : try assessment.approve(at: date(10))
        try session.setCurrentSetSetupGateOutcome(outcome)
        _ = try session.completeCurrentSet(
            analysis: SetAnalysisSummary(
                provisionalCountedReps: 1,
                finalizedCountedReps: 2,
                cleanResult: .unavailable,
                reps: [
                    SetRepSummary(
                        index: 1,
                        startSeconds: 1,
                        bottomSeconds: 2,
                        endSeconds: 3,
                        countConfidence: 0.91,
                        quality: .unavailable
                    ),
                    SetRepSummary(
                        index: 2,
                        startSeconds: 4,
                        bottomSeconds: 5,
                        endSeconds: 6,
                        countConfidence: 0.89,
                        quality: .unavailable
                    )
                ],
                framesObserved: 240,
                framesAnalyzed: 228,
                modelMetadata: SetResultModelMetadata(
                    poseEngine: SetResultModelComponentMetadata(
                        name: "mediapipe_pose_landmarker",
                        version: "MediaPipeTasksVision",
                        configuration: [
                            "model": "pose_landmarker_full.task",
                            "running_mode": "video"
                        ]
                    ),
                    analyzer: SetResultModelComponentMetadata(
                        name: "SquatAnalyzer"
                    )
                )
            ),
            at: date(30),
            nextSetID: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
        )
        return session
    }

    private func replacingCleanEvidence(
        in result: SetResult,
        setID: UUID,
        analyzerClean: SetResultCleanEvidence,
        currentClean: SetResultCleanEvidence
    ) -> SetResult {
        SetResult(
            schemaVersion: result.schemaVersion,
            identity: SetResultIdentity(
                setID: setID,
                workoutID: result.identity.workoutID,
                sessionID: result.identity.sessionID,
                ordinal: result.identity.ordinal + 1,
                exerciseID: result.identity.exerciseID
            ),
            timestamps: result.timestamps,
            load: result.load,
            countedReps: result.countedReps,
            capture: result.capture,
            analysis: SetResultAnalysisEvidence(
                analyzerClean: analyzerClean,
                clean: currentClean,
                form: result.analysis.form,
                reps: result.analysis.reps,
                framesObserved: result.analysis.framesObserved,
                framesAnalyzed: result.analysis.framesAnalyzed,
                modelMetadata: result.analysis.modelMetadata
            ),
            corrections: [],
            artifacts: result.artifacts
        )
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_800_000_000 + seconds)
    }
}
