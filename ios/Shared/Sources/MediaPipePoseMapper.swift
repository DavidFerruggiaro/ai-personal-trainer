import MediaPipeTasksVision
import PoseCore

enum MediaPipePoseMapper {
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
        return switch (visibility, presence) {
        case let (.some(visibility), .some(presence)):
            min(visibility, presence)
        case let (.some(visibility), .none):
            visibility
        case let (.none, .some(presence)):
            presence
        case (.none, .none):
            1
        }
    }

    private static func averageConfidence(for landmarks: [PoseLandmark]) -> Double? {
        guard !landmarks.isEmpty else {
            return nil
        }
        return landmarks.reduce(0) { $0 + $1.confidence } / Double(landmarks.count)
    }
}
