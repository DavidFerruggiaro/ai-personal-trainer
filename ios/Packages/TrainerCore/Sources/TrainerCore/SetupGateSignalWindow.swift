import Foundation

public struct SetupGateSignalSample: Equatable, Sendable {
    public let fullBodyVisible: Bool?
    public let sideViewLikely: Bool?
    public let phoneStable: Bool?
    public let poseConfidenceOK: Bool?

    public init(
        fullBodyVisible: Bool?,
        sideViewLikely: Bool?,
        phoneStable: Bool?,
        poseConfidenceOK: Bool?
    ) {
        self.fullBodyVisible = fullBodyVisible
        self.sideViewLikely = sideViewLikely
        self.phoneStable = phoneStable
        self.poseConfidenceOK = poseConfidenceOK
    }

    func value(for id: SetupCheckID) -> Bool? {
        switch id {
        case .fullBodyVisible:
            fullBodyVisible
        case .sideViewLikely:
            sideViewLikely
        case .phoneStable:
            phoneStable
        case .poseConfidenceOK:
            poseConfidenceOK
        }
    }
}

public struct SetupGateSignalWindow: Equatable, Sendable {
    public let capacity: Int
    public let minimumSamples: Int
    public let passingRatio: Double

    private var valuesByCheck: [SetupCheckID: [Bool]]

    public init(
        capacity: Int = 45,
        minimumSamples: Int = 24,
        passingRatio: Double = 0.80
    ) {
        precondition(capacity > 0)
        precondition(minimumSamples > 0 && minimumSamples <= capacity)
        precondition((0...1).contains(passingRatio))
        self.capacity = capacity
        self.minimumSamples = minimumSamples
        self.passingRatio = passingRatio
        self.valuesByCheck = [:]
    }

    public var assessment: SetupGateAssessment {
        SetupGateAssessment(statuses: Dictionary(
            uniqueKeysWithValues: SetupCheckID.allCases.map { id in
                (id, status(for: id))
            }
        ))
    }

    public mutating func observe(_ sample: SetupGateSignalSample) {
        for id in SetupCheckID.allCases {
            guard let value = sample.value(for: id) else {
                continue
            }
            var values = valuesByCheck[id, default: []]
            values.append(value)
            if values.count > capacity {
                values.removeFirst(values.count - capacity)
            }
            valuesByCheck[id] = values
        }
    }

    public mutating func reset() {
        valuesByCheck.removeAll(keepingCapacity: true)
    }

    private func status(for id: SetupCheckID) -> SetupCheckStatus {
        let values = valuesByCheck[id, default: []]
        guard values.count >= minimumSamples else {
            return .pending
        }
        let passingCount = values.lazy.filter { $0 }.count
        let ratio = Double(passingCount) / Double(values.count)
        return ratio >= passingRatio ? .passing : .failing
    }
}
