import AppKit
import AVFoundation
import Foundation

struct RunResult: Codable {
    let videos: [VideoResult]
}

struct VideoResult: Codable {
    let input: String
    let filename: String
    let duration_s: Double
    let frames: [FrameResult]
}

struct FrameResult: Codable {
    let timestamp_s: Double
    let landmarks: [LandmarkResult]
    let frame_confidence: Double?
}

struct LandmarkResult: Codable {
    let name: String
    let x: Double
    let y: Double
    let confidence: Double
}

let jsonURL = URL(fileURLWithPath: "docs/bakeoff_results/2026-05-24_apple_vision_smoke/apple_vision_smoke_results.json")
let outputURL = URL(fileURLWithPath: "docs/bakeoff_results/2026-05-24_apple_vision_smoke/apple_vision_contact_sheet.png")
let result = try JSONDecoder().decode(RunResult.self, from: Data(contentsOf: jsonURL))

let cellWidth: CGFloat = 260
let cellHeight: CGFloat = 520
let headerHeight: CGFloat = 54
let labelHeight: CGFloat = 48
let columns = 4
let rows = result.videos.count
let sheetSize = CGSize(
    width: cellWidth * CGFloat(columns),
    height: cellHeight * CGFloat(rows)
)

let image = NSImage(size: sheetSize)
image.lockFocus()
NSColor.white.setFill()
NSBezierPath(rect: CGRect(origin: .zero, size: sheetSize)).fill()

for (rowIndex, video) in result.videos.enumerated() {
    let yBase = CGFloat(rowIndex) * cellHeight
    let timestamps = [0.20, 0.40, 0.60, 0.80].map { video.duration_s * $0 }

    for (columnIndex, timestamp) in timestamps.enumerated() {
        let xBase = CGFloat(columnIndex) * cellWidth
        let targetFrame = nearestFrame(to: timestamp, in: video.frames)
        let frameImage = try loadImage(videoPath: video.input, timestamp: targetFrame.timestamp_s)
        let imageRect = fit(
            CGSize(width: frameImage.width, height: frameImage.height),
            in: CGRect(
                x: xBase + 12,
                y: yBase + labelHeight,
                width: cellWidth - 24,
                height: cellHeight - headerHeight - labelHeight
            )
        )

        NSGraphicsContext.current?.cgContext.draw(frameImage, in: imageRect)
        drawOverlay(frame: targetFrame, in: imageRect)
        drawLabel(video: video, frame: targetFrame, rect: CGRect(x: xBase + 12, y: yBase + 8, width: cellWidth - 24, height: labelHeight - 10))
    }
}

image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "RenderVisionContactSheet", code: 1)
}

try pngData.write(to: outputURL, options: [.atomic])
print("Wrote \(outputURL.path)")

func nearestFrame(to timestamp: Double, in frames: [FrameResult]) -> FrameResult {
    frames.min { left, right in
        abs(left.timestamp_s - timestamp) < abs(right.timestamp_s - timestamp)
    } ?? FrameResult(timestamp_s: timestamp, landmarks: [], frame_confidence: nil)
}

func loadImage(videoPath: String, timestamp: Double) throws -> CGImage {
    let asset = AVURLAsset(url: URL(fileURLWithPath: videoPath))
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 1080, height: 1080)
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    return try generator.copyCGImage(
        at: CMTime(seconds: timestamp, preferredTimescale: 600),
        actualTime: nil
    )
}

func fit(_ imageSize: CGSize, in rect: CGRect) -> CGRect {
    let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
    let width = imageSize.width * scale
    let height = imageSize.height * scale
    return CGRect(
        x: rect.midX - width / 2,
        y: rect.midY - height / 2,
        width: width,
        height: height
    )
}

func drawOverlay(frame: FrameResult, in rect: CGRect) {
    let context = NSGraphicsContext.current!.cgContext
    let landmarks = Dictionary(uniqueKeysWithValues: frame.landmarks.map { ($0.name, $0) })
    let connections = [
        ("left_shoulder", "right_shoulder"),
        ("left_shoulder", "left_hip"),
        ("right_shoulder", "right_hip"),
        ("left_hip", "right_hip"),
        ("left_hip", "left_knee"),
        ("left_knee", "left_ankle"),
        ("right_hip", "right_knee"),
        ("right_knee", "right_ankle"),
        ("neck", "left_shoulder"),
        ("neck", "right_shoulder"),
        ("mid_hip", "left_hip"),
        ("mid_hip", "right_hip")
    ]

    context.setLineCap(.round)

    for (startName, endName) in connections {
        guard let start = landmarks[startName], let end = landmarks[endName] else {
            continue
        }

        let confidence = min(start.confidence, end.confidence)
        context.setStrokeColor(NSColor.systemCyan.withAlphaComponent(confidence >= 0.30 ? 0.95 : 0.30).cgColor)
        context.setLineWidth(confidence >= 0.30 ? 3 : 1.5)
        context.move(to: point(for: start, in: rect))
        context.addLine(to: point(for: end, in: rect))
        context.strokePath()
    }

    for landmark in frame.landmarks {
        let center = point(for: landmark, in: rect)
        let radius: CGFloat = landmark.confidence >= 0.30 ? 4 : 2.5
        let dot = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.setFillColor((landmark.confidence >= 0.30 ? NSColor.systemYellow : NSColor.systemOrange.withAlphaComponent(0.45)).cgColor)
        context.fillEllipse(in: dot)
    }
}

func point(for landmark: LandmarkResult, in rect: CGRect) -> CGPoint {
    CGPoint(
        x: rect.minX + CGFloat(landmark.x) * rect.width,
        y: rect.minY + CGFloat(landmark.y) * rect.height
    )
}

func drawLabel(video: VideoResult, frame: FrameResult, rect: CGRect) {
    let confidence = frame.frame_confidence.map { String(format: "%.2f", $0) } ?? "n/a"
    let text = "\(video.filename)\n\(String(format: "%.1fs", frame.timestamp_s))  conf \(confidence)  lower \(lowerBodyStatus(frame))"
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineBreakMode = .byTruncatingMiddle
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 10, weight: .medium),
        .foregroundColor: NSColor.black,
        .paragraphStyle: paragraph
    ]
    text.draw(in: rect, withAttributes: attributes)
}

func lowerBodyStatus(_ frame: FrameResult) -> String {
    sideComplete(frame, prefix: "left") || sideComplete(frame, prefix: "right") ? "ok" : "miss"
}

func sideComplete(_ frame: FrameResult, prefix: String) -> Bool {
    let names = Set(frame.landmarks.filter { $0.confidence >= 0.30 }.map(\.name))
    return names.contains("\(prefix)_hip") && names.contains("\(prefix)_knee") && names.contains("\(prefix)_ankle")
}
