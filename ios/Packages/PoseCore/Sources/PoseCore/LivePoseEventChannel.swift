import Foundation

public final class LivePoseEventChannel: LivePoseEventDelivering, @unchecked Sendable {
    public let events: AsyncStream<LivePoseEvent>
    public let deliveryQueue: DispatchQueue

    private let eventContinuation: AsyncStream<LivePoseEvent>.Continuation
    private let lifecycleLock = NSLock()
    private var nextObservationSequence: UInt64 = 1
    private var mostRecentEmittedObservationSequence: UInt64?
    private var eventDeliveryDropHandler: (@Sendable (UInt64) -> Void)?
    private var eventDeliveryDropCountStorage: UInt64 = 0
    private var eventDeliveryDropNotificationPending = false

    public init(
        bufferingNewest: Int = 120,
        deliveryQueue: DispatchQueue = DispatchQueue(label: "PoseCore.livePose.delivery")
    ) {
        let stream = AsyncStream.makeStream(
            of: LivePoseEvent.self,
            bufferingPolicy: .bufferingNewest(bufferingNewest)
        )
        events = stream.stream
        eventContinuation = stream.continuation
        self.deliveryQueue = deliveryQueue
    }

    deinit {
        eventContinuation.finish()
    }

    public var deliveryBaseline: LivePoseDeliveryBaseline {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return LivePoseDeliveryBaseline(
            latestObservationSequence: mostRecentEmittedObservationSequence,
            eventDeliveryDropCount: eventDeliveryDropCountStorage
        )
    }

    public var eventDeliveryDropCount: UInt64 {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return eventDeliveryDropCountStorage
    }

    public func setEventDeliveryDropHandler(
        _ handler: @escaping @Sendable (UInt64) -> Void
    ) {
        lifecycleLock.lock()
        eventDeliveryDropHandler = handler
        lifecycleLock.unlock()
    }

    public func completeEventDeliveryDropNotification(through deliveredCount: UInt64) {
        lifecycleLock.lock()
        let shouldRenotify = eventDeliveryDropCountStorage > deliveredCount
        let nextCount = eventDeliveryDropCountStorage
        let handler = shouldRenotify ? eventDeliveryDropHandler : nil
        if !shouldRenotify {
            eventDeliveryDropNotificationPending = false
        }
        lifecycleLock.unlock()
        if let handler {
            handler(nextCount)
        }
    }

    public func enqueueDeliveryBoundary(_ id: UUID) {
        deliveryQueue.async { [weak self] in
            self?.emit(.deliveryBoundary(id))
        }
    }

    public func nextSourceSequence() -> UInt64 {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        let sequence = nextObservationSequence
        nextObservationSequence &+= 1
        mostRecentEmittedObservationSequence = sequence
        return sequence
    }

    public func emit(_ event: LivePoseEvent) {
        switch eventContinuation.yield(event) {
        case .enqueued, .terminated:
            break
        case .dropped:
            lifecycleLock.lock()
            eventDeliveryDropCountStorage &+= 1
            let shouldNotify = !eventDeliveryDropNotificationPending
                && eventDeliveryDropHandler != nil
            if shouldNotify {
                eventDeliveryDropNotificationPending = true
            }
            let droppedCount = eventDeliveryDropCountStorage
            let handler = shouldNotify ? eventDeliveryDropHandler : nil
            lifecycleLock.unlock()
            handler?(droppedCount)
        @unknown default:
            break
        }
    }

    func runOnDeliveryQueue(_ work: @escaping () -> Void) async {
        await withCheckedContinuation { continuation in
            deliveryQueue.async {
                work()
                continuation.resume()
            }
        }
    }
}
