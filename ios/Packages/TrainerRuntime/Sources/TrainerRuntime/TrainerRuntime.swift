import PoseCore
import TrainerCore

public enum SetupGateSignalAdapter {
    public static func sample(
        from evidence: PoseSetupEvidence,
        phoneStable: Bool?
    ) -> SetupGateSignalSample {
        SetupGateSignalSample(
            fullBodyVisible: evidence.fullBodyVisible,
            sideViewLikely: evidence.sideViewLikely,
            phoneStable: phoneStable,
            poseConfidenceOK: evidence.poseConfidenceOK
        )
    }
}
