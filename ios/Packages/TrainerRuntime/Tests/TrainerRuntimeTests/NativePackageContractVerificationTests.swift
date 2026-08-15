import Foundation
import PoseCore
import SquatAnalysis
import Testing
import TrainerCore
import TrainerRuntime

@Test
func deterministicPoseSequenceComposesPublicPackageContracts() throws {
    let analyzerConfiguration = SquatAnalysisConfiguration(
        minimumFrameConfidence: 0.5,
        minimumLandmarkConfidence: 0.5,
        minimumStandingKneeAngleDegrees: 145,
        standingCalibrationDurationSeconds: 0.2,
        minimumStandingCalibrationSamples: 3,
        descentStartKneeFlexionDegrees: 10,
        descentStartHipRatio: 0.02,
        minimumCountedKneeFlexionDegrees: 30,
        minimumCountedHipDescentRatio: 0.08,
        ascentReversalDegrees: 5,
        standingReturnToleranceDegrees: 15,
        standingHipReturnToleranceRatio: 0.06,
        minimumRepDurationSeconds: 0.5,
        maximumRepDurationSeconds: 4,
        maximumEvidenceGapSeconds: 0.5,
        smoothingFactor: 1
    )
    var pipeline = TrainerPoseObservationPipeline(
        setupSignalWindow: SetupGateSignalWindow(
            capacity: 3,
            minimumSamples: 3,
            passingRatio: 1
        ),
        retentionPolicy: ActiveSetPoseRetentionPolicy(
            maximumFrameCount: 30,
            maximumDurationSeconds: 10
        ),
        analyzerConfiguration: analyzerConfiguration
    )

    for (offset, frame) in standingFrames(startingAt: 0).enumerated() {
        _ = try pipeline.observe(
            LivePoseObservation(
                frame: frame,
                inferenceLatencyMilliseconds: 5,
                sourceSequenceNumber: UInt64(offset + 1)
            ),
            phoneStable: true
        )
    }

    #expect(pipeline.setupAssessment.isReady)
    let setupOutcome = try pipeline.setupAssessment.approve(
        at: Date(timeIntervalSince1970: 10)
    )

    try pipeline.beginActiveSet(afterSourceSequence: 3)
    let activeFrames = countedRepFrames(startingAt: 1)
    for (offset, frame) in activeFrames.enumerated() {
        _ = try pipeline.observe(
            LivePoseObservation(
                frame: frame,
                inferenceLatencyMilliseconds: 5,
                sourceSequenceNumber: UInt64(offset + 4)
            ),
            phoneStable: true
        )
    }

    let sequence = try pipeline.stopActiveSet()
    #expect(sequence.frames == activeFrames)
    #expect(sequence.provisionalCountedReps == 1)

    let finalized = SquatAnalyzer(configuration: sequence.analyzerConfiguration)
        .analyze(frames: sequence.frames)
    let summary = TrainerSetAnalysisMapper.summary(
        from: finalized,
        provisionalCountedReps: sequence.provisionalCountedReps
    )

    #expect(summary.provisionalCountedReps == 1)
    #expect(summary.finalizedCountedReps == 1)
    #expect(summary.cleanResult == .unavailable)
    #expect(summary.reps.count == 1)
    #expect(summary.reps.first?.quality == .unavailable)

    var session = QuickSession(
        exerciseID: .backSquat,
        startedAt: Date(timeIntervalSince1970: 0)
    )
    try session.setCurrentSetLoad(TrainingLoad(value: 185, unit: .pounds))
    try session.setCurrentSetSetupGateOutcome(setupOutcome)
    let completedSet = try session.completeCurrentSet(
        analysis: summary,
        at: Date(timeIntervalSince1970: 20)
    )

    #expect(completedSet.countedReps == 1)
    #expect(completedSet.cleanResult == .unavailable)
    #expect(completedSet.setupGateOutcome?.disposition == .passed)

    let workoutSummary = try session.end(at: Date(timeIntervalSince1970: 30))
    #expect(workoutSummary.totalCountedReps == 1)
    #expect(workoutSummary.sets.count == 1)
    #expect(workoutSummary.sets.first?.cleanResult == .unavailable)
    #expect(workoutSummary.sets.first?.captureConfidence == .standard)
}

private func standingFrames(startingAt start: Double) -> [PoseFrame] {
    [
        makeFullBodyFrame(timestamp: start, kneeAngle: 170, hipY: 0.34),
        makeFullBodyFrame(timestamp: start + 0.1, kneeAngle: 170, hipY: 0.34),
        makeFullBodyFrame(timestamp: start + 0.2, kneeAngle: 170, hipY: 0.34)
    ]
}

private func countedRepFrames(startingAt start: Double) -> [PoseFrame] {
    standingFrames(startingAt: start) + [
        makeFullBodyFrame(timestamp: start + 0.3, kneeAngle: 157, hipY: 0.355),
        makeFullBodyFrame(timestamp: start + 0.4, kneeAngle: 145, hipY: 0.38),
        makeFullBodyFrame(timestamp: start + 0.5, kneeAngle: 125, hipY: 0.43),
        makeFullBodyFrame(timestamp: start + 0.6, kneeAngle: 120, hipY: 0.45),
        makeFullBodyFrame(timestamp: start + 0.7, kneeAngle: 130, hipY: 0.43),
        makeFullBodyFrame(timestamp: start + 0.8, kneeAngle: 145, hipY: 0.39),
        makeFullBodyFrame(timestamp: start + 0.9, kneeAngle: 158, hipY: 0.36)
    ]
}

private func makeFullBodyFrame(
    timestamp: Double,
    kneeAngle: Double,
    hipY: Double
) -> PoseFrame {
    let kneeX = 0.5
    let kneeY = 0.62
    let shinLength = 0.24
    let radians = kneeAngle * .pi / 180
    let ankleX = kneeX + sin(radians) * shinLength
    let ankleY = kneeY - cos(radians) * shinLength

    return PoseFrame(
        timestampSeconds: timestamp,
        landmarks: [
            PoseLandmark(name: .nose, x: 0.5, y: 0.08, confidence: 0.95),
            PoseLandmark(name: .leftShoulder, x: 0.49, y: 0.18, confidence: 0.95),
            PoseLandmark(name: .rightShoulder, x: 0.51, y: 0.18, confidence: 0.80),
            PoseLandmark(name: .leftHip, x: kneeX, y: hipY, confidence: 0.95),
            PoseLandmark(name: .rightHip, x: 0.52, y: hipY, confidence: 0.80),
            PoseLandmark(name: .leftKnee, x: kneeX, y: kneeY, confidence: 0.95),
            PoseLandmark(name: .leftAnkle, x: ankleX, y: ankleY, confidence: 0.95),
            PoseLandmark(
                name: .leftHeel,
                x: ankleX - 0.01,
                y: ankleY + 0.02,
                confidence: 0.95
            ),
            PoseLandmark(
                name: .leftFootIndex,
                x: ankleX + 0.03,
                y: ankleY + 0.02,
                confidence: 0.95
            )
        ],
        frameConfidence: 0.90
    )
}
