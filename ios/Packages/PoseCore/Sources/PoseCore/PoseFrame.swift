import Foundation

public struct PoseFrame: Codable, Equatable, Sendable {
    public var timestampSeconds: Double
    public var landmarks: [PoseLandmark]
    public var frameConfidence: Double?

    private enum CodingKeys: String, CodingKey {
        case timestampSeconds = "timestamp_s"
        case landmarks
        case frameConfidence = "frame_confidence"
    }

    public init(
        timestampSeconds: Double,
        landmarks: [PoseLandmark],
        frameConfidence: Double? = nil
    ) {
        self.timestampSeconds = timestampSeconds
        self.landmarks = landmarks
        self.frameConfidence = frameConfidence
    }
}
