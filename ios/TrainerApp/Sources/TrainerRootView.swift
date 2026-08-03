import Accessibility
import PoseCore
import SquatAnalysis
import SwiftUI
import TrainerCore
import TrainerRuntime

private enum SessionFieldFocus: Hashable {
    case load
    case reviewLoad
    case reviewCountedReps
    case reviewCleanReps
}

private struct WorkoutStatusPresentation {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
}

private struct SessionNoticePresentation: Equatable {
    let title: String
    let detail: String
    let systemImage: String
}

struct TrainerRootView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Start")
                            .font(.largeTitle.bold())

                        Text("Start a focused back-squat session without a plan or account.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(ExerciseCatalog.v1.supportedExercises) { exercise in
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 12) {
                                    Image(systemName: "figure.strengthtraining.traditional")
                                        .font(.title2)
                                        .frame(width: 36, height: 36)
                                        .foregroundStyle(.tint)
                                        .accessibilityHidden(true)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.displayName)
                                            .font(.title3.bold())
                                        Text("\(exercise.variantDisplayName) · Side view")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Divider()

                                Label("Place your phone on a stable surface", systemImage: "iphone.gen3")
                                Label("You will confirm load before each set", systemImage: "scalemass")
                            }
                            .font(.subheadline)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

                            NavigationLink {
                                BackSquatQuickSessionView(exercise: exercise)
                            } label: {
                                HStack {
                                    Text("Start Quick Session")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                        .accessibilityHidden(true)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                    }

                    Text("Enter load, arm the set, prop the phone, then walk into frame. On-screen status and countdown haptics show when recording begins.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Squat Trainer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#if DEBUG
#Preview("Workout state hierarchy") {
    ScrollView {
        VStack(spacing: 16) {
            WorkoutStatusCard(
                presentation: WorkoutStatusPresentation(
                    title: "Recording",
                    detail: "Live count is provisional. Tap Stop when the set is over.",
                    systemImage: "record.circle.fill",
                    tint: .red
                ),
                completedSetCount: 1
            )

            WorkoutStatusCard(
                presentation: WorkoutStatusPresentation(
                    title: "Processing set",
                    detail: "The camera is off. Review opens automatically when the final count is ready.",
                    systemImage: "hourglass",
                    tint: .blue
                ),
                completedSetCount: 1
            )

            WorkoutStatusCard(
                presentation: WorkoutStatusPresentation(
                    title: "Review ready",
                    detail: "This set is saved in the current session. Check it before continuing.",
                    systemImage: "checkmark.circle.fill",
                    tint: .green
                ),
                completedSetCount: 2
            )

            CameraAvailabilityCallout(
                title: "Camera unavailable",
                detail: "Camera permission is unavailable.",
                isLoading: false
            )
        }
        .padding()
    }
}

#Preview("Review and recovery states") {
    ScrollView {
        VStack(spacing: 16) {
            ReviewResultHero(load: "185 lb", countedReps: 0)
            ZeroRepReviewNotice(setOrdinal: 2)
            ValidationCallout(message: "Clean reps cannot exceed counted reps.")
            SessionNoticeCard(
                presentation: SessionNoticePresentation(
                    title: "Corrected set discarded",
                    detail: "Set 2 was removed. Its load is restored for the retry.",
                    systemImage: "arrow.uturn.backward.circle.fill"
                ),
                dismiss: {}
            )
            SessionSummarySetRow(
                ordinal: 2,
                result: "185 lb × 5",
                cleanResult: "4 clean · user corrected",
                captureConfidence: .low
            )
        }
        .padding()
    }
}

#Preview("Accessibility text layout") {
    ScrollView {
        VStack(spacing: 16) {
            WorkoutStatusCard(
                presentation: WorkoutStatusPresentation(
                    title: "Processing failed",
                    detail: "Retry finalization or discard this capture.",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                ),
                completedSetCount: 3
            )
            ReviewResultHero(load: "102.5 kg", countedReps: 12)
            SessionSummarySetRow(
                ordinal: 3,
                result: "102.5 kg × 12",
                cleanResult: "Clean reps unavailable",
                captureConfidence: .unavailable
            )
        }
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
    .preferredColorScheme(.dark)
}
#endif

private struct BackSquatQuickSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focusedField: SessionFieldFocus?
    @ScaledMetric(relativeTo: .largeTitle) private var countdownNumberSize = 72
    @ScaledMetric(relativeTo: .largeTitle) private var provisionalRepCountSize = 72
    @State private var session: QuickSession
    @State private var loadText: String
    @State private var loadUnit: LoadUnit
    @State private var loadEntryError: String?
    @State private var countdown = PreSetCountdown()
    @State private var startArming = StartSetArming()
    @State private var activeCapture = ActiveSetCapture()
    @State private var retainedPoseSequence: ActiveSetPoseSequence?
    @State private var reviewedSet: CompletedSetSummary?
    @State private var endedSummary: QuickSessionSummary?
    @State private var isEditingReview = false
    @State private var reviewLoadText = ""
    @State private var reviewLoadUnit: LoadUnit = .defaultUnit
    @State private var reviewCountedRepsText = ""
    @State private var reviewCleanRepsText = ""
    @State private var reviewEditError: String?
    @State private var processingError: String?
    @State private var countdownTask: Task<Void, Never>?
    @State private var captureStopTask: Task<Void, Never>?
    @State private var processingTask: Task<Void, Never>?
    @State private var showWeakSetupOption = false
    @State private var sessionNotice: SessionNoticePresentation?
    @StateObject private var setupController = TrainerSetupGateController()
    private let cues = TrainerSessionCues()
    private let exercise: ExerciseDefinition

    private var isCapturingSet: Bool {
        activeCapture.phase == .recording
    }

    private var isPostCaptureFlow: Bool {
        switch activeCapture.phase {
        case .processing, .processingFailed, .awaitingReview:
            true
        case .idle, .recording, .discarded:
            false
        }
    }

    private var displayedSetOrdinal: Int {
        reviewedSet?.ordinal ?? session.currentSet.ordinal
    }

    private var isArmedOrCounting: Bool {
        startArming.isArmed || countdown.state != .idle
    }

    private var hasEnteredLoad: Bool {
        !loadText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var cameraFailureMessage: String? {
        guard case let .failed(message) = setupController.streamState else {
            return nil
        }
        return message
    }

    private var canArmSet: Bool {
        hasEnteredLoad && cameraFailureMessage == nil
    }

    private var requiresControlledSessionExit: Bool {
        endedSummary != nil
            || isArmedOrCounting
            || activeCapture.phase != .idle
            || !session.completedSets.isEmpty
    }

    private var workoutStatus: WorkoutStatusPresentation {
        switch activeCapture.phase {
        case .recording:
            if let cameraFailureMessage {
                return WorkoutStatusPresentation(
                    title: "Camera interrupted",
                    detail: "\(cameraFailureMessage) Tap Stop to finish or discard this capture.",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .red
                )
            }
            return WorkoutStatusPresentation(
                title: "Recording",
                detail: "Live count is provisional. Tap Stop when the set is over.",
                systemImage: "record.circle.fill",
                tint: .red
            )
        case .processing:
            return WorkoutStatusPresentation(
                title: "Processing set",
                detail: "The camera is off. Review opens automatically when the final count is ready.",
                systemImage: "hourglass",
                tint: .blue
            )
        case .processingFailed:
            return WorkoutStatusPresentation(
                title: "Processing failed",
                detail: "Retry finalization or discard this capture.",
                systemImage: "exclamationmark.triangle.fill",
                tint: .orange
            )
        case .awaitingReview:
            let finalizedCount = reviewedSet?.analysis?.finalizedCountedReps
                ?? activeCapture.finalizedCountedReps
            let currentCount = reviewedSet?.countedReps ?? finalizedCount
            if currentCount == 0, finalizedCount == 0 {
                return WorkoutStatusPresentation(
                    title: "No reps detected",
                    detail: "Discard and retry keeps an accidental capture out of this workout.",
                    systemImage: "exclamationmark.circle.fill",
                    tint: .orange
                )
            }
            return WorkoutStatusPresentation(
                title: "Review ready",
                detail: "This set is saved in the current session. Check it before continuing.",
                systemImage: "checkmark.circle.fill",
                tint: .green
            )
        case .idle, .discarded:
            if let cameraFailureMessage {
                return WorkoutStatusPresentation(
                    title: "Camera unavailable",
                    detail: cameraFailureMessage,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                )
            }
            if case let .counting(remainingSeconds) = countdown.state {
                return WorkoutStatusPresentation(
                    title: "Starting in \(remainingSeconds)",
                    detail: "Recording begins automatically when the countdown ends.",
                    systemImage: "timer",
                    tint: .blue
                )
            }
            if countdown.state == .visibilityConfirmationRequired {
                return WorkoutStatusPresentation(
                    title: "Setup changed",
                    detail: "Full-body visibility was lost before recording.",
                    systemImage: "person.crop.rectangle",
                    tint: .orange
                )
            }
            if startArming.isArmed {
                return WorkoutStatusPresentation(
                    title: "Set armed",
                    detail: "Leave the phone propped and walk into frame.",
                    systemImage: "figure.walk",
                    tint: .blue
                )
            }
            if setupController.assessment.isReady {
                return WorkoutStatusPresentation(
                    title: "Setup ready",
                    detail: "Enter the load and arm the set when you are ready to step away.",
                    systemImage: "checkmark.circle.fill",
                    tint: .green
                )
            }
            return WorkoutStatusPresentation(
                title: "Set setup",
                detail: "Enter the load and complete the camera checks.",
                systemImage: "camera.viewfinder",
                tint: .accentColor
            )
        }
    }

    private func announceWorkoutStatus() {
        AccessibilityNotification.Announcement(
            "\(workoutStatus.title). \(workoutStatus.detail)"
        ).post()
    }

    init(exercise: ExerciseDefinition) {
        self.exercise = exercise
        _session = State(initialValue: QuickSession(exerciseID: exercise.id))
        _loadText = State(initialValue: "")
        _loadUnit = State(initialValue: .defaultUnit)
        _loadEntryError = State(initialValue: nil)
    }

    var body: some View {
        ScrollView {
            if let endedSummary {
                sessionSummaryContent(endedSummary)
            } else {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quick Session")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(exercise.displayName)
                            .font(.largeTitle.bold())

                        Text("Set \(displayedSetOrdinal)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    WorkoutStatusCard(
                        presentation: workoutStatus,
                        completedSetCount: session.completedSets.count
                    )

                    if let sessionNotice {
                        SessionNoticeCard(presentation: sessionNotice) {
                            self.sessionNotice = nil
                        }
                    }

                    if isCapturingSet {
                        cameraPreview
                        activeSetControls
                    } else if isPostCaptureFlow {
                        activeSetControls
                    } else if isArmedOrCounting {
                        cameraPreview
                        countdownControls
                        if startArming.isArmed {
                            setupGateSection
                        }
                    } else {
                        preCaptureSections
                        cameraPreview
                        setupGateSection
                        countdownControls
                    }

                    if !isPostCaptureFlow {
                        Button("End Quick Session", role: .destructive) {
                            endSession()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(activeCapture.phase == .recording)
                    }
                }
                .padding()
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .navigationTitle(endedSummary == nil ? exercise.displayName : "Workout Summary")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(requiresControlledSessionExit)
        .alert(discardAlertTitle, isPresented: discardConfirmationBinding) {
            Button(discardCancelButtonTitle, role: .cancel) {
                activeCapture.cancelDiscardConfirmation()
            }
            Button(discardConfirmButtonTitle, role: .destructive) {
                confirmDiscardActiveSet()
            }
        } message: {
            Text(discardConfirmationMessage)
        }
        .task {
            if endedSummary == nil {
                setupController.start()
            }
        }
        .onDisappear {
            countdownTask?.cancel()
            captureStopTask?.cancel()
            processingTask?.cancel()
            cues.stop()
            setupController.discardActiveSetPoseIngestion()
            setupController.shutdown()
        }
        .onChange(of: setupController.assessment) { _, _ in
            tryBeginArmedCountdownIfReady()
        }
        .onChange(of: setupController.activeSetPoseFailure) { _, failure in
            guard let failure else { return }
            handleActiveSetPoseIngestionFailure(failure)
        }
        .onChange(of: activeCapture.phase) { _, phase in
            switch phase {
            case .recording, .processing, .processingFailed, .awaitingReview:
                focusedField = nil
                announceWorkoutStatus()
            case .idle, .discarded:
                break
            }
        }
        .onChange(of: setupController.streamState) { _, state in
            if case .failed = state {
                announceWorkoutStatus()
            }
        }
    }

    @ViewBuilder
    private var preCaptureSections: some View {
        let loadInputLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))

        VStack(alignment: .leading, spacing: 14) {
            Label("\(exercise.variantDisplayName) · \(exercise.displayName)", systemImage: "figure.strengthtraining.traditional")
            Label("Side-view capture", systemImage: "camera.viewfinder")
            Label("Quick-start session", systemImage: "bolt.fill")
        }
        .font(.body.weight(.medium))
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

        VStack(alignment: .leading, spacing: 8) {
            Text(session.currentSet.ordinal == 1 ? "Before your first set" : "Before your next set")
                .font(.headline)

            Text("Enter load, arm the set while you still have the phone, prop it, then walk into frame. Countdown starts when setup checks are green.")
                .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 12) {
            Text("Load for Set \(session.currentSet.ordinal)")
                .font(.headline)

            loadInputLayout {
                TextField("Weight", text: $loadText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .load)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Load value")
                    .accessibilityHint("Enter the total load for Set \(session.currentSet.ordinal).")

                Picker("Unit", selection: $loadUnit) {
                    ForEach(LoadUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(
                    maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 130
                )
                .frame(minHeight: 44)
            }

            if session.currentSet.load != nil {
                Text("A load is prefilled for this set. Edit it if the load changes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Pounds are the initial default. Enter the actual load, including zero if that is intentional.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let loadEntryError {
                ValidationCallout(message: loadEntryError)
            }
        }
        .padding(16)
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }

    private var cameraPreview: some View {
        ZStack(alignment: .topLeading) {
            TrainerCameraPreview(session: setupController.camera.captureSession)
                .aspectRatio(9 / 16, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if let frame = setupController.latestPoseFrame {
                TrainerPoseOverlay(frame: frame)
                    .aspectRatio(9 / 16, contentMode: .fit)
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    if isCapturingSet {
                        Circle()
                            .fill(.red)
                            .frame(width: 9, height: 9)
                    }
                    Text(cameraStatusBanner)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.black.opacity(0.78), in: Capsule())

                if case let .counting(remainingSeconds) = countdown.state {
                    Text("\(remainingSeconds)")
                        .font(.system(size: countdownNumberSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rear camera preview")
        .accessibilityValue(cameraAccessibilityValue)
    }

    private var cameraStatusBanner: String {
        if cameraFailureMessage != nil {
            return isCapturingSet ? "CAMERA INTERRUPTED · TAP STOP" : "CAMERA UNAVAILABLE"
        }
        if isCapturingSet {
            return "RECORDING"
        }
        if case .counting = countdown.state {
            return "COUNTDOWN"
        }
        if startArming.isArmed {
            let passing = setupController.assessment.checks.filter { $0.status == .passing }.count
            return "ARMED · \(passing)/\(setupController.assessment.checks.count) CHECKS"
        }
        return setupController.statusText
    }

    private var cameraAccessibilityValue: String {
        if let cameraFailureMessage {
            return isCapturingSet
                ? "Camera interrupted. \(cameraFailureMessage) Tap Stop to finish or discard this capture."
                : "Camera unavailable. \(cameraFailureMessage)"
        }
        if isCapturingSet {
            return "Recording is active."
        }
        if case let .counting(remainingSeconds) = countdown.state {
            return "Countdown, \(remainingSeconds) seconds remaining."
        }
        if startArming.isArmed {
            return "Set armed. \(passingCheckSummaryText) setup checks passing."
        }
        return setupController.statusText
    }

    private var setupGateSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Camera Setup Gate")
                    .font(.headline)
                Text("Runs before every set")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let cameraFailureMessage {
                CameraAvailabilityCallout(
                    title: "Camera unavailable",
                    detail: cameraFailureMessage,
                    isLoading: false
                )
            } else if setupController.streamState == .starting {
                CameraAvailabilityCallout(
                    title: "Starting rear camera",
                    detail: "Setup checks will begin when the camera is ready.",
                    isLoading: true
                )
            }

            ForEach(setupController.assessment.checks) { check in
                SetupCheckRow(check: check)
            }

            Text("Checks use a short live window. Full-body, side-view, and confidence come from pose landmarks; phone stability comes from device motion.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Reset Setup Checks") {
                resetSetup()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(countdown.state != .idle || startArming.isArmed)
        }
        .padding(16)
        .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var activeSetControls: some View {
        switch activeCapture.phase {
        case .recording:
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Provisional reps")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("\(setupController.activeSetPoseStatus.provisionalCountedReps)")
                        .font(.system(size: provisionalRepCountSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .accessibilityLabel("Provisional rep count")
                        .accessibilityValue("\(setupController.activeSetPoseStatus.provisionalCountedReps)")
                    Text("Live count is provisional. Final counted and clean reps come after the set.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 12) {
                    Button("Discard", role: .destructive) {
                        discardActiveSet()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button("Stop") {
                        stopActiveSet()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.red)
                    .frame(maxWidth: .infinity)
                    .accessibilityHint("Stops recording and opens set processing.")
                }
            }

        case .processing:
            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.large)
                Text("Analyzing the complete set")
                    .font(.headline)
                Text(retainedPoseSequence == nil
                     ? "Finishing the capture before analysis. The camera is off."
                     : "Finalizing counted reps. Review will open automatically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Discard set", role: .destructive) {
                    discardActiveSet()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

        case .processingFailed:
            VStack(alignment: .leading, spacing: 14) {
                Label {
                    Text("Couldn’t finalize set")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.headline)

                Text(processingError ?? "The full-sequence analysis did not finish.")
                    .foregroundStyle(.secondary)

                Text(retainedPoseSequence == nil
                     ? "This capture can’t be reviewed reliably. Discard it and retry the set."
                     : "No set result was saved. Retry analysis from this capture or discard it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Button("Discard", role: .destructive) {
                        discardActiveSet()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    if retainedPoseSequence != nil {
                        Button("Retry Processing") {
                            retryFinalization()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
            .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))

        case .awaitingReview:
            if let reviewedSet, let analysis = reviewedSet.analysis {
                postSetReview(completedSet: reviewedSet, analysis: analysis)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Label {
                        Text("Review unavailable")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .font(.headline)
                    Text("The set reached review without a finalized analysis summary.")
                        .foregroundStyle(.secondary)
                    Button("Discard set", role: .destructive) {
                        discardActiveSet()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(16)
                .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            }

        case .idle, .discarded:
            EmptyView()
        }
    }

    private func postSetReview(
        completedSet: CompletedSetSummary,
        analysis: SetAnalysisSummary
    ) -> some View {
        let countedReps = completedSet.countedReps ?? analysis.finalizedCountedReps
        let cleanResult = completedSet.cleanResult ?? .unavailable
        let showsZeroRepEmptyState = countedReps == 0
            && analysis.finalizedCountedReps == 0

        return VStack(alignment: .leading, spacing: 18) {
            Label {
                Text(
                    showsZeroRepEmptyState
                        ? "No reps detected"
                        : "Set \(completedSet.ordinal) ready for review"
                )
            } icon: {
                Image(
                    systemName: showsZeroRepEmptyState
                        ? "exclamationmark.circle.fill"
                        : "checkmark.circle.fill"
                )
                .foregroundStyle(showsZeroRepEmptyState ? Color.orange : Color.green)
            }
            .font(.headline)

            ReviewResultHero(
                load: formattedLoad(completedSet.load),
                countedReps: countedReps
            )

            if showsZeroRepEmptyState {
                ZeroRepReviewNotice(setOrdinal: completedSet.ordinal)

                if !isEditingReview {
                    Button("Discard and Retry Set \(completedSet.ordinal)", role: .destructive) {
                        discardActiveSet()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.red)
                    .frame(maxWidth: .infinity)
                }
            }

            if analysis.provisionalCountedReps != analysis.finalizedCountedReps {
                Label(
                    "Live count \(analysis.provisionalCountedReps) → finalized \(analysis.finalizedCountedReps)",
                    systemImage: "arrow.triangle.2.circlepath"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            }

            if countedReps != analysis.finalizedCountedReps {
                Label(
                    "User corrected counted reps: analyzer \(analysis.finalizedCountedReps) → current \(countedReps)",
                    systemImage: "pencil.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            } else if hasCorrection(.load, in: completedSet) {
                Label("Load edited after analysis", systemImage: "pencil.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            if completedSet.setupGateOutcome?.requiresLowConfidenceLabel == true {
                Label {
                    Text("Low-confidence capture — setup was overridden")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.subheadline.weight(.semibold))
            }

            if isEditingReview {
                reviewEditor(for: completedSet)
            } else {
                Button {
                    beginEditingReview(completedSet)
                } label: {
                    Label("Edit results", systemImage: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Clean result")
                    .font(.headline)

                switch cleanResult {
                case let .analyzerAssessed(cleanReps):
                    Text("\(cleanReps) clean \(cleanReps == 1 ? "rep" : "reps")")
                        .font(.title2.bold())
                case let .userCorrected(cleanReps):
                    Text("\(cleanReps) clean \(cleanReps == 1 ? "rep" : "reps")")
                        .font(.title2.bold())
                    Label("User corrected — not analyzer evidence", systemImage: "person.fill.checkmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.blue)
                case .unavailable:
                    Text("Clean reps unavailable")
                        .font(.title2.bold())
                    Text("Depth, lockout, and tempo/control were not assessed with sufficient evidence. This is not 0 clean reps.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Rep quality")
                    .font(.headline)

                if analysis.reps.isEmpty {
                    Text("No completed reps were finalized.")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(analysis.reps) { rep in
                                VStack(spacing: 5) {
                                    Image(systemName: qualityIcon(for: rep.quality))
                                        .font(.title2)
                                        .foregroundStyle(qualityColor(for: rep.quality))
                                    Text("\(rep.index)")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Rep \(rep.index), \(qualityLabel(for: rep.quality))")
                            }
                        }
                    }

                    if analysis.reps.contains(where: { $0.quality == .unavailable }) {
                        Label("Quality not assessed", systemImage: "questionmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Form takeaway")
                    .font(.headline)
                Text(formTakeaway(for: analysis))
                    .foregroundStyle(.secondary)
            }

            if isEditingReview {
                Text("Apply or cancel edits before continuing.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else if showsZeroRepEmptyState {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        zeroRepKeepButton
                        reviewEndWorkoutButton
                    }

                    VStack(spacing: 12) {
                        zeroRepKeepButton
                        reviewEndWorkoutButton
                    }
                }
            } else {
                Button("Next Set") {
                    advanceAfterStoppedSet()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        reviewDiscardButton
                        reviewEndWorkoutButton
                    }

                    VStack(spacing: 12) {
                        reviewDiscardButton
                        reviewEndWorkoutButton
                    }
                }
            }
        }
        .padding(18)
        .background(
            (showsZeroRepEmptyState ? Color.orange : Color.green).opacity(0.08),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }

    private var zeroRepKeepButton: some View {
        Button("Keep 0 Reps and Continue") {
            advanceAfterStoppedSet()
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }

    private var reviewEndWorkoutButton: some View {
        Button("End Workout") {
            endSession()
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }

    private var reviewDiscardButton: some View {
        Button("Discard", role: .destructive) {
            discardActiveSet()
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
    }

    private func reviewEditor(for completedSet: CompletedSetSummary) -> some View {
        let loadInputLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        let actionLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))

        return VStack(alignment: .leading, spacing: 12) {
            Text("Edit results")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("Load")
                    .font(.subheadline.weight(.semibold))

                loadInputLayout {
                    TextField("Weight", text: $reviewLoadText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .reviewLoad)
                        .frame(minHeight: 44)
                        .accessibilityLabel("Corrected load value")
                        .accessibilityHint("Enter a number zero or greater.")

                    Picker("Unit", selection: $reviewLoadUnit) {
                        ForEach(LoadUnit.allCases) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(
                        maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 150
                    )
                    .frame(minHeight: 44)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Counted")
                    .font(.subheadline.weight(.semibold))
                TextField("Reps", text: $reviewCountedRepsText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .reviewCountedReps)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Corrected counted reps")
                    .accessibilityHint("Enter a whole number zero or greater.")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Clean")
                    .font(.subheadline.weight(.semibold))
                TextField("Unavailable", text: $reviewCleanRepsText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .reviewCleanReps)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Corrected clean reps")
                    .accessibilityHint("Leave blank to preserve unavailable evidence, or enter a whole number.")
            }

            Text("Leave clean reps blank to keep the current status. Entering a number records user evidence, not analyzer evidence.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let reviewEditError {
                ValidationCallout(message: reviewEditError)
            }

            actionLayout {
                Button("Cancel") {
                    resetReviewEditor()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                Button("Apply edits") {
                    applyReviewEdits(to: completedSet)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func beginEditingReview(_ completedSet: CompletedSetSummary) {
        reviewLoadText = formattedLoadValue(completedSet.load)
        reviewLoadUnit = completedSet.load.unit
        reviewCountedRepsText = completedSet.countedReps.map(String.init) ?? ""
        reviewCleanRepsText = cleanRepCount(from: completedSet.cleanResult).map(String.init) ?? ""
        reviewEditError = nil
        isEditingReview = true
    }

    private func applyReviewEdits(to completedSet: CompletedSetSummary) {
        let trimmedLoad = reviewLoadText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let loadValue = Double(trimmedLoad),
              let correctedLoad = try? TrainingLoad(value: loadValue, unit: reviewLoadUnit) else {
            setReviewEditError(
                "Load must be a number zero or greater.",
                focus: .reviewLoad
            )
            return
        }

        let trimmedCounted = reviewCountedRepsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let correctedCountedReps = Int(trimmedCounted), correctedCountedReps >= 0 else {
            setReviewEditError(
                "Counted reps must be a whole number zero or greater.",
                focus: .reviewCountedReps
            )
            return
        }

        let trimmedClean = reviewCleanRepsText.trimmingCharacters(in: .whitespacesAndNewlines)
        let correctedCleanReps: Int?
        if trimmedClean.isEmpty {
            correctedCleanReps = nil
        } else if let cleanReps = Int(trimmedClean), cleanReps >= 0 {
            correctedCleanReps = cleanReps
        } else {
            setReviewEditError(
                "Clean reps must be a whole number zero or greater, or left blank.",
                focus: .reviewCleanReps
            )
            return
        }

        guard let currentCountedReps = completedSet.countedReps else {
            setReviewEditError(
                "This set no longer has a reviewable counted-rep result.",
                focus: nil
            )
            return
        }
        let currentCleanReps = cleanRepCount(from: completedSet.cleanResult)
        let resultingCleanReps = correctedCleanReps ?? currentCleanReps
        guard resultingCleanReps.map({ $0 <= correctedCountedReps }) ?? true else {
            setReviewEditError(
                "Clean reps cannot exceed counted reps.",
                focus: .reviewCleanReps
            )
            return
        }

        let countedChanged = correctedCountedReps != currentCountedReps
        let cleanChanged = correctedCleanReps.map { $0 != currentCleanReps } ?? false
        let correctedAt = Date()

        do {
            if countedChanged, correctedCountedReps >= currentCountedReps {
                try session.correctReviewedSetCountedReps(
                    completedSet.id,
                    to: correctedCountedReps,
                    at: correctedAt
                )
            }
            if cleanChanged, let correctedCleanReps {
                try session.correctReviewedSetCleanReps(
                    completedSet.id,
                    to: correctedCleanReps,
                    at: correctedAt
                )
            }
            if countedChanged, correctedCountedReps < currentCountedReps {
                try session.correctReviewedSetCountedReps(
                    completedSet.id,
                    to: correctedCountedReps,
                    at: correctedAt
                )
            }
            if correctedLoad != completedSet.load {
                try session.correctReviewedSetLoad(
                    completedSet.id,
                    to: correctedLoad,
                    at: correctedAt
                )
            }

            guard let correctedSet = session.completedSets.last,
                  correctedSet.id == completedSet.id else {
                setReviewEditError(
                    "The reviewed set could not be refreshed.",
                    focus: nil
                )
                return
            }
            reviewedSet = correctedSet
            syncLoadEntryFromCurrentSet()
            resetReviewEditor()
        } catch let error as SetCorrectionError {
            switch error {
            case .negativeCount:
                setReviewEditError(
                    "Rep counts must be zero or greater.",
                    focus: .reviewCountedReps
                )
            case .cleanRepsExceedCounted:
                setReviewEditError(
                    "Clean reps cannot exceed counted reps.",
                    focus: .reviewCleanReps
                )
            }
        } catch {
            setReviewEditError(
                "This set is no longer available to edit.",
                focus: nil
            )
        }
    }

    private func setReviewEditError(
        _ message: String,
        focus: SessionFieldFocus?
    ) {
        reviewEditError = message
        focusedField = focus
        AccessibilityNotification.Announcement("Error. \(message)").post()
    }

    private func resetReviewEditor() {
        isEditingReview = false
        reviewEditError = nil
        focusedField = nil
    }

    private func cleanRepCount(from result: ReviewedSetCleanResult?) -> Int? {
        switch result {
        case let .analyzerAssessed(cleanReps), let .userCorrected(cleanReps):
            cleanReps
        case .unavailable, .none:
            nil
        }
    }

    private func hasCorrection(
        _ field: SetCorrectionField,
        in completedSet: CompletedSetSummary
    ) -> Bool {
        completedSet.userCorrections.contains { $0.field == field }
    }

    private func formattedLoad(_ load: TrainingLoad) -> String {
        "\(formattedLoadValue(load)) \(load.unit.rawValue)"
    }

    private func formattedLoadValue(_ load: TrainingLoad) -> String {
        load.value == floor(load.value)
            ? String(Int(load.value))
            : String(load.value)
    }

    private func qualityIcon(for quality: SetRepQuality) -> String {
        switch quality {
        case .clean:
            "checkmark.circle.fill"
        case .notClean:
            "exclamationmark.circle.fill"
        case .unavailable:
            "questionmark.circle"
        }
    }

    private func qualityColor(for quality: SetRepQuality) -> Color {
        switch quality {
        case .clean:
            .green
        case .notClean:
            .orange
        case .unavailable:
            .secondary
        }
    }

    private func qualityLabel(for quality: SetRepQuality) -> String {
        switch quality {
        case .clean:
            "clean"
        case .notClean:
            "not clean"
        case .unavailable:
            "quality unavailable"
        }
    }

    private func formTakeaway(for analysis: SetAnalysisSummary) -> String {
        switch analysis.cleanResult {
        case let .assessed(cleanReps)
            where cleanReps == analysis.finalizedCountedReps && analysis.finalizedCountedReps > 0:
            "All finalized reps passed the required clean gates."
        case .assessed:
            "One or more reps missed a required clean gate. Issue categories are not available yet."
        case .unavailable:
            "Unavailable until depth, lockout, and tempo/control gates are assessed."
        }
    }

    @ViewBuilder
    private var countdownControls: some View {
        switch countdown.state {
        case .idle:
            if startArming.isArmed {
                armedWaitingControls
            } else {
                armingControls
            }

        case .counting:
            // Countdown number is overlaid on the camera so the preview stays primary.
            EmptyView()

        case .visibilityConfirmationRequired:
            let confirmationLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(spacing: 12))

            VStack(alignment: .leading, spacing: 12) {
                Text("Can't see full body. Start anyway?")
                    .font(.headline)

                confirmationLayout {
                    Button("Reset") {
                        resetSetup()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button("Start Anyway") {
                        startAnywayAfterCountdown()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(16)
            .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

        case .readyForActiveCapture:
            EmptyView()
        }
    }

    private var armingControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Arm set") {
                focusedField = nil
                armStart(mode: .waitForPassingSetup)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(!canArmSet)
            .accessibilityHint("Locks the entered load, then waits for passing setup checks.")

            Text("Locks your load, then waits while you prop the phone and walk into frame. Countdown starts when all checks are green.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !setupController.assessment.hasPendingChecks,
               !setupController.assessment.failedChecks.isEmpty {
                Button(showWeakSetupOption ? "Hide weak-setup option" : "Setup looks weak — other options") {
                    showWeakSetupOption.toggle()
                }
                .font(.footnote)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .frame(minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityHint("Shows the low-confidence setup override.")

                if showWeakSetupOption {
                    Button("Accept weak setup") {
                        focusedField = nil
                        armStart(mode: .waitForEvaluatedSetupAllowingOverride)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.orange)
                    .disabled(!canArmSet)

                    Text("Different from Arm set: countdown can begin even if some checks stay red. That set is labeled low-confidence.")
                        .font(.footnote)
                        .foregroundStyle(.primary)
                }
            }

            if !hasEnteredLoad {
                Text("Enter a load before arming.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if cameraFailureMessage != nil {
                Label("Camera access must be available before the set can be armed.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.primary)
            }
        }
    }

    private var armedWaitingControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(
                    cameraFailureMessage == nil
                        ? "Armed — walk into frame"
                        : "Arming paused — camera unavailable"
                )
                    .font(.headline)
                Spacer()
                Text(passingCheckSummaryText)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(setupController.assessment.isReady ? .green : .secondary)
            }

            Text(
                cameraFailureMessage == nil
                    ? armedWaitingDetail
                    : "Cancel arming, then restore camera access before trying again."
            )
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Cancel") {
                startArming.cancel()
                loadEntryError = nil
                cues.stop()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }

    private var passingCheckSummaryText: String {
        let passing = setupController.assessment.checks.filter { $0.status == .passing }.count
        let total = setupController.assessment.checks.count
        return "\(passing)/\(total)"
    }

    private var armedWaitingDetail: String {
        switch startArming.state {
        case .idle:
            ""
        case .armed(.waitForPassingSetup):
            "Leave the phone propped. Stand side-on until checks clear."
        case .armed(.waitForEvaluatedSetupAllowingOverride):
            "Leave the phone propped. Weak setup accepted; countdown can start with failed checks."
        }
    }

    private func armStart(mode: StartSetArmingMode) {
        let trimmedLoad = loadText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmedLoad) else {
            presentLoadEntryError("Enter a valid numeric load.")
            return
        }

        do {
            let load = try TrainingLoad(value: value, unit: loadUnit)
            try session.setCurrentSetLoad(load)
            startArming.arm(mode)
            loadEntryError = nil
            sessionNotice = nil
            showWeakSetupOption = false
            tryBeginArmedCountdownIfReady()
        } catch TrainingLoadError.invalidValue {
            presentLoadEntryError("Load must be zero or greater.")
        } catch {
            assertionFailure("An active quick session should accept load before arming: \(error)")
        }
    }

    private func presentLoadEntryError(_ message: String) {
        loadEntryError = message
        focusedField = .load
        AccessibilityNotification.Announcement("Error. \(message)").post()
    }

    private func tryBeginArmedCountdownIfReady() {
        guard countdown.state == .idle,
              activeCapture.phase == .idle,
              let launch = startArming.launchIfReady(given: setupController.assessment) else {
            return
        }
        beginCountdown(from: launch)
    }

    private func beginCountdown(from launch: StartSetLaunch) {
        do {
            let outcome: SetupGateOutcome
            switch launch {
            case .approve:
                outcome = try setupController.assessment.approve()
            case .overrideFailures:
                outcome = try setupController.assessment.overrideFailures()
            }
            try session.setCurrentSetSetupGateOutcome(outcome)
            startArming.cancel()
            countdown.start(after: outcome)
            loadEntryError = nil
            runCountdown()
        } catch SetupGateError.checksPending {
            // Keep armed; checks can flicker while the user settles.
        } catch SetupGateError.checksFailing {
            loadEntryError = "Fix setup, or open Setup looks weak — other options."
            startArming.cancel()
        } catch SetupGateError.overrideUnavailable {
            // All checks passed after an override arm; retry as approve.
            beginCountdown(from: .approve)
        } catch {
            assertionFailure("Armed setup should launch countdown once ready: \(error)")
        }
    }

    private func runCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { @MainActor in
            while case let .counting(remaining) = countdown.state {
                // Haptic only — spoken ticks made the final second feel stalled.
                cues.countdownTick(remaining)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                let fullBodyVisible = setupController.assessment
                    .check(withID: .fullBodyVisible)?.status == .passing
                countdown.tick(fullBodyVisibleAtEnd: fullBodyVisible)
                if case .readyForActiveCapture = countdown.state {
                    beginActiveCapture()
                    return
                }
            }
        }
    }

    private func startAnywayAfterCountdown() {
        do {
            if !setupController.assessment.failedChecks.isEmpty,
               !setupController.assessment.hasPendingChecks {
                let outcome = try setupController.assessment.overrideFailures()
                try session.setCurrentSetSetupGateOutcome(outcome)
            }
            countdown.startAnyway()
            beginActiveCapture()
        } catch {
            assertionFailure("A failed evaluated setup should support a low-confidence override: \(error)")
        }
    }

    private func beginActiveCapture() {
        do {
            try setupController.beginActiveSetPoseIngestion()
            do {
                try activeCapture.beginRecording()
            } catch {
                setupController.discardActiveSetPoseIngestion()
                throw error
            }
            retainedPoseSequence = nil
            reviewedSet = nil
            resetReviewEditor()
            processingError = nil
            countdown.reset()
        } catch {
            assertionFailure("Countdown ready should transition into active capture once: \(error)")
        }
    }

    private func stopActiveSet() {
        do {
            activeCapture.updateProvisionalCountedReps(
                setupController.activeSetPoseStatus.provisionalCountedReps
            )
            try activeCapture.stop()
            setupController.stop()
            captureStopTask?.cancel()
            captureStopTask = Task { @MainActor in
                do {
                    let sequence = try await setupController.freezeActiveSetPoseSequence()
                    guard !Task.isCancelled, activeCapture.phase == .processing else {
                        return
                    }
                    activeCapture.reconcileProvisionalCountedRepsAfterStop(
                        sequence.provisionalCountedReps
                    )
                    retainedPoseSequence = sequence
                    finalizeRetainedPoseSequence()
                } catch let error as ActiveSetPoseIngestionError {
                    guard !Task.isCancelled, activeCapture.phase == .processing else {
                        return
                    }
                    retainedPoseSequence = nil
                    processingError = switch error {
                    case .eventDeliveryDropped:
                        "Some camera analysis data was missed, so this set can’t be reviewed reliably."
                    case .retentionLimitExceeded:
                        "This capture exceeded the 10-minute safety limit and can’t be reviewed."
                    case .invalidPhase:
                        "This capture couldn’t be prepared for review."
                    }
                    try? activeCapture.failProcessing()
                } catch {
                    guard !Task.isCancelled, activeCapture.phase == .processing else {
                        return
                    }
                    retainedPoseSequence = nil
                    processingError = "This capture couldn’t be prepared for review."
                    try? activeCapture.failProcessing()
                }
            }
        } catch {
            assertionFailure("Stop should only be available while recording: \(error)")
        }
    }

    private func retryFinalization() {
        guard retainedPoseSequence != nil else {
            assertionFailure("Retry requires a retained active-set pose sequence")
            return
        }
        do {
            try activeCapture.retryProcessing()
            processingError = nil
            finalizeRetainedPoseSequence()
        } catch {
            assertionFailure("Only failed processing can be retried: \(error)")
        }
    }

    private func finalizeRetainedPoseSequence() {
        guard let retainedPoseSequence else {
            processingError = "This capture is no longer available for processing."
            if activeCapture.phase == .processing {
                try? activeCapture.failProcessing()
            }
            return
        }
        processingTask?.cancel()
        let frames = retainedPoseSequence.frames
        let provisionalCountedReps = retainedPoseSequence.provisionalCountedReps
        let configuration = retainedPoseSequence.analyzerConfiguration

        processingTask = Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                SquatAnalyzer(configuration: configuration).analyze(frames: frames)
            }.value

            guard !Task.isCancelled, activeCapture.phase == .processing else {
                return
            }

            let summary = TrainerSetAnalysisMapper.summary(
                from: result,
                provisionalCountedReps: provisionalCountedReps
            )

            do {
                let completedSet = try session.completeCurrentSet(analysis: summary)
                try activeCapture.finishProcessing(
                    finalizedCountedReps: summary.finalizedCountedReps
                )
                reviewedSet = completedSet
                processingError = nil
                self.retainedPoseSequence = nil
            } catch {
                processingError = "This capture couldn’t be converted into a review result."
                if activeCapture.phase == .processing {
                    try? activeCapture.failProcessing()
                }
            }
        }
    }

    private func handleActiveSetPoseIngestionFailure(
        _ failure: ActiveSetPoseIngestionError
    ) {
        guard activeCapture.phase == .recording else {
            return
        }

        activeCapture.updateProvisionalCountedReps(
            setupController.activeSetPoseStatus.provisionalCountedReps
        )
        retainedPoseSequence = nil
        setupController.stop()

        do {
            try activeCapture.stop()
            switch failure {
            case .retentionLimitExceeded:
                processingError = "This capture exceeded the 10-minute safety limit and can’t be reviewed."
            case .eventDeliveryDropped:
                processingError = "Some camera analysis data was missed, so this set can’t be reviewed reliably."
            case .invalidPhase:
                processingError = "Camera analysis stopped unexpectedly, so this set can’t be reviewed reliably."
            }
            try activeCapture.failProcessing()
        } catch {
            assertionFailure("Pose ingestion failure should leave capture in failed processing: \(error)")
        }
    }

    private var discardConfirmationBinding: Binding<Bool> {
        Binding(
            get: { activeCapture.discardConfirmationRequired },
            set: { isPresented in
                if !isPresented {
                    activeCapture.cancelDiscardConfirmation()
                }
            }
        )
    }

    private var discardConfirmationMessage: String {
        let detectedRepCount = activeCapture.finalizedCountedReps
            ?? activeCapture.provisionalCountedReps
        switch activeCapture.phase {
        case .recording where detectedRepCount > 0:
            let repNoun = detectedRepCount == 1 ? "rep" : "reps"
            return "The live count shows \(detectedRepCount) provisional \(repNoun). Discarding stops and removes this capture."
        case .processing where detectedRepCount > 0,
             .processingFailed where detectedRepCount > 0:
            let repNoun = detectedRepCount == 1 ? "rep" : "reps"
            return "This capture contains \(detectedRepCount) provisional \(repNoun). Discarding removes it before review."
        case .processingFailed:
            return "This capture could not be finalized and may still contain reps. Discarding removes it without a review."
        case .awaitingReview where detectedRepCount > 0:
            let repNoun = detectedRepCount == 1 ? "rep" : "reps"
            return "Final analysis detected \(detectedRepCount) counted \(repNoun). Discarding removes this set and any edits from the current workout."
        case .awaitingReview:
            return "Final analysis detected no counted reps. Discarding removes this zero-rep set from the current workout."
        case .processing:
            return "Final rep detection is still finishing, so this capture may contain reps. Discarding removes it before review."
        case .recording:
            return "No provisional reps are visible yet. Discarding stops and removes this capture."
        case .idle, .discarded:
            return "Discarding removes this capture."
        }
    }

    private var discardAlertTitle: String {
        activeCapture.phase == .awaitingReview ? "Discard set?" : "Discard capture?"
    }

    private var discardCancelButtonTitle: String {
        switch activeCapture.phase {
        case .recording:
            "Continue Recording"
        case .processing, .processingFailed:
            "Keep Capture"
        case .awaitingReview:
            "Keep Set"
        case .idle, .discarded:
            "Cancel"
        }
    }

    private var discardConfirmButtonTitle: String {
        activeCapture.phase == .awaitingReview ? "Discard Set" : "Discard Capture"
    }

    private func discardActiveSet() {
        activeCapture.updateProvisionalCountedReps(
            setupController.activeSetPoseStatus.provisionalCountedReps
        )
        do {
            try activeCapture.requestDiscard(
                evidenceMayStillContainReps: activeCapture.phase == .processing
                    && retainedPoseSequence == nil
            )
            if activeCapture.phase == .discarded {
                finishDiscardedSet()
            }
        } catch {
            assertionFailure("Discard should be available during capture, processing, failure, or review: \(error)")
        }
    }

    private func confirmDiscardActiveSet() {
        do {
            try activeCapture.confirmDiscard()
            finishDiscardedSet()
        } catch {
            assertionFailure("Confirmed discard requires an outstanding confirmation: \(error)")
        }
    }

    private func finishDiscardedSet() {
        let discardedReview = reviewedSet
        let discardedSetOrdinal = discardedReview?.ordinal ?? session.currentSet.ordinal
        let discardedReviewWasCorrected = !(discardedReview?.userCorrections.isEmpty ?? true)

        captureStopTask?.cancel()
        captureStopTask = nil
        processingTask?.cancel()
        processingTask = nil

        if let reviewedSet {
            do {
                try session.discardCompletedSetFromReview(reviewedSet.id)
            } catch {
                assertionFailure("Only the currently reviewed set should be discarded: \(error)")
                return
            }
        }

        retainedPoseSequence = nil
        reviewedSet = nil
        resetReviewEditor()
        processingError = nil
        setupController.discardActiveSetPoseIngestion()
        activeCapture.reset()
        startArming.cancel()
        countdown.reset()
        setupController.stop()
        setupController.resetEvidence()
        do {
            try session.clearCurrentSetSetupGateOutcome()
        } catch {
            assertionFailure("An active session should allow discard reset: \(error)")
        }
        syncLoadEntryFromCurrentSet()
        let notice = SessionNoticePresentation(
            title: discardedReviewWasCorrected
                ? "Corrected set discarded"
                : (discardedReview == nil ? "Capture discarded" : "Set discarded"),
            detail: discardedReview == nil
                ? "Set \(discardedSetOrdinal) is ready to retry. Review the entered load before arming."
                : "Set \(discardedSetOrdinal) was removed. Its load is restored for the retry.",
            systemImage: "arrow.uturn.backward.circle.fill"
        )
        sessionNotice = notice
        AccessibilityNotification.Announcement(
            "\(notice.title). \(notice.detail)"
        ).post()
        setupController.start()
    }

    private func advanceAfterStoppedSet() {
        guard reviewedSet != nil else {
            assertionFailure("Next Set requires an auto-saved reviewed set")
            return
        }

        captureStopTask?.cancel()
        captureStopTask = nil
        processingTask?.cancel()
        processingTask = nil
        retainedPoseSequence = nil
        reviewedSet = nil
        resetReviewEditor()
        processingError = nil
        setupController.discardActiveSetPoseIngestion()
        activeCapture.reset()
        startArming.cancel()
        countdown.reset()
        setupController.resetEvidence()
        syncLoadEntryFromCurrentSet()
        sessionNotice = nil
        setupController.start()
    }

    private func syncLoadEntryFromCurrentSet() {
        guard let load = session.currentSet.load else {
            return
        }
        loadText = load.value == floor(load.value)
            ? String(Int(load.value))
            : String(load.value)
        loadUnit = load.unit
    }

    private func resetSetup() {
        countdownTask?.cancel()
        countdownTask = nil
        startArming.cancel()
        countdown.reset()
        setupController.resetEvidence()
        do {
            try session.clearCurrentSetSetupGateOutcome()
        } catch {
            assertionFailure("An active session should allow setup reset: \(error)")
        }
    }

    private func sessionSummaryContent(
        _ summary: QuickSessionSummary
    ) -> some View {
        let setNoun = summary.sets.count == 1 ? "set" : "sets"

        return VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("Workout complete")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .font(.title2.bold())

                Text(exercise.displayName)
                    .font(.largeTitle.bold())

                if let totalCountedReps = summary.totalCountedReps {
                    let repNoun = totalCountedReps == 1 ? "rep" : "reps"
                    Text("\(summary.sets.count) \(setNoun) · \(totalCountedReps) counted \(repNoun)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(summary.sets.count) completed \(setNoun)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            if summary.lowConfidenceCaptureCount > 0 {
                Label {
                    Text(
                        "\(summary.lowConfidenceCaptureCount) low-confidence capture\(summary.lowConfidenceCaptureCount == 1 ? "" : "s")"
                    )
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.subheadline.weight(.semibold))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Completed sets")
                    .font(.headline)

                ForEach(summary.sets) { set in
                    SessionSummarySetRow(
                        ordinal: set.ordinal,
                        result: summarySetResult(set),
                        cleanResult: summaryCleanResult(set.cleanResult),
                        captureConfidence: set.captureConfidence
                    )
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Form trends")
                    .font(.headline)
                Text("Recurring form issues aren’t available yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))

            Button("Done") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .accessibilityHint("Returns to Quick Start. This summary is not persisted yet.")
        }
        .padding()
    }

    private func summarySetResult(_ set: SessionSetSummary) -> String {
        let count = set.countedReps.map(String.init) ?? "—"
        return "\(formattedLoad(set.load)) × \(count)"
    }

    private func summaryCleanResult(_ result: ReviewedSetCleanResult?) -> String {
        switch result {
        case let .analyzerAssessed(cleanReps):
            "\(cleanReps) clean · analyzer assessed"
        case let .userCorrected(cleanReps):
            "\(cleanReps) clean · user corrected"
        case .unavailable:
            "Clean reps unavailable"
        case .none:
            "Rep analysis unavailable"
        }
    }

    private func endSession() {
        do {
            let summary = try session.end()
            countdownTask?.cancel()
            countdownTask = nil
            captureStopTask?.cancel()
            captureStopTask = nil
            processingTask?.cancel()
            processingTask = nil
            cues.stop()
            setupController.discardActiveSetPoseIngestion()
            setupController.shutdown()

            if summary.sets.isEmpty {
                dismiss()
            } else {
                endedSummary = summary
            }
        } catch {
            assertionFailure("An active quick session should end once: \(error)")
        }
    }
}

private struct WorkoutStatusCard: View {
    let presentation: WorkoutStatusPresentation
    let completedSetCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: presentation.systemImage)
                .font(.title2)
                .foregroundStyle(presentation.tint)
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(presentation.title)
                    .font(.headline)

                Text(presentation.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(completedSetLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            presentation.tint.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.title)
        .accessibilityValue("\(presentation.detail) \(completedSetLabel).")
    }

    private var completedSetLabel: String {
        let noun = completedSetCount == 1 ? "set" : "sets"
        return "\(completedSetCount) completed \(noun)"
    }
}

private struct SessionNoticeCard: View {
    let presentation: SessionNoticePresentation
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: presentation.systemImage)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(presentation.title)
                    .font(.subheadline.weight(.semibold))
                Text(presentation.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss status")
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
        .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct CameraAvailabilityCallout: View {
    let title: String
    let detail: String
    let isLoading: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isLoading ? Color.blue : Color.orange).opacity(0.10),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(detail)
    }
}

private struct ValidationCallout: View {
    let message: String

    var body: some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.primary)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.red.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Error: \(message)")
    }
}

private struct ReviewResultHero: View {
    let load: String
    let countedReps: Int
    @ScaledMetric(relativeTo: .title) private var loadSize = 34
    @ScaledMetric(relativeTo: .largeTitle) private var countSize = 54

    var body: some View {
        let repNoun = countedReps == 1 ? "rep" : "reps"

        VStack(alignment: .leading, spacing: 5) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(load)
                        .font(.system(size: loadSize, weight: .bold, design: .rounded))
                    Text("×")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("\(countedReps)")
                        .font(.system(size: countSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(load)
                        .font(.title.bold())
                    Text("\(countedReps) counted \(repNoun)")
                        .font(.largeTitle.bold())
                        .monospacedDigit()
                }
            }

            Text("Load × current counted reps")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(load), \(countedReps) counted \(repNoun)")
    }
}

private struct ZeroRepReviewNotice: View {
    let setOrdinal: Int

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text("No completed squat cycle was found")
                    .font(.subheadline.weight(.semibold))
                Text("Discard and retry keeps an accidental capture out of this workout.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .foregroundStyle(.orange)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "No reps detected for Set \(setOrdinal). Discard and retry keeps an accidental capture out of this workout."
        )
    }
}

private struct SessionSummarySetRow: View {
    let ordinal: Int
    let result: String
    let cleanResult: String
    let captureConfidence: SessionSetCaptureConfidence

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Set \(ordinal)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(result)
                        .font(.title3.bold())
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Set \(ordinal)")
                        .font(.subheadline.weight(.semibold))
                    Text(result)
                        .font(.title3.bold())
                        .monospacedDigit()
                }
            }

            Text(cleanResult)
                .font(.footnote)
                .foregroundStyle(.secondary)

            switch captureConfidence {
            case .standard:
                EmptyView()
            case .low:
                Label {
                    Text("Low-confidence setup override")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
            case .unavailable:
                Text("Capture confidence unavailable")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let captureDescription = switch captureConfidence {
        case .standard:
            "Standard capture confidence."
        case .low:
            "Low-confidence setup override."
        case .unavailable:
            "Capture confidence unavailable."
        }
        return "Set \(ordinal), \(result). \(cleanResult). \(captureDescription)"
    }
}

private struct SetupCheckRow: View {
    let check: SetupCheck

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(check.id.displayName)
                    .font(.subheadline.weight(.semibold))

                Text(detailText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    private var iconName: String {
        switch check.status {
        case .pending:
            "circle.dotted"
        case .passing:
            "checkmark.circle.fill"
        case .failing:
            "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch check.status {
        case .pending:
            .secondary
        case .passing:
            .green
        case .failing:
            .orange
        }
    }

    private var detailText: String {
        switch check.status {
        case .pending:
            check.id.setupInstruction
        case .passing:
            "Ready"
        case .failing:
            check.id.failureFix
        }
    }

    private var accessibilityStatus: String {
        switch check.status {
        case .pending:
            "pending"
        case .passing:
            "ready"
        case .failing:
            "needs attention"
        }
    }

    private var accessibilityDescription: String {
        if check.status == .passing {
            return "\(check.id.displayName), \(accessibilityStatus)."
        }
        return "\(check.id.displayName), \(accessibilityStatus). \(detailText)"
    }
}
