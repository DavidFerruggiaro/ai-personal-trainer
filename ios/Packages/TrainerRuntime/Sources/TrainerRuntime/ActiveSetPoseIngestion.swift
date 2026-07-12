import PoseCore
import SquatAnalysis

public struct ActiveSetPoseRetentionPolicy: Equatable, Sendable {
    public let maximumFrameCount: Int
    public let maximumDurationSeconds: Double

    public init(
        maximumFrameCount: Int = 18_000,
        maximumDurationSeconds: Double = 600
    ) {
        precondition(maximumFrameCount > 0)
        precondition(maximumDurationSeconds.isFinite && maximumDurationSeconds > 0)
        self.maximumFrameCount = maximumFrameCount
        self.maximumDurationSeconds = maximumDurationSeconds
    }

    public static let `default` = ActiveSetPoseRetentionPolicy()
}

public enum ActiveSetPoseIngestionPhase: Equatable, Sendable {
    case idle
    case recording
    case stopped
    case discarded
    case failed
}

public enum ActiveSetPoseIngestionError: Error, Equatable, Sendable {
    case invalidPhase
    case retentionLimitExceeded
    case eventDeliveryDropped
}

public struct ActiveSetPoseIngestionStatus: Equatable, Sendable {
    public let phase: ActiveSetPoseIngestionPhase
    public let framesObserved: Int
    public let streamingFramesAnalyzed: Int
    public let provisionalCountedReps: Int
}

public struct ActiveSetPoseSequence: Equatable, Sendable {
    public let frames: [PoseFrame]
    public let provisionalCountedReps: Int
    public let streamingFramesObserved: Int
    public let streamingFramesAnalyzed: Int
    public let analyzerConfiguration: SquatAnalysisConfiguration
}

public struct ActiveSetPoseIngestion: Sendable {
    public let retentionPolicy: ActiveSetPoseRetentionPolicy
    public private(set) var phase: ActiveSetPoseIngestionPhase = .idle

    private var analyzer: SquatAnalyzer
    private var frames: [PoseFrame] = []
    private var firstRetainedTimestamp: Double?
    private var minimumSourceSequenceExclusive: UInt64?
    private var failedStatus: ActiveSetPoseIngestionStatus?

    public init(
        retentionPolicy: ActiveSetPoseRetentionPolicy = .default,
        analyzerConfiguration: SquatAnalysisConfiguration = SquatAnalysisConfiguration()
    ) {
        self.retentionPolicy = retentionPolicy
        self.analyzer = SquatAnalyzer(configuration: analyzerConfiguration)
    }

    public var status: ActiveSetPoseIngestionStatus {
        if let failedStatus {
            return failedStatus
        }
        return ActiveSetPoseIngestionStatus(
            phase: phase,
            framesObserved: frames.count,
            streamingFramesAnalyzed: analyzer.framesAnalyzed,
            provisionalCountedReps: analyzer.reps.count
        )
    }

    public var retainedFrameCount: Int {
        frames.count
    }

    public mutating func begin(afterSourceSequence: UInt64? = nil) throws {
        guard phase == .idle || phase == .stopped || phase == .discarded else {
            throw ActiveSetPoseIngestionError.invalidPhase
        }
        frames.removeAll(keepingCapacity: true)
        analyzer.reset()
        firstRetainedTimestamp = nil
        minimumSourceSequenceExclusive = afterSourceSequence
        failedStatus = nil
        phase = .recording
    }

    @discardableResult
    public mutating func observe(
        _ frame: PoseFrame,
        sourceSequenceNumber: UInt64? = nil
    ) throws -> ActiveSetPoseIngestionStatus {
        guard phase == .recording else {
            throw ActiveSetPoseIngestionError.invalidPhase
        }
        if let minimumSourceSequenceExclusive,
           let sourceSequenceNumber,
           sourceSequenceNumber <= minimumSourceSequenceExclusive {
            return status
        }
        guard frames.count < retentionPolicy.maximumFrameCount else {
            failRetention()
            throw ActiveSetPoseIngestionError.retentionLimitExceeded
        }
        if let firstRetainedTimestamp,
           frame.timestampSeconds.isFinite,
           frame.timestampSeconds - firstRetainedTimestamp
            > retentionPolicy.maximumDurationSeconds {
            failRetention()
            throw ActiveSetPoseIngestionError.retentionLimitExceeded
        }
        if firstRetainedTimestamp == nil, frame.timestampSeconds.isFinite {
            firstRetainedTimestamp = frame.timestampSeconds
        }
        frames.append(frame)
        _ = analyzer.observe(frame: frame)
        return status
    }

    public mutating func stop() throws -> ActiveSetPoseSequence {
        guard phase == .recording else {
            throw ActiveSetPoseIngestionError.invalidPhase
        }
        phase = .stopped
        let sequence = ActiveSetPoseSequence(
            frames: frames,
            provisionalCountedReps: analyzer.reps.count,
            streamingFramesObserved: analyzer.framesObserved,
            streamingFramesAnalyzed: analyzer.framesAnalyzed,
            analyzerConfiguration: analyzer.configuration
        )
        frames.removeAll(keepingCapacity: false)
        firstRetainedTimestamp = nil
        minimumSourceSequenceExclusive = nil
        return sequence
    }

    public mutating func discard() throws {
        guard phase == .recording || phase == .stopped || phase == .failed else {
            throw ActiveSetPoseIngestionError.invalidPhase
        }
        frames.removeAll(keepingCapacity: false)
        analyzer.reset()
        firstRetainedTimestamp = nil
        minimumSourceSequenceExclusive = nil
        failedStatus = nil
        phase = .discarded
    }

    public mutating func invalidateForEventDeliveryDrop() -> ActiveSetPoseIngestionStatus {
        guard phase == .recording else {
            return status
        }
        failIngestion()
        return status
    }

    private mutating func failRetention() {
        failIngestion()
    }

    private mutating func failIngestion() {
        let lastTrustedStatus = status
        phase = .failed
        failedStatus = ActiveSetPoseIngestionStatus(
            phase: .failed,
            framesObserved: lastTrustedStatus.framesObserved,
            streamingFramesAnalyzed: lastTrustedStatus.streamingFramesAnalyzed,
            provisionalCountedReps: lastTrustedStatus.provisionalCountedReps
        )
        frames.removeAll(keepingCapacity: false)
        analyzer.reset()
        firstRetainedTimestamp = nil
        minimumSourceSequenceExclusive = nil
    }
}
