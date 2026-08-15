import Foundation

public enum SetupCheckID: String, CaseIterable, Equatable, Identifiable, Sendable {
    case fullBodyVisible = "full_body_visible"
    case sideViewLikely = "side_view_likely"
    case phoneStable = "phone_stable"
    case poseConfidenceOK = "pose_confidence_ok"

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .fullBodyVisible:
            "Full body visible"
        case .sideViewLikely:
            "Side view"
        case .phoneStable:
            "Phone stable"
        case .poseConfidenceOK:
            "Pose confidence"
        }
    }

    public var setupInstruction: String {
        switch self {
        case .fullBodyVisible:
            "Keep your head, hips, knees, and feet in frame."
        case .sideViewLikely:
            "Stand side-on so the camera can see squat depth."
        case .phoneStable:
            "Place the phone on a stable surface."
        case .poseConfidenceOK:
            "Use clear lighting and keep your body unobstructed."
        }
    }

    public var failureFix: String {
        switch self {
        case .fullBodyVisible:
            "Move the phone back until your full body stays in frame."
        case .sideViewLikely:
            "Turn so your shoulder and hip line are side-on to the camera."
        case .phoneStable:
            "Set the phone down securely; do not hand-hold it."
        case .poseConfidenceOK:
            "Improve the lighting and clear obstructions around your body."
        }
    }
}

public enum SetupCheckStatus: String, Equatable, Sendable {
    case pending
    case passing
    case failing
}

public struct SetupCheck: Equatable, Identifiable, Sendable {
    public let id: SetupCheckID
    public let status: SetupCheckStatus

    public init(id: SetupCheckID, status: SetupCheckStatus) {
        self.id = id
        self.status = status
    }
}

public enum SetupGateDisposition: String, Equatable, Sendable {
    case passed
    case overridden
}

public struct SetupGateOutcome: Equatable, Sendable {
    public let checks: [SetupCheck]
    public let decidedAt: Date
    public let disposition: SetupGateDisposition

    public var overrideUsed: Bool {
        disposition == .overridden
    }

    public var requiresLowConfidenceLabel: Bool {
        disposition == .overridden
    }

    public var failedCheckIDs: [SetupCheckID] {
        checks.compactMap { check in
            check.status == .failing ? check.id : nil
        }
    }

    fileprivate init(
        checks: [SetupCheck],
        decidedAt: Date,
        disposition: SetupGateDisposition
    ) {
        self.checks = checks
        self.decidedAt = decidedAt
        self.disposition = disposition
    }
}

public enum SetupGateError: Error, Equatable, Sendable {
    case checksPending
    case checksFailing
    case overrideUnavailable
}

public struct SetupGateAssessment: Equatable, Sendable {
    public let checks: [SetupCheck]

    public var hasPendingChecks: Bool {
        checks.contains { $0.status == .pending }
    }

    public var failedChecks: [SetupCheck] {
        checks.filter { $0.status == .failing }
    }

    public var isReady: Bool {
        checks.allSatisfy { $0.status == .passing }
    }

    public init(statuses: [SetupCheckID: SetupCheckStatus] = [:]) {
        checks = SetupCheckID.allCases.map { id in
            SetupCheck(id: id, status: statuses[id] ?? .pending)
        }
    }

    public func check(withID id: SetupCheckID) -> SetupCheck? {
        checks.first { $0.id == id }
    }

    public func approve(at decidedAt: Date = Date()) throws -> SetupGateOutcome {
        guard !hasPendingChecks else {
            throw SetupGateError.checksPending
        }
        guard failedChecks.isEmpty else {
            throw SetupGateError.checksFailing
        }

        return SetupGateOutcome(
            checks: checks,
            decidedAt: decidedAt,
            disposition: .passed
        )
    }

    public func overrideFailures(at decidedAt: Date = Date()) throws -> SetupGateOutcome {
        guard !hasPendingChecks else {
            throw SetupGateError.checksPending
        }
        guard !failedChecks.isEmpty else {
            throw SetupGateError.overrideUnavailable
        }

        return SetupGateOutcome(
            checks: checks,
            decidedAt: decidedAt,
            disposition: .overridden
        )
    }

    public static let pending = SetupGateAssessment()
}
