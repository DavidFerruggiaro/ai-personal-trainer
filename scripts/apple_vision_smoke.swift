import AVFoundation
import CoreGraphics
import Foundation
import Vision

struct Resolution: Codable {
    let width: Int
    let height: Int
}

struct LandmarkResult: Codable {
    let name: String
    let x: Double
    let y: Double
    let confidence: Double
}

struct FrameResult: Codable {
    let timestamp_s: Double
    let landmarks: [LandmarkResult]
    let frame_confidence: Double?
}

struct VideoResult: Codable {
    let input: String
    let filename: String
    let duration_s: Double
    let resolution: Resolution
    let nominal_fps: Double
    let sample_fps: Double
    let max_frame_dimension: Int
    let confidence_threshold: Double
    let frames_processed: Int
    let pose_frames: Int
    let pose_hit_rate: Double
    let avg_landmark_count: Double
    let avg_frame_confidence: Double?
    let avg_lower_body_confidence: Double?
    let any_side_lower_body_complete_frames: Int
    let any_side_lower_body_complete_rate: Double
    let both_sides_lower_body_complete_frames: Int
    let both_sides_lower_body_complete_rate: Double
    let longest_pose_miss_streak_s: Double
    let processing_seconds: Double
    let processing_fps: Double
    let frames: [FrameResult]
}

struct RunResult: Codable {
    let created_at: String
    let engine: String
    let videos: [VideoResult]
}

let confidenceThreshold = 0.30
let sampleFPS = 10.0
let maxFrameDimension = 1080

let inputPaths = CommandLine.arguments.dropFirst()
guard !inputPaths.isEmpty else {
    fputs("Usage: apple_vision_smoke <video> [video...]\n", stderr)
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: "docs/bakeoff_results/2026-05-24_apple_vision_smoke", isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let results = try inputPaths.map { path in
    try analyzeVideo(at: URL(fileURLWithPath: path))
}

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let runResult = RunResult(
    created_at: ISO8601DateFormatter().string(from: Date()),
    engine: "apple_vision_vndetecthumanbodypose",
    videos: results
)
let data = try encoder.encode(runResult)
let jsonURL = outputDirectory.appendingPathComponent("apple_vision_smoke_results.json")
try data.write(to: jsonURL, options: [.atomic])

print("Wrote \(jsonURL.path)")
for result in results {
    print(
        [
            result.filename,
            "frames=\(result.frames_processed)",
            "pose_hit=\(percent(result.pose_hit_rate))",
            "any_side_lower=\(percent(result.any_side_lower_body_complete_rate))",
            "avg_conf=\(result.avg_frame_confidence.map { String(format: "%.3f", $0) } ?? "n/a")",
            "proc_fps=\(String(format: "%.2f", result.processing_fps))"
        ].joined(separator: " | ")
    )
}

func analyzeVideo(at url: URL) throws -> VideoResult {
    let startedAt = CFAbsoluteTimeGetCurrent()
    let asset = AVURLAsset(url: url)
    let durationSeconds = CMTimeGetSeconds(asset.duration)
    guard durationSeconds.isFinite, durationSeconds > 0 else {
        throw NSError(domain: "AppleVisionSmoke", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid duration for \(url.path)"])
    }

    guard let track = asset.tracks(withMediaType: .video).first else {
        throw NSError(domain: "AppleVisionSmoke", code: 2, userInfo: [NSLocalizedDescriptionKey: "No video track for \(url.path)"])
    }

    let naturalSize = track.naturalSize.applying(track.preferredTransform)
    let width = Int(abs(naturalSize.width))
    let height = Int(abs(naturalSize.height))
    let nominalFPS = Double(track.nominalFrameRate)
    let framesToProcess = max(1, Int(durationSeconds * sampleFPS))

    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    imageGenerator.maximumSize = CGSize(width: maxFrameDimension, height: maxFrameDimension)
    imageGenerator.requestedTimeToleranceBefore = .zero
    imageGenerator.requestedTimeToleranceAfter = .zero

    var frames: [FrameResult] = []
    frames.reserveCapacity(framesToProcess)

    for frameIndex in 0..<framesToProcess {
        if frameIndex > 0, frameIndex % 100 == 0 {
            print("\(url.lastPathComponent): \(frameIndex)/\(framesToProcess)")
        }

        let timestampSeconds = Double(frameIndex) / sampleFPS
        let time = CMTime(seconds: timestampSeconds, preferredTimescale: 600)

        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            frames.append(try detectPose(in: cgImage, timestampSeconds: timestampSeconds))
        } catch {
            frames.append(FrameResult(timestamp_s: timestampSeconds, landmarks: [], frame_confidence: nil))
        }
    }

    let processingSeconds = CFAbsoluteTimeGetCurrent() - startedAt
    let poseFrames = frames.filter { hasPose($0) }.count
    let landmarkCounts = frames.map { Double($0.landmarks.count) }
    let frameConfidences = frames.compactMap(\.frame_confidence)
    let lowerBodyConfidences = frames.flatMap { frame in
        frame.landmarks
            .filter { ["left_hip", "right_hip", "left_knee", "right_knee", "left_ankle", "right_ankle"].contains($0.name) }
            .map(\.confidence)
    }
    let anySideComplete = frames.filter { isAnySideLowerBodyComplete($0) }.count
    let bothSidesComplete = frames.filter { isBothSidesLowerBodyComplete($0) }.count

    return VideoResult(
        input: url.path,
        filename: url.lastPathComponent,
        duration_s: durationSeconds,
        resolution: Resolution(width: width, height: height),
        nominal_fps: nominalFPS,
        sample_fps: sampleFPS,
        max_frame_dimension: maxFrameDimension,
        confidence_threshold: confidenceThreshold,
        frames_processed: frames.count,
        pose_frames: poseFrames,
        pose_hit_rate: Double(poseFrames) / Double(frames.count),
        avg_landmark_count: average(landmarkCounts) ?? 0,
        avg_frame_confidence: average(frameConfidences),
        avg_lower_body_confidence: average(lowerBodyConfidences),
        any_side_lower_body_complete_frames: anySideComplete,
        any_side_lower_body_complete_rate: Double(anySideComplete) / Double(frames.count),
        both_sides_lower_body_complete_frames: bothSidesComplete,
        both_sides_lower_body_complete_rate: Double(bothSidesComplete) / Double(frames.count),
        longest_pose_miss_streak_s: Double(longestMissStreak(frames)) / sampleFPS,
        processing_seconds: processingSeconds,
        processing_fps: Double(frames.count) / processingSeconds,
        frames: frames
    )
}

func detectPose(in image: CGImage, timestampSeconds: Double) throws -> FrameResult {
    let request = VNDetectHumanBodyPoseRequest()
    let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
    try handler.perform([request])

    guard let observation = request.results?.first else {
        return FrameResult(timestamp_s: timestampSeconds, landmarks: [], frame_confidence: nil)
    }

    let points = try observation.recognizedPoints(.all)
    let landmarks = mapLandmarks(from: points)
    return FrameResult(
        timestamp_s: timestampSeconds,
        landmarks: landmarks,
        frame_confidence: average(landmarks.map(\.confidence))
    )
}

func mapLandmarks(from points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> [LandmarkResult] {
    let mappings: [(VNHumanBodyPoseObservation.JointName, String)] = [
        (.nose, "nose"),
        (.neck, "neck"),
        (.root, "mid_hip"),
        (.leftShoulder, "left_shoulder"),
        (.rightShoulder, "right_shoulder"),
        (.leftElbow, "left_elbow"),
        (.rightElbow, "right_elbow"),
        (.leftWrist, "left_wrist"),
        (.rightWrist, "right_wrist"),
        (.leftHip, "left_hip"),
        (.rightHip, "right_hip"),
        (.leftKnee, "left_knee"),
        (.rightKnee, "right_knee"),
        (.leftAnkle, "left_ankle"),
        (.rightAnkle, "right_ankle")
    ]

    return mappings.compactMap { visionName, appName in
        guard let point = points[visionName], point.confidence > 0 else {
            return nil
        }

        return LandmarkResult(
            name: appName,
            x: Double(point.location.x),
            y: Double(1 - point.location.y),
            confidence: Double(point.confidence)
        )
    }
}

func hasPose(_ frame: FrameResult) -> Bool {
    frame.landmarks.contains { $0.confidence >= confidenceThreshold }
}

func isAnySideLowerBodyComplete(_ frame: FrameResult) -> Bool {
    sideComplete(frame, prefix: "left") || sideComplete(frame, prefix: "right")
}

func isBothSidesLowerBodyComplete(_ frame: FrameResult) -> Bool {
    sideComplete(frame, prefix: "left") && sideComplete(frame, prefix: "right")
}

func sideComplete(_ frame: FrameResult, prefix: String) -> Bool {
    let names = Set(frame.landmarks.filter { $0.confidence >= confidenceThreshold }.map(\.name))
    return names.contains("\(prefix)_hip") && names.contains("\(prefix)_knee") && names.contains("\(prefix)_ankle")
}

func longestMissStreak(_ frames: [FrameResult]) -> Int {
    var current = 0
    var longest = 0
    for frame in frames {
        if hasPose(frame) {
            current = 0
        } else {
            current += 1
            longest = max(longest, current)
        }
    }
    return longest
}

func average(_ values: [Double]) -> Double? {
    guard !values.isEmpty else {
        return nil
    }
    return values.reduce(0, +) / Double(values.count)
}

func percent(_ value: Double) -> String {
    String(format: "%.1f%%", value * 100)
}
