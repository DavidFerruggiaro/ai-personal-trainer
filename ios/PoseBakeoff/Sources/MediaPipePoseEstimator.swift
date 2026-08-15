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
                frames.append(MediaPipePoseMapper.mapResult(result, timestampSeconds: timestampSeconds))
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

    private func formatted(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(format: "%.2f", value)
    }
}
