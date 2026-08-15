import Foundation
import PoseCore

public enum SquatMovementPhase: String, Equatable, Sendable {
    case acquiringStandingReference
    case standing
    case descending
    case ascending
    case trackingLost
}

public enum SquatRepGateAssessmentStatus: String, Codable, Equatable, Sendable {
    case notAssessed = "not_assessed"
    case passed
    case failed
    case insufficientEvidence = "insufficient_evidence"
}

/// Required clean-rep gates stay independent from whether a rep happened.
///
/// M2.8 intentionally leaves these gates unassessed. Later full-sequence
/// analysis can fill them without changing counted-rep detection semantics.
public struct SquatCleanRepAssessment: Codable, Equatable, Sendable {
    public var depth: SquatRepGateAssessmentStatus
    public var lockout: SquatRepGateAssessmentStatus
    public var tempoControl: SquatRepGateAssessmentStatus

    public init(
        depth: SquatRepGateAssessmentStatus = .notAssessed,
        lockout: SquatRepGateAssessmentStatus = .notAssessed,
        tempoControl: SquatRepGateAssessmentStatus = .notAssessed
    ) {
        self.depth = depth
        self.lockout = lockout
        self.tempoControl = tempoControl
    }

    /// `nil` means clean quality has not been established.
    public var clean: Bool? {
        let requiredGates = [depth, lockout, tempoControl]
        if requiredGates.contains(.failed) {
            return false
        }
        if requiredGates.allSatisfy({ $0 == .passed }) {
            return true
        }
        return nil
    }

    public static let notAssessed = SquatCleanRepAssessment()
}

public struct AnalyzedSquatRep: Codable, Equatable, Sendable {
    public var index: Int
    public var startSeconds: Double
    public var bottomSeconds: Double
    public var endSeconds: Double
    public var counted: Bool
    public var countConfidence: Double
    public var cleanAssessment: SquatCleanRepAssessment

    public init(
        index: Int,
        startSeconds: Double,
        bottomSeconds: Double,
        endSeconds: Double,
        counted: Bool,
        countConfidence: Double,
        cleanAssessment: SquatCleanRepAssessment
    ) {
        self.index = index
        self.startSeconds = startSeconds
        self.bottomSeconds = bottomSeconds
        self.endSeconds = endSeconds
        self.counted = counted
        self.countConfidence = countConfidence
        self.cleanAssessment = cleanAssessment
    }
}

public struct SquatAnalysisConfiguration: Equatable, Sendable {
    public var minimumFrameConfidence: Double
    public var minimumLandmarkConfidence: Double
    public var minimumStandingKneeAngleDegrees: Double
    public var standingCalibrationDurationSeconds: Double
    public var minimumStandingCalibrationSamples: Int
    public var descentStartKneeFlexionDegrees: Double
    public var descentStartHipRatio: Double
    public var minimumCountedKneeFlexionDegrees: Double
    public var minimumCountedHipDescentRatio: Double
    public var ascentReversalDegrees: Double
    public var standingReturnToleranceDegrees: Double
    public var standingHipReturnToleranceRatio: Double
    public var minimumRepDurationSeconds: Double
    public var maximumRepDurationSeconds: Double
    public var maximumEvidenceGapSeconds: Double
    public var smoothingFactor: Double

    public init(
        minimumFrameConfidence: Double = 0.30,
        minimumLandmarkConfidence: Double = 0.50,
        minimumStandingKneeAngleDegrees: Double = 150,
        standingCalibrationDurationSeconds: Double = 0.40,
        minimumStandingCalibrationSamples: Int = 8,
        descentStartKneeFlexionDegrees: Double = 10,
        descentStartHipRatio: Double = 0.02,
        minimumCountedKneeFlexionDegrees: Double = 30,
        minimumCountedHipDescentRatio: Double = 0.08,
        ascentReversalDegrees: Double = 5,
        standingReturnToleranceDegrees: Double = 15,
        standingHipReturnToleranceRatio: Double = 0.06,
        minimumRepDurationSeconds: Double = 0.60,
        maximumRepDurationSeconds: Double = 12,
        maximumEvidenceGapSeconds: Double = 0.50,
        smoothingFactor: Double = 0.35
    ) {
        self.minimumFrameConfidence = minimumFrameConfidence
        self.minimumLandmarkConfidence = minimumLandmarkConfidence
        self.minimumStandingKneeAngleDegrees = minimumStandingKneeAngleDegrees
        self.standingCalibrationDurationSeconds = standingCalibrationDurationSeconds
        self.minimumStandingCalibrationSamples = minimumStandingCalibrationSamples
        self.descentStartKneeFlexionDegrees = descentStartKneeFlexionDegrees
        self.descentStartHipRatio = descentStartHipRatio
        self.minimumCountedKneeFlexionDegrees = minimumCountedKneeFlexionDegrees
        self.minimumCountedHipDescentRatio = minimumCountedHipDescentRatio
        self.ascentReversalDegrees = ascentReversalDegrees
        self.standingReturnToleranceDegrees = standingReturnToleranceDegrees
        self.standingHipReturnToleranceRatio = standingHipReturnToleranceRatio
        self.minimumRepDurationSeconds = minimumRepDurationSeconds
        self.maximumRepDurationSeconds = maximumRepDurationSeconds
        self.maximumEvidenceGapSeconds = maximumEvidenceGapSeconds
        self.smoothingFactor = smoothingFactor
    }
}

public struct SquatAnalysisResult: Equatable, Sendable {
    public var framesObserved: Int
    public var framesAnalyzed: Int
    public var reps: [AnalyzedSquatRep]

    public init(
        framesObserved: Int,
        framesAnalyzed: Int,
        reps: [AnalyzedSquatRep]
    ) {
        self.framesObserved = framesObserved
        self.framesAnalyzed = framesAnalyzed
        self.reps = reps
    }

    public var countedReps: Int {
        reps.lazy.filter(\.counted).count
    }

    /// `nil` means at least one counted rep still has unassessed clean gates.
    public var cleanReps: Int? {
        let counted = reps.filter(\.counted)
        let cleanValues = counted.map(\.cleanAssessment.clean)
        guard cleanValues.allSatisfy({ $0 != nil }) else {
            return nil
        }
        return cleanValues.compactMap { $0 }.filter { $0 }.count
    }
}

public struct SquatAnalyzerUpdate: Equatable, Sendable {
    public var phase: SquatMovementPhase
    public var provisionalCountedReps: Int
    public var completedRep: AnalyzedSquatRep?
    public var framesObserved: Int
    public var framesAnalyzed: Int

    public init(
        phase: SquatMovementPhase,
        provisionalCountedReps: Int,
        completedRep: AnalyzedSquatRep?,
        framesObserved: Int,
        framesAnalyzed: Int
    ) {
        self.phase = phase
        self.provisionalCountedReps = provisionalCountedReps
        self.completedRep = completedRep
        self.framesObserved = framesObserved
        self.framesAnalyzed = framesAnalyzed
    }
}

/// Conservative streaming detector for whether a squat cycle happened.
///
/// Counting requires a calibrated standing reference, confident landmarks from
/// one visible leg, meaningful knee flexion plus hip descent, an ascent, and a
/// return near the lifter's own standing reference. Depth and absolute lockout
/// thresholds are deliberately not count gates; they belong to clean-rep
/// assessment.
public struct SquatAnalyzer: Sendable {
    public var configuration: SquatAnalysisConfiguration
    public private(set) var framesObserved = 0
    public private(set) var framesAnalyzed = 0
    public private(set) var reps: [AnalyzedSquatRep] = []

    private var state: DetectionState = .acquiringStandingReference
    private var primarySide: BodySide?
    private var standingSamples: [Measurement] = []
    private var smoothedMeasurement: Measurement?
    private var lastFrameTimestamp: Double?
    private var lastUsableTimestamp: Double?

    public init(configuration: SquatAnalysisConfiguration = SquatAnalysisConfiguration()) {
        self.configuration = configuration
    }

    public func analyze(frames: [PoseFrame]) -> SquatAnalysisResult {
        var analyzer = SquatAnalyzer(configuration: configuration)
        for frame in frames {
            _ = analyzer.observe(frame: frame)
        }
        return analyzer.result
    }

    public var result: SquatAnalysisResult {
        SquatAnalysisResult(
            framesObserved: framesObserved,
            framesAnalyzed: framesAnalyzed,
            reps: reps
        )
    }

    @discardableResult
    public mutating func observe(frame: PoseFrame) -> SquatAnalyzerUpdate {
        framesObserved += 1

        guard frame.timestampSeconds.isFinite,
              lastFrameTimestamp.map({ frame.timestampSeconds > $0 }) ?? true else {
            return update(phase: publicPhase, completedRep: nil)
        }
        lastFrameTimestamp = frame.timestampSeconds

        guard frame.frameConfidence.map({ $0 >= configuration.minimumFrameConfidence }) ?? true,
              let rawMeasurement = measurement(from: frame) else {
            return handleMissingEvidence(at: frame.timestampSeconds)
        }

        let measurement = smooth(rawMeasurement)
        framesAnalyzed += 1
        lastUsableTimestamp = measurement.timestampSeconds

        switch state {
        case .acquiringStandingReference:
            observeStandingCalibration(measurement)
            return update(phase: publicPhase, completedRep: nil)

        case let .standing(reference):
            let kneeFlexion = reference.kneeAngleDegrees - measurement.kneeAngleDegrees
            let hipDescent = hipDescentRatio(measurement, from: reference)
            guard kneeFlexion >= configuration.descentStartKneeFlexionDegrees,
                  hipDescent >= configuration.descentStartHipRatio else {
                return update(phase: .standing, completedRep: nil)
            }

            let candidate = RepCandidate(
                startSeconds: measurement.timestampSeconds,
                bottomSeconds: measurement.timestampSeconds,
                minimumKneeAngleDegrees: measurement.kneeAngleDegrees,
                maximumKneeFlexionDegrees: kneeFlexion,
                maximumHipDescentRatio: hipDescent,
                minimumConfidence: measurement.confidence,
                lastKneeAngleDegrees: measurement.kneeAngleDegrees
            )
            state = .descending(reference, candidate)
            return update(phase: .descending, completedRep: nil)

        case let .descending(reference, existingCandidate):
            var candidate = updated(
                existingCandidate,
                with: measurement,
                reference: reference
            )
            guard repDuration(candidate, at: measurement.timestampSeconds)
                    <= configuration.maximumRepDurationSeconds else {
                clearTrackingReference()
                return update(phase: .acquiringStandingReference, completedRep: nil)
            }

            if measurement.kneeAngleDegrees
                >= candidate.minimumKneeAngleDegrees + configuration.ascentReversalDegrees {
                state = .ascending(reference, candidate)
                return update(phase: .ascending, completedRep: nil)
            }

            candidate.lastKneeAngleDegrees = measurement.kneeAngleDegrees
            state = .descending(reference, candidate)
            return update(phase: .descending, completedRep: nil)

        case let .ascending(reference, existingCandidate):
            var candidate = updated(
                existingCandidate,
                with: measurement,
                reference: reference
            )
            let duration = repDuration(candidate, at: measurement.timestampSeconds)
            guard duration <= configuration.maximumRepDurationSeconds else {
                clearTrackingReference()
                return update(phase: .acquiringStandingReference, completedRep: nil)
            }

            if measurement.kneeAngleDegrees
                <= candidate.lastKneeAngleDegrees - configuration.ascentReversalDegrees {
                candidate.lastKneeAngleDegrees = measurement.kneeAngleDegrees
                state = .descending(reference, candidate)
                return update(phase: .descending, completedRep: nil)
            }

            let returnedToStanding =
                measurement.kneeAngleDegrees
                    >= reference.kneeAngleDegrees - configuration.standingReturnToleranceDegrees
                && hipDescentRatio(measurement, from: reference)
                    <= configuration.standingHipReturnToleranceRatio
            guard returnedToStanding else {
                candidate.lastKneeAngleDegrees = measurement.kneeAngleDegrees
                state = .ascending(reference, candidate)
                return update(phase: .ascending, completedRep: nil)
            }

            state = .standing(reference)
            guard duration >= configuration.minimumRepDurationSeconds,
                  candidate.maximumKneeFlexionDegrees
                    >= configuration.minimumCountedKneeFlexionDegrees,
                  candidate.maximumHipDescentRatio
                    >= configuration.minimumCountedHipDescentRatio else {
                return update(phase: .standing, completedRep: nil)
            }

            let rep = AnalyzedSquatRep(
                index: reps.count + 1,
                startSeconds: candidate.startSeconds,
                bottomSeconds: candidate.bottomSeconds,
                endSeconds: measurement.timestampSeconds,
                counted: true,
                countConfidence: candidate.minimumConfidence,
                cleanAssessment: .notAssessed
            )
            reps.append(rep)
            return update(phase: .standing, completedRep: rep)
        }
    }

    public mutating func reset() {
        framesObserved = 0
        framesAnalyzed = 0
        reps.removeAll(keepingCapacity: true)
        lastFrameTimestamp = nil
        lastUsableTimestamp = nil
        clearTrackingReference()
    }

    private var publicPhase: SquatMovementPhase {
        switch state {
        case .acquiringStandingReference:
            .acquiringStandingReference
        case .standing:
            .standing
        case .descending:
            .descending
        case .ascending:
            .ascending
        }
    }

    private mutating func observeStandingCalibration(_ measurement: Measurement) {
        guard measurement.kneeAngleDegrees >= configuration.minimumStandingKneeAngleDegrees else {
            standingSamples.removeAll(keepingCapacity: true)
            return
        }

        standingSamples.append(measurement)
        if standingSamples.count > 60 {
            standingSamples.removeFirst(standingSamples.count - 60)
        }

        guard standingSamples.count >= configuration.minimumStandingCalibrationSamples,
              let first = standingSamples.first,
              measurement.timestampSeconds - first.timestampSeconds
                >= configuration.standingCalibrationDurationSeconds else {
            return
        }

        let reference = StandingReference(
            kneeAngleDegrees: median(standingSamples.map(\.kneeAngleDegrees)),
            hipY: median(standingSamples.map(\.hipY)),
            legLength: median(standingSamples.map(\.legLength))
        )
        state = .standing(reference)
        standingSamples.removeAll(keepingCapacity: true)
    }

    private mutating func handleMissingEvidence(at timestamp: Double) -> SquatAnalyzerUpdate {
        guard let lastUsableTimestamp else {
            return update(phase: .acquiringStandingReference, completedRep: nil)
        }

        if timestamp - lastUsableTimestamp > configuration.maximumEvidenceGapSeconds {
            clearTrackingReference()
        }
        return update(phase: .trackingLost, completedRep: nil)
    }

    private mutating func clearTrackingReference() {
        state = .acquiringStandingReference
        primarySide = nil
        standingSamples.removeAll(keepingCapacity: true)
        smoothedMeasurement = nil
        lastUsableTimestamp = nil
    }

    private mutating func measurement(from frame: PoseFrame) -> Measurement? {
        let landmarks = frame.landmarks.reduce(into: [PoseLandmarkName: PoseLandmark]()) {
            current, landmark in
            if current[landmark.name].map({ $0.confidence < landmark.confidence }) ?? true {
                current[landmark.name] = landmark
            }
        }

        if let primarySide {
            return measurement(
                for: primarySide,
                landmarks: landmarks,
                timestamp: frame.timestampSeconds
            )
        }

        let candidates = BodySide.allCases.compactMap { side -> (BodySide, Measurement)? in
            guard let measurement = measurement(
                for: side,
                landmarks: landmarks,
                timestamp: frame.timestampSeconds
            ) else {
                return nil
            }
            return (side, measurement)
        }
        guard let best = candidates.max(by: { $0.1.confidence < $1.1.confidence }) else {
            return nil
        }
        primarySide = best.0
        return best.1
    }

    private func measurement(
        for side: BodySide,
        landmarks: [PoseLandmarkName: PoseLandmark],
        timestamp: Double
    ) -> Measurement? {
        let names: (PoseLandmarkName, PoseLandmarkName, PoseLandmarkName) = switch side {
        case .left:
            (.leftHip, .leftKnee, .leftAnkle)
        case .right:
            (.rightHip, .rightKnee, .rightAnkle)
        }
        guard let hip = landmarks[names.0],
              let knee = landmarks[names.1],
              let ankle = landmarks[names.2] else {
            return nil
        }

        let points = [hip, knee, ankle]
        guard points.allSatisfy({
            $0.confidence >= configuration.minimumLandmarkConfidence
                && $0.x.isFinite
                && $0.y.isFinite
        }) else {
            return nil
        }

        let thigh = Vector(x: hip.x - knee.x, y: hip.y - knee.y)
        let shin = Vector(x: ankle.x - knee.x, y: ankle.y - knee.y)
        let thighLength = hypot(thigh.x, thigh.y)
        let shinLength = hypot(shin.x, shin.y)
        let legLength = hypot(hip.x - ankle.x, hip.y - ankle.y)
        guard thighLength > 0.01, shinLength > 0.01, legLength > 0.05 else {
            return nil
        }

        let cosine = max(
            -1,
            min(1, (thigh.x * shin.x + thigh.y * shin.y) / (thighLength * shinLength))
        )
        let kneeAngle = acos(cosine) * 180 / .pi
        return Measurement(
            timestampSeconds: timestamp,
            kneeAngleDegrees: kneeAngle,
            hipY: hip.y,
            legLength: legLength,
            confidence: points.map(\.confidence).min() ?? 0
        )
    }

    private mutating func smooth(_ raw: Measurement) -> Measurement {
        guard let previous = smoothedMeasurement else {
            smoothedMeasurement = raw
            return raw
        }
        let alpha = max(0, min(1, configuration.smoothingFactor))
        let smoothed = Measurement(
            timestampSeconds: raw.timestampSeconds,
            kneeAngleDegrees: alpha * raw.kneeAngleDegrees
                + (1 - alpha) * previous.kneeAngleDegrees,
            hipY: alpha * raw.hipY + (1 - alpha) * previous.hipY,
            legLength: alpha * raw.legLength + (1 - alpha) * previous.legLength,
            confidence: raw.confidence
        )
        smoothedMeasurement = smoothed
        return smoothed
    }

    private func updated(
        _ existing: RepCandidate,
        with measurement: Measurement,
        reference: StandingReference
    ) -> RepCandidate {
        var candidate = existing
        let kneeFlexion = reference.kneeAngleDegrees - measurement.kneeAngleDegrees
        candidate.maximumKneeFlexionDegrees = max(
            candidate.maximumKneeFlexionDegrees,
            kneeFlexion
        )
        candidate.maximumHipDescentRatio = max(
            candidate.maximumHipDescentRatio,
            hipDescentRatio(measurement, from: reference)
        )
        candidate.minimumConfidence = min(candidate.minimumConfidence, measurement.confidence)
        if measurement.kneeAngleDegrees < candidate.minimumKneeAngleDegrees {
            candidate.minimumKneeAngleDegrees = measurement.kneeAngleDegrees
            candidate.bottomSeconds = measurement.timestampSeconds
        }
        return candidate
    }

    private func hipDescentRatio(
        _ measurement: Measurement,
        from reference: StandingReference
    ) -> Double {
        (measurement.hipY - reference.hipY) / max(reference.legLength, 0.01)
    }

    private func repDuration(_ candidate: RepCandidate, at timestamp: Double) -> Double {
        timestamp - candidate.startSeconds
    }

    private func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else {
            return 0
        }
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private func update(
        phase: SquatMovementPhase,
        completedRep: AnalyzedSquatRep?
    ) -> SquatAnalyzerUpdate {
        SquatAnalyzerUpdate(
            phase: phase,
            provisionalCountedReps: reps.count,
            completedRep: completedRep,
            framesObserved: framesObserved,
            framesAnalyzed: framesAnalyzed
        )
    }
}

private enum DetectionState: Sendable {
    case acquiringStandingReference
    case standing(StandingReference)
    case descending(StandingReference, RepCandidate)
    case ascending(StandingReference, RepCandidate)
}

private struct StandingReference: Sendable {
    var kneeAngleDegrees: Double
    var hipY: Double
    var legLength: Double
}

private struct RepCandidate: Sendable {
    var startSeconds: Double
    var bottomSeconds: Double
    var minimumKneeAngleDegrees: Double
    var maximumKneeFlexionDegrees: Double
    var maximumHipDescentRatio: Double
    var minimumConfidence: Double
    var lastKneeAngleDegrees: Double
}

private struct Measurement: Sendable {
    var timestampSeconds: Double
    var kneeAngleDegrees: Double
    var hipY: Double
    var legLength: Double
    var confidence: Double
}

private struct Vector {
    var x: Double
    var y: Double
}
