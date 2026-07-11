# M2 Back Squat Vertical Slice Tasks

Last updated: 2026-07-10

## Milestone Goal

Build the first user-facing native iOS workout loop for one exercise: side-view barbell back squat.

Milestone 2 starts after Milestone 1 selects the pose engine. The goal is not a broad fitness app. The goal is to prove that a real lifter can complete repeated back squat sets in the gym with trustworthy tracking, post-set review, and local saved history.

## Dependency

Do not start Milestone 2 implementation until:

- Full Xcode is installed and selected.
- `PoseBakeoff` builds.
- Apple Vision vs MediaPipe engine decision is documented.
- The chosen engine can run prerecorded clips through the shared `PoseEstimator` path.

The shared protocol does not yet cover live sample buffers. A production live-pose abstraction is an additional dependency before camera-backed setup checks or active capture, not before camera-independent session/UI tickets.

## Task Status Key

- `pending`: not started
- `in_progress`: actively being worked
- `blocked`: cannot proceed without external action
- `done`: implemented and verified

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
-> Next Set
```

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

Status: in_progress

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

Camera-independent progress (2026-07-10):

- Added typed state for the four locked checks: `full_body_visible`, `side_view_likely`, `phone_stable`, and `pose_confidence_ok`; each is `pending`, `passing`, or `failing`.
- Pending checks cannot be approved or overridden. Fully passing checks produce a `passed` gate disposition without inventing the later high/medium/low capture label. Evaluated failures can be overridden, and that outcome explicitly requires a low-confidence label with the failed check IDs preserved.
- A setup outcome can be attached to the current set only after load exists. The completed summary preserves it, while the next set keeps the prior load but resets setup to `nil` so the gate must run again.
- Normal `QuickSession.completeCurrentSet()` now requires a setup outcome. `TrainerApp` uses the conspicuously named `advanceCurrentSetForCameraIndependentTesting()` seam while live checks are unavailable, and its `Advance Test Set` copy explicitly says the pending gate is bypassed.
- `TrainerApp` renders all four checks as pending with explicit copy that live checks are not connected and no check is being treated as passed.
- Exact pending instructions are: `Keep your head, hips, knees, and feet in frame.`, `Stand side-on so the camera can see squat depth.`, `Place the phone on a stable surface.`, and `Use clear lighting and keep your body unobstructed.`
- Exact failure fixes are: `Move the phone back until your full body stays in frame.`, `Turn so your shoulder and hip line are side-on to the camera.`, `Set the phone down securely; do not hand-hold it.`, and `Improve the lighting and clear obstructions around your body.`
- Four setup-gate tests bring `TrainerCore` to 16 passing tests. `TrainerApp` passes the generic iOS Simulator build.
- M2.5 remains `in_progress`. A live signal source, interactive pass/fail/override flow, and `TrainerApp` real-device verification are intentionally not claimed; the remaining engineering dependency is the production live-pose abstraction.

### M2.6 Add Start Set Countdown

Status: pending

Goal:

Give the user time to get into lifting position after tapping `Start Set`.

Context:

Setup passing should not auto-start recording. V1 requires deliberate `Start Set`, then countdown. No second tap after countdown.

Tasks:

- Add `Start Set` action.
- Add countdown state.
- Default countdown to 5 seconds.
- Support likely options: 3, 5, 10 seconds.
- Continue setup checks during countdown.
- If full body is not visible at countdown end, show `Can't see full body. Start anyway?`.
- Offer `Reset` and `Start Anyway`.

Acceptance criteria:

- Countdown starts only after deliberate tap.
- Recording begins automatically after countdown when setup is acceptable.
- No second tap is required.
- Bad visibility at countdown end prompts reset/start-anyway choice.

Verification:

- Manual run through good setup and failed setup countdown.

Files likely touched:

- `ios/TrainerApp/Sources/`

Documentation updates:

- Record exact countdown options and messages.

### M2.7 Add Active Set Capture State

Status: pending

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

### M2.8 Implement Provisional Rep Count

Status: pending

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

### M2.9 Implement Stop -> Processing -> Review

Status: pending

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

### M2.10 Build Post-Set Review Screen

Status: pending

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

### M2.11 Add Essential Post-Set Editing

Status: pending

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

### M2.12 Implement Discard Behavior

Status: pending

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

Status: pending

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
