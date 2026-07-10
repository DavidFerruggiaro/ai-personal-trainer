import Foundation

public enum PoseLandmarkName: String, Codable, CaseIterable, Sendable {
    case nose
    case leftEye = "left_eye"
    case rightEye = "right_eye"
    case leftEar = "left_ear"
    case rightEar = "right_ear"
    case neck
    case leftShoulder = "left_shoulder"
    case rightShoulder = "right_shoulder"
    case leftElbow = "left_elbow"
    case rightElbow = "right_elbow"
    case leftWrist = "left_wrist"
    case rightWrist = "right_wrist"
    case midHip = "mid_hip"
    case leftHip = "left_hip"
    case rightHip = "right_hip"
    case leftKnee = "left_knee"
    case rightKnee = "right_knee"
    case leftAnkle = "left_ankle"
    case rightAnkle = "right_ankle"
    case leftHeel = "left_heel"
    case rightHeel = "right_heel"
    case leftFootIndex = "left_foot_index"
    case rightFootIndex = "right_foot_index"
}

public struct PoseLandmark: Codable, Equatable, Sendable {
    public var name: PoseLandmarkName
    public var x: Double
    public var y: Double
    public var confidence: Double

    public init(
        name: PoseLandmarkName,
        x: Double,
        y: Double,
        confidence: Double
    ) {
        self.name = name
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}
