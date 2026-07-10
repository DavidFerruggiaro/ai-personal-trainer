import AVFoundation
import MediaPipeTasksVision
import PoseCore
import UIKit

struct MediaPipePoseEstimator: PoseEstimator {
    let sampleFPSLimit: Double
    let maxFrameDimension: CGFloat

    var engine: PoseEngineInfo {
        PoseEngineInfo(
            name: "mediapipe_pose_landmarker",
            version: "MediaPipeTasksVision",
            config: [
                "model": "pose_landmarker_full.task",
                "source": "prerecorded_video",
                "running_mode": "video",
                "max_sample_fps": formatted(sampleFPSLimit),
                "max_frame_dimension": formatted(Double(maxFrameDimension)),
                "num_poses": "1",
                "min_pose_detection_confidence": "0.30",
                "min_pose_presence_confidence": "0.30",
                "min_tracking_confidence": "0.30"
            ]
        )
    }

    init(sampleFPSLimit: Double = 10, maxFrameDimension: CGFloat = 1080) {
        self.sampleFPSLimit = sampleFPSLimit
        self.maxFrameDimension = maxFrameDimension
    }

    func estimatePoseFrames(from videoURL: URL) async throws -> [PoseFrame] {
        guard let modelPath = Bundle.main.path(
            forResource: "pose_landmarker_full",
            ofType: "task"
        ) else {
            throw PoseEstimatorError.engineUnavailable("Missing pose_landmarker_full.task in app bundle.")
        }

        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let nominalFrameRate = try await tracks.first?.load(.nominalFrameRate) ?? 30
        let sampleFPS = max(1, min(Double(nominalFrameRate), sampleFPSLimit))
        let frameCount = max(1, Int(durationSeconds * sampleFPS))

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: maxFrameDimension, height: maxFrameDimension)
        imageGenerator.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 25)
        imageGenerator.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 25)

        let landmarker = try makeLandmarker(modelPath: modelPath)

        var frames: [PoseFrame] = []
        frames.reserveCapacity(frameCount)

        for frameIndex in 0..<frameCount {
            let timestampSeconds = Double(frameIndex) / sampleFPS
            let timestampMilliseconds = Int((timestampSeconds * 1000).rounded())
            let time = CMTime(seconds: timestampSeconds, preferredTimescale: 600)

            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
                let mpImage = try MPImage(uiImage: uiImage)
                let result = try landmarker.detect(
                    videoFrame: mpImage,
                    timestampInMilliseconds: timestampMilliseconds
                )
                frames.append(Self.mapResult(result, timestampSeconds: timestampSeconds))
            } catch {
                frames.append(
                    PoseFrame(
                        timestampSeconds: timestampSeconds,
                        landmarks: [],
                        frameConfidence: nil
                    )
                )
            }
        }

        return frames
    }

    private func makeLandmarker(modelPath: String) throws -> PoseLandmarker {
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .video
        options.numPoses = 1
        options.minPoseDetectionConfidence = 0.30
        options.minPosePresenceConfidence = 0.30
        options.minTrackingConfidence = 0.30

        return try PoseLandmarker(options: options)
    }

    static func mapResult(
        _ result: PoseLandmarkerResult,
        timestampSeconds: Double
    ) -> PoseFrame {
        guard let pose = result.landmarks.first else {
            return PoseFrame(
                timestampSeconds: timestampSeconds,
                landmarks: [],
                frameConfidence: nil
            )
        }

        let landmarks = mapLandmarks(from: pose)

        return PoseFrame(
            timestampSeconds: timestampSeconds,
            landmarks: landmarks,
            frameConfidence: averageConfidence(for: landmarks)
        )
    }

    private static func mapLandmarks(from pose: [NormalizedLandmark]) -> [PoseLandmark] {
        let mappings: [(Int, PoseLandmarkName)] = [
            (0, .nose),
            (2, .leftEye),
            (5, .rightEye),
            (7, .leftEar),
            (8, .rightEar),
            (11, .leftShoulder),
            (12, .rightShoulder),
            (13, .leftElbow),
            (14, .rightElbow),
            (15, .leftWrist),
            (16, .rightWrist),
            (23, .leftHip),
            (24, .rightHip),
            (25, .leftKnee),
            (26, .rightKnee),
            (27, .leftAnkle),
            (28, .rightAnkle),
            (29, .leftHeel),
            (30, .rightHeel),
            (31, .leftFootIndex),
            (32, .rightFootIndex)
        ]

        var landmarks = mappings.compactMap { index, name -> PoseLandmark? in
            guard pose.indices.contains(index) else {
                return nil
            }

            return makeLandmark(name: name, from: pose[index])
        }

        if let neck = makeSyntheticLandmark(
            name: .neck,
            leftIndex: 11,
            rightIndex: 12,
            pose: pose
        ) {
            landmarks.append(neck)
        }

        if let midHip = makeSyntheticLandmark(
            name: .midHip,
            leftIndex: 23,
            rightIndex: 24,
            pose: pose
        ) {
            landmarks.append(midHip)
        }

        return landmarks
    }

    private static func makeLandmark(
        name: PoseLandmarkName,
        from landmark: NormalizedLandmark
    ) -> PoseLandmark {
        PoseLandmark(
            name: name,
            x: Double(landmark.x),
            y: Double(landmark.y),
            confidence: confidence(for: landmark)
        )
    }

    private static func makeSyntheticLandmark(
        name: PoseLandmarkName,
        leftIndex: Int,
        rightIndex: Int,
        pose: [NormalizedLandmark]
    ) -> PoseLandmark? {
        guard pose.indices.contains(leftIndex), pose.indices.contains(rightIndex) else {
            return nil
        }

        let left = pose[leftIndex]
        let right = pose[rightIndex]

        return PoseLandmark(
            name: name,
            x: Double((left.x + right.x) / 2),
            y: Double((left.y + right.y) / 2),
            confidence: (confidence(for: left) + confidence(for: right)) / 2
        )
    }

    private static func confidence(for landmark: NormalizedLandmark) -> Double {
        let visibility = landmark.visibility?.doubleValue
        let presence = landmark.presence?.doubleValue

        switch (visibility, presence) {
        case let (.some(visibility), .some(presence)):
            return min(visibility, presence)
        case let (.some(visibility), .none):
            return visibility
        case let (.none, .some(presence)):
            return presence
        case (.none, .none):
            return 1
        }
    }

    private static func averageConfidence(for landmarks: [PoseLandmark]) -> Double? {
        guard !landmarks.isEmpty else {
            return nil
        }

        let total = landmarks.reduce(0) { partialResult, landmark in
            partialResult + landmark.confidence
        }

        return total / Double(landmarks.count)
    }

    private func formatted(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.2f", value)
    }
}
