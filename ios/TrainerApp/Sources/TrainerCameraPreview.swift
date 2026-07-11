import AVFoundation
import PoseCore
import SwiftUI
import UIKit

struct TrainerCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.configure(session: session)
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.configure(session: session)
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        private var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        func configure(session: AVCaptureSession) {
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspect
            if let connection = previewLayer.connection,
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }
}

struct TrainerPoseOverlay: View {
    let frame: PoseFrame

    private let connections: [(PoseLandmarkName, PoseLandmarkName)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle)
    ]

    var body: some View {
        Canvas { context, size in
            let landmarks = Dictionary(uniqueKeysWithValues: frame.landmarks.map { ($0.name, $0) })
            for (startName, endName) in connections {
                guard let start = landmarks[startName], let end = landmarks[endName] else {
                    continue
                }
                var path = Path()
                path.move(to: point(start, in: size))
                path.addLine(to: point(end, in: size))
                context.stroke(path, with: .color(.cyan.opacity(0.85)), lineWidth: 3)
            }
            for landmark in frame.landmarks where landmark.confidence >= 0.35 {
                let center = point(landmark, in: size)
                let rect = CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: rect), with: .color(.yellow))
            }
        }
    }

    private func point(_ landmark: PoseLandmark, in size: CGSize) -> CGPoint {
        CGPoint(
            x: CGFloat(landmark.x) * size.width,
            y: CGFloat(landmark.y) * size.height
        )
    }
}
