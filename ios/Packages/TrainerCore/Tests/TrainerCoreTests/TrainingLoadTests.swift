import Foundation
import Testing
@testable import TrainerCore

struct TrainingLoadTests {
    @Test func poundsAreTheInitialUnitDefault() {
        #expect(LoadUnit.defaultUnit == .pounds)
    }

    @Test func invalidValuesAreRejectedWithoutUsingZeroAsMissing() throws {
        #expect(throws: TrainingLoadError.invalidValue) {
            try TrainingLoad(value: -1, unit: .pounds)
        }
        #expect(throws: TrainingLoadError.invalidValue) {
            try TrainingLoad(value: .nan, unit: .pounds)
        }
        #expect(throws: TrainingLoadError.invalidValue) {
            try TrainingLoad(value: .infinity, unit: .kilograms)
        }

        let explicitZero = try TrainingLoad(value: 0, unit: .pounds)
        #expect(explicitZero.value == 0)
    }

    @Test func completingWithoutLoadIsRejected() {
        var session = QuickSession(exerciseID: .backSquat)

        #expect(session.currentSet.load == nil)
        #expect(throws: QuickSessionError.missingLoad) {
            try session.advanceCurrentSetForCameraIndependentTesting()
        }
        #expect(session.completedSets.isEmpty)
        #expect(session.currentSet.ordinal == 1)
    }

    @Test func nextSetCopiesPreviousLoadAndCanBeEditedIndependently() throws {
        let firstSetID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let secondSetID = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!
        var session = QuickSession(exerciseID: .backSquat, initialSetID: firstSetID)
        let firstLoad = try TrainingLoad(value: 185, unit: .pounds)
        let secondLoad = try TrainingLoad(value: 195, unit: .pounds)

        try session.setCurrentSetLoad(firstLoad)
        try session.advanceCurrentSetForCameraIndependentTesting(nextSetID: secondSetID)

        #expect(session.completedSets[0].load == firstLoad)
        #expect(session.currentSet.load == firstLoad)

        try session.setCurrentSetLoad(secondLoad)

        #expect(session.completedSets[0].load == firstLoad)
        #expect(session.currentSet.load == secondLoad)
    }

    @Test func kilogramsCarryForwardWithoutConversionOrReinterpretation() throws {
        var session = QuickSession(exerciseID: .backSquat)
        let load = try TrainingLoad(value: 100.5, unit: .kilograms)

        try session.setCurrentSetLoad(load)
        let completed = try session.advanceCurrentSetForCameraIndependentTesting()

        #expect(completed.load == load)
        #expect(session.currentSet.load == load)
        #expect(session.currentSet.load?.value == 100.5)
        #expect(session.currentSet.load?.unit == .kilograms)
    }
}
