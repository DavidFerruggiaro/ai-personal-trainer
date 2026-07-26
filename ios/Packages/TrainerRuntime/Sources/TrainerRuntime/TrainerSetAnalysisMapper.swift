import SquatAnalysis
import TrainerCore

public enum TrainerSetAnalysisMapper {
    public static func summary(
        from result: SquatAnalysisResult,
        provisionalCountedReps: Int
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
            framesAnalyzed: result.framesAnalyzed
        )
    }
}
