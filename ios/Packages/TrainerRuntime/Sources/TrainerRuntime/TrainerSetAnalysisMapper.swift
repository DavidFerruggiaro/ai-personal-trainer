import PoseCore
import SquatAnalysis
import TrainerCore

public enum TrainerSetAnalysisMapper {
    public static func summary(
        from result: SquatAnalysisResult,
        provisionalCountedReps: Int,
        poseEngine: PoseEngineInfo? = nil
    ) -> SetAnalysisSummary {
        let cleanResult: SetCleanResult
        if result.countedReps > 0, let cleanReps = result.cleanReps {
            cleanResult = .assessed(cleanReps: cleanReps)
        } else {
            cleanResult = .unavailable
        }

        return SetAnalysisSummary(
            provisionalCountedReps: provisionalCountedReps,
            finalizedCountedReps: result.countedReps,
            cleanResult: cleanResult,
            reps: result.reps.filter(\.counted).map { rep in
                let quality: SetRepQuality = switch rep.cleanAssessment.clean {
                case .some(true):
                    .clean
                case .some(false):
                    .notClean
                case .none:
                    .unavailable
                }
                return SetRepSummary(
                    index: rep.index,
                    startSeconds: rep.startSeconds,
                    bottomSeconds: rep.bottomSeconds,
                    endSeconds: rep.endSeconds,
                    countConfidence: rep.countConfidence,
                    quality: quality
                )
            },
            framesObserved: result.framesObserved,
            framesAnalyzed: result.framesAnalyzed,
            modelMetadata: SetResultModelMetadata(
                poseEngine: poseEngine.map { engine in
                    SetResultModelComponentMetadata(
                        name: engine.name,
                        version: engine.version,
                        configuration: engine.config
                    )
                },
                analyzer: SetResultModelComponentMetadata(name: "SquatAnalyzer")
            )
        )
    }
}
