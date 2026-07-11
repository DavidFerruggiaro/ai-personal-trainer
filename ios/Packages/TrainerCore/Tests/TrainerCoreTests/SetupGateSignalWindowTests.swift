import Testing
@testable import TrainerCore

struct SetupGateSignalWindowTests {
    @Test func staysPendingUntilEveryCheckHasEnoughEvidence() {
        var window = SetupGateSignalWindow(capacity: 3, minimumSamples: 2)
        window.observe(sample(phoneStable: nil))
        window.observe(sample(phoneStable: nil))

        #expect(window.assessment.check(withID: .fullBodyVisible)?.status == .passing)
        #expect(window.assessment.check(withID: .phoneStable)?.status == .pending)
        #expect(!window.assessment.isReady)
    }

    @Test func usesPassingRatioAcrossTheBoundedWindow() {
        var window = SetupGateSignalWindow(capacity: 4, minimumSamples: 4, passingRatio: 0.75)
        window.observe(sample(fullBodyVisible: false))
        window.observe(sample())
        window.observe(sample())
        window.observe(sample())

        #expect(window.assessment.check(withID: .fullBodyVisible)?.status == .passing)

        window.observe(sample(fullBodyVisible: false))

        #expect(window.assessment.check(withID: .fullBodyVisible)?.status == .passing)

        window.observe(sample(fullBodyVisible: false))

        #expect(window.assessment.check(withID: .fullBodyVisible)?.status == .failing)
    }

    @Test func resetReturnsEveryCheckToPending() {
        var window = SetupGateSignalWindow(capacity: 2, minimumSamples: 1)
        window.observe(sample())
        #expect(window.assessment.isReady)

        window.reset()

        #expect(window.assessment == .pending)
    }

    private func sample(
        fullBodyVisible: Bool? = true,
        phoneStable: Bool? = true
    ) -> SetupGateSignalSample {
        SetupGateSignalSample(
            fullBodyVisible: fullBodyVisible,
            sideViewLikely: true,
            phoneStable: phoneStable,
            poseConfidenceOK: true
        )
    }
}
