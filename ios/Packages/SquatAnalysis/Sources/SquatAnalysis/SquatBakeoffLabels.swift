import Foundation

public enum SquatFailureReason: String, Codable, CaseIterable, Sendable {
    case depth
    case lockout
    case kneeTracking = "knee_tracking"
    case torsoAngle = "torso_angle"
    case tempoControl = "tempo_control"
    case captureConfidence = "capture_confidence"
    case unknown
}

public struct SquatLabelSourceVideo: Codable, Equatable, Sendable {
    public var filename: String
    public var localPath: String?

    private enum CodingKeys: String, CodingKey {
        case filename
        case localPath = "local_path"
    }

    public init(filename: String, localPath: String? = nil) {
        self.filename = filename
        self.localPath = localPath
    }
}

public struct SquatRepLabel: Codable, Equatable, Sendable {
    public var index: Int?
    public var startSeconds: Double
    public var bottomSeconds: Double
    public var endSeconds: Double
    public var counted: Bool
    public var clean: Bool
    public var failures: [SquatFailureReason]

    private enum CodingKeys: String, CodingKey {
        case index
        case startSeconds = "start_s"
        case bottomSeconds = "bottom_s"
        case endSeconds = "end_s"
        case counted
        case clean
        case failures
    }

    public init(
        index: Int? = nil,
        startSeconds: Double,
        bottomSeconds: Double,
        endSeconds: Double,
        counted: Bool,
        clean: Bool,
        failures: [SquatFailureReason] = []
    ) {
        self.index = index
        self.startSeconds = startSeconds
        self.bottomSeconds = bottomSeconds
        self.endSeconds = endSeconds
        self.counted = counted
        self.clean = clean
        self.failures = failures
    }
}

public struct SquatClipLabels: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var clipID: String
    public var sourceVideo: SquatLabelSourceVideo
    public var exercise: String
    public var cameraAngle: String
    public var loadLbs: Double?
    public var conditions: [String]
    public var confidenceShouldBeLow: Bool
    public var labelingNotes: [String]
    public var reps: [SquatRepLabel]

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case clipID = "clip_id"
        case sourceVideo = "source_video"
        case exercise
        case cameraAngle = "camera_angle"
        case loadLbs = "load_lbs"
        case conditions
        case confidenceShouldBeLow = "confidence_should_be_low"
        case labelingNotes = "labeling_notes"
        case reps
    }

    public init(
        schemaVersion: Int = 1,
        clipID: String,
        sourceVideo: SquatLabelSourceVideo,
        exercise: String,
        cameraAngle: String,
        loadLbs: Double? = nil,
        conditions: [String] = [],
        confidenceShouldBeLow: Bool = false,
        labelingNotes: [String] = [],
        reps: [SquatRepLabel]
    ) {
        self.schemaVersion = schemaVersion
        self.clipID = clipID
        self.sourceVideo = sourceVideo
        self.exercise = exercise
        self.cameraAngle = cameraAngle
        self.loadLbs = loadLbs
        self.conditions = conditions
        self.confidenceShouldBeLow = confidenceShouldBeLow
        self.labelingNotes = labelingNotes
        self.reps = reps
    }
}

public enum SquatLabelLoader {
    public static func load(from url: URL) throws -> SquatClipLabels {
        let data = try Data(contentsOf: url)
        return try makeJSONDecoder().decode(SquatClipLabels.self, from: data)
    }

    public static func makeJSONDecoder() -> JSONDecoder {
        JSONDecoder()
    }
}
