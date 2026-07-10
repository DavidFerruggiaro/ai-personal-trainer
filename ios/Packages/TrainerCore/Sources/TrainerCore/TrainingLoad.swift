public enum LoadUnit: String, CaseIterable, Equatable, Identifiable, Sendable {
    case pounds = "lb"
    case kilograms = "kg"

    public var id: Self { self }

    public static let defaultUnit: LoadUnit = .pounds
}

public enum TrainingLoadError: Error, Equatable, Sendable {
    case invalidValue
}

public struct TrainingLoad: Equatable, Sendable {
    public let value: Double
    public let unit: LoadUnit

    public init(value: Double, unit: LoadUnit) throws {
        guard value.isFinite, value >= 0 else {
            throw TrainingLoadError.invalidValue
        }

        self.value = value
        self.unit = unit
    }
}
