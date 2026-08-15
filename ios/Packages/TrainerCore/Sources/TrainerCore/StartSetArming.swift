import Foundation

public enum StartSetArmingState: Equatable, Sendable {
    case idle
    case armed
    case weakSetupDecision(SetupGateAssessment)
}

/// Deliberate pre-start arming so a solo lifter can leave the phone propped up.
///
/// Passing setup may start countdown immediately after arming. Evaluated failures
/// wait through a positioning grace period, then latch until the user explicitly
/// retries, accepts low-confidence setup, or cancels.
public struct StartSetArming: Equatable, Sendable {
    public private(set) var state: StartSetArmingState
    public let weakSetupGraceDuration: TimeInterval
    private var armedAt: Date?

    public init(weakSetupGraceDuration: TimeInterval = 10) {
        precondition(weakSetupGraceDuration >= 0)
        state = .idle
        self.weakSetupGraceDuration = weakSetupGraceDuration
        armedAt = nil
    }

    public var isArmed: Bool {
        state != .idle
    }

    public var latchedWeakSetup: SetupGateAssessment? {
        guard case let .weakSetupDecision(assessment) = state else {
            return nil
        }
        return assessment
    }

    public mutating func arm(at armedAt: Date = Date()) {
        state = .armed
        self.armedAt = armedAt
    }

    public mutating func cancel() {
        state = .idle
        armedAt = nil
    }

    public mutating func retryWeakSetup(at armedAt: Date = Date()) {
        guard latchedWeakSetup != nil else {
            return
        }
        arm(at: armedAt)
    }

    public mutating func acceptWeakSetup(
        at decidedAt: Date = Date()
    ) throws -> SetupGateOutcome {
        guard let latchedWeakSetup else {
            throw SetupGateError.overrideUnavailable
        }
        let outcome = try latchedWeakSetup.overrideFailures(at: decidedAt)
        cancel()
        return outcome
    }

    /// Observes the latest evaluated setup.
    ///
    /// Returns the passing assessment that may begin countdown. Failing evidence
    /// is latched only after the solo-positioning grace period and never launches
    /// without an explicit `acceptWeakSetup` call.
    public mutating func observe(
        _ assessment: SetupGateAssessment,
        at observedAt: Date = Date()
    ) -> SetupGateAssessment? {
        guard state == .armed else {
            return nil
        }
        if assessment.isReady {
            return assessment
        }
        guard !assessment.hasPendingChecks,
              !assessment.failedChecks.isEmpty,
              let armedAt,
              observedAt.timeIntervalSince(armedAt) >= weakSetupGraceDuration else {
            return nil
        }
        state = .weakSetupDecision(assessment)
        return nil
    }
}
