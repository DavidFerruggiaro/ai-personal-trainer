import Foundation
import Testing
@testable import TrainerCore

struct StartSetArmingTests {
    @Test func armedWeakSetupLatchesOnlyAfterTheSoloPositioningGracePeriod() throws {
        let armedAt = Date(timeIntervalSince1970: 1_000)
        let failing = try failingAssessment()
        var arming = StartSetArming(weakSetupGraceDuration: 10)

        arming.arm(at: armedAt)

        #expect(arming.observe(failing, at: armedAt.addingTimeInterval(9)) == nil)
        #expect(arming.latchedWeakSetup == nil)

        #expect(arming.observe(failing, at: armedAt.addingTimeInterval(10)) == nil)
        #expect(arming.latchedWeakSetup == failing)
    }

    @Test func latchedWeakSetupSurvivesLiveEvidenceChangingWhenUserReturns() throws {
        let armedAt = Date(timeIntervalSince1970: 1_000)
        let failing = try failingAssessment()
        var arming = StartSetArming(weakSetupGraceDuration: 10)
        arming.arm(at: armedAt)
        _ = arming.observe(failing, at: armedAt.addingTimeInterval(10))

        let launch = arming.observe(
            try passingAssessment(),
            at: armedAt.addingTimeInterval(11)
        )

        #expect(launch == nil)
        #expect(arming.latchedWeakSetup == failing)
    }

    @Test func retryClearsTheLatchAndStartsAFreshArmedEvaluation() throws {
        let armedAt = Date(timeIntervalSince1970: 1_000)
        let retryAt = armedAt.addingTimeInterval(20)
        let failing = try failingAssessment()
        var arming = StartSetArming(weakSetupGraceDuration: 10)
        arming.arm(at: armedAt)
        _ = arming.observe(failing, at: armedAt.addingTimeInterval(10))

        arming.retryWeakSetup(at: retryAt)

        #expect(arming.latchedWeakSetup == nil)
        #expect(arming.isArmed)
        #expect(arming.observe(failing, at: retryAt.addingTimeInterval(9)) == nil)
        #expect(arming.latchedWeakSetup == nil)
        let passing = try passingAssessment()
        #expect(
            arming.observe(
                passing,
                at: retryAt.addingTimeInterval(9)
            ) == passing
        )
    }

    @Test func acceptingLatchedWeakSetupReturnsLowConfidenceOutcomeFromSavedEvidence() throws {
        let armedAt = Date(timeIntervalSince1970: 1_000)
        let acceptedAt = armedAt.addingTimeInterval(20)
        let failing = try failingAssessment()
        var arming = StartSetArming(weakSetupGraceDuration: 10)
        arming.arm(at: armedAt)
        _ = arming.observe(failing, at: armedAt.addingTimeInterval(10))

        let outcome = try arming.acceptWeakSetup(at: acceptedAt)

        #expect(outcome.disposition == .overridden)
        #expect(outcome.decidedAt == acceptedAt)
        #expect(outcome.failedCheckIDs == [.phoneStable])
        #expect(outcome.requiresLowConfidenceLabel)
        #expect(!arming.isArmed)
        #expect(arming.latchedWeakSetup == nil)
    }

    @Test func setupPassingAloneDoesNotLaunchUntilArmed() throws {
        var arming = StartSetArming()
        let ready = try passingAssessment()

        #expect(arming.observe(ready) == nil)

        arming.arm()
        #expect(arming.observe(ready) == ready)
    }

    @Test func armedFlowWaitsThroughPendingAndTransientFailingChecks() throws {
        let armedAt = Date(timeIntervalSince1970: 1_000)
        var arming = StartSetArming(weakSetupGraceDuration: 10)
        arming.arm(at: armedAt)

        #expect(arming.observe(.pending, at: armedAt.addingTimeInterval(1)) == nil)
        #expect(
            arming.observe(
                try failingAssessment(),
                at: armedAt.addingTimeInterval(9)
            ) == nil
        )
        let passing = try passingAssessment()
        #expect(arming.observe(passing, at: armedAt.addingTimeInterval(9)) == passing)
    }

    @Test func cancelClearsArmingAndAnyLatchedWeakSetup() throws {
        let armedAt = Date(timeIntervalSince1970: 1_000)
        var arming = StartSetArming(weakSetupGraceDuration: 0)
        arming.arm(at: armedAt)
        _ = arming.observe(try failingAssessment(), at: armedAt)
        #expect(arming.isArmed)
        #expect(arming.latchedWeakSetup != nil)

        arming.cancel()
        #expect(!arming.isArmed)
        #expect(arming.state == .idle)
        #expect(arming.latchedWeakSetup == nil)
    }

    private func passingAssessment() throws -> SetupGateAssessment {
        SetupGateAssessment(statuses: Dictionary(
            uniqueKeysWithValues: SetupCheckID.allCases.map { ($0, .passing) }
        ))
    }

    private func failingAssessment() throws -> SetupGateAssessment {
        var statuses = Dictionary(
            uniqueKeysWithValues: SetupCheckID.allCases.map { ($0, SetupCheckStatus.passing) }
        )
        statuses[.phoneStable] = .failing
        return SetupGateAssessment(statuses: statuses)
    }
}
