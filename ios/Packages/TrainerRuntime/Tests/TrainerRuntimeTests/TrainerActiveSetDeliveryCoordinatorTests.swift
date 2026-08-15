import Foundation
import SquatAnalysis
import Testing
import TrainerCore
@testable import PoseCore
@testable import TrainerRuntime

final class EnqueueArmingSpy: LivePoseEventDelivering, @unchecked Sendable {
    let channel: LivePoseEventChannel
    private let lock = NSLock()
    private var onEnqueueHandler: ((UUID) -> Void)?
    private var holdNextBoundary = false
    private var heldBoundaryID: UUID?

    init(channel: LivePoseEventChannel) {
        self.channel = channel
    }

    var onEnqueue: ((UUID) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return onEnqueueHandler
        }
        set {
            lock.lock()
            onEnqueueHandler = newValue
            lock.unlock()
        }
    }

    var eventDeliveryDropCount: UInt64 {
        channel.eventDeliveryDropCount
    }

    func holdNextBoundaryRequest() {
        lock.lock()
        holdNextBoundary = true
        heldBoundaryID = nil
        lock.unlock()
    }

    func enqueueDeliveryBoundary(_ id: UUID) {
        let shouldHold: Bool
        lock.lock()
        shouldHold = holdNextBoundary
        if shouldHold {
            holdNextBoundary = false
            heldBoundaryID = id
        }
        let handler = onEnqueueHandler
        lock.unlock()

        if shouldHold {
            handler?(id)
            return
        }
        channel.enqueueDeliveryBoundary(id)
        handler?(id)
    }

    func forwardHeldBoundary() {
        let id: UUID?
        lock.lock()
        id = heldBoundaryID
        heldBoundaryID = nil
        lock.unlock()
        if let id {
            channel.enqueueDeliveryBoundary(id)
        }
    }
}

@MainActor
final class ConsumerGate {
    private var isPaused = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func pause() {
        isPaused = true
    }

    func resumeProcessing() {
        isPaused = false
        let waiters = self.waiters
        self.waiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    func waitIfPaused() async {
        while isPaused {
            await withCheckedContinuation { continuation in
                if isPaused {
                    waiters.append(continuation)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

@MainActor
final class DeliveryTestHarness {
    let channel: LivePoseEventChannel
    let spy: EnqueueArmingSpy
    let coordinator: TrainerActiveSetDeliveryCoordinator
    let gate = ConsumerGate()
    var onEvent: ((LivePoseEvent) -> Void)?
    private(set) var lastConsumptionEffect: TrainerLivePoseConsumptionEffect?
    private var consumer: Task<Void, Never>?

    init(pipeline: TrainerPoseObservationPipeline = TrainerPoseObservationPipeline()) {
        let channel = LivePoseEventChannel(bufferingNewest: 120)
        let spy = EnqueueArmingSpy(channel: channel)
        self.channel = channel
        self.spy = spy
        self.coordinator = TrainerActiveSetDeliveryCoordinator(
            source: spy,
            pipeline: pipeline
        )
    }

    func startConsumer(pauseAfterHandshake: Bool = false) async {
        consumer = Task { @MainActor in
            var iterator = channel.events.makeAsyncIterator()
            while !Task.isCancelled {
                await gate.waitIfPaused()
                guard let event = await iterator.next() else {
                    break
                }
                do {
                    lastConsumptionEffect = try coordinator.consume(event, phoneStable: true)
                } catch {
                    lastConsumptionEffect = TrainerLivePoseConsumptionEffect.none
                }
                onEvent?(event)
            }
        }

        await withCheckedContinuation { (started: CheckedContinuation<Void, Never>) in
            onEvent = { [self] event in
                if case .stateChanged(.running) = event {
                    if pauseAfterHandshake {
                        self.gate.pause()
                    }
                    self.onEvent = nil
                    started.resume()
                }
            }
            Task { @MainActor in
                await self.channel.runOnDeliveryQueue {
                    self.channel.emit(.stateChanged(.running))
                }
            }
        }
    }

    func stopConsumer() {
        consumer?.cancel()
        consumer = nil
        gate.resumeProcessing()
    }

    func emitObservations(
        timestamps: [Double],
        waitUntilObserved: Bool = false,
        pauseAfter: Bool = false
    ) async {
        guard waitUntilObserved || pauseAfter else {
            await emitObservationsOnDeliveryQueue(timestamps)
            return
        }

        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            onEvent = { _ in
                if self.coordinator.activeSetPoseStatus.framesObserved >= timestamps.count {
                    if pauseAfter {
                        self.gate.pause()
                    }
                    self.onEvent = nil
                    done.resume()
                }
            }
            Task { @MainActor in
                await self.emitObservationsOnDeliveryQueue(timestamps)
            }
        }
    }

    private func emitObservationsOnDeliveryQueue(_ timestamps: [Double]) async {
        await channel.runOnDeliveryQueue {
            for timestamp in timestamps {
                let sequence = self.channel.nextSourceSequence()
                self.channel.emit(.observation(LivePoseObservation(
                    frame: poseFrame(at: timestamp),
                    inferenceLatencyMilliseconds: 1,
                    sourceSequenceNumber: sequence
                )))
            }
        }
    }

    func startFreezeWaitingUntilArmed(
        holdBoundary: Bool = false
    ) async -> (
        task: Task<ActiveSetPoseSequence, Error>,
        boundaryID: UUID
    ) {
        if holdBoundary {
            spy.holdNextBoundaryRequest()
        }
        var freezeTask: Task<ActiveSetPoseSequence, Error>!
        let boundaryID = await withCheckedContinuation { (
            armed: CheckedContinuation<UUID, Never>
        ) in
            spy.onEnqueue = { id in
                self.spy.onEnqueue = nil
                armed.resume(returning: id)
            }
            freezeTask = Task { @MainActor in
                try await self.coordinator.freezeActiveSetPoseSequence()
            }
        }
        return (freezeTask, boundaryID)
    }

    func forwardHeldBoundaryAndAwaitEffect() async -> TrainerLivePoseConsumptionEffect {
        await withCheckedContinuation { (
            done: CheckedContinuation<TrainerLivePoseConsumptionEffect, Never>
        ) in
            onEvent = { event in
                guard case .deliveryBoundary = event else {
                    return
                }
                self.onEvent = nil
                done.resume(returning: self.lastConsumptionEffect ?? .none)
            }
            spy.forwardHeldBoundary()
        }
    }
}

private func poseFrame(at timestampSeconds: Double) -> PoseFrame {
    PoseFrame(
        timestampSeconds: timestampSeconds,
        landmarks: [],
        frameConfidence: nil
    )
}

@MainActor
struct TrainerActiveSetDeliveryCoordinatorTests {
    @Test func startSnapshotExcludesEarlierObservationsAndKeepsLaterOnesInOrder() async throws {
        let harness = DeliveryTestHarness()
        await harness.startConsumer()
        defer { harness.stopConsumer() }

        await harness.emitObservations(timestamps: [1, 2, 3])
        try harness.coordinator.begin(baseline: harness.channel.deliveryBaseline)
        await harness.emitObservations(timestamps: [4, 5])

        let sequence = try await freezeUntilComplete(harness)
        #expect(sequence.frames.map(\.timestampSeconds) == [4, 5])
    }

    @Test func preStartBufferedObservationsStayOutOfTheActiveSet() async throws {
        let harness = DeliveryTestHarness()
        // Gate the consumer after handshake so [1, 2, 3] stay undrained until begin and freeze enqueue.
        await harness.startConsumer(pauseAfterHandshake: true)
        defer { harness.stopConsumer() }

        await harness.emitObservations(timestamps: [1, 2, 3])
        try harness.coordinator.begin(baseline: harness.channel.deliveryBaseline)
        await harness.emitObservations(timestamps: [4])

        let freeze = await harness.startFreezeWaitingUntilArmed()
        harness.gate.resumeProcessing()
        let sequence = try await freeze.task.value
        #expect(sequence.frames.map(\.timestampSeconds) == [4])
    }

    @Test func queuedBoundaryExcludesEventsEmittedAfterEnqueueIsConfirmed() async throws {
        let harness = DeliveryTestHarness()
        await harness.startConsumer()
        defer { harness.stopConsumer() }

        try harness.coordinator.begin(baseline: harness.channel.deliveryBaseline)
        await harness.emitObservations(timestamps: [10, 11])

        let freeze = await harness.startFreezeWaitingUntilArmed()
        await harness.emitObservations(timestamps: [12])
        let sequence = try await freeze.task.value

        #expect(sequence.frames.map(\.timestampSeconds) == [10, 11])
    }

    @Test func deliveryLossBeforeStartIsAbsorbedIntoTheBaseline() async throws {
        let harness = DeliveryTestHarness()
        await harness.channel.runOnDeliveryQueue {
            for _ in 0..<121 {
                harness.channel.emit(.captureDropped)
            }
        }
        #expect(harness.channel.eventDeliveryDropCount >= 1)

        await harness.startConsumer()
        defer { harness.stopConsumer() }

        try harness.coordinator.begin(baseline: harness.channel.deliveryBaseline)
        await harness.emitObservations(timestamps: [20])
        let sequence = try await freezeUntilComplete(harness)
        #expect(sequence.frames.map(\.timestampSeconds) == [20])
    }

    @Test func inSetOverflowFailsClosedUsingTheQueuedDropCount() async throws {
        let harness = DeliveryTestHarness()
        await harness.startConsumer()
        defer { harness.stopConsumer() }

        try harness.coordinator.begin(baseline: harness.channel.deliveryBaseline)
        await harness.emitObservations(timestamps: [1], pauseAfter: true)

        await harness.channel.runOnDeliveryQueue {
            for _ in 0..<121 {
                harness.channel.emit(.captureDropped)
            }
        }
        #expect(harness.channel.eventDeliveryDropCount >= 1)

        harness.gate.resumeProcessing()
        let freeze = await harness.startFreezeWaitingUntilArmed()
        await #expect(throws: ActiveSetPoseIngestionError.eventDeliveryDropped) {
            try await freeze.task.value
        }
        #expect(harness.coordinator.activeSetPosePhase == .failed)

        harness.coordinator.discard()
        try harness.coordinator.begin(baseline: harness.channel.deliveryBaseline)
        #expect(harness.coordinator.activeSetPosePhase == .recording)
    }

    @Test func dropWhileFreezeIsPendingResumesExactlyOnce() async throws {
        let harness = DeliveryTestHarness()
        await harness.startConsumer()
        defer { harness.stopConsumer() }

        try harness.coordinator.begin(baseline: harness.channel.deliveryBaseline)
        await harness.emitObservations(timestamps: [1], waitUntilObserved: true)

        let freeze = await harness.startFreezeWaitingUntilArmed(holdBoundary: true)
        let didInvalidate = harness.coordinator.handleEventDeliveryDrop(
            harness.channel.eventDeliveryDropCount + 1
        )
        #expect(didInvalidate)

        await #expect(throws: ActiveSetPoseIngestionError.eventDeliveryDropped) {
            try await freeze.task.value
        }
        #expect(harness.coordinator.activeSetPosePhase == .failed)

        let heldEffect = await harness.forwardHeldBoundaryAndAwaitEffect()
        #expect(heldEffect == .deliveryBoundaryIgnored)

        _ = harness.coordinator.handleEventDeliveryDrop(
            harness.channel.eventDeliveryDropCount + 2
        )
        harness.coordinator.cancelDeliveryBoundary(freeze.boundaryID)

        harness.coordinator.discard()
        try harness.coordinator.begin(baseline: harness.channel.deliveryBaseline)
        await harness.emitObservations(timestamps: [2])
        let sequence = try await freezeUntilComplete(harness)
        #expect(sequence.frames.map(\.timestampSeconds) == [2])
    }

    @Test func shutdownResumesAPendingFreezeExactlyOnce() async throws {
        let harness = DeliveryTestHarness()
        await harness.startConsumer()
        defer { harness.stopConsumer() }

        try harness.coordinator.begin(baseline: harness.channel.deliveryBaseline)
        let freeze = await harness.startFreezeWaitingUntilArmed(holdBoundary: true)
        harness.coordinator.shutdown()

        await #expect(throws: ActiveSetPoseIngestionError.invalidPhase) {
            try await freeze.task.value
        }

        let heldEffect = await harness.forwardHeldBoundaryAndAwaitEffect()
        #expect(heldEffect == .deliveryBoundaryIgnored)

        harness.coordinator.shutdown()
        await harness.emitObservations(timestamps: [3])
        #expect(harness.coordinator.activeSetPosePhase == .recording)
    }

    @Test func cancelResumesAPendingFreezeAndAllowsANewSetAfterDiscard() async throws {
        let harness = DeliveryTestHarness()
        await harness.startConsumer()
        defer { harness.stopConsumer() }

        try harness.coordinator.begin(baseline: harness.channel.deliveryBaseline)
        await harness.emitObservations(timestamps: [1], waitUntilObserved: true)

        let freeze = await harness.startFreezeWaitingUntilArmed(holdBoundary: true)
        harness.coordinator.cancelDeliveryBoundary(freeze.boundaryID)

        await #expect(throws: CancellationError.self) {
            try await freeze.task.value
        }

        let heldEffect = await harness.forwardHeldBoundaryAndAwaitEffect()
        #expect(heldEffect == .deliveryBoundaryIgnored)

        harness.coordinator.cancelDeliveryBoundary(freeze.boundaryID)

        harness.coordinator.discard()
        try harness.coordinator.begin(baseline: harness.channel.deliveryBaseline)
        await harness.emitObservations(timestamps: [2])
        let sequence = try await freezeUntilComplete(harness)
        #expect(sequence.frames.map(\.timestampSeconds) == [2])
    }

    @Test func consecutiveSetsOnOneUninterruptedConsumerDoNotLeakPriorFrames() async throws {
        let harness = DeliveryTestHarness()
        await harness.startConsumer()
        defer { harness.stopConsumer() }

        try harness.coordinator.begin(baseline: harness.channel.deliveryBaseline)
        await harness.emitObservations(timestamps: [1])
        let first = try await freezeUntilComplete(harness)
        #expect(first.frames.map(\.timestampSeconds) == [1])

        try harness.coordinator.begin(baseline: harness.channel.deliveryBaseline)
        await harness.emitObservations(timestamps: [2])
        let second = try await freezeUntilComplete(harness)
        #expect(second.frames.map(\.timestampSeconds) == [2])
    }

    @Test func productionDefaultPipelinePreservesAnalyzerConfigurationOnTheFrozenSequence() async throws {
        let harness = DeliveryTestHarness()
        await harness.startConsumer()
        defer { harness.stopConsumer() }

        await harness.emitObservations(timestamps: [1, 2, 3])
        try harness.coordinator.begin(baseline: harness.channel.deliveryBaseline)
        await harness.emitObservations(timestamps: [4, 5])

        let freeze = await harness.startFreezeWaitingUntilArmed()
        await harness.emitObservations(timestamps: [6])
        let sequence = try await freeze.task.value

        #expect(sequence.analyzerConfiguration == SquatAnalysisConfiguration())
        #expect(sequence.frames.map(\.timestampSeconds) == [4, 5])
    }

    @Test func lateBoundaryDoesNotRelabelANonDropIngestionFailureAsDeliveryDrop() async throws {
        let harness = DeliveryTestHarness(
            pipeline: TrainerPoseObservationPipeline(
                retentionPolicy: ActiveSetPoseRetentionPolicy(
                    maximumFrameCount: 1,
                    maximumDurationSeconds: 600
                )
            )
        )
        await harness.startConsumer()
        defer { harness.stopConsumer() }

        try harness.coordinator.begin(baseline: harness.channel.deliveryBaseline)
        await harness.emitObservations(timestamps: [1], waitUntilObserved: true)

        let overflowingObservation = LivePoseObservation(
            frame: poseFrame(at: 2),
            inferenceLatencyMilliseconds: 1,
            sourceSequenceNumber: 9_001
        )
        var reportedFailure: ActiveSetPoseIngestionError?
        do {
            _ = try harness.coordinator.observe(overflowingObservation, phoneStable: true)
        } catch let error as ActiveSetPoseIngestionError {
            reportedFailure = error
        }
        #expect(reportedFailure == .retentionLimitExceeded)
        #expect(harness.coordinator.activeSetPosePhase == .failed)

        let freeze = await harness.startFreezeWaitingUntilArmed(holdBoundary: true)
        let effect = await harness.forwardHeldBoundaryAndAwaitEffect()
        #expect(effect == .deliveryBoundaryIgnored)
        if effect == .deliveryDropMismatch {
            reportedFailure = .eventDeliveryDropped
        }
        #expect(reportedFailure == .retentionLimitExceeded)
        #expect(harness.coordinator.activeSetPosePhase == .failed)

        await #expect(throws: ActiveSetPoseIngestionError.invalidPhase) {
            try await freeze.task.value
        }
    }
}

@MainActor
private func freezeUntilComplete(
    _ harness: DeliveryTestHarness
) async throws -> ActiveSetPoseSequence {
    let freeze = await harness.startFreezeWaitingUntilArmed()
    return try await freeze.task.value
}
