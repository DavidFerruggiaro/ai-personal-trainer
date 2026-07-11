import Foundation

public enum BodySide: String, Equatable, Sendable {
    case left
    case right
}

public struct PoseSetupEvidence: Equatable, Sendable {
    public let fullBodyVisible: Bool
    public let sideViewLikely: Bool?
    public let poseConfidenceOK: Bool
    public let primaryVisibleSide: BodySide?
    public let lowerBodyConfidence: Double?

    public init(
        fullBodyVisible: Bool,
        sideViewLikely: Bool?,
        poseConfidenceOK: Bool,
        primaryVisibleSide: BodySide?,
        lowerBodyConfidence: Double?
    ) {
        self.fullBodyVisible = fullBodyVisible
        self.sideViewLikely = sideViewLikely
        self.poseConfidenceOK = poseConfidenceOK
        self.primaryVisibleSide = primaryVisibleSide
        self.lowerBodyConfidence = lowerBodyConfidence
    }
}

public struct PoseSetupEvidencePolicy: Equatable, Sendable {
    public let minimumLandmarkConfidence: Double
    public let minimumLowerBodyConfidence: Double
    public let frameEdgeMargin: Double
    public let maximumShoulderSeparationToTorsoRatio: Double
    public let maximumHipSeparationToTorsoRatio: Double

    public init(
        minimumLandmarkConfidence: Double = 0.50,
        minimumLowerBodyConfidence: Double = 0.55,
        frameEdgeMargin: Double = 0.01,
        maximumShoulderSeparationToTorsoRatio: Double = 0.45,
        maximumHipSeparationToTorsoRatio: Double = 0.35
    ) {
        self.minimumLandmarkConfidence = minimumLandmarkConfidence
        self.minimumLowerBodyConfidence = minimumLowerBodyConfidence
        self.frameEdgeMargin = frameEdgeMargin
        self.maximumShoulderSeparationToTorsoRatio = maximumShoulderSeparationToTorsoRatio
        self.maximumHipSeparationToTorsoRatio = maximumHipSeparationToTorsoRatio
    }

    public static let `default` = PoseSetupEvidencePolicy()
}

public struct PoseSetupEvidenceExtractor: Sendable {
    public let policy: PoseSetupEvidencePolicy

    public init(policy: PoseSetupEvidencePolicy = .default) {
        self.policy = policy
    }

    public func evidence(from frame: PoseFrame) -> PoseSetupEvidence {
        let landmarks = Dictionary(uniqueKeysWithValues: frame.landmarks.map { ($0.name, $0) })
        let primarySide = bestVisibleSide(in: landmarks)
        let lowerBodyConfidence = primarySide.flatMap { confidence(for: $0, in: landmarks) }

        return PoseSetupEvidence(
            fullBodyVisible: primarySide.map { fullBodyVisible(on: $0, in: landmarks) } ?? false,
            sideViewLikely: sideViewLikely(in: landmarks),
            poseConfidenceOK: lowerBodyConfidence.map { $0 >= policy.minimumLowerBodyConfidence } ?? false,
            primaryVisibleSide: primarySide,
            lowerBodyConfidence: lowerBodyConfidence
        )
    }

    private func bestVisibleSide(
        in landmarks: [PoseLandmarkName: PoseLandmark]
    ) -> BodySide? {
        let candidates: [(BodySide, Double)] = BodySide.allCases.compactMap { side in
            guard let confidence = confidence(for: side, in: landmarks) else {
                return nil
            }
            return (side, confidence)
        }
        return candidates.max { $0.1 < $1.1 }?.0
    }

    private func confidence(
        for side: BodySide,
        in landmarks: [PoseLandmarkName: PoseLandmark]
    ) -> Double? {
        let names = lowerBodyNames(for: side)
        let values = names.compactMap { landmarks[$0] }.filter(isUsable).map(\.confidence)
        guard values.count == names.count else {
            return nil
        }
        return values.reduce(0, +) / Double(values.count)
    }

    private func fullBodyVisible(
        on side: BodySide,
        in landmarks: [PoseLandmarkName: PoseLandmark]
    ) -> Bool {
        let shoulder: PoseLandmarkName = side == .left ? .leftShoulder : .rightShoulder
        let required = [.nose, shoulder] + lowerBodyNames(for: side)
        return required.allSatisfy { name in
            landmarks[name].map(isUsable) == true
        }
    }

    private func sideViewLikely(
        in landmarks: [PoseLandmarkName: PoseLandmark]
    ) -> Bool? {
        let names: [PoseLandmarkName] = [.leftShoulder, .rightShoulder, .leftHip, .rightHip]
        guard names.allSatisfy({ landmarks[$0].map(isUsable) == true }),
              let leftShoulder = landmarks[.leftShoulder],
              let rightShoulder = landmarks[.rightShoulder],
              let leftHip = landmarks[.leftHip],
              let rightHip = landmarks[.rightHip] else {
            return nil
        }

        let midShoulder = midpoint(leftShoulder, rightShoulder)
        let midHip = midpoint(leftHip, rightHip)
        let torsoLength = distance(midShoulder, midHip)
        guard torsoLength > 0.01 else {
            return nil
        }

        let shoulderRatio = abs(leftShoulder.x - rightShoulder.x) / torsoLength
        let hipRatio = abs(leftHip.x - rightHip.x) / torsoLength
        return shoulderRatio <= policy.maximumShoulderSeparationToTorsoRatio
            && hipRatio <= policy.maximumHipSeparationToTorsoRatio
    }

    private func lowerBodyNames(for side: BodySide) -> [PoseLandmarkName] {
        switch side {
        case .left:
            [.leftHip, .leftKnee, .leftAnkle, .leftHeel, .leftFootIndex]
        case .right:
            [.rightHip, .rightKnee, .rightAnkle, .rightHeel, .rightFootIndex]
        }
    }

    private func isUsable(_ landmark: PoseLandmark) -> Bool {
        let margin = policy.frameEdgeMargin
        return landmark.confidence >= policy.minimumLandmarkConfidence
            && landmark.x >= margin
            && landmark.x <= 1 - margin
            && landmark.y >= margin
            && landmark.y <= 1 - margin
    }

    private func midpoint(_ first: PoseLandmark, _ second: PoseLandmark) -> Point {
        Point(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }

    private func distance(_ first: Point, _ second: Point) -> Double {
        hypot(first.x - second.x, first.y - second.y)
    }

    private struct Point {
        let x: Double
        let y: Double
    }
}

extension BodySide: CaseIterable {}
