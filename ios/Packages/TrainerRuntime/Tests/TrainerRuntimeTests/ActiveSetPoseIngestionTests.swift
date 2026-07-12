import PoseCore
import Testing
@testable import TrainerRuntime

@Test
func activeSetIngestionRetainsEveryObservationInOrder() throws {
    var ingestion = ActiveSetPoseIngestion(
        retentionPolicy: ActiveSetPoseRetentionPolicy(
            maximumFrameCount: 20,
            maximumDurationSeconds: 20
        )
    )
    try ingestion.begin()

    let frames = (0..<10).map { index in
        PoseFrame(
            timestampSeconds: Double(index) / 30,
            landmarks: [],
            frameConfidence: nil
        )
    }
    for frame in frames {
        _ = try ingestion.observe(frame)
    }

    let sequence = try ingestion.stop()

    #expect(sequence.frames == frames)
    #expect(sequence.streamingFramesObserved == frames.count)
}

@Test
func stoppingFreezesTheFinalizedSequence() throws {
    var ingestion = ActiveSetPoseIngestion()
    try ingestion.begin()
    let first = poseFrame(at: 0)
    try ingestion.observe(first)

    let sequence = try ingestion.stop()

    #expect(throws: ActiveSetPoseIngestionError.invalidPhase) {
        try ingestion.observe(poseFrame(at: 1))
    }
    #expect(sequence.frames == [first])
}

@Test
func discardingClearsTheRetainedSequence() throws {
    var ingestion = ActiveSetPoseIngestion()
    try ingestion.begin()
    try ingestion.observe(poseFrame(at: 0))

    try ingestion.discard()

    #expect(ingestion.status.phase == .discarded)
    #expect(ingestion.status.framesObserved == 0)
}

@Test
func exceedingTheFrameRetentionLimitRejectsPartialFinalization() throws {
    var ingestion = ActiveSetPoseIngestion(
        retentionPolicy: ActiveSetPoseRetentionPolicy(
            maximumFrameCount: 2,
            maximumDurationSeconds: 20
        )
    )
    try ingestion.begin()
    try ingestion.observe(poseFrame(at: 0))
    try ingestion.observe(poseFrame(at: 1))

    #expect(throws: ActiveSetPoseIngestionError.retentionLimitExceeded) {
        try ingestion.observe(poseFrame(at: 2))
    }

    #expect(ingestion.status.phase == .failed)
    #expect(ingestion.status.framesObserved == 2)
    #expect(ingestion.retainedFrameCount == 0)
    #expect(throws: ActiveSetPoseIngestionError.invalidPhase) {
        try ingestion.stop()
    }
}

@Test
func exceedingTheDurationRetentionLimitRejectsPartialFinalization() throws {
    var ingestion = ActiveSetPoseIngestion(
        retentionPolicy: ActiveSetPoseRetentionPolicy(
            maximumFrameCount: 20,
            maximumDurationSeconds: 1
        )
    )
    try ingestion.begin()
    try ingestion.observe(poseFrame(at: 10))

    #expect(throws: ActiveSetPoseIngestionError.retentionLimitExceeded) {
        try ingestion.observe(poseFrame(at: 11.01))
    }

    #expect(ingestion.status.phase == .failed)
    #expect(ingestion.status.framesObserved == 1)
    #expect(ingestion.retainedFrameCount == 0)
}

@Test
func eventDeliveryLossClearsEvidenceAndRejectsFinalization() throws {
    var ingestion = ActiveSetPoseIngestion()
    try ingestion.begin()
    try ingestion.observe(poseFrame(at: 1))

    let failedStatus = ingestion.invalidateForEventDeliveryDrop()

    #expect(failedStatus.phase == .failed)
    #expect(failedStatus.framesObserved == 1)
    #expect(ingestion.retainedFrameCount == 0)
    #expect(throws: ActiveSetPoseIngestionError.invalidPhase) {
        try ingestion.stop()
    }
}

@Test
func beginningTheNextSetDoesNotReusePriorFrames() throws {
    var ingestion = ActiveSetPoseIngestion()
    try ingestion.begin()
    try ingestion.observe(poseFrame(at: 1))
    _ = try ingestion.stop()

    try ingestion.begin()
    let nextSetFrame = poseFrame(at: 2)
    try ingestion.observe(nextSetFrame)
    let nextSetSequence = try ingestion.stop()

    #expect(nextSetSequence.frames == [nextSetFrame])
    #expect(nextSetSequence.streamingFramesObserved == 1)
}

@Test
func exactDurationLimitIsAccepted() throws {
    var ingestion = ActiveSetPoseIngestion(
        retentionPolicy: ActiveSetPoseRetentionPolicy(
            maximumFrameCount: 10,
            maximumDurationSeconds: 1
        )
    )
    try ingestion.begin()
    try ingestion.observe(poseFrame(at: 10))
    try ingestion.observe(poseFrame(at: 11))

    #expect(try ingestion.stop().frames.count == 2)
}

@Test
func stoppingWithoutObservationsProducesAnEmptySequence() throws {
    var ingestion = ActiveSetPoseIngestion()
    try ingestion.begin()

    let sequence = try ingestion.stop()

    #expect(sequence.frames.isEmpty)
    #expect(sequence.streamingFramesObserved == 0)
}

private func poseFrame(at timestampSeconds: Double) -> PoseFrame {
    PoseFrame(
        timestampSeconds: timestampSeconds,
        landmarks: [],
        frameConfidence: nil
    )
}
