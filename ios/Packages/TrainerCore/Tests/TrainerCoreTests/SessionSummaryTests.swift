import Foundation
import Testing
@testable import TrainerCore

struct SessionSummaryTests {
    @Test func endingProjectsCompletedSetsInOrderUsingCurrentCorrectedValues() throws {
        let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let firstSetID = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
        let secondSetID = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
        let thirdSetID = UUID(uuidString: "00000000-0000-0000-0000-000000000104")!
        let startedAt = Date(timeIntervalSince1970: 100)
        let firstCompletedAt = Date(timeIntervalSince1970: 120)
        let secondCompletedAt = Date(timeIntervalSince1970: 150)
        let endedAt = Date(timeIntervalSince1970: 180)
        let correctedLoad = try TrainingLoad(value: 190, unit: .pounds)
        var session = QuickSession(
            id: sessionID,
            exerciseID: .backSquat,
            startedAt: startedAt,
            initialSetID: firstSetID
        )

        try session.setCurrentSetLoad(TrainingLoad(value: 185, unit: .pounds))
        try session.setCurrentSetSetupGateOutcome(passingSetupOutcome)
        let first = try session.completeCurrentSet(
            analysis: analysis(countedReps: 4, cleanResult: .unavailable),
            at: firstCompletedAt,
            nextSetID: secondSetID
        )
        try session.correctReviewedSetLoad(
            first.id,
            to: correctedLoad
        )
        try session.correctReviewedSetCountedReps(first.id, to: 5)
        try session.correctReviewedSetCleanReps(first.id, to: 3)

        try session.setCurrentSetSetupGateOutcome(passingSetupOutcome)
        try session.completeCurrentSet(
            analysis: analysis(countedReps: 2, cleanResult: .assessed(cleanReps: 2)),
            at: secondCompletedAt,
            nextSetID: thirdSetID
        )

        let summary = try session.end(at: endedAt)

        #expect(summary.sessionID == sessionID)
        #expect(summary.exerciseID == .backSquat)
        #expect(summary.startedAt == startedAt)
        #expect(summary.endedAt == endedAt)
        #expect(summary.sets.map(\.id) == [firstSetID, secondSetID])
        #expect(summary.sets.map(\.ordinal) == [1, 2])
        #expect(summary.sets.map(\.completedAt) == [firstCompletedAt, secondCompletedAt])
        #expect(summary.sets[0].load == correctedLoad)
        #expect(summary.sets[0].countedReps == 5)
        #expect(summary.sets[0].cleanResult == .userCorrected(cleanReps: 3))
        #expect(summary.sets[1].load == correctedLoad)
        #expect(summary.sets[1].countedReps == 2)
        #expect(summary.sets[1].cleanResult == .analyzerAssessed(cleanReps: 2))
        #expect(summary.totalCountedReps == 7)
    }

    @Test func captureConfidenceDistinguishesPassedOverriddenAndMissingSetup() throws {
        var session = QuickSession(exerciseID: .backSquat)
        try session.setCurrentSetLoad(TrainingLoad(value: 135, unit: .pounds))

        try session.setCurrentSetSetupGateOutcome(passingSetupOutcome)
        try session.completeCurrentSet(
            analysis: analysis(countedReps: 3, cleanResult: .unavailable)
        )

        try session.setCurrentSetSetupGateOutcome(overriddenSetupOutcome)
        try session.completeCurrentSet(
            analysis: analysis(countedReps: 2, cleanResult: .unavailable)
        )

        try session.advanceCurrentSetForCameraIndependentTesting()

        let summary = try session.end()

        #expect(summary.sets.map(\.captureConfidence) == [
            SessionSetCaptureConfidence.standard,
            .low,
            .unavailable
        ])
        #expect(summary.lowConfidenceCaptureCount == 1)
        #expect(summary.sets[2].countedReps == nil)
        #expect(summary.sets[2].cleanResult == nil)
    }

    @Test func totalCountedRepsIsUnavailableWhenAnyCompletedSetLacksAnalysis() throws {
        var fullyAnalyzed = QuickSession(exerciseID: .backSquat)
        try fullyAnalyzed.setCurrentSetLoad(TrainingLoad(value: 95, unit: .kilograms))
        try fullyAnalyzed.setCurrentSetSetupGateOutcome(passingSetupOutcome)
        try fullyAnalyzed.completeCurrentSet(
            analysis: analysis(countedReps: 3, cleanResult: .unavailable)
        )
        try fullyAnalyzed.setCurrentSetSetupGateOutcome(passingSetupOutcome)
        try fullyAnalyzed.completeCurrentSet(
            analysis: analysis(countedReps: 2, cleanResult: .unavailable)
        )

        var missingAnalysis = QuickSession(exerciseID: .backSquat)
        try missingAnalysis.setCurrentSetLoad(TrainingLoad(value: 185, unit: .pounds))
        try missingAnalysis.advanceCurrentSetForCameraIndependentTesting()

        #expect(try fullyAnalyzed.end().totalCountedReps == 5)
        #expect(try missingAnalysis.end().totalCountedReps == nil)
    }

    @Test func discardedSetsAndTheCurrentDraftStayOutOfTheSummary() throws {
        var session = QuickSession(exerciseID: .backSquat)
        let firstLoad = try TrainingLoad(value: 185, unit: .pounds)
        let replacementDraftLoad = try TrainingLoad(value: 87.5, unit: .kilograms)
        try session.setCurrentSetLoad(firstLoad)
        try session.setCurrentSetSetupGateOutcome(passingSetupOutcome)
        let kept = try session.completeCurrentSet(
            analysis: analysis(countedReps: 4, cleanResult: .unavailable)
        )

        try session.setCurrentSetSetupGateOutcome(passingSetupOutcome)
        let discarded = try session.completeCurrentSet(
            analysis: analysis(countedReps: 1, cleanResult: .unavailable)
        )
        try session.discardCompletedSetFromReview(discarded.id)
        try session.setCurrentSetLoad(replacementDraftLoad)
        try session.setCurrentSetSetupGateOutcome(passingSetupOutcome)

        let summary = try session.end()

        #expect(summary.sets.map(\.id) == [kept.id])
        #expect(summary.sets.map(\.load) == [firstLoad])
    }

    @Test func endingWithoutCompletedSetsProducesAnEmptySummary() throws {
        let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000000105")!
        let endedAt = Date(timeIntervalSince1970: 200)
        var session = QuickSession(id: sessionID, exerciseID: .backSquat)

        let summary = try session.end(at: endedAt)

        #expect(summary.sessionID == sessionID)
        #expect(summary.endedAt == endedAt)
        #expect(summary.sets.isEmpty)
        #expect(summary.totalCountedReps == 0)
        #expect(summary.lowConfidenceCaptureCount == 0)
    }

    @Test func completedSetRowsPreserveMixedLoadUnitsWithoutConversion() throws {
        var session = QuickSession(exerciseID: .backSquat)
        let pounds = try TrainingLoad(value: 185, unit: .pounds)
        let kilograms = try TrainingLoad(value: 87.5, unit: .kilograms)

        try session.setCurrentSetLoad(pounds)
        try session.setCurrentSetSetupGateOutcome(passingSetupOutcome)
        try session.completeCurrentSet(
            analysis: analysis(countedReps: 4, cleanResult: .unavailable)
        )

        try session.setCurrentSetLoad(kilograms)
        try session.setCurrentSetSetupGateOutcome(passingSetupOutcome)
        try session.completeCurrentSet(
            analysis: analysis(countedReps: 3, cleanResult: .unavailable)
        )

        let summary = try session.end()

        #expect(summary.sets.map(\.load) == [pounds, kilograms])
    }

    private var passingSetupOutcome: SetupGateOutcome {
        get throws {
            try SetupGateAssessment(statuses: Dictionary(
                uniqueKeysWithValues: SetupCheckID.allCases.map { ($0, .passing) }
            )).approve(at: Date(timeIntervalSince1970: 110))
        }
    }

    private var overriddenSetupOutcome: SetupGateOutcome {
        get throws {
            var statuses = Dictionary(
                uniqueKeysWithValues: SetupCheckID.allCases.map { ($0, SetupCheckStatus.passing) }
            )
            statuses[.sideViewLikely] = .failing
            return try SetupGateAssessment(statuses: statuses).overrideFailures(
                at: Date(timeIntervalSince1970: 111)
            )
        }
    }

    private func analysis(
        countedReps: Int,
        cleanResult: SetCleanResult
    ) -> SetAnalysisSummary {
        SetAnalysisSummary(
            provisionalCountedReps: countedReps,
            finalizedCountedReps: countedReps,
            cleanResult: cleanResult,
            reps: [],
            framesObserved: countedReps * 30,
            framesAnalyzed: countedReps * 30
        )
    }
}
