import XCTest
import PoseCore
@testable import SquatAnalysis

final class SquatAnalyzerTests: XCTestCase {
    func testAnalyzerFiltersLowConfidenceFrames() {
        let analyzer = SquatAnalyzer(
            configuration: SquatAnalysisConfiguration(minimumFrameConfidence: 0.5)
        )

        let result = analyzer.analyze(frames: [
            PoseFrame(timestampSeconds: 0, landmarks: [], frameConfidence: 0.9),
            PoseFrame(timestampSeconds: 1, landmarks: [], frameConfidence: 0.2),
            PoseFrame(timestampSeconds: 2, landmarks: [], frameConfidence: nil)
        ])

        XCTAssertEqual(result.framesAnalyzed, 2)
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
}
