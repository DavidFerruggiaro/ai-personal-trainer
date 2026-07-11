import Foundation
import Testing
@testable import TrainerCore

struct ActiveSetCaptureTests {
    @Test func beginsRecordingFromIdleAndTracksFramesWithoutInventingReps() throws {
        var capture = ActiveSetCapture()
        try capture.beginRecording()

        #expect(capture.phase == .recording)
        #expect(capture.provisionalCountedReps == 0)
        #expect(capture.framesObserved == 0)

        capture.observeFrame()
        capture.observeFrame()
        capture.updateProvisionalCountedReps(3)

        #expect(capture.framesObserved == 2)
        #expect(capture.provisionalCountedReps == 3)
    }

    @Test func stopMovesThroughProcessingToAwaitingReviewWithoutPause() throws {
        var capture = ActiveSetCapture()
        try capture.beginRecording()
        capture.observeFrame()
        capture.updateProvisionalCountedReps(5)
        try capture.stop()

        #expect(capture.phase == .processing)
        #expect(!capture.showsActiveSetControls)

        try capture.finishProcessing(finalizedCountedReps: 4)
        #expect(capture.phase == .awaitingReview)
        #expect(capture.provisionalCountedReps == 5)
        #expect(capture.finalizedCountedReps == 4)
    }

    @Test func zeroRepDiscardIsImmediateWhileDetectedRepsRequireConfirmation() throws {
        var capture = ActiveSetCapture()
        try capture.beginRecording()
        try capture.requestDiscard()
        #expect(capture.phase == .discarded)
        #expect(!capture.discardConfirmationRequired)

        capture.reset()
        try capture.beginRecording()
        capture.updateProvisionalCountedReps(2)
        try capture.requestDiscard()
        #expect(capture.phase == .recording)
        #expect(capture.discardConfirmationRequired)

        capture.cancelDiscardConfirmation()
        #expect(!capture.discardConfirmationRequired)

        try capture.requestDiscard()
        try capture.confirmDiscard()
        #expect(capture.phase == .discarded)
        #expect(!capture.discardConfirmationRequired)
    }

    @Test func processingFailureCanRetryWithoutLosingProvisionalEvidence() throws {
        var capture = ActiveSetCapture()
        try capture.beginRecording()
        capture.updateProvisionalCountedReps(3)
        try capture.stop()

        try capture.failProcessing()
        #expect(capture.phase == .processingFailed)
        #expect(capture.provisionalCountedReps == 3)

        try capture.retryProcessing()
        #expect(capture.phase == .processing)
        #expect(capture.provisionalCountedReps == 3)
    }

    @Test func processingFailureCanBeDiscardedWithDetectedRepConfirmation() throws {
        var capture = ActiveSetCapture()
        try capture.beginRecording()
        capture.updateProvisionalCountedReps(2)
        try capture.stop()
        try capture.failProcessing()

        try capture.requestDiscard()
        #expect(capture.phase == .processingFailed)
        #expect(capture.discardConfirmationRequired)

        try capture.confirmDiscard()
        #expect(capture.phase == .discarded)
    }

    @Test func inFlightProcessingCanBeDiscardedIfItHangs() throws {
        var capture = ActiveSetCapture()
        try capture.beginRecording()
        capture.updateProvisionalCountedReps(1)
        try capture.stop()

        try capture.requestDiscard()
        #expect(capture.phase == .processing)
        #expect(capture.discardConfirmationRequired)

        try capture.confirmDiscard()
        #expect(capture.phase == .discarded)
    }

    @Test func reviewDiscardUsesCanonicalDetectionWhenLiveCountWasZero() throws {
        var capture = ActiveSetCapture()
        try capture.beginRecording()
        try capture.stop()
        try capture.finishProcessing(finalizedCountedReps: 1)

        try capture.requestDiscard()

        #expect(capture.phase == .awaitingReview)
        #expect(capture.discardConfirmationRequired)
    }

    @Test func rejectsInvalidTransitions() {
        var capture = ActiveSetCapture()
        #expect(throws: ActiveSetCaptureError.invalidPhase) {
            try capture.stop()
        }
        #expect(throws: ActiveSetCaptureError.invalidPhase) {
            try capture.requestDiscard()
        }

        try? capture.beginRecording()
        #expect(throws: ActiveSetCaptureError.invalidPhase) {
            try capture.beginRecording()
        }
        #expect(throws: ActiveSetCaptureError.invalidPhase) {
            try capture.finishProcessing(finalizedCountedReps: 0)
        }
    }
}
