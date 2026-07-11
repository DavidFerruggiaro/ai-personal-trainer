import Foundation
import Testing
@testable import TrainerCore

struct SetupGateTests {
    @Test func pendingAssessmentContainsAllFourLockedChecks() {
        let assessment = SetupGateAssessment.pending

        #expect(assessment.checks.map(\.id) == SetupCheckID.allCases)
        #expect(assessment.checks.allSatisfy { $0.status == .pending })
        #expect(!assessment.isReady)
        #expect(throws: SetupGateError.checksPending) {
            try assessment.approve()
        }
        #expect(throws: SetupGateError.checksPending) {
            try assessment.overrideFailures()
        }
    }

    @Test func passingAssessmentDoesNotForceLowConfidenceLabel() throws {
        let decidedAt = Date(timeIntervalSince1970: 200)
        let assessment = assessment(with: .passing)

        let outcome = try assessment.approve(at: decidedAt)

        #expect(assessment.isReady)
        #expect(outcome.decidedAt == decidedAt)
        #expect(!outcome.overrideUsed)
        #expect(outcome.disposition == .passed)
        #expect(!outcome.requiresLowConfidenceLabel)
        #expect(outcome.failedCheckIDs.isEmpty)
        #expect(throws: SetupGateError.overrideUnavailable) {
            try assessment.overrideFailures()
        }
    }

    @Test func failedAssessmentProvidesConcreteFixAndLowConfidenceOverride() throws {
        let decidedAt = Date(timeIntervalSince1970: 220)
        let assessment = SetupGateAssessment(statuses: [
            .fullBodyVisible: .failing,
            .sideViewLikely: .passing,
            .phoneStable: .passing,
            .poseConfidenceOK: .failing
        ])

        #expect(!assessment.isReady)
        #expect(assessment.check(withID: .fullBodyVisible)?.id.failureFix == "Move the phone back until your full body stays in frame.")
        #expect(throws: SetupGateError.checksFailing) {
            try assessment.approve()
        }

        let outcome = try assessment.overrideFailures(at: decidedAt)

        #expect(outcome.overrideUsed)
        #expect(outcome.disposition == .overridden)
        #expect(outcome.requiresLowConfidenceLabel)
        #expect(outcome.failedCheckIDs == [.fullBodyVisible, .poseConfidenceOK])
    }

    @Test func setupOutcomeRequiresLoadAndResetsForTheNextSet() throws {
        var session = QuickSession(exerciseID: .backSquat)
        let load = try TrainingLoad(value: 185, unit: .pounds)
        let outcome = try assessment(with: .passing).approve()

        #expect(throws: QuickSessionError.missingLoad) {
            try session.setCurrentSetSetupGateOutcome(outcome)
        }

        try session.setCurrentSetLoad(load)
        #expect(throws: QuickSessionError.missingSetupGateOutcome) {
            try session.completeCurrentSet(analysis: unavailableAnalysis)
        }
        try session.setCurrentSetSetupGateOutcome(outcome)
        #expect(session.currentSet.setupGateOutcome == outcome)

        try session.clearCurrentSetSetupGateOutcome()
        #expect(session.currentSet.setupGateOutcome == nil)
        try session.setCurrentSetSetupGateOutcome(outcome)

        let completed = try session.completeCurrentSet(analysis: unavailableAnalysis)

        #expect(completed.setupGateOutcome == outcome)
        #expect(session.currentSet.load == load)
        #expect(session.currentSet.setupGateOutcome == nil)
    }

    private func assessment(with status: SetupCheckStatus) -> SetupGateAssessment {
        SetupGateAssessment(statuses: Dictionary(
            uniqueKeysWithValues: SetupCheckID.allCases.map { ($0, status) }
        ))
    }

    private var unavailableAnalysis: SetAnalysisSummary {
        SetAnalysisSummary(
            provisionalCountedReps: 0,
            finalizedCountedReps: 0,
            cleanResult: .unavailable,
            reps: [],
            framesObserved: 0,
            framesAnalyzed: 0
        )
    }
}
