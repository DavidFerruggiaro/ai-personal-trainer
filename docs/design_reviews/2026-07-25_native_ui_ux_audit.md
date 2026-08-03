# Native iOS Workout UI/UX Audit

Date: 2026-07-25

Audit status: complete

Implementation status: complete (code/Simulator only; physical gates remain open)

## Scope And Evidence

This audit starts from trusted commit `aa57e11` in the isolated `agent/native-ui-ux-pass` worktree. It covers the checked-in product/handoff/roadmap/decision records, the full `TrainerApp` SwiftUI journey, the supporting `TrainerCore` lifecycle, and available screenshot/preview verification.

There are no checked-in `TrainerApp` screenshots, SwiftUI previews, UI tests, or snapshot fixtures at the trusted base. The tracked PNG artifacts are pose-engine bakeoff contact sheets and do not show the workout UI. The UI screenshots inspected during this pass were transient and were not retained as repository artifacts.

## Current Journey

1. `TrainerApp` launches `TrainerRootView`, a Quick Start screen with the sole supported Back Squat entry.
2. `BackSquatQuickSessionView` creates a transient `QuickSession`, starts the rear camera, shows load entry, live preview, and the four setup checks.
3. `armingControls` validates and locks load, then arms the set. Passing setup launches the countdown automatically; the evaluated-failure override remains a secondary path.
4. `cameraPreview` overlays the countdown. At the final tick, acceptable full-body evidence starts capture automatically; missing visibility offers Reset or Start Anyway.
5. `activeSetControls` shows the live camera, provisional counted reps, Discard, and Stop.
6. Stop moves `ActiveSetCapture` to processing, removes/stops the camera, freezes the ordered pose sequence, and batch-finalizes off the main actor.
7. Successful finalization auto-completes the in-memory set and moves directly to `postSetReview`; failure offers retry or discard.
8. Review shows corrected load × canonical counted reps, separate clean evidence, provisional/final differences, low-confidence setup, a rep-quality strip, inline edits, Next Set, Discard, and End Workout.
9. Zero detected reps discard immediately. Detected or conservatively unfinished rep evidence requires confirmation. Review discard removes the auto-saved set and restores its ordinal and corrected load.
10. End Workout projects corrected, non-discarded sets into a transient multi-set summary; an empty session dismisses directly.

## Ranked Findings

These ten entries are ranked audit subfindings, not ten separate implementation
initiatives. The safe presentation-only work is grouped into exactly three outcome
initiatives under **Selected Improvements**; the remaining product and physical-flow
questions stay deferred.

### 1. Unsafe navigation can abandon an in-flight or in-memory session

Impact: critical

`BackSquatQuickSessionView.body` leaves the default navigation Back action and swipe gesture available while armed, recording, processing, and reviewing. `onDisappear` shuts down tasks and pose ingestion without routing through Stop, Discard, or End Workout. Since the session is transient, an accidental back gesture can silently abandon work.

References:

- `ios/TrainerApp/Sources/TrainerRootView.swift` — `BackSquatQuickSessionView.body`
- `ios/TrainerApp/Sources/TrainerRootView.swift` — `onDisappear`

Safe response: require the existing controlled actions while a set or completed session is in progress. Do not change session-domain transitions.

### 2. Recording, processing, and review compete through duplicated status chrome

Impact: high

`sessionStatusTitle`, the top status card, `cameraStatusBanner`, and each `activeSetControls` branch repeat state with different colors and copy. Recording uses orange and exposes an internal frame count. Processing exposes retained-frame implementation language. State is not consistently conveyed with a high-contrast text/icon treatment, and camera startup failure is only small overlay text.

References:

- `TrainerRootView.swift` — `sessionStatusTitle`, `sessionStatusIcon`, `sessionStatusColor`
- `TrainerRootView.swift` — `cameraStatusBanner`
- `TrainerRootView.swift` — `activeSetControls`
- `TrainerSetupGateController.swift` — `statusText`

Safe response: one presentation hierarchy with explicit Recording, Processing, Review Ready, and Camera Unavailable states; keep state transitions unchanged.

### 3. A canonical zero-rep result looks like a successful normal set

Impact: high

`postSetReview` renders a green “Set finalized” card and primary Next Set action even when the canonical result is zero. The only empty-state explanation appears lower under Rep quality. The user can therefore retain an accidental zero-rep set despite the product direction that accidental captures should be discarded.

References:

- `TrainerRootView.swift` — `postSetReview`
- `TrainerRootView.swift` — `activeSetControls`
- `TrainerCore/ActiveSetCapture.swift` — `requestDiscard`

Safe response: make “No reps detected” explicit and foreground the existing immediate discard-and-retry path while retaining an honest secondary way to keep the current zero result. Do not auto-delete or change auto-save behavior.

### 4. Discard confirmation copy can make a false evidence claim

Impact: high

The inline `discardConfirmation` always says counted reps were detected. During Stop-boundary draining, `requestDiscard(evidenceMayStillContainReps: true)` can require confirmation while the known count is still zero. The safety policy is correct; the copy is not.

References:

- `TrainerRootView.swift` — `discardConfirmation`
- `TrainerRootView.swift` — `discardActiveSet`
- `TrainerCore/ActiveSetCapture.swift` — `requestDiscard`

Safe response: use a modal destructive alert with count-aware or unfinished-analysis-aware wording and Keep Set as the cancel action.

### 5. Review editing is brittle under keyboard and Dynamic Type pressure

Impact: high

All three review fields share one Boolean focus binding. Fixed label and picker widths can collide at accessibility sizes. Validation is small red text below the fields, does not identify/focus the invalid field, and has no explicit error semantics. Keyboard Done and interactive scroll dismissal exist but are not field-specific.

References:

- `TrainerRootView.swift` — focus state declarations
- `TrainerRootView.swift` — `reviewEditor`
- `TrainerRootView.swift` — `applyReviewEdits`

Safe response: field-specific focus, adaptive vertical fallback, an icon-and-text validation callout, focus on the invalid field, and explicit keyboard dismissal. Do not implement the separate M2.11a atomic domain transaction.

### 6. Corrected-set rollback is invisible after the review disappears

Impact: medium-high

`finishDiscardedSet` correctly removes the reviewed set and restores its ordinal/corrected load, but immediately replaces review with setup and gives no confirmation. A user cannot tell whether the corrected set was removed or which load survived for the retry.

References:

- `TrainerRootView.swift` — `finishDiscardedSet`
- `TrainerCore/QuickSession.swift` — `discardCompletedSetFromReview`

Safe response: show a persistent, dismissible UI notice describing the already-completed rollback. Do not change rollback data.

### 7. Camera failure can leave Arm set available for an indefinite wait

Impact: medium-high

Camera failure is represented only by preview-banner text. `Arm set` is disabled only when load text is empty, so a valid load can arm a set even when the camera is unavailable and setup can never pass.

References:

- `TrainerSetupGateController.swift` — `streamState`, `statusText`
- `TrainerRootView.swift` — `armingControls`

Safe response: surface a dedicated error card and disable the arm affordances while the stream is failed. Do not change camera/runtime recovery.

### 8. Key layouts and actions are not consistently accessibility-sized

Impact: medium

Fixed 72/54-point hero counts do not scale semantically, review and summary rows assume horizontal space, and several secondary/destructive controls use default sizing. The weak-setup plain button may not provide a 44-point target. Color is often paired with an icon, but warning-colored small text may have weak contrast.

References:

- `TrainerRootView.swift` — `cameraPreview`, recording count, review result, `reviewEditor`, `sessionSummaryContent`, `armingControls`

Safe response: scaled metrics with adaptive fallback, combined accessibility labels/values, large controls/minimum targets, and warning text that does not depend on color alone.

### 9. Multi-set summary rows become ambiguous under narrow or large-text layouts

Impact: medium

Each row places Set N and a potentially long decimal load × count value at opposite ends of one baseline. Clean provenance and capture confidence are separate small lines. At large sizes the result can compress or wrap without a clear reading order.

Reference:

- `TrainerRootView.swift` — `sessionSummaryContent`

Safe response: adaptive row layout and one combined accessibility description. The summary content and projection remain unchanged.

### 10. Deep workout states have no deterministic visual fixtures

Impact: medium

The app target enables previews but declares none, and the concrete session view owns live camera/runtime state. Compile verification cannot inspect recording, processing, zero review, validation, rollback notice, or summary presentation.

Reference:

- `ios/TrainerApp/Sources/`
- `ios/SquatTrainer.xcodeproj/project.pbxproj` — `ENABLE_PREVIEWS`

Safe response: add deterministic previews for new stateless presentation components. Do not claim that they validate physical flow.

## Selected Improvements

1. **State hierarchy and exit safety:** one accessible recording/processing/review hierarchy, controlled exit while transient work exists, and a visible camera-failure/disabled state.
2. **Zero/discard/rollback recovery:** a canonical-zero treatment, phase-accurate destructive confirmation, and visible corrected-set rollback feedback.
3. **Adaptive review and summary accessibility:** field-specific focus and validation, keyboard dismissal, adaptive layouts, minimum touch targets, combined accessibility descriptions, and deterministic component previews.

These are the highest-value changes that preserve every existing domain transition and avoid the unresolved Arm-set wording/override-design decisions.

## Explicitly Deferred

- Final `Arm set` wording.
- Post-arm waiting layout beyond accessibility/touch-target fixes.
- Weak-setup override discovery and copy.
- Countdown-duration options and placement.
- Any analyzer, rep, clean-gate, coaching, capture, runtime, correction-transaction, persistence, or summary-projection change.
- Closing Stop/review/edit/discard/summary acceptance gates without a physical workout pass.

## Implementation And Verification Result

- Implemented exactly the three selected outcome initiatives in `TrainerRootView.swift`; no analyzer, camera/runtime, package, domain, correction, summary-projection, or persistence source changed.
- Added deterministic previews for the new stateless state, recovery, validation, and summary components. The app target compiles them in Debug, but no reliable headless preview renderer was available.
- `PoseCore` passed 4 tests; `SquatAnalysis` passed 10; `TrainerCore` passed 53; `TrainerRuntime` passed 14.
- `TrainerApp` passed a clean arm64 Simulator build through `ios/SquatTrainer.xcworkspace`.
- `xcrun swiftc -parse` and `git diff --check` passed.
- Transient normal and accessibility-extra-extra-large root-screen Simulator screenshots were inspected but not retained as repository artifacts. They were launch/layout evidence only, not evidence for the physical workout sequence.
- Two independent read-only diff reviews found no remaining actionable SwiftUI or product-scope issue. Physical timing, reachability, focus/VoiceOver behavior, and camera-interruption races remain unverified.
