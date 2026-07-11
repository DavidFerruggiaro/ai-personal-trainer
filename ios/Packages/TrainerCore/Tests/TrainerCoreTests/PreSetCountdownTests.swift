import Foundation
import Testing
@testable import TrainerCore

struct PreSetCountdownTests {
    @Test func defaultsToFiveSecondsAndBecomesCaptureReadyWithoutSecondTap() throws {
        var countdown = PreSetCountdown()
        countdown.start(after: try passingOutcome())

        #expect(countdown.state == .counting(remainingSeconds: 5))
        for remaining in [4, 3, 2, 1] {
            countdown.tick(fullBodyVisibleAtEnd: true)
            #expect(countdown.state == .counting(remainingSeconds: remaining))
        }
        countdown.tick(fullBodyVisibleAtEnd: true)

        #expect(countdown.state == .readyForActiveCapture)
    }

    @Test func missingFullBodyAtEndRequiresExplicitStartAnywayOrReset() throws {
        var countdown = PreSetCountdown(durationSeconds: 1)
        countdown.start(after: try passingOutcome())
        countdown.tick(fullBodyVisibleAtEnd: false)

        #expect(countdown.state == .visibilityConfirmationRequired)

        countdown.startAnyway()
        #expect(countdown.state == .readyForActiveCapture)

        countdown.reset()
        #expect(countdown.state == .idle)
    }

    private func passingOutcome() throws -> SetupGateOutcome {
        try SetupGateAssessment(statuses: Dictionary(
            uniqueKeysWithValues: SetupCheckID.allCases.map { ($0, .passing) }
        )).approve(at: Date(timeIntervalSince1970: 100))
    }
}
