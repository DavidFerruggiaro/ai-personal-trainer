import Foundation
import Testing
@testable import TrainerCore

struct StartSetArmingTests {
    @Test func setupPassingAloneDoesNotLaunchUntilArmed() throws {
        var arming = StartSetArming()
        let ready = try passingAssessment()

        #expect(arming.launchIfReady(given: ready) == nil)

        arming.arm(.waitForPassingSetup)
        #expect(arming.launchIfReady(given: ready) == .approve)
    }

    @Test func armedPassingModeWaitsThroughPendingAndFailingChecks() throws {
        var arming = StartSetArming()
        arming.arm(.waitForPassingSetup)

        #expect(arming.launchIfReady(given: .pending) == nil)
        #expect(arming.launchIfReady(given: try failingAssessment()) == nil)
        #expect(arming.launchIfReady(given: try passingAssessment()) == .approve)
    }

    @Test func overrideModeLaunchesOnceChecksAreEvaluated() throws {
        var arming = StartSetArming()
        arming.arm(.waitForEvaluatedSetupAllowingOverride)

        #expect(arming.launchIfReady(given: .pending) == nil)
        #expect(arming.launchIfReady(given: try failingAssessment()) == .overrideFailures)
        #expect(arming.launchIfReady(given: try passingAssessment()) == .approve)
    }

    @Test func cancelReturnsToIdle() {
        var arming = StartSetArming()
        arming.arm(.waitForPassingSetup)
        #expect(arming.isArmed)

        arming.cancel()
        #expect(!arming.isArmed)
        #expect(arming.state == .idle)
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
