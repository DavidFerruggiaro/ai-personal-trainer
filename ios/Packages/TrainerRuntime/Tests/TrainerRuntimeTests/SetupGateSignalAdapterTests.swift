import PoseCore
import Testing
import TrainerCore
@testable import TrainerRuntime

@Test
func unknownSideViewEvidenceRemainsUnknown() {
    let evidence = PoseSetupEvidence(
        fullBodyVisible: true,
        sideViewLikely: nil,
        poseConfidenceOK: true,
        primaryVisibleSide: .left,
        lowerBodyConfidence: 0.90
    )

    let sample = SetupGateSignalAdapter.sample(
        from: evidence,
        phoneStable: true
    )

    #expect(sample.sideViewLikely == nil)
}

@Test
func unknownSideViewSamplesDoNotDiluteLaterPassingEvidence() {
    var window = SetupGateSignalWindow(
        capacity: 4,
        minimumSamples: 2,
        passingRatio: 1
    )

    for _ in 0..<4 {
        window.observe(SetupGateSignalAdapter.sample(
            from: evidence(sideViewLikely: nil),
            phoneStable: true
        ))
    }

    #expect(window.assessment.check(withID: .sideViewLikely)?.status == .pending)

    for _ in 0..<2 {
        window.observe(SetupGateSignalAdapter.sample(
            from: evidence(sideViewLikely: true),
            phoneStable: true
        ))
    }

    #expect(window.assessment.check(withID: .sideViewLikely)?.status == .passing)
}

@Test
func explicitSideViewFailureStillContributesToTheWindow() {
    var window = SetupGateSignalWindow(
        capacity: 2,
        minimumSamples: 2,
        passingRatio: 0.80
    )

    for _ in 0..<2 {
        window.observe(SetupGateSignalAdapter.sample(
            from: evidence(sideViewLikely: false),
            phoneStable: true
        ))
    }

    #expect(window.assessment.check(withID: .sideViewLikely)?.status == .failing)
}

private func evidence(sideViewLikely: Bool?) -> PoseSetupEvidence {
    PoseSetupEvidence(
        fullBodyVisible: true,
        sideViewLikely: sideViewLikely,
        poseConfidenceOK: true,
        primaryVisibleSide: .left,
        lowerBodyConfidence: 0.90
    )
}
