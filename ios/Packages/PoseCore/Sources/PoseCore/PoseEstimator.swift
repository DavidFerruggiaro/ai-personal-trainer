import Foundation

public enum PoseEstimatorError: Error, Equatable, Sendable {
    case unsupportedSource
    case engineUnavailable(String)
    case processingFailed(String)
}

public protocol PoseEstimator: Sendable {
    var engine: PoseEngineInfo { get }

    func estimatePoseFrames(from videoURL: URL) async throws -> [PoseFrame]
}
