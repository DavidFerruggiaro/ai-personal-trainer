# M2 Back Squat Vertical Slice Tasks

Last updated: 2026-07-25

## Milestone Goal

Build the first user-facing native iOS workout loop for one exercise: side-view barbell back squat.

Milestone 2 starts after Milestone 1 selects the pose engine. The goal is not a broad fitness app. The goal is to prove that a real lifter can complete repeated back squat sets in the gym with trustworthy tracking, post-set review, and local saved history.

Current implementation is still in-memory only. Durable local history remains M2.13 and has not started.

## Dependency

Do not start Milestone 2 implementation until:

- Full Xcode is installed and selected.
- `PoseBakeoff` builds.
- Apple Vision vs MediaPipe engine decision is documented.
- The chosen engine can run prerecorded clips through the shared `PoseEstimator` path.

The original prerecorded-only estimator protocol did not cover live sample buffers. That dependency is now resolved by `PoseCore.LivePoseStreaming` / `LivePoseEvent` and the `TrainerLivePoseCamera` adapter.

## Task Status Key

- `pending`: not started
- `in_progress`: actively being worked
- `blocked`: cannot proceed without external action
- `done`: implemented and verified

When a ticket has an explicit offline completion target, `done` may still list a non-blocking physical UI follow-up. Tickets whose acceptance criteria explicitly require a device remain `in_progress` until that gate passes.

## Product Loop

```text
Start Session
-> Back Squat
-> Weight
-> Setup Gate
-> Start Set
-> Countdown
-> Active Set
-> Stop
-> Processing Set
-> Auto-Saved Post-Set Review
-> Next Set -> Countdown (loop)
or End Workout -> Workout Summary -> Done
```

## Current Execution Boundary

- M2.1-M2.4, M2.5a, M2.7, M2.7a, M2.8, M2.9, M2.11, M2.12, M2.14a, and M2.V1 are done.
- M2.6, M2.10, and parent M2.14 retain the timing, clean-evidence, or deferred physical gates documented in their result sections.
- M2.13 persistence has not started; the M2.14a summary is transient and in memory only.
- The 2026-08-03 physical pass is recorded in `docs/design_reviews/2026-08-03_m2_physical_acceptance.md`. Multi-set summary inspection is deliberately deferred until the next natural multi-set workout.
- M2.5b reachable armed weak-setup recovery passes both full native verification and the focused solo physical-device flow, closing parent M2.5. M2.6 transition instrumentation isolated the approximately 9-second delay and a cleaned preview-identity candidate is installed; physical confirmation is deferred until a natural future set.

## Tasks

### M2.0 Confirm Engine And Architecture Baseline

Status: done

Goal:

Start Milestone 2 from the selected pose engine and shared architecture, not from a parallel implementation.

Context:

Milestone 2 depends on Milestone 1. The real app should consume normalized pose streams, not engine-native data.

Tasks:

- Read final engine-selection write-up.
- Confirm the selected prerecorded engine implementation is behind `PoseEstimator`.
- Confirm normalized pose schema is stable enough for app use.
- Confirm `SquatAnalysis` owns rep/form logic.
- Confirm UI will not own analysis logic.

Acceptance criteria:

- Selected pose engine is documented.
- `TrainerApp` can depend on shared packages.
- No direct engine-specific pose types are exposed to user-facing UI.

Verification:

- Package tests pass.
- `PoseBakeoff` still builds after any shared-code changes.

Files likely touched:

- `docs/decision_log.md`
- `docs/native_rebuild_agent_handoff.md`

Documentation updates:

- Record engine selected and any known caveats.

Result:

- MediaPipe Pose Landmarker is selected for M2 implementation in `docs/bakeoff_results/2026-07-09_engine_selection.md`.
- MediaPipe prerecorded estimation conforms to the app-owned `PoseEstimator` protocol and exports `PoseCore` types.
- `TrainerApp` already links `PoseCore` and `SquatAnalysis`; its UI exposes no engine-native types.
- `SquatAnalyzer` remains the owner of future rep/form logic, but its current production API is only a placeholder. The M1 bakeoff detector must not be presented as production analysis.
- The current live-camera harness is `PoseBakeoff`-specific and bypasses the prerecorded-only estimator protocol. A production live-pose abstraction remains a focused prerequisite for later setup/capture tickets, not M2.1 shell scope.
- M1.11 physical-device viability now passes for portrait MediaPipe capture. Camera-backed setup checks and production capture are no longer blocked by feasibility, but still require a deliberate shared live-pose abstraction.
- On 2026-07-09 both shared package test suites and both app build checks passed.

### M2.1 Create TrainerApp Shell

Status: done

Goal:

Make `TrainerApp` a runnable native app with the first workout entry point.

Context:

`TrainerApp` exists as a placeholder. It should become the user-facing app while staying narrow.

Tasks:

- Add a simple root navigation structure.
- Add quick-start entry point.
- Remove placeholder-only messaging.
- Keep visual design restrained and workout-focused.

Acceptance criteria:

- App launches to a usable first screen.
- Primary action is starting a quick session.
- No marketing/landing page.

Verification:

- Build and run `TrainerApp`.

Files likely touched:

- `ios/TrainerApp/Sources/`

Documentation updates:

- Add first screen notes if decisions change.

Result:

- Replaced the pose-bakeoff placeholder message with a restrained `Quick Start` root screen.
- The only supported workout entry is `Back Squat`, labeled for barbell side-view capture.
- Added a prominent `Start Quick Session` navigation action and a narrow Back Squat session shell with an `End Quick Session` exit.
- Kept the change in the existing `TrainerRootView.swift` file, avoiding manual Xcode project-file churn.
- Added no tabs, planned workouts, templates, history, unsupported exercises, camera simulation, persistence, or analysis claims.
- `TrainerApp` built successfully for the generic iOS Simulator on 2026-07-09.
- Installed and launched `com.aiPersonalTrainer.TrainerApp` on an iPhone 16 / iOS 18.6 simulator; visual inspection confirmed the quick-start root renders correctly.
- The `NavigationLink` destination and dismiss paths compile, but an automated tap-through could not be completed because the local computer-use runtime failed to start. Do not treat that as a physical interaction result.

### M2.2 Implement Quick-Start Session State

Status: done

Goal:

Represent a local workout session in app state before persistence.

Context:

V1 uses quick-start sessions only. No planned workout builder, templates, calendar, or programming layer.

Tasks:

- Add session state model.
- Add start session action.
- Track current exercise, current set, completed sets.
- Add end workout action.
- Keep persistence out until session loop works in memory.

Acceptance criteria:

- User can start a local session.
- Session can hold multiple sets in memory.
- User can end session.

Verification:

- Manual run through start/end session.
- Unit tests if models are in a testable package.

Files likely touched:

- `ios/TrainerApp/Sources/`
- maybe `ios/Packages/SquatAnalysis/`

Documentation updates:

- Record session state assumptions if they differ from handoff.

Result:

- Added a Foundation-only `TrainerCore` package for app-domain session state. It is linked only to `TrainerApp`; pose and squat-analysis packages remain independent.
- Added stable exercise IDs, `SetDraft`, `CompletedSetSummary`, and an in-memory `QuickSession` lifecycle with explicit start, ordered set completion, next-set creation, and end behavior.
- Session mutations after end are rejected. The model intentionally contains no persistence, camera, pose, rep analysis, history, or production `SetResult` claims.
- `BackSquatQuickSessionView` now owns a local session, shows the current set and completed-set count, can advance multiple sets in memory, and marks the session ended before dismissing.
- The temporary completion control explicitly says that it neither analyzes nor saves the set; M2.5 later renamed it `Advance Test Set` and separated it from setup-required production completion.
- `TrainerCore` has three deterministic lifecycle tests covering start state, two ordered set completions, next-set advancement, end state, and rejection of post-end mutation.
- On 2026-07-10, `TrainerCore`, `PoseCore`, and `SquatAnalysis` tests passed; `TrainerApp` and `PoseBakeoff` Simulator builds passed; `TrainerApp` installed, launched, and rendered its root screen on an iPhone 16 / iOS 18.6 simulator.
- The local computer-use runtime still failed to start, so the destination buttons were not mechanically tapped in Simulator. Model transitions are unit-tested and the destination compiles, but this is not recorded as a manual interaction run.

### M2.3 Add Supported Exercise Selection

Status: done

Goal:

Let the user choose `Back Squat` explicitly.

Context:

V1 uses a predefined exercise catalog. Normal workout flow should show only supported exercises. Planned/disabled exercises are hidden.

Tasks:

- Add exercise catalog model.
- Mark `back_squat` as supported.
- Hide planned/disabled exercises from normal selection.
- Add exercise selection screen or inline selection.

Acceptance criteria:

- `Back Squat` is selectable.
- Unsupported/planned exercises do not appear in the lifting flow.
- Selected exercise is attached to the session/set.

Verification:

- Manual run through exercise selection.
- Unit test catalog filtering if model is shared.

Files likely touched:

- `ios/TrainerApp/Sources/`
- maybe `ios/Packages/SquatAnalysis/`

Documentation updates:

- Update catalog docs if exercise IDs change.

Result:

- Added the locked v1 catalog to `TrainerCore` with stable IDs and explicit `supported`, `planned`, and `disabled` availability states.
- `back_squat` is the only supported entry. `goblet_squat`, `bodyweight_squat`, `dumbbell_squat`, and `kettlebell_squat` remain planned.
- The normal quick-start flow is derived from `supportedExercises`; it renders only the Back Squat card and passes that catalog entry's stable ID into `QuickSession`.
- Planned and disabled entries have no selectable lookup result and are not rendered as teasers, disabled cards, or roadmap content in the lifting flow.
- Added four catalog tests covering the single supported exercise, all four planned IDs, disabled-entry filtering, and propagation of the selected ID into the session/current set. The full `TrainerCore` suite passes with seven tests.
- On 2026-07-10, `TrainerApp` built, installed, launched, and rendered the catalog-driven root on an iPhone 16 / iOS 18.6 simulator. A fresh screenshot showed only Back Squat. `PoseBakeoff` also retained a passing Simulator build and no `TrainerCore` target dependency.
- A mechanical tap-through into the selected Back Squat session was not completed because the local computer-use runtime failed to start. Catalog filtering and selected-ID propagation are automated tests; this result does not claim a manual selection interaction.

### M2.4 Add Weight Entry With Defaults

Status: done

Goal:

Collect load before the set with fast defaults.

Context:

Weight input happens before the set. Defaults should come from last used history once persistence exists; initially previous set/session state is enough.

Tasks:

- Add weight input before setup gate.
- Support unit, defaulting to pounds for initial user context.
- Default to previous set weight when available.
- Allow fast edit before next set.

Acceptance criteria:

- User can enter weight before set.
- Next set defaults to previous weight.
- Weight is attached to `SetResult` draft.

Verification:

- Manual run through multiple sets with same and edited weight.

Files likely touched:

- `ios/TrainerApp/Sources/`

Documentation updates:

- Record initial unit decision if changed.

Result:

- Added `TrainingLoad` as an explicit numeric value plus `LoadUnit` (`lb` or `kg`) in `TrainerCore`; pounds are the initial UI/domain default.
- Missing load remains `nil`. Zero is a valid explicit value, while negative, NaN, and infinite values are rejected.
- `SetDraft` now carries optional load, and a set cannot move into `CompletedSetSummary` until a valid load is attached. Completed summaries carry a required load.
- Completing a set copies the exact value and unit into the next set draft. Editing the next draft replaces only that draft and does not mutate the prior completed summary.
- Added a pre-set load field and `lb`/`kg` segmented control to the quick-session screen. After a set advances, the carried value/unit remain visible and editable for the next set.
- The M2.4 camera-independent seam validates and commits UI entry immediately before advancing. M2.5 now enforces load-before-setup in the domain and requires a setup outcome for normal completion; the visible bypass is explicitly test-only.
- Added five focused load tests and extended lifecycle coverage. The full `TrainerCore` suite passes with 12 tests, including missing/invalid load, explicit zero, pounds default, exact pound carry-forward with immutable prior data, and kilogram carry-forward without conversion.
- `TrainerApp` passed the generic iOS Simulator build on 2026-07-10. Mechanical multi-set weight entry was not tapped because the local computer-use runtime remains unavailable; the carry/edit behavior is verified at the domain layer, not claimed as a manual UI run.
- This remains transient session state. It is not SwiftData/history and is not the later canonical persisted `SetResult`.

### M2.5 Implement Setup Gate UI State

Status: done

Goal:

Add the pre-set setup gate before every set.

Context:

V1 setup gate checks full body visibility, side view likely, phone stability, and pose confidence. Override is allowed with low-confidence labeling.

Tasks:

- Add setup gate screen/state.
- Display clear setup instructions.
- Represent four checks:
  - `full_body_visible`
  - `side_view_likely`
  - `phone_stable`
  - `pose_confidence_ok`
- Add override path.
- Mark overridden/failed captures as low confidence.

Acceptance criteria:

- User sees setup gate before every set.
- Failed setup gives a concrete fix.
- User can override and continue with low-confidence label.

Verification:

- Manual flow with pass and override states.
- Later device test with real camera.

Files likely touched:

- `ios/TrainerApp/Sources/`
- `ios/Packages/SquatAnalysis/`

Documentation updates:

- Record exact user-facing setup messages.

Historical camera-independent progress (2026-07-10; superseded by live-signal progress below):

- Added typed state for the four locked checks: `full_body_visible`, `side_view_likely`, `phone_stable`, and `pose_confidence_ok`; each is `pending`, `passing`, or `failing`.
- Pending checks cannot be approved or overridden. Fully passing checks produce a `passed` gate disposition without inventing the later high/medium/low capture label. Evaluated failures can be overridden, and that outcome explicitly requires a low-confidence label with the failed check IDs preserved.
- A setup outcome can be attached to the current set only after load exists. The completed summary preserves it, while the next set keeps the prior load but resets setup to `nil` so the gate must run again.
- Normal `QuickSession.completeCurrentSet()` now requires a setup outcome. `TrainerApp` uses the conspicuously named `advanceCurrentSetForCameraIndependentTesting()` seam while live checks are unavailable, and its `Advance Test Set` copy explicitly says the pending gate is bypassed.
- `TrainerApp` renders all four checks as pending with explicit copy that live checks are not connected and no check is being treated as passed.
- Exact pending instructions are: `Keep your head, hips, knees, and feet in frame.`, `Stand side-on so the camera can see squat depth.`, `Place the phone on a stable surface.`, and `Use clear lighting and keep your body unobstructed.`
- Exact failure fixes are: `Move the phone back until your full body stays in frame.`, `Turn so your shoulder and hip line are side-on to the camera.`, `Set the phone down securely; do not hand-hold it.`, and `Improve the lighting and clear obstructions around your body.`
- Four setup-gate tests were added with the camera-independent seam. Live signals and arming came later (see below).
- At this historical point, M2.5 remained `in_progress` pending Arm-set UX discussion and a quick override/Stop device pass.

Live-signal progress (2026-07-10, post-checkpoint):

- Added shared `LivePoseStreaming` / `LivePoseEvent` contracts in `PoseCore`, plus `PoseSetupEvidenceExtractor` for full-body, side-view, and pose-confidence evidence from normalized landmarks.
- Added `SetupGateSignalWindow` in `TrainerCore` to require a bounded live sample window before promoting checks out of `pending`.
- Added production `TrainerLivePoseCamera` behind the shared live-pose protocol: rear camera, portrait sample buffers, MediaPipe video mode, and the same orientation contract proven in M1.11.
- Phone stability now comes from `CMDeviceMotion` rather than a synthetic UI toggle.
- `TrainerApp` shows live camera preview + pose overlay, live check status, approve/`Start Anyway` override, and setup reset. The camera-independent `Advance Test Set` bypass is gone from the session UI.
- Shared MediaPipe landmark mapping lives in `ios/Shared/Sources/MediaPipePoseMapper.swift` and is reused by `PoseBakeoff` and `TrainerApp`.
- CocoaPods now pins `MediaPipeTasksVision` for both `PoseBakeoff` and `TrainerApp`; open `SquatTrainer.xcworkspace` for either app.
- Verification: `PoseCore` tests pass; `TrainerCore` tests pass (29 as of arming work); Simulator and device builds pass for `TrainerApp`.
- Physical verification (2026-07-11): propped-phone arm flow works. User armed, walked into frame, all four checks went green, countdown ran, live recording observed ~920 frames with pose overlay. Override path not yet exercised on device.
- Open UX discussion: `Arm set` wording and post-arm waiting UI (camera must stay primary).
- At this historical point, M2.5 remained `in_progress` until that UX discussion was settled and override/Stop paths received a device pass.
- Physical acceptance (2026-08-03): the user reaffirmed that deliberate pre-position `Arm set` behavior matches solo gym use, and the normal arm/countdown/capture/Stop path passed. The weak-setup override did not: `Setup looks weak — other options` exists only before arming while all checks are evaluated and at least one is failing. Walking back from the evaluated position changes the live evidence, while the armed waiting UI offers only `Cancel`, making the override effectively unreachable for a solo lifter.
- M2.5b was selected to fix that reachability gap without weakening the deliberate-start rule; its result is recorded below.
- Final physical acceptance (2026-08-03): post-arm failed setup remained latched while the user returned to the phone, Retry restarted evaluation, Start Anyway launched the existing countdown/capture path, one rep finalized, and review displayed `Low-confidence capture — setup was overridden`. Together with the normal arm path and the automated evidence, this closes M2.5.

### M2.5a Preserve Unknown Side-View Evidence

Status: done

Goal:

Keep unavailable side-view evidence unknown instead of counting it as a failing setup sample.

Result (2026-07-12):

- Added a small `TrainerRuntime` package for testable app-runtime composition without adding any dependency to Foundation-only `TrainerCore`.
- Added `SetupGateSignalAdapter`, which preserves `PoseSetupEvidence.sideViewLikely == nil` when building the optional `TrainerCore` signal sample.
- `TrainerSetupGateController` now uses that adapter instead of coercing unknown side-view evidence to `false`.
- Tests cover unknown evidence remaining pending, unknown startup samples not diluting later passing evidence, and explicit `false` samples still producing a failing ratio.
- All four Swift package suites pass. `TrainerApp` builds through `SquatTrainer.xcworkspace` for the arm64 iOS Simulator architecture; the normal dual-architecture build reached final linking but the disk filled before its universal binary could be written.
- M2.5's physical-device and Arm-set UX gates remain open; this code-only fix does not close them.

### M2.5b Make Weak-Setup Recovery Reachable After Arming

Status: done

Selection: completed follow-up to the 2026-08-03 physical acceptance pass

Goal:

Let a solo lifter make an explicit retry/start-anyway decision after an armed setup has been evaluated as weak, without requiring another person or making the decision disappear when the lifter returns to the phone.

Constraints:

- Preserve `Arm set` as the deliberate interaction before the user props the phone and enters frame.
- Do not silently override failing checks or auto-start a low-confidence capture.
- Keep the camera primary and post-arm status compact.
- Preserve the evaluated failed-check IDs in the low-confidence setup outcome.

Acceptance criteria:

- After arming, a fully evaluated failing setup enters a latched recovery state.
- The retry/start-anyway decision remains visible when the user returns to the phone even if live checks subsequently change.
- Retry clears the latched decision and waits for a fresh evaluated setup.
- Start Anyway begins the existing countdown and the completed set is labeled low-confidence with the latched failed checks.
- The complete interaction is usable by one person with a propped phone.

Verification:

- Public-behavior state tests for latch, retry, explicit override, and cancellation.
- `TrainerApp` workspace build.
- One focused solo physical-device pass through retry and Start Anyway into low-confidence review.

Result (2026-08-03):

- Replaced the unreachable pre-arm weak-setup option with one deliberate `Arm set` path.
- Passing setup can still launch countdown immediately. Evaluated failures wait through a 10-second solo-positioning grace period so walking into frame does not prematurely stop arming.
- After the grace period, failing setup is latched as an immutable assessment. Later live changes while the user returns to the phone cannot erase the saved failed-check evidence.
- The armed recovery card names the latched failed checks and offers `Retry Setup`, `Start Anyway`, and `Cancel Arming`. Retry resets setup evidence and begins a fresh grace window. Start Anyway derives an overridden `SetupGateOutcome` from the latched assessment, preserving low-confidence failed-check provenance.
- Seven public-behavior arming tests cover deliberate arming, transient failures, grace-period latching, latch persistence, retry, explicit low-confidence acceptance, and cancellation.
- Full verification passes: PoseCore 4, SquatAnalysis 10, TrainerCore 56, TrainerRuntime 19, plus arm64 Simulator workspace builds of `TrainerApp` and `PoseBakeoff`.
- The signed replacement build passed the focused solo device flow on an iPhone 16 Pro Max. The recovery card remained visible after the user returned; its saved `Phone stable` failure remained listed while the live gate underneath had already changed to `Ready`, directly demonstrating that live evidence could not erase the latch.
- Retry restarted the armed evaluation. Start Anyway then reached capture, finalized one counted rep, and displayed `Low-confidence capture — setup was overridden` in review while leaving clean reps honestly unavailable.
- M2.5b and parent M2.5 are done. M2.6's approximately 9-second countdown-to-visible-recording delay is selected next.

### M2.6 Add Start Set Countdown

Status: in_progress

Goal:

Give the user time to get into lifting position after the deliberate start action.

Context:

Setup passing should not auto-start recording. V1 requires a deliberate start action, then countdown. No second tap after countdown. Because the phone is propped facing the lifter, the deliberate action is an earlier **arm** tap (`Arm set`) before walking into frame.

Tasks:

- Add deliberate start / arm action.
- Add countdown state.
- Default countdown to 5 seconds.
- Support likely options: 3, 5, 10 seconds.
- Continue setup checks during countdown.
- If full body is not visible at countdown end, show `Can't see full body. Start anyway?`.
- Offer `Reset` and `Start Anyway`.

Acceptance criteria:

- Countdown starts only after deliberate arm/start.
- Recording begins automatically after countdown when setup is acceptable.
- No second tap is required.
- Bad visibility at countdown end prompts reset/start-anyway choice.

Verification:

- Manual run through good setup and failed setup countdown.

Files likely touched:

- `ios/TrainerApp/Sources/`

Documentation updates:

- Record exact countdown options and messages.

Countdown / arming progress (2026-07-10 → 2026-07-11):

- Added tested `PreSetCountdown` and `StartSetArming` in `TrainerCore`.
- Flow: enter load → `Arm set` → prop phone / walk into frame → when checks are green, 5s countdown starts → recording begins automatically.
- Weak-setup path is behind `Setup looks weak — other options` → `Accept weak setup` (not a twin primary button).
- Load field has keyboard Done + scroll-dismiss.
- Countdown number overlays the camera; no spoken countdown ticks (they made the final second feel stalled).
- Duration options 3/5/10 remain unimplemented; default remains 5 seconds.
- Physical arm→countdown→record succeeded once. Visibility-failure confirmation at countdown end not yet device-tested.
- Open discussion: final arming copy and post-arm chrome.
- Physical acceptance (2026-08-03): the normal armed setup triggered the countdown and recording automatically without a second tap, but the gap from countdown completion to visible recording state was approximately 9 seconds. M2.6 remains `in_progress`; after M2.5b, measure whether the delay is camera/runtime startup, main-thread work, or state feedback and make the recording boundary unambiguous.

Transition diagnosis (2026-08-03):

- A temporary timestamp build reproduced the user's approximately 8-second visible delay. The five-second countdown itself completed in 5.05 seconds, the countdown-to-domain-recording transition took under 1 millisecond, no camera restart occurred, and the first active pose observation was retained 9.04 seconds later.
- A queued-observation fast-forward hypothesis produced the same 9.04-second gap and no user-visible improvement. That experiment and all temporary logging were removed rather than retained as ineffective complexity.
- The strongest remaining code-local cause is the duplicated SwiftUI camera-preview expression across countdown and recording branches: changing phase can recreate and reattach an `AVCaptureVideoPreviewLayer` for the already-running session on the main thread. The candidate keeps one structural preview identity across setup/countdown/recording and adds a distinct success haptic immediately after the active recording boundary is established.
- The cleaned candidate passes all four package suites and both workspace Simulator builds, builds and signs for the iPhone 16 Pro Max, and is installed on that device. The user ended cumbersome physical testing for the day, so this is not claimed as a physical fix yet.
- Remaining M2.6 transition gate: during a natural future set, compare countdown end to the distinct haptic, visible `Recording set` state, and first counted motion. Duration choices and the existing visibility-failure behavior remain separately open under M2.6.

### M2.7 Add Active Set Capture State

Status: done

Goal:

Represent active set recording and analysis from countdown end until stop/discard.

Context:

Capture/analyze continuously. Do not try to save only from the first detected rep. No pause in v1.

Tasks:

- Add active set state.
- Start capture/analyze at countdown end.
- Show provisional live rep count.
- Add `Stop` control.
- Add `Discard` control.
- Do not add pause.

Acceptance criteria:

- Active set begins after countdown.
- User sees provisional live rep count.
- User can stop.
- User can discard.
- No pause path exists.

Verification:

- Manual active-set flow.
- Later device test with real camera.

Files likely touched:

- `ios/TrainerApp/Sources/`
- `ios/Packages/SquatAnalysis/`

Documentation updates:

- Record any state-machine changes.

Implementation history (2026-07-10 → 2026-07-11):

- Added tested `ActiveSetCapture` in `TrainerCore`: `idle -> recording -> processing -> awaitingReview`, plus `discarded`.
- Live pose frames increment `framesObserved` during recording. This originally left provisional reps at 0 behind an analyzer seam; M2.8 now supplies the real streaming count.
- The first seam used a thin stopped handoff. M2.9/M2.10 replaced it with full-sequence processing, in-memory auto-save, and automatic review.
- `Discard` is immediate when provisional reps are 0; confirmation is required when provisional reps are > 0. No pause control exists.
- Physical device: countdown auto-started recording and observed ~920 frames with "Recording set" UI.
- `TrainerCore` has 29 passing tests (includes arming + active-set suites).
- Physical acceptance (2026-08-03) confirmed Stop, immediate zero-rep active discard, detected-rep confirmation/cancel/confirm, and return to the same set/load. No pause path exists. Together with the prior analyzer-backed provisional-count pass, this satisfies M2.7; the weak-setup reachability and countdown latency findings remain scoped to M2.5/M2.6.

### M2.7a Lossless Active-Set Pose Ingestion

Status: done

Goal:

Route every emitted live-pose observation directly into active-set retention and streaming analysis without depending on SwiftUI delivery of a published latest frame.

Result (2026-07-12):

- Added `ActiveSetPoseIngestion` to the app-runtime package. It owns the active set's temporary pose sequence and its streaming `SquatAnalyzer`, while `TrainerCore` remains Foundation-only and pose-independent.
- `TrainerSetupGateController` now sends each `LivePoseEvent.observation` directly to setup evidence, preview state, and (while recording) active-set ingestion in the same ordered event-consumer path.
- Removed the SwiftUI `onChange` latest-frame delivery seam. Published pose status now drives display only; buffering and analysis have already occurred before SwiftUI observes an update.
- Each emitted observation carries a monotonic source sequence. Starting a set takes one lock-protected snapshot of the source watermark and delivery-loss count before runtime recording begins. Stop enqueues a delivery boundary behind already-queued camera work before freezing an immutable `ActiveSetPoseSequence`; pre-start and post-boundary observations cannot enter it, and loss after the start snapshot cannot be absorbed into the baseline.
- The camera-to-consumer event stream is bounded to 120 newest events. If delivery pressure drops an event during a set, ingestion fails closed, clears partial evidence, and requires discard instead of finalizing a sequence claimed to be complete.
- The controller keeps one event subscription for its lifetime so ordinary Stop/Next Set cycles do not terminate the `AsyncStream` consumer. Batch finalization replays exactly the frozen sequence and preserves its streaming provisional count/configuration.
- Discard clears the runtime buffer. Successful finalization releases the stopped snapshot; failed finalization retains it for retry.
- Added an explicit in-memory safety policy: at most 18,000 frames or 10 minutes. Exceeding either limit clears partial evidence, prevents finalization, stops the camera, and requires discard rather than claiming a result from an incomplete sequence.
- Fourteen runtime tests cover optional setup evidence, ordered N-frame delivery, setup/preview/active fan-out, pre-start exclusion, Stop isolation, next-set reuse, discard clearing, exact duration/empty-stop boundaries, frame-count overflow, duration overflow, and fail-closed event loss. Two additional `TrainerCore` lifecycle tests cover post-boundary provisional-count reconciliation and conservative discard confirmation while Stop evidence is still draining. All four package suites pass, and both arm64 Simulator app schemes build through the workspace.
- Stop-boundary waits are cancellation-aware, and delivery loss resumes pending waits immediately. Delivery-drop notifications are coalesced so a saturated main actor cannot turn the fail-closed signal into a second unbounded queue.
- "Lossless" means every observation emitted by `TrainerLivePoseCamera`; AVFoundation capture-output drops remain separately reported and are not reconstructed.
- M2.7 remains `in_progress` until its existing Arm-set UX and physical Stop/Discard gates pass. M2.7a does not close those gates from offline tests.

### M2.8 Implement Provisional Rep Count

Status: done

Goal:

Show live/provisional rep count during the set.

Context:

Live count is provisional. Post-set count is canonical.

Tasks:

- Connect pose stream to `SquatAnalyzer`.
- Emit provisional rep count.
- Display count prominently during active set.
- Ensure UI labels do not imply finality.

Acceptance criteria:

- Rep count updates during active set.
- Saved result uses finalized post-set count.
- If final count differs, review can indicate finalization.

Verification:

- Real or recorded-camera test once camera is available.
- Unit tests for analyzer state if available.

Files likely touched:

- `ios/Packages/SquatAnalysis/`
- `ios/TrainerApp/Sources/`

Documentation updates:

- Record provisional/final behavior if adjusted.

Implementation progress (2026-07-11):

- Replaced the production `SquatAnalyzer` placeholder with a separate streaming detector; the rough M1 `SquatRepDetector` remains bakeoff-only and is not wired into `TrainerApp`.
- A provisional count now requires a confident visible leg, a short standing calibration, meaningful knee flexion plus hip descent, an ascent, and a return near the lifter's own standing reference.
- Depth and absolute lockout thresholds are not counted-rep gates. Production rep output carries separate depth/lockout/tempo clean-gate states, which remain explicitly `not_assessed` in M2.8 rather than inventing clean reps.
- Tracking gaps cancel the in-progress candidate and require standing recalibration. Small knee dips and knee flexion without hip descent are covered as non-counting cases.
- `TrainerApp` now feeds active-capture `PoseFrame` values to the production analyzer and forwards only its monotonic provisional count into `ActiveSetCapture`.
- Automated verification passes: `SquatAnalysis` (10 tests), `PoseCore`, `TrainerCore` (35 tests), and the `TrainerApp` workspace Simulator build.
- Physical-device verification passed on one eight-rep set: the live provisional counter reported all 8 completed reps, including one intentionally shallow rep. Small test leg movements and walking back toward the phone produced no phantom reps.
- This is a successful integration/behavior check, not an accuracy estimate. Broader footage and set variation are still needed before threshold quality can be claimed.
- M2.9 now retains the full active-set sequence and runs a fresh batch pass for the canonical count. Both the provisional and finalized counts are preserved in the in-memory app-domain summary, and M2.10 discloses a change when they differ.
- The finalized result is auto-saved into the in-memory quick session before review. This closes M2.8's remaining finalized/saved-count acceptance criteria. Persistence across launch remains M2.13 and was not started.

### M2.9 Implement Stop -> Processing -> Review

Status: done

Goal:

Make set-ending state unambiguous.

Context:

On `Stop`, leave camera screen immediately, process the set, auto-save, and show review.

Tasks:

- Add processing state.
- Finalize reps from full pose sequence.
- Auto-save in memory initially.
- Transition to post-set review.
- Add discard option if processing fails or hangs.

Acceptance criteria:

- `Stop` leaves active camera screen.
- Processing state is visible.
- Review appears automatically.
- No explicit save button is required.

Verification:

- Manual stop flow.
- Simulate processing failure if practical.

Files likely touched:

- `ios/TrainerApp/Sources/`
- `ios/Packages/SquatAnalysis/`

Documentation updates:

- Record processing states/errors.

Historical starting point / guardrails (2026-07-11; superseded by implementation progress below):

- Current `TrainerRootView` uses a fake 600ms processing delay, keeps `ActiveSetCapture` in a thin `awaitingReview` handoff, and does not retain the full active-set pose sequence. Replace this seam; do not build the real review on top of the delay.
- Retain active-set `[PoseFrame]` values in memory only, beginning at recording start and ending on Stop/Discard. Do not put the per-frame stream in `CompletedSetSummary`, SwiftData, or another structured record.
- `SquatAnalyzer.analyze(frames:)` already supports deterministic batch replay with the same counted-cycle semantics as streaming. The canonical post-set count should come from that full-sequence pass, not by blindly copying the provisional count.
- Preserve both provisional and finalized counts so review can disclose a difference. Do not silently rewrite history.
- Stop must remove the active camera UI immediately, show real processing state, and automatically enter review. Processing failure needs an honest recover/discard path.
- `TrainerCore` should remain independent of `SquatAnalysis`. Map finalized output into small app-domain summary types rather than importing engine/analyzer implementation types into the session model.

Implementation progress (2026-07-11):

- Active capture now retains only the current set's `[PoseFrame]` values in app memory. The buffer starts at recording, is consumed by finalization, and is cleared after successful review handoff or discard; it is not embedded in `CompletedSetSummary`.
- `Stop` immediately changes state, removes the camera preview, and stops the live camera/controller. The fake 600 ms delay is gone.
- Finalization runs `SquatAnalyzer.analyze(frames:)` on the retained full sequence off the main actor. Its result is mapped in `TrainerApp` into `TrainerCore.SetAnalysisSummary`; `TrainerCore` still has no `SquatAnalysis` dependency.
- The mapped summary preserves provisional and finalized counted reps, explicit clean availability, per-rep timing/count confidence/quality availability, and frame totals.
- Successful finalization auto-completes the current set into `QuickSession.completedSets` before review and carries load into the next draft. Review requires no save tap.
- Processing can be discarded while in flight if it hangs. An unexpected finalization/session failure enters an honest failed state with retained-frame retry and discard; no result is claimed as saved on that path.
- `TrainerCore` tests cover canonical/provisional preservation, failure retry, failure discard, and in-flight processing discard. All required package tests and the `TrainerApp` workspace Simulator build pass.
- A fresh signed `TrainerApp` 0.1 (build 1) was built from `SquatTrainer.xcworkspace` and installed successfully on the connected iPhone 16 Pro Max at 2026-07-11 01:04 local time. `devicectl` confirmed the installed developer app. Automated launch was denied only because the phone was locked; installation is verified, behavior is not.
- Physical acceptance (2026-08-03): Stop removed the camera immediately, processing completed, review opened automatically, and the set was already present in the current session with no explicit save action. Processing failure was not artificially induced; existing deterministic retry/discard coverage remains the evidence for that exceptional path. M2.9 is done.

### M2.10 Build Post-Set Review Screen

Status: in_progress

Goal:

Show what happened and what to do next set.

Context:

Review should be compact and useful, not a dense analytics dashboard.

Tasks:

- Show weight x counted reps.
- Show clean reps separately.
- Show one primary form takeaway.
- Show per-rep quality strip.
- Show top 1-2 issue categories.
- Show confidence label if capture quality was low.
- Primary action: `Next Set`.
- Secondary actions: edit, discard, end workout.

Acceptance criteria:

- Counted reps and clean reps are visually distinct.
- Primary action is `Next Set`.
- Review does not require explicit save.
- Low-confidence capture is visible when applicable.

Verification:

- Manual review with normal and low-confidence mock results.

Files likely touched:

- `ios/TrainerApp/Sources/`

Documentation updates:

- Add UI notes or screenshots later.

Historical starting point / guardrails (2026-07-11; superseded by implementation progress below):

- The current `awaitingReview` card is only a temporary handoff, not M2.10 review.
- Counted reps are now trustworthy enough for the first review slice, but clean depth/lockout/tempo gates remain `not_assessed`. Never render unknown clean status as `0 clean reps`, and do not default missing evidence to clean.
- If required clean gates cannot be implemented and physically challenged in this ticket, show an explicit unavailable/insufficient-evidence state and keep M2.10 `in_progress` rather than making a false quality claim.
- Keep review compact: load × canonical counted reps first; clean result separate; provisional→finalized change disclosure only when values differ; low-confidence setup label when overridden; primary `Next Set`; secondary discard/end workout.
- Per-rep timing/count events already exist in `AnalyzedSquatRep`. Add quality markers only for evidence the analyzer actually produces.
- Avoid dense charts, generic workout logging, persistence, video retention, real-time cues, or exercise expansion in this slice.

Implementation progress (2026-07-11):

- Replaced the temporary stopped handoff with a compact review led by `load × canonical counted reps`.
- Clean result is visually separate and strongly typed as assessed or unavailable. Current depth/lockout/tempo gates remain unassessed, so review says `Clean reps unavailable` and explicitly says that this is not `0 clean reps`.
- A provisional → finalized count note appears only when the two values differ.
- Setup overrides render a visible low-confidence capture label.
- Counted reps render as a compact numbered quality strip. Current markers are neutral/unavailable because no clean-gate evidence is being invented.
- The form takeaway is explicitly unavailable until required clean gates are assessed; no fake issue categories or clean claims are shown.
- `Next Set` is the primary action. `Discard` and `End Workout` are secondary. There is no explicit save action.
- Remaining before `done`: required clean depth/lockout/tempo conclusions are still unimplemented and physically unchallenged, so M2.10 intentionally remains `in_progress` under its guardrail. Normal and overridden-setup review also need physical-device inspection.
- Physical acceptance (2026-08-03): normal review was legible at standard text size and clearly showed `load × counted reps`, unavailable clean evidence, neutral rep markers, unavailable takeaway, and `Next Set`. A later focused M2.5b pass reached Start Anyway through the intended solo flow and verified the low-confidence review label. Required clean gates remain open, so M2.10 stays `in_progress`.
- Offline clean-evidence audit (2026-08-03): added deterministic `scripts/audit_clean_rep_evidence.py` coverage/geometry reporting plus tests and replayed all three local MediaPipe pose exports. The verified barbell set has confident right-leg evidence throughout all seven labeled rep intervals, but its 2 FPS cadence misses the 150 ms timing target and its labels contain seven clean positives with zero depth, lockout, or tempo/control failures. Raw tracked-joint geometry also shows that naive hip-vs-knee and terminal-knee-angle thresholds would contradict or overinterpret verified-clean labels. The go/no-go is therefore **no-go for native/user-facing clean gates, go for a full-rate gate-labeled data tranche**. `not_assessed` / `Clean reps unavailable` remains the required production behavior. See `docs/bakeoff_results/2026-08-03_clean_rep_evidence/README.md`.

### M2.11 Add Essential Post-Set Editing

Status: done

Goal:

Allow lightweight correction without turning the app into a spreadsheet.

Context:

V1 edit essentials only: weight, counted reps, clean reps, discard set. Preserve original model output.

Tasks:

- Add inline edit for weight.
- Add inline edit for counted reps.
- Add inline edit for clean reps.
- Add discard set from review.
- Preserve original model output in set metadata.

Acceptance criteria:

- User can correct obvious errors quickly.
- Detailed per-rep tag editing is not present.
- Corrections are represented in `user_corrections`.

Verification:

- Manual edit flow.
- Data model/unit test if possible.

Files likely touched:

- `ios/TrainerApp/Sources/`
- maybe `ios/Packages/SquatAnalysis/`

Documentation updates:

- Record correction behavior.

Historical starting guardrails (2026-07-11; implemented in the result below):

- This is the recommended codebase-only task while physical testing is unavailable. Keep M2.9, M2.10, and M2.12 physical gates open; do not mark them done from Simulator or unit tests.
- `QuickSession` now auto-completes a finalized set before review. `CompletedSetSummary` preserves the analyzer-mapped `SetAnalysisSummary`, and review discard can roll back only the most recently reviewed set.
- Add correction state in `TrainerCore`, not `SquatAnalysis`. `TrainerCore` must remain Foundation-only and analyzer-independent.
- Preserve immutable original model output. User-facing corrected values should be derived from the original finalized summary plus an ordered correction log; never overwrite the analyzer result in place.
- Scope editing to load, counted reps, and clean reps. Existing discard remains M2.12 behavior. Do not add detailed per-rep tag editing, persistence, history, video, coaching, or exercise expansion.
- Unknown clean status must remain unavailable until the user explicitly edits clean reps. A manual clean-rep correction is user evidence, not a model claim, and should be labeled/represented as such.
- Enforce nonnegative counts and `clean <= counted`. Reject impossible edits with clear validation; do not silently clamp values or turn unavailable clean evidence into zero.
- Preserve correction metadata sufficient for later persistence: timestamp, field, previous user-facing value, new value, and `user_edit` reason.
- Use TDD one behavior at a time through public `TrainerCore` APIs, then add the smallest compact edit affordance to the existing review. No explicit Save Set action should reappear; applying an edit updates the in-memory reviewed set.
- Automated completion target: focused correction tests, all four package suites, and the `TrainerApp` workspace Simulator build. Physical edit-flow inspection can remain a follow-up.

Result (2026-07-11):

- Added Foundation-only correction types and public `QuickSession` correction behavior for load, counted reps, and clean reps. `CompletedSetSummary` keeps its original load and analyzer-mapped `SetAnalysisSummary` immutable, then derives current review values by replaying its ordered `userCorrections`.
- Every correction records timestamp, typed field, previous user-facing value, new value, and the stable `user_edit` reason. Repeated edits use the latest derived value as the next correction's previous value.
- Clean review state distinguishes analyzer-assessed, user-corrected, and unavailable values. An explicit manual clean count can replace unavailable review status, but the UI labels it `User corrected — not analyzer evidence`; leaving the edit field blank preserves unavailable rather than creating zero.
- Negative counted/clean values and `clean > counted` are rejected with explicit errors. Validation applies in both directions, including lowering counted reps below an existing analyzer or user clean count; values are never clamped.
- Correcting review load also updates the next draft's carried-forward load. Review discard removes a corrected auto-saved set and restores the set ordinal with the corrected load and a reset setup gate.
- Added a compact inline `Edit results` affordance to the existing review for load/unit, counted reps, and clean reps. `Apply edits` mutates the already auto-saved in-memory set and refreshes review; it does not reintroduce `Save Set` or detailed per-rep editing.
- Added 10 public-behavior correction tests through `QuickSession`. Final verification passes: `PoseCore`, `SquatAnalysis` (10 tests), `TrainerCore` (45 tests), and the `TrainerApp` workspace Simulator build.
- Physical acceptance (2026-08-03) passed the correction follow-up: load/count/clean edits applied, manual clean evidence displayed `User corrected — not analyzer evidence`, `clean > counted` was rejected, corrected load carried forward, and corrected review discard restored the corrected load and set ordinal. M2.11 remains done.

### M2.12 Implement Discard Behavior

Status: done

Goal:

Make accidental/bad sets disappear from workout history.

Context:

Discard is available during active set and after stopping. If reps were detected, confirm before discarding. If no reps were detected, discard should be immediate or nearly immediate.

Tasks:

- Add active-set discard.
- Add review discard.
- Add confirmation if reps detected.
- Ensure discarded set does not contribute to session summary/history.

Acceptance criteria:

- Accidental set can be discarded during active set.
- Bad set can be discarded from review.
- Detected-rep discard confirms.
- Discarded sets disappear from user-facing history.

Verification:

- Manual discard flow for zero-rep and detected-rep sets.

Files likely touched:

- `ios/TrainerApp/Sources/`

Documentation updates:

- Record discard confirmation copy.

Implementation progress (2026-07-11):

- Active-set zero-rep discard remains immediate; any detected provisional rep requires `Discard this set? Counted reps were detected.` confirmation.
- Processing and failed-processing states can now be discarded, providing an escape hatch for a hung or failed finalization.
- Review discard uses the canonical finalized count when available, so a rep found only by batch finalization still requires confirmation.
- Because successful finalization auto-saves in memory before review, review discard now removes that exact most-recent completed set and restores the set ordinal/load draft with setup reset. The discarded set no longer contributes to the session's completed-set count.
- `TrainerCore` tests cover active, processing, failed-processing, canonical-review confirmation, and reviewed-set rollback behavior.
- Physical acceptance (2026-08-03) passed all three required paths: zero-rep active discard was immediate; detected provisional reps required confirmation and supported cancel/confirm; corrected review discard removed the completed result, restored its set ordinal and corrected load, and reduced the completed-set count. One zero-rep attempt did not show the expected recovery notice, while a later confirmed discard did; that visual-feedback inconsistency is a follow-up and does not change the verified discard/rollback outcome. M2.12 is done.

### M2.13 Add Local Persistence

Status: pending

Goal:

Persist workout/session/set records locally.

Context:

Use hybrid persistence: SwiftData for structured records, files for videos and heavy artifacts. Do not embed full videos or pose streams in structured records.

Tasks:

- Add SwiftData models for workout/session/set records.
- Store `SetResult` structured fields.
- Store artifact references only.
- Save auto-saved set after processing.
- Ensure discarded sets do not contribute to history.

Acceptance criteria:

- Saved sets survive app restart.
- `SetResult` includes required fields.
- Heavy artifacts are not stored inside SwiftData records.

Verification:

- Manual save/relaunch check.
- Unit tests if models are isolated enough.

Files likely touched:

- `ios/TrainerApp/Sources/`
- maybe new persistence package later

Documentation updates:

- Record persistence model details.

### M2.14 Add Session Summary

Status: in_progress

Goal:

Show a concise workout-end summary.

Context:

Summary should prioritize strength-training usefulness, not social sharing or calories.

Tasks:

- Show exercises performed.
- Show sets x reps x weight.
- Show clean reps vs counted reps.
- Show top recurring form issue.
- Show low-confidence captures.
- Optionally show total volume.

Acceptance criteria:

- User can end workout.
- Summary reflects saved, non-discarded sets only.
- Summary is concise and useful.

Verification:

- Manual multi-set session.

Files likely touched:

- `ios/TrainerApp/Sources/`

Documentation updates:

- Record summary fields.

### M2.14a Add In-Memory Session Summary Projection

Status: done

Goal:

Derive and present a concise transient workout summary from the current quick session without starting persistence or inventing unavailable form conclusions.

Scoped behavior:

- Project only completed, non-discarded sets.
- Use corrected load, counted-rep, and clean-rep values while preserving analyzer, user-corrected, and unavailable clean evidence.
- Preserve ordered set rows and low-confidence setup overrides.
- Keep mixed load units separate; do not calculate a cross-unit volume total.
- Show the projection in a minimal in-memory end-workout screen.
- Do not add history, persistence, charts, issue inference, quality scoring, or programming suggestions.

Verification:

- Public-behavior `TrainerCore` tests for corrected sets, discarded sets, clean evidence, low-confidence captures, and empty sessions.
- `TrainerApp` workspace Simulator build.
- Manual multi-set summary inspection remains required before closing M2.14.

Result (2026-07-12):

- `QuickSession.end()` now atomically returns an immutable `QuickSessionSummary` with exact session timestamps and ordered completed-set rows.
- Each row uses current corrected load/count/clean values while preserving analyzer-assessed, user-corrected, unavailable, and missing evidence as distinct states. Original analyzer/load evidence and correction logs remain unchanged.
- Discarded sets and the unfinished current draft are excluded. Passed, overridden, and missing setup outcomes map to standard, low, and unavailable capture confidence.
- Counted reps are totaled only when every completed row has count evidence. Per-set decimal lb/kg loads remain exact; no mixed-unit volume total or conversion was added.
- Ending a nonempty session now shuts down capture and replaces the workout in place with a concise transient summary: set rows, clean evidence, counted total, low-confidence count, honest unavailable form-trend copy, and `Done`. Empty sessions still dismiss directly.
- Review `Next Set`, `Discard`, and `End Workout` actions are withheld while edits are unapplied, so typed corrections cannot be silently omitted from the summary.
- Six public-behavior summary tests bring `TrainerCore` to 53 passing tests. All four package suites and arm64 Simulator workspace builds for both app schemes pass.
- A signed `TrainerApp` build from checkpoint `ffb32d5` installed and launched successfully on the connected iPhone 16 Pro Max at 2026-07-12 19:56 local time. This verifies device delivery only, not the multi-set summary acceptance behavior.
- M2.14 remains `in_progress` pending physical multi-set summary inspection. Recurring form issues remain deliberately unavailable because issue inference/clean scoring was not added.
- The 2026-08-03 pass accumulated multiple sets but the summary state was no longer reachable when requested, and recreating several sets solely for acceptance had become cumbersome. The user deferred summary inspection until the next natural multi-set workout. M2.14 remains `in_progress`; this is deferred, not failed.

### M2.V1 Add Deterministic Native Verification Harness

Status: done

Goal:

Make the current native Back Squat vertical slice repeatably verifiable offline without implying physical-device or real-world pose accuracy.

Scoped behavior:

- Add one repository command that runs all four Swift package suites and the workspace Simulator builds.
- Support a package-only quick mode.
- Use one isolated, self-cleaning scratch directory for verification state, with an override for choosing a filesystem that has sufficient free space.
- Add a public app-runtime mapping seam for `SquatAnalysisResult` → `TrainerCore.SetAnalysisSummary`.
- Exercise the public normalized-pose → runtime ingestion → streaming/batch analysis → app-domain package contracts with deterministic synthetic pose frames.
- Keep clean-rep evidence unavailable when the analyzer has not assessed the required gates.

Guardrails:

- Do not change counted-rep thresholds or invent clean-rep gates.
- Do not claim physical-device behavior, overlay alignment, or real-world pose accuracy from synthetic data.
- Keep `TrainerCore` Foundation-only and independent of pose/analysis packages.
- Do not start persistence, history, video retention, coaching, new exercises, or broad UI work.

Verification:

- Focused red/green checks in `TrainerRuntime`.
- Shell syntax/help checks for the repository command.
- All four Swift package suites.
- `TrainerApp` workspace Simulator build; `PoseBakeoff` workspace Simulator build when running the full harness.

Result (2026-07-24, corrected 2026-07-25):

- Added executable `scripts/verify_native_ios.sh`. Its default mode runs all four package suites, then single-architecture Simulator builds for `TrainerApp` and `PoseBakeoff` through `ios/SquatTrainer.xcworkspace`; `--packages-only` provides the quick mode.
- The harness canonicalizes an existing writable non-root scratch base with Apple Bash's `pwd -P`, creates one uniquely named child for SwiftPM caches/build products and Xcode DerivedData, restricts cleanup to that exact child prefix, and reports success only after cleanup succeeds. An explicit keep-artifacts option preserves the directory.
- Scratch isolation and cleanup do not impose a storage quota or guarantee free capacity. `NATIVE_VERIFY_SCRATCH_ROOT` lets the caller select another filesystem when local space is constrained.
- SwiftPM sandboxing remains enabled by default. `NATIVE_VERIFY_DISABLE_SWIFTPM_SANDBOX=1` is an explicit opt-in reserved for a process already contained by a trusted outer sandbox; the harness no longer infers that condition from `CODEX_SANDBOX`. The Xcode build portion still requires normal access to CoreSimulator services.
- Extracted the production `SquatAnalysisResult` → `SetAnalysisSummary` adapter from `TrainerRootView` into public `TrainerRuntime.TrainerSetAnalysisMapper`; `TrainerCore` remains dependency-free.
- Added mapper coverage for provisional/final count preservation, counted-rep filtering, frame totals, assessed clean totals, clean/not-clean/unavailable per-rep quality, partial evidence, and zero-count unavailable semantics.
- Added a deterministic package-contract scenario that feeds synthetic normalized full-body frames through setup evidence and ordered active-set ingestion, verifies streaming and batch counted-rep agreement, maps the result, auto-completes a `QuickSession`, and projects the ended-session summary without inventing clean evidence. Its deliberately frozen test configuration does not cover production defaults, `TrainerSetupGateController` wiring, controller `AsyncStream` behavior, or queued Stop handling.
- Corrected verification passed with Swift 6.1.2 / Xcode 16.4: PoseCore (1 XCTest + 3 Swift Testing tests), SquatAnalysis (10), TrainerCore (53), TrainerRuntime (19), plus host-architecture Simulator workspace builds for both app schemes.
- This result proves deterministic package contracts and compilation only. It does not exercise AVFoundation camera input, MediaPipe landmark generation, CoreMotion, overlay geometry, SwiftUI interactions, physical Stop/review/edit/discard behavior, or real-world pose accuracy. All existing physical gates remain open.

### M2.15 Back Squat Vertical Slice Review

Status: pending

Goal:

Review the milestone through product, engineering, QA, and documentation lenses.

Context:

Before expanding features, confirm that the single-exercise loop is usable.

Tasks:

- Product co-founder review.
- Staff engineer review.
- QA review with real gym scenarios.
- Documentation/release review.
- Record known gaps and next milestone entry criteria.

Acceptance criteria:

- Review notes exist in `docs/design_reviews/`.
- Gaps are classified as must-fix vs later.
- Milestone 3 can start without re-litigating Milestone 2.

Files likely touched:

- `docs/design_reviews/`
- `docs/decision_log.md`
- `docs/native_rebuild_agent_handoff.md`

Documentation updates:

- Add milestone review note.
