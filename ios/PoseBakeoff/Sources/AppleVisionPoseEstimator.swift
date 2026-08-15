import AVFoundation
import CoreGraphics
import ImageIO
import PoseCore
import Vision

struct AppleVisionPoseEstimator: PoseEstimator {
    let engine = PoseEngineInfo(
        name: "apple_vision",
        version: "VNDetectHumanBodyPoseRequest",
        config: [
            "source": "prerecorded_video",
            "max_sample_fps": "10",
            "max_frame_dimension": "1080"
        ]
    )

    func estimatePoseFrames(from videoURL: URL) async throws -> [PoseFrame] {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let nominalFrameRate = try await tracks.first?.load(.nominalFrameRate) ?? 30
        let sampleFPS = max(1, min(Double(nominalFrameRate), 10))
        let frameCount = max(1, Int(durationSeconds * sampleFPS))

        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 1080, height: 1080)
        imageGenerator.requestedTimeToleranceBefore = .zero
        imageGenerator.requestedTimeToleranceAfter = .zero

        var frames: [PoseFrame] = []
        frames.reserveCapacity(frameCount)

        for frameIndex in 0..<frameCount {
            let timestampSeconds = Double(frameIndex) / sampleFPS
            let time = CMTime(seconds: timestampSeconds, preferredTimescale: 600)

            do {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                let poseFrame = try detectPose(in: cgImage, timestampSeconds: timestampSeconds)
                frames.append(poseFrame)
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

    private func detectPose(in image: CGImage, timestampSeconds: Double) throws -> PoseFrame {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(
            cgImage: image,
            orientation: .up,
            options: [:]
        )

        try handler.perform([request])

        guard let observation = request.results?.first else {
            return PoseFrame(
                timestampSeconds: timestampSeconds,
                landmarks: [],
                frameConfidence: nil
            )
        }

        let recognizedPoints = try observation.recognizedPoints(.all)
        let landmarks = mapLandmarks(from: recognizedPoints)

        return PoseFrame(
            timestampSeconds: timestampSeconds,
            landmarks: landmarks,
            frameConfidence: averageConfidence(for: landmarks)
        )
    }

    private func mapLandmarks(
        from recognizedPoints: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]
    ) -> [PoseLandmark] {
        let mappings: [(VNHumanBodyPoseObservation.JointName, PoseLandmarkName)] = [
            (.nose, .nose),
            (.neck, .neck),
            (.root, .midHip),
            (.leftShoulder, .leftShoulder),
            (.rightShoulder, .rightShoulder),
            (.leftElbow, .leftElbow),
            (.rightElbow, .rightElbow),
            (.leftWrist, .leftWrist),
            (.rightWrist, .rightWrist),
            (.leftHip, .leftHip),
            (.rightHip, .rightHip),
            (.leftKnee, .leftKnee),
            (.rightKnee, .rightKnee),
            (.leftAnkle, .leftAnkle),
            (.rightAnkle, .rightAnkle)
        ]

        return mappings.compactMap { visionName, appName in
            guard let point = recognizedPoints[visionName], point.confidence > 0 else {
                return nil
            }

            return PoseLandmark(
                name: appName,
                x: Double(point.location.x),
                y: Double(1 - point.location.y),
                confidence: Double(point.confidence)
            )
        }
    }

    private func averageConfidence(for landmarks: [PoseLandmark]) -> Double? {
        guard !landmarks.isEmpty else {
            return nil
        }

        let total = landmarks.reduce(0) { partialResult, landmark in
            partialResult + landmark.confidence
        }

        return total / Double(landmarks.count)
    }
}
