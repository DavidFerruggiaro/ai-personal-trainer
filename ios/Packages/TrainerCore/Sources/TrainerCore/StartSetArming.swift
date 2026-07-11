import Foundation

public enum StartSetArmingMode: Equatable, Sendable {
    /// Wait until every setup check is passing, then begin countdown.
    case waitForPassingSetup
    /// Wait until checks leave pending; begin with override if any are failing.
    case waitForEvaluatedSetupAllowingOverride
}

public enum StartSetArmingState: Equatable, Sendable {
    case idle
    case armed(StartSetArmingMode)
}

public enum StartSetLaunch: Equatable, Sendable {
    case approve
    case overrideFailures
}

/// Deliberate pre-start arming so the lifter can leave the phone propped up.
///
/// Setup becoming ready must not start a set by itself. The user arms first,
/// walks into frame, and countdown begins only after the armed mode's setup
/// condition is met.
public struct StartSetArming: Equatable, Sendable {
    public private(set) var state: StartSetArmingState

    public init() {
        state = .idle
    }

    public var isArmed: Bool {
        if case .armed = state {
            return true
        }
        return false
    }

    public mutating func arm(_ mode: StartSetArmingMode) {
        state = .armed(mode)
    }

    public mutating func cancel() {
        state = .idle
    }

    public func launchIfReady(given assessment: SetupGateAssessment) -> StartSetLaunch? {
        guard case let .armed(mode) = state else {
            return nil
        }

        switch mode {
        case .waitForPassingSetup:
            return assessment.isReady ? .approve : nil
        case .waitForEvaluatedSetupAllowingOverride:
            guard !assessment.hasPendingChecks else {
                return nil
            }
            return assessment.isReady ? .approve : .overrideFailures
        }
    }
}
