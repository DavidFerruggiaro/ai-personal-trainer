import Foundation

public enum PreSetCountdownState: Equatable, Sendable {
    case idle
    case counting(remainingSeconds: Int)
    case visibilityConfirmationRequired
    case readyForActiveCapture
}

public struct PreSetCountdown: Equatable, Sendable {
    public let durationSeconds: Int
    public private(set) var state: PreSetCountdownState

    public init(durationSeconds: Int = 5) {
        precondition(durationSeconds > 0)
        self.durationSeconds = durationSeconds
        self.state = .idle
    }

    public mutating func start(after outcome: SetupGateOutcome) {
        _ = outcome
        state = .counting(remainingSeconds: durationSeconds)
    }

    public mutating func tick(fullBodyVisibleAtEnd: Bool) {
        guard case let .counting(remainingSeconds) = state else {
            return
        }
        if remainingSeconds > 1 {
            state = .counting(remainingSeconds: remainingSeconds - 1)
        } else {
            state = fullBodyVisibleAtEnd
                ? .readyForActiveCapture
                : .visibilityConfirmationRequired
        }
    }

    public mutating func startAnyway() {
        guard state == .visibilityConfirmationRequired else {
            return
        }
        state = .readyForActiveCapture
    }

    public mutating func reset() {
        state = .idle
    }
}
