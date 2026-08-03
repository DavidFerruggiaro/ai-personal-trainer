import UIKit

@MainActor
final class TrainerSessionCues {
    func countdownTick(_ remainingSeconds: Int) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle =
            remainingSeconds <= 3 ? .medium : .light
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func recordingStarted() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func stop() {}
}
