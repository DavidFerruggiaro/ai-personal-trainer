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
    public let sourceSequenceNumber: UInt64

    public init(
        frame: PoseFrame,
        inferenceLatencyMilliseconds: Double,
        sourceSequenceNumber: UInt64 = 0
    ) {
        self.frame = frame
        self.inferenceLatencyMilliseconds = inferenceLatencyMilliseconds
        self.sourceSequenceNumber = sourceSequenceNumber
    }
}

public enum LivePoseEvent: Equatable, Sendable {
    case stateChanged(LivePoseStreamState)
    case observation(LivePoseObservation)
    case captureDropped
    case inferenceFailed(String)
    case deliveryBoundary(UUID)
}

public protocol LivePoseStreaming: AnyObject {
    var engine: PoseEngineInfo { get }
    var events: AsyncStream<LivePoseEvent> { get }

    func start()
    func stop()
}
