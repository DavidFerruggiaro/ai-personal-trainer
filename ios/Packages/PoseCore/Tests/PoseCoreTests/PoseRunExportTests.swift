import XCTest
@testable import PoseCore

final class PoseRunExportTests: XCTestCase {
    func testSourceVideoInfoDecodesLegacyJSONWithoutSHA256() throws {
        let data = Data(#"{"filename":"legacy.mov"}"#.utf8)

        let decoded = try JSONDecoder().decode(SourceVideoInfo.self, from: data)

        XCTAssertEqual(decoded.filename, "legacy.mov")
        XCTAssertNil(decoded.sha256)
    }

    func testPoseRunExportRoundTripsThroughJSON() throws {
        let export = PoseRunExport(
            appVersion: "PoseBakeoff 0.1",
            engine: PoseEngineInfo(name: "apple_vision", version: "1"),
            sourceVideo: SourceVideoInfo(
                filename: "squat_side_001.mov",
                sha256: String(repeating: "a", count: 64),
                durationSeconds: 12.4,
                width: 1920,
                height: 1080,
                nominalFPS: 30
            ),
            frames: [
                PoseFrame(
                    timestampSeconds: 0.033,
                    landmarks: [
                        PoseLandmark(name: .leftHip, x: 0.42, y: 0.51, confidence: 0.96)
                    ],
                    frameConfidence: 0.91
                )
            ],
            summary: PoseRunSummary(framesProcessed: 1, effectiveFPS: 28.7)
        )

        let data = try PoseRunExport.makeJSONEncoder().encode(export)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains("\"run_id\""))
        XCTAssertTrue(json.contains("\"created_at\""))
        XCTAssertTrue(json.contains("\"app_version\""))
        XCTAssertTrue(json.contains("\"source_video\""))
        XCTAssertTrue(json.contains("\"sha256\""))
        XCTAssertTrue(json.contains("\"duration_s\""))
        XCTAssertTrue(json.contains("\"fps_nominal\""))
        XCTAssertTrue(json.contains("\"timestamp_s\""))
        XCTAssertTrue(json.contains("\"frame_confidence\""))
        XCTAssertTrue(json.contains("\"frames_processed\""))
        XCTAssertTrue(json.contains("\"effective_fps\""))

        let decoded = try PoseRunExport.makeJSONDecoder().decode(PoseRunExport.self, from: data)

        XCTAssertEqual(decoded.engine.name, "apple_vision")
        XCTAssertEqual(decoded.sourceVideo.filename, "squat_side_001.mov")
        XCTAssertEqual(decoded.sourceVideo.sha256, String(repeating: "a", count: 64))
        XCTAssertEqual(decoded.sourceVideo.resolution?.width, 1920)
        XCTAssertEqual(decoded.sourceVideo.resolution?.height, 1080)
        XCTAssertEqual(decoded.frames.first?.landmarks.first?.name, .leftHip)
    }
}
