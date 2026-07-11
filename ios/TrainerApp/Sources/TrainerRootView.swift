import PoseCore
import SquatAnalysis
import SwiftUI
import TrainerCore

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

private struct BackSquatQuickSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isLoadFieldFocused: Bool
    @FocusState private var isReviewEditFieldFocused: Bool
    @State private var session: QuickSession
    @State private var loadText: String
    @State private var loadUnit: LoadUnit
    @State private var loadEntryError: String?
    @State private var countdown = PreSetCountdown()
    @State private var startArming = StartSetArming()
    @State private var activeCapture = ActiveSetCapture()
    @State private var squatAnalyzer = SquatAnalyzer()
    @State private var retainedPoseFrames: [PoseFrame] = []
    @State private var reviewedSet: CompletedSetSummary?
    @State private var isEditingReview = false
    @State private var reviewLoadText = ""
    @State private var reviewLoadUnit: LoadUnit = .defaultUnit
    @State private var reviewCountedRepsText = ""
    @State private var reviewCleanRepsText = ""
    @State private var reviewEditError: String?
    @State private var processingError: String?
    @State private var countdownTask: Task<Void, Never>?
    @State private var processingTask: Task<Void, Never>?
    @State private var showWeakSetupOption = false
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

    private var sessionStatusTitle: String {
        switch activeCapture.phase {
        case .recording:
            "Recording set"
        case .processing:
            "Processing set"
        case .processingFailed:
            "Finalization failed"
        case .awaitingReview:
            "Set finalized"
        case .idle, .discarded:
            "Active session"
        }
    }

    private var sessionStatusIcon: String {
        switch activeCapture.phase {
        case .recording:
            "record.circle"
        case .processing:
            "gearshape.2"
        case .processingFailed:
            "exclamationmark.triangle"
        case .awaitingReview:
            "checkmark.circle"
        case .idle, .discarded:
            "timer"
        }
    }

    private var sessionStatusColor: Color {
        switch activeCapture.phase {
        case .recording:
            .orange
        case .processing:
            .blue
        case .processingFailed:
            .orange
        case .awaitingReview:
            .green
        case .idle, .discarded:
            .green
        }
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

                HStack {
                    Label(sessionStatusTitle, systemImage: sessionStatusIcon)
                        .fontWeight(.semibold)

                    Spacer()

                    Text("\(session.completedSets.count) completed")
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(sessionStatusColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))

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
                    .disabled(activeCapture.phase == .recording)
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isLoadFieldFocused = false
                    isReviewEditFieldFocused = false
                }
            }
        }
        .navigationTitle(exercise.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            setupController.start()
        }
        .onDisappear {
            countdownTask?.cancel()
            processingTask?.cancel()
            cues.stop()
            setupController.stop()
        }
        .onChange(of: setupController.latestPoseFrame?.timestampSeconds) { _, _ in
            guard activeCapture.isRecording,
                  let frame = setupController.latestPoseFrame else { return }
            retainedPoseFrames.append(frame)
            activeCapture.observeFrame()
            let update = squatAnalyzer.observe(frame: frame)
            activeCapture.updateProvisionalCountedReps(update.provisionalCountedReps)
        }
        .onChange(of: setupController.assessment) { _, _ in
            tryBeginArmedCountdownIfReady()
        }
    }

    @ViewBuilder
    private var preCaptureSections: some View {
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

            HStack(spacing: 12) {
                TextField("Weight", text: $loadText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($isLoadFieldFocused)
                    .accessibilityLabel("Load value")

                Picker("Unit", selection: $loadUnit) {
                    ForEach(LoadUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
            }

            if let previousSet = session.completedSets.last {
                Text("Carried forward from Set \(previousSet.ordinal). Edit it if the load changes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Pounds are the initial default. Enter the actual load, including zero if that is intentional.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let loadEntryError {
                Text(loadEntryError)
                    .font(.footnote)
                    .foregroundStyle(.red)
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
                Text(cameraStatusBanner)
                    .font(.caption.monospaced())
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))

                if case let .counting(remainingSeconds) = countdown.state {
                    Text("\(remainingSeconds)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(10)
        }
    }

    private var cameraStatusBanner: String {
        if isCapturingSet {
            return "Recording · \(activeCapture.framesObserved) frames"
        }
        if startArming.isArmed {
            let passing = setupController.assessment.checks.filter { $0.status == .passing }.count
            return "Armed · \(passing)/\(setupController.assessment.checks.count) checks"
        }
        if case .counting = countdown.state {
            return "Countdown"
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
                    Text("\(activeCapture.provisionalCountedReps)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("Live count is provisional. Final counted and clean reps come after the set.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))

                if activeCapture.discardConfirmationRequired {
                    discardConfirmation
                } else {
                    HStack(spacing: 12) {
                        Button("Discard", role: .destructive) {
                            discardActiveSet()
                        }
                        .buttonStyle(.bordered)

                        Button("Stop") {
                            stopActiveSet()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                    }
                }
            }

        case .processing:
            VStack(spacing: 10) {
                ProgressView()
                Text("Processing set…")
                    .font(.headline)
                Text("Finalizing counted reps from \(retainedPoseFrames.count) retained pose frames.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if activeCapture.discardConfirmationRequired {
                    discardConfirmation
                } else {
                    Button("Discard set", role: .destructive) {
                        discardActiveSet()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))

        case .processingFailed:
            VStack(alignment: .leading, spacing: 14) {
                Label("Couldn’t finalize set", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)

                Text(processingError ?? "The full-sequence analysis did not finish.")
                    .foregroundStyle(.secondary)

                Text("No set result was saved. Retry with the retained frames or discard this capture.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if activeCapture.discardConfirmationRequired {
                    discardConfirmation
                } else {
                    HStack(spacing: 12) {
                        Button("Discard", role: .destructive) {
                            discardActiveSet()
                        }
                        .buttonStyle(.bordered)

                        Button("Retry Finalization") {
                            retryFinalization()
                        }
                        .buttonStyle(.borderedProminent)
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
                    Label("Review unavailable", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Text("The set reached review without a finalized analysis summary.")
                        .foregroundStyle(.secondary)
                    Button("Discard set", role: .destructive) {
                        discardActiveSet()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
                .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            }

        case .idle, .discarded:
            EmptyView()
        }
    }

    private var discardConfirmation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Discard this set? Counted reps were detected.")
                .font(.subheadline.weight(.semibold))
            HStack {
                Button("Keep Set") {
                    activeCapture.cancelDiscardConfirmation()
                }
                .buttonStyle(.bordered)

                Button("Discard", role: .destructive) {
                    confirmDiscardActiveSet()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
    }

    private func postSetReview(
        completedSet: CompletedSetSummary,
        analysis: SetAnalysisSummary
    ) -> some View {
        let countedReps = completedSet.countedReps ?? analysis.finalizedCountedReps
        let cleanResult = completedSet.cleanResult ?? .unavailable

        return VStack(alignment: .leading, spacing: 18) {
            Label("Set \(completedSet.ordinal) finalized", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(formattedLoad(completedSet.load))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("×")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("\(countedReps)")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            Text("Load × current counted reps")
                .font(.footnote)
                .foregroundStyle(.secondary)

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
                Label(
                    "Low-confidence capture — setup was overridden",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
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
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Clean result")
                    .font(.headline)

                switch cleanResult {
                case let .analyzerAssessed(cleanReps):
                    Text("\(cleanReps) clean reps")
                        .font(.title2.bold())
                case let .userCorrected(cleanReps):
                    Text("\(cleanReps) clean reps")
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

            if activeCapture.discardConfirmationRequired {
                discardConfirmation
            } else {
                Button("Next Set") {
                    advanceAfterStoppedSet()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)

                HStack(spacing: 12) {
                    Button("Discard", role: .destructive) {
                        discardActiveSet()
                    }
                    .buttonStyle(.bordered)

                    Button("End Workout") {
                        endSession()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(18)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    private func reviewEditor(for completedSet: CompletedSetSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit results")
                .font(.headline)

            HStack(spacing: 12) {
                Text("Load")
                    .frame(width: 70, alignment: .leading)
                TextField("Weight", text: $reviewLoadText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($isReviewEditFieldFocused)
                    .accessibilityLabel("Corrected load value")
                Picker("Unit", selection: $reviewLoadUnit) {
                    ForEach(LoadUnit.allCases) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
            }

            HStack(spacing: 12) {
                Text("Counted")
                    .frame(width: 70, alignment: .leading)
                TextField("Reps", text: $reviewCountedRepsText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($isReviewEditFieldFocused)
                    .accessibilityLabel("Corrected counted reps")
            }

            HStack(spacing: 12) {
                Text("Clean")
                    .frame(width: 70, alignment: .leading)
                TextField("Unavailable", text: $reviewCleanRepsText)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($isReviewEditFieldFocused)
                    .accessibilityLabel("Corrected clean reps")
            }

            Text("Leave clean reps blank to keep the current status. Entering a number records user evidence, not analyzer evidence.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let reviewEditError {
                Text(reviewEditError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    resetReviewEditor()
                }
                .buttonStyle(.bordered)

                Button("Apply edits") {
                    applyReviewEdits(to: completedSet)
                }
                .buttonStyle(.borderedProminent)
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
            reviewEditError = "Load must be a number zero or greater."
            return
        }

        let trimmedCounted = reviewCountedRepsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let correctedCountedReps = Int(trimmedCounted), correctedCountedReps >= 0 else {
            reviewEditError = "Counted reps must be a whole number zero or greater."
            return
        }

        let trimmedClean = reviewCleanRepsText.trimmingCharacters(in: .whitespacesAndNewlines)
        let correctedCleanReps: Int?
        if trimmedClean.isEmpty {
            correctedCleanReps = nil
        } else if let cleanReps = Int(trimmedClean), cleanReps >= 0 {
            correctedCleanReps = cleanReps
        } else {
            reviewEditError = "Clean reps must be a whole number zero or greater, or left blank."
            return
        }

        guard let currentCountedReps = completedSet.countedReps else {
            reviewEditError = "This set no longer has a reviewable counted-rep result."
            return
        }
        let currentCleanReps = cleanRepCount(from: completedSet.cleanResult)
        let resultingCleanReps = correctedCleanReps ?? currentCleanReps
        guard resultingCleanReps.map({ $0 <= correctedCountedReps }) ?? true else {
            reviewEditError = "Clean reps cannot exceed counted reps."
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
                reviewEditError = "The reviewed set could not be refreshed."
                return
            }
            reviewedSet = correctedSet
            syncLoadEntryFromCurrentSet()
            resetReviewEditor()
        } catch let error as SetCorrectionError {
            switch error {
            case .negativeCount:
                reviewEditError = "Rep counts must be zero or greater."
            case .cleanRepsExceedCounted:
                reviewEditError = "Clean reps cannot exceed counted reps."
            }
        } catch {
            reviewEditError = "This set is no longer available to edit."
        }
    }

    private func resetReviewEditor() {
        isEditingReview = false
        reviewEditError = nil
        isReviewEditFieldFocused = false
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
            VStack(alignment: .leading, spacing: 12) {
                Text("Can't see full body. Start anyway?")
                    .font(.headline)
                HStack {
                    Button("Reset") {
                        resetSetup()
                    }
                    .buttonStyle(.bordered)

                    Button("Start Anyway") {
                        startAnywayAfterCountdown()
                    }
                    .buttonStyle(.borderedProminent)
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
                isLoadFieldFocused = false
                armStart(mode: .waitForPassingSetup)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(!hasEnteredLoad)

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

                if showWeakSetupOption {
                    Button("Accept weak setup") {
                        isLoadFieldFocused = false
                        armStart(mode: .waitForEvaluatedSetupAllowingOverride)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    .disabled(!hasEnteredLoad)

                    Text("Different from Arm set: countdown can begin even if some checks stay red. That set is labeled low-confidence.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            if !hasEnteredLoad {
                Text("Enter a load before arming.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let loadEntryError {
                Text(loadEntryError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var armedWaitingControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Armed — walk into frame")
                    .font(.headline)
                Spacer()
                Text(passingCheckSummaryText)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(setupController.assessment.isReady ? .green : .secondary)
            }

            Text(armedWaitingDetail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Cancel") {
                startArming.cancel()
                loadEntryError = nil
                cues.stop()
            }
            .buttonStyle(.bordered)
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
            loadEntryError = "Enter a valid numeric load."
            return
        }

        do {
            let load = try TrainingLoad(value: value, unit: loadUnit)
            try session.setCurrentSetLoad(load)
            startArming.arm(mode)
            loadEntryError = nil
            showWeakSetupOption = false
            tryBeginArmedCountdownIfReady()
        } catch TrainingLoadError.invalidValue {
            loadEntryError = "Load must be zero or greater."
        } catch {
            assertionFailure("An active quick session should accept load before arming: \(error)")
        }
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
            squatAnalyzer.reset()
            retainedPoseFrames.removeAll(keepingCapacity: true)
            reviewedSet = nil
            resetReviewEditor()
            processingError = nil
            try activeCapture.beginRecording()
            countdown.reset()
        } catch {
            assertionFailure("Countdown ready should transition into active capture once: \(error)")
        }
    }

    private func stopActiveSet() {
        do {
            try activeCapture.stop()
            setupController.stop()
            finalizeRetainedPoseSequence()
        } catch {
            assertionFailure("Stop should only be available while recording: \(error)")
        }
    }

    private func retryFinalization() {
        do {
            try activeCapture.retryProcessing()
            processingError = nil
            finalizeRetainedPoseSequence()
        } catch {
            assertionFailure("Only failed processing can be retried: \(error)")
        }
    }

    private func finalizeRetainedPoseSequence() {
        processingTask?.cancel()
        let frames = retainedPoseFrames
        let provisionalCountedReps = activeCapture.provisionalCountedReps
        let configuration = squatAnalyzer.configuration

        processingTask = Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                SquatAnalyzer(configuration: configuration).analyze(frames: frames)
            }.value

            guard !Task.isCancelled, activeCapture.phase == .processing else {
                return
            }

            let summary = makeAnalysisSummary(
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
                retainedPoseFrames.removeAll(keepingCapacity: false)
            } catch {
                processingError = "The retained sequence could not be converted into a review result."
                if activeCapture.phase == .processing {
                    try? activeCapture.failProcessing()
                }
            }
        }
    }

    private func makeAnalysisSummary(
        from result: SquatAnalysisResult,
        provisionalCountedReps: Int
    ) -> SetAnalysisSummary {
        let cleanResult: SetCleanResult
        if result.countedReps > 0, let cleanReps = result.cleanReps {
            cleanResult = .assessed(cleanReps: cleanReps)
        } else {
            cleanResult = .unavailable
        }

        return SetAnalysisSummary(
            provisionalCountedReps: provisionalCountedReps,
            finalizedCountedReps: result.countedReps,
            cleanResult: cleanResult,
            reps: result.reps.filter(\.counted).map { rep in
                let quality: SetRepQuality = switch rep.cleanAssessment.clean {
                case .some(true):
                    .clean
                case .some(false):
                    .notClean
                case .none:
                    .unavailable
                }
                return SetRepSummary(
                    index: rep.index,
                    startSeconds: rep.startSeconds,
                    bottomSeconds: rep.bottomSeconds,
                    endSeconds: rep.endSeconds,
                    countConfidence: rep.countConfidence,
                    quality: quality
                )
            },
            framesObserved: result.framesObserved,
            framesAnalyzed: result.framesAnalyzed
        )
    }

    private func discardActiveSet() {
        do {
            try activeCapture.requestDiscard()
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

        retainedPoseFrames.removeAll(keepingCapacity: false)
        reviewedSet = nil
        resetReviewEditor()
        processingError = nil
        squatAnalyzer.reset()
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
        setupController.start()
    }

    private func advanceAfterStoppedSet() {
        guard reviewedSet != nil else {
            assertionFailure("Next Set requires an auto-saved reviewed set")
            return
        }

        processingTask?.cancel()
        processingTask = nil
        retainedPoseFrames.removeAll(keepingCapacity: false)
        reviewedSet = nil
        resetReviewEditor()
        processingError = nil
        squatAnalyzer.reset()
        activeCapture.reset()
        startArming.cancel()
        countdown.reset()
        setupController.resetEvidence()
        syncLoadEntryFromCurrentSet()
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

    private func endSession() {
        do {
            try session.end()
            dismiss()
        } catch {
            assertionFailure("An active quick session should end once: \(error)")
        }
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
        .accessibilityElement(children: .combine)
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
}
