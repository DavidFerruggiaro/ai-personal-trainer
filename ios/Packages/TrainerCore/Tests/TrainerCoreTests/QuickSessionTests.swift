import Foundation
import Testing
@testable import TrainerCore

struct QuickSessionTests {
    private let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let firstSetID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private let secondSetID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private let thirdSetID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    private let startedAt = Date(timeIntervalSince1970: 100)

    @Test func startsWithCurrentBackSquatSet() {
        let session = makeSession()

        #expect(session.id == sessionID)
        #expect(session.isActive)
        #expect(session.endedAt == nil)
        #expect(session.exerciseID == .backSquat)
        #expect(session.currentSet == SetDraft(id: firstSetID, ordinal: 1, exerciseID: .backSquat))
        #expect(session.completedSets.isEmpty)
    }

    @Test func completingSetsPreservesOrderAndAdvancesCurrentSet() throws {
        var session = makeSession()
        let load = try TrainingLoad(value: 185, unit: .pounds)
        let firstCompletedAt = Date(timeIntervalSince1970: 120)
        let secondCompletedAt = Date(timeIntervalSince1970: 150)

        try session.setCurrentSetLoad(load)
        let first = try session.advanceCurrentSetForCameraIndependentTesting(
            at: firstCompletedAt,
            nextSetID: secondSetID
        )
        let second = try session.advanceCurrentSetForCameraIndependentTesting(
            at: secondCompletedAt,
            nextSetID: thirdSetID
        )

        #expect(first == CompletedSetSummary(
            draft: SetDraft(id: firstSetID, ordinal: 1, exerciseID: .backSquat, load: load),
            completedAt: firstCompletedAt
        ))
        #expect(second.ordinal == 2)
        #expect(second.exerciseID == .backSquat)
        #expect(session.completedSets == [first, second])
        #expect(session.currentSet == SetDraft(
            id: thirdSetID,
            ordinal: 3,
            exerciseID: .backSquat,
            load: load
        ))
    }

    @Test func finalizedAnalysisAutoSavesIntoCompletedSetWithoutInventingCleanReps() throws {
        var session = makeSession()
        let load = try TrainingLoad(value: 185, unit: .pounds)
        let setup = try passingSetupOutcome()
        let analysis = SetAnalysisSummary(
            provisionalCountedReps: 5,
            finalizedCountedReps: 4,
            cleanResult: .unavailable,
            reps: [
                SetRepSummary(
                    index: 1,
                    startSeconds: 1,
                    bottomSeconds: 2,
                    endSeconds: 3,
                    countConfidence: 0.9,
                    quality: .unavailable
                )
            ],
            framesObserved: 120,
            framesAnalyzed: 118
        )

        try session.setCurrentSetLoad(load)
        try session.setCurrentSetSetupGateOutcome(setup)
        let completed = try session.completeCurrentSet(
            analysis: analysis,
            at: Date(timeIntervalSince1970: 130),
            nextSetID: secondSetID
        )

        #expect(completed.analysis == analysis)
        #expect(session.completedSets == [completed])
        #expect(session.currentSet.ordinal == 2)
        #expect(session.currentSet.load == load)
        #expect(session.currentSet.setupGateOutcome == nil)
    }

    @Test func discardingReviewedSetRemovesItAndRestoresTheSetOrdinal() throws {
        var session = makeSession()
        let load = try TrainingLoad(value: 185, unit: .pounds)
        let setup = try passingSetupOutcome()
        let analysis = SetAnalysisSummary(
            provisionalCountedReps: 1,
            finalizedCountedReps: 1,
            cleanResult: .unavailable,
            reps: [],
            framesObserved: 30,
            framesAnalyzed: 30
        )
        try session.setCurrentSetLoad(load)
        try session.setCurrentSetSetupGateOutcome(setup)
        let completed = try session.completeCurrentSet(
            analysis: analysis,
            nextSetID: secondSetID
        )

        try session.discardCompletedSetFromReview(completed.id)

        #expect(session.completedSets.isEmpty)
        #expect(session.currentSet.id == secondSetID)
        #expect(session.currentSet.ordinal == 1)
        #expect(session.currentSet.load == load)
        #expect(session.currentSet.setupGateOutcome == nil)
    }

    @Test func endingRecordsLifecycleAndRejectsLaterMutation() throws {
        var session = makeSession()
        let endedAt = Date(timeIntervalSince1970: 180)

        try session.end(at: endedAt)

        #expect(!session.isActive)
        #expect(session.endedAt == endedAt)
        #expect(throws: QuickSessionError.sessionEnded) {
            try session.advanceCurrentSetForCameraIndependentTesting(nextSetID: secondSetID)
        }
        #expect(throws: QuickSessionError.sessionEnded) {
            try session.setCurrentSetLoad(TrainingLoad(value: 185, unit: .pounds))
        }
        #expect(throws: QuickSessionError.sessionEnded) {
            try session.end(at: endedAt.addingTimeInterval(10))
        }
        #expect(session.completedSets.isEmpty)
        #expect(session.currentSet.id == firstSetID)
    }

    private func makeSession() -> QuickSession {
        QuickSession(
            id: sessionID,
            exerciseID: .backSquat,
            startedAt: startedAt,
            initialSetID: firstSetID
        )
    }

    private func passingSetupOutcome() throws -> SetupGateOutcome {
        try SetupGateAssessment(statuses: Dictionary(
            uniqueKeysWithValues: SetupCheckID.allCases.map { ($0, .passing) }
        )).approve(at: Date(timeIntervalSince1970: 110))
    }
}
