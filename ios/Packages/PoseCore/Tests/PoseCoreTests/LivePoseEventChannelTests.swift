import Foundation
import Testing
@testable import PoseCore

struct LivePoseEventChannelTests {
    @Test func deliveryBaselineSnapshotsSequenceAndDropCountTogether() async {
        let channel = LivePoseEventChannel(bufferingNewest: 8)
        await channel.runOnDeliveryQueue {
            for _ in 0..<3 {
                emitObservation(on: channel)
            }
        }

        let baseline = channel.deliveryBaseline
        #expect(baseline.latestObservationSequence == 3)
        #expect(baseline.eventDeliveryDropCount == 0)
    }

    @Test func bufferingNewestDropsIncrementTheDeliveryLossCount() async {
        let channel = LivePoseEventChannel(bufferingNewest: 120)
        await channel.runOnDeliveryQueue {
            for _ in 0..<121 {
                channel.emit(.captureDropped)
            }
        }

        #expect(channel.eventDeliveryDropCount >= 1)
        #expect(channel.deliveryBaseline.eventDeliveryDropCount == channel.eventDeliveryDropCount)
    }

    @Test func dropNotificationsAreCoalescedAndRenotifyLeftoverLoss() async {
        let channel = LivePoseEventChannel(bufferingNewest: 1)
        let notifications = DropNotificationBox()
        channel.setEventDeliveryDropHandler { count in
            notifications.record(count)
        }

        await channel.runOnDeliveryQueue {
            channel.emit(.captureDropped)
            channel.emit(.captureDropped)
            channel.emit(.captureDropped)
        }

        #expect(notifications.counts == [1])
        #expect(channel.eventDeliveryDropCount == 2)

        channel.completeEventDeliveryDropNotification(through: 1)
        #expect(notifications.counts == [1, 2])

        channel.completeEventDeliveryDropNotification(through: 2)
        #expect(notifications.counts == [1, 2])
    }

    @Test func queuedDeliveryBoundaryStaysBehindEarlierEmitsOnTheSameQueue() async {
        let channel = LivePoseEventChannel(bufferingNewest: 120)
        let boundaryID = UUID()
        var collected: [LivePoseEvent] = []

        await channel.runOnDeliveryQueue {
            emitObservation(on: channel, timestamp: 1)
            emitObservation(on: channel, timestamp: 2)
        }
        channel.enqueueDeliveryBoundary(boundaryID)
        await channel.runOnDeliveryQueue {
            emitObservation(on: channel, timestamp: 3)
        }

        for await event in channel.events {
            collected.append(event)
            if collected.count == 4 {
                break
            }
        }

        guard collected.count == 4 else {
            Issue.record("Expected four queued events before the consumer drained.")
            return
        }
        #expect(isObservation(collected[0], timestamp: 1))
        #expect(isObservation(collected[1], timestamp: 2))
        #expect(collected[2] == .deliveryBoundary(boundaryID))
        #expect(isObservation(collected[3], timestamp: 3))
    }
}

private final class DropNotificationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [UInt64] = []

    var counts: [UInt64] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    func record(_ count: UInt64) {
        lock.lock()
        recorded.append(count)
        lock.unlock()
    }
}

private func emitObservation(
    on channel: LivePoseEventChannel,
    timestamp: Double = 0
) {
    let sequence = channel.nextSourceSequence()
    channel.emit(.observation(LivePoseObservation(
        frame: PoseFrame(timestampSeconds: timestamp, landmarks: [], frameConfidence: nil),
        inferenceLatencyMilliseconds: 1,
        sourceSequenceNumber: sequence
    )))
}

private func isObservation(_ event: LivePoseEvent, timestamp: Double) -> Bool {
    guard case let .observation(observation) = event else {
        return false
    }
    return observation.frame.timestampSeconds == timestamp
}
