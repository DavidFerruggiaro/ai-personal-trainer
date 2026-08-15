import Foundation

public struct PoseEngineInfo: Codable, Equatable, Sendable {
    public var name: String
    public var version: String?
    public var config: [String: String]

    public init(name: String, version: String? = nil, config: [String: String] = [:]) {
        self.name = name
        self.version = version
        self.config = config
    }
}

public struct SourceVideoInfo: Codable, Equatable, Sendable {
    public var filename: String
    public var sha256: String?
    public var durationSeconds: Double?
    public var resolution: VideoResolution?
    public var nominalFPS: Double?

    private enum CodingKeys: String, CodingKey {
        case filename
        case sha256
        case durationSeconds = "duration_s"
        case resolution
        case nominalFPS = "fps_nominal"
    }

    public init(
        filename: String,
        sha256: String? = nil,
        durationSeconds: Double? = nil,
        width: Int? = nil,
        height: Int? = nil,
        nominalFPS: Double? = nil
    ) {
        self.filename = filename
        self.sha256 = sha256
        self.durationSeconds = durationSeconds
        if let width, let height {
            self.resolution = VideoResolution(width: width, height: height)
        } else {
            self.resolution = nil
        }
        self.nominalFPS = nominalFPS
    }
}

public struct VideoResolution: Codable, Equatable, Sendable {
    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct PoseRunSummary: Codable, Equatable, Sendable {
    public var framesProcessed: Int
    public var effectiveFPS: Double?
    public var droppedOrUnprocessedFrames: Int?

    private enum CodingKeys: String, CodingKey {
        case framesProcessed = "frames_processed"
        case effectiveFPS = "effective_fps"
        case droppedOrUnprocessedFrames = "dropped_or_unprocessed_frames"
    }

    public init(
        framesProcessed: Int,
        effectiveFPS: Double? = nil,
        droppedOrUnprocessedFrames: Int? = nil
    ) {
        self.framesProcessed = framesProcessed
        self.effectiveFPS = effectiveFPS
        self.droppedOrUnprocessedFrames = droppedOrUnprocessedFrames
    }
}

public struct PoseRunExport: Codable, Equatable, Sendable {
    public var runID: UUID
    public var createdAt: Date
    public var appVersion: String
    public var engine: PoseEngineInfo
    public var sourceVideo: SourceVideoInfo
    public var frames: [PoseFrame]
    public var summary: PoseRunSummary

    private enum CodingKeys: String, CodingKey {
        case runID = "run_id"
        case createdAt = "created_at"
        case appVersion = "app_version"
        case engine
        case sourceVideo = "source_video"
        case frames
        case summary
    }

    public init(
        runID: UUID = UUID(),
        createdAt: Date = Date(),
        appVersion: String,
        engine: PoseEngineInfo,
        sourceVideo: SourceVideoInfo,
        frames: [PoseFrame],
        summary: PoseRunSummary
    ) {
        self.runID = runID
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.engine = engine
        self.sourceVideo = sourceVideo
        self.frames = frames
        self.summary = summary
    }

    public static func makeJSONEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
