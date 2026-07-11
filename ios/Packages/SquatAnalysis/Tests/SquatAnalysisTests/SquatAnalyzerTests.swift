import XCTest
import PoseCore
@testable import SquatAnalysis

final class SquatAnalyzerTests: XCTestCase {
    func testAnalyzerFiltersLowConfidenceFrames() {
        let analyzer = SquatAnalyzer(
            configuration: SquatAnalysisConfiguration(
                minimumFrameConfidence: 0.5,
                standingCalibrationDurationSeconds: 0.1,
                minimumStandingCalibrationSamples: 2,
                smoothingFactor: 1
            )
        )

        let result = analyzer.analyze(frames: [
            makeLegFrame(timestamp: 0, kneeAngle: 170, hipY: 0.34, frameConfidence: 0.9),
            makeLegFrame(timestamp: 1, kneeAngle: 170, hipY: 0.34, frameConfidence: 0.2),
            makeLegFrame(timestamp: 2, kneeAngle: 170, hipY: 0.34, frameConfidence: nil)
        ])

        XCTAssertEqual(result.framesObserved, 3)
        XCTAssertEqual(result.framesAnalyzed, 2)
    }

    func testStreamingAnalyzerCountsCompletedCycleWithoutDeclaringItClean() throws {
        var analyzer = SquatAnalyzer(configuration: streamingConfiguration)
        var updates: [SquatAnalyzerUpdate] = []

        for frame in countedRepFrames {
            updates.append(analyzer.observe(frame: frame))
        }

        XCTAssertEqual(analyzer.result.countedReps, 1)
        XCTAssertNil(analyzer.result.cleanReps)
        let rep = try XCTUnwrap(analyzer.result.reps.first)
        XCTAssertTrue(rep.counted)
        XCTAssertNil(rep.cleanAssessment.clean)
        XCTAssertEqual(rep.cleanAssessment.depth, .notAssessed)
        XCTAssertEqual(rep.cleanAssessment.lockout, .notAssessed)
        XCTAssertEqual(rep.cleanAssessment.tempoControl, .notAssessed)
        XCTAssertEqual(updates.filter { $0.completedRep != nil }.count, 1)
        XCTAssertEqual(updates.last?.provisionalCountedReps, 1)
    }

    func testBatchAndStreamingAnalysisProduceTheSameCount() {
        let batch = SquatAnalyzer(configuration: streamingConfiguration)
            .analyze(frames: countedRepFrames)
        var streaming = SquatAnalyzer(configuration: streamingConfiguration)
        countedRepFrames.forEach { streaming.observe(frame: $0) }

        XCTAssertEqual(batch, streaming.result)
        XCTAssertEqual(batch.countedReps, 1)
    }

    func testSmallKneeDipDoesNotCountAsRep() {
        var analyzer = SquatAnalyzer(configuration: streamingConfiguration)
        let frames = standingFrames + [
            makeLegFrame(timestamp: 0.3, kneeAngle: 158, hipY: 0.355),
            makeLegFrame(timestamp: 0.4, kneeAngle: 150, hipY: 0.38),
            makeLegFrame(timestamp: 0.5, kneeAngle: 160, hipY: 0.35),
            makeLegFrame(timestamp: 0.6, kneeAngle: 170, hipY: 0.34)
        ]

        frames.forEach { analyzer.observe(frame: $0) }

        XCTAssertEqual(analyzer.result.countedReps, 0)
    }

    func testKneeFlexionWithoutHipDescentDoesNotStartRep() {
        var analyzer = SquatAnalyzer(configuration: streamingConfiguration)
        let frames = standingFrames + [
            makeLegFrame(timestamp: 0.3, kneeAngle: 150, hipY: 0.34),
            makeLegFrame(timestamp: 0.4, kneeAngle: 120, hipY: 0.34),
            makeLegFrame(timestamp: 0.5, kneeAngle: 135, hipY: 0.34),
            makeLegFrame(timestamp: 0.6, kneeAngle: 160, hipY: 0.34),
            makeLegFrame(timestamp: 0.7, kneeAngle: 170, hipY: 0.34)
        ]

        frames.forEach { analyzer.observe(frame: $0) }

        XCTAssertEqual(analyzer.result.countedReps, 0)
    }

    func testLongEvidenceGapCancelsInProgressCandidate() {
        var analyzer = SquatAnalyzer(configuration: streamingConfiguration)
        let frames = standingFrames + [
            makeLegFrame(timestamp: 0.3, kneeAngle: 155, hipY: 0.36),
            makeLegFrame(timestamp: 0.4, kneeAngle: 125, hipY: 0.44),
            makeLegFrame(timestamp: 1.0, kneeAngle: 125, hipY: 0.44, confidence: 0.1),
            makeLegFrame(timestamp: 1.1, kneeAngle: 145, hipY: 0.39),
            makeLegFrame(timestamp: 1.2, kneeAngle: 165, hipY: 0.35)
        ]

        let updates = frames.map { analyzer.observe(frame: $0) }

        XCTAssertEqual(analyzer.result.countedReps, 0)
        XCTAssertTrue(updates.contains { $0.phase == .trackingLost })
    }

    func testCleanAssessmentRequiresAllRequiredGates() {
        XCTAssertEqual(
            SquatCleanRepAssessment(depth: .passed, lockout: .passed, tempoControl: .passed).clean,
            true
        )
        XCTAssertEqual(
            SquatCleanRepAssessment(
                depth: .failed,
                lockout: .insufficientEvidence,
                tempoControl: .passed
            ).clean,
            false
        )
        XCTAssertNil(
            SquatCleanRepAssessment(
                depth: .passed,
                lockout: .insufficientEvidence,
                tempoControl: .passed
            ).clean
        )
    }

    func testManualLabelJSONDecodesSnakeCaseFields() throws {
        let json = """
        {
          "schema_version": 1,
          "clip_id": "side_squat_001",
          "source_video": {
            "filename": "side_squat_001.mov",
            "local_path": "side_squat_001.mov"
          },
          "exercise": "back_squat",
          "camera_angle": "side",
          "load_lbs": 185,
          "conditions": ["commercial_gym"],
          "confidence_should_be_low": false,
          "labeling_notes": ["first pass"],
          "reps": [
            {
              "index": 1,
              "start_s": 1.0,
              "bottom_s": 2.0,
              "end_s": 3.0,
              "counted": true,
              "clean": false,
              "failures": ["depth", "tempo_control"]
            }
          ]
        }
        """

        let labels = try SquatLabelLoader.makeJSONDecoder().decode(
            SquatClipLabels.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(labels.clipID, "side_squat_001")
        XCTAssertEqual(labels.sourceVideo.filename, "side_squat_001.mov")
        XCTAssertEqual(labels.reps[0].bottomSeconds, 2.0)
        XCTAssertEqual(labels.reps[0].failures, [.depth, .tempoControl])
    }

    func testScorerReportsMatchedMissedAndPhantomReps() {
        let labels = SquatClipLabels(
            clipID: "side_squat_001",
            sourceVideo: SquatLabelSourceVideo(filename: "side_squat_001.mov"),
            exercise: "back_squat",
            cameraAngle: "side",
            reps: [
                SquatRepLabel(index: 1, startSeconds: 1, bottomSeconds: 2, endSeconds: 3, counted: true, clean: true),
                SquatRepLabel(index: 2, startSeconds: 4, bottomSeconds: 5, endSeconds: 6, counted: true, clean: true)
            ]
        )
        let predictions = [
            SquatRepEvent(index: 1, startSeconds: 1.1, bottomSeconds: 2.1, endSeconds: 3.1),
            SquatRepEvent(index: 2, startSeconds: 8, bottomSeconds: 9, endSeconds: 10)
        ]

        let score = SquatBakeoffScorer(
            configuration: SquatBakeoffScoringConfiguration(eventToleranceSeconds: 0.25)
        ).score(labels: labels, predictions: predictions)

        XCTAssertEqual(score.expectedReps, 2)
        XCTAssertEqual(score.predictedReps, 2)
        XCTAssertEqual(score.matchedReps, 1)
        XCTAssertEqual(score.missedReps, 1)
        XCTAssertEqual(score.phantomReps, 1)
        XCTAssertEqual(score.bottomWithinTolerance, 1)
        XCTAssertEqual(score.countedAgreement, 1)
    }

    func testDetectorFindsSyntheticHipDipReps() throws {
        let frames = [
            makeFrame(timestamp: 0.0, hipY: 0.50),
            makeFrame(timestamp: 0.5, hipY: 0.54),
            makeFrame(timestamp: 1.0, hipY: 0.66),
            makeFrame(timestamp: 1.5, hipY: 0.54),
            makeFrame(timestamp: 2.0, hipY: 0.50),
            makeFrame(timestamp: 2.5, hipY: 0.52),
            makeFrame(timestamp: 3.0, hipY: 0.65),
            makeFrame(timestamp: 3.5, hipY: 0.53),
            makeFrame(timestamp: 4.0, hipY: 0.50)
        ]

        let detector = SquatRepDetector(configuration: SquatRepDetectorConfiguration(
            minimumLandmarkConfidence: 0.25,
            maximumNormalizedHipY: 1.0,
            minimumDescentDelta: 0.04,
            bottomThresholdFraction: 0.45,
            standingThresholdDelta: 0.03,
            minimumRepDurationSeconds: 0.75
        ))

        let reps = detector.detectReps(frames: frames)

        XCTAssertEqual(reps.count, 2)
        XCTAssertEqual(try XCTUnwrap(reps.first).bottomSeconds, 1.0)
        XCTAssertEqual(try XCTUnwrap(reps.last).bottomSeconds, 3.0)
    }

    private func makeFrame(timestamp: Double, hipY: Double) -> PoseFrame {
        PoseFrame(
            timestampSeconds: timestamp,
            landmarks: [
                PoseLandmark(name: .midHip, x: 0.5, y: hipY, confidence: 0.9)
            ],
            frameConfidence: 0.9
        )
    }

    private var streamingConfiguration: SquatAnalysisConfiguration {
        SquatAnalysisConfiguration(
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
    }

    private var standingFrames: [PoseFrame] {
        [
            makeLegFrame(timestamp: 0.0, kneeAngle: 170, hipY: 0.34),
            makeLegFrame(timestamp: 0.1, kneeAngle: 170, hipY: 0.34),
            makeLegFrame(timestamp: 0.2, kneeAngle: 170, hipY: 0.34)
        ]
    }

    private var countedRepFrames: [PoseFrame] {
        standingFrames + [
            makeLegFrame(timestamp: 0.3, kneeAngle: 157, hipY: 0.355),
            makeLegFrame(timestamp: 0.4, kneeAngle: 145, hipY: 0.38),
            makeLegFrame(timestamp: 0.5, kneeAngle: 125, hipY: 0.43),
            makeLegFrame(timestamp: 0.6, kneeAngle: 120, hipY: 0.45),
            makeLegFrame(timestamp: 0.7, kneeAngle: 130, hipY: 0.43),
            makeLegFrame(timestamp: 0.8, kneeAngle: 145, hipY: 0.39),
            makeLegFrame(timestamp: 0.9, kneeAngle: 158, hipY: 0.36)
        ]
    }

    private func makeLegFrame(
        timestamp: Double,
        kneeAngle: Double,
        hipY: Double,
        confidence: Double = 0.9,
        frameConfidence: Double? = 0.9
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
                PoseLandmark(name: .leftHip, x: kneeX, y: hipY, confidence: confidence),
                PoseLandmark(name: .leftKnee, x: kneeX, y: kneeY, confidence: confidence),
                PoseLandmark(name: .leftAnkle, x: ankleX, y: ankleY, confidence: confidence)
            ],
            frameConfidence: frameConfidence
        )
    }
}
