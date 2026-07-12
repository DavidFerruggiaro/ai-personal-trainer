import PoseCore
import SquatAnalysis
import TrainerCore

public struct TrainerPoseObservationOutput: Equatable, Sendable {
    public let latestPoseFrame: PoseFrame
    public let setupAssessment: SetupGateAssessment
    public let activeSetPoseStatus: ActiveSetPoseIngestionStatus
}

public struct TrainerPoseObservationPipeline: Sendable {
    private let evidenceExtractor: PoseSetupEvidenceExtractor
    private var setupSignalWindow: SetupGateSignalWindow
    private var activeSetPoseIngestion: ActiveSetPoseIngestion

    public init(
        setupSignalWindow: SetupGateSignalWindow = SetupGateSignalWindow(),
        retentionPolicy: ActiveSetPoseRetentionPolicy = .default,
        analyzerConfiguration: SquatAnalysisConfiguration = SquatAnalysisConfiguration()
    ) {
        self.evidenceExtractor = PoseSetupEvidenceExtractor()
        self.setupSignalWindow = setupSignalWindow
        self.activeSetPoseIngestion = ActiveSetPoseIngestion(
            retentionPolicy: retentionPolicy,
            analyzerConfiguration: analyzerConfiguration
        )
    }

    public var setupAssessment: SetupGateAssessment {
        setupSignalWindow.assessment
    }

    public var activeSetPoseStatus: ActiveSetPoseIngestionStatus {
        activeSetPoseIngestion.status
    }

    public var activeSetPosePhase: ActiveSetPoseIngestionPhase {
        activeSetPoseIngestion.phase
    }

    public mutating func resetSetupEvidence() {
        setupSignalWindow.reset()
    }

    public mutating func beginActiveSet(afterSourceSequence: UInt64?) throws {
        try activeSetPoseIngestion.begin(afterSourceSequence: afterSourceSequence)
    }

    public mutating func observe(
        _ observation: LivePoseObservation,
        phoneStable: Bool?
    ) throws -> TrainerPoseObservationOutput {
        let evidence = evidenceExtractor.evidence(from: observation.frame)
        setupSignalWindow.observe(SetupGateSignalAdapter.sample(
            from: evidence,
            phoneStable: phoneStable
        ))

        if activeSetPoseIngestion.phase == .recording {
            _ = try activeSetPoseIngestion.observe(
                observation.frame,
                sourceSequenceNumber: observation.sourceSequenceNumber
            )
        }

        return TrainerPoseObservationOutput(
            latestPoseFrame: observation.frame,
            setupAssessment: setupSignalWindow.assessment,
            activeSetPoseStatus: activeSetPoseIngestion.status
        )
    }

    public mutating func stopActiveSet() throws -> ActiveSetPoseSequence {
        try activeSetPoseIngestion.stop()
    }

    public mutating func discardActiveSet() {
        switch activeSetPoseIngestion.phase {
        case .recording, .stopped, .failed:
            try? activeSetPoseIngestion.discard()
        case .idle, .discarded:
            break
        }
    }

    public mutating func invalidateActiveSetForEventDeliveryDrop()
        -> ActiveSetPoseIngestionStatus {
        activeSetPoseIngestion.invalidateForEventDeliveryDrop()
    }
}
