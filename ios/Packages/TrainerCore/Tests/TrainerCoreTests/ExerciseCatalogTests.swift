import Testing
@testable import TrainerCore

struct ExerciseCatalogTests {
    @Test func v1CatalogExposesOnlyBackSquatToTheWorkoutFlow() {
        let catalog = ExerciseCatalog.v1

        #expect(catalog.supportedExercises.map(\.id) == [.backSquat])
        #expect(catalog.supportedExercise(withID: .backSquat)?.displayName == "Back Squat")
    }

    @Test func plannedExercisesExistButCannotBeSelected() {
        let catalog = ExerciseCatalog.v1
        let plannedIDs: [ExerciseID] = [
            .gobletSquat,
            .bodyweightSquat,
            .dumbbellSquat,
            .kettlebellSquat
        ]

        for id in plannedIDs {
            #expect(catalog.exercise(withID: id)?.availability == .planned)
            #expect(catalog.supportedExercise(withID: id) == nil)
        }
    }

    @Test func disabledExercisesAreAlsoHiddenFromSelection() {
        let disabledExercise = ExerciseDefinition(
            id: ExerciseID(rawValue: "disabled_test_exercise"),
            displayName: "Disabled Test Exercise",
            variantDisplayName: "Test",
            availability: .disabled
        )
        let catalog = ExerciseCatalog(exercises: [disabledExercise])

        #expect(catalog.supportedExercises.isEmpty)
        #expect(catalog.supportedExercise(withID: disabledExercise.id) == nil)
    }

    @Test func supportedSelectionIsAttachedToTheSessionAndCurrentSet() throws {
        let exercise = try #require(ExerciseCatalog.v1.supportedExercise(withID: .backSquat))

        let session = QuickSession(exerciseID: exercise.id)

        #expect(session.exerciseID == exercise.id)
        #expect(session.currentSet.exerciseID == exercise.id)
    }
}
