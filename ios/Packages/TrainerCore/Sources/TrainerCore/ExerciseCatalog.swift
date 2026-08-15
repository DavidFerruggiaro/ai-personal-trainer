public struct ExerciseID: Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        precondition(!rawValue.isEmpty, "Exercise IDs must not be empty")
        self.rawValue = rawValue
    }

    public static let backSquat = ExerciseID(rawValue: "back_squat")
    public static let gobletSquat = ExerciseID(rawValue: "goblet_squat")
    public static let bodyweightSquat = ExerciseID(rawValue: "bodyweight_squat")
    public static let dumbbellSquat = ExerciseID(rawValue: "dumbbell_squat")
    public static let kettlebellSquat = ExerciseID(rawValue: "kettlebell_squat")
}

public enum ExerciseAvailability: String, Equatable, Sendable {
    case supported
    case planned
    case disabled
}

public struct ExerciseDefinition: Equatable, Identifiable, Sendable {
    public let id: ExerciseID
    public let displayName: String
    public let variantDisplayName: String
    public let availability: ExerciseAvailability

    public init(
        id: ExerciseID,
        displayName: String,
        variantDisplayName: String,
        availability: ExerciseAvailability
    ) {
        self.id = id
        self.displayName = displayName
        self.variantDisplayName = variantDisplayName
        self.availability = availability
    }
}

public struct ExerciseCatalog: Equatable, Sendable {
    public let exercises: [ExerciseDefinition]

    public var supportedExercises: [ExerciseDefinition] {
        exercises.filter { $0.availability == .supported }
    }

    public init(exercises: [ExerciseDefinition]) {
        self.exercises = exercises
    }

    public func exercise(withID id: ExerciseID) -> ExerciseDefinition? {
        exercises.first { $0.id == id }
    }

    public func supportedExercise(withID id: ExerciseID) -> ExerciseDefinition? {
        supportedExercises.first { $0.id == id }
    }

    public static let v1 = ExerciseCatalog(exercises: [
        ExerciseDefinition(
            id: .backSquat,
            displayName: "Back Squat",
            variantDisplayName: "Barbell",
            availability: .supported
        ),
        ExerciseDefinition(
            id: .gobletSquat,
            displayName: "Goblet Squat",
            variantDisplayName: "Dumbbell or Kettlebell",
            availability: .planned
        ),
        ExerciseDefinition(
            id: .bodyweightSquat,
            displayName: "Bodyweight Squat",
            variantDisplayName: "Bodyweight",
            availability: .planned
        ),
        ExerciseDefinition(
            id: .dumbbellSquat,
            displayName: "Dumbbell Squat",
            variantDisplayName: "Dumbbell",
            availability: .planned
        ),
        ExerciseDefinition(
            id: .kettlebellSquat,
            displayName: "Kettlebell Squat",
            variantDisplayName: "Kettlebell",
            availability: .planned
        )
    ])
}
