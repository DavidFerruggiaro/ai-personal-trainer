import Foundation
import PoseCore

public struct SquatAnalysisConfiguration: Equatable, Sendable {
    public var minimumFrameConfidence: Double

    public init(minimumFrameConfidence: Double = 0.5) {
        self.minimumFrameConfidence = minimumFrameConfidence
    }
}

public struct SquatAnalysisResult: Equatable, Sendable {
    public var framesAnalyzed: Int

    public init(framesAnalyzed: Int) {
        self.framesAnalyzed = framesAnalyzed
    }
}

public struct SquatAnalyzer: Sendable {
    public var configuration: SquatAnalysisConfiguration

    public init(configuration: SquatAnalysisConfiguration = SquatAnalysisConfiguration()) {
        self.configuration = configuration
    }

    public func analyze(frames: [PoseFrame]) -> SquatAnalysisResult {
        let usableFrames = frames.filter { frame in
            guard let confidence = frame.frameConfidence else {
                return true
            }
            return confidence >= configuration.minimumFrameConfidence
        }

        return SquatAnalysisResult(framesAnalyzed: usableFrames.count)
    }
}
