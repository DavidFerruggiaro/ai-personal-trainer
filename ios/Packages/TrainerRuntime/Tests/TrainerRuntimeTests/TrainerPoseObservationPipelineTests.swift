import PoseCore
import Testing
import TrainerCore
@testable import TrainerRuntime

@Test
func oneObservationFansOutToPreviewSetupAndActiveIngestion() throws {
    var pipeline = TrainerPoseObservationPipeline(
        setupSignalWindow: SetupGateSignalWindow(
            capacity: 1,
            minimumSamples: 1,
            passingRatio: 1
        ),
        retentionPolicy: ActiveSetPoseRetentionPolicy(
            maximumFrameCount: 10,
            maximumDurationSeconds: 10
        )
    )
    try pipeline.beginActiveSet(afterSourceSequence: 0)
    let frame = PoseFrame(timestampSeconds: 1, landmarks: [], frameConfidence: nil)
    let observation = LivePoseObservation(
        frame: frame,
        inferenceLatencyMilliseconds: 5,
        sourceSequenceNumber: 1
    )

    let output = try pipeline.observe(observation, phoneStable: true)

    #expect(output.latestPoseFrame == frame)
    #expect(output.setupAssessment.check(withID: .fullBodyVisible)?.status == .failing)
    #expect(output.setupAssessment.check(withID: .phoneStable)?.status == .passing)
    #expect(output.activeSetPoseStatus.framesObserved == 1)
    #expect(try pipeline.stopActiveSet().frames == [frame])
}

@Test
func observationsEmittedBeforeTheStartBoundaryStayOutOfTheActiveSet() throws {
    var pipeline = TrainerPoseObservationPipeline(
        setupSignalWindow: SetupGateSignalWindow(
            capacity: 1,
            minimumSamples: 1,
            passingRatio: 1
        )
    )
    try pipeline.beginActiveSet(afterSourceSequence: 5)
    let preStartFrame = PoseFrame(timestampSeconds: 1, landmarks: [], frameConfidence: nil)
    let activeFrame = PoseFrame(timestampSeconds: 2, landmarks: [], frameConfidence: nil)

    let preStartOutput = try pipeline.observe(
        LivePoseObservation(
            frame: preStartFrame,
            inferenceLatencyMilliseconds: 5,
            sourceSequenceNumber: 5
        ),
        phoneStable: true
    )
    let activeOutput = try pipeline.observe(
        LivePoseObservation(
            frame: activeFrame,
            inferenceLatencyMilliseconds: 5,
            sourceSequenceNumber: 6
        ),
        phoneStable: true
    )

    #expect(preStartOutput.latestPoseFrame == preStartFrame)
    #expect(preStartOutput.setupAssessment.check(withID: .phoneStable)?.status == .passing)
    #expect(preStartOutput.activeSetPoseStatus.framesObserved == 0)
    #expect(activeOutput.activeSetPoseStatus.framesObserved == 1)
    #expect(try pipeline.stopActiveSet().frames == [activeFrame])
}
