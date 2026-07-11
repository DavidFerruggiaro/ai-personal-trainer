import Testing
@testable import PoseCore

struct PoseSetupEvidenceTests {
    @Test func sideViewWithOneCompleteVisibleSidePassesSetupEvidence() {
        let frame = PoseFrame(
            timestampSeconds: 0,
            landmarks: sideViewLandmarks(),
            frameConfidence: 0.9
        )

        let evidence = PoseSetupEvidenceExtractor().evidence(from: frame)

        #expect(evidence.fullBodyVisible)
        #expect(evidence.sideViewLikely == true)
        #expect(evidence.poseConfidenceOK)
        #expect(evidence.primaryVisibleSide == .left)
    }

    @Test func frontViewFailsSideViewSignal() {
        var landmarks = sideViewLandmarks()
        replace(&landmarks, .leftShoulder, x: 0.30)
        replace(&landmarks, .rightShoulder, x: 0.70)
        replace(&landmarks, .leftHip, x: 0.40)
        replace(&landmarks, .rightHip, x: 0.60)

        let evidence = PoseSetupEvidenceExtractor().evidence(from: PoseFrame(
            timestampSeconds: 0,
            landmarks: landmarks
        ))

        #expect(evidence.sideViewLikely == false)
    }

    @Test func missingFootFailsFullBodyAndLowerBodyConfidence() {
        let landmarks = sideViewLandmarks().filter { $0.name != .leftFootIndex }

        let evidence = PoseSetupEvidenceExtractor().evidence(from: PoseFrame(
            timestampSeconds: 0,
            landmarks: landmarks
        ))

        #expect(!evidence.fullBodyVisible)
        #expect(!evidence.poseConfidenceOK)
    }

    private func sideViewLandmarks() -> [PoseLandmark] {
        [
            landmark(.nose, 0.50, 0.08, 0.95),
            landmark(.leftShoulder, 0.49, 0.25, 0.95),
            landmark(.rightShoulder, 0.52, 0.25, 0.75),
            landmark(.leftHip, 0.50, 0.48, 0.95),
            landmark(.rightHip, 0.52, 0.48, 0.75),
            landmark(.leftKnee, 0.51, 0.68, 0.95),
            landmark(.leftAnkle, 0.51, 0.86, 0.95),
            landmark(.leftHeel, 0.49, 0.92, 0.95),
            landmark(.leftFootIndex, 0.55, 0.93, 0.95)
        ]
    }

    private func landmark(
        _ name: PoseLandmarkName,
        _ x: Double,
        _ y: Double,
        _ confidence: Double
    ) -> PoseLandmark {
        PoseLandmark(name: name, x: x, y: y, confidence: confidence)
    }

    private func replace(
        _ landmarks: inout [PoseLandmark],
        _ name: PoseLandmarkName,
        x: Double
    ) {
        guard let index = landmarks.firstIndex(where: { $0.name == name }) else {
            return
        }
        let old = landmarks[index]
        landmarks[index] = landmark(name, x, old.y, old.confidence)
    }
}
