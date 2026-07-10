import Foundation
import PoseCore

public struct SquatRepEvent: Codable, Equatable, Sendable {
    public var index: Int
    public var startSeconds: Double
    public var bottomSeconds: Double
    public var endSeconds: Double
    public var counted: Bool
    public var clean: Bool
    public var failures: [SquatFailureReason]
    public var confidence: Double?

    private enum CodingKeys: String, CodingKey {
        case index
        case startSeconds = "start_s"
        case bottomSeconds = "bottom_s"
        case endSeconds = "end_s"
        case counted
        case clean
        case failures
        case confidence
    }

    public init(
        index: Int,
        startSeconds: Double,
        bottomSeconds: Double,
        endSeconds: Double,
        counted: Bool = true,
        clean: Bool = true,
        failures: [SquatFailureReason] = [],
        confidence: Double? = nil
    ) {
        self.index = index
        self.startSeconds = startSeconds
        self.bottomSeconds = bottomSeconds
        self.endSeconds = endSeconds
        self.counted = counted
        self.clean = clean
        self.failures = failures
        self.confidence = confidence
    }
}

public struct SquatRepMatch: Codable, Equatable, Sendable {
    public var labelIndex: Int?
    public var predictedIndex: Int?
    public var bottomErrorSeconds: Double?
    public var startErrorSeconds: Double?
    public var endErrorSeconds: Double?
    public var countedAgrees: Bool?
    public var cleanAgrees: Bool?
    public var failureAgrees: Bool?

    private enum CodingKeys: String, CodingKey {
        case labelIndex = "label_index"
        case predictedIndex = "predicted_index"
        case bottomErrorSeconds = "bottom_error_s"
        case startErrorSeconds = "start_error_s"
        case endErrorSeconds = "end_error_s"
        case countedAgrees = "counted_agrees"
        case cleanAgrees = "clean_agrees"
        case failureAgrees = "failure_agrees"
    }
}

public struct SquatBakeoffScore: Codable, Equatable, Sendable {
    public var expectedReps: Int
    public var predictedReps: Int
    public var matchedReps: Int
    public var missedReps: Int
    public var phantomReps: Int
    public var countedAgreement: Double?
    public var cleanAgreement: Double?
    public var failureAgreement: Double?
    public var bottomMeanAbsoluteErrorSeconds: Double?
    public var bottomWithinTolerance: Int
    public var matches: [SquatRepMatch]

    private enum CodingKeys: String, CodingKey {
        case expectedReps = "expected_reps"
        case predictedReps = "predicted_reps"
        case matchedReps = "matched_reps"
        case missedReps = "missed_reps"
        case phantomReps = "phantom_reps"
        case countedAgreement = "counted_agreement"
        case cleanAgreement = "clean_agreement"
        case failureAgreement = "failure_agreement"
        case bottomMeanAbsoluteErrorSeconds = "bottom_mean_absolute_error_s"
        case bottomWithinTolerance = "bottom_within_tolerance"
        case matches
    }
}

public struct SquatBakeoffScoringConfiguration: Equatable, Sendable {
    public var eventToleranceSeconds: Double

    public init(eventToleranceSeconds: Double = 0.5) {
        self.eventToleranceSeconds = eventToleranceSeconds
    }
}

public struct SquatBakeoffScorer: Sendable {
    public var configuration: SquatBakeoffScoringConfiguration

    public init(configuration: SquatBakeoffScoringConfiguration = SquatBakeoffScoringConfiguration()) {
        self.configuration = configuration
    }

    public func score(labels: SquatClipLabels, predictions: [SquatRepEvent]) -> SquatBakeoffScore {
        var unmatchedPredictionIndices = Set(predictions.indices)
        var matches: [SquatRepMatch] = []
        var matchedBottomErrors: [Double] = []
        var countedAgreements = 0
        var cleanAgreements = 0
        var failureAgreements = 0

        for label in labels.reps {
            let bestPredictionIndex = unmatchedPredictionIndices.min { lhs, rhs in
                abs(predictions[lhs].bottomSeconds - label.bottomSeconds) <
                    abs(predictions[rhs].bottomSeconds - label.bottomSeconds)
            }

            guard
                let predictionIndex = bestPredictionIndex,
                abs(predictions[predictionIndex].bottomSeconds - label.bottomSeconds) <= configuration.eventToleranceSeconds
            else {
                matches.append(SquatRepMatch(
                    labelIndex: label.index,
                    predictedIndex: nil,
                    bottomErrorSeconds: nil,
                    startErrorSeconds: nil,
                    endErrorSeconds: nil,
                    countedAgrees: nil,
                    cleanAgrees: nil,
                    failureAgrees: nil
                ))
                continue
            }

            unmatchedPredictionIndices.remove(predictionIndex)
            let prediction = predictions[predictionIndex]
            let bottomError = prediction.bottomSeconds - label.bottomSeconds
            let startError = prediction.startSeconds - label.startSeconds
            let endError = prediction.endSeconds - label.endSeconds
            let countedAgrees = prediction.counted == label.counted
            let cleanAgrees = prediction.clean == label.clean
            let failureAgrees = Set(prediction.failures) == Set(label.failures)

            if countedAgrees { countedAgreements += 1 }
            if cleanAgrees { cleanAgreements += 1 }
            if failureAgrees { failureAgreements += 1 }
            matchedBottomErrors.append(abs(bottomError))

            matches.append(SquatRepMatch(
                labelIndex: label.index,
                predictedIndex: prediction.index,
                bottomErrorSeconds: bottomError,
                startErrorSeconds: startError,
                endErrorSeconds: endError,
                countedAgrees: countedAgrees,
                cleanAgrees: cleanAgrees,
                failureAgrees: failureAgrees
            ))
        }

        for predictionIndex in unmatchedPredictionIndices.sorted() {
            matches.append(SquatRepMatch(
                labelIndex: nil,
                predictedIndex: predictions[predictionIndex].index,
                bottomErrorSeconds: nil,
                startErrorSeconds: nil,
                endErrorSeconds: nil,
                countedAgrees: nil,
                cleanAgrees: nil,
                failureAgrees: nil
            ))
        }

        let matchedReps = matchedBottomErrors.count
        let denominator = matchedReps == 0 ? nil : Double(matchedReps)

        return SquatBakeoffScore(
            expectedReps: labels.reps.count,
            predictedReps: predictions.count,
            matchedReps: matchedReps,
            missedReps: labels.reps.count - matchedReps,
            phantomReps: unmatchedPredictionIndices.count,
            countedAgreement: denominator.map { Double(countedAgreements) / $0 },
            cleanAgreement: denominator.map { Double(cleanAgreements) / $0 },
            failureAgreement: denominator.map { Double(failureAgreements) / $0 },
            bottomMeanAbsoluteErrorSeconds: matchedBottomErrors.isEmpty
                ? nil
                : matchedBottomErrors.reduce(0, +) / Double(matchedBottomErrors.count),
            bottomWithinTolerance: matchedBottomErrors.filter { $0 <= configuration.eventToleranceSeconds }.count,
            matches: matches
        )
    }
}

public struct SquatRepDetectorConfiguration: Equatable, Sendable {
    public var minimumLandmarkConfidence: Double
    public var maximumNormalizedHipY: Double
    public var minimumDescentDelta: Double
    public var bottomThresholdFraction: Double
    public var standingThresholdDelta: Double
    public var minimumRepDurationSeconds: Double

    public init(
        minimumLandmarkConfidence: Double = 0.25,
        maximumNormalizedHipY: Double = 1.0,
        minimumDescentDelta: Double = 0.08,
        bottomThresholdFraction: Double = 0.45,
        standingThresholdDelta: Double = 0.03,
        minimumRepDurationSeconds: Double = 0.75
    ) {
        self.minimumLandmarkConfidence = minimumLandmarkConfidence
        self.maximumNormalizedHipY = maximumNormalizedHipY
        self.minimumDescentDelta = minimumDescentDelta
        self.bottomThresholdFraction = bottomThresholdFraction
        self.standingThresholdDelta = standingThresholdDelta
        self.minimumRepDurationSeconds = minimumRepDurationSeconds
    }
}

public struct SquatRepDetector: Sendable {
    public var configuration: SquatRepDetectorConfiguration

    public init(configuration: SquatRepDetectorConfiguration = SquatRepDetectorConfiguration()) {
        self.configuration = configuration
    }

    public func detectReps(frames: [PoseFrame]) -> [SquatRepEvent] {
        let samples = hipSamples(from: frames)
        guard samples.count >= 3 else {
            return []
        }

        let smoothedSamples = smooth(samples)
        let hipValues = smoothedSamples.map(\.hipY).sorted()
        let standingY = percentile(hipValues, percentile: 0.20)
        guard let maxY = hipValues.max() else {
            return []
        }

        let bottomThreshold = standingY + max(configuration.minimumDescentDelta, (maxY - standingY) * configuration.bottomThresholdFraction)
        let standingThreshold = standingY + configuration.standingThresholdDelta

        var events: [SquatRepEvent] = []
        var index = 0
        while index < smoothedSamples.count {
            guard smoothedSamples[index].hipY >= bottomThreshold else {
                index += 1
                continue
            }

            let segmentStart = index
            while index + 1 < smoothedSamples.count, smoothedSamples[index + 1].hipY >= bottomThreshold {
                index += 1
            }
            let segmentEnd = index

            let bottomSample = smoothedSamples[segmentStart...segmentEnd].max { lhs, rhs in
                lhs.hipY < rhs.hipY
            }!

            var startIndex = segmentStart
            while startIndex > 0, smoothedSamples[startIndex].hipY > standingThreshold {
                startIndex -= 1
            }

            var endIndex = segmentEnd
            while endIndex + 1 < smoothedSamples.count, smoothedSamples[endIndex].hipY > standingThreshold {
                endIndex += 1
            }

            let startSample = smoothedSamples[startIndex]
            let endSample = smoothedSamples[endIndex]
            let duration = endSample.timestampSeconds - startSample.timestampSeconds

            if duration >= configuration.minimumRepDurationSeconds {
                let failures = inferredFailures(
                    startHipY: startSample.hipY,
                    bottomHipY: bottomSample.hipY,
                    endHipY: endSample.hipY,
                    durationSeconds: duration
                )
                events.append(SquatRepEvent(
                    index: events.count + 1,
                    startSeconds: startSample.timestampSeconds,
                    bottomSeconds: bottomSample.timestampSeconds,
                    endSeconds: endSample.timestampSeconds,
                    counted: true,
                    clean: failures.isEmpty,
                    failures: failures,
                    confidence: bottomSample.confidence
                ))
            }

            index = max(segmentEnd + 1, index + 1)
        }

        return events
    }

    private func inferredFailures(
        startHipY: Double,
        bottomHipY: Double,
        endHipY: Double,
        durationSeconds: Double
    ) -> [SquatFailureReason] {
        var failures: [SquatFailureReason] = []
        if bottomHipY - min(startHipY, endHipY) < configuration.minimumDescentDelta {
            failures.append(.depth)
        }
        if endHipY - startHipY > configuration.standingThresholdDelta * 2 {
            failures.append(.lockout)
        }
        if durationSeconds < configuration.minimumRepDurationSeconds {
            failures.append(.tempoControl)
        }
        return failures
    }

    private func hipSamples(from frames: [PoseFrame]) -> [HipSample] {
        frames.compactMap { frame in
            var landmarks: [PoseLandmarkName: PoseLandmark] = [:]
            for landmark in frame.landmarks {
                if landmarks[landmark.name, default: landmark].confidence <= landmark.confidence {
                    landmarks[landmark.name] = landmark
                }
            }
            let candidates = [PoseLandmarkName.midHip, .leftHip, .rightHip].compactMap { name -> PoseLandmark? in
                guard let landmark = landmarks[name], landmark.confidence >= configuration.minimumLandmarkConfidence else {
                    return nil
                }
                return landmark
            }

            guard !candidates.isEmpty else {
                return nil
            }

            let hipY = candidates.map(\.y).reduce(0, +) / Double(candidates.count)
            guard hipY <= configuration.maximumNormalizedHipY else {
                return nil
            }
            let confidence = candidates.map(\.confidence).reduce(0, +) / Double(candidates.count)
            return HipSample(timestampSeconds: frame.timestampSeconds, hipY: hipY, confidence: confidence)
        }
    }

    private func smooth(_ samples: [HipSample]) -> [HipSample] {
        samples.indices.map { index in
            let lowerBound = max(0, index - 1)
            let upperBound = min(samples.count - 1, index + 1)
            let window = samples[lowerBound...upperBound]
            return HipSample(
                timestampSeconds: samples[index].timestampSeconds,
                hipY: window.map(\.hipY).reduce(0, +) / Double(window.count),
                confidence: window.map(\.confidence).reduce(0, +) / Double(window.count)
            )
        }
    }

    private func percentile(_ sortedValues: [Double], percentile: Double) -> Double {
        guard let first = sortedValues.first else {
            return 0
        }
        guard sortedValues.count > 1 else {
            return first
        }
        let position = percentile * Double(sortedValues.count - 1)
        let lowerIndex = Int(position.rounded(.down))
        let upperIndex = Int(position.rounded(.up))
        if lowerIndex == upperIndex {
            return sortedValues[lowerIndex]
        }
        let fraction = position - Double(lowerIndex)
        return sortedValues[lowerIndex] + (sortedValues[upperIndex] - sortedValues[lowerIndex]) * fraction
    }
}

private struct HipSample: Equatable {
    var timestampSeconds: Double
    var hipY: Double
    var confidence: Double
}
