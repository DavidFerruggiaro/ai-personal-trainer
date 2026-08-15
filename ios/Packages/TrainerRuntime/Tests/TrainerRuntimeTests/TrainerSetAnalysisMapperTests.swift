import PoseCore
import SquatAnalysis
import Testing
import TrainerCore
import TrainerRuntime

@Test
func analysisSummaryPreservesCountsWithoutInventingCleanEvidence() {
    let result = SquatAnalysisResult(
        framesObserved: 12,
        framesAnalyzed: 10,
        reps: [
            AnalyzedSquatRep(
                index: 1,
                startSeconds: 1,
                bottomSeconds: 2,
                endSeconds: 3,
                counted: true,
                countConfidence: 0.86,
                cleanAssessment: .notAssessed
            ),
            AnalyzedSquatRep(
                index: 2,
                startSeconds: 4,
                bottomSeconds: 5,
                endSeconds: 6,
                counted: false,
                countConfidence: 0.40,
                cleanAssessment: .notAssessed
            )
        ]
    )

    let summary = TrainerSetAnalysisMapper.summary(
        from: result,
        provisionalCountedReps: 2,
        poseEngine: PoseEngineInfo(
            name: "mediapipe_pose_landmarker",
            version: "MediaPipeTasksVision",
            config: ["model": "pose_landmarker_full.task"]
        )
    )

    #expect(summary.provisionalCountedReps == 2)
    #expect(summary.finalizedCountedReps == 1)
    #expect(summary.cleanResult == .unavailable)
    #expect(summary.reps == [
        SetRepSummary(
            index: 1,
            startSeconds: 1,
            bottomSeconds: 2,
            endSeconds: 3,
            countConfidence: 0.86,
            quality: .unavailable
        )
    ])
    #expect(summary.framesObserved == 12)
    #expect(summary.framesAnalyzed == 10)
    #expect(summary.modelMetadata.poseEngine == SetResultModelComponentMetadata(
        name: "mediapipe_pose_landmarker",
        version: "MediaPipeTasksVision",
        configuration: ["model": "pose_landmarker_full.task"]
    ))
    #expect(summary.modelMetadata.analyzer?.name == "SquatAnalyzer")
}

@Test
func analysisSummaryMapsCompleteCleanEvidencePerCountedRep() {
    let result = SquatAnalysisResult(
        framesObserved: 24,
        framesAnalyzed: 22,
        reps: [
            AnalyzedSquatRep(
                index: 1,
                startSeconds: 1,
                bottomSeconds: 2,
                endSeconds: 3,
                counted: true,
                countConfidence: 0.93,
                cleanAssessment: SquatCleanRepAssessment(
                    depth: .passed,
                    lockout: .passed,
                    tempoControl: .passed
                )
            ),
            AnalyzedSquatRep(
                index: 2,
                startSeconds: 4,
                bottomSeconds: 5,
                endSeconds: 6,
                counted: true,
                countConfidence: 0.78,
                cleanAssessment: SquatCleanRepAssessment(
                    depth: .passed,
                    lockout: .failed,
                    tempoControl: .passed
                )
            )
        ]
    )

    let summary = TrainerSetAnalysisMapper.summary(
        from: result,
        provisionalCountedReps: 2
    )

    #expect(summary.finalizedCountedReps == 2)
    #expect(summary.cleanResult == .assessed(cleanReps: 1))
    #expect(summary.reps.map(\.quality) == [.clean, .notClean])
}

@Test
func analysisSummaryKeepsAggregateUnavailableWhenAnyCountedRepIsUnassessed() {
    let result = SquatAnalysisResult(
        framesObserved: 18,
        framesAnalyzed: 18,
        reps: [
            AnalyzedSquatRep(
                index: 1,
                startSeconds: 1,
                bottomSeconds: 2,
                endSeconds: 3,
                counted: true,
                countConfidence: 0.91,
                cleanAssessment: SquatCleanRepAssessment(
                    depth: .passed,
                    lockout: .passed,
                    tempoControl: .passed
                )
            ),
            AnalyzedSquatRep(
                index: 2,
                startSeconds: 4,
                bottomSeconds: 5,
                endSeconds: 6,
                counted: true,
                countConfidence: 0.82,
                cleanAssessment: SquatCleanRepAssessment(
                    depth: .passed,
                    lockout: .passed,
                    tempoControl: .insufficientEvidence
                )
            )
        ]
    )

    let summary = TrainerSetAnalysisMapper.summary(
        from: result,
        provisionalCountedReps: 2
    )

    #expect(summary.cleanResult == .unavailable)
    #expect(summary.reps.map(\.quality) == [.clean, .unavailable])
}

@Test
func analysisSummaryDoesNotPresentZeroCountedRepsAsAssessedCleanEvidence() {
    let result = SquatAnalysisResult(
        framesObserved: 8,
        framesAnalyzed: 8,
        reps: [
            AnalyzedSquatRep(
                index: 1,
                startSeconds: 1,
                bottomSeconds: 2,
                endSeconds: 3,
                counted: false,
                countConfidence: 0.42,
                cleanAssessment: SquatCleanRepAssessment(
                    depth: .passed,
                    lockout: .passed,
                    tempoControl: .passed
                )
            )
        ]
    )

    #expect(result.cleanReps == 0)

    let summary = TrainerSetAnalysisMapper.summary(
        from: result,
        provisionalCountedReps: 0
    )

    #expect(summary.finalizedCountedReps == 0)
    #expect(summary.cleanResult == .unavailable)
    #expect(summary.reps.isEmpty)
}
