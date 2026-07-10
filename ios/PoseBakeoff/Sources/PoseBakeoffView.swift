import AVFoundation
import AVKit
import CoreTransferable
import PhotosUI
import PoseCore
import SwiftUI
import UniformTypeIdentifiers

struct PoseBakeoffView: View {
    @State private var selectedVideoURL: URL?
    @State private var selectedVideoAspectRatio: CGFloat = 16 / 9
    @State private var activeSecurityScopedURL: URL?
    @State private var importErrorMessage: String?
    @State private var isShowingVideoImporter = false
    @State private var isAnalyzing = false
    @State private var analysisStatusMessage: String?
    @State private var exportURL: URL?
    @State private var videoPlayer: AVPlayer?
    @State private var analyzedFrames: [PoseFrame] = []
    @State private var currentPlaybackSeconds: Double = 0
    @State private var selectedPhotosItem: PhotosPickerItem?

    private let playbackTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("PoseBakeoff")
                        .font(.largeTitle.bold())

                    Text("Day-one goal: pick a prerecorded squat video, run a pose estimator, inspect the overlay, and export normalized JSON.")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Selected Video")
                            .font(.headline)

                        if let selectedVideoURL {
                            Text(selectedVideoURL.lastPathComponent)
                                .font(.body.monospaced())
                                .lineLimit(2)
                        } else {
                            Text("None")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let videoPlayer {
                        ZStack {
                            VideoPlayer(player: videoPlayer)

                            if let overlayFrame {
                                PoseOverlayView(frame: overlayFrame)
                                    .allowsHitTesting(false)
                            }
                        }
                            .aspectRatio(selectedVideoAspectRatio, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.secondary.opacity(0.25))
                            }
                            .onReceive(playbackTimer) { _ in
                                currentPlaybackSeconds = CMTimeGetSeconds(videoPlayer.currentTime())
                            }
                    }

                    if let importErrorMessage {
                        Text(importErrorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                    }

                    if let analysisStatusMessage {
                        Text(analysisStatusMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("Share JSON Export", systemImage: "square.and.arrow.up")
                        }
                    }

                    HStack {
                        PhotosPicker(
                            selection: $selectedPhotosItem,
                            matching: .videos,
                            photoLibrary: .shared()
                        ) {
                            Label("Photos", systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            importErrorMessage = nil
                            analysisStatusMessage = nil
                            exportURL = nil
                            isShowingVideoImporter = true
                        } label: {
                            Label("Files", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack {
                        Button("Run MediaPipe") {
                            Task {
                                await runEstimator(MediaPipePoseEstimator())
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedVideoURL == nil || isAnalyzing)

                        Button("Quick MediaPipe") {
                            Task {
                                await runEstimator(
                                    MediaPipePoseEstimator(
                                        sampleFPSLimit: 2,
                                        maxFrameDimension: 720
                                    )
                                )
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedVideoURL == nil || isAnalyzing)
                    }

                    HStack {
                        Button("Run Apple Vision") {
                            Task {
                                await runEstimator(AppleVisionPoseEstimator())
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedVideoURL == nil || isAnalyzing)
                    }

                    Divider()

                    LiveCameraViabilityView()
                }
                .padding()
            }
            .navigationTitle("Bakeoff")
            .fileImporter(
                isPresented: $isShowingVideoImporter,
                allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie],
                allowsMultipleSelection: false,
                onCompletion: handleVideoImport
            )
            .onChange(of: selectedPhotosItem) { _, newItem in
                guard let newItem else {
                    return
                }

                Task {
                    await handlePhotosImport(newItem)
                }
            }
        }
    }

    private func handleVideoImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                importErrorMessage = "No video selected."
                return
            }

            activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
            activeSecurityScopedURL = nil

            if url.startAccessingSecurityScopedResource() {
                activeSecurityScopedURL = url
            }

            selectedVideoURL = url
            selectedVideoAspectRatio = 16 / 9
            videoPlayer = AVPlayer(url: url)
            analyzedFrames = []
            currentPlaybackSeconds = 0
            analysisStatusMessage = nil
            exportURL = nil

            Task {
                await updateSelectedVideoAspectRatio(for: url)
            }
        case .failure(let error):
            importErrorMessage = "Could not select video: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func handlePhotosImport(_ item: PhotosPickerItem) async {
        importErrorMessage = nil
        analysisStatusMessage = "Loading video from Photos..."
        exportURL = nil

        do {
            guard let video = try await item.loadTransferable(type: PickedVideo.self) else {
                importErrorMessage = "Could not load selected Photos video."
                analysisStatusMessage = nil
                return
            }

            activeSecurityScopedURL?.stopAccessingSecurityScopedResource()
            activeSecurityScopedURL = nil
            selectedVideoURL = video.url
            selectedVideoAspectRatio = 16 / 9
            videoPlayer = AVPlayer(url: video.url)
            analyzedFrames = []
            currentPlaybackSeconds = 0
            analysisStatusMessage = nil

            await updateSelectedVideoAspectRatio(for: video.url)
        } catch {
            importErrorMessage = "Could not load Photos video: \(error.localizedDescription)"
            analysisStatusMessage = nil
        }
    }

    @MainActor
    private func runEstimator(_ estimator: any PoseEstimator) async {
        guard let selectedVideoURL else {
            return
        }

        isAnalyzing = true
        analysisStatusMessage = "Running \(displayName(for: estimator.engine))..."

        do {
            let startDate = Date()
            let frames = try await estimator.estimatePoseFrames(from: selectedVideoURL)
            let elapsedSeconds = Date().timeIntervalSince(startDate)
            analyzedFrames = frames
            let sourceVideo = try await loadSourceVideoInfo(from: selectedVideoURL)
            let export = PoseRunExport(
                appVersion: "PoseBakeoff 0.1",
                engine: estimator.engine,
                sourceVideo: sourceVideo,
                frames: frames,
                summary: PoseRunSummary(
                    framesProcessed: frames.count,
                    effectiveFPS: effectiveFPS(for: frames, sourceVideo: sourceVideo),
                    droppedOrUnprocessedFrames: frames.filter { $0.landmarks.isEmpty }.count
                )
            )
            exportURL = try writeExport(export, sourceVideoURL: selectedVideoURL)

            let framesWithPose = frames.filter { !$0.landmarks.isEmpty }.count
            analysisStatusMessage = "\(displayName(for: estimator.engine)) processed \(frames.count) frames in \(formatElapsed(elapsedSeconds)); pose found in \(framesWithPose). JSON export ready."
        } catch {
            analysisStatusMessage = "\(displayName(for: estimator.engine)) failed: \(error.localizedDescription)"
        }

        isAnalyzing = false
    }

    private var overlayFrame: PoseFrame? {
        guard !analyzedFrames.isEmpty else {
            return nil
        }

        return analyzedFrames.min { left, right in
            abs(left.timestampSeconds - currentPlaybackSeconds) < abs(right.timestampSeconds - currentPlaybackSeconds)
        }
    }

    private func loadSourceVideoInfo(from url: URL) async throws -> SourceVideoInfo {
        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = tracks.first
        let nominalFPS = try await track?.load(.nominalFrameRate)
        let naturalSize = try await track?.load(.naturalSize)

        return SourceVideoInfo(
            filename: url.lastPathComponent,
            durationSeconds: CMTimeGetSeconds(duration),
            width: naturalSize.map { Int($0.width) },
            height: naturalSize.map { Int($0.height) },
            nominalFPS: nominalFPS.map(Double.init)
        )
    }

    @MainActor
    private func updateSelectedVideoAspectRatio(for url: URL) async {
        do {
            let aspectRatio = try await loadDisplayAspectRatio(from: url)

            guard selectedVideoURL == url else {
                return
            }

            selectedVideoAspectRatio = aspectRatio
        } catch {
            selectedVideoAspectRatio = 16 / 9
        }
    }

    private func loadDisplayAspectRatio(from url: URL) async throws -> CGFloat {
        let asset = AVAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let track = tracks.first else {
            return 16 / 9
        }

        let naturalSize = try await track.load(.naturalSize)
        let preferredTransform = try await track.load(.preferredTransform)
        let displaySize = naturalSize.applying(preferredTransform)
        let width = abs(displaySize.width)
        let height = abs(displaySize.height)

        guard width > 0, height > 0 else {
            return 16 / 9
        }

        return width / height
    }

    private func effectiveFPS(for frames: [PoseFrame], sourceVideo: SourceVideoInfo) -> Double? {
        guard let durationSeconds = sourceVideo.durationSeconds, durationSeconds > 0 else {
            return nil
        }

        return Double(frames.count) / durationSeconds
    }

    private func writeExport(_ export: PoseRunExport, sourceVideoURL: URL) throws -> URL {
        let safeBaseName = sourceVideoURL
            .deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: " ", with: "_")
        let engineName = export.engine.name.replacingOccurrences(of: " ", with: "_")
        let outputDirectory = try exportDirectory()
        let outputURL = outputDirectory
            .appendingPathComponent("\(safeBaseName)_\(engineName)_pose.json")

        let data = try PoseRunExport.makeJSONEncoder().encode(export)
        try data.write(to: outputURL, options: [.atomic])

        return outputURL
    }

    private func exportDirectory() throws -> URL {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        let outputDirectory = documentsDirectory.appendingPathComponent(
            "PoseBakeoffExports",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        return outputDirectory
    }

    private func displayName(for engine: PoseEngineInfo) -> String {
        switch engine.name {
        case "apple_vision":
            return "Apple Vision"
        case "mediapipe_pose_landmarker":
            return "MediaPipe"
        default:
            return engine.name
        }
    }

    private func formatElapsed(_ seconds: TimeInterval) -> String {
        String(format: "%.1fs", seconds)
    }
}

private struct PickedVideo: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let pathExtension = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("photos_video_\(UUID().uuidString).\(pathExtension)")

            if FileManager.default.fileExists(atPath: outputURL.path) {
                try FileManager.default.removeItem(at: outputURL)
            }

            try FileManager.default.copyItem(at: received.file, to: outputURL)
            return PickedVideo(url: outputURL)
        }
    }
}

struct PoseOverlayView: View {
    let frame: PoseFrame

    private let connections: [(PoseLandmarkName, PoseLandmarkName)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle),
        (.neck, .leftShoulder),
        (.neck, .rightShoulder),
        (.midHip, .leftHip),
        (.midHip, .rightHip)
    ]

    var body: some View {
        Canvas { context, size in
            let landmarksByName = Dictionary(uniqueKeysWithValues: frame.landmarks.map { ($0.name, $0) })

            for (startName, endName) in connections {
                guard let start = landmarksByName[startName], let end = landmarksByName[endName] else {
                    continue
                }

                var path = Path()
                path.move(to: point(for: start, in: size))
                path.addLine(to: point(for: end, in: size))

                let confidence = min(start.confidence, end.confidence)
                context.stroke(
                    path,
                    with: .color(.cyan.opacity(confidence >= 0.35 ? 0.9 : 0.35)),
                    lineWidth: confidence >= 0.35 ? 3 : 2
                )
            }

            for landmark in frame.landmarks {
                let center = point(for: landmark, in: size)
                let radius = landmark.confidence >= 0.35 ? 4.5 : 3
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )

                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(landmark.confidence >= 0.35 ? .yellow : .orange.opacity(0.55))
                )
            }
        }
    }

    private func point(for landmark: PoseLandmark, in size: CGSize) -> CGPoint {
        CGPoint(
            x: CGFloat(landmark.x) * size.width,
            y: CGFloat(landmark.y) * size.height
        )
    }
}
