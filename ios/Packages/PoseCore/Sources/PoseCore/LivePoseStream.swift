import Foundation

public enum LivePoseStreamState: Equatable, Sendable {
    case idle
    case starting
    case running
    case stopped
    case failed(String)
}

public struct LivePoseObservation: Equatable, Sendable {
    public let frame: PoseFrame
    public let inferenceLatencyMilliseconds: Double

    public init(frame: PoseFrame, inferenceLatencyMilliseconds: Double) {
        self.frame = frame
        self.inferenceLatencyMilliseconds = inferenceLatencyMilliseconds
    }
}

public enum LivePoseEvent: Equatable, Sendable {
    case stateChanged(LivePoseStreamState)
    case observation(LivePoseObservation)
    case captureDropped
    case inferenceFailed(String)
}

public protocol LivePoseStreaming: AnyObject {
    var engine: PoseEngineInfo { get }
    var events: AsyncStream<LivePoseEvent> { get }

    func start()
    func stop()
}
