import Foundation
import Testing
import TrainerCore

struct SetCorrectionTests {
    @Test func correctingLoadPreservesOriginalSetEvidenceAndRecordsTheEdit() throws {
        var session = try makeSessionWithReviewedSet()
        let setID = try #require(session.completedSets.last?.id)
        let originalLoad = try TrainingLoad(value: 185, unit: .pounds)
        let correctedLoad = try TrainingLoad(value: 190, unit: .pounds)
        let correctedAt = Date(timeIntervalSince1970: 200)

        try session.correctReviewedSetLoad(setID, to: correctedLoad, at: correctedAt)

        let correctedSet = try #require(session.completedSets.last)
        #expect(correctedSet.originalLoad == originalLoad)
        #expect(correctedSet.load == correctedLoad)
        #expect(correctedSet.analysis == originalAnalysis)
        #expect(correctedSet.userCorrections.count == 1)
        #expect(correctedSet.userCorrections[0].createdAt == correctedAt)
        #expect(correctedSet.userCorrections[0].field == .load)
        #expect(correctedSet.userCorrections[0].previousValue == .load(originalLoad))
        #expect(correctedSet.userCorrections[0].newValue == .load(correctedLoad))
        #expect(correctedSet.userCorrections[0].reason == .userEdit)
        #expect(correctedSet.userCorrections[0].reason.rawValue == "user_edit")
    }

    @Test func repeatedCorrectionsAreOrderedFromTheCurrentUserFacingValue() throws {
        var session = try makeSessionWithReviewedSet()
        let setID = try #require(session.completedSets.last?.id)
        let firstLoad = try TrainingLoad(value: 190, unit: .pounds)
        let secondLoad = try TrainingLoad(value: 87.5, unit: .kilograms)

        try session.correctReviewedSetLoad(
            setID,
            to: firstLoad,
            at: Date(timeIntervalSince1970: 200)
        )
        try session.correctReviewedSetLoad(
            setID,
            to: secondLoad,
            at: Date(timeIntervalSince1970: 210)
        )

        let correctedSet = try #require(session.completedSets.last)
        #expect(correctedSet.load == secondLoad)
        #expect(correctedSet.userCorrections.map(\.createdAt) == [
            Date(timeIntervalSince1970: 200),
            Date(timeIntervalSince1970: 210)
        ])
        #expect(correctedSet.userCorrections[1].previousValue == .load(firstLoad))
        #expect(correctedSet.userCorrections[1].newValue == .load(secondLoad))
    }

    @Test func correctedReviewedLoadBecomesTheNextSetDefault() throws {
        var session = try makeSessionWithReviewedSet()
        let setID = try #require(session.completedSets.last?.id)
        let correctedLoad = try TrainingLoad(value: 190, unit: .pounds)

        try session.correctReviewedSetLoad(setID, to: correctedLoad)

        #expect(session.currentSet.load == correctedLoad)
        #expect(session.currentSet.setupGateOutcome == nil)
    }

    @Test func correctingCountedRepsPreservesTheFinalizedAnalyzerCount() throws {
        var session = try makeSessionWithReviewedSet()
        let setID = try #require(session.completedSets.last?.id)
        let correctedAt = Date(timeIntervalSince1970: 220)

        try session.correctReviewedSetCountedReps(setID, to: 5, at: correctedAt)

        let correctedSet = try #require(session.completedSets.last)
        #expect(correctedSet.analysis?.finalizedCountedReps == 4)
        #expect(correctedSet.countedReps == 5)
        #expect(correctedSet.userCorrections.last?.createdAt == correctedAt)
        #expect(correctedSet.userCorrections.last?.field == .countedReps)
        #expect(correctedSet.userCorrections.last?.previousValue == .countedReps(4))
        #expect(correctedSet.userCorrections.last?.newValue == .countedReps(5))
        #expect(correctedSet.userCorrections.last?.reason == .userEdit)
    }

    @Test func manualCleanCorrectionReplacesUnavailableStatusAsUserEvidence() throws {
        var session = try makeSessionWithReviewedSet()
        let setID = try #require(session.completedSets.last?.id)
        let correctedAt = Date(timeIntervalSince1970: 230)

        try session.correctReviewedSetCleanReps(setID, to: 3, at: correctedAt)

        let correctedSet = try #require(session.completedSets.last)
        #expect(correctedSet.analysis?.cleanResult == .unavailable)
        #expect(correctedSet.cleanResult == .userCorrected(cleanReps: 3))
        #expect(correctedSet.userCorrections.last?.createdAt == correctedAt)
        #expect(correctedSet.userCorrections.last?.field == .cleanReps)
        #expect(correctedSet.userCorrections.last?.previousValue == .unavailable)
        #expect(correctedSet.userCorrections.last?.newValue == .cleanReps(3))
        #expect(correctedSet.userCorrections.last?.reason == .userEdit)
    }

    @Test func negativeCountedCorrectionIsRejectedWithoutChangingTheSet() throws {
        var session = try makeSessionWithReviewedSet()
        let setID = try #require(session.completedSets.last?.id)

        #expect(throws: SetCorrectionError.negativeCount(field: .countedReps)) {
            try session.correctReviewedSetCountedReps(setID, to: -1)
        }

        let unchangedSet = try #require(session.completedSets.last)
        #expect(unchangedSet.countedReps == 4)
        #expect(unchangedSet.userCorrections.isEmpty)
    }

    @Test func negativeCleanCorrectionIsRejectedWithoutReplacingUnavailable() throws {
        var session = try makeSessionWithReviewedSet()
        let setID = try #require(session.completedSets.last?.id)

        #expect(throws: SetCorrectionError.negativeCount(field: .cleanReps)) {
            try session.correctReviewedSetCleanReps(setID, to: -1)
        }

        let unchangedSet = try #require(session.completedSets.last)
        #expect(unchangedSet.cleanResult == .unavailable)
        #expect(unchangedSet.userCorrections.isEmpty)
    }

    @Test func cleanCorrectionAboveCurrentCountedRepsIsRejectedWithoutClamping() throws {
        var session = try makeSessionWithReviewedSet()
        let setID = try #require(session.completedSets.last?.id)

        #expect(throws: SetCorrectionError.cleanRepsExceedCounted(
            cleanReps: 5,
            countedReps: 4
        )) {
            try session.correctReviewedSetCleanReps(setID, to: 5)
        }

        let unchangedSet = try #require(session.completedSets.last)
        #expect(unchangedSet.cleanResult == .unavailable)
        #expect(unchangedSet.userCorrections.isEmpty)
    }

    @Test func countedCorrectionBelowUserCorrectedCleanRepsIsRejected() throws {
        var session = try makeSessionWithReviewedSet()
        let setID = try #require(session.completedSets.last?.id)
        try session.correctReviewedSetCleanReps(
            setID,
            to: 3,
            at: Date(timeIntervalSince1970: 230)
        )

        #expect(throws: SetCorrectionError.cleanRepsExceedCounted(
            cleanReps: 3,
            countedReps: 2
        )) {
            try session.correctReviewedSetCountedReps(setID, to: 2)
        }

        let unchangedSet = try #require(session.completedSets.last)
        #expect(unchangedSet.countedReps == 4)
        #expect(unchangedSet.cleanResult == .userCorrected(cleanReps: 3))
        #expect(unchangedSet.userCorrections.count == 1)
    }

    @Test func discardingCorrectedReviewedSetRemovesItAndKeepsCorrectedLoadForRetry() throws {
        var session = try makeSessionWithReviewedSet()
        let setID = try #require(session.completedSets.last?.id)
        let correctedLoad = try TrainingLoad(value: 190, unit: .pounds)
        try session.correctReviewedSetLoad(setID, to: correctedLoad)
        try session.correctReviewedSetCountedReps(setID, to: 5)
        try session.correctReviewedSetCleanReps(setID, to: 4)

        try session.discardCompletedSetFromReview(setID)

        #expect(session.completedSets.isEmpty)
        #expect(session.currentSet.ordinal == 1)
        #expect(session.currentSet.load == correctedLoad)
        #expect(session.currentSet.setupGateOutcome == nil)
    }

    private func makeSessionWithReviewedSet() throws -> QuickSession {
        var session = QuickSession(exerciseID: .backSquat)
        try session.setCurrentSetLoad(TrainingLoad(value: 185, unit: .pounds))
        try session.setCurrentSetSetupGateOutcome(passingSetupOutcome)
        try session.completeCurrentSet(analysis: originalAnalysis)
        return session
    }

    private var passingSetupOutcome: SetupGateOutcome {
        get throws {
            try SetupGateAssessment(statuses: Dictionary(
                uniqueKeysWithValues: SetupCheckID.allCases.map { ($0, .passing) }
            )).approve(at: Date(timeIntervalSince1970: 110))
        }
    }

    private var originalAnalysis: SetAnalysisSummary {
        SetAnalysisSummary(
            provisionalCountedReps: 5,
            finalizedCountedReps: 4,
            cleanResult: .unavailable,
            reps: [],
            framesObserved: 120,
            framesAnalyzed: 118
        )
    }
}
